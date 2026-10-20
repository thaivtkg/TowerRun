class_name HeroEntity
extends CombatEntity

@export var data: HeroData
@onready var attack_timer: Timer = $AttackTimer
var progression: HeroProgression = null
var metrics: CombatMetric = CombatMetric.new()

# SPRINT 4: RUNTIME ABILITIES STATE
var basic_attack_ability: Ability           
var runtime_pools: Dictionary = {} 
var pending_milestones: Array[int] = []
var pending_upgrade_milestone: int = 0
var _has_pending_milestone: bool = false
var has_pending_milestone: bool:
	get:
		return _has_pending_milestone or (not pending_milestones.is_empty())
	set(val):
		_has_pending_milestone = val
		if not val:
			pending_milestones.clear()
			pending_upgrade_milestone = 0
		_update_upgrade_badge()

var upgrade_badge: Node2D = null

func _setup_upgrade_badge() -> void:
	if upgrade_badge != null and is_instance_valid(upgrade_badge):
		return
	upgrade_badge = Node2D.new()
	upgrade_badge.name = "UpgradeBadge"
	# Placed safely above status_bar at Vector2(0, -35), preventing overlap
	upgrade_badge.position = Vector2(0, -56)
	
	var badge_label := Label.new()
	badge_label.name = "BadgeLabel"
	badge_label.text = "⬆️ NÂNG CẤP"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.position = Vector2(-40, -10)
	badge_label.size = Vector2(80, 20)
	badge_label.add_theme_font_size_override("font_size", 10)
	badge_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	badge_label.add_theme_constant_override("outline_size", 2)
	badge_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 0.9))
	upgrade_badge.add_child(badge_label)
	
	add_child(upgrade_badge)
	upgrade_badge.visible = has_pending_milestone

func _update_upgrade_badge() -> void:
	if upgrade_badge == null:
		_setup_upgrade_badge()
	if upgrade_badge != null:
		upgrade_badge.visible = has_pending_milestone

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
	var init_lvl: int = progression.current_level if progression != null else 1
	max_hp = calculate_max_hp(init_lvl)
	current_hp = max_hp
	if "max_energy" in data and data.max_energy > 0.0:
		max_energy = data.max_energy
	if "starting_energy" in data:
		current_energy = data.starting_energy
	else:
		current_energy = 0.0
	setup_status_bar(true)
	_setup_upgrade_badge()
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

func _on_level_up(_new_level: int) -> void:
	level = _new_level
	_update_scaled_max_hp()

func _on_milestone_reached(milestone: int) -> void:
	pending_milestones.append(milestone)
	_has_pending_milestone = true
	_update_upgrade_badge()
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
	
	has_pending_milestone = false
	pending_milestones.clear()
	pending_upgrade_milestone = 0
	_update_upgrade_badge()

# ==========================================
# SPRINT 5: HERO STAT PROGRESSION (GD SPEC SECTION I.2)
# ==========================================
static func get_tier_multiplier(lvl: int) -> float:
	if lvl >= 99: return 1.30
	if lvl >= 75: return 1.20
	if lvl >= 50: return 1.15
	if lvl >= 25: return 1.10
	if lvl >= 10: return 1.05
	return 1.00

func get_effective_level() -> int:
	if progression != null:
		return progression.current_level
	return level

var passive_stat_bonus: float = 0.0

func add_milestone_compensation(count: int = 1) -> void:
	passive_stat_bonus += 0.05 * float(count)
	_update_scaled_max_hp()

func calculate_max_hp(lvl: int) -> float:
	var base: float = data.base_hp if data != null else 100.0
	var factor: float = 1.0 + float(lvl - 1) * 0.08
	var t_mult: float = get_tier_multiplier(lvl)
	return base * factor * t_mult * (1.0 + passive_stat_bonus)

func get_attack() -> float:
	var base: float = data.base_attack if data != null else 10.0
	var lvl: int = get_effective_level()
	var factor: float = 1.0 + float(lvl - 1) * 0.08
	var t_mult: float = get_tier_multiplier(lvl)
	return base * factor * t_mult * (1.0 + passive_stat_bonus)

func get_spell_power() -> float:
	var base: float = data.base_spell_power if (data != null and "base_spell_power" in data) else 10.0
	var lvl: int = get_effective_level()
	var factor: float = 1.0 + float(lvl - 1) * 0.08
	var t_mult: float = get_tier_multiplier(lvl)
	return base * factor * t_mult * (1.0 + passive_stat_bonus)

func get_defense() -> float:
	var base: float = data.base_defense if data != null else 0.0
	var lvl: int = get_effective_level()
	var factor: float = 1.0 + float(lvl - 1) * 0.05
	var t_mult: float = get_tier_multiplier(lvl)
	return base * factor * t_mult

func _update_scaled_max_hp() -> void:
	if data == null: return
	var old_max := max_hp
	var new_max := calculate_max_hp(get_effective_level())
	if is_equal_approx(old_max, new_max):
		return
	if old_max > 0.0 and new_max > 0.0:
		var ratio := current_hp / old_max
		max_hp = new_max
		current_hp = clampf(new_max * ratio, 1.0, new_max)
	else:
		max_hp = new_max
		current_hp = new_max
	hp_changed.emit(current_hp, max_hp)

func get_attack_range() -> int: return int(data.attack_range) if data != null else 1
func get_crit_chance() -> float: return data.crit_chance if data != null else 0.0
func get_crit_damage() -> float: return data.crit_damage if data != null else 2.0
func get_attack_speed() -> float: return data.attack_speed if data != null else 1.0

# ==========================================
# FULL PROGRESSION & ABILITIES PERSISTENCE (S4.6+)
# ==========================================
func serialize() -> Dictionary:
	var hero_dict := {
		"name": name,
		"level": progression.current_level if progression != null else 1,
		"xp": progression.current_xp if progression != null else 0.0,
		"deployed_cell": [deployed_cell.x, deployed_cell.y],
		"unlocked_abilities": []
	}
	if basic_attack_ability != null and basic_attack_ability.data != null:
		hero_dict["basic_attack_effects"] = _serialize_effects(basic_attack_ability.data.effects)
		
	for ab in unlocked_abilities:
		if ab != null and ab.data != null:
			hero_dict["unlocked_abilities"].append({
				"id": ab.data.id,
				"name": ab.data.name,
				"description": ab.data.description,
				"ability_type": int(ab.data.ability_type),
				"target_rule": int(ab.data.target_rule),
				"cooldown": ab.data.cooldown,
				"effects": _serialize_effects(ab.data.effects)
			})
	return hero_dict

func deserialize(saved: Dictionary) -> void:
	if saved.has("level") and progression != null:
		progression.current_level = int(saved["level"])
		level = progression.current_level
	if saved.has("xp") and progression != null:
		progression.current_xp = float(saved["xp"])
	if saved.has("deployed_cell"):
		var cell_arr: Array = saved["deployed_cell"]
		if cell_arr.size() == 2:
			deployed_cell = Vector2i(int(cell_arr[0]), int(cell_arr[1]))
			
	if saved.has("basic_attack_effects") and basic_attack_ability != null and basic_attack_ability.data != null:
		_deserialize_effects(basic_attack_ability.data.effects, saved["basic_attack_effects"])
		
	if saved.has("unlocked_abilities"):
		unlocked_abilities.clear()
		for ab_dict in saved["unlocked_abilities"]:
			var ab_data := AbilityData.new()
			ab_data.id = ab_dict.get("id", "")
			ab_data.name = ab_dict.get("name", "Ability")
			ab_data.description = ab_dict.get("description", "")
			ab_data.ability_type = ab_dict.get("ability_type", AbilityData.AbilityType.ACTIVE)
			ab_data.target_rule = ab_dict.get("target_rule", AbilityData.TargetRule.SINGLE_ENEMY)
			ab_data.cooldown = float(ab_dict.get("cooldown", 1.0))
			
			ab_data.effects = []
			if ab_dict.has("effects"):
				for eff_dict in ab_dict["effects"]:
					var eff: EffectData
					if eff_dict.get("is_heal", false):
						eff = HealEffectData.new()
						eff.heal_amount = float(eff_dict.get("base_amount", 0.0))
					else:
						eff = DamageEffectData.new()
						eff.base_damage = float(eff_dict.get("base_amount", 0.0))
					eff.base_amount = float(eff_dict.get("base_amount", 0.0))
					eff.scalings = eff_dict.get("scalings", {}).duplicate()
					ab_data.effects.append(eff)
			unlocked_abilities.append(Ability.new(self, ab_data))
			
			# Remove from runtime pools if matches so it won't be rolled again
			for milestone in runtime_pools.keys():
				var pool: Array = runtime_pools[milestone]
				for item in pool:
					if item != null and item.name == ab_data.name:
						pool.erase(item)
						break

static func _serialize_effects(effects: Array[EffectData]) -> Array:
	var res := []
	for eff in effects:
		if eff != null:
			res.append({
				"is_heal": (eff is HealEffectData),
				"base_amount": eff.base_amount,
				"scalings": eff.scalings.duplicate()
			})
	return res

static func _deserialize_effects(target_effects: Array[EffectData], saved_effects: Array) -> void:
	for i in range(mini(target_effects.size(), saved_effects.size())):
		var eff := target_effects[i]
		var s_eff: Dictionary = saved_effects[i]
		if eff != null and s_eff != null:
			eff.base_amount = float(s_eff.get("base_amount", eff.base_amount))
			if eff is DamageEffectData:
				eff.base_damage = eff.base_amount
			elif eff is HealEffectData:
				eff.heal_amount = eff.base_amount
			if s_eff.has("scalings") and typeof(s_eff["scalings"]) == TYPE_DICTIONARY:
				eff.scalings = s_eff["scalings"].duplicate()
