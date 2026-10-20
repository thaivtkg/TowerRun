class_name AbilitySystem
extends Node

signal ability_executed(source: CombatEntity, ability: Ability)

var combat_system: CombatSystem
var targeting_system: TargetingSystem

# [ADDED] Lắng nghe Event từ Combat System
func setup_hooks() -> void:
	if not combat_system.damage_dealt.is_connected(_on_damage_dealt):
		combat_system.damage_dealt.connect(_on_damage_dealt)
	if not combat_system.entity_killed.is_connected(_on_entity_killed):
		combat_system.entity_killed.connect(_on_entity_killed)


# Trả về bool để biết ability có thực sự thi triển không (có target không)
func execute_ability(ability: Ability) -> bool:
	if ability == null or not is_instance_valid(ability.owner): return false
	
	var source: CombatEntity = ability.owner
	# Kiểm tra năng lượng thực tế truyền từ CombatEntity
	if not ability.is_ready(source.current_energy): return false 
	
	var targets: Array[CombatEntity] = targeting_system.get_targets_for_ability(source, ability.data)
	# Ngăn Start Cooldown và trừ Energy nếu không có mục tiêu
	if targets.is_empty(): return false 
	
	print("\n[AbilitySystem] 💥 %s casts [%s] %s!" % [source.name, AbilityData.AbilityType.keys()[ability.data.ability_type], ability.data.name])
	
	# AbilitySystem thực thi Energy Contract
	if ability.data.ability_type == AbilityData.AbilityType.ULTIMATE:
		source.current_energy = 0.0 # Ultimate luôn xả cạn năng lượng
	else:
		source.current_energy = max(0.0, source.current_energy - ability.data.energy_cost)
		
	ability.start_cooldown()
	
	for target in targets:
		for effect in ability.data.effects:
			_apply_effect(effect, source, target)
			
	ability_executed.emit(source, ability)
	return true # Cast thành công

# Theo dõi các Passive đang chạy để cho phép Chain nhưng chặn Cycle
var _executing_passives: Array[Ability] = []

func trigger_passives(source: CombatEntity, condition: AbilityData.TriggerCondition) -> void:
	if source == null or source.is_dead: return
	
	for ability in source.unlocked_abilities:
		if ability.data.ability_type == AbilityData.AbilityType.PASSIVE:
			if ability.data.trigger_condition == condition and ability.is_ready(source.current_energy):
				
				# [FIX P1.5] Chặn tự gọi đệ quy (Cycle), nhưng cho phép gọi chéo (Chain)
				if ability in _executing_passives: continue 
				
				var targets = targeting_system.get_targets_for_ability(source, ability.data)
				if targets.is_empty(): continue
				
				_executing_passives.append(ability) # Khóa Ability này
				
				if ability.data.cooldown > 0: ability.start_cooldown()
				print("[AbilitySystem] ⚙️ PASSIVE TRIGGERED: [%s] by %s" % [ability.data.name, source.name])
				
				for target in targets:
					for effect in ability.data.effects:
						_apply_effect(effect, source, target)
						
				_executing_passives.erase(ability) # Mở khóa

func _on_damage_dealt(source: CombatEntity, target: CombatEntity, _amount: float, is_crit: bool, _damage_type: int = DamageEvent.DamageType.PHYSICAL) -> void:
	trigger_passives(source, AbilityData.TriggerCondition.ON_ATTACK)
	if is_crit:
		trigger_passives(source, AbilityData.TriggerCondition.ON_CRIT)
		
	if target != null and not target.is_dead:
		trigger_passives(target, AbilityData.TriggerCondition.ON_TAKE_DAMAGE)
		
		# SPRINT 4: Thực thể bị ăn đòn sẽ được hồi 10 Năng lượng (chuẩn Auto-battler)
		target._gain_energy(10.0)

func _on_entity_killed(killer: CombatEntity, _victim: CombatEntity) -> void:
	trigger_passives(killer, AbilityData.TriggerCondition.ON_KILL)

# ==========================================
# EFFECTS EXECUTION
# ==========================================
func _apply_effect(effect: EffectData, source: CombatEntity, target: CombatEntity) -> void:
	if effect is DamageEffectData:
		var dmg_effect = effect as DamageEffectData
		var actual_dmg: float = dmg_effect.calculate_total_value(source)
		var event = DamageEvent.new(source, target, actual_dmg, dmg_effect.damage_type)
		event.is_crit = dmg_effect.can_crit and (randf() <= source.get_crit_chance())
		event.crit_multiplier = source.get_crit_damage()
		combat_system.process_attack(event)
		
	elif effect is HealEffectData:
		var heal_effect = effect as HealEffectData
		var actual_heal: float = heal_effect.calculate_total_value(source)
		# Tăng 50% hiệu lực hồi máu cho đồng minh dưới 40% máu (chuẩn Nguyện Ước Cứu Rỗi)
		if target.max_hp > 0.0 and (target.current_hp / target.max_hp) <= 0.40:
			actual_heal *= 1.50
		var old_hp: float = target.current_hp
		target.heal(actual_heal)
		var actual_healed: float = target.current_hp - old_hp
		if combat_system != null and actual_healed > 0.0:
			combat_system.entity_healed.emit(source, target, actual_healed)
		print("[AbilitySystem] 💚 %s heals %s for %.1f HP. (New HP: %.1f)" % [source.name, target.name, actual_healed, target.current_hp])
