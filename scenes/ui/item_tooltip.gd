class_name ItemTooltip
extends PanelContainer

# ==========================================
# ITEM TOOLTIP - DYNAMIC BBCODE 2-TIER SYSTEM
# Sprint 6 - Task S6.2.3 & S6.3
# ==========================================

var title_label: Label = null
var stats_label: RichTextLabel = null
var passive_container: Control = null
var passive_label: RichTextLabel = null

func _ready() -> void:
	if stats_label == null:
		_setup_dynamic_ui()

func _setup_dynamic_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240, 100)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.95)
	style.set_corner_radius_all(8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.22, 0.74, 0.97, 0.5)
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	
	stats_label = RichTextLabel.new()
	stats_label.name = "StatsLabel"
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_label)

static func format_tooltip_text(item: ItemData) -> String:
	if item == null:
		return ""
		
	var lines: Array[String] = []
	
	# 1. Tiêu đề theo Bậc
	var tier_tag: String = ""
	match item.tier:
		1: tier_tag = "[color=#94a3b8][Bậc 1: Mảnh][/color]"
		2: tier_tag = "[color=#38bdf8][Bậc 2: Cổ Vật][/color]"
		3: tier_tag = "[wave amp=15 freq=3][color=#fbbf24]👑 [Bậc 3: Thần Thoại][/color][/wave]"
		_: tier_tag = ""
	lines.append("%s [b]%s[/b]" % [tier_tag, item.name])
	
	# 2. Khối Chỉ Số
	var stat_lines: Array[String] = []
	if item.get_bonus_ad() > 0.0:
		stat_lines.append("[color=#f87171]⚔️ +%d Sức Mạnh Công Kích[/color]" % int(item.get_bonus_ad()))
	if item.get_bonus_ap() > 0.0:
		stat_lines.append("[color=#60a5fa]🔮 +%d Sức Mạnh Phép Thuật[/color]" % int(item.get_bonus_ap()))
	if item.get_bonus_armor() > 0.0:
		stat_lines.append("[color=#fbbf24]🛡️ +%d Giáp[/color]" % int(item.get_bonus_armor()))
	if item.get_bonus_hp() > 0.0:
		stat_lines.append("[color=#4ade80]💚 +%d Máu Tối Đa[/color]" % int(item.get_bonus_hp()))
	if item.get_starting_energy() > 0.0:
		stat_lines.append("[color=#38bdf8]⚡ +%d Năng Lượng Khởi Đầu[/color]" % int(item.get_starting_energy()))
	if item.get_crit_chance() > 0.0:
		stat_lines.append("[color=#f43f5e]🎯 +%d%% Tỉ Lệ Chí Mạng[/color]" % int(item.get_crit_chance() * 100))
	if item.get_bonus_attack_speed() > 0.0:
		stat_lines.append("[color=#e879f9]⚡ +%d%% Tốc Độ Đánh[/color]" % int(item.get_bonus_attack_speed() * 100))
	if item.get_bonus_omnivamp() > 0.0:
		stat_lines.append("[color=#fb7185]🩸 +%d%% Hút Máu Toàn Phần[/color]" % int(item.get_bonus_omnivamp() * 100))
		
	if not stat_lines.is_empty():
		lines.append("\n".join(stat_lines))
		
	# 3. Khối Nội Tại (Nếu is_pure_stat == true: ẨN TOÀN BỘ)
	if not item.is_pure_stat:
		if item.tier == 3:
			# Bậc 3: Tầng 1 (Nội tại phụ) & Tầng 2 (Nội tại thần thoại phát sáng)
			if item.sub_passive_name != "":
				lines.append("[color=#38bdf8]⚡ %s[/color]\n%s" % [item.sub_passive_name, item.sub_passive_desc])
			if item.mythic_passive_name != "":
				lines.append("[wave amp=20 freq=3][color=#fb7185]🔥 %s[/color][/wave]\n%s" % [item.mythic_passive_name, item.mythic_passive_desc])
		elif item.tier == 2:
			if item.passive_name != "":
				lines.append("[color=#f59e0b]★ %s[/color]\n%s" % [item.passive_name, item.passive_desc])
				
	return "\n\n".join(lines)

func render_tooltip(item: ItemData) -> void:
	if item == null:
		hide()
		return
		
	if stats_label == null:
		_setup_dynamic_ui()
		
	stats_label.text = format_tooltip_text(item)
	show()
