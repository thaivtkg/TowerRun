class_name EnemyData
extends Resource

enum EnemyRank { NORMAL, ELITE, BOSS }

@export var id: String = ""
@export var name: String = "Unknown Enemy"
@export var rank: EnemyRank = EnemyRank.NORMAL

@export_group("Base Stats")
@export var base_hp: float = 50.0
@export var base_attack: float = 5.0
@export var base_spell_power: float = 10.0
@export var base_defense: float = 2.0
@export var attack_speed: float = 1.0
@export var attack_range: int = 1
@export var crit_chance: float = 0.0
@export var crit_damage: float = 2.0

@export_group("Energy & Skills")
@export var starting_energy: float = 0.0
@export var max_energy: float = 100.0
@export var abilities: Array[AbilityData] = []
