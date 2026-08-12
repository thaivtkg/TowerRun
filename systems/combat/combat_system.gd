class_name CombatSystem
extends Node

# Xử lý toàn bộ logic tính toán trước khi áp dụng sát thương
func process_attack(event: DamageEvent) -> void:
	if event == null: return
	if not is_instance_valid(event.target) or event.target.is_dead: return
		
	# 1. Tính toán Chí mạng (áp dụng trước khi tính giáp)
	if event.is_crit:
		event.final_damage = event.base_damage * event.crit_multiplier
	
	# 2. Tính toán Giảm thương
	if event.damage_type == DamageEvent.DamageType.PHYSICAL:
		var target_defense: float = max(0.0, event.target.get_defense())
		var damage_multiplier: float = 100.0 / (100.0 + target_defense)
		event.final_damage = event.final_damage * damage_multiplier
		
	elif event.damage_type == DamageEvent.DamageType.TRUE:
		pass # Sát thương chuẩn giữ nguyên
		
	event.final_damage = max(1.0, event.final_damage)
	
	# 3. Log có đánh dấu CRIT để phân biệt
	var crit_label: String = "💥 CRIT!" if event.is_crit else "Normal"
	print("[CombatSystem] %s -> %s [%s] | Base: %.1f | DEF: %.1f | Final: %.1f" % [
		event.source.name, event.target.name, crit_label,
		event.base_damage, event.target.get_defense(), event.final_damage
	])
	
	event.target.take_damage(event.final_damage)
