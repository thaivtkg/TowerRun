class_name EnemyEntity
extends CombatEntity

@export var data: EnemyData

@onready var attack_timer: Timer = $AttackTimer

func initialize(initial_data: EnemyData, spawn_level: int = 1, spawn_rank: EnemyData.EnemyRank = EnemyData.EnemyRank.NORMAL, is_solo_boss: bool = false) -> void:
	data = initial_data
	if data == null:
		printerr("[EnemyEntity] FATAL: EnemyData is null.")
		return
		
	level = spawn_level
	name = data.name
	
	var effective_rank: EnemyData.EnemyRank = spawn_rank
	if effective_rank == EnemyData.EnemyRank.NORMAL and "rank" in data and data.rank != EnemyData.EnemyRank.NORMAL:
		effective_rank = data.rank
		
	var level_hp_factor: float = 1.0 + (level - 1) * 0.10
	var rank_mult: float = 1.0
	if is_solo_boss:
		rank_mult = 4.0
		damage_reduction = 0.30
	else:
		match effective_rank:
			EnemyData.EnemyRank.ELITE:
				rank_mult = 1.8
			EnemyData.EnemyRank.BOSS:
				rank_mult = 3.5
			_:
				rank_mult = 1.0
				
	max_hp = data.base_hp * level_hp_factor * rank_mult
	current_hp = max_hp
	
	if "max_energy" in data and data.max_energy > 0.0:
		max_energy = data.max_energy
	if "starting_energy" in data:
		current_energy = data.starting_energy
	else:
		current_energy = 0.0
		
	var has_abilities: bool = not data.abilities.is_empty()
	setup_status_bar(false, has_abilities)
	hp_changed.emit(current_hp, max_hp)
	energy_changed.emit(current_energy, max_energy)
	
	unlocked_abilities.clear()
	for ab in data.abilities:
		if ab != null:
			var cloned: AbilityData = HeroEntity.clone_ability_runtime(ab)
			unlocked_abilities.append(Ability.new(self, cloned))
	
	var safe_attack_speed: float = max(0.1, data.attack_speed)
	attack_timer.wait_time = 1.0 / safe_attack_speed
	
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		
	attack_timer.start()
	print("[EnemyEntity] Initialized: %s (Lv%d, Rank %s) | HP: %.1f | Energy: %.1f/%.1f" % [
		data.name, level, EnemyData.EnemyRank.keys()[effective_rank], current_hp, current_energy, max_energy
	])

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
	
	# Kích hoạt Ultimate / Kỹ năng khi đầy Năng lượng
	if current_energy >= max_energy:
		for ability in unlocked_abilities:
			if ability.is_ready(current_energy):
				ability_requested.emit(ability)
				return
		
	var event := DamageEvent.new(self, target, get_attack(), DamageEvent.DamageType.PHYSICAL)
	event.is_crit = (randf() <= get_crit_chance())
	event.crit_multiplier = get_crit_damage()
	attack_requested.emit(event)
	_gain_energy(energy_per_attack)

# ==========================================
# STATS OVERRIDES
# Trỏ trực tiếp các hợp đồng chỉ số về EnemyData kết hợp Level & Rank
# ==========================================

func get_attack_range() -> int:
	return int(data.attack_range) if data != null else 1

func get_defense() -> float:
	if data == null: return 0.0
	var level_factor: float = 1.0 + (level - 1) * 0.05
	return data.base_defense * level_factor

func get_crit_chance() -> float:
	return data.crit_chance if data != null else 0.0

func get_crit_damage() -> float:
	return data.crit_damage if data != null else 2.0

func get_attack() -> float:
	if data == null: return 10.0
	var level_factor: float = 1.0 + (level - 1) * 0.06
	var rank_mult: float = 1.0
	if damage_reduction > 0.0:
		rank_mult = 1.6
	elif "rank" in data and data.rank == EnemyData.EnemyRank.BOSS:
		rank_mult = 1.5
	elif "rank" in data and data.rank == EnemyData.EnemyRank.ELITE:
		rank_mult = 1.8
	return data.base_attack * level_factor * rank_mult

func get_spell_power() -> float:
	if data == null: return 10.0
	var base_sp: float = data.base_spell_power if "base_spell_power" in data else 10.0
	var level_factor: float = 1.0 + (level - 1) * 0.06
	return base_sp * level_factor

func get_attack_speed() -> float:
	return data.attack_speed if data != null else 1.0
