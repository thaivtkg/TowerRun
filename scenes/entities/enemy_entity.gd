class_name EnemyEntity
extends CombatEntity

@export var data: EnemyData
var target: CombatEntity = null

@onready var attack_timer: Timer = $AttackTimer

func initialize(initial_data: EnemyData) -> void:
	data = initial_data
	if data == null:
		printerr("[EnemyEntity] FATAL: EnemyData is null.")
		return
		
	name = data.name
	current_hp = data.base_hp
	
	var safe_attack_speed: float = max(0.1, data.attack_speed)
	attack_timer.wait_time = 1.0 / safe_attack_speed
	
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		
	attack_timer.start()
	print("[EnemyEntity] Initialized: ", data.name, " | HP: ", current_hp)

func _die() -> void:
	attack_timer.stop()
	super()

func _on_attack_timer_timeout() -> void:
	if is_dead or data == null: return
	
	if is_instance_valid(target) and not target.is_dead:
		target.take_damage(data.base_attack)
	else:
		attack_timer.stop()
