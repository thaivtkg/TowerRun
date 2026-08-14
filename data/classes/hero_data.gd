class_name HeroData
extends Resource

enum HeroClass { TANK, FIGHTER, ASSASSIN, MAGE, MARKSMAN, SUPPORT }

@export var id: String = ""
@export var name: String = "Unknown Hero"
@export var hero_class: HeroClass = HeroClass.FIGHTER

@export_group("Base Stats")
@export var base_hp: float = 100.0
@export var base_attack: float = 10.0
@export var base_defense: float = 0.0
@export var attack_speed: float = 1.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 2.0
@export var attack_range: float = 1.0 

@export_group("Core Abilities")
@export var basic_attack: AbilityData 
# Các kỹ năng đã được unlock trong run hiện tại sẽ được lưu vào runtime state (HeroEntity), 
# không lưu cứng ở đây để bảo toàn Resource gốc.

@export_group("Milestone Skill Pools")
@export var pool_lv5_passives: Array[AbilityData] = []
@export var pool_lv10_actives: Array[AbilityData] = []
@export var pool_lv15_utilities: Array[AbilityData] = []
@export var pool_lv20_upgrades: Array[AbilityData] = []
@export var pool_lv25_signatures: Array[AbilityData] = []
