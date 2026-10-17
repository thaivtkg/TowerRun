class_name HeroEntity
extends CombatEntity

signal pending_skill_choice(hero: HeroEntity, milestone: int, choices: Array[AbilityData])
signal ability_requested(ability: Ability) 

@export var data: HeroData
@onready var attack_timer: Timer = $AttackTimer
var progression: HeroProgression = null
var metrics: CombatMetric = CombatMetric.new()

# SPRINT 4: RUNTIME ABILITIES STATE
var unlocked_abilities: Array[Ability] = [] 
var basic_attack_ability: Ability           
var runtime_pools: Dictionary = {} 
var pending_milestones: Array[int] = []

# ==========================================
# SPRINT 4: ENERGY SYSTEM (HỆ THỐNG NĂNG LƯỢNG)
# ==========================================
var current_energy: float = 0.0:
	set(val):
		current_energy = clampf(val, 0.0, max_energy)
		energy_changed.emit(current_energy, max_energy)

var max_energy: float = 100.0:
	set(val):
		max_energy = val
		energy_changed.emit(current_energy, max_energy)

var energy_per_attack: float = 25.0 # Đánh 4 phát là xả Ultimate

# ==========================================
# SPRINT 4: RUNTIME ABILITY CLONING (P0 ISOLATION)
# ==========================================
static func clone_ability_runtime(src: AbilityData) -> AbilityData:
	if src == null:
		return null
	var copy: AbilityData = src.duplicate()
	copy.effects = []
	for eff in src.effects:
		if eff != null:
			var eff_copy: EffectData = eff.duplicate()
			eff_copy.scalings = eff.scalings.duplicate()
			copy.effects.append(eff_copy)
	return copy

func _init_runtime_pools() -> void:
	runtime_pools.clear()
	var raw_pools = {
		5: data.pool_lv5_passives,
		10: data.pool_lv10_actives,
		15: data.pool_lv15_utilities,
		20: data.pool_lv20_upgrades,
		25: data.pool_lv25_signatures
	}
	for milestone in raw_pools.keys():
		var arr: Array[AbilityData] = []
		for ab in raw_pools[milestone]:
			if ab != null:
				arr.append(clone_ability_runtime(ab))
		runtime_pools[milestone] = arr

func initialize(initial_data: HeroData) -> void:
	data = initial_data
	if data == null: return
		
	name = data.name 
	max_hp = data.base_hp
	current_hp = data.base_hp
	if "max_energy" in data and data.max_energy > 0.0:
		max_energy = data.max_energy
	if "starting_energy" in data:
		current_energy = data.starting_energy
	else:
		current_energy = 0.0
	setup_status_bar(true)
	hp_changed.emit(current_hp, max_hp)
	energy_changed.emit(current_energy, max_energy)
	
	if progression == null:
		progression = HeroProgression.new()
		progression.leveled_up.connect(_on_level_up)
		progression.milestone_reached.connect(_on_milestone_reached)
	else:
		progression.current_level = 1
		progression.current_xp = 0.0
		progression.pending_milestones.clear()
	
	if data.basic_attack != null:
		basic_attack_ability = Ability.new(self, clone_ability_runtime(data.basic_attack))
	
	_init_runtime_pools()
	
	var safe_speed: float = max(0.1, data.attack_speed)
	attack_timer.wait_time = 1.0 / safe_speed
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

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

func _process(delta: float) -> void:
	if is_dead: return
	
	for ability in unlocked_abilities:
		ability.process_cooldown(delta)
		if ability.data.ability_type == AbilityData.AbilityType.ACTIVE and ability.is_ready(current_energy):
			# [FIX P2.1] Chỉ request nếu là buff bản thân, hoặc có mục tiêu hợp lệ
			if ability.data.target_rule == AbilityData.TargetRule.SELF or (is_instance_valid(target) and not target.is_dead):
				ability_requested.emit(ability)

func _on_attack_timer_timeout() -> void:
	if is_dead or data == null: return
	if not is_instance_valid(target) or target.is_dead: return # [FIX P1.1] Không đánh không khí
	
	# [S2.3 / S3.4] Range Check & Smart Retargeting
	if not is_target_in_attack_range():
		if targeting_system != null:
			var in_range := targeting_system.find_closest_target_in_range(self, get_attack_range())
			if in_range != null:
				target = in_range
		if not is_target_in_attack_range():
			step_towards_target()
			return
	
	if current_energy >= max_energy:
		for ability in unlocked_abilities:
			if ability.data.ability_type == AbilityData.AbilityType.ULTIMATE and ability.is_ready(current_energy):
				ability_requested.emit(ability)
				return 
	
	# Chỉ đi tới đây khi có target hợp lệ -> Nhận Energy chuẩn xác
	if basic_attack_ability != null:
		ability_requested.emit(basic_attack_ability)
		_gain_energy(energy_per_attack)
	else:
		var event := DamageEvent.new(self, target, data.base_attack, DamageEvent.DamageType.PHYSICAL)
		attack_requested.emit(event)
		_gain_energy(energy_per_attack)

# Hàm tăng Năng lượng công khai (để hệ thống khác có thể gọi)
func _gain_energy(amount: float) -> void:
	if is_dead:
		return
	self.current_energy += amount

func _on_level_up(_new_level: int) -> void: pass

func _on_milestone_reached(milestone: int) -> void:
	pending_milestones.append(milestone)
	print("[HeroEntity] %s reached Milestone Lv%d. Choice pending." % [name, milestone])

func pull_milestone_choices(milestone: int) -> Array[AbilityData]:
	var pool: Array = runtime_pools.get(milestone, [])
	if pool.is_empty(): return []
		
	pool.shuffle() 
	var choices: Array[AbilityData] = []
	var reveal_count: int = min(3, pool.size())
	
	for i in range(reveal_count): 
		choices.append(pool[i])
	return choices

func apply_skill_choice(milestone: int, chosen: AbilityData, revealed: Array[AbilityData]) -> void:
	if not chosen in revealed:
		printerr("[HeroEntity] Invalid skill choice. Rejected.")
		return
		
	var cloned := clone_ability_runtime(chosen)
	var runtime_ability = Ability.new(self, cloned)
	unlocked_abilities.append(runtime_ability)
	
	print("[HeroEntity] %s unlocked ability: [%s] %s" % [name, AbilityData.AbilityType.keys()[chosen.ability_type], chosen.name])
	
	var pool: Array = runtime_pools.get(milestone, [])
	for ability in revealed: pool.erase(ability)

func get_attack_range() -> int: return int(data.attack_range) if data != null else 1
func get_defense() -> float: return data.base_defense if data != null else 0.0
func get_crit_chance() -> float: return data.crit_chance if data != null else 0.0
func get_crit_damage() -> float: return data.crit_damage if data != null else 2.0
func get_attack() -> float: return data.base_attack if data != null else 10.0
func get_spell_power() -> float: return data.base_spell_power if (data != null and "base_spell_power" in data) else 10.0
func get_attack_speed() -> float: return data.attack_speed if data != null else 1.0
