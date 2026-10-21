class_name InventoryPanel
extends Control

# ==========================================
# INVENTORY BENCH PANEL (SPRINT 6 - TASK S6.3)
# Quản lý 10 ô chứa đồ và giao diện trực quan
# ==========================================

signal slot_clicked(slot_idx: int)
signal item_crafted_ui(item: ItemData, slot_idx: int)

@export var max_slots: int = 10
var selected_slot: int = -1

var slot_buttons: Array[Button] = []
var slots_container: HBoxContainer = null
var header_label: Label = null
var tooltip_instance: ItemTooltip = null

func _ready() -> void:
	_build_ui()
	if ItemManager != null:
		if not ItemManager.item_crafted.is_connected(_on_item_crafted):
			ItemManager.item_crafted.connect(_on_item_crafted)
	refresh_all_slots()

func _build_ui() -> void:
	if slots_container != null:
		return
		
	custom_minimum_size = Vector2(572, 70)
	size = Vector2(572, 70)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Control Anchors: Neo cố định Bottom-Center responsive khi Fullscreen / thay đổi độ phân giải
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -286.0
	offset_right = 286.0
	offset_top = -173.0
	offset_bottom = -103.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(vbox)
	
	# Header Label
	header_label = Label.new()
	header_label.name = "HeaderLabel"
	header_label.text = "🎒 HÀNG CHỜ KHO ĐỒ (10 Ô)"
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.add_theme_font_size_override("font_size", 12)
	header_label.add_theme_color_override("font_color", Color("#94a3b8"))
	vbox.add_child(header_label)
	
	# Slots Container
	slots_container = HBoxContainer.new()
	slots_container.name = "SlotsContainer"
	slots_container.add_theme_constant_override("separation", 8)
	slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_container.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(slots_container)
	
	slot_buttons.clear()
	for i in range(max_slots):
		var btn := Button.new()
		btn.name = "SlotButton_%d" % i
		btn.custom_minimum_size = Vector2(50, 50)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func(): select_slot(i))
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
	if hero.equip_item(item):
		ItemManager.bench_slots[slot_idx] = null
		if selected_slot == slot_idx:
			selected_slot = -1
		refresh_all_slots()
		return true
	return false

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
	var item := get_item_at(idx)
	if item != null and tooltip_instance != null:
		tooltip_instance.render_tooltip(item)
		if idx < slot_buttons.size():
			var btn := slot_buttons[idx]
			var tt_size := tooltip_instance.get_combined_minimum_size()
			
			# Canh giữa theo nút đồ và đặt đáy Tooltip cách đỉnh nút đồ 10px
			var target_x: float = btn.position.x + (btn.size.x - tt_size.x) / 2.0
			var target_y: float = -tt_size.y - 10.0
			
			# Khóa biên không cho Tooltip tràn ra mép ngoài màn hình
			# shortcut: clamp to 582px bench width, upgrade to dynamic viewport width if supporting narrow resolutions
			target_x = clamp(target_x, -10.0, 582.0 - tt_size.x)
			
			tooltip_instance.position = Vector2(target_x, target_y)

func _on_slot_mouse_exited(_idx: int) -> void:
	if tooltip_instance != null:
		tooltip_instance.hide()

func _on_item_crafted(item: ItemData, slot_idx: int) -> void:
	refresh_all_slots()
	item_crafted_ui.emit(item, slot_idx)
