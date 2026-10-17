class_name CombatSummaryUI
extends CanvasLayer

# ==========================================
# COMBAT SUMMARY UI (SPRINT 3 - TASK S3.2)
# Bảng tổng kết giao tranh & thống kê sát thương (Damage Meter)
# ==========================================

signal continued

enum MetricTab { DAMAGE, TAKEN, HEAL }
var active_tab: MetricTab = MetricTab.DAMAGE

var dim_bg: ColorRect
var center_container: CenterContainer
var panel: PanelContainer
var main_vbox: VBoxContainer
var title_label: Label
var subtitle_label: Label
var tab_container: HBoxContainer
var damage_tab_btn: Button
var taken_tab_btn: Button
var heal_tab_btn: Button
var rows_container: VBoxContainer
var continue_button: Button

# Dữ liệu cache của trận đấu hiện tại
var cached_heroes: Array = []
var cached_is_victory: bool = true
var cached_floor: int = 1

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_build_ui()
	hide()

func _build_ui() -> void:
	# 1. Overlay nền đen mờ bao phủ toàn màn hình
	dim_bg = ColorRect.new()
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.75)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim_bg)

	# 2. Container căn giữa
	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_container)

	# 3. PanelContainer bảng trung tâm
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 460)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.12, 0.16, 0.98)
	panel_style.set_corner_radius_all(14)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 4
	panel_style.border_color = Color(0.24, 0.32, 0.42)
	panel_style.content_margin_left = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_right = 24
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(panel)

	# 4. Bố cục dọc bên trong Panel
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(main_vbox)

	# Header: Tiêu đề kết quả
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "THỐNG KÊ CHIẾN ĐẤU & ĐÓNG GÓP ĐỘI HÌNH"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color("95a5a6"))
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(subtitle_label)

	# 5. Thanh Tab chuyển đổi (Damage, Taken, Heal)
	tab_container = HBoxContainer.new()
	tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_container.add_theme_constant_override("separation", 12)
	main_vbox.add_child(tab_container)

	damage_tab_btn = _create_tab_button("⚔️ SÁT THƯƠNG", MetricTab.DAMAGE)
	taken_tab_btn = _create_tab_button("🛡️ GÁNH CHỊU", MetricTab.TAKEN)
	heal_tab_btn = _create_tab_button("💚 HỒI PHỤC", MetricTab.HEAL)

	tab_container.add_child(damage_tab_btn)
	tab_container.add_child(taken_tab_btn)
	tab_container.add_child(heal_tab_btn)

	# 6. Danh sách các hàng Tướng
	rows_container = VBoxContainer.new()
	rows_container.add_theme_constant_override("separation", 10)
	rows_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(rows_container)

	# 7. Nút Tiếp tục / Chơi lại ở chân bảng
	var footer_box := HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(footer_box)

	continue_button = Button.new()
	continue_button.custom_minimum_size = Vector2(240, 44)
	continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	continue_button.pressed.connect(_on_continue_pressed)
	footer_box.add_child(continue_button)

func _create_tab_button(text_str: String, tab_type: MetricTab) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = Vector2(150, 34)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func(): _switch_tab(tab_type))
	return btn

func _style_tab_buttons() -> void:
	var tabs: Array[Button] = [damage_tab_btn, taken_tab_btn, heal_tab_btn]
	for i in range(tabs.size()):
		var btn: Button = tabs[i]
		var is_active: bool = (i == int(active_tab))
		
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		if is_active:
			sb.bg_color = Color(0.20, 0.28, 0.38)
			sb.border_width_bottom = 3
			sb.border_color = Color(0.35, 0.65, 0.95)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			sb.bg_color = Color(0.12, 0.14, 0.18)
			sb.border_width_bottom = 0
			btn.add_theme_color_override("font_color", Color("7f8c8d"))
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)

func _switch_tab(new_tab: MetricTab) -> void:
	active_tab = new_tab
	_style_tab_buttons()
	_render_hero_rows()

func show_summary(is_victory: bool, floor_number: int, all_heroes: Array) -> void:
	cached_is_victory = is_victory
	cached_floor = floor_number
	cached_heroes = all_heroes.duplicate()
	
	if is_victory:
		title_label.text = "🏆 CHIẾN THẮNG — TẦNG %d" % floor_number
		title_label.add_theme_color_override("font_color", Color("f1c40f"))
		continue_button.text = "TIẾP TỤC  ➔"
		_style_continue_button(Color("27ae60"), Color("2ecc71"))
	else:
		title_label.text = "❌ THẤT TRẬN — TẦNG %d" % floor_number
		title_label.add_theme_color_override("font_color", Color("e74c3c"))
		continue_button.text = "CHƠI LẠI TỪ ĐẦU  🔄"
		_style_continue_button(Color("c0392b"), Color("e74c3c"))

	active_tab = MetricTab.DAMAGE
	_style_tab_buttons()
	_render_hero_rows()
	show()

func _style_continue_button(base_color: Color, hover_color: Color) -> void:
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = base_color
	normal_sb.set_corner_radius_all(8)
	normal_sb.border_width_bottom = 3
	normal_sb.border_color = base_color.darkened(0.2)
	continue_button.add_theme_stylebox_override("normal", normal_sb)

	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = hover_color
	hover_sb.set_corner_radius_all(8)
	hover_sb.border_width_bottom = 3
	hover_sb.border_color = base_color
	continue_button.add_theme_stylebox_override("hover", hover_sb)
	continue_button.add_theme_stylebox_override("pressed", normal_sb)
	continue_button.add_theme_font_size_override("font_size", 15)

func _get_hero_metric_value(hero: HeroEntity, tab: MetricTab) -> float:
	if hero == null or hero.metrics == null:
		return 0.0
	match tab:
		MetricTab.DAMAGE:
			return hero.metrics.damage_dealt
		MetricTab.TAKEN:
			return hero.metrics.damage_taken
		MetricTab.HEAL:
			return hero.metrics.healing_done
	return 0.0

func _render_hero_rows() -> void:
	for child in rows_container.get_children():
		rows_container.remove_child(child)
		child.queue_free()

	if cached_heroes.is_empty():
		return

	# Thuật toán Normalize: Tìm giá trị cao nhất và tổng giá trị của toàn đội
	var max_val: float = 0.0
	var total_val: float = 0.0
	for h in cached_heroes:
		if h is HeroEntity:
			var v := _get_hero_metric_value(h as HeroEntity, active_tab)
			if v > max_val:
				max_val = v
			total_val += v

	var safe_max: float = max_val if max_val > 0.0 else 1.0

	# Màu sắc của thanh đo theo từng Tab
	var fill_color: Color
	match active_tab:
		MetricTab.DAMAGE:
			fill_color = Color("e74c3c") # Đỏ
		MetricTab.TAKEN:
			fill_color = Color("95a5a6") # Xám bạc
		MetricTab.HEAL:
			fill_color = Color("2ecc71") # Xanh ngọc

	for h in cached_heroes:
		if not (h is HeroEntity):
			continue
		var hero := h as HeroEntity
		var val := _get_hero_metric_value(hero, active_tab)
		var pct: float = (val / total_val * 100.0) if total_val > 0.0 else 0.0

		var row := _create_hero_row(hero, val, safe_max, pct, fill_color)
		rows_container.add_child(row)

func _create_hero_row(hero: HeroEntity, val: float, max_val: float, pct: float, fill_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	# 1. Cột Tên & Class (Cố định width 150px)
	var name_box := VBoxContainer.new()
	name_box.custom_minimum_size = Vector2(150, 0)
	
	var name_lbl := Label.new()
	var dead_tag: String = " ☠️" if hero.is_dead else ""
	name_lbl.text = hero.name + dead_tag
	name_lbl.add_theme_font_size_override("font_size", 14)
	if hero.is_dead:
		name_lbl.add_theme_color_override("font_color", Color("7f8c8d"))
	name_box.add_child(name_lbl)

	var class_lbl := Label.new()
	var class_name_str: String = HeroData.HeroClass.keys()[hero.data.hero_class] if hero.data != null else "HERO"
	var level_val: int = hero.progression.current_level if hero.progression != null else 1
	class_lbl.text = "%s  •  Lv.%d" % [class_name_str, level_val]
	class_lbl.add_theme_font_size_override("font_size", 11)
	class_lbl.add_theme_color_override("font_color", Color("95a5a6"))
	name_box.add_child(class_lbl)
	row.add_child(name_box)

	# 2. Cột ProgressBar (Co dãn chiếm trọn không gian giữa)
	var bar_container := MarginContainer.new()
	bar_container.name = "BarContainer"
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bar := ProgressBar.new()
	bar.name = "ProgressBar"
	bar.custom_minimum_size = Vector2(180, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.max_value = max_val
	bar.value = val

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.08, 0.10, 0.13)
	bg_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg_sb)

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_sb)

	bar_container.add_child(bar)
	row.add_child(bar_container)

	# 3. Cột Số liệu & Tỷ lệ % (Cố định width 110px)
	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(110, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.text = "%d  (%.0f%%)" % [roundi(val), pct]
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", Color("ecf0f1"))
	row.add_child(val_lbl)

	return row

func _on_continue_pressed() -> void:
	hide()
	continued.emit()
