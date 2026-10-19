class_name EffectData
extends Resource

# ==============================================================================
# EFFECT DATA - SCALING & BBCODE FRAMEWORK (SPRINT 4 - TASK S4.1)
# ==============================================================================

const STAT_AD: String = "AD"
const STAT_AP: String = "AP"
const STAT_HP: String = "HP"
const STAT_ARM: String = "ARM"

# Hệ màu BBCode chuẩn thị giác (Riot Games Palette)
const COLOR_AD: String = "#e74c3c"   # Cam Đỏ (SMCK)
const COLOR_AP: String = "#9b59b6"   # Tím Phép thuật (SMPT)
const COLOR_HP: String = "#2ecc71"   # Xanh Lục (Máu tối đa)
const COLOR_ARM: String = "#f1c40f"  # Vàng Đất (Giáp)

const STAT_NAMES: Dictionary = {
	STAT_AD: "SMCK",
	STAT_AP: "SMPT",
	STAT_HP: "Máu tối đa",
	STAT_ARM: "Giáp"
}

const STAT_COLORS: Dictionary = {
	STAT_AD: COLOR_AD,
	STAT_AP: COLOR_AP,
	STAT_HP: COLOR_HP,
	STAT_ARM: COLOR_ARM
}

@export var base_amount: float = 0.0
@export var scalings: Dictionary = {} # e.g. {"AD": 0.8, "AP": 0.2}

func calculate_total_value(source: CombatEntity = null) -> float:
	var total: float = base_amount
	if source == null:
		return total
		
	for stat_key in scalings.keys():
		var ratio: float = float(scalings[stat_key])
		match stat_key:
			STAT_AD:
				var ad_val: float = source.get_attack() if source.has_method("get_attack") else (source.data.base_attack if source.data != null else 0.0)
				total += ad_val * ratio
			STAT_AP:
				var ap_val: float = source.get_spell_power() if source.has_method("get_spell_power") else (source.data.base_spell_power if (source.data != null and "base_spell_power" in source.data) else 0.0)
				total += ap_val * ratio
			STAT_HP:
				total += source.max_hp * ratio
			STAT_ARM:
				var arm_val: float = source.get_defense() if source.has_method("get_defense") else (source.data.base_defense if source.data != null else 0.0)
				total += arm_val * ratio
	return total

func get_formatted_description(source: CombatEntity = null) -> String:
	var total_val := calculate_total_value(source)
	var scale_parts: Array[String] = []
	
	# Duyệt theo thứ tự chuẩn AD -> AP -> HP -> ARM
	for stat_key in [STAT_AD, STAT_AP, STAT_HP, STAT_ARM]:
		if scalings.has(stat_key):
			var ratio: float = float(scalings[stat_key])
			if ratio > 0.0:
				var pct := int(round(ratio * 100.0))
				var col: String = STAT_COLORS.get(stat_key, "#ffffff")
				var name_str: String = STAT_NAMES.get(stat_key, stat_key)
				scale_parts.append("[color=%s]+%d%% %s[/color]" % [col, pct, name_str])
				
	for stat_key in scalings.keys():
		if not stat_key in [STAT_AD, STAT_AP, STAT_HP, STAT_ARM]:
			var ratio: float = float(scalings[stat_key])
			if ratio > 0.0:
				var pct := int(round(ratio * 100.0))
				scale_parts.append("+%d%% %s" % [pct, stat_key])
				
	var scale_str := ""
	if scale_parts.size() > 0:
		scale_str = " (" + " + ".join(scale_parts) + ")"
		
	return _build_action_text(total_val, scale_str)

func get_inline_value_bbcode(source: CombatEntity = null) -> String:
	var total_val := calculate_total_value(source)
	var scale_parts: Array[String] = []
	
	for stat_key in [STAT_AD, STAT_AP, STAT_HP, STAT_ARM]:
		if scalings.has(stat_key):
			var ratio: float = float(scalings[stat_key])
			if ratio > 0.0:
				var pct := int(round(ratio * 100.0))
				var col: String = STAT_COLORS.get(stat_key, "#ffffff")
				var name_str: String = STAT_NAMES.get(stat_key, stat_key)
				scale_parts.append("[color=%s]+%d%% %s[/color]" % [col, pct, name_str])
				
	for stat_key in scalings.keys():
		if not stat_key in [STAT_AD, STAT_AP, STAT_HP, STAT_ARM]:
			var ratio: float = float(scalings[stat_key])
			if ratio > 0.0:
				var pct := int(round(ratio * 100.0))
				scale_parts.append("+%d%% %s" % [pct, stat_key])
				
	var scale_str := ""
	if scale_parts.size() > 0:
		scale_str = " (" + " + ".join(scale_parts) + ")"
		
	var val_color: String = "#ff5555"
	if self is DamageEffectData:
		var dmg_eff = self as DamageEffectData
		val_color = "#ff5555" if dmg_eff.damage_type == DamageEvent.DamageType.PHYSICAL else "#9b59b6"
	elif self is HealEffectData:
		val_color = "#2ecc71"
		
	return "[color=%s][b]%.0f[/b][/color]%s" % [val_color, total_val, scale_str]

func _build_action_text(total_val: float, scale_str: String) -> String:
	return "Tác dụng [color=#ff5555][b]%.0f[/b][/color]%s." % [total_val, scale_str]
