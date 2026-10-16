class_name SkillChoiceUI
extends CanvasLayer

signal skill_chosen(chosen: AbilityData, all_choices: Array[AbilityData])

var _selection_locked: bool = false
var current_choices: Array[AbilityData] = []

var dim_bg: ColorRect
var center_container: CenterContainer
var main_vbox: VBoxContainer
var title_label: Label
var cards_container: HBoxContainer

func _init() -> void:
	# Bẫy 1: PROCESS_MODE_ALWAYS để mọi Tween & Input hoạt động bình thường khi Tree paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	# Lớp nền đen mờ bao phủ toàn màn hình, chặn click xuyên xuống chiến trường
	dim_bg = ColorRect.new()
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.72)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim_bg)
	
	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_container)
	
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 28)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_container.add_child(main_vbox)
	
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(title_label)
	
	cards_container = HBoxContainer.new()
	cards_container.add_theme_constant_override("separation", 24)
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(cards_container)
	
	hide()

func show_choices(hero_name: String, milestone: int, choices: Array) -> void:
	# Bẫy 4: Mở khóa chọn cho lần mở UI mới
	_selection_locked = false
	current_choices.clear()
	for c in choices:
		if c is AbilityData:
			current_choices.append(c as AbilityData)
	
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
		
	title_label.text = "=== %s REACHED LEVEL %d ===\nCHOOSE 1 ABILITY" % [hero_name.to_upper(), milestone]
	
	for i in range(current_choices.size()):
		var ability: AbilityData = current_choices[i]
		var card: Control = _create_card(ability, i)
		cards_container.add_child(card)
		
	show()
	get_tree().paused = true # Tạm dừng thời gian trong trận đấu

func _create_card(ability: AbilityData, index: int) -> Control:
	var type_color := _get_type_color(ability.ability_type)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 320)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Bẫy 2: Cài đặt tâm xoay/phóng về giữa thẻ bài
	card.pivot_offset = Vector2(120, 160)
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5)
	
	# StyleBoxFlat cho card
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.16, 0.96)
	style.border_color = type_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	card.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# 1. Type Badge
	var badge := Label.new()
	var type_str: String = AbilityData.AbilityType.keys()[ability.ability_type]
	badge.text = "[ %s ]" % type_str
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", type_color)
	badge.add_theme_font_size_override("font_size", 13)
	vbox.add_child(badge)
	
	# 2. Skill Name
	var name_lbl := Label.new()
	name_lbl.text = ability.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_lbl)
	
	# 3. Separator
	var hsep := HSeparator.new()
	vbox.add_child(hsep)
	
	# 4. Stats / Spec Row
	var stats_lbl := Label.new()
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	if ability.ability_type == AbilityData.AbilityType.PASSIVE:
		var cond_name: String = AbilityData.TriggerCondition.keys()[ability.trigger_condition]
		stats_lbl.text = "Trigger: " + cond_name
	elif ability.ability_type == AbilityData.AbilityType.ULTIMATE:
		stats_lbl.text = "Cost: 100% Energy"
	else:
		stats_lbl.text = "CD: %.1fs  |  Cost: %.0f MP" % [ability.cooldown, ability.energy_cost]
		
	vbox.add_child(stats_lbl)
	
	# 5. Dynamic Description (Bẫy 5: Fallback an toàn)
	var desc_lbl := Label.new()
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_lbl.text = _build_card_description(ability)
	vbox.add_child(desc_lbl)
	
	# 6. Action prompt
	var action_lbl := Label.new()
	action_lbl.text = "[ CHỌN KỸ NĂNG ]"
	action_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_lbl.add_theme_font_size_override("font_size", 13)
	action_lbl.add_theme_color_override("font_color", type_color)
	vbox.add_child(action_lbl)
	
	# Bẫy 3: Ép tất cả node con trong thẻ bài có mouse_filter = IGNORE để chống giật nháy chuột
	_ensure_mouse_filter_ignore(margin)
	
	# Pop-in Staggered Animation
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var in_tween := _start_card_tween(card)
	in_tween.tween_interval(index * 0.06)
	in_tween.tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	in_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.15)
	
	# Hover & Click Signals
	card.mouse_entered.connect(func(): _on_card_hover_enter(card, type_color))
	card.mouse_exited.connect(func(): _on_card_hover_exit(card, type_color))
	card.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, ability, card))
	
	return card

func _kill_card_tween(card: Control) -> void:
	if card.has_meta("card_tween"):
		var t = card.get_meta("card_tween") as Tween
		if t != null and t.is_running():
			t.kill()
		card.remove_meta("card_tween")

func _start_card_tween(card: Control) -> Tween:
	_kill_card_tween(card)
	var t := card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	card.set_meta("card_tween", t)
	return t

func _on_card_hover_enter(card: PanelContainer, _type_color: Color) -> void:
	if _selection_locked: return
	card.pivot_offset = card.size * 0.5
	var tween := _start_card_tween(card)
	tween.tween_property(card, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var style: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3

func _on_card_hover_exit(card: PanelContainer, _type_color: Color) -> void:
	if _selection_locked: return
	card.pivot_offset = card.size * 0.5
	var tween := _start_card_tween(card)
	tween.tween_property(card, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var style: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2

func _on_card_gui_input(event: InputEvent, ability: AbilityData, card: PanelContainer) -> void:
	if _selection_locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_selection_locked = true # Khóa ngay lập tức chống double click
		card.pivot_offset = card.size * 0.5
		var select_tween := _start_card_tween(card)
		select_tween.tween_property(card, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_QUAD)
		select_tween.tween_property(card, "scale", Vector2(0.95, 0.95), 0.08).set_trans(Tween.TRANS_QUAD)
		select_tween.tween_callback(func():
			hide()
			get_tree().paused = false
			skill_chosen.emit(ability, current_choices)
		)

func _get_type_color(type: AbilityData.AbilityType) -> Color:
	match type:
		AbilityData.AbilityType.PASSIVE:
			return Color("2ecc71") # Xanh lục
		AbilityData.AbilityType.ACTIVE:
			return Color("3498db") # Xanh lam
		AbilityData.AbilityType.ULTIMATE:
			return Color("f39c12") # Vàng cam
		_:
			return Color.WHITE

func _build_card_description(ability: AbilityData) -> String:
	if ability == null:
		return "Kỹ năng đặc biệt hỗ trợ chiến đấu."
	if not ability.description.is_empty():
		return ability.description
	if ability.effects.is_empty():
		return "Kỹ năng đặc biệt hỗ trợ chiến đấu."
	
	var lines: Array[String] = []
	for effect in ability.effects:
		if effect is DamageEffectData:
			var dmg = effect as DamageEffectData
			var type_name: String = "PHYSICAL"
			if dmg.damage_type >= 0 and dmg.damage_type < DamageEvent.DamageType.size():
				type_name = DamageEvent.DamageType.keys()[dmg.damage_type]
			lines.append("Gây %.0f sát thương %s." % [dmg.base_damage, type_name])
		elif effect is HealEffectData:
			var heal = effect as HealEffectData
			lines.append("Hồi %.0f Máu cho mục tiêu." % heal.heal_amount)
	
	if lines.is_empty():
		return "Kỹ năng đặc biệt hỗ trợ chiến đấu."
	return "\n".join(lines)

func _ensure_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ensure_mouse_filter_ignore(child)
