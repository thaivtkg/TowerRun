class_name EnemyEntity
extends CharacterBody2D

signal died(entity: EnemyEntity)

@export var data: EnemyData
var current_hp: float = 0.0
var target: Node2D = null # Tham chiếu tới Hero
var is_dead: bool = false

@onready var attack_timer: Timer = $AttackTimer

func initialize(initial_data: EnemyData) -> void:
	data = initial_data
	if data == null:
		printerr("[EnemyEntity] FATAL: HeroData is null.")
		return
		
	current_hp = data.base_hp
	
	# Validate attack speed to prevent division by zero or negative timers
	var safe_attack_speed: float = max(0.1, data.attack_speed)
	attack_timer.wait_time = 1.0 / safe_attack_speed
	
	# Prevent duplicate signal connections
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		
	attack_timer.start()
	
	print("[EnemyEntity] Initialized: ", data.name, " | HP: ", current_hp)

func take_damage(amount: float) -> void:
	if is_dead: return
	
	# Validate damage input to prevent healing from negative damage or crash from NaN/INF
	if amount < 0 or is_nan(amount) or is_inf(amount):
		printerr("[EnemyEntity] WARNING: Invalid damage amount received: ", amount)
		return
	
	current_hp -= amount
	print("[Combat] ", data.name, " takes ", amount, " damage! (HP: ", current_hp, "/", data.base_hp, ")")
	
	if current_hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	attack_timer.stop()
	print("[Combat] ☠️ ", data.name, " has died.")
	died.emit(self)
	queue_free()

func _on_attack_timer_timeout() -> void:
	if is_dead or data == null: return
	
	if is_instance_valid(target) and not target.is_dead:
		target.take_damage(data.base_attack)
	else:
		attack_timer.stop()
