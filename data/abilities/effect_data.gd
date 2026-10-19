class_name EffectData
extends Resource

# ==============================================================================
# EFFECT DATA - SCALING & BBCODE FRAMEWORK (SPRINT 4 & 5)
# ==============================================================================

const STAT_AD: String = "AD"
const STAT_AP: String = "AP"
const STAT_HP: String = "HP"
const STAT_ARM: String = "ARM"

# SPRINT 5: DETAILED TOTAL VS BONUS STAT SCALING (GD & QA SPEC)
const STAT_TOTAL_AD: String = "TOTAL_AD"
const STAT_BONUS_AD: String = "BONUS_AD"
const STAT_TOTAL_AP: String = "TOTAL_AP"
const STAT_BONUS_AP: String = "BONUS_AP"
const STAT_TOTAL_HP: String = "TOTAL_HP"
const STAT_BONUS_ARM: String = "BONUS_ARM"

# Hệ màu BBCode chuẩn thị giác (Riot Games Palette)
const COLOR_AD: String = "#e74c3c"   # Cam Đỏ (SMCK)
const COLOR_AP: String = "#9b59b6"   # Tím Phép thuật (SMPT)
const COLOR_HP: String = "#2ecc71"   # Xanh Lục (Máu tối đa)
const COLOR_ARM: String = "#f1c40f"  # Vàng Đất (Giáp)

const STAT_NAMES: Dictionary = {
	STAT_AD: "SMCK",
	STAT_AP: "SMPT",
	STAT_HP: "Máu tối đa",
	STAT_ARM: "Giáp",
	STAT_TOTAL_AD: "SMCK",
	STAT_BONUS_AD: "SMCK cộng thêm",
	STAT_TOTAL_AP: "SMPT",
	STAT_BONUS_AP: "SMPT cộng thêm",
	STAT_TOTAL_HP: "Máu tối đa",
	STAT_BONUS_ARM: "Giáp cộng thêm"
}

const STAT_COLORS: Dictionary = {
	STAT_AD: COLOR_AD,
	STAT_AP: COLOR_AP,
	STAT_HP: COLOR_HP,
	STAT_ARM: COLOR_ARM,
	STAT_TOTAL_AD: COLOR_AD,
	STAT_BONUS_AD: COLOR_AD,
	STAT_TOTAL_AP: COLOR_AP,
	STAT_BONUS_AP: COLOR_AP,
	STAT_TOTAL_HP: COLOR_HP,
	STAT_BONUS_ARM: COLOR_ARM
}

@export var base_amount: float = 0.0
@export var scalings: Dictionary = {} # e.g. {"AD": 0.8, "AP": 0.2, "TOTAL_AD": 0.2}

func _get_stat_value(source: CombatEntity, stat_key: String) -> float:
	if source == null: return 0.0
	match stat_key:
		STAT_AD, STAT_TOTAL_AD:
			return source.get_attack() if source.has_method("get_attack") else (source.data.base_attack if source.data != null else 0.0)
		STAT_BONUS_AD:
			var cur_ad: float = source.get_attack() if source.has_method("get_attack") else (source.data.base_attack if source.data != null else 0.0)
			var base_ad: float = source.data.base_attack if source.data != null else 10.0
			return maxf(0.0, cur_ad - base_ad)
		STAT_AP, STAT_TOTAL_AP:
			return source.get_spell_power() if source.has_method("get_spell_power") else (source.data.base_spell_power if (source.data != null and "base_spell_power" in source.data) else 0.0)
		STAT_BONUS_AP:
			var cur_ap: float = source.get_spell_power() if source.has_method("get_spell_power") else (source.data.base_spell_power if (source.data != null and "base_spell_power" in source.data) else 0.0)
			var base_ap: float = source.data.base_spell_power if (source.data != null and "base_spell_power" in source.data) else 10.0
			return maxf(0.0, cur_ap - base_ap)
		STAT_HP, STAT_TOTAL_HP:
			return source.max_hp
		STAT_ARM:
			return source.get_defense() if source.has_method("get_defense") else (source.data.base_defense if source.data != null else 0.0)
		STAT_BONUS_ARM:
			var cur_arm: float = source.get_defense() if source.has_method("get_defense") else (source.data.base_defense if source.data != null else 0.0)
			var base_arm: float = source.data.base_defense if source.data != null else 0.0
			return maxf(0.0, cur_arm - base_arm)
		_:
			return 0.0

static func fmt_val(val: float) -> String:
	if is_equal_approx(val, roundf(val)):
		return "%.0f" % val
	return "%.1f" % val

func calculate_total_value(source: CombatEntity = null) -> float:
	var total: float = base_amount
	if source == null:
		return total
		
	for stat_key in scalings.keys():
		var ratio: float = float(scalings[stat_key])
		total += _get_stat_value(source, stat_key) * ratio
	return total

func _build_scale_string(source: CombatEntity = null) -> String:
	if scalings.is_empty():
		return ""
		
	var standard_keys = [
		STAT_TOTAL_AD, STAT_BONUS_AD, STAT_AD,
		STAT_TOTAL_AP, STAT_BONUS_AP, STAT_AP,
		STAT_TOTAL_HP, STAT_HP,
		STAT_BONUS_ARM, STAT_ARM
	]
	
	# 1. Pure % Skill (Base Amount == 0): " = (X% ...)"
	if base_amount == 0.0:
		var parts: Array[String] = []
		for stat_key in standard_keys:
			if scalings.has(stat_key):
				var ratio: float = float(scalings[stat_key])
				if ratio > 0.0:
					var pct := int(round(ratio * 100.0))
					var name_str: String = STAT_NAMES.get(stat_key, stat_key)
					parts.append("%d%% %s" % [pct, name_str])
		for stat_key in scalings.keys():
			if not stat_key in standard_keys:
				var ratio: float = float(scalings[stat_key])
				if ratio > 0.0:
					var pct := int(round(ratio * 100.0))
					parts.append("%d%% %s" % [pct, stat_key])
		if parts.is_empty():
			return ""
		return " = (" + " + ".join(parts) + ")"
		
	var has_advanced: bool = false
	for k in [STAT_TOTAL_AD, STAT_BONUS_AD, STAT_TOTAL_AP, STAT_BONUS_AP, STAT_TOTAL_HP, STAT_BONUS_ARM]:
		if scalings.has(k):
			has_advanced = true
			break
			
	# 2. LMHT Breakdown Syntax: " = ([Base] + [Bonus] [Ratio% Stat])"
	if has_advanced and source != null:
		var base_str := "[color=#bdc3c7]%s[/color]" % fmt_val(base_amount)
		var bonus_parts: Array[String] = []
		for stat_key in standard_keys:
			if scalings.has(stat_key):
				var ratio: float = float(scalings[stat_key])
				if ratio > 0.0:
					var pct := int(round(ratio * 100.0))
					var col: String = STAT_COLORS.get(stat_key, "#ffffff")
					var name_str: String = STAT_NAMES.get(stat_key, stat_key)
					var scale_val: float = _get_stat_value(source, stat_key) * ratio
					var bonus_str := "[color=%s]%s[/color] [%d%% %s]" % [col, fmt_val(scale_val), pct, name_str]
					bonus_parts.append(bonus_str)
		for stat_key in scalings.keys():
			if not stat_key in standard_keys:
				var ratio: float = float(scalings[stat_key])
				if ratio > 0.0:
					var pct := int(round(ratio * 100.0))
					var scale_val: float = _get_stat_value(source, stat_key) * ratio
					var bonus_str := "%.1f [%d%% %s]" % [scale_val, pct, stat_key]
					bonus_parts.append(bonus_str)
		if bonus_parts.is_empty():
			return ""
		return " = (%s + %s)" % [base_str, " + ".join(bonus_parts)]
		
	# 3. Legacy Keys (AD, AP, HP, ARM) - Maintains 100% TC-17 exact syntax
	var scale_parts: Array[String] = []
	for stat_key in standard_keys:
		if scalings.has(stat_key):
			var ratio: float = float(scalings[stat_key])
			if ratio > 0.0:
				var pct := int(round(ratio * 100.0))
				var col: String = STAT_COLORS.get(stat_key, "#ffffff")
				var name_str: String = STAT_NAMES.get(stat_key, stat_key)
				scale_parts.append("[color=%s]+%d%% %s[/color]" % [col, pct, name_str])
				
	for stat_key in scalings.keys():
		if not stat_key in standard_keys:
			var ratio: float = float(scalings[stat_key])
			if ratio > 0.0:
				var pct := int(round(ratio * 100.0))
				scale_parts.append("+%d%% %s" % [pct, stat_key])
				
	if scale_parts.is_empty():
		return ""
	return " (" + " + ".join(scale_parts) + ")"

func get_formatted_description(source: CombatEntity = null) -> String:
	var total_val := calculate_total_value(source)
	var scale_str := _build_scale_string(source)
	return _build_action_text(total_val, scale_str)

func get_inline_value_bbcode(source: CombatEntity = null) -> String:
	var total_val := calculate_total_value(source)
	var scale_str := _build_scale_string(source)
		
	var val_color: String = "#ff5555"
	if "damage_type" in self:
		var dmg_type = self.get("damage_type")
		val_color = "#ff5555" if dmg_type == DamageEvent.DamageType.PHYSICAL else "#9b59b6"
	elif "heal_amount" in self or "shield_amount" in self:
		val_color = "#2ecc71"
		
	return "[color=%s][b]%.0f[/b][/color]%s" % [val_color, total_val, scale_str]

func _build_action_text(total_val: float, scale_str: String) -> String:
	return "Tác dụng [color=#ff5555][b]%.0f[/b][/color]%s." % [total_val, scale_str]
