class_name CharacterStatsUI
extends CanvasLayer

# ==============================================================================
# CHARACTER STATS PANEL UI (SPRINT 3 - TASK S3.4.2: TFT-STYLE RIGHT-DOCK PANEL)
# Bảng hiển thị thông tin & chỉ số chi tiết Tướng đặt cạnh phải màn hình chuẩn TFT
# ==============================================================================

signal entity_inspected(entity: CombatEntity)
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
		rtl.custom_minimum_size = Vector2(280, 0)
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
var panel_style: StyleBoxFlat
var main_vbox: VBoxContainer

# 0. Top-Center Level Crest (TFT-Style Crest Badge)
var crest_overlay: Control = null
var crest_panel: PanelContainer
var crest_style: StyleBoxFlat
var crest_label: Label

# 1. Top Avatar & Info Banner
var avatar_panel: PanelContainer
var avatar_bg_style: StyleBoxFlat
var avatar_initial_label: Label
var name_label: Label
var class_label: Label
var level_label: Label
var awakening_label: Label = null
var close_button: Button = null

# 2. Survival & Progression Bars
var hp_label: Label
var hp_bar: ProgressBar
var energy_label: Label
var energy_bar: ProgressBar
var xp_box: HBoxContainer
var xp_label: Label
var xp_bar: ProgressBar

# 3. Hexagonal Skills Section
var skills_container: HBoxContainer

# 3.5. Equipped Items (Task S6.5: 3 Item Slots)
var items_section: VBoxContainer = null
var items_container: HBoxContainer = null
var item_slot_buttons: Array[Button] = []
var item_tooltip: ItemTooltip = null
var _on_item_equipped_callable: Callable

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
var inspected_entity: CombatEntity = null
var inspected_hero: HeroEntity:
	get:
		return inspected_entity as HeroEntity
	set(val):
		inspected_entity = val

var _on_hp_changed_callable: Callable
var _on_energy_changed_callable: Callable
var _on_died_callable: Callable
var _on_exiting_callable: Callable
var _on_leveled_up_callable: Callable

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
	
	panel_style = StyleBoxFlat.new()
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
	# 1. TOP HEADER & AVATAR BANNER (TRUE MONOLITHIC CARD - INTEGRATED CREST)
	# ==========================================================================
	avatar_panel = PanelContainer.new()
	avatar_panel.name = "AvatarBannerPanel"
	avatar_panel.custom_minimum_size = Vector2(260, 115)
	avatar_bg_style = StyleBoxFlat.new()
	avatar_bg_style.bg_color = Color(0.18, 0.24, 0.36)
	avatar_bg_style.set_corner_radius_all(8)
	avatar_bg_style.content_margin_left = 8
	avatar_bg_style.content_margin_right = 8
	avatar_bg_style.content_margin_top = 6
	avatar_bg_style.content_margin_bottom = 6
	# Seamless Monolithic: panel_container is sole bounding frame; no inner border
	var empty_avatar_style := StyleBoxEmpty.new()
	avatar_panel.add_theme_stylebox_override("panel", empty_avatar_style)
	main_vbox.add_child(avatar_panel)
	
	var banner_control := Control.new()
	banner_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_panel.add_child(banner_control)
	
	# Class / Hệ Tộc (Góc trên trái banner, chuẩn TFT)
	class_label = Label.new()
	class_label.text = "[TANK]"
	class_label.position = Vector2(6, 4)
	class_label.add_theme_font_size_override("font_size", 11)
	class_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	banner_control.add_child(class_label)
	
	# Integrated Crest Badge (Nằm hoàn toàn bên trong đỉnh khung, Y >= 0, không nhô ra ngoài)
	crest_panel = PanelContainer.new()
	crest_panel.name = "LevelCrestBadge"
	crest_panel.custom_minimum_size = Vector2(130, 24)
	crest_panel.size = Vector2(130, 24)
	crest_panel.position = Vector2((260 - 130) * 0.5, 2)
	crest_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	crest_style = StyleBoxFlat.new()
	crest_style.set_corner_radius_all(8)
	crest_style.content_margin_left = 10
	crest_style.content_margin_right = 10
	crest_style.content_margin_top = 1
	crest_style.content_margin_bottom = 1
	crest_style.set_border_width_all(0)
	# SPRINT 5: Khử triệt để viền con - crest_panel dùng StyleBoxEmpty theo GD Spec
	crest_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	banner_control.add_child(crest_panel)
	
	crest_label = Label.new()
	crest_label.name = "CrestLabel"
	crest_label.text = "• CẤP 1 •"
	crest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crest_label.add_theme_font_size_override("font_size", 11)
	crest_label.add_theme_constant_override("outline_size", 3)
	crest_label.add_theme_color_override("font_outline_color", Color(0.07, 0.08, 0.1, 1.0))
	crest_panel.add_child(crest_label)
	
	# Nút đóng [✕] bị loại bỏ hoàn toàn theo GD Spec (tự động đóng khi Click ngoài)
	close_button = null
	
	# Icon Avatar Placeholder ở giữa banner
	avatar_initial_label = Label.new()
	avatar_initial_label.text = "⚔️"
	avatar_initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_initial_label.size = Vector2(50, 50)
	avatar_initial_label.position = Vector2(105, 30)
	avatar_initial_label.add_theme_font_size_override("font_size", 28)
	banner_control.add_child(avatar_initial_label)
	
	# Tên Tướng (Chính giữa bên dưới Avatar)
	name_label = Label.new()
	name_label.text = "Hero Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(240, 22)
	name_label.position = Vector2(10, 84)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	banner_control.add_child(name_label)
	
	# level_label (Duy trì đồng bộ ngầm để tương thích ngược 100% với các test TC-16 & TC-20)
	level_label = Label.new()
	level_label.text = "Cấp 1"
	level_label.visible = false
	banner_control.add_child(level_label)
	
	# S7.2: Nhãn Thức Tỉnh Class Awakening
	awakening_label = Label.new()
	awakening_label.name = "AwakeningBadge"
	awakening_label.text = ""
	awakening_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	awakening_label.size = Vector2(240, 18)
	awakening_label.position = Vector2(10, 104)
	awakening_label.add_theme_font_size_override("font_size", 11)
	awakening_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	awakening_label.visible = false
	banner_control.add_child(awakening_label)
	
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
	
	# Thanh XP (Gói trong xp_box để co lại mượt mà khi soi quái vật)
	xp_box = HBoxContainer.new()
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
	skills_title.text = "KỸ NĂNG & VỊ TRÍ"
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
	# 3.5. KHỐI TRANG BỊ ĐÃ MANG (TASK S6.5: 3 ITEM SLOTS)
	# ==========================================================================
	items_section = VBoxContainer.new()
	items_section.name = "ItemsSection"
	items_section.add_theme_constant_override("separation", 4)
	main_vbox.add_child(items_section)
	
	var items_title := Label.new()
	items_title.name = "ItemsTitle"
	items_title.text = "TRANG BỊ (3 Ô)"
	items_title.add_theme_font_size_override("font_size", 11)
	items_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	items_section.add_child(items_title)
	
	items_container = HBoxContainer.new()
	items_container.name = "ItemsContainer"
	items_container.alignment = BoxContainer.ALIGNMENT_CENTER
	items_container.add_theme_constant_override("separation", 10)
	items_container.custom_minimum_size = Vector2(0, 50)
	items_section.add_child(items_container)
	
	item_slot_buttons.clear()
	for i in range(3):
		var btn := Button.new()
		btn.name = "HeroItemSlot_%d" % i
		btn.custom_minimum_size = Vector2(48, 48)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.mouse_entered.connect(func(): _on_item_slot_hovered(i))
		btn.mouse_exited.connect(func(): _on_item_slot_unhovered(i))
		items_container.add_child(btn)
		item_slot_buttons.append(btn)
		
	main_vbox.add_child(_create_separator())
	
	# Tooltip nổi cho thẻ tướng (Bung sang trái thẻ bài)
	item_tooltip = ItemTooltip.new()
	item_tooltip.name = "HeroItemTooltip"
	item_tooltip.hide()
	item_tooltip.z_index = 100
	add_child(item_tooltip) # Thêm trực tiếp vào CanvasLayer thay vì panel_container
	
	# ==========================================================================
	# 4. KHỐI CHỈ SỐ CỐT LÕI (TFT COMPACT GRID: 2 HÀNG X 4 CỘT)
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
	
	# Hàng 1 (Tấn công & Phòng thủ): ⚔️ SMCK | 🔮 SMPT | 🛡️ Giáp | 🎯 Tốc đánh
	attack_val_label = _create_stat_cell(grid, "⚔️", "SMCK")
	spell_val_label = _create_stat_cell(grid, "🔮", "SMPT")
	def_val_label = _create_stat_cell(grid, "🛡️", "Giáp")
	speed_val_label = _create_stat_cell(grid, "🎯", "Tốc")
	
	# Hàng 2 (Chí mạng & Đặc thù): 💥 Tỉ lệ CM | ⚡ Sát thương CM | 🏹 Tầm đánh | 🔋 Năng lượng khởi đầu
	crit_val_label = _create_stat_cell(grid, "💥", "CM")
	crit_dmg_val_label = _create_stat_cell(grid, "⚡", "STCM")
	range_val_label = _create_stat_cell(grid, "🏹", "Tầm")
	start_energy_val_label = _create_stat_cell(grid, "🔋", "Khởi")
	
	main_vbox.add_child(grid)

func _create_stat_cell(parent: GridContainer, icon: String, stat_name: String) -> Label:
	var cell_panel := PanelContainer.new()
	cell_panel.custom_minimum_size = Vector2(58, 44)
	cell_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = Color(0.12, 0.15, 0.20, 0.85)
	cell_style.set_corner_radius_all(6)
	cell_style.content_margin_top = 3
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

func inspect_entity(entity: CombatEntity) -> void:
	if entity == null or not is_instance_valid(entity):
		close()
		return
		
	_disconnect_inspected_entity()
	inspected_entity = entity
	_connect_inspected_entity()
	
	update_stats()
	show()
	entity_inspected.emit(entity)
	if entity is HeroEntity:
		hero_inspected.emit(entity as HeroEntity)

func inspect_hero(hero: CombatEntity) -> void:
	inspect_entity(hero)

func close() -> void:
	_disconnect_inspected_entity()
	inspected_entity = null
	if item_tooltip != null:
		item_tooltip.hide()
	hide()
	panel_closed.emit()

func update_stats() -> void:
	if inspected_entity == null or not is_instance_valid(inspected_entity):
		close()
		return
		
	if inspected_entity is HeroEntity:
		_render_hero_prestige_ui(inspected_entity as HeroEntity)
	elif inspected_entity is EnemyEntity:
		_render_enemy_rank_ui(inspected_entity as EnemyEntity)
	else:
		_render_generic_entity_ui(inspected_entity)
		
	_update_items_display()

func _render_hero_prestige_ui(hero: HeroEntity) -> void:
	var data: HeroData = hero.data
	name_label.text = data.name if data != null else hero.name
	
	# Class Banner Label
	class_label.visible = true
	var class_str := "TƯỚNG"
	if data != null:
		class_str = HeroData.HeroClass.keys()[data.hero_class]
	class_label.text = "[%s]" % class_str
	
	# Progression & Level
	var current_lvl: int = 1
	var cur_xp: float = 0.0
	var req_xp: float = 100.0
	if hero.progression != null:
		current_lvl = hero.progression.current_level
		cur_xp = hero.progression.current_xp
		req_xp = hero.progression.required_xp
	level_label.text = "Cấp %d" % current_lvl
	level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	if awakening_label != null:
		if hero.awakening_count > 0:
			awakening_label.text = "✦ Thức Tỉnh x%d" % hero.awakening_count
			awakening_label.visible = true
		else:
			awakening_label.text = ""
			awakening_label.visible = false
	_apply_crest_tier(hero)
	
	# XP Bar
	if xp_box != null: xp_box.visible = true
	xp_label.visible = true
	xp_bar.visible = true
	xp_label.text = "XP: %.0f / %.0f" % [cur_xp, req_xp]
	xp_bar.max_value = req_xp
	xp_bar.value = cur_xp
	
	# HP & Energy
	hp_label.text = "HP: %.0f / %.0f" % [hero.current_hp, hero.max_hp]
	hp_bar.max_value = hero.max_hp
	hp_bar.value = hero.current_hp
	
	energy_label.visible = true
	energy_bar.visible = true
	energy_label.text = "Năng lượng: %.0f / %.0f" % [hero.current_energy, hero.max_energy]
	energy_bar.max_value = hero.max_energy
	energy_bar.value = hero.current_energy
	
	# 4x2 Grid Core Stats
	var atk: float = hero.get_attack()
	var spell_pow: float = hero.get_spell_power()
	var def: float = hero.get_defense()
	var atk_rng: int = hero.get_attack_range()
	var spd: float = hero.get_attack_speed()
	var crit_c: float = hero.get_crit_chance() * 100.0
	var crit_d: float = hero.get_crit_damage() * 100.0
	var start_en: float = data.starting_energy if (data != null and "starting_energy" in data) else 0.0
	
	attack_val_label.text = "%.1f" % atk
	spell_val_label.text = "%.1f" % spell_pow
	def_val_label.text = "%.1f" % def
	def_val_label.tooltip_text = "Giáp: %.1f" % def
	range_val_label.text = "%d ô" % atk_rng
	speed_val_label.text = "%.2f/s" % spd
	crit_val_label.text = "%.0f%%" % crit_c
	crit_dmg_val_label.text = "%.0f%%" % crit_d
	start_energy_val_label.text = "%.0f" % start_en
	
	# Hexagonal Skills Section
	for child in skills_container.get_children():
		child.queue_free()
		
	var skills_found: int = 0
	if hero.basic_attack_ability != null and hero.basic_attack_ability.data != null:
		var basic_desc: String = hero.basic_attack_ability.data.get_formatted_tooltip(hero, true)
		var basic_icon := HexSkillIcon.new(hero.basic_attack_ability.data.name, "Đánh thường", Color(0.65, 0.70, 0.80), basic_desc)
		skills_container.add_child(basic_icon)
		skills_found += 1
		
	for runtime_ab in hero.unlocked_abilities:
		if is_instance_valid(runtime_ab) and runtime_ab.data != null:
			var type_name: String = str(AbilityData.AbilityType.keys()[runtime_ab.data.ability_type])
			var border_col := Color(0.35, 0.75, 1.0)
			if runtime_ab.data.ability_type == AbilityData.AbilityType.ULTIMATE:
				border_col = Color(1.0, 0.85, 0.2)
			elif runtime_ab.data.ability_type == AbilityData.AbilityType.PASSIVE:
				border_col = Color(0.4, 0.9, 0.4)
			var skill_desc: String = runtime_ab.data.get_formatted_tooltip(hero, true)
			var skill_icon := HexSkillIcon.new(runtime_ab.data.name, type_name, border_col, skill_desc)
			skills_container.add_child(skill_icon)
			skills_found += 1
			
	if skills_found == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "(Chưa mở khóa kỹ năng)"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		skills_container.add_child(empty_lbl)
		
	_apply_prestige_style(hero)

func _render_enemy_rank_ui(enemy: EnemyEntity) -> void:
	var edata: EnemyData = enemy.data
	name_label.text = edata.name if edata != null else enemy.name
	
	# Class Label is hidden for enemies
	class_label.visible = false
	
	var is_solo_boss: bool = enemy.damage_reduction >= 0.30
	var is_boss: bool = (edata != null and edata.rank == EnemyData.EnemyRank.BOSS) or is_solo_boss
	var is_elite: bool = (edata != null and edata.rank == EnemyData.EnemyRank.ELITE)
	
	_apply_crest_tier(enemy)
	
	if is_boss:
		level_label.text = "[👑 LÃNH CHÚA TẦNG] - Cấp %d" % enemy.level
		level_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	elif is_elite:
		level_label.text = "[🔥 TINH ANH] - Cấp %d" % enemy.level
		level_label.add_theme_color_override("font_color", Color(0.75, 0.40, 0.95))
	else:
		level_label.text = "[QUÁI THƯỜNG] - Cấp %d" % enemy.level
		level_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		
	# XP bar is hidden for enemies (Guardrail 3: co lại mượt mà, không khoảng trống chết)
	if xp_box != null: xp_box.visible = false
	xp_label.visible = false
	xp_bar.visible = false
	
	# HP bar
	hp_label.text = "HP: %.0f / %.0f" % [enemy.current_hp, enemy.max_hp]
	hp_bar.max_value = enemy.max_hp
	hp_bar.value = enemy.current_hp
	
	# Energy bar: hidden if enemy has no abilities
	var has_skills: bool = not enemy.unlocked_abilities.is_empty()
	energy_label.visible = has_skills
	energy_bar.visible = has_skills
	if has_skills:
		energy_label.text = "Năng lượng: %.0f / %.0f" % [enemy.current_energy, enemy.max_energy]
		energy_bar.max_value = enemy.max_energy
		energy_bar.value = enemy.current_energy
		
	# 4x2 Grid Core Stats
	var atk: float = enemy.get_attack()
	var spell_pow: float = enemy.get_spell_power()
	var def: float = enemy.get_defense()
	var atk_rng: int = enemy.get_attack_range()
	var spd: float = enemy.get_attack_speed()
	var crit_c: float = enemy.get_crit_chance() * 100.0
	var crit_d: float = enemy.get_crit_damage() * 100.0
	var start_en: float = edata.starting_energy if (edata != null and "starting_energy" in edata) else 0.0
	
	attack_val_label.text = "%.1f" % atk
	spell_val_label.text = "%.1f" % spell_pow
	
	# Giáp & Kháng sát thương
	if enemy.damage_reduction > 0.0:
		var dr_pct := roundi(enemy.damage_reduction * 100.0)
		def_val_label.text = "%.0f (-%d%%)" % [def, dr_pct]
		def_val_label.tooltip_text = "Giáp: %.1f | Kháng sát thương: %d%%" % [def, dr_pct]
	else:
		def_val_label.text = "%.1f" % def
		def_val_label.tooltip_text = "Giáp: %.1f" % def
		
	range_val_label.text = "%d ô" % atk_rng
	speed_val_label.text = "%.2f/s" % spd
	crit_val_label.text = "%.0f%%" % crit_c
	crit_dmg_val_label.text = "%.0f%%" % crit_d
	start_energy_val_label.text = "%.0f" % start_en
	
	# Hexagonal Skills Section
	for child in skills_container.get_children():
		child.queue_free()
		
	var skills_found: int = 0
	for runtime_ab in enemy.unlocked_abilities:
		if is_instance_valid(runtime_ab) and runtime_ab.data != null:
			var type_name: String = str(AbilityData.AbilityType.keys()[runtime_ab.data.ability_type])
			var border_col := Color(0.85, 0.35, 0.8) if is_elite else (Color(1.0, 0.85, 0.2) if is_boss else Color(0.35, 0.75, 1.0))
			var skill_desc: String = runtime_ab.data.get_formatted_tooltip(enemy)
			var skill_icon := HexSkillIcon.new(runtime_ab.data.name, type_name, border_col, skill_desc)
			skills_container.add_child(skill_icon)
			skills_found += 1
			
	if skills_found == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "(Không có kỹ năng)"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		skills_container.add_child(empty_lbl)
		
	_apply_prestige_style(enemy)

func _render_generic_entity_ui(entity: CombatEntity) -> void:
	name_label.text = entity.name
	class_label.visible = false
	level_label.text = "Cấp %d" % entity.level
	_apply_crest_tier(entity)
	_apply_prestige_style(entity)
	if xp_box != null: xp_box.visible = false
	xp_label.visible = false
	xp_bar.visible = false
	hp_label.text = "HP: %.0f / %.0f" % [entity.current_hp, entity.max_hp]
	hp_bar.max_value = entity.max_hp
	hp_bar.value = entity.current_hp
	energy_label.text = "Năng lượng: %.0f / %.0f" % [entity.current_energy, entity.max_energy]
	energy_bar.max_value = entity.max_energy
	energy_bar.value = entity.current_energy
	attack_val_label.text = "%.1f" % entity.get_attack()
	spell_val_label.text = "%.1f" % entity.get_spell_power()
	def_val_label.text = "%.1f" % entity.get_defense()
	range_val_label.text = "%d ô" % entity.get_attack_range()
	speed_val_label.text = "%.2f/s" % entity.get_attack_speed()
	crit_val_label.text = "%.0f%%" % (entity.get_crit_chance() * 100.0)
	crit_dmg_val_label.text = "%.0f%%" % (entity.get_crit_damage() * 100.0)
	start_energy_val_label.text = "0"

# ==============================================================================
# EQUIPPED ITEMS DISPLAY & HOVER TOOLTIP (TASK S6.5)
# ==============================================================================
func _update_items_display() -> void:
	if items_section == null:
		return
		
	if inspected_hero == null:
		items_section.hide()
		return
		
	items_section.show()
	for i in range(3):
		if i >= item_slot_buttons.size(): break
		var btn := item_slot_buttons[i]
		var item: ItemData = inspected_hero.equipped_items[i] if i < inspected_hero.equipped_items.size() else null
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#0f172a")
		style.set_corner_radius_all(8)
		
		if item != null:
			style.set_border_width_all(2)
			match item.tier:
				1: style.border_color = Color("#64748b")
				2: style.border_color = Color("#f59e0b")
				3: style.border_color = Color("#e879f9")
				_: style.border_color = Color("#64748b")
			btn.text = _get_item_symbol(item)
			btn.add_theme_font_size_override("font_size", 20)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			style.set_border_width_all(1)
			style.border_color = Color("#334155")
			btn.text = "+"
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color("#475569"))
			
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _on_item_slot_hovered(idx: int) -> void:
	if inspected_hero == null or idx >= inspected_hero.equipped_items.size():
		return
	var item := inspected_hero.equipped_items[idx]
	if item != null and item_tooltip != null:
		item_tooltip.render_tooltip(item)
		var tt_size := item_tooltip.get_combined_minimum_size()
		
		# Tọa độ neo tuyệt đối bên trái thẻ bài (856px - 230px - 12px = 614px)
		var target_x: float = panel_container.position.x - tt_size.x - 12.0
		# Neo Y kế bên ô trang bị đang xem thay vì ở trên cao
		var slot_btn: Button = item_slot_buttons[idx] if idx < item_slot_buttons.size() else null
		var slot_y: float = slot_btn.global_position.y if (slot_btn != null and slot_btn.global_position.y > 0) else (panel_container.position.y + 350.0)
		var slot_h: float = slot_btn.size.y if (slot_btn != null and slot_btn.size.y > 0) else 48.0
		var target_y: float = clamp(slot_y - (tt_size.y - slot_h) * 0.5, 40.0, 640.0 - tt_size.y - 10.0)
		
		item_tooltip.position = Vector2(target_x, target_y)
		item_tooltip.show()

func _on_item_slot_unhovered(_idx: int) -> void:
	if item_tooltip != null:
		item_tooltip.hide()

func _get_item_symbol(item: ItemData) -> String:
	if item == null:
		return ""
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

# ==============================================================================
# LEVEL CREST TIER MATRIX & MONSTER EMBLEMS (GD SPEC SECTION II)
# ==============================================================================
func _apply_crest_tier(entity: CombatEntity) -> void:
	if crest_label == null or crest_style == null:
		return
	crest_label.tooltip_text = ""
	
	if entity is HeroEntity:
		var hero := entity as HeroEntity
		var lvl: int = hero.progression.current_level if hero.progression != null else hero.level
		
		if lvl >= 99:
			# Tier VI: Vô Cực (Mythic MAX)
			crest_label.text = "✨ CẤP 99 MAX ✨"
			_set_crest_style(Color("#9b59b6"), Color("#1f0a2a"), 3.0, Color(0.61, 0.35, 0.71, 0.8), 12)
		elif lvl >= 75:
			# Tier V: Huyền Thoại (Legend)
			crest_label.text = "👑 CẤP %d 👑" % lvl
			_set_crest_style(Color("#e74c3c"), Color("#2a0808"), 3.0, Color(0.91, 0.30, 0.24, 0.7), 10)
		elif lvl >= 50:
			# Tier IV: Bậc Thầy (Diamond)
			crest_label.text = "❖ CẤP %d ❖" % lvl
			_set_crest_style(Color("#00cec9"), Color("#062024"), 2.5, Color(0.0, 0.81, 0.79, 0.6), 8)
		elif lvl >= 25:
			# Tier III: Dũng Sĩ (Gold)
			crest_label.text = "★ CẤP %d ★" % lvl
			_set_crest_style(Color("#f1c40f"), Color("#2c2105"), 2.5, Color(0.95, 0.77, 0.06, 0.5), 6)
		elif lvl >= 10:
			# Tier II: Tinh Anh (Silver)
			crest_label.text = "✦ CẤP %d ✦" % lvl
			_set_crest_style(Color("#bdc3c7"), Color("#1e272e"), 2.0, Color(0.74, 0.76, 0.78, 0.4), 4)
		else:
			# Tier I: Tân Binh (Bronze)
			crest_label.text = "• CẤP %d •" % lvl
			_set_crest_style(Color("#cd7f32"), Color("#2d1a10"), 1.5, Color(0, 0, 0, 0.4), 2)
			
	elif entity is EnemyEntity:
		var enemy := entity as EnemyEntity
		var is_solo_boss: bool = enemy.damage_reduction >= 0.30
		var is_boss: bool = (enemy.data != null and enemy.data.rank == EnemyData.EnemyRank.BOSS) or is_solo_boss
		var is_elite: bool = (enemy.data != null and enemy.data.rank == EnemyData.EnemyRank.ELITE)
		
		if is_solo_boss:
			crest_label.text = "👑 SOLO BOSS (Lv.%d) 👑" % enemy.level
			crest_label.tooltip_text = "Giảm 30% Sát thương nhận vào"
			_set_crest_style(Color("#d35400"), Color("#331a00"), 3.0, Color(0.83, 0.33, 0.0, 0.8), 12)
		elif is_boss:
			crest_label.text = "💀 BOSS (Lv.%d) 💀" % enemy.level
			_set_crest_style(Color("#c0392b"), Color("#330d0d"), 3.0, Color(0.75, 0.22, 0.17, 0.7), 10)
		elif is_elite:
			crest_label.text = "🔥 TINH ANH (Lv.%d) 🔥" % enemy.level
			_set_crest_style(Color("#8e44ad"), Color("#251133"), 2.5, Color(0.56, 0.27, 0.68, 0.6), 8)
		else:
			var name_str: String = enemy.data.name if (enemy.data and enemy.data.name != "") else "QUÁI THƯỜNG"
			crest_label.text = "• %s (Lv.%d) •" % [name_str, enemy.level]
			_set_crest_style(Color("#7f8c8d"), Color("#1e2226"), 1.5, Color(0, 0, 0, 0), 0)
	else:
		crest_label.text = "• CẤP %d •" % entity.level
		_set_crest_style(Color("#7f8c8d"), Color("#1e2226"), 1.5, Color(0, 0, 0, 0), 0)

func _set_crest_style(fg: Color, bg: Color, _border_w: float, shadow: Color, shadow_sz: int) -> void:
	crest_label.add_theme_color_override("font_color", fg)
	crest_style.border_color = fg
	crest_style.bg_color = bg
	crest_style.set_border_width_all(0)
	crest_style.shadow_color = shadow
	crest_style.shadow_size = shadow_sz

func _apply_prestige_style(entity: CombatEntity) -> void:
	if entity is HeroEntity:
		var hero := entity as HeroEntity
		var lvl: int = hero.progression.current_level if hero.progression != null else hero.level
		
		if lvl >= 99:
			# Tier VI: Vô Cực MAX (Lv 99) - Tím Vũ Trụ
			if panel_style != null:
				panel_style.border_color = Color("#9b59b6")
				panel_style.shadow_color = Color(0.61, 0.35, 0.71, 0.8)
				panel_style.shadow_size = 14
				panel_style.set_border_width_all(2)
			# TC-20 compatibility
			avatar_bg_style.border_color = Color(1.0, 0.2, 0.7, 1.0)
			avatar_bg_style.set_border_width_all(3)
			avatar_bg_style.shadow_color = Color(1.0, 0.2, 0.7, 0.8)
			avatar_bg_style.shadow_size = 12
			avatar_bg_style.bg_color = Color(0.28, 0.08, 0.22)
		elif lvl >= 75:
			# Tier V: Huyền Thoại (Lv 75 - 98) - Đỏ Huyết Ngọc
			if panel_style != null:
				panel_style.border_color = Color("#e74c3c")
				panel_style.shadow_color = Color(0.91, 0.30, 0.24, 0.6)
				panel_style.shadow_size = 10
				panel_style.set_border_width_all(2)
			# TC-20 compatibility
			avatar_bg_style.border_color = Color(1.0, 0.35, 0.15, 1.0)
			avatar_bg_style.set_border_width_all(3)
			avatar_bg_style.shadow_color = Color(1.0, 0.4, 0.1, 0.7)
			avatar_bg_style.shadow_size = 10
			avatar_bg_style.bg_color = Color(0.32, 0.12, 0.12)
		elif lvl >= 50:
			# Tier IV: Bậc Thầy (Lv 50 - 74) - Lam Ngọc Kim Cương
			if panel_style != null:
				panel_style.border_color = Color("#00cec9")
				panel_style.shadow_color = Color(0.0, 0.81, 0.79, 0.5)
				panel_style.shadow_size = 8
				panel_style.set_border_width_all(2)
			# TC-20 compatibility
			avatar_bg_style.border_color = Color(0.70, 0.30, 0.95, 1.0)
			avatar_bg_style.set_border_width_all(2)
			avatar_bg_style.shadow_color = Color(0.70, 0.30, 0.95, 0.6)
			avatar_bg_style.shadow_size = 8
			avatar_bg_style.bg_color = Color(0.22, 0.12, 0.35)
		elif lvl >= 25:
			# Tier III: Dũng Sĩ (Lv 25 - 49) - Vàng Hoàng Kim (Mốc Jaina Cấp 31)
			if panel_style != null:
				panel_style.border_color = Color("#f1c40f")
				panel_style.shadow_color = Color(0.95, 0.77, 0.06, 0.4)
				panel_style.shadow_size = 6
				panel_style.set_border_width_all(2)
			# TC-20 compatibility
			avatar_bg_style.border_color = Color(0.20, 0.65, 1.0, 1.0)
			avatar_bg_style.set_border_width_all(2)
			avatar_bg_style.shadow_color = Color(0.20, 0.65, 1.0, 0.5)
			avatar_bg_style.shadow_size = 6
			avatar_bg_style.bg_color = Color(0.12, 0.22, 0.38)
		elif lvl >= 10:
			# Tier II: Tinh Anh (Lv 10 - 24) - Bạc Ánh Kim
			if panel_style != null:
				panel_style.border_color = Color("#bdc3c7")
				panel_style.shadow_color = Color(0.74, 0.76, 0.78, 0.3)
				panel_style.shadow_size = 4
				panel_style.set_border_width_all(2)
			# TC-20 compatibility
			avatar_bg_style.border_color = Color(0.18, 0.85, 0.45, 1.0)
			avatar_bg_style.set_border_width_all(2)
			avatar_bg_style.shadow_color = Color(0.18, 0.85, 0.45, 0.4)
			avatar_bg_style.shadow_size = 4
			avatar_bg_style.bg_color = Color(0.12, 0.30, 0.20)
		else:
			# Tier I: Tân Binh (Lv 1 - 9) - Nâu Đồng
			if panel_style != null:
				panel_style.border_color = Color("#cd7f32")
				panel_style.shadow_color = Color(0, 0, 0, 0)
				panel_style.shadow_size = 0
				panel_style.set_border_width_all(2)
			# TC-20 compatibility
			avatar_bg_style.border_color = Color(0.35, 0.4, 0.5, 0.8)
			avatar_bg_style.set_border_width_all(1)
			avatar_bg_style.shadow_color = Color(0, 0, 0, 0)
			avatar_bg_style.shadow_size = 0
			_apply_hero_class_bg(hero.data)
			
	elif entity is EnemyEntity:
		var enemy := entity as EnemyEntity
		var is_solo_boss: bool = enemy.damage_reduction >= 0.30
		var is_boss: bool = (enemy.data != null and enemy.data.rank == EnemyData.EnemyRank.BOSS) or is_solo_boss
		var is_elite: bool = (enemy.data != null and enemy.data.rank == EnemyData.EnemyRank.ELITE)
		
		if is_solo_boss:
			# Solo Raid Boss - Cam Cháy
			if panel_style != null:
				panel_style.border_color = Color("#d35400")
				panel_style.shadow_color = Color(0.83, 0.33, 0.0, 0.7)
				panel_style.shadow_size = 12
				panel_style.set_border_width_all(2)
			avatar_bg_style.border_color = Color(0.90, 0.12, 0.20, 1.0)
			avatar_bg_style.set_border_width_all(3)
			avatar_bg_style.shadow_color = Color(0.90, 0.12, 0.20, 0.8)
			avatar_bg_style.shadow_size = 12
			avatar_bg_style.bg_color = Color(0.24, 0.05, 0.08)
			avatar_initial_label.text = "👑"
		elif is_boss:
			# Boss - Đỏ Hắc Ám
			if panel_style != null:
				panel_style.border_color = Color("#c0392b")
				panel_style.shadow_color = Color(0.75, 0.22, 0.17, 0.6)
				panel_style.shadow_size = 10
				panel_style.set_border_width_all(2)
			avatar_bg_style.border_color = Color(0.90, 0.12, 0.20, 1.0)
			avatar_bg_style.set_border_width_all(3)
			avatar_bg_style.shadow_color = Color(0.90, 0.12, 0.20, 0.8)
			avatar_bg_style.shadow_size = 12
			avatar_bg_style.bg_color = Color(0.24, 0.05, 0.08)
			avatar_initial_label.text = "👑"
		elif is_elite:
			# Tinh Anh - Tím Thẫm
			if panel_style != null:
				panel_style.border_color = Color("#8e44ad")
				panel_style.shadow_color = Color(0.56, 0.27, 0.68, 0.5)
				panel_style.shadow_size = 6
				panel_style.set_border_width_all(2)
			avatar_bg_style.border_color = Color(0.85, 0.35, 0.80, 1.0)
			avatar_bg_style.set_border_width_all(2)
			avatar_bg_style.shadow_color = Color(0.85, 0.35, 0.80, 0.6)
			avatar_bg_style.shadow_size = 8
			avatar_bg_style.bg_color = Color(0.25, 0.10, 0.28)
			avatar_initial_label.text = "🔥"
		else:
			# Quái Thường - Xám Tro
			if panel_style != null:
				panel_style.border_color = Color("#484852")
				panel_style.shadow_color = Color(0, 0, 0, 0)
				panel_style.shadow_size = 0
				panel_style.set_border_width_all(2)
			avatar_bg_style.border_color = Color(0.48, 0.48, 0.52, 0.8)
			avatar_bg_style.set_border_width_all(1)
			avatar_bg_style.shadow_color = Color(0, 0, 0, 0)
			avatar_bg_style.shadow_size = 0
			avatar_bg_style.bg_color = Color(0.18, 0.18, 0.22)
			avatar_initial_label.text = "👾"
	else:
		if panel_style != null:
			panel_style.border_color = Color("#484852")
			panel_style.shadow_color = Color(0, 0, 0, 0)
			panel_style.shadow_size = 0
			panel_style.set_border_width_all(2)

func _apply_hero_class_bg(data: HeroData) -> void:
	if data == null:
		avatar_bg_style.bg_color = Color(0.18, 0.24, 0.36)
		avatar_initial_label.text = "⚔️"
		return
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

func _connect_inspected_entity() -> void:
	if inspected_entity == null: return
	_on_hp_changed_callable = func(_c, _m): update_stats()
	_on_energy_changed_callable = func(_c, _m): update_stats()
	_on_died_callable = func(_e): close()
	_on_exiting_callable = func(): close()
	
	inspected_entity.hp_changed.connect(_on_hp_changed_callable)
	inspected_entity.energy_changed.connect(_on_energy_changed_callable)
	inspected_entity.died.connect(_on_died_callable)
	inspected_entity.tree_exiting.connect(_on_exiting_callable)

	if inspected_entity is HeroEntity:
		var hero := inspected_entity as HeroEntity
		if hero.progression != null:
			_on_leveled_up_callable = func(_lvl): update_stats()
			if not hero.progression.leveled_up.is_connected(_on_leveled_up_callable):
				hero.progression.leveled_up.connect(_on_leveled_up_callable)
		_on_item_equipped_callable = func(_h, _i, _c): _update_items_display()
		if not hero.item_equipped.is_connected(_on_item_equipped_callable):
			hero.item_equipped.connect(_on_item_equipped_callable)

func _disconnect_inspected_entity() -> void:
	if inspected_entity != null and is_instance_valid(inspected_entity):
		if _on_hp_changed_callable.is_valid() and inspected_entity.hp_changed.is_connected(_on_hp_changed_callable):
			inspected_entity.hp_changed.disconnect(_on_hp_changed_callable)
		if _on_energy_changed_callable.is_valid() and inspected_entity.energy_changed.is_connected(_on_energy_changed_callable):
			inspected_entity.energy_changed.disconnect(_on_energy_changed_callable)
		if _on_died_callable.is_valid() and inspected_entity.died.is_connected(_on_died_callable):
			inspected_entity.died.disconnect(_on_died_callable)
		if _on_exiting_callable.is_valid() and inspected_entity.tree_exiting.is_connected(_on_exiting_callable):
			inspected_entity.tree_exiting.disconnect(_on_exiting_callable)
		if inspected_entity is HeroEntity:
			var hero := inspected_entity as HeroEntity
			if hero.progression != null and _on_leveled_up_callable.is_valid():
				if hero.progression.leveled_up.is_connected(_on_leveled_up_callable):
					hero.progression.leveled_up.disconnect(_on_leveled_up_callable)
			if _on_item_equipped_callable.is_valid() and hero.item_equipped.is_connected(_on_item_equipped_callable):
				hero.item_equipped.disconnect(_on_item_equipped_callable)

# ==============================================================================
# SPRINT 5: CLICK-OUTSIDE DISMISS DETECTION (GD & QA SPEC)
# ==============================================================================
func is_click_inside(screen_pos: Vector2) -> bool:
	if not visible:
		return false
	if panel_container != null and is_instance_valid(panel_container):
		if panel_container.get_global_rect().has_point(screen_pos):
			return true
	if crest_panel != null and is_instance_valid(crest_panel):
		if crest_panel.get_global_rect().has_point(screen_pos):
			return true
	return false

func handle_click_outside(screen_pos: Vector2) -> bool:
	if visible and not is_click_inside(screen_pos):
		close()
		return true
	return false


