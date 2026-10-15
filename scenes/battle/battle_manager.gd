extends Node2D

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text/FloatingText.tscn")

@export var hero_scene: PackedScene
@export var enemy_scene: PackedScene

@onready var hero_spawn: Marker2D = $HeroSpawn
@onready var enemy_spawn: Marker2D = $EnemySpawn

var heroes: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []
var corpses: Array[CombatEntity] = []

var combat_system: CombatSystem
var targeting_system: TargetingSystem
var progression_system: ProgressionSystem
var ability_system: AbilitySystem
var skill_ui: SkillChoiceUI
var choice_queue: Array[Dictionary] = []

# Trạng thái điều phối cuối trận
var battle_ended: bool = false
var next_game_state: GameManager.GameState

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.BATTLE)
	_start_battle()

func _start_battle() -> void:
	print("=====================================")
	print("[BattleManager] ⚔️ BATTLE STARTED ⚔️")
	print("=====================================")
	
	if hero_scene == null or enemy_scene == null:
		printerr("[BattleManager] FATAL: Hero or Enemy scene not assigned.")
		return
		
	_init_systems()
	_spawn_mock_teams()

func _init_systems() -> void:
	combat_system = CombatSystem.new()
	combat_system.name = "CombatSystem"
	add_child(combat_system)
	combat_system.damage_dealt.connect(_on_combat_damage_dealt)
	
	targeting_system = TargetingSystem.new()
	targeting_system.name = "TargetingSystem"
	targeting_system.heroes = self.heroes
	targeting_system.enemies = self.enemies
	add_child(targeting_system)
	
	progression_system = ProgressionSystem.new()
	progression_system.name = "ProgressionSystem"
	add_child(progression_system)
	progression_system.initialize(combat_system)
	
	ability_system = AbilitySystem.new()
	ability_system.name = "AbilitySystem"
	ability_system.combat_system = combat_system
	ability_system.targeting_system = targeting_system
	add_child(ability_system)
	
	ability_system.setup_hooks()
	
	skill_ui = SkillChoiceUI.new()
	add_child(skill_ui)
	skill_ui.skill_chosen.connect(_on_skill_chosen)

func _spawn_mock_teams() -> void:
	# 1. Tướng THẬT (Kira) nạp từ file Resource
	var kira_data = load("res://data/kira_data.tres") as HeroData
	if kira_data:
		_spawn_hero(kira_data, Vector2(0, -40))
		
	# 2. Sinh nhanh 4 Tướng ẢO (để Kira không bị hội đồng)
	_spawn_hero(_create_mock_hero_data("Arthur", HeroData.HeroClass.TANK, 250.0, 5.0, 30.0, 0.8), Vector2(0, -80))
	_spawn_hero(_create_mock_hero_data("Jaina", HeroData.HeroClass.MAGE, 80.0, 25.0, 2.0, 0.7), Vector2(0, 0))
	_spawn_hero(_create_mock_hero_data("Robin", HeroData.HeroClass.MARKSMAN, 90.0, 15.0, 5.0, 1.5), Vector2(0, 40))
	_spawn_hero(_create_mock_hero_data("Soraka", HeroData.HeroClass.SUPPORT, 120.0, 3.0, 10.0, 0.6), Vector2(0, 80))
	
	# 3. Quái vật
	for i in range(5):
		_spawn_enemy("Slime " + str(i+1), 80.0, 8.0, 5.0, 1.0, 0.0, 2.0, Vector2(0, -80 + (i * 40)))

# Hàm hỗ trợ sinh Data nhanh bằng code
func _create_mock_hero_data(h_name: String, h_class: HeroData.HeroClass, hp: float, atk: float, def: float, spd: float) -> HeroData:
	var data: HeroData = HeroData.new()
	data.name = h_name
	data.hero_class = h_class
	data.base_hp = hp
	data.base_attack = atk
	data.base_defense = def
	data.attack_speed = spd
	return data

func _spawn_hero(data: HeroData, offset: Vector2) -> void:
	var hero: HeroEntity = hero_scene.instantiate() as HeroEntity
	add_child(hero)
	
	if hero_spawn != null:
		hero.global_position = hero_spawn.global_position + offset
	else:
		hero.global_position = offset
	
	hero.died.connect(_on_entity_died.bind(true))
	hero.attack_requested.connect(combat_system.process_attack)
	hero.ability_requested.connect(ability_system.execute_ability)
	
	hero.initialize(data)
	hero.healed.connect(_on_entity_healed)
	if hero.progression != null:
		hero.progression.xp_gained.connect(func(amt: float): _on_hero_xp_gained(hero, amt))
		hero.progression.milestone_reached.connect(func(ms: int): _on_hero_milestone(hero, ms))
	heroes.append(hero)

func _spawn_enemy(e_name: String, hp: float, atk: float, def: float, spd: float, crit_c: float, crit_d: float, offset: Vector2) -> void:
	var data: EnemyData = EnemyData.new()
	data.name = e_name
	data.base_hp = hp
	data.base_attack = atk
	data.base_defense = def
	data.attack_speed = spd
	data.crit_chance = crit_c
	data.crit_damage = crit_d
	
	var enemy: EnemyEntity = enemy_scene.instantiate() as EnemyEntity
	add_child(enemy)
	
	if enemy_spawn != null:
		enemy.global_position = enemy_spawn.global_position + offset
	else:
		enemy.global_position = offset
	
	enemy.died.connect(_on_entity_died.bind(false))
	enemy.attack_requested.connect(combat_system.process_attack)
	enemy.initialize(data)
	enemy.healed.connect(_on_entity_healed)
	enemies.append(enemy)

func _on_entity_died(entity: CombatEntity, is_hero: bool) -> void:
	if is_hero:
		heroes.erase(entity)
	else:
		enemies.erase(entity)
		
	corpses.append(entity)
	_check_battle_end()

func _check_battle_end() -> void:
	if GameManager.current_state != GameManager.GameState.BATTLE:
		return
		
	if heroes.is_empty():
		_end_battle(GameManager.GameState.GAME_OVER, "❌ DEFEAT - All Heroes have fallen.")
	elif enemies.is_empty():
		_end_battle(GameManager.GameState.REWARD, "🏆 VICTORY - Floor Cleared!")

# ==========================================
# POST-BATTLE REWARD PHASE (Xử lý cuối trận)
# ==========================================
func _end_battle(state: GameManager.GameState, log_message: String) -> void:
	if battle_ended: return
	battle_ended = true
	next_game_state = state
	
	print("[BattleManager] ", log_message)
	print("--- REWARD PHASE STARTED ---")
	
	var is_victory: bool = (state == GameManager.GameState.REWARD)
	if progression_system != null:
		progression_system.finalize_battle_xp(is_victory)
	
	_build_post_battle_choice_queue()
	
	if not choice_queue.is_empty():
		_process_next_choice()
	else:
		_finish_battle_cleanup()

func _build_post_battle_choice_queue() -> void:
	choice_queue.clear()
	# RÀ SOÁT: Nối mảng an toàn không qua toán tử +
	var all_heroes: Array[CombatEntity] = []
	all_heroes.append_array(heroes)
	all_heroes.append_array(corpses)
	
	for entity in all_heroes:
		if entity is HeroEntity:
			var hero = entity as HeroEntity
			for milestone in hero.pending_milestones:
				var choices = hero.pull_milestone_choices(milestone)
				if not choices.is_empty():
					choice_queue.append({
						"hero": hero,
						"milestone": milestone,
						"choices": choices
					})
			hero.pending_milestones.clear()

func _process_next_choice() -> void:
	if choice_queue.is_empty(): return
	var next = choice_queue[0]
	skill_ui.show_choices(next.hero.name, next.milestone, next.choices)

func _on_skill_chosen(chosen: AbilityData, all_choices: Array[AbilityData]) -> void:
	if choice_queue.is_empty():
		return
	var current = choice_queue.pop_front()
	if current == null or not current.has("hero") or not is_instance_valid(current.hero):
		return
	current.hero.apply_skill_choice(current.milestone, chosen, all_choices)
	
	if choice_queue.size() > 0:
		_process_next_choice()
	else:
		_finish_battle_cleanup()

func _finish_battle_cleanup() -> void:
	print("[BattleManager] Reward Phase Complete. Cleaning up ", corpses.size(), " corpses.")
	for corpse in corpses:
		if is_instance_valid(corpse):
			corpse.queue_free()
	corpses.clear()
	
	get_tree().create_timer(1.0).timeout.connect(_start_next_floor)

func _start_next_floor() -> void:
	battle_ended = false
	print("\n=====================================")
	print("[BattleManager] 🚀 BẮT ĐẦU MÀN MỚI / TẦNG TIẾP THEO 🚀")
	print("=====================================")
	
	for i in range(5):
		_spawn_enemy("Slime Lv2 - " + str(i+1), 120.0, 10.0, 6.0, 1.0, 0.0, 2.0, Vector2(0, -80 + (i * 40)))

# ==========================================
# FLOATING TEXT SPAWNER (SPRINT 5 VFX)
# ==========================================
func _spawn_floating_text(pos: Vector2, text_str: String, type: FloatingText.Type) -> void:
	if FLOATING_TEXT_SCENE == null:
		return
	var ft: FloatingText = FLOATING_TEXT_SCENE.instantiate() as FloatingText
	add_child(ft)
	# Nhích nhẹ lên trên đầu thực thể và lệch ngẫu nhiên nhỏ để chống đè lấp chữ
	ft.global_position = pos + Vector2(randf_range(-12.0, 12.0), randf_range(-30.0, -20.0))
	ft.setup(text_str, type)

func _on_combat_damage_dealt(_source: CombatEntity, target: CombatEntity, amount: float, is_crit: bool) -> void:
	if not is_instance_valid(target):
		return
	var dmg_val: int = maxi(1, roundi(amount))
	if is_crit:
		_spawn_floating_text(target.global_position, "%d!" % dmg_val, FloatingText.Type.CRIT)
	else:
		_spawn_floating_text(target.global_position, str(dmg_val), FloatingText.Type.DAMAGE)

func _on_entity_healed(entity: CombatEntity, amount: float) -> void:
	if not is_instance_valid(entity):
		return
	var heal_val: int = maxi(1, roundi(amount))
	_spawn_floating_text(entity.global_position, "+%d" % heal_val, FloatingText.Type.HEAL)

func _on_hero_xp_gained(hero: HeroEntity, amount: float) -> void:
	if not is_instance_valid(hero):
		return
	var xp_val: int = roundi(amount)
	if xp_val > 0:
		_spawn_floating_text(hero.global_position + Vector2(0, -15), "+%d XP" % xp_val, FloatingText.Type.XP)

func _on_hero_milestone(hero: HeroEntity, milestone: int) -> void:
	if not is_instance_valid(hero):
		return
	_spawn_floating_text(hero.global_position + Vector2(0, -35), "LV.%d MILESTONE!" % milestone, FloatingText.Type.SYSTEM)


# ==============================================================================
# SPRINT 4 AUTOMATED TEST RUNNER (BẢN XUẤT RA FILE REPORT)
# Phím 0: Chạy toàn bộ Test Suite và lưu vào file
# ==============================================================================
var test_report_path: String = "user://sprint4_test_report.txt"

# Hàm hỗ trợ vừa in ra Console, vừa ghi vào File Report
func _log_test(msg: String) -> void:
	print("📝 ", msg) # In ra console với icon để dễ phân biệt với log game
	
	var file: FileAccess
	if FileAccess.file_exists(test_report_path):
		file = FileAccess.open(test_report_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(test_report_path, FileAccess.WRITE)
	
	if file != null:
		file.store_line(msg)
		file.close()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed): return
	
	match event.keycode:
		KEY_SPACE:
			print("\n[DEBUG] 🚀 BƠM 800 XP CHO TOÀN BỘ HEROES!")
			for hero in heroes:
				if is_instance_valid(hero) and hero.progression != null:
					hero.progression.add_xp(800.0)
					
		# PHÍM 0: CHẠY TOÀN BỘ 6 TEST CASE VÀ GHI REPORT
		KEY_0: 
			# Mở file với quyền WRITE để xóa dữ liệu cũ, ghi đè báo cáo mới
			var file = FileAccess.open(test_report_path, FileAccess.WRITE)
			if file:
				file.store_line("=== BÁO CÁO KIỂM THỬ SPRINT 4 ===")
				file.store_line("Thời gian: " + Time.get_datetime_string_from_system())
				file.store_line("==================================\n")
				file.close()
			
			_log_test("Đang chạy toàn bộ Test Suite...")
			_log_test("Thư mục lưu report: " + ProjectSettings.globalize_path(test_report_path))
			
			_run_tc_01_active_ability_xp()
			_run_tc_02_targeting_rules()
			_run_tc_03_energy_and_ultimate()
			_run_tc_04_passive_recursion()
			_run_tc_05_post_battle_choice_queue()
			_run_tc_06_xp_regression()
			
			_log_test("\n🎉 TẤT CẢ TEST ĐÃ HOÀN THÀNH (100% PASSED)!")
			
		# Chạy lẻ từng test như cũ
		KEY_1: _run_tc_03_energy_and_ultimate()
		KEY_2: _run_tc_04_passive_recursion()
		KEY_3: _run_tc_02_targeting_rules()
		KEY_4: _run_tc_01_active_ability_xp()
		KEY_5: _run_tc_05_post_battle_choice_queue()
		KEY_6: _run_tc_06_xp_regression()

# ------------------------------------------------------------------------------
# TC-03: Energy Cost & Ultimate
# ------------------------------------------------------------------------------
func _run_tc_03_energy_and_ultimate() -> void:
	_log_test("\n==================== [TEST TC-03: ENERGY & ULTIMATE] ====================")
	_reset_test_battlefield()
	var hero = heroes[0] as HeroEntity
	
	while enemies.size() > 1:
		var extra_e = enemies.pop_back()
		if is_instance_valid(extra_e): extra_e.queue_free()
	
	var actual_target = enemies[0]
	actual_target.current_hp = 500.0
	var hp_before = actual_target.current_hp
	
	var ult_data = AbilityData.new()
	ult_data.ability_type = AbilityData.AbilityType.ULTIMATE
	ult_data.target_rule = AbilityData.TargetRule.SINGLE_ENEMY
	var dmg = DamageEffectData.new()
	dmg.base_damage = 150.0
	dmg.can_crit = false
	ult_data.effects.append(dmg)
	
	var ult_ability = Ability.new(hero, ult_data)
	hero.unlocked_abilities.clear()
	hero.unlocked_abilities.append(ult_ability)
	hero.current_energy = 100.0
	
	var success = ability_system.execute_ability(ult_ability)
	var hp_after = actual_target.current_hp
	
	_log_test("[TC-03] HP Before: %.1f | HP After: %.1f" % [hp_before, hp_after])
	assert(success, "FAIL: Ultimate execution rejected")
	assert(hp_after < hp_before, "FAIL P0: Expected HP to decrease!")
	assert(hero.current_energy == 0.0, "FAIL: Energy not drained")
	_log_test(">>> 🟢 TC-03 PASSED!\n")

# ------------------------------------------------------------------------------
# TC-04: Passive Recursion & Cooldown
# ------------------------------------------------------------------------------
func _run_tc_04_passive_recursion() -> void:
	_log_test("\n==================== [TEST TC-04: PASSIVE RECURSION & COOLDOWN] ====================")
	_reset_test_battlefield()
	
	while enemies.size() > 1:
		var extra = enemies.pop_back()
		if is_instance_valid(extra): extra.queue_free()
		
	var hero = heroes[0] as HeroEntity
	var enemy = enemies[0]
	enemy.current_hp = 1000.0
	enemy.data.base_defense = 0.0 
	
	var passive_data = AbilityData.new()
	passive_data.name = "Recursive Blade"
	passive_data.ability_type = AbilityData.AbilityType.PASSIVE
	passive_data.trigger_condition = AbilityData.TriggerCondition.ON_CRIT
	passive_data.cooldown = 0.0
	var dmg = DamageEffectData.new()
	dmg.base_damage = 20.0
	dmg.can_crit = true
	passive_data.effects.append(dmg)
	
	var passive_ability = Ability.new(hero, passive_data)
	hero.unlocked_abilities.clear()
	hero.unlocked_abilities.append(passive_ability)
	hero.data.crit_chance = 1.0
	
	var start_hp = enemy.current_hp
	var event = DamageEvent.new(hero, enemy, 50.0, DamageEvent.DamageType.PHYSICAL)
	event.is_crit = true
	event.crit_multiplier = 2.0
	combat_system.process_attack(event)
	
	var expected_hp = start_hp - 140.0
	_log_test("[TC-04.1] Anti-Recursion HP: %.1f -> %.1f (Expected: %.1f)" % [start_hp, enemy.current_hp, expected_hp])
	assert(is_equal_approx(enemy.current_hp, expected_hp), "FAIL TC-04.1")
	
	passive_data.cooldown = 2.0
	passive_ability.current_cooldown = 0.0
	
	var hp_before_cd = enemy.current_hp
	combat_system.process_attack(event)
	var hp_after_first = enemy.current_hp
	assert(is_equal_approx(hp_after_first, hp_before_cd - 140.0), "FAIL TC-04.2")
	assert(passive_ability.current_cooldown > 0.0, "FAIL TC-04.2")
	
	combat_system.process_attack(event)
	var hp_after_second = enemy.current_hp
	assert(is_equal_approx(hp_after_second, hp_after_first - 100.0), "FAIL TC-04.2")
	
	passive_ability.process_cooldown(2.0)
	
	combat_system.process_attack(event)
	var hp_after_third = enemy.current_hp
	assert(is_equal_approx(hp_after_third, hp_after_second - 140.0), "FAIL TC-04.2")
	
	_log_test(">>> 🟢 TC-04 PASSED: Recursion prevented & Cooldown semantics verified!\n")

# ------------------------------------------------------------------------------
# TC-02: Targeting System Contract (8 Rules)
# ------------------------------------------------------------------------------
func _run_tc_02_targeting_rules() -> void:
	_log_test("\n==================== [TEST TC-02: TARGETING RULES] ====================")
	_reset_test_battlefield()
	
	while heroes.size() > 3:
		var extra_h = heroes.pop_back()
		if is_instance_valid(extra_h): extra_h.queue_free()
	while enemies.size() > 3:
		var extra_e = enemies.pop_back()
		if is_instance_valid(extra_e): extra_e.queue_free()
	
	heroes[0].current_hp = 100.0; heroes[0].global_position = Vector2(0, 0); heroes[0].name = "H1"
	heroes[1].current_hp = 40.0;  heroes[1].global_position = Vector2(20, 0); heroes[1].name = "H2"
	heroes[2].current_hp = 70.0;  heroes[2].global_position = Vector2(40, 0); heroes[2].name = "H3"
	
	enemies[0].current_hp = 100.0; enemies[0].global_position = Vector2(100, 0); enemies[0].name = "E1"
	enemies[1].current_hp = 30.0;  enemies[1].global_position = Vector2(50, 0);  enemies[1].name = "E2"
	enemies[2].current_hp = 80.0;  enemies[2].global_position = Vector2(200, 0); enemies[2].name = "E3"
	
	var h1 = heroes[0]
	
	var r_self = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.SELF)
	_log_test("[TC-02] SELF: %s (Expected: ['H1'])" % str(r_self.map(func(e): return e.name)))
	assert(r_self.size() == 1 and r_self[0].name == "H1")
	
	var r_lowest_e = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.LOWEST_HP_ENEMY)
	_log_test("[TC-02] LOWEST_HP_ENEMY: %s (Expected: ['E2'])" % str(r_lowest_e.map(func(e): return e.name)))
	assert(r_lowest_e.size() == 1 and r_lowest_e[0].name == "E2")
	
	var r_nearest_e = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.NEAREST_ENEMY)
	_log_test("[TC-02] NEAREST_ENEMY: %s (Expected: ['E2'])" % str(r_nearest_e.map(func(e): return e.name)))
	assert(r_nearest_e.size() == 1 and r_nearest_e[0].name == "E2")
	
	var r_lowest_a = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.LOWEST_HP_ALLY)
	_log_test("[TC-02] LOWEST_HP_ALLY: %s (Expected: ['H2'])" % str(r_lowest_a.map(func(e): return e.name)))
	assert(r_lowest_a.size() == 1 and r_lowest_a[0].name == "H2")
	
	var r_all_e = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.ALL_ENEMIES)
	_log_test("[TC-02] ALL_ENEMIES count: %d (Expected: 3)" % r_all_e.size())
	assert(r_all_e.size() == 3)
	
	var r_all_a = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.ALL_ALLIES)
	_log_test("[TC-02] ALL_ALLIES count: %d (Expected: 3)" % r_all_a.size())
	assert(r_all_a.size() == 3)
	
	enemies[1].is_dead = true
	var r_nearest_after_death = targeting_system.get_targets_for_rule(h1, AbilityData.TargetRule.NEAREST_ENEMY)
	_log_test("[TC-02] NEAREST_ENEMY after E2 dead: %s (Expected: ['E1'])" % str(r_nearest_after_death.map(func(e): return e.name)))
	assert(r_nearest_after_death[0].name == "E1")
	
	_log_test(">>> 🟢 TC-02 PASSED!\n")

# ------------------------------------------------------------------------------
# TC-01: Active Ability Damage Pipeline
# ------------------------------------------------------------------------------
func _run_tc_01_active_ability_xp() -> void:
	_log_test("\n==================== [TEST TC-01: ACTIVE ABILITY PIPELINE] ====================")
	_reset_test_battlefield()
	
	while enemies.size() > 1:
		var extra_e = enemies.pop_back()
		if is_instance_valid(extra_e): extra_e.queue_free()
		
	var hero = heroes[0] as HeroEntity
	var enemy = enemies[0]
	enemy.current_hp = 500.0
	
	var active = AbilityData.new()
	active.name = "Fireball"
	active.ability_type = AbilityData.AbilityType.ACTIVE
	active.target_rule = AbilityData.TargetRule.SINGLE_ENEMY
	active.energy_cost = 0.0 
	
	var dmg = DamageEffectData.new()
	dmg.base_damage = 250.0 
	active.effects.append(dmg)
	
	var ability = Ability.new(hero, active)
	hero.current_energy = 100.0 
	
	var hp_before = enemy.current_hp
	var success = ability_system.execute_ability(ability)
	
	_log_test("[TC-01] Execute Success: " + str(success))
	_log_test("[TC-01] Enemy HP: %.1f -> %.1f" % [hp_before, enemy.current_hp])
	
	assert(success, "FAIL TC-01: Ability execution rejected")
	assert(enemy.current_hp < hp_before, "FAIL TC-01: Damage not applied")
	_log_test(">>> 🟢 TC-01 PASSED!\n")

# ------------------------------------------------------------------------------
# TC-06: XP Regression Full Path
# ------------------------------------------------------------------------------
func _run_tc_06_xp_regression() -> void:
	_log_test("\n==================== [TEST TC-06: XP REGRESSION (FULL PATH)] ====================")
	_reset_test_battlefield()
	
	while enemies.size() > 1:
		var extra = enemies.pop_back()
		if is_instance_valid(extra): extra.queue_free()
		
	var hero = heroes[0] as HeroEntity
	hero.data.hero_class = HeroData.HeroClass.ASSASSIN 
	
	var enemy = enemies[0]
	enemy.current_hp = 350.0
	enemy.data.base_defense = 0.0 
	
	var old_progression = hero.progression
	hero.progression = HeroProgression.new()
	
	var temp_combat = CombatSystem.new()
	var temp_prog = ProgressionSystem.new()
	temp_prog.initialize(temp_combat)
	
	temp_combat.process_attack(DamageEvent.new(hero, enemy, 100.0, DamageEvent.DamageType.PHYSICAL))
	
	var crit_event = DamageEvent.new(hero, enemy, 50.0, DamageEvent.DamageType.PHYSICAL)
	crit_event.is_crit = true
	crit_event.crit_multiplier = 1.0 
	temp_combat.process_attack(crit_event)
	
	temp_combat.process_attack(DamageEvent.new(hero, enemy, 200.0, DamageEvent.DamageType.PHYSICAL))
	
	temp_prog.finalize_battle_xp(true)
	
	var final_xp = hero.progression.current_xp
	
	_log_test("[TC-06] Pipeline processing complete. XP Remainder: %.1f" % final_xp)
	assert(final_xp > 0.0, "FAIL TC-06: XP pipeline broken! No XP was processed.")
	
	hero.progression = old_progression
	temp_combat.free()
	temp_prog.free()
	_log_test(">>> 🟢 TC-06 PASSED!\n")

# ------------------------------------------------------------------------------
# TC-05: Multi-Milestone Post-Battle Choice Queue
# ------------------------------------------------------------------------------
func _run_tc_05_post_battle_choice_queue() -> void:
	_log_test("\n==================== [TEST TC-05: INTEGRATION POST-BATTLE QUEUE] ====================")
	_reset_test_battlefield()
	var hero = heroes[0] as HeroEntity
	
	for lvl in [5, 10, 15]:
		var pool: Array[AbilityData] = []
		for i in range(3):
			var a = AbilityData.new()
			a.name = "Skill_%d_%d" % [lvl, i + 1]
			pool.append(a)
		hero.runtime_pools[lvl] = pool
		
	_log_test("[TC-05] Emitting milestone signals to simulate leveling up...")
	hero.progression.milestone_reached.emit(5)
	hero.progression.milestone_reached.emit(10)
	hero.progression.milestone_reached.emit(15)
	
	_log_test("[TC-05] Actual Pending Milestones: " + str(hero.pending_milestones))
	assert(hero.pending_milestones == [5, 10, 15], "FAIL: Progression pipeline failed to register milestones")
	assert(not skill_ui.visible, "FAIL: UI opened mid-combat")
	
	_end_battle(GameManager.GameState.REWARD, "Victory Test")
	assert(choice_queue.size() == 3, "FAIL: Queue construction failed")
	if is_instance_valid(skill_ui):
		skill_ui.hide()
	if get_tree() != null:
		get_tree().paused = false
	choice_queue.clear()
	_log_test(">>> 🟢 TC-05 PASSED!\n")

# ------------------------------------------------------------------------------
# Helper Reset Battlefield
# ------------------------------------------------------------------------------
func _reset_test_battlefield() -> void:
	for h in heroes: if is_instance_valid(h): h.queue_free()
	for e in enemies: if is_instance_valid(e): e.queue_free()
	heroes.clear(); enemies.clear(); choice_queue.clear()
	if is_instance_valid(skill_ui):
		skill_ui.hide()
	if get_tree() != null:
		get_tree().paused = false
	battle_ended = false
	_spawn_mock_teams()
