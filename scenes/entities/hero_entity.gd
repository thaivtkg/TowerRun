class_name HeroEntity
extends CombatEntity

@export var data: HeroData

@onready var attack_timer: Timer = $AttackTimer

func initialize(initial_data: HeroData) -> void:
	data = initial_data
	if data == null:
		printerr("[HeroEntity] FATAL: HeroData is null.")
		return
		
	name = data.name 
	current_hp = data.base_hp
	
	var safe_attack_speed: float = max(0.1, data.attack_speed)
	attack_timer.wait_time = 1.0 / safe_attack_speed
	
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		
	attack_timer.start()
	print("[HeroEntity] Initialized: ", data.name, " | HP: ", current_hp)

func _die() -> void:
	attack_timer.stop()
	super()

func _on_attack_timer_timeout() -> void:
	if is_dead or data == null: return
	
	if is_instance_valid(target) and not target.is_dead:
		var event := DamageEvent.new(self, target, data.base_attack, DamageEvent.DamageType.PHYSICAL)
		event.is_crit = (randf() <= get_crit_chance())
		event.crit_multiplier = get_crit_damage()
		attack_requested.emit(event)

# ==========================================
# STATS OVERRIDES
# Trỏ trực tiếp các hợp đồng chỉ số về HeroData
# ==========================================

func get_defense() -> float:
	return data.base_defense if data != null else 0.0

func get_crit_chance() -> float:
	return data.crit_chance if data != null else 0.0

func get_crit_damage() -> float:
	return data.crit_damage if data != null else 2.0
