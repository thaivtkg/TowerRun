class_name CharacterStatsUI
extends CanvasLayer

# ==========================================
# CHARACTER STATS PANEL UI (SPRINT 3 - TASK S3.4)
# Bảng hiển thị thông tin & chỉ số chi tiết Tướng (Inspect Panel)
# ==========================================

signal hero_inspected(hero: HeroEntity)
signal panel_closed

var panel_container: PanelContainer
var main_vbox: VBoxContainer

# Header elements
var name_label: Label
var class_label: Label
var level_label: Label
var close_button: Button

# Bars
var hp_label: Label
var hp_bar: ProgressBar
var energy_label: Label
var energy_bar: ProgressBar
var xp_label: Label
var xp_bar: ProgressBar

# Stat Grid labels
var attack_val_label: Label
var spell_val_label: Label
var def_val_label: Label
var speed_val_label: Label
var crit_val_label: Label
var crit_dmg_val_label: Label
var range_val_label: Label

# Abilities Container
var abilities_title: Label
var abilities_vbox: VBoxContainer

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
	panel_container = PanelContainer.new()
	panel_container.name = "StatsPanel"
	panel_container.custom_minimum_size = Vector2(250, 480)
	panel_container.size = Vector2(250, 500)
	panel_container.position = Vector2(16, 60)
	panel_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.12, 0.16, 0.94)
	panel_style.border_color = Color(0.25, 0.30, 0.40, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 12
	panel_container.add_theme_stylebox_override("panel", panel_style)
	add_child(panel_container)
	
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	panel_container.add_child(main_vbox)
	
	# 1. Top Bar: Name & Close Button
	var top_bar := HBoxContainer.new()
	name_label = Label.new()
	name_label.text = "Hero Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	top_bar.add_child(name_label)
	
	close_button = Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.focus_mode = Control.FOCUS_NONE
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.2, 0.22, 0.28, 0.8)
	close_style.set_corner_radius_all(4)
	close_button.add_theme_stylebox_override("normal", close_style)
	close_button.pressed.connect(close)
	top_bar.add_child(close_button)
	main_vbox.add_child(top_bar)
	
	# 2. Subheader: Class & Level
	var subheader := HBoxContainer.new()
	class_label = Label.new()
	class_label.text = "TANK"
	class_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_label.add_theme_font_size_override("font_size", 12)
	class_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95))
	subheader.add_child(class_label)
	
	level_label = Label.new()
	level_label.text = "Lv. 1"
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	subheader.add_child(level_label)
	main_vbox.add_child(subheader)
	
	# 3. XP Bar
	var xp_box := VBoxContainer.new()
	xp_box.add_theme_constant_override("separation", 2)
	xp_label = Label.new()
	xp_label.text = "XP: 0 / 100"
	xp_label.add_theme_font_size_override("font_size", 10)
	xp_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	xp_box.add_child(xp_label)
	
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 6)
	xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.95, 0.75, 0.2)
	xp_fill.set_corner_radius_all(3)
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.18, 0.20, 0.26)
	xp_bg.set_corner_radius_all(3)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	xp_box.add_child(xp_bar)
	main_vbox.add_child(xp_box)
	
	main_vbox.add_child(_create_separator())
	
	# 4. Resource Bars (HP & Energy)
	var hp_box := VBoxContainer.new()
	hp_box.add_theme_constant_override("separation", 2)
	hp_label = Label.new()
	hp_label.text = "HP: 100 / 100"
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	hp_box.add_child(hp_label)
	
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 10)
	hp_bar.show_percentage = false
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.22, 0.75, 0.38)
	hp_fill.set_corner_radius_all(4)
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.25, 0.12, 0.12)
	hp_bg.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	hp_box.add_child(hp_bar)
	main_vbox.add_child(hp_box)
	
	var energy_box := VBoxContainer.new()
	energy_box.add_theme_constant_override("separation", 2)
	energy_label = Label.new()
	energy_label.text = "Năng lượng: 0 / 100"
	energy_label.add_theme_font_size_override("font_size", 11)
	energy_label.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))
	energy_box.add_child(energy_label)
	
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(0, 10)
	energy_bar.show_percentage = false
	var en_fill := StyleBoxFlat.new()
	en_fill.bg_color = Color(0.2, 0.6, 0.95)
	en_fill.set_corner_radius_all(4)
	var en_bg := StyleBoxFlat.new()
	en_bg.bg_color = Color(0.12, 0.16, 0.25)
	en_bg.set_corner_radius_all(4)
	energy_bar.add_theme_stylebox_override("fill", en_fill)
	energy_bar.add_theme_stylebox_override("background", en_bg)
	energy_box.add_child(energy_bar)
	main_vbox.add_child(energy_box)
	
	main_vbox.add_child(_create_separator())
	
	# 5. Stats Grid
	var stats_title := Label.new()
	stats_title.text = "CHỈ SỐ CHI TIẾT"
	stats_title.add_theme_font_size_override("font_size", 11)
	stats_title.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	main_vbox.add_child(stats_title)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	
	attack_val_label = _create_stat_row(grid, "🗡️ SMCK:")
	spell_val_label = _create_stat_row(grid, "✨ SMPT:")
	def_val_label = _create_stat_row(grid, "🛡️ Giáp:")
	speed_val_label = _create_stat_row(grid, "⚡ Tốc đánh:")
	crit_val_label = _create_stat_row(grid, "🎯 Chí mạng:")
	crit_dmg_val_label = _create_stat_row(grid, "💥 STCM:")
	range_val_label = _create_stat_row(grid, "🏹 Tầm đánh:")
	main_vbox.add_child(grid)
	
	main_vbox.add_child(_create_separator())
	
	# 6. Abilities / Skills
	abilities_title = Label.new()
	abilities_title.text = "KỸ NĂNG ĐÃ HỌC"
	abilities_title.add_theme_font_size_override("font_size", 11)
	abilities_title.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	main_vbox.add_child(abilities_title)
	
	abilities_vbox = VBoxContainer.new()
	abilities_vbox.add_theme_constant_override("separation", 3)
	main_vbox.add_child(abilities_vbox)

func _create_stat_row(parent: GridContainer, stat_name: String) -> Label:
	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	parent.add_child(name_lbl)
	
	var val_lbl := Label.new()
	val_lbl.text = "0"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(val_lbl)
	return val_lbl

func _create_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.25, 0.28, 0.35, 0.6)
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep

# ==========================================
# PUBLIC API: INSPECTION
# ==========================================

func inspect_hero(hero: HeroEntity) -> void:
	if hero == null or not is_instance_valid(hero):
		close()
		return
		
	# Huỷ liên kết cũ nếu inspect Tướng khác
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
	
	var class_str := "TƯỚNG"
	if data != null:
		class_str = HeroData.HeroClass.keys()[data.hero_class]
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
	
	# Grid Stats
	var atk: float = inspected_hero.get_attack()
	var spell_pow: float = inspected_hero.get_spell_power()
	var def: float = inspected_hero.get_defense()
	var spd: float = inspected_hero.get_attack_speed()
	var crit_c: float = inspected_hero.get_crit_chance() * 100.0
	var crit_d: float = inspected_hero.get_crit_damage() * 100.0
	var atk_rng: int = inspected_hero.get_attack_range()
	
	attack_val_label.text = "%.1f" % atk
	spell_val_label.text = "%.1f" % spell_pow
	def_val_label.text = "%.1f" % def
	speed_val_label.text = "%.2f/s" % spd
	crit_val_label.text = "%.0f%%" % crit_c
	crit_dmg_val_label.text = "%.0f%%" % crit_d
	range_val_label.text = "%d ô" % atk_rng
	
	# Skills List
	for child in abilities_vbox.get_children():
		child.queue_free()
		
	var abilities_found: int = 0
	if inspected_hero.basic_attack_ability != null and inspected_hero.basic_attack_ability.data != null:
		_add_ability_entry("Đánh thường", inspected_hero.basic_attack_ability.data.name, Color(0.8, 0.8, 0.85))
		abilities_found += 1
		
	for runtime_ab in inspected_hero.unlocked_abilities:
		if is_instance_valid(runtime_ab) and runtime_ab.data != null:
			var type_name: String = str(AbilityData.AbilityType.keys()[runtime_ab.data.ability_type])
			var color := Color(0.4, 0.8, 1.0)
			if runtime_ab.data.ability_type == AbilityData.AbilityType.ULTIMATE:
				color = Color(1.0, 0.85, 0.2)
			elif runtime_ab.data.ability_type == AbilityData.AbilityType.PASSIVE:
				color = Color(0.5, 0.9, 0.5)
			_add_ability_entry(type_name, runtime_ab.data.name, color)
			abilities_found += 1
			
	if abilities_found == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "(Chưa mở khóa kỹ năng)"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		abilities_vbox.add_child(empty_lbl)

func _add_ability_entry(type_tag: String, ability_name: String, tag_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	
	var tag := Label.new()
	tag.text = "[%s]" % type_tag
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", tag_color)
	row.add_child(tag)
	
	var name_lbl := Label.new()
	name_lbl.text = ability_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(name_lbl)
	
	abilities_vbox.add_child(row)

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
