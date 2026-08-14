class_name HeroEntity
extends CombatEntity

signal pending_skill_choice(hero: HeroEntity, milestone: int, choices: Array[AbilityData])

@export var data: HeroData
@onready var attack_timer: Timer = $AttackTimer
var progression: HeroProgression = null

# ==========================================
# SPRINT 4: RUNTIME ABILITIES STATE
# ==========================================
var unlocked_abilities: Array[AbilityData] = []
var runtime_pools: Dictionary = {} # Quản lý Pool dùng một lần cho Run hiện tại

func initialize(initial_data: HeroData) -> void:
	data = initial_data
	if data == null: return
		
	name = data.name 
	current_hp = data.base_hp
	
	progression = HeroProgression.new()
	progression.leveled_up.connect(_on_level_up)
	progression.milestone_reached.connect(_on_milestone_reached)
	
	# Clone data vào Runtime để không làm hỏng Resource gốc
	runtime_pools[5] = data.pool_lv5_passives.duplicate()
	runtime_pools[10] = data.pool_lv10_actives.duplicate()
	runtime_pools[15] = data.pool_lv15_utilities.duplicate()
	runtime_pools[20] = data.pool_lv20_upgrades.duplicate()
	runtime_pools[25] = data.pool_lv25_signatures.duplicate()
	
	var safe_speed: float = max(0.1, data.attack_speed)
	attack_timer.wait_time = 1.0 / safe_speed
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

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

func _on_level_up(new_level: int) -> void:
	print("[HeroEntity] 🌟 %s is now Level %d!" % [name, new_level])

# ==========================================
# RANDOM REVEAL & CHOICE LOGIC
# ==========================================
func _on_milestone_reached(milestone: int) -> void:
	var pool: Array = runtime_pools.get(milestone, [])
	if pool.is_empty():
		print("[HeroEntity] WARNING: No abilities found in pool for Lv", milestone)
		return
		
	pool.shuffle() # Xào bài (Controlled Randomness)
	var choices: Array[AbilityData] = []
	var reveal_count: int = min(3, pool.size()) # Rút tối đa 3 thẻ
	
	for i in range(reveal_count):
		choices.append(pool[i])
		
	pending_skill_choice.emit(self, milestone, choices)

func apply_skill_choice(milestone: int, chosen: AbilityData, revealed: Array[AbilityData]) -> void:
	unlocked_abilities.append(chosen)
	print("[HeroEntity] %s unlocked ability: [%s] %s" % [name, AbilityData.AbilityType.keys()[chosen.ability_type], chosen.name])
	
	# Core mechanic: Xóa VĨNH VIỄN các kỹ năng đã reveal khỏi pool của mốc này
	var pool: Array = runtime_pools.get(milestone, [])
	for ability in revealed:
		pool.erase(ability)

# ==========================================
# STATS OVERRIDES
# ==========================================
func get_defense() -> float: return data.base_defense if data != null else 0.0
func get_crit_chance() -> float: return data.crit_chance if data != null else 0.0
func get_crit_damage() -> float: return data.crit_damage if data != null else 2.0
