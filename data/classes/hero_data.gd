class_name HeroData
extends Resource

@export var id: String = ""
@export var name: String = "Unknown Hero"

# Tuân thủ Rule 17: Invariants Classes
@export_enum("Tank", "Fighter", "Assassin", "Mage", "Marksman", "Support") 
var hero_class: String = "Fighter"

@export_group("Base Stats")
@export var base_hp: float = 100.0
@export var base_attack: float = 10.0
@export var base_defense: float = 5.0
@export var attack_speed: float = 1.0 # Số đòn đánh mỗi giây
@export var attack_range: float = 1.0# Đơn vị khoảng cách trên board
@export var crit_chance: float = 0.0 # Tỷ lệ chí mạng (0.0 đến 1.0)
@export var crit_damage: float = 2.0 # Sát thương chí mạng (2.0 = 200%)

@export_group("Skills")
@export var basic_attack: SkillData
@export var active_skill: SkillData
