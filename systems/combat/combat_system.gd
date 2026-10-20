class_name CombatSystem
extends Node

# Tín hiệu này sẽ được ProgressionSystem lắng nghe ở các Task sau
signal damage_dealt(source: CombatEntity, target: CombatEntity, amount: float, is_crit: bool, damage_type: DamageEvent.DamageType)
signal entity_killed(killer: CombatEntity, victim: CombatEntity)
signal entity_healed(source: CombatEntity, target: CombatEntity, amount: float)

func process_attack(event: DamageEvent) -> void:
	if event == null: return
	if not is_instance_valid(event.target) or event.target.is_dead: return
		
	# 1. Tính toán Chí mạng
	if event.is_crit:
		event.final_damage = event.base_damage * event.crit_multiplier
	
	# 2. Tính toán Giảm thương
	if event.damage_type == DamageEvent.DamageType.PHYSICAL:
		var target_defense: float = max(0.0, event.target.get_defense())
		var damage_multiplier: float = 100.0 / (100.0 + target_defense)
		event.final_damage = event.final_damage * damage_multiplier
	elif event.damage_type == DamageEvent.DamageType.MAGIC:
		var target_defense: float = max(0.0, event.target.get_defense())
		# Kháng Phép cơ bản tương đương 70% giá trị Giáp
		var magic_multiplier: float = 100.0 / (100.0 + target_defense * 0.70)
		event.final_damage = event.final_damage * magic_multiplier
	elif event.damage_type == DamageEvent.DamageType.TRUE:
		pass 
		
	# 3. Tính toán Giảm sát thương nhận vào (ví dụ: Solo Raid Boss giảm 30%)
	if "damage_reduction" in event.target and event.target.damage_reduction > 0.0:
		event.final_damage *= (1.0 - clampf(event.target.damage_reduction, 0.0, 1.0))
		
	# 4. Bảo hiểm chống bốc hơi (Survivability Guardrail):
	# Sát thương đơn phát từ Quái vật lên Tướng bị chặn trần không quá 40% Max HP của Tướng
	if event.source is EnemyEntity and event.target is HeroEntity:
		if event.target.max_hp > 0.0:
			event.final_damage = minf(event.final_damage, event.target.max_hp * 0.40)
		
	event.final_damage = max(1.0, event.final_damage)
	
	var crit_label: String = "💥 CRIT!" if event.is_crit else "Normal"
	print("[CombatSystem] %s -> %s [%s] | Base: %.1f | DEF: %.1f | Final: %.1f" % [
		event.source.name, event.target.name, crit_label,
		event.base_damage, event.target.get_defense(), event.final_damage
	])
	
	# Áp dụng sát thương với phân loại DamageType
	event.target.take_damage(event.final_damage, event.damage_type)
	
	# Kích hoạt signal cho UI, VFX, Passive & Progression
	damage_dealt.emit(event.source, event.target, event.final_damage, event.is_crit, event.damage_type)
	
	if event.target.is_dead:
		entity_killed.emit(event.source, event.target)
