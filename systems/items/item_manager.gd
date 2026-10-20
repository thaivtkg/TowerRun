extends Node

# ==========================================
# ITEM MANAGER - ARTIFACT RECIPES & CRAFTING
# Sprint 6 - Task S6.1
# ==========================================

static var instance: ItemManager = null

# 4 Core Components
const BLOODSTEEL_SHARD: Resource = preload("res://data/items/bloodsteel_shard.tres")
const SORCERY_CRYSTAL: Resource = preload("res://data/items/sorcery_crystal.tres")
const OBSIDIAN_PLATING: Resource = preload("res://data/items/obsidian_plating.tres")
const SOUL_AETHER_BEAD: Resource = preload("res://data/items/soul_aether_bead.tres")

# 6 Core Completed Items
const SOUL_SEVERING_BLADE: Resource = preload("res://data/items/soul_severing_blade.tres")
const BLOOD_RUNIC_BLADE: Resource = preload("res://data/items/blood_runic_blade.tres")
const THORN_OBSIDIAN_SHIELD: Resource = preload("res://data/items/thorn_obsidian_shield.tres")
const VOID_CELESTIAL_ORB: Resource = preload("res://data/items/void_celestial_orb.tres")
const ORIGIN_ANCIENT_STAFF: Resource = preload("res://data/items/origin_ancient_staff.tres")
const FROST_PRISON_HEART: Resource = preload("res://data/items/frost_prison_heart.tres")

var items_by_id: Dictionary = {}
var recipe_matrix: Dictionary = {}

func _init() -> void:
	instance = self
	_setup_registry()

func _ready() -> void:
	instance = self
	if items_by_id.is_empty():
		_setup_registry()

func _setup_registry() -> void:
	var all_items: Array[ItemData] = [
		BLOODSTEEL_SHARD as ItemData,
		SORCERY_CRYSTAL as ItemData,
		OBSIDIAN_PLATING as ItemData,
		SOUL_AETHER_BEAD as ItemData,
		SOUL_SEVERING_BLADE as ItemData,
		BLOOD_RUNIC_BLADE as ItemData,
		THORN_OBSIDIAN_SHIELD as ItemData,
		VOID_CELESTIAL_ORB as ItemData,
		ORIGIN_ANCIENT_STAFF as ItemData,
		FROST_PRISON_HEART as ItemData
	]
	
	items_by_id.clear()
	recipe_matrix.clear()
	
	for it in all_items:
		if it != null and it.id != "":
			items_by_id[it.id] = it
			if not it.is_component and it.recipe.size() == 2:
				var key := get_recipe_key(it.recipe[0], it.recipe[1])
				recipe_matrix[key] = it

static func get_recipe_key(id_a: String, id_b: String) -> String:
	var pair: Array[String] = [id_a, id_b]
	pair.sort()
	return "%s+%s" % [pair[0], pair[1]]

func get_item_by_id(id: String) -> ItemData:
	return items_by_id.get(id, null)

func combine(item_a: ItemData, item_b: ItemData) -> ItemData:
	if item_a == null or item_b == null:
		return null
	var key := get_recipe_key(item_a.id, item_b.id)
	return recipe_matrix.get(key, null)

func combine_ids(id_a: String, id_b: String) -> ItemData:
	var key := get_recipe_key(id_a, id_b)
	return recipe_matrix.get(key, null)
