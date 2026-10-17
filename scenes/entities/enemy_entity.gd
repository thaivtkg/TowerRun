class_name EnemyEntity
extends CombatEntity

@export var data: EnemyData

@onready var attack_timer: Timer = $AttackTimer

func initialize(initial_data: EnemyData) -> void:
	data = initial_data
	if data == null:
		printerr("[EnemyEntity] FATAL: EnemyData is null.")
		return
		
	name = data.name
	max_hp = data.base_hp
	current_hp = data.base_hp
	setup_status_bar(false)
	
	var safe_attack_speed: float = max(0.1, data.attack_speed)
	attack_timer.wait_time = 1.0 / safe_attack_speed
	
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		
	attack_timer.start()
	print("[EnemyEntity] Initialized: ", data.name, " | HP: ", current_hp)

func _die() -> void:
	attack_timer.stop()
	super()

func set_combat_active(active: bool) -> void:
	super(active)
	if attack_timer != null:
		if active:
			if not is_dead:
				attack_timer.start()
		else:
			attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	if is_dead or data == null: return
	if not is_instance_valid(target) or target.is_dead: return
	
	# [S2.3 / S3.4] Range Check & Smart Retargeting
	if not is_target_in_attack_range():
		if targeting_system != null:
			var in_range := targeting_system.find_closest_target_in_range(self, get_attack_range())
			if in_range != null:
				target = in_range
		if not is_target_in_attack_range():
			step_towards_target()
			return
		
	var event := DamageEvent.new(self, target, data.base_attack, DamageEvent.DamageType.PHYSICAL)
	event.is_crit = (randf() <= get_crit_chance())
	event.crit_multiplier = get_crit_damage()
	attack_requested.emit(event)

# ==========================================
# STATS OVERRIDES
# Trỏ trực tiếp các hợp đồng chỉ số về EnemyData
# ==========================================

func get_attack_range() -> int:
	return int(data.attack_range) if data != null else 1

func get_defense() -> float:
	return data.base_defense if data != null else 0.0

func get_crit_chance() -> float:
	return data.crit_chance if data != null else 0.0

func get_crit_damage() -> float:
	return data.crit_damage if data != null else 2.0
