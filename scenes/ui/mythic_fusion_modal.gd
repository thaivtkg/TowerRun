class_name MythicFusionModal
extends CanvasLayer

# ==============================================================================
# SPRINT 6: BẢNG CHỌN HỢP THỂ THẦN THOẠI BẬC 3 (TASK S6.6 - GD SPEC)
# ==============================================================================

signal option_selected(hero: HeroEntity, slot_idx: int, crafted_mythic: ItemData, source_bench_slot: int)
signal equip_separate_selected(hero: HeroEntity, item: ItemData, source_bench_slot: int)
signal modal_cancelled(source_bench_slot: int)

var current_hero: HeroEntity = null
var incoming_item: ItemData = null
var source_bench_slot: int = -1
var target_slot_indices: Array[int] = []
var mythic_options: Array[ItemData] = []
var is_open: bool = false

# UI References
var backdrop: ColorRect = null
var panel_container: PanelContainer = null
var options_container: HBoxContainer = null
var separate_button: Button = null
var cancel_button: Button = null

func _ready() -> void:
	layer = 60
	_build_ui()
	hide()

func _build_ui() -> void:
	if backdrop != null:
		return
		
	# 1. Lớp phủ mờ (Dimmed Backdrop) khóa click xuyên thấu
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.02, 0.04, 0.08, 0.8)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	
	# 2. Khung Trung Tâm (PanelContainer) Monolithic Dark Fantasy
	panel_container = PanelContainer.new()
	panel_container.name = "CenterPanel"
	panel_container.custom_minimum_size = Vector2(640, 420)
	panel_container.set_anchors_preset(Control.PRESET_CENTER)
	panel_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.16, 0.98)
	style.set_corner_radius_all(12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#e879f9") # Neon Pink Thần Thoại
	style.shadow_color = Color(0, 0, 0, 0.8)
	style.shadow_size = 16
	panel_container.add_theme_stylebox_override("panel", style)
	add_child(panel_container)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel_container.add_child(margin)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(main_vbox)
	
	# Tiêu đề Thần Thoại hiệu ứng sóng & màu Dark Fantasy
	var title_label := RichTextLabel.new()
	title_label.name = "TitleLabel"
	title_label.bbcode_enabled = true
	title_label.text = "[center][wave amp=15 freq=3][color=#fbbf24]🔥 THĂNG HOA BẬC 3: CHỌN HƯỚNG HỢP THỂ[/color][/wave][/center]"
	title_label.fit_content = true
	title_label.scroll_active = false
	title_label.custom_minimum_size = Vector2(600, 28)
	main_vbox.add_child(title_label)
	
	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.text = "Chọn 1 trong các hướng hợp thể sức mạnh tối thượng"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#94a3b8"))
	main_vbox.add_child(subtitle)
	
	# Dải Thẻ Lựa Chọn Hợp Thể (HBoxContainer)
	options_container = HBoxContainer.new()
	options_container.name = "OptionsContainer"
	options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	options_container.add_theme_constant_override("separation", 16)
	main_vbox.add_child(options_container)
	
	# Thanh Điều Hướng Phía Dưới (HBoxContainer)
	var nav_hbox := HBoxContainer.new()
	nav_hbox.name = "NavHBox"
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(nav_hbox)
	
	separate_button = Button.new()
	separate_button.name = "SeparateButton"
	separate_button.text = "🎒 Lắp Riêng Rẽ (Thành 3 Món)"
	separate_button.custom_minimum_size = Vector2(210, 38)
	separate_button.focus_mode = Control.FOCUS_NONE
	separate_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	separate_button.pressed.connect(_on_separate_pressed)
	_style_nav_button(separate_button, Color("#38bdf8"))
	nav_hbox.add_child(separate_button)
	
	cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "❌ Hủy Bỏ (Hoàn Trả Kho Đồ)"
	cancel_button.custom_minimum_size = Vector2(200, 38)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_button.pressed.connect(cancel_and_close)
	_style_nav_button(cancel_button, Color("#ef4444"))
	nav_hbox.add_child(cancel_button)

func _style_nav_button(btn: Button, accent_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.25, 0.9)
	style.set_corner_radius_all(6)
	style.border_width_bottom = 2
	style.border_color = accent_color
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.15, 0.22, 0.35, 1.0)
	hover_style.border_color = Color.WHITE
	btn.add_theme_stylebox_override("hover", hover_style)

# ==============================================================================
# QUY TRÌNH MỞ & RENDER MODAL LỰA CHỌN
# ==============================================================================
func open(hero: HeroEntity, item: ItemData, src_slot: int, tier2_indices: Array[int]) -> void:
	current_hero = hero
	incoming_item = item
	source_bench_slot = src_slot
	target_slot_indices = tier2_indices.duplicate()
	mythic_options.clear()
	is_open = true
	
	_build_ui()
	
	# Xóa các thẻ cũ
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()
		
	# Tạo thẻ lựa chọn cho từng Cổ Vật Bậc 2
	for i in range(tier2_indices.size()):
		var slot_idx: int = tier2_indices[i]
		if slot_idx >= hero.equipped_items.size():
			continue
		var existing: ItemData = hero.equipped_items[slot_idx]
		if existing == null:
			continue
			
		var mythic: ItemData = null
		if ItemManager != null:
			mythic = ItemManager.get_mythic_fusion(existing, incoming_item)
		if mythic == null:
			continue
			
		mythic_options.append(mythic)
		var card := _create_choice_card(i, slot_idx, existing, incoming_item, mythic)
		options_container.add_child(card)
		
	# Kiểm tra nút Lắp riêng (chỉ khả dụng nếu tướng có dưới 3 món)
	if separate_button != null:
		separate_button.visible = (hero.equipped_items.size() < 3)
		
	show()

func _create_choice_card(choice_idx: int, slot_idx: int, existing: ItemData, incoming: ItemData, mythic: ItemData) -> Control:
	var panel := PanelContainer.new()
	panel.name = "ChoiceCard_%d" % choice_idx
	panel.custom_minimum_size = Vector2(210, 270)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f172a")
	style.set_corner_radius_all(8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#f59e0b") # Viền vàng hổ phách
	style.shadow_color = Color(0.96, 0.62, 0.04, 0.25)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	# Công thức: [Ô X: Tên 1] + [Tên 2]
	var recipe_lbl := RichTextLabel.new()
	recipe_lbl.bbcode_enabled = true
	recipe_lbl.text = "[center][color=#94a3b8]%s[/color] + [color=#38bdf8]%s[/color][/center]" % [existing.name, incoming.name]
	recipe_lbl.fit_content = true
	recipe_lbl.scroll_active = false
	vbox.add_child(recipe_lbl)
	
	# Biểu tượng Thần Thoại Vương Miện 👑
	var icon_lbl := Label.new()
	icon_lbl.text = "👑"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 28)
	vbox.add_child(icon_lbl)
	
	# Tên Thần Thoại
	var name_lbl := RichTextLabel.new()
	name_lbl.bbcode_enabled = true
	name_lbl.text = "[center][b][color=#fb7185]%s[/color][/b][/center]" % mythic.name
	name_lbl.fit_content = true
	name_lbl.scroll_active = false
	vbox.add_child(name_lbl)
	
	# Tóm tắt chỉ số
	var stats_lbl := Label.new()
	stats_lbl.text = _format_stats_summary(mythic)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(stats_lbl)
	
	# 2 Tầng nội tại
	var passive1 := RichTextLabel.new()
	passive1.bbcode_enabled = true
	passive1.text = "[color=#38bdf8]⚡ %s[/color]" % mythic.sub_passive_name
	passive1.fit_content = true
	passive1.scroll_active = false
	vbox.add_child(passive1)
	
	var passive2 := RichTextLabel.new()
	passive2.bbcode_enabled = true
	passive2.text = "[color=#fbbf24]🔥 %s[/color]" % mythic.mythic_passive_name
	passive2.fit_content = true
	passive2.scroll_active = false
	vbox.add_child(passive2)
	
	# Nút hành động Hợp Thể Món Này
	var action_btn := Button.new()
	action_btn.name = "CraftButton_%d" % choice_idx
	action_btn.text = "🔥 HỢP THỂ MÓN NÀY"
	action_btn.focus_mode = Control.FOCUS_NONE
	action_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_btn.pressed.connect(func(): _on_option_chosen(slot_idx, mythic))
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.22, 0.35)
	btn_style.set_corner_radius_all(6)
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color("#f59e0b")
	action_btn.add_theme_stylebox_override("normal", btn_style)
	action_btn.add_theme_font_size_override("font_size", 11)
	action_btn.add_theme_color_override("font_color", Color("#fef08a"))
	vbox.add_child(action_btn)
	
	return panel

func _format_stats_summary(it: ItemData) -> String:
	var parts: Array[String] = []
	if it.get_bonus_ad() > 0: parts.append("⚔️ +%.0f SMCK" % it.get_bonus_ad())
	if it.get_bonus_ap() > 0: parts.append("🔮 +%.0f SMPT" % it.get_bonus_ap())
	if it.get_bonus_hp() > 0: parts.append("🏰 +%.0f HP" % it.get_bonus_hp())
	if it.get_bonus_armor() > 0: parts.append("🛡️ +%.0f Giáp" % it.get_bonus_armor())
	if it.get_bonus_attack_speed() > 0: parts.append("🎯 +%.0f%% Tốc" % (it.get_bonus_attack_speed() * 100))
	if it.get_crit_chance() > 0: parts.append("💥 +%.0f%% CM" % (it.get_crit_chance() * 100))
	if it.get_bonus_omnivamp() > 0: parts.append("🩸 +%.0f%% Hút" % (it.get_bonus_omnivamp() * 100))
	if it.get_starting_energy() > 0: parts.append("⚡ +%.0f NL" % it.get_starting_energy())
	return " | ".join(parts)

# ==============================================================================
# HÀNH ĐỘNG & ĐIỀU HƯỚNG
# ==============================================================================
func _on_option_chosen(target_slot: int, crafted_mythic: ItemData) -> void:
	if not is_open:
		return
	is_open = false
	hide()
	option_selected.emit(current_hero, target_slot, crafted_mythic, source_bench_slot)

func _on_separate_pressed() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	equip_separate_selected.emit(current_hero, incoming_item, source_bench_slot)

func select_option(choice_idx: int) -> void:
	if choice_idx >= 0 and choice_idx < target_slot_indices.size() and choice_idx < mythic_options.size():
		_on_option_chosen(target_slot_indices[choice_idx], mythic_options[choice_idx])

func select_separate() -> void:
	_on_separate_pressed()

func cancel_and_close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	modal_cancelled.emit(source_bench_slot)

# ==============================================================================
# KHÓA HOTKEYS TRÁNH BẤM NHẦM KHI ĐANG MỞ MODAL
# ==============================================================================
func _input(event: InputEvent) -> void:
	if is_open and visible:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			if event.keycode == KEY_ESCAPE:
				cancel_and_close()
				get_viewport().set_input_as_handled()
				return
			# Khóa triệt để các phím Space, Enter, v.v... không kích hoạt chuyển pha
			get_viewport().set_input_as_handled()
