class_name ItemTooltip
extends PanelContainer

# ==========================================
# ITEM TOOLTIP - DYNAMIC BBCODE 2-TIER SYSTEM
# Sprint 6 - Task S6.2.3
# ==========================================

@onready var title_label: Label = get_node_or_null("VBox/TitleLabel") as Label
@onready var stats_label: RichTextLabel = get_node_or_null("VBox/StatsLabel") as RichTextLabel
@onready var passive_container: Control = get_node_or_null("VBox/PassiveContainer") as Control
@onready var passive_label: RichTextLabel = get_node_or_null("VBox/PassiveContainer/PassiveLabel") as RichTextLabel

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
		
	if title_label != null:
		title_label.text = item.name
		
	if stats_label != null:
		stats_label.text = format_tooltip_text(item)
		
	if passive_container != null:
		passive_container.visible = not item.is_pure_stat
		
	show()
