extends Node2D

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
var skill_ui: SkillChoiceUI
var choice_queue: Array[Dictionary] = []

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
	
	targeting_system = TargetingSystem.new()
	targeting_system.name = "TargetingSystem"
	targeting_system.heroes = self.heroes
	targeting_system.enemies = self.enemies
	add_child(targeting_system)
	
	progression_system = ProgressionSystem.new()
	progression_system.name = "ProgressionSystem"
	add_child(progression_system)
	progression_system.initialize(combat_system)
	
	# Khởi tạo UI Chọn Kỹ năng
	skill_ui = SkillChoiceUI.new()
	add_child(skill_ui)
	skill_ui.skill_chosen.connect(_on_skill_chosen)

func _spawn_mock_teams() -> void:
	# ==========================================
	# TASK 3.7: TEST SCENARIO (5 Heroes vs 5 Enemies)
	# ==========================================
	
	# 1. Tank: Máu trâu, giáp dày -> Sẽ nhận XP từ sát thương gánh chịu
	_spawn_hero("Arthur", HeroData.HeroClass.TANK, 250.0, 5.0, 30.0, 0.8, 0.0, 1.5, Vector2(0, -80))
	# 2. Assassin: Dame to, tỷ lệ chí mạng 50% -> Sẽ nhận XP từ Crit, Kill và một phần Damage
	_spawn_hero("Kira", HeroData.HeroClass.ASSASSIN, 100.0, 20.0, 5.0, 1.2, 0.5, 2.0, Vector2(0, -40))
	# 3. Mage: Sát thương gốc cao -> Sẽ nhận XP từ lượng sát thương gây ra
	_spawn_hero("Jaina", HeroData.HeroClass.MAGE, 80.0, 25.0, 2.0, 0.7, 0.1, 1.5, Vector2(0, 0))
	# 4. Marksman: Đánh rất nhanh (spd 1.5) -> Sẽ nhận XP từ lượng sát thương gây ra
	_spawn_hero("Robin", HeroData.HeroClass.MARKSMAN, 90.0, 15.0, 5.0, 1.5, 0.2, 1.5, Vector2(0, 40))
	# 5. Support: Tạm nhận XP từ Damage Dealt cho đến khi Support utility metrics được triển khai.
	_spawn_hero("Soraka", HeroData.HeroClass.SUPPORT, 120.0, 3.0, 10.0, 0.6, 0.0, 1.0, Vector2(0, 80))
	
	# Spawn 5 quái vật để có đủ lượng XP cho Heroes thăng cấp
	for i in range(5):
		_spawn_enemy("Slime " + str(i+1), 80.0, 8.0, 5.0, 1.0, 0.0, 2.0, Vector2(0, -80 + (i * 40)))

func _spawn_hero(h_name: String, h_class: HeroData.HeroClass, hp: float, atk: float, def: float, spd: float, crit_c: float, crit_d: float, offset: Vector2) -> void:
	var data := HeroData.new()
	data.name = h_name; data.hero_class = h_class
	data.base_hp = hp; data.base_attack = atk; data.base_defense = def; data.attack_speed = spd; 
	data.crit_chance = crit_c; data.crit_damage = crit_d
	
	# --- SPRINT 4 FIX: Tự động nhét 5 kỹ năng thử nghiệm vào Pool Lv5 ---
	for i in range(5):
		var mock_ability = AbilityData.new()
		mock_ability.name = "Kỹ năng Bí truyền " + str(i + 1)
		mock_ability.description = "Mô tả của kỹ năng số " + str(i + 1)
		mock_ability.ability_type = AbilityData.AbilityType.PASSIVE
		data.pool_lv5_passives.append(mock_ability)
	# ---------------------------------------------------------------------
	
	var hero := hero_scene.instantiate() as HeroEntity
	add_child(hero)
	hero.global_position = hero_spawn.global_position + offset
	
	hero.died.connect(_on_entity_died.bind(true))
	hero.attack_requested.connect(combat_system.process_attack)
	hero.pending_skill_choice.connect(_on_pending_skill_choice)
	hero.initialize(data)
	heroes.append(hero)

func _spawn_enemy(e_name: String, hp: float, atk: float, def: float, spd: float, crit_c: float, crit_d: float, offset: Vector2) -> void:
	var data := EnemyData.new()
	data.name = e_name
	data.base_hp = hp; data.base_attack = atk; data.base_defense = def; data.attack_speed = spd; 
	data.crit_chance = crit_c; data.crit_damage = crit_d
	
	var enemy := enemy_scene.instantiate() as EnemyEntity
	add_child(enemy)
	enemy.global_position = enemy_spawn.global_position + offset
	
	enemy.died.connect(_on_entity_died.bind(false))
	enemy.attack_requested.connect(combat_system.process_attack)
	enemy.initialize(data)
	enemies.append(enemy)

func _on_entity_died(entity: CombatEntity, is_hero: bool) -> void:
	if is_hero: heroes.erase(entity)
	else: enemies.erase(entity)
		
	corpses.append(entity)
	_check_battle_end()

func _check_battle_end() -> void:
	if GameManager.current_state != GameManager.GameState.BATTLE: return
		
	if heroes.is_empty(): _end_battle(GameManager.GameState.GAME_OVER, "❌ DEFEAT - All Heroes have fallen.")
	elif enemies.is_empty(): _end_battle(GameManager.GameState.REWARD, "🏆 VICTORY - Floor Cleared!")

func _end_battle(state: GameManager.GameState, log_message: String) -> void:
	print("[BattleManager] ", log_message)
	
	# Xác định thắng thua để truyền vào ProgressionSystem
	var is_victory: bool = (state == GameManager.GameState.REWARD)
	
	# Chỉ huy ProgressionSystem tổng kết XP dựa trên cống hiến
	if progression_system != null:
		progression_system.finalize_battle_xp(is_victory)
	
	print("[BattleManager] Cleaning up ", corpses.size(), " corpses.")
	
	for corpse in corpses:
		if is_instance_valid(corpse):
			corpse.queue_free()
	corpses.clear()
	
	GameManager.change_state(state)
	
func _on_pending_skill_choice(hero: HeroEntity, milestone: int, choices: Array[AbilityData]) -> void:
	choice_queue.append({"hero": hero, "milestone": milestone, "choices": choices})
	
	# Nếu game không bị pause (chưa có UI nào đang bật), mở ngay UI đầu tiên
	if not get_tree().paused:
		_process_next_choice()

func _process_next_choice() -> void:
	if choice_queue.is_empty(): return
	
	var next = choice_queue[0]
	skill_ui.show_choices(next.hero.name, next.milestone, next.choices)

func _on_skill_chosen(chosen: AbilityData, all_choices: Array[AbilityData]) -> void:
	var current = choice_queue.pop_front()
	current.hero.apply_skill_choice(current.milestone, chosen, all_choices)
	
	# Nếu Hero nhảy liền 2 cấp (VD: ăn XP thẳng lên Lv10), mở tiếp UI Lv10 ngay lập tức
	if choice_queue.size() > 0:
		_process_next_choice()

func _input(event: InputEvent) -> void:
	# Bắt trực tiếp phím SPACE cứng, không thông qua ui_accept để tránh lỗi focus
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("\n[DEBUG] 🚀 BƠM 800 XP CHO TOÀN BỘ HEROES!")
		for hero in heroes:
			if is_instance_valid(hero) and hero.progression != null:
				hero.progression.add_xp(800.0)
