extends Node2D

@export var hero_scene: PackedScene
@export var enemy_scene: PackedScene

@onready var hero_spawn: Marker2D = $HeroSpawn
@onready var enemy_spawn: Marker2D = $EnemySpawn

var active_hero: HeroEntity = null
var active_enemy: EnemyEntity = null

func _ready() -> void:
	# Cập nhật State toàn cục
	GameManager.change_state(GameManager.GameState.BATTLE)
	_start_battle()

func _start_battle() -> void:
	print("=====================================")
	print("[BattleManager] ⚔️ BATTLE STARTED ⚔️")
	print("=====================================")
	
	# 🔮 Predictive Error: Quên kéo scene vào Inspector
	if hero_scene == null or enemy_scene == null:
		printerr("[BattleManager] FATAL: Hero or Enemy scene not assigned in Inspector.")
		return
		
	# 1. Khởi tạo Mock Data cho nhanh
	var mock_hero := HeroData.new()
	mock_hero.name = "Kira (Assassin)"
	mock_hero.base_hp = 100.0
	mock_hero.base_attack = 18.0
	mock_hero.attack_speed = 1.2 # Đánh nhanh
	
	var mock_enemy := EnemyData.new()
	mock_enemy.name = "Slime Boss"
	mock_enemy.base_hp = 150.0
	mock_enemy.base_attack = 10.0
	mock_enemy.attack_speed = 0.8 # Đánh chậm
	
	# 2. Sinh Node
	active_hero = hero_scene.instantiate() as HeroEntity
	add_child(active_hero)
	active_hero.global_position = hero_spawn.global_position
	active_hero.died.connect(_on_hero_died)
	
	active_enemy = enemy_scene.instantiate() as EnemyEntity
	add_child(active_enemy)
	active_enemy.global_position = enemy_spawn.global_position
	active_enemy.died.connect(_on_enemy_died)
	
	# 3. Setup tham chiếu Target & Bắt đầu đánh
	active_hero.target = active_enemy
	active_enemy.target = active_hero
	
	active_hero.initialize(mock_hero)
	active_enemy.initialize(mock_enemy)

# 🔮 Luồng Combat kết thúc an toàn, chuẩn bị State Machine
func _on_hero_died(_entity: HeroEntity) -> void:
	print("[BattleManager] ❌ DEFEAT - All Heroes are dead.")
	GameManager.change_state(GameManager.GameState.GAME_OVER)

func _on_enemy_died(_entity: EnemyEntity) -> void:
	print("[BattleManager] 🏆 VICTORY - Floor Cleared!")
	GameManager.change_state(GameManager.GameState.REWARD)
