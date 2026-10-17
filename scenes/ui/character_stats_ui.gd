class_name CharacterStatsUI
extends CanvasLayer

# ==============================================================================
# CHARACTER STATS PANEL UI (SPRINT 3 - TASK S3.4.2: TFT-STYLE RIGHT-DOCK PANEL)
# Bảng hiển thị thông tin & chỉ số chi tiết Tướng đặt cạnh phải màn hình chuẩn TFT
# ==============================================================================

signal hero_inspected(hero: HeroEntity)
signal panel_closed

# ------------------------------------------------------------------------------
# INNER CLASS: KHUNG KỸ NĂNG HÌNH LỤC GIÁC POINTY-TOP (VẼ BẰNG CODE)
# ------------------------------------------------------------------------------
class HexSkillIcon extends Control:
	var ability_name: String = ""
	var ability_type_str: String = ""
	var description_bbcode: String = ""
	var border_color: Color = Color(0.5, 0.6, 0.7)
	var border_width: float = 2.0
	
	func _init(p_name: String, p_type: String, p_border: Color, p_desc: String = "") -> void:
		ability_name = p_name
		ability_type_str = p_type
		border_color = p_border
		description_bbcode = p_desc
		custom_minimum_size = Vector2(46, 52)
		size = Vector2(46, 52)
		mouse_filter = Control.MOUSE_FILTER_PASS
		if description_bbcode != "":
			tooltip_text = "[b]%s[/b] [%s]\n%s" % [ability_name, ability_type_str, description_bbcode]
		else:
			tooltip_text = "[b]%s[/b] [%s]" % [ability_name, ability_type_str]

	func _make_custom_tooltip(for_text: String) -> Object:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.12, 0.16, 0.98)
		style.border_color = border_color
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", style)
		
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.text = for_text
		rtl.fit_content = true
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.custom_minimum_size = Vector2(220, 0)
		panel.add_child(rtl)
		return panel

	func _draw() -> void:
		var center := size * 0.5
		var radius: float = min(center.x, center.y) - 2.0
		var points: PackedVector2Array = []
		# Pointy-Top Hexagon: 6 đỉnh lệch 30 độ
		for i in range(6):
			var angle_rad := deg_to_rad(60.0 * i - 30.0)
			points.append(center + Vector2(cos(angle_rad), sin(angle_rad)) * radius)
		
		# 1. Nền lục giác sẫm màu
		draw_colored_polygon(points, Color(0.11, 0.13, 0.18, 0.95))
		
		# 2. Viền lục giác theo màu phẩm cấp chiêu thức
		var loop_points := points.duplicate()
		loop_points.append(points[0])
		draw_polyline(loop_points, border_color, border_width, true)
		
		# 3. Ký tự viết tắt của kỹ năng ở tâm lục giác
		var display_char: String = ability_name.left(1).to_upper() if ability_name != "" else "?"
		var font := ThemeDB.fallback_font
		var font_size: int = 14
		var string_size := font.get_string_size(display_char, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := center + Vector2(-string_size.x * 0.5, string_size.y * 0.3)
		draw_string(font, text_pos, display_char, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, border_color)

# ------------------------------------------------------------------------------
# PANEL MAIN NODES
# ------------------------------------------------------------------------------
var panel_container: PanelContainer
var main_vbox: VBoxContainer

# 1. Top Avatar & Info Banner
var avatar_panel: PanelContainer
var avatar_bg_style: StyleBoxFlat
var avatar_initial_label: Label
var name_label: Label
var class_label: Label
var level_label: Label
var close_button: Button

# 2. Survival & Progression Bars
var hp_label: Label
var hp_bar: ProgressBar
var energy_label: Label
var energy_bar: ProgressBar
var xp_label: Label
var xp_bar: ProgressBar

# 3. Hexagonal Skills Section
var skills_container: HBoxContainer

# 4. Core Stats Grid (4 columns x 2 rows)
var attack_val_label: Label
var spell_val_label: Label
var def_val_label: Label
var range_val_label: Label
var speed_val_label: Label
var crit_val_label: Label
var crit_dmg_val_label: Label
var start_energy_val_label: Label

# Inspected Target State
var inspected_hero: HeroEntity = null
var _on_hp_changed_callable: Callable
var _on_energy_changed_callable: Callable
var _on_died_callable: Callable
var _on_exiting_callable: Callable

func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()

func _build_ui() -> void:
	# Bảng neo cạnh phải: x = 856, y = 40, width = 280, height = 560
	panel_container = PanelContainer.new()
	panel_container.name = "StatsPanelRight"
	panel_container.custom_minimum_size = Vector2(280, 560)
	panel_container.size = Vector2(280, 560)
	panel_container.position = Vector2(856, 40)
	panel_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.96)
	panel_style.border_color = Color(0.24, 0.28, 0.38, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 12
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	panel_style.shadow_size = 8
	panel_container.add_theme_stylebox_override("panel", panel_style)
	add_child(panel_container)
	
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel_container.add_child(main_vbox)
	
	# ==========================================================================
	# 1. TOP AVATAR BANNER
	# ==========================================================================
	avatar_panel = PanelContainer.new()
	avatar_panel.custom_minimum_size = Vector2(260, 105)
	avatar_bg_style = StyleBoxFlat.new()
	avatar_bg_style.bg_color = Color(0.18, 0.24, 0.36)
	avatar_bg_style.set_corner_radius_all(8)
	avatar_bg_style.content_margin_left = 8
	avatar_bg_style.content_margin_right = 8
	avatar_bg_style.content_margin_top = 6
	avatar_bg_style.content_margin_bottom = 6
	avatar_panel.add_theme_stylebox_override("panel", avatar_bg_style)
	main_vbox.add_child(avatar_panel)
	
	var banner_control := Control.new()
	banner_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_panel.add_child(banner_control)
	
	# Badge Cấp độ (Góc trên trái)
	level_label = Label.new()
	level_label.text = "Cấp 1"
	level_label.position = Vector2(4, 2)
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	banner_control.add_child(level_label)
	
	# Nút đóng "✕" (Góc trên phải)
	close_button = Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(22, 22)
	close_button.size = Vector2(22, 22)
	close_button.position = Vector2(218, 2)
	close_button.focus_mode = Control.FOCUS_NONE
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.25, 0.28, 0.35, 0.8)
	close_style.set_corner_radius_all(4)
	close_button.add_theme_stylebox_override("normal", close_style)
	close_button.pressed.connect(close)
	banner_control.add_child(close_button)
	
	# Icon Avatar Placeholder ở giữa banner
	avatar_initial_label = Label.new()
	avatar_initial_label.text = "⚔️"
	avatar_initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_initial_label.size = Vector2(50, 50)
	avatar_initial_label.position = Vector2(97, 8)
	avatar_initial_label.add_theme_font_size_override("font_size", 28)
	banner_control.add_child(avatar_initial_label)
	
	# Tên Tướng (Góc dưới trái banner)
	name_label = Label.new()
	name_label.text = "Hero Name"
	name_label.position = Vector2(4, 60)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	banner_control.add_child(name_label)
	
	# Class / Hệ Tộc (Góc dưới trái banner, dưới tên)
	class_label = Label.new()
	class_label.text = "[TANK]"
	class_label.position = Vector2(4, 80)
	class_label.add_theme_font_size_override("font_size", 11)
	class_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	banner_control.add_child(class_label)
	
	# ==========================================================================
	# 2. KHỐI SINH TỒN & TIẾN TRÌNH (HP, ENERGY, XP)
	# ==========================================================================
	var survival_box := VBoxContainer.new()
	survival_box.add_theme_constant_override("separation", 3)
	main_vbox.add_child(survival_box)
	
	# Thanh HP
	hp_label = Label.new()
	hp_label.text = "HP: 100 / 100"
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	survival_box.add_child(hp_label)
	
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 11)
	hp_bar.show_percentage = false
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.22, 0.75, 0.38)
	hp_fill.set_corner_radius_all(4)
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.22, 0.12, 0.12)
	hp_bg.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	survival_box.add_child(hp_bar)
	
	# Thanh Năng lượng
	energy_label = Label.new()
	energy_label.text = "Năng lượng: 0 / 100"
	energy_label.add_theme_font_size_override("font_size", 11)
	energy_label.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))
	survival_box.add_child(energy_label)
	
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(0, 9)
	energy_bar.show_percentage = false
	var en_fill := StyleBoxFlat.new()
	en_fill.bg_color = Color(0.2, 0.6, 0.95)
	en_fill.set_corner_radius_all(4)
	var en_bg := StyleBoxFlat.new()
	en_bg.bg_color = Color(0.12, 0.16, 0.25)
	en_bg.set_corner_radius_all(4)
	energy_bar.add_theme_stylebox_override("fill", en_fill)
	energy_bar.add_theme_stylebox_override("background", en_bg)
	survival_box.add_child(energy_bar)
	
	# Thanh XP
	var xp_box := HBoxContainer.new()
	xp_label = Label.new()
	xp_label.text = "XP: 0 / 100"
	xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_label.add_theme_font_size_override("font_size", 10)
	xp_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	xp_box.add_child(xp_label)
	survival_box.add_child(xp_box)
	
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 5)
	xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.95, 0.75, 0.2)
	xp_fill.set_corner_radius_all(2)
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.18, 0.20, 0.26)
	xp_bg.set_corner_radius_all(2)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	survival_box.add_child(xp_bar)
	
	main_vbox.add_child(_create_separator())
	
	# ==========================================================================
	# 3. KHỐI KỸ NĂNG HÌNH LỤC GIÁC (HEXAGON SKILLS)
	# ==========================================================================
	var skills_title := Label.new()
	skills_title.text = "KỸ NĂNG & THỨC TỈNH"
	skills_title.add_theme_font_size_override("font_size", 11)
	skills_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	main_vbox.add_child(skills_title)
	
	skills_container = HBoxContainer.new()
	skills_container.alignment = BoxContainer.ALIGNMENT_CENTER
	skills_container.add_theme_constant_override("separation", 8)
	skills_container.custom_minimum_size = Vector2(0, 56)
	main_vbox.add_child(skills_container)
	
	main_vbox.add_child(_create_separator())
	
	# ==========================================================================
	# 4. KHỐI CHỈ SỐ CỐT LÕI (GRID 4 CỘT X 2 HÀNG)
	# ==========================================================================
	var stats_title := Label.new()
	stats_title.text = "CHỈ SỐ CHI TIẾT"
	stats_title.add_theme_font_size_override("font_size", 11)
	stats_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	main_vbox.add_child(stats_title)
	
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	
	# Hàng 1: SMCK, SMPT, Giáp, Tầm đánh
	attack_val_label = _create_stat_cell(grid, "⚔️", "SMCK")
	spell_val_label = _create_stat_cell(grid, "🔮", "SMPT")
	def_val_label = _create_stat_cell(grid, "🛡️", "Giáp")
	range_val_label = _create_stat_cell(grid, "🏹", "Tầm")
	
	# Hàng 2: Tốc đánh, Chí mạng, STCM, Năng lượng đầu
	speed_val_label = _create_stat_cell(grid, "⚡", "Tốc")
	crit_val_label = _create_stat_cell(grid, "🎯", "CM")
	crit_dmg_val_label = _create_stat_cell(grid, "💥", "STCM")
	start_energy_val_label = _create_stat_cell(grid, "🧪", "Khởi")
	
	main_vbox.add_child(grid)

func _create_stat_cell(parent: GridContainer, icon: String, stat_name: String) -> Label:
	var cell_panel := PanelContainer.new()
	cell_panel.custom_minimum_size = Vector2(58, 48)
	cell_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = Color(0.13, 0.16, 0.22, 0.85)
	cell_style.set_corner_radius_all(6)
	cell_style.content_margin_top = 4
	cell_style.content_margin_bottom = 4
	cell_panel.add_theme_stylebox_override("panel", cell_style)
	parent.add_child(cell_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	cell_panel.add_child(vbox)
	
	var header_lbl := Label.new()
	header_lbl.text = "%s %s" % [icon, stat_name]
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_size_override("font_size", 9)
	header_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	vbox.add_child(header_lbl)
	
	var val_lbl := Label.new()
	val_lbl.text = "0"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(val_lbl)
	
	return val_lbl

func _create_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.22, 0.26, 0.34, 0.7)
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep

# ==============================================================================
# PUBLIC API: INSPECTION & REACTIVITY
# ==============================================================================

func inspect_hero(hero: HeroEntity) -> void:
	if hero == null or not is_instance_valid(hero):
		close()
		return
		
	_disconnect_inspected_hero()
	
	inspected_hero = hero
	_connect_inspected_hero()
	
	update_stats()
	show()
	hero_inspected.emit(hero)

func close() -> void:
	_disconnect_inspected_hero()
	inspected_hero = null
	hide()
	panel_closed.emit()

func update_stats() -> void:
	if inspected_hero == null or not is_instance_valid(inspected_hero):
		close()
		return
		
	var data: HeroData = inspected_hero.data
	name_label.text = data.name if data != null else inspected_hero.name
	
	# Class Banner Styling
	var class_str := "TƯỚNG"
	if data != null:
		class_str = HeroData.HeroClass.keys()[data.hero_class]
		match data.hero_class:
			HeroData.HeroClass.TANK:
				avatar_bg_style.bg_color = Color(0.18, 0.28, 0.45)
				avatar_initial_label.text = "🛡️"
			HeroData.HeroClass.ASSASSIN:
				avatar_bg_style.bg_color = Color(0.38, 0.16, 0.42)
				avatar_initial_label.text = "🗡️"
			HeroData.HeroClass.MAGE:
				avatar_bg_style.bg_color = Color(0.20, 0.32, 0.55)
				avatar_initial_label.text = "🔮"
			HeroData.HeroClass.MARKSMAN:
				avatar_bg_style.bg_color = Color(0.18, 0.38, 0.28)
				avatar_initial_label.text = "🏹"
			HeroData.HeroClass.SUPPORT:
				avatar_bg_style.bg_color = Color(0.14, 0.38, 0.38)
				avatar_initial_label.text = "💚"
			_:
				avatar_bg_style.bg_color = Color(0.35, 0.25, 0.18)
				avatar_initial_label.text = "⚔️"
	class_label.text = "[%s]" % class_str
	
	# Progression & Level
	var current_lvl: int = 1
	var cur_xp: float = 0.0
	var req_xp: float = 100.0
	if inspected_hero.progression != null:
		current_lvl = inspected_hero.progression.current_level
		cur_xp = inspected_hero.progression.current_xp
		req_xp = inspected_hero.progression.required_xp
	level_label.text = "Cấp %d" % current_lvl
	xp_label.text = "XP: %.0f / %.0f" % [cur_xp, req_xp]
	xp_bar.max_value = req_xp
	xp_bar.value = cur_xp
	
	# HP & Energy
	hp_label.text = "HP: %.0f / %.0f" % [inspected_hero.current_hp, inspected_hero.max_hp]
	hp_bar.max_value = inspected_hero.max_hp
	hp_bar.value = inspected_hero.current_hp
	
	energy_label.text = "Năng lượng: %.0f / %.0f" % [inspected_hero.current_energy, inspected_hero.max_energy]
	energy_bar.max_value = inspected_hero.max_energy
	energy_bar.value = inspected_hero.current_energy
	
	# 4x2 Grid Core Stats
	var atk: float = inspected_hero.get_attack()
	var spell_pow: float = inspected_hero.get_spell_power()
	var def: float = inspected_hero.get_defense()
	var atk_rng: int = inspected_hero.get_attack_range()
	var spd: float = inspected_hero.get_attack_speed()
	var crit_c: float = inspected_hero.get_crit_chance() * 100.0
	var crit_d: float = inspected_hero.get_crit_damage() * 100.0
	var start_en: float = data.starting_energy if (data != null and "starting_energy" in data) else 0.0
	
	attack_val_label.text = "%.1f" % atk
	spell_val_label.text = "%.1f" % spell_pow
	def_val_label.text = "%.1f" % def
	range_val_label.text = "%d ô" % atk_rng
	speed_val_label.text = "%.2f/s" % spd
	crit_val_label.text = "%.0f%%" % crit_c
	crit_dmg_val_label.text = "%.0f%%" % crit_d
	start_energy_val_label.text = "%.0f" % start_en
	
	# Hexagonal Skills Section
	for child in skills_container.get_children():
		child.queue_free()
		
	var skills_found: int = 0
	if inspected_hero.basic_attack_ability != null and inspected_hero.basic_attack_ability.data != null:
		var basic_desc: String = inspected_hero.basic_attack_ability.data.get_formatted_tooltip(inspected_hero)
		var basic_icon := HexSkillIcon.new(inspected_hero.basic_attack_ability.data.name, "Đánh thường", Color(0.65, 0.70, 0.80), basic_desc)
		skills_container.add_child(basic_icon)
		skills_found += 1
		
	for runtime_ab in inspected_hero.unlocked_abilities:
		if is_instance_valid(runtime_ab) and runtime_ab.data != null:
			var type_name: String = str(AbilityData.AbilityType.keys()[runtime_ab.data.ability_type])
			var border_col := Color(0.35, 0.75, 1.0)
			if runtime_ab.data.ability_type == AbilityData.AbilityType.ULTIMATE:
				border_col = Color(1.0, 0.85, 0.2)
			elif runtime_ab.data.ability_type == AbilityData.AbilityType.PASSIVE:
				border_col = Color(0.4, 0.9, 0.4)
			var skill_desc: String = runtime_ab.data.get_formatted_tooltip(inspected_hero)
			var skill_icon := HexSkillIcon.new(runtime_ab.data.name, type_name, border_col, skill_desc)
			skills_container.add_child(skill_icon)
			skills_found += 1
			
	if skills_found == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "(Chưa mở khóa kỹ năng)"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		skills_container.add_child(empty_lbl)

func _connect_inspected_hero() -> void:
	if inspected_hero == null: return
	_on_hp_changed_callable = func(_c, _m): update_stats()
	_on_energy_changed_callable = func(_c, _m): update_stats()
	_on_died_callable = func(_e): close()
	_on_exiting_callable = func(): close()
	
	inspected_hero.hp_changed.connect(_on_hp_changed_callable)
	inspected_hero.energy_changed.connect(_on_energy_changed_callable)
	inspected_hero.died.connect(_on_died_callable)
	inspected_hero.tree_exiting.connect(_on_exiting_callable)

func _disconnect_inspected_hero() -> void:
	if inspected_hero != null and is_instance_valid(inspected_hero):
		if _on_hp_changed_callable.is_valid() and inspected_hero.hp_changed.is_connected(_on_hp_changed_callable):
			inspected_hero.hp_changed.disconnect(_on_hp_changed_callable)
		if _on_energy_changed_callable.is_valid() and inspected_hero.energy_changed.is_connected(_on_energy_changed_callable):
			inspected_hero.energy_changed.disconnect(_on_energy_changed_callable)
		if _on_died_callable.is_valid() and inspected_hero.died.is_connected(_on_died_callable):
			inspected_hero.died.disconnect(_on_died_callable)
		if _on_exiting_callable.is_valid() and inspected_hero.tree_exiting.is_connected(_on_exiting_callable):
			inspected_hero.tree_exiting.disconnect(_on_exiting_callable)
