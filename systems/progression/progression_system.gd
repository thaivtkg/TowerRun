class_name ProgressionSystem
extends Node

# ==========================================
# PROGRESSION SYSTEM (SPRINT 3)
# Cỗ máy tính toán đóng góp và phân phối XP theo Class
# ==========================================

const CLASS_XP_WEIGHTS: Dictionary = {
	HeroData.HeroClass.TANK:      {"damage": 0.2, "taken": 1.2, "heal": 0.5, "kill_xp": 10.0},
	HeroData.HeroClass.FIGHTER:   {"damage": 0.7, "taken": 0.7, "heal": 0.5, "kill_xp": 15.0},
	HeroData.HeroClass.ASSASSIN:  {"damage": 1.5, "taken": 0.1, "heal": 0.0, "kill_xp": 30.0},
	HeroData.HeroClass.MAGE:      {"damage": 1.2, "taken": 0.2, "heal": 0.5, "kill_xp": 20.0},
	HeroData.HeroClass.MARKSMAN:  {"damage": 1.2, "taken": 0.1, "heal": 0.1, "kill_xp": 20.0},
	HeroData.HeroClass.SUPPORT:   {"damage": 0.3, "taken": 0.3, "heal": 2.0, "kill_xp": 10.0},
}

var tracked_heroes: Array[HeroEntity] = []

func initialize(combat_system: CombatSystem) -> void:
	if combat_system == null:
		return
	if not combat_system.damage_dealt.is_connected(_on_damage_dealt):
		combat_system.damage_dealt.connect(_on_damage_dealt)
	if not combat_system.entity_killed.is_connected(_on_entity_killed):
		combat_system.entity_killed.connect(_on_entity_killed)
	if not combat_system.entity_healed.is_connected(_on_entity_healed):
		combat_system.entity_healed.connect(_on_entity_healed)

func _track_hero(hero: HeroEntity) -> void:
	if is_instance_valid(hero) and not tracked_heroes.has(hero):
		tracked_heroes.append(hero)

func _on_damage_dealt(source: CombatEntity, target: CombatEntity, amount: float, _is_crit: bool, _damage_type: int = DamageEvent.DamageType.PHYSICAL) -> void:
	if source is HeroEntity and is_instance_valid(source):
		var hero := source as HeroEntity
		if hero.metrics != null:
			hero.metrics.damage_dealt += amount
		_track_hero(hero)
		
	if target is HeroEntity and is_instance_valid(target):
		var hero := target as HeroEntity
		if hero.metrics != null:
			hero.metrics.damage_taken += amount
		_track_hero(hero)

func _on_entity_killed(killer: CombatEntity, _victim: CombatEntity) -> void:
	if killer is HeroEntity and is_instance_valid(killer):
		var hero := killer as HeroEntity
		if hero.metrics != null:
			hero.metrics.kills += 1
		_track_hero(hero)

func _on_entity_healed(source: CombatEntity, _target: CombatEntity, amount: float) -> void:
	if source is HeroEntity and is_instance_valid(source):
		var hero := source as HeroEntity
		if hero.metrics != null:
			hero.metrics.healing_done += amount
		_track_hero(hero)

func calculate_hero_contribution(hero: HeroEntity) -> float:
	if not is_instance_valid(hero) or hero.data == null or hero.metrics == null:
		return 0.0
	var weights: Dictionary = CLASS_XP_WEIGHTS.get(
		hero.data.hero_class,
		{"damage": 1.0, "taken": 1.0, "heal": 1.0, "kill_xp": 15.0}
	)
	var m := hero.metrics
	return (m.damage_dealt * weights.damage) \
		+ (m.damage_taken * weights.taken) \
		+ (m.healing_done * weights.heal) \
		+ (float(m.kills) * weights.kill_xp)

# ==========================================
# BATTLE END XP CONVERSION
# Quy đổi toàn bộ metrics thành XP và cộng vào HeroProgression
# ==========================================
func finalize_battle_xp(is_victory: bool, target_heroes: Array = []) -> void:
	print("\n--- BATTLE XP CONVERSION (70/30 TEAM POOL) ---")
	var win_multiplier: float = 1.2 if is_victory else 0.5
	
	var raw_heroes: Array = target_heroes if not target_heroes.is_empty() else tracked_heroes
	var valid_heroes: Array[HeroEntity] = []
	var total_contrib: float = 0.0
	var hero_contribs: Dictionary = {}
	var total_level: int = 0
	
	for hero_item in raw_heroes:
		if not is_instance_valid(hero_item):
			continue
		var hero := hero_item as HeroEntity
		if hero != null and hero.progression != null:
			valid_heroes.append(hero)
			var contrib: float = calculate_hero_contribution(hero)
			hero_contribs[hero] = contrib
			total_contrib += contrib
			total_level += hero.progression.current_level
			
	if valid_heroes.is_empty():
		tracked_heroes.clear()
		print("----------------------------\n")
		return
		
	var avg_level: int = maxi(1, int(round(float(total_level) / float(valid_heroes.size()))))
	var total_team_xp: float = total_contrib * win_multiplier
	
	# Quy tắc 70/30:
	# 70% Tổng XP: Chia đều cho toàn bộ Tướng tham chiến (chống bỏ đói Tanker & Support)
	var shared_pool: float = total_team_xp * 0.70
	var shared_xp_per_hero: float = shared_pool / float(valid_heroes.size())
	
	# 30% Tổng XP: Thưởng hiệu suất cá nhân (MVP bonus)
	var individual_pool: float = total_team_xp * 0.30
	
	for hero in valid_heroes:
		var contrib: float = hero_contribs.get(hero, 0.0)
		var hero_ratio: float = (contrib / total_contrib) if total_contrib > 0.0 else (1.0 / float(valid_heroes.size()))
		var individual_xp: float = individual_pool * hero_ratio
		var hero_xp: float = shared_xp_per_hero + individual_xp
		
		# Cơ chế Bắt kịp (Catch-up Mechanism):
		# Nếu cấp Tướng thấp hơn cấp trung bình đội từ 2 cấp trở lên -> Nhận thêm +50% XP
		if (avg_level - hero.progression.current_level) >= 2:
			hero_xp *= 1.50
			
		hero.progression.add_xp(hero_xp)
		
		var class_str: String = HeroData.HeroClass.keys()[hero.data.hero_class] if hero.data != null else "UNKNOWN"
		print("> %s (%s) | Contrib: %.1f | Final XP (+%.1f) [Shared: %.1f, MVP: %.1f] | Lv%d (%.1f/%.1f)" % [
			hero.name, class_str, contrib, hero_xp, shared_xp_per_hero, individual_xp,
			hero.progression.current_level, hero.progression.current_xp, hero.progression.required_xp
		])
		
	tracked_heroes.clear()
	print("----------------------------\n")

# ==========================================
# SPRINT 4: WEIGHTED GACHA SKILL UPGRADES (TASK S4.2)
# ==========================================
static func sample_weighted_card(cards: Array[SkillUpgradeCard]) -> SkillUpgradeCard:
	if cards.is_empty():
		return null
	var total_weight: float = 0.0
	for c in cards:
		if c != null:
			total_weight += float(c.weight)
	if total_weight <= 0.0:
		return cards[0]
	var roll := randf() * total_weight
	var cumulative: float = 0.0
	for c in cards:
		if c != null:
			cumulative += float(c.weight)
			if roll <= cumulative:
				return c
	return cards.back()

func generate_upgrade_choices(hero: HeroEntity, milestone: int) -> Array[SkillUpgradeCard]:
	var candidates: Array[SkillUpgradeCard] = []
	if hero == null:
		return candidates

	# 1. NEW_ABILITY (Trọng số: 40, Hiếm) từ runtime_pools[milestone]
	var pool: Array = hero.runtime_pools.get(milestone, [])
	for ab in pool:
		if ab is AbilityData:
			var card := SkillUpgradeCard.new()
			card.upgrade_type = SkillUpgradeCard.UpgradeType.NEW_ABILITY
			card.rarity_tier = "RARE"
			card.weight = 40
			card.title = ab.name
			card.new_ability_data = ab
			card.milestone = milestone
			candidates.append(card)

	# 2. Existing abilities (unlocked + basic attack)
	var existing_abilities: Array[AbilityData] = []
	if hero.basic_attack_ability != null and hero.basic_attack_ability.data != null:
		existing_abilities.append(hero.basic_attack_ability.data)
	for ab in hero.unlocked_abilities:
		if ab != null and ab.data != null and not existing_abilities.has(ab.data):
			existing_abilities.append(ab.data)

	# Determine primary stat key based on class
	var pref_stat := EffectData.STAT_AD
	if hero.data != null:
		match hero.data.hero_class:
			HeroData.HeroClass.MAGE, HeroData.HeroClass.SUPPORT:
				pref_stat = EffectData.STAT_AP
			HeroData.HeroClass.TANK:
				pref_stat = EffectData.STAT_HP
			_:
				pref_stat = EffectData.STAT_AD

	for ab_data in existing_abilities:
		if ab_data.effects.is_empty():
			continue

		# FLAT_BOOST (Trọng số: 75, Phổ biến)
		var flat_card := SkillUpgradeCard.new()
		flat_card.upgrade_type = SkillUpgradeCard.UpgradeType.FLAT_BOOST
		flat_card.rarity_tier = "COMMON"
		flat_card.weight = 75
		flat_card.target_ability = ab_data
		flat_card.bonus_value = 25.0
		flat_card.title = "[CƯỜNG HÓA] " + ab_data.name
		candidates.append(flat_card)

		# SCALE_BOOST (Trọng số: 20, Hiếm)
		var scale_card := SkillUpgradeCard.new()
		scale_card.upgrade_type = SkillUpgradeCard.UpgradeType.SCALE_BOOST
		scale_card.rarity_tier = "RARE"
		scale_card.weight = 20
		scale_card.target_ability = ab_data
		scale_card.stat_key = pref_stat
		scale_card.bonus_value = 0.20
		scale_card.title = "[ĐỘT PHÁ] " + ab_data.name
		candidates.append(scale_card)

		# ULTIMATE_EVOLVE (Trọng số: 5, Huyền thoại)
		if ab_data.ability_type == AbilityData.AbilityType.ULTIMATE:
			var ult_card := SkillUpgradeCard.new()
			ult_card.upgrade_type = SkillUpgradeCard.UpgradeType.ULTIMATE_EVOLVE
			ult_card.rarity_tier = "EPIC"
			ult_card.weight = 5
			ult_card.target_ability = ab_data
			ult_card.bonus_value = 50.0
			ult_card.title = "[TIẾN HÓA] " + ab_data.name
			candidates.append(ult_card)

	# Rút tối đa 3 thẻ không trùng lặp
	var chosen: Array[SkillUpgradeCard] = []
	var pool_copy := candidates.duplicate()
	var pick_count := mini(3, pool_copy.size())

	for _i in range(pick_count):
		var picked = sample_weighted_card(pool_copy)
		if picked != null:
			chosen.append(picked)
			pool_copy.erase(picked)

	return chosen
