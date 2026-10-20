extends Node

# ==========================================
# ITEM MANAGER - ARTIFACT RECIPES & CRAFTING
# Sprint 6 - Task S6.1 & S6.2 (Dark Fantasy RPG)
# ==========================================

static var instance = null

signal item_crafted(item: ItemData, slot_idx: int)

# 5 Core Components (Bậc 1 - 2 Từ)
const BLOODSTEEL_SHARD: Resource = preload("res://data/items/bloodsteel_shard.tres")
const SORCERY_CRYSTAL: Resource = preload("res://data/items/sorcery_crystal.tres")
const OBSIDIAN_PLATING: Resource = preload("res://data/items/obsidian_plating.tres")
const SOUL_AETHER_BEAD: Resource = preload("res://data/items/soul_aether_bead.tres")
const LIFE_STONE_SHARD: Resource = preload("res://data/items/life_stone_shard.tres")

# 8 Core Completed Artifacts (Bậc 2 - 3 Từ)
const SOUL_SEVERING_BLADE: Resource = preload("res://data/items/soul_severing_blade.tres")
const VOID_CELESTIAL_ORB: Resource = preload("res://data/items/void_celestial_orb.tres")
const COLOSSUS_VITALITY_ARMOR: Resource = preload("res://data/items/colossus_vitality_armor.tres")
const BLOOD_RUNIC_BLADE: Resource = preload("res://data/items/blood_runic_blade.tres")
const THORN_OBSIDIAN_SHIELD: Resource = preload("res://data/items/thorn_obsidian_shield.tres")
const FROST_PRISON_HEART: Resource = preload("res://data/items/frost_prison_heart.tres")
const OBSIDIAN_ARMOR: Resource = preload("res://data/items/obsidian_armor.tres")
const INFINITE_MANA_BEAD: Resource = preload("res://data/items/infinite_mana_bead.tres")
const ORIGIN_ANCIENT_STAFF: Resource = preload("res://data/items/origin_ancient_staff.tres")

# 5 Tier 3 Mythics (Bậc 3 - Tối Đa 4 Từ)
const MYTHIC_SOUL_SEVERING_BLADE: Resource = preload("res://data/items/mythic_soul_severing_blade.tres")
const MYTHIC_VOID_CELESTIAL_ORB: Resource = preload("res://data/items/mythic_void_celestial_orb.tres")
const MYTHIC_COLOSSUS_VITALITY_ARMOR: Resource = preload("res://data/items/mythic_colossus_vitality_armor.tres")
const MYTHIC_COLOSSUS_IMMORTAL: Resource = preload("res://data/items/mythic_colossus_immortal.tres")
const MYTHIC_BLOOD_RUNIC_SEVERING: Resource = preload("res://data/items/mythic_blood_runic_severing.tres")

var items_by_id: Dictionary = {}
var recipe_matrix: Dictionary = {}
var mythic_matrix: Dictionary = {}

# Hàng chờ kho đồ (10 ô)
var bench_slots: Array = []

func _init() -> void:
	instance = self
	_init_bench()
	_setup_registry()

func _ready() -> void:
	instance = self
	if bench_slots.is_empty():
		_init_bench()
	if items_by_id.is_empty():
		_setup_registry()

func _init_bench() -> void:
	bench_slots.clear()
	for i in range(10):
		bench_slots.append(null)

func _setup_registry() -> void:
	var all_items: Array[ItemData] = [
		BLOODSTEEL_SHARD as ItemData,
		SORCERY_CRYSTAL as ItemData,
		OBSIDIAN_PLATING as ItemData,
		SOUL_AETHER_BEAD as ItemData,
		LIFE_STONE_SHARD as ItemData,
		SOUL_SEVERING_BLADE as ItemData,
		VOID_CELESTIAL_ORB as ItemData,
		COLOSSUS_VITALITY_ARMOR as ItemData,
		BLOOD_RUNIC_BLADE as ItemData,
		THORN_OBSIDIAN_SHIELD as ItemData,
		FROST_PRISON_HEART as ItemData,
		OBSIDIAN_ARMOR as ItemData,
		INFINITE_MANA_BEAD as ItemData,
		ORIGIN_ANCIENT_STAFF as ItemData,
		MYTHIC_SOUL_SEVERING_BLADE as ItemData,
		MYTHIC_VOID_CELESTIAL_ORB as ItemData,
		MYTHIC_COLOSSUS_VITALITY_ARMOR as ItemData,
		MYTHIC_COLOSSUS_IMMORTAL as ItemData,
		MYTHIC_BLOOD_RUNIC_SEVERING as ItemData
	]
	
	items_by_id.clear()
	recipe_matrix.clear()
	mythic_matrix.clear()
	
	for it in all_items:
		if it != null and it.id != "":
			items_by_id[it.id] = it
			if it.recipe.size() == 2:
				var key := get_recipe_key(it.recipe[0], it.recipe[1])
				if it.tier == 3:
					mythic_matrix[key] = it
				elif it.tier == 2 or not it.is_component:
					recipe_matrix[key] = it

static func get_recipe_key(id_a: String, id_b: String) -> String:
	var pair: Array[String] = [id_a, id_b]
	pair.sort()
	return "%s+%s" % [pair[0], pair[1]]

func get_item_by_id(id: String) -> ItemData:
	return items_by_id.get(id, null)

# ==========================================
# GHÉP ĐỒ TRÊN ĐƠN VỊ (UNIT COMBINE)
# ==========================================
func combine(item_a: ItemData, item_b: ItemData) -> ItemData:
	if item_a == null or item_b == null:
		return null
	if item_a.tier == 1 and item_b.tier == 1:
		var key := get_recipe_key(item_a.id, item_b.id)
		return recipe_matrix.get(key, null)
	elif item_a.tier == 2 and item_b.tier == 2:
		return get_mythic_fusion(item_a, item_b)
	elif not item_a.is_component or not item_b.is_component:
		# Fallback cho recipe matrix
		var key := get_recipe_key(item_a.id, item_b.id)
		return recipe_matrix.get(key, null)
	return null

func combine_ids(id_a: String, id_b: String) -> ItemData:
	var key := get_recipe_key(id_a, id_b)
	if recipe_matrix.has(key):
		return recipe_matrix.get(key)
	if mythic_matrix.has(key):
		return mythic_matrix.get(key)
	return null

func get_combined_artifact(id_a: String, id_b: String) -> ItemData:
	var key := get_recipe_key(id_a, id_b)
	return recipe_matrix.get(key, null)

func get_tier2_recipe_result(id_a: String, id_b: String) -> ItemData:
	return get_combined_artifact(id_a, id_b)

func get_tier3_recipe_result(id_a: String, id_b: String) -> ItemData:
	var key := get_recipe_key(id_a, id_b)
	return mythic_matrix.get(key, null)

# ==========================================
# ĐƯỜNG ỐNG RÈN ĐỒ TRÊN KHO (BENCH CRAFTING)
# ==========================================
func craft_on_bench(source_idx: int, target_idx: int) -> bool:
	if source_idx == target_idx or source_idx < 0 or target_idx < 0:
		return false
	if source_idx >= bench_slots.size() or target_idx >= bench_slots.size():
		return false
		
	var item_src: ItemData = bench_slots[source_idx]
	var item_tgt: ItemData = bench_slots[target_idx]
	if not item_src or not item_tgt:
		return false
		
	var crafted_item: ItemData = null
	# 1. Rèn Bậc 1 + Bậc 1 -> Bậc 2 Cổ Vật
	if item_src.tier == 1 and item_tgt.tier == 1:
		crafted_item = get_combined_artifact(item_src.id, item_tgt.id)
	# 2. Thăng hoa Bậc 2 + Bậc 2 -> Bậc 3 Thần Thoại
	elif item_src.tier == 2 and item_tgt.tier == 2:
		crafted_item = get_mythic_fusion(item_src, item_tgt)
		
	if crafted_item != null:
		bench_slots[target_idx] = crafted_item
		bench_slots[source_idx] = null
		item_crafted.emit(crafted_item, target_idx)
		return true
	return false

func combine_bench_items(slot_a: int, slot_b: int) -> bool:
	return craft_on_bench(slot_a, slot_b)

# ==========================================
# BỘ TỔNG HỢP THẦN THOẠI (MYTHIC FUSION & SYNTHESIZER)
# ==========================================
func get_mythic_fusion(item_a: ItemData, item_b: ItemData) -> ItemData:
	if item_a == null or item_b == null:
		return null
		
	# 1. Kiểm tra tài nguyên có sẵn trong ma trận thần thoại
	var key := get_recipe_key(item_a.id, item_b.id)
	if mythic_matrix.has(key):
		return mythic_matrix.get(key)
		
	# 2. Bộ Tổng Hợp Thần Thoại Tự Động (Dynamic Mythic Synthesizer)
	var words_a := item_a.name.split(" ", false)
	var words_b := item_b.name.split(" ", false)
	var w1: String = words_a[0] if words_a.size() > 0 else "Cổ"
	var w2: String = words_b[words_b.size() - 1] if words_b.size() > 0 else "Bảo"
	var dyn_name: String = "%s Thần %s" % [w1, w2]
	
	var dyn := ItemData.new()
	dyn.id = "mythic_%s_%s" % [item_a.id, item_b.id]
	dyn.name = dyn_name
	dyn.tier = 3
	dyn.is_component = false
	dyn.is_pure_stat = false
	dyn.recipe = [item_a.id, item_b.id]
	
	# Cộng dồn 100% toàn bộ chỉ số từ 2 món Bậc 2
	dyn.bonus_ad = item_a.get_bonus_ad() + item_b.get_bonus_ad()
	dyn.bonus_ap = item_a.get_bonus_ap() + item_b.get_bonus_ap()
	dyn.bonus_armor = item_a.get_bonus_armor() + item_b.get_bonus_armor()
	dyn.bonus_hp = item_a.get_bonus_hp() + item_b.get_bonus_hp()
	dyn.starting_energy = item_a.get_starting_energy() + item_b.get_starting_energy()
	dyn.crit_chance = item_a.get_crit_chance() + item_b.get_crit_chance()
	dyn.bonus_attack_speed = item_a.get_bonus_attack_speed() + item_b.get_bonus_attack_speed()
	dyn.bonus_omnivamp = item_a.get_bonus_omnivamp() + item_b.get_bonus_omnivamp()
	
	# Kế thừa nội tại tầng 1 (sub_passive)
	if item_a.passive_name != "":
		dyn.sub_passive_name = item_a.passive_name
		dyn.sub_passive_desc = item_a.passive_desc
	elif item_b.passive_name != "":
		dyn.sub_passive_name = item_b.passive_name
		dyn.sub_passive_desc = item_b.passive_desc
	else:
		dyn.sub_passive_name = "Thần Uy"
		dyn.sub_passive_desc = "Tăng cường toàn diện khả năng chiến đấu khi thăng hoa"
		
	# Nội tại thần thoại tầng 2 phát sáng (mythic_passive)
	dyn.mythic_passive_name = "Vạn Cổ Thần Nộ"
	dyn.mythic_passive_desc = "Kích phát thần lực tối thượng khi lượng máu suy giảm"
	
	return dyn
