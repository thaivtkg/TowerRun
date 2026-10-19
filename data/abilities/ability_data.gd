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

func get_formatted_tooltip(source: CombatEntity = null) -> String:
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
