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

func _on_damage_dealt(source: CombatEntity, target: CombatEntity, amount: float, _is_crit: bool) -> void:
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
	print("\n--- BATTLE XP CONVERSION ---")
	var win_multiplier: float = 1.2 if is_victory else 0.5
	
	var heroes_to_process: Array = target_heroes if not target_heroes.is_empty() else tracked_heroes
	
	for hero_item in heroes_to_process:
		var hero := hero_item as HeroEntity
		if not is_instance_valid(hero) or hero.progression == null:
			continue
			
		var raw_contribution: float = calculate_hero_contribution(hero)
		var final_xp: float = raw_contribution * win_multiplier
		
		hero.progression.add_xp(final_xp)
		
		var class_str: String = HeroData.HeroClass.keys()[hero.data.hero_class] if hero.data != null else "UNKNOWN"
		print("> %s (%s) | Raw Contrib: %.1f | Final XP (+%.1f) | Current: Lv%d (%.1f/%.1f)" % [
			hero.name, class_str, raw_contribution, final_xp, 
			hero.progression.current_level, hero.progression.current_xp, hero.progression.required_xp
		])
		
	tracked_heroes.clear()
	print("----------------------------\n")
