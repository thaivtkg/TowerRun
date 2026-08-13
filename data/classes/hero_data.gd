class_name HeroData
extends Resource

enum HeroClass {
	TANK,
	FIGHTER,
	ASSASSIN,
	MAGE,
	MARKSMAN,
	SUPPORT
}

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
