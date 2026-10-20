class_name ItemData
extends Resource

# ==========================================
# ITEM DATA CORE (SPRINT 6 - TASK S6.1)
# Phong cách Dark Fantasy RPG
# ==========================================

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var is_component: bool = true
@export var recipe: Array[String] = [] # Ví dụ: ["bloodsteel_shard", "sorcery_crystal"]
@export var stat_modifiers: Dictionary = {
	"bonus_ad": 0.0,
	"bonus_ap": 0.0,
	"bonus_armor": 0.0,
	"starting_energy": 0.0,
	"crit_chance": 0.0
}
@export var passive_id: String = ""

func get_bonus_ad() -> float:
	return stat_modifiers.get("bonus_ad", 0.0)

func get_bonus_ap() -> float:
	return stat_modifiers.get("bonus_ap", 0.0)

func get_bonus_armor() -> float:
	return stat_modifiers.get("bonus_armor", 0.0)

func get_starting_energy() -> float:
	return stat_modifiers.get("starting_energy", 0.0)

func get_crit_chance() -> float:
	return stat_modifiers.get("crit_chance", 0.0)
