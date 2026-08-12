class_name HeroEntity
extends CombatEntity

@export var data: HeroData
var target: CombatEntity = null

@onready var attack_timer: Timer = $AttackTimer

func initialize(initial_data: HeroData) -> void:
	data = initial_data
	if data == null:
		printerr("[HeroEntity] FATAL: HeroData is null.")
		return
		
	# Gán tên Node bằng tên Data để log của CombatEntity in ra đúng tên nhân vật
	name = data.name 
	current_hp = data.base_hp
	
	var safe_attack_speed: float = max(0.1, data.attack_speed)
	attack_timer.wait_time = 1.0 / safe_attack_speed
	
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		
	attack_timer.start()
	print("[HeroEntity] Initialized: ", data.name, " | HP: ", current_hp)

# Override hàm _die() của base class để dọn dẹp các logic nội bộ
func _die() -> void:
	attack_timer.stop()
	super()	

func get_crit_chance() -> float:
	return data.crit_chance if data != null else 0.0
	
func get_crit_damage() -> float:
	return data.crit_damage if data != null else 2.0

func _on_attack_timer_timeout() -> void:
	if is_dead or data == null: return
	
	if is_instance_valid(target) and not target.is_dead:
		var event := DamageEvent.new(self, target, data.base_attack, DamageEvent.DamageType.PHYSICAL)
		
		# Đổ xí ngầu (Roll) xem có chí mạng không
		event.is_crit = (randf() <= get_crit_chance())
		event.crit_multiplier = get_crit_damage()
		
		attack_requested.emit(event)
		
# Override hàm của CombatEntity để lấy giáp từ HeroData
func get_defense() -> float:
	if data != null:
		return data.base_defense
	return 0.0
