class_name SkillData
extends Resource

@export var id: String = ""
@export var name: String = "Unknown Skill"
@export_multiline var description: String = ""

@export_group("Combat Stats")
@export var cooldown: float = 0.0
@export var base_damage: float = 0.0
@export var mana_cost: float = 0.0
