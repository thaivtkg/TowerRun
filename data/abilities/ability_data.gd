class_name AbilityData
extends Resource

enum AbilityType { PASSIVE, ACTIVE, ULTIMATE }

enum TargetRule {
	SELF, SINGLE_ENEMY, LOWEST_HP_ENEMY, NEAREST_ENEMY,
	SINGLE_ALLY, LOWEST_HP_ALLY, ALL_ENEMIES, ALL_ALLIES
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
@export var trigger_condition: TriggerCondition = TriggerCondition.NONE # [ADDED]

@export_flags("Crit", "Bleed", "Execute", "AoE", "Defense", "Heal", "Buff", "Debuff", "Mobility", "Control") var tags: int = 0

@export_group("Requirements")
@export var cooldown: float = 5.0
@export var energy_cost: float = 0.0

@export_group("Effects")
@export var effects: Array[EffectData] = []
