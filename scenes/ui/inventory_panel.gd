class_name InventoryPanel
extends Control

const MythicFusionModal = preload("res://scenes/ui/mythic_fusion_modal.gd")

# ==========================================
# INVENTORY BENCH PANEL (SPRINT 6 - TASK S6.3)
# Quản lý 10 ô chứa đồ và giao diện trực quan
# ==========================================

signal slot_clicked(slot_idx: int)
signal item_crafted_ui(item: ItemData, slot_idx: int)

@export var max_slots: int = 10
var selected_slot: int = -1

var slot_buttons: Array[Button] = []
var slots_container: GridContainer = null
var header_label: Label = null
var tooltip_instance: ItemTooltip = null

# SPRINT 6: DRAG & DROP PIPELINE (TASK S6.4)
const DRAG_THRESHOLD: float = 8.0
var dragged_slot: int = -1
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_preview: Control = null
var board_grid = null
var board_view = null
var battle_manager = null
var fusion_modal: MythicFusionModal = null

func _ready() -> void:
	_build_ui()
	if ItemManager != null:
		if not ItemManager.item_crafted.is_connected(_on_item_crafted):
			ItemManager.item_crafted.connect(_on_item_crafted)
	refresh_all_slots()

func _build_ui() -> void:
	if slots_container != null:
		return
		
	custom_minimum_size = Vector2(108, 300)
	size = Vector2(108, 300)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Control Anchors: Left Dock Cột Trái Chuẩn TFT (2 Cột x 5 Hàng)
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 35.0
	offset_top = 175.0
	offset_right = 143.0
	offset_bottom = 475.0
	position = Vector2(35, 175)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(vbox)
	
	# Header Label
	header_label = Label.new()
	header_label.name = "HeaderLabel"
	header_label.text = "🎒 KHO ĐỒ"
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.add_theme_font_size_override("font_size", 12)
	header_label.add_theme_color_override("font_color", Color("#94a3b8"))
	vbox.add_child(header_label)
	
	# Slots Container: GridContainer 2 Cột x 5 Hàng
	slots_container = GridContainer.new()
	slots_container.name = "SlotsContainer"
	slots_container.columns = 2
	slots_container.add_theme_constant_override("h_separation", 8)
	slots_container.add_theme_constant_override("v_separation", 8)
	slots_container.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(slots_container)
	
	slot_buttons.clear()
	for i in range(max_slots):
		var btn := Button.new()
		btn.name = "SlotButton_%d" % i
		btn.custom_minimum_size = Vector2(48, 48)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func(): select_slot(i))
		btn.gui_input.connect(func(event: InputEvent): _on_slot_gui_input(event, i))
		btn.mouse_entered.connect(func(): _on_slot_mouse_entered(i))
		btn.mouse_exited.connect(func(): _on_slot_mouse_exited(i))
		slots_container.add_child(btn)
		slot_buttons.append(btn)
		
	# Floating Tooltip
	tooltip_instance = ItemTooltip.new()
	tooltip_instance.name = "InventoryTooltip"
	tooltip_instance.hide()
	tooltip_instance.z_index = 100
	add_child(tooltip_instance)

func select_slot(idx: int) -> void:
	if idx < 0 or idx >= max_slots:
		return
		
	var item_at_idx = get_item_at(idx)
	
	# 1. Nếu click vào chính ô đang chọn -> Hủy chọn
	if selected_slot == idx:
		selected_slot = -1
		slot_clicked.emit(idx)
		refresh_all_slots()
		return
		
	# 2. Nếu chưa chọn ô nào
	if selected_slot == -1:
		if item_at_idx != null:
			selected_slot = idx
			slot_clicked.emit(idx)
			refresh_all_slots()
		return
		
	# 3. Đã có ô chọn trước đó -> Thử ghép đồ từ selected_slot sang idx
	if ItemManager != null and ItemManager.craft_on_bench(selected_slot, idx):
		selected_slot = -1
		refresh_all_slots()
	else:
		if item_at_idx != null:
			selected_slot = idx
		else:
			selected_slot = -1
		slot_clicked.emit(idx)
		refresh_all_slots()

func try_equip_selected_to_hero(hero: HeroEntity) -> bool:
	if selected_slot == -1 or hero == null:
		return false
	return equip_slot_to_hero(selected_slot, hero)

func equip_slot_to_hero(slot_idx: int, hero: HeroEntity) -> bool:
	if hero == null or ItemManager == null:
		return false
	if slot_idx < 0 or slot_idx >= ItemManager.bench_slots.size():
		return false
	var item: ItemData = ItemManager.bench_slots[slot_idx]
	if item == null:
		return false
		
	# SPRINT 6 - TASK S6.6: Kiểm tra điều kiện mở Modal Thần Thoại khi lắp Cổ Vật Bậc 2
	if item.tier == 2:
		var tier2_indices: Array[int] = []
		for i in range(hero.equipped_items.size()):
			var it := hero.equipped_items[i]
			if it != null and it.tier == 2:
				tier2_indices.append(i)
				
		if tier2_indices.size() >= 2:
			# Tướng đang có từ 2 Cổ Vật Bậc 2 trở lên -> Kích hoạt Modal Lựa Chọn!
			_open_mythic_fusion_modal(hero, item, slot_idx, tier2_indices)
			return true

	if hero.equip_item(item):
		ItemManager.bench_slots[slot_idx] = null
		if selected_slot == slot_idx:
			selected_slot = -1
		refresh_all_slots()
		return true
	return false

func _open_mythic_fusion_modal(hero: HeroEntity, item: ItemData, src_slot: int, indices: Array[int]) -> MythicFusionModal:
	if fusion_modal != null and is_instance_valid(fusion_modal):
		fusion_modal.cancel_and_close()
		
	var modal := MythicFusionModal.new()
	modal.name = "MythicFusionModal"
	modal.setup(hero, item, src_slot, indices)
	
	modal.option_selected.connect(_on_fusion_option_selected)
	modal.equip_separate_selected.connect(_on_fusion_equip_separate)
	modal.modal_cancelled.connect(_on_fusion_modal_cancelled)
	
	fusion_modal = modal
	if battle_manager != null:
		battle_manager.fusion_modal = modal
		if battle_manager.prep_timer != null:
			battle_manager.prep_timer.paused = true
			
	add_child(modal)
	return modal

func _on_fusion_option_selected(hero: HeroEntity, slot_idx: int, crafted_mythic: ItemData, src_slot: int) -> void:
	if hero != null and slot_idx >= 0 and slot_idx < hero.equipped_items.size():
		hero.equipped_items[slot_idx] = crafted_mythic
		if ItemManager != null and src_slot >= 0 and src_slot < ItemManager.bench_slots.size():
			ItemManager.bench_slots[src_slot] = null
		hero._on_item_equipped(crafted_mythic, true)
	refresh_all_slots()
	_cleanup_fusion_modal()

func _on_fusion_equip_separate(hero: HeroEntity, item: ItemData, src_slot: int) -> void:
	if hero != null:
		hero.equip_item(item, true) # force_no_craft = true
		if ItemManager != null and src_slot >= 0 and src_slot < ItemManager.bench_slots.size():
			ItemManager.bench_slots[src_slot] = null
	refresh_all_slots()
	_cleanup_fusion_modal()

func _on_fusion_modal_cancelled(_src_slot: int) -> void:
	refresh_all_slots()
	_cleanup_fusion_modal()

func _cleanup_fusion_modal() -> void:
	if battle_manager != null and battle_manager.prep_timer != null:
		battle_manager.prep_timer.paused = false
	fusion_modal = null
	if battle_manager != null:
		battle_manager.fusion_modal = null

func get_item_at(idx: int) -> ItemData:
	if ItemManager != null and idx >= 0 and idx < ItemManager.bench_slots.size():
		return ItemManager.bench_slots[idx]
	return null

func refresh_all_slots() -> void:
	if slot_buttons.is_empty():
		return
		
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		var item: ItemData = get_item_at(i)
		var is_selected: bool = (selected_slot == i)
		
		# TASK S6.4.1: Nếu ô đang được kéo thả -> Tạm coi là rỗng để ẩn icon khỏi ô gốc!
		if is_dragging and dragged_slot == i:
			item = null
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#0f172a")
		style.set_corner_radius_all(8)
		
		if is_selected:
			# Viền phát sáng chọn lựa (#38bdf8 - Electric Blue)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color("#38bdf8")
			style.shadow_color = Color(0.22, 0.74, 0.97, 0.4)
			style.shadow_size = 6
		elif item != null:
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			match item.tier:
				1:
					style.border_color = Color("#64748b") # Bạc Bậc 1
				2:
					style.border_color = Color("#f59e0b") # Vàng kim Bậc 2
					style.shadow_color = Color(0.96, 0.62, 0.04, 0.3)
					style.shadow_size = 3
				3:
					style.border_color = Color("#e879f9") # Neon Pink/Purple Bậc 3
					style.shadow_color = Color(0.91, 0.47, 0.98, 0.4)
					style.shadow_size = 6
				_:
					style.border_color = Color("#64748b")
		else:
			# Ô trống
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color("#334155")
			
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		
		if item != null:
			btn.text = _get_item_symbol(item)
			btn.add_theme_font_size_override("font_size", 20)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			btn.text = str(i + 1)
			btn.add_theme_font_size_override("font_size", 12)
			btn.add_theme_color_override("font_color", Color("#475569"))

func _get_item_symbol(item: ItemData) -> String:
	match item.id:
		"bloodsteel_shard": return "🗡️"
		"sorcery_crystal": return "🔮"
		"obsidian_plating": return "🛡️"
		"soul_aether_bead": return "💧"
		"life_stone_shard": return "💚"
		"soul_severing_blade": return "⚔️"
		"void_celestial_orb": return "🌌"
		"colossus_vitality_armor": return "🏰"
		"blood_runic_blade": return "🩸"
		"thorn_obsidian_shield": return "🌵"
		"frost_prison_heart": return "❄️"
		"obsidian_armor": return "🪨"
		"infinite_mana_bead": return "💠"
		"origin_ancient_staff": return "🪄"
		"mythic_soul_severing_blade": return "👑"
		"mythic_void_celestial_orb": return "✨"
		"mythic_colossus_vitality_armor": return "🔱"
		"mythic_colossus_immortal": return "🗿"
		"mythic_blood_runic_severing": return "👹"
		_:
			if item.tier == 3: return "👑"
			elif item.tier == 2: return "⚔️"
			return "📦"

func _on_slot_mouse_entered(idx: int) -> void:
	if is_dragging:
		return # TASK S6.4.1: Không bung Tooltip khi đang kéo đồ lướt qua các ô khác
	var item := get_item_at(idx)
	if item != null and tooltip_instance != null:
		tooltip_instance.render_tooltip(item)
		if idx < slot_buttons.size():
			var btn := slot_buttons[idx]
			var tt_size := tooltip_instance.get_combined_minimum_size()
			
			# Bung Tooltip sang mép phải ô đồ (cách 12px)
			var target_x: float = btn.position.x + btn.size.x + 12.0
			# Căn dọc ngang bằng với ô đồ hoặc dịch nhẹ lên trên
			var target_y: float = btn.position.y - (tt_size.y - btn.size.y) / 2.0
			
			# shortcut: right-anchor offset, upgrade to screen edge clamping if viewport scales
			tooltip_instance.position = Vector2(target_x, target_y)

func _on_slot_mouse_exited(_idx: int) -> void:
	if tooltip_instance != null:
		tooltip_instance.hide()

func _on_item_crafted(item: ItemData, slot_idx: int) -> void:
	refresh_all_slots()
	item_crafted_ui.emit(item, slot_idx)

# ==========================================
# DRAG & DROP PIPELINE (TASK S6.4)
# ==========================================
func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if get_item_at(idx) != null:
				dragged_slot = idx
				drag_start_pos = event.global_position
				is_dragging = false
		else:
			if is_dragging:
				_finish_drag(event.global_position)
				_cancel_drag()
				get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if dragged_slot != -1 and event is InputEventMouseMotion:
		if not is_dragging:
			if (event.global_position - drag_start_pos).length() >= DRAG_THRESHOLD:
				is_dragging = true
				_create_drag_preview(dragged_slot)
				refresh_all_slots() # TASK S6.4.1: Biến mất khỏi ô gốc ngay tích tắc bắt đầu kéo!
		if is_dragging and drag_preview != null:
			drag_preview.global_position = event.global_position - drag_preview.size * 0.5

	elif is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_finish_drag(event.global_position)
			_cancel_drag()
			get_viewport().set_input_as_handled()

func _create_drag_preview(slot_idx: int) -> void:
	if drag_preview != null:
		if is_instance_valid(drag_preview):
			drag_preview.queue_free()
		drag_preview = null
		
	var item := get_item_at(slot_idx)
	if item == null:
		return
		
	var panel := PanelContainer.new()
	panel.name = "DragPreview"
	panel.custom_minimum_size = Vector2(48, 48)
	panel.size = Vector2(48, 48)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 200
	panel.modulate.a = 0.85
	panel.scale = Vector2(1.15, 1.15)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.16, 0.9)
	style.set_corner_radius_all(8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.22, 0.74, 0.97, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	
	var lbl := Label.new()
	lbl.name = "IconLabel"
	lbl.text = _get_item_symbol(item)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)
	
	var parent_canvas = get_viewport()
	if parent_canvas != null:
		parent_canvas.add_child(panel)
	else:
		add_child(panel)
		
	drag_preview = panel
	if is_instance_valid(tooltip_instance):
		tooltip_instance.hide()

func _cancel_drag() -> void:
	is_dragging = false
	dragged_slot = -1
	if drag_preview != null:
		if is_instance_valid(drag_preview):
			drag_preview.queue_free()
		drag_preview = null
	refresh_all_slots() # TASK S6.4.1: Hoàn trả hiển thị (Rebound) nếu drop trượt hoặc hủy kéo!

func _finish_drag(drop_pos: Vector2) -> void:
	var src_slot := dragged_slot
	if src_slot < 0 or src_slot >= max_slots:
		return
	var item := get_item_at(src_slot)
	if item == null:
		return
		
	# 1. Thả vào ô kho đồ khác
	for j in range(slot_buttons.size()):
		var target_btn := slot_buttons[j]
		if target_btn.get_global_rect().has_point(drop_pos):
			if j != src_slot:
				var crafted: bool = false
				if ItemManager != null:
					crafted = ItemManager.craft_on_bench(src_slot, j)
					if not crafted:
						ItemManager.swap_or_move_bench(src_slot, j)
				refresh_all_slots()
			return

	# 2. Thả vào Tướng trên sàn cờ
	var target_hero: HeroEntity = null
	if board_view != null and board_grid != null:
		var cell: Vector2i = board_view.world_to_grid(drop_pos)
		if board_grid.is_in_bounds(cell):
			var occupant = board_grid.get_occupant(cell)
			if occupant is HeroEntity:
				target_hero = occupant
				
	if target_hero == null and get_tree() != null:
		var hero_nodes = get_tree().get_nodes_in_group("heroes")
		for h in hero_nodes:
			if h is HeroEntity and is_instance_valid(h):
				if h.global_position.distance_to(drop_pos) <= 45.0:
					target_hero = h
					break
					
	if target_hero != null:
		equip_slot_to_hero(src_slot, target_hero)
		return
