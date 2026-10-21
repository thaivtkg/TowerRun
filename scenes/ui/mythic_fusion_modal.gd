class_name MythicFusionModal
extends CanvasLayer

# ==============================================================================
# SPRINT 6 - TASK S6.6: BẢNG CHỌN HỢP THỂ THẦN THOẠI BẬC 3
# Interactive Mythic Fusion Choice Modal
# ==============================================================================

signal option_selected(hero: HeroEntity, slot_idx: int, crafted_mythic: ItemData, source_bench_slot: int)
signal equip_separate_selected(hero: HeroEntity, item: ItemData, source_bench_slot: int)
signal modal_cancelled(source_bench_slot: int)

var current_hero: HeroEntity = null
var incoming_item: ItemData = null
var source_bench_slot: int = -1
var tier2_indices: Array[int] = []

var panel_container: PanelContainer = null
var options_container: HBoxContainer = null
var option_buttons: Array[Button] = []
var separate_button: Button = null
var cancel_button: Button = null

func _init() -> void:
	layer = 60

func setup(hero: HeroEntity, item: ItemData, src_slot: int, indices: Array[int]) -> void:
	current_hero = hero
	incoming_item = item
	source_bench_slot = src_slot
	tier2_indices = indices
	_build_ui()

func _build_ui() -> void:
	# 1. Dimmed Backdrop khóa click xuyên thấu
	var backdrop := ColorRect.new()
	backdrop.name = "DimBackdrop"
	backdrop.color = Color(0.02, 0.04, 0.08, 0.8)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# 2. CenterContainer định vị giữa màn hình
	var center := CenterContainer.new()
	center.name = "Center"
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# 3. Khung trung tâm Monolithic Dark Fantasy Card
	panel_container = PanelContainer.new()
	panel_container.name = "MainPanel"
	panel_container.custom_minimum_size = Vector2(620, 360)
	panel_container.mouse_filter = Control.MOUSE_FILTER_STOP

	var style_panel := StyleBoxFlat.new()
	style_panel.bg_color = Color("#0b0f19")
	style_panel.set_corner_radius_all(12)
	style_panel.border_width_left = 2
	style_panel.border_width_top = 2
	style_panel.border_width_right = 2
	style_panel.border_width_bottom = 2
	style_panel.border_color = Color("#e879f9") # Tím Thần Thoại
	style_panel.shadow_color = Color(0, 0, 0, 0.85)
	style_panel.shadow_size = 18
	style_panel.shadow_offset = Vector2(0, 8)
	style_panel.content_margin_left = 20.0
	style_panel.content_margin_top = 16.0
	style_panel.content_margin_right = 20.0
	style_panel.content_margin_bottom = 16.0
	panel_container.add_theme_stylebox_override("panel", style_panel)
	center.add_child(panel_container)

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 14)
	panel_container.add_child(main_vbox)

	# Tiêu đề Thần Thoại
	var title_lbl := RichTextLabel.new()
	title_lbl.name = "Title"
	title_lbl.bbcode_enabled = true
	title_lbl.fit_content = true
	title_lbl.scroll_active = false
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.text = "[center][wave amp=15 freq=3][color=#fbbf24]🔥 THĂNG HOA BẬC 3: CHỌN HƯỚNG HỢP THỂ[/color][/wave][/center]"
	title_lbl.add_theme_font_size_override("normal_font_size", 16)
	main_vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "Chọn 1 trong các hướng hợp thể sức mạnh tối thượng cho %s" % (current_hero.name if current_hero != null else "Tướng")
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_size_override("font_size", 11)
	subtitle_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	main_vbox.add_child(subtitle_lbl)

	# 4. Dải Thẻ Lựa Chọn (HBoxContainer)
	options_container = HBoxContainer.new()
	options_container.name = "OptionsContainer"
	options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	options_container.add_theme_constant_override("separation", 16)
	main_vbox.add_child(options_container)

	option_buttons.clear()
	for slot_idx in tier2_indices:
		if current_hero == null or slot_idx >= current_hero.equipped_items.size():
			continue
		var existing: ItemData = current_hero.equipped_items[slot_idx]
		if existing == null:
			continue
		var mythic: ItemData = null
		if ItemManager != null:
			mythic = ItemManager.get_mythic_fusion(existing, incoming_item)
		if mythic == null:
			continue

		var card := _create_choice_card(slot_idx, existing, incoming_item, mythic)
		options_container.add_child(card)

	# 5. Thanh Điều Hướng Phía Dưới
	var nav_hbox := HBoxContainer.new()
	nav_hbox.name = "NavHBox"
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(nav_hbox)

	if current_hero != null and current_hero.equipped_items.size() < 3:
		separate_button = Button.new()
		separate_button.name = "SeparateButton"
		separate_button.text = "🎒 Lắp Riêng Rẽ (Thành 3 Món)"
		separate_button.custom_minimum_size = Vector2(210, 36)
		separate_button.focus_mode = Control.FOCUS_NONE
		separate_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var style_sep := StyleBoxFlat.new()
		style_sep.bg_color = Color("#1e293b")
		style_sep.set_corner_radius_all(6)
		style_sep.border_width_left = 1
		style_sep.border_width_top = 1
		style_sep.border_width_right = 1
		style_sep.border_width_bottom = 1
		style_sep.border_color = Color("#475569")
		separate_button.add_theme_stylebox_override("normal", style_sep)
		separate_button.add_theme_stylebox_override("hover", style_sep)
		separate_button.add_theme_font_size_override("font_size", 12)
		separate_button.pressed.connect(_on_equip_separate_pressed)
		nav_hbox.add_child(separate_button)

	cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "❌ Hủy Bỏ (Hoàn Trả Kho Đồ)"
	cancel_button.custom_minimum_size = Vector2(180, 36)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style_cancel := StyleBoxFlat.new()
	style_cancel.bg_color = Color("#1e1e2e")
	style_cancel.set_corner_radius_all(6)
	style_cancel.border_width_left = 1
	style_cancel.border_width_top = 1
	style_cancel.border_width_right = 1
	style_cancel.border_width_bottom = 1
	style_cancel.border_color = Color("#ef4444")
	cancel_button.add_theme_stylebox_override("normal", style_cancel)
	cancel_button.add_theme_stylebox_override("hover", style_cancel)
	cancel_button.add_theme_font_size_override("font_size", 12)
	cancel_button.pressed.connect(cancel_and_close)
	nav_hbox.add_child(cancel_button)

func _create_choice_card(slot_idx: int, existing: ItemData, incoming: ItemData, mythic: ItemData) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ChoiceCard_Slot%d" % slot_idx
	card.custom_minimum_size = Vector2(210, 230)

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f172a")
	style.set_corner_radius_all(8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("#f59e0b")
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	# Công thức
	var recipe_lbl := Label.new()
	recipe_lbl.text = "[%s] + [%s]" % [existing.name, incoming.name]
	recipe_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_lbl.add_theme_font_size_override("font_size", 10)
	recipe_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	vbox.add_child(recipe_lbl)

	# Biểu tượng Thần Thoại
	var icon_lbl := Label.new()
	icon_lbl.text = "👑"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 28)
	vbox.add_child(icon_lbl)

	# Tên Thần Thoại
	var name_lbl := Label.new()
	name_lbl.text = mythic.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color("#fb7185"))
	vbox.add_child(name_lbl)

	# Chỉ số tổng hợp
	var stats_lbl := Label.new()
	stats_lbl.text = _format_stats_summary(mythic)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(stats_lbl)

	# Nội tại 2 tầng
	if mythic.sub_passive_name != "":
		var sub_p := Label.new()
		sub_p.text = "⚡ %s" % mythic.sub_passive_name
		sub_p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_p.add_theme_font_size_override("font_size", 9)
		sub_p.add_theme_color_override("font_color", Color("#38bdf8"))
		vbox.add_child(sub_p)

	if mythic.mythic_passive_name != "":
		var myth_p := Label.new()
		myth_p.text = "🔥 %s" % mythic.mythic_passive_name
		myth_p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		myth_p.add_theme_font_size_override("font_size", 9)
		myth_p.add_theme_color_override("font_color", Color("#fbbf24"))
		vbox.add_child(myth_p)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Nút Hợp Thể
	var btn := Button.new()
	btn.name = "FuseBtn_Slot%d" % slot_idx
	btn.text = "🔥 HỢP THỂ MÓN NÀY"
	btn.custom_minimum_size = Vector2(0, 32)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#0369a1")
	btn_style.set_corner_radius_all(6)
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color("#38bdf8")
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_style)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func(): _on_option_chosen(slot_idx, mythic))
	vbox.add_child(btn)
	option_buttons.append(btn)

	return card

func _format_stats_summary(item: ItemData) -> String:
	var lines: Array[String] = []
	if item.bonus_ad > 0: lines.append("⚔️ +%.0f SMCK" % item.bonus_ad)
	if item.bonus_ap > 0: lines.append("🔮 +%.0f SMPT" % item.bonus_ap)
	if item.bonus_armor > 0: lines.append("🛡️ +%.0f Giáp" % item.bonus_armor)
	if item.bonus_hp > 0: lines.append("🏰 +%.0f HP" % item.bonus_hp)
	if item.starting_energy > 0: lines.append("⚡ +%.0f Năng Lượng" % item.starting_energy)
	if item.crit_chance > 0: lines.append("🎯 +%.0f%% Chí Mạng" % (item.crit_chance * 100.0))
	if item.bonus_omnivamp > 0: lines.append("🩸 +%.0f%% Hút Máu" % (item.bonus_omnivamp * 100.0))
	if item.bonus_attack_speed > 0: lines.append("🏹 +%.0f%% Tốc Đánh" % (item.bonus_attack_speed * 100.0))
	if lines.is_empty():
		return "Chỉ số toàn diện tăng cao"
	return " | ".join(lines.slice(0, 3))

func _on_option_chosen(slot_idx: int, mythic: ItemData) -> void:
	option_selected.emit(current_hero, slot_idx, mythic, source_bench_slot)
	hide()
	queue_free()

func _on_equip_separate_pressed() -> void:
	equip_separate_selected.emit(current_hero, incoming_item, source_bench_slot)
	hide()
	queue_free()

func cancel_and_close() -> void:
	modal_cancelled.emit(source_bench_slot)
	hide()
	queue_free()

func _input(event: InputEvent) -> void:
	if visible and not is_queued_for_deletion():
		if event is InputEventKey:
			if event.pressed and event.keycode == KEY_ESCAPE:
				cancel_and_close()
			get_viewport().set_input_as_handled()
