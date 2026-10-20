class_name AbilityData
extends Resource

enum AbilityType { PASSIVE, ACTIVE, ULTIMATE }

enum TargetRule {
	SELF, SINGLE_ENEMY, LOWEST_HP_ENEMY, NEAREST_ENEMY,
	SINGLE_ALLY, LOWEST_HP_ALLY, ALL_ENEMIES, ALL_ALLIES,
	FURTHEST_ENEMY, LOWEST_HP_PERCENT_ENEMY, DENSEST_ENEMY_CLUSTER
}

enum AoEShape {
	SINGLE,
	HEX_RADIUS
}

# [ADDED] Các điều kiện để kích hoạt Passive
enum TriggerCondition {
	NONE,               # Dành cho Active/Ultimate
	ON_ATTACK,          # Khi tung đòn đánh
	ON_CRIT,            # Khi đòn đánh nổ Chí mạng
	ON_KILL,            # Khi kết liễu mục tiêu
	ON_TAKE_DAMAGE      # Khi bị nhận sát thương
}

enum AbilityTag {
	NONE = 0, CRIT = 1 << 0, BLEED = 1 << 1, EXECUTE = 1 << 2, 
	AOE = 1 << 3, DEFENSE = 1 << 4, HEAL = 1 << 5, BUFF = 1 << 6, 
	DEBUFF = 1 << 7, MOBILITY = 1 << 8, CONTROL = 1 << 9
}

@export var id: String = "ability_id"
@export var name: String = "New Ability"
@export_multiline var description: String = ""
@export var ability_type: AbilityType = AbilityType.ACTIVE
@export var target_rule: TargetRule = TargetRule.SINGLE_ENEMY
@export var aoe_shape: AoEShape = AoEShape.SINGLE
@export var aoe_radius: int = 1
@export var trigger_condition: TriggerCondition = TriggerCondition.NONE # [ADDED]

@export_flags("Crit", "Bleed", "Execute", "AoE", "Defense", "Heal", "Buff", "Debuff", "Mobility", "Control") var tags: int = 0

@export_group("Requirements")
@export var cooldown: float = 5.0
@export var energy_cost: float = 0.0

@export_group("Effects")
@export var effects: Array[EffectData] = []

@export_group("4-Tier Tooltip (LMHT / TFT Standard)")
@export_multiline var narrative_template: String = ""
@export_multiline var caveat: String = ""
@export var progression_ranks: Dictionary = {}
@export var current_rank: int = 1

func get_target_rule_string() -> String:
	match target_rule:
		TargetRule.SINGLE_ENEMY:
			return "mục tiêu"
		TargetRule.ALL_ENEMIES:
			return "toàn bộ kẻ địch trên sàn đấu"
		TargetRule.LOWEST_HP_ENEMY:
			return "kẻ địch thấp máu nhất"
		TargetRule.DENSEST_ENEMY_CLUSTER:
			return "cụm kẻ địch đông nhất"
		TargetRule.NEAREST_ENEMY:
			return "kẻ địch gần nhất"
		TargetRule.SINGLE_ALLY:
			return "đồng minh"
		TargetRule.LOWEST_HP_ALLY:
			return "đồng minh thấp máu nhất"
		TargetRule.ALL_ALLIES:
			return "toàn bộ đồng minh"
		TargetRule.SELF:
			return "bản thân"
		_:
			return "mục tiêu"

func _calculate_active_rank_index(source: CombatEntity, max_ranks: int) -> int:
	if max_ranks <= 0:
		return 0
	if source != null:
		var lvl: int = 1
		if source.has_method("get_effective_level"):
			lvl = source.get_effective_level()
		elif "level" in source:
			lvl = int(source.level)
			
		if max_ranks == 3:
			if lvl >= 25 or lvl == 3:
				return 2
			elif lvl >= 10 or lvl == 2:
				return 1
			else:
				return 0
		else:
			return clampi(lvl - 1, 0, max_ranks - 1)
			
	if current_rank > 0:
		return clampi(current_rank - 1, 0, max_ranks - 1)
	return 0

func get_formatted_tooltip(source: CombatEntity = null, include_progression: bool = true) -> String:
	if narrative_template != "":
		var hero_name := "Tướng"
		if source != null:
			if "data" in source and source.data != null and "name" in source.data and str(source.data.name) != "":
				hero_name = str(source.data.name)
			elif "name" in source and str(source.name) != "":
				hero_name = str(source.name)
				
		var target_str := get_target_rule_string()
		var text := narrative_template
		text = text.replace("{hero}", hero_name)
		text = text.replace("{action_target}", target_str)
		
		for i in range(effects.size()):
			var eff := effects[i]
			var inline_val := eff.get_inline_value_bbcode(source) if eff != null else ""
			text = text.replace("{%d}" % i, inline_val)
			text = text.replace("{formula:%d}" % i, inline_val)
			
		if text.contains("{radius}"):
			text = text.replace("{radius}", str(aoe_radius))
			
		var result := text
		
		# Tầng 3: Rule Caveats / Ghi chú ngoại lệ
		if caveat != "":
			var parsed_caveat := caveat
			parsed_caveat = parsed_caveat.replace("{hero}", hero_name)
			parsed_caveat = parsed_caveat.replace("{action_target}", target_str)
			result += "\n\n[color=#a4b0be][i]%s[/i][/color]" % parsed_caveat
			
		# Tầng 4: Progression Table (Bảng thăng tiến đa mốc)
		if include_progression and not progression_ranks.is_empty():
			var prog_entries: Array[String] = []
			for key in progression_ranks.keys():
				var ranks: Array = progression_ranks[key]
				var rank_strs: Array[String] = []
				var active_idx := _calculate_active_rank_index(source, ranks.size())
				for idx in range(ranks.size()):
					var val_str := str(ranks[idx])
					if idx == active_idx:
						rank_strs.append("[b][color=#f1c40f]%s[/color][/b]" % val_str)
					else:
						rank_strs.append(val_str)
				prog_entries.append("%s: [%s]" % [key, " / ".join(rank_strs)])
				
			result += "\n\n[color=#7f8c8d]─── Tiến trình theo cấp ───[/color]\n" + " | ".join(prog_entries)
			
		return result
	if description != "" and description.contains("{0}"):
		var result: String = description
		for i in range(effects.size()):
			var placeholder := "{%d}" % i
			if result.contains(placeholder):
				var eff := effects[i]
				var replacement := eff.get_inline_value_bbcode(source) if eff != null else ""
				result = result.replace(placeholder, replacement)
		return result
		
	# Fallback tương thích ngược (nếu không có {0} hoặc effects rỗng)
	if effects.is_empty():
		return description if description != "" else "Kỹ năng đặc biệt."
		
	var lines: Array[String] = []
	for effect in effects:
		if effect != null:
			lines.append(effect.get_formatted_description(source))
			
	if lines.is_empty():
		return description if description != "" else "Kỹ năng đặc biệt."
	return "\n".join(lines)
