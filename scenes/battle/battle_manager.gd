extends Node2D

@export var hero_scene: PackedScene
@export var enemy_scene: PackedScene

@onready var hero_spawn: Marker2D = $HeroSpawn
@onready var enemy_spawn: Marker2D = $EnemySpawn

# Thêm biến này dưới danh sách heroes, enemies
var corpses: Array[CombatEntity] = []

# Quản lý danh sách thực thể trên sân
var heroes: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []

var combat_system: CombatSystem
var targeting_system: TargetingSystem

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

# Khởi tạo các hệ thống hỗ trợ chiến đấu
func _init_systems() -> void:
	combat_system = CombatSystem.new()
	combat_system.name = "CombatSystem"
	add_child(combat_system)
	
	targeting_system = TargetingSystem.new()
	targeting_system.name = "TargetingSystem"
	targeting_system.heroes = self.heroes
	targeting_system.enemies = self.enemies
	add_child(targeting_system)

# Khởi tạo dữ liệu giả lập cho chế độ Multi-unit
# Sửa lại Mock Data ở hàm _spawn_mock_teams() để Kira có 50% tỷ lệ chí mạng
func _spawn_mock_teams() -> void:
	_spawn_hero("Kira (Assassin)", 100.0, 18.0, 5.0, 1.2, 0.5, 2.0, Vector2(0, -50)) # 50% Crit
	_spawn_hero("Arthur (Tank)", 200.0, 8.0, 20.0, 0.8, 0.0, 1.5, Vector2(0, 50)) # 0% Crit
	_spawn_enemy("Slime A", 50.0, 5.0, 2.0, 1.0, 0.0, 2.0, Vector2(0, -60))
	_spawn_enemy("Slime B", 50.0, 5.0, 2.0, 1.0, 0.0, 2.0, Vector2(0, 0))
	_spawn_enemy("Slime Boss", 150.0, 12.0, 10.0, 0.7, 0.1, 1.5, Vector2(0, 60)) # 10% Crit

func _spawn_hero(h_name: String, hp: float, atk: float, def: float, spd: float, crit_c: float, crit_d: float, offset: Vector2) -> void:
	var data := HeroData.new()
	data.name = h_name; data.base_hp = hp; data.base_attack = atk; data.base_defense = def; data.attack_speed = spd; 
	data.crit_chance = crit_c; data.crit_damage = crit_d
	
	var hero := hero_scene.instantiate() as HeroEntity
	add_child(hero)
	hero.global_position = hero_spawn.global_position + offset
	
	# Sử dụng bind(true) để truyền thêm cờ is_hero vào hàm callback
	hero.died.connect(_on_entity_died.bind(true))
	hero.attack_requested.connect(combat_system.process_attack)
	hero.initialize(data)
	heroes.append(hero)

func _spawn_enemy(e_name: String, hp: float, atk: float, def: float, spd: float, crit_c: float, crit_d: float, offset: Vector2) -> void:
	var data := EnemyData.new()
	data.name = e_name; data.base_hp = hp; data.base_attack = atk; data.base_defense = def; data.attack_speed = spd; 
	data.crit_chance = crit_c; data.crit_damage = crit_d
	
	var enemy := enemy_scene.instantiate() as EnemyEntity
	add_child(enemy)
	enemy.global_position = enemy_spawn.global_position + offset
	
	enemy.died.connect(_on_entity_died.bind(false))
	enemy.attack_requested.connect(combat_system.process_attack)
	enemy.initialize(data)
	enemies.append(enemy)

# Xử lý vòng đời khi một thực thể ngã xuống
func _on_entity_died(entity: CombatEntity, is_hero: bool) -> void:
	if is_hero: heroes.erase(entity)
	else: enemies.erase(entity)
		
	corpses.append(entity) # Chuyển vào mảng xác chết
	_check_battle_end()

# Đánh giá điều kiện thắng / thua dựa trên số lượng mảng
func _check_battle_end() -> void:
	if GameManager.current_state != GameManager.GameState.BATTLE: return
		
	if heroes.is_empty(): _end_battle(GameManager.GameState.GAME_OVER, "❌ DEFEAT - All Heroes have fallen.")
	elif enemies.is_empty(): _end_battle(GameManager.GameState.REWARD, "🏆 VICTORY - Floor Cleared!")
	
func _end_battle(state: GameManager.GameState, log_message: String) -> void:
	print("[BattleManager] ", log_message)
	print("[BattleManager] Cleaning up ", corpses.size(), " corpses.")
	
	# An toàn dọn dẹp xác chết sau khi trận chiến kết thúc
	for corpse in corpses:
		if is_instance_valid(corpse):
			corpse.queue_free()
	corpses.clear()
	
	GameManager.change_state(state)
