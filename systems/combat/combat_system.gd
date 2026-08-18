class_name CombatSystem
extends Node

# Tín hiệu này sẽ được ProgressionSystem lắng nghe ở các Task sau
signal metric_recorded(metric: CombatMetric)
signal damage_dealt(source: CombatEntity, target: CombatEntity, amount: float, is_crit: bool)
signal entity_killed(killer: CombatEntity, victim: CombatEntity)

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
		
	elif event.damage_type == DamageEvent.DamageType.TRUE:
		pass 
		
	event.final_damage = max(1.0, event.final_damage)
	
	var crit_label: String = "💥 CRIT!" if event.is_crit else "Normal"
	print("[CombatSystem] %s -> %s [%s] | Base: %.1f | DEF: %.1f | Final: %.1f" % [
		event.source.name, event.target.name, crit_label,
		event.base_damage, event.target.get_defense(), event.final_damage
	])
	
	# Áp dụng sát thương
	event.target.take_damage(event.final_damage)
	
	# --- SPRINT 4: KÍCH HOẠT EVENT CHO PASSIVE ---
	# (Biến final_damage có thể khác tên tùy theo code hiện tại của bạn)
	damage_dealt.emit(event.source, event.target, event.base_damage, event.is_crit)
	
	if event.target.is_dead:
		entity_killed.emit(event.source, event.target)
	
	# ==========================================
	# REPORTING METRICS (Phóng viên chiến trường)
	# ==========================================
	
	# Metric 1: Damage (Ghi nhận lượng sát thương cuối cùng đã gây ra/gánh chịu)
	var damage_metric = CombatMetric.new(CombatMetric.MetricType.DAMAGE, event.source, event.target, event.final_damage)
	metric_recorded.emit(damage_metric)
	
	# Metric 2: Crit (Ghi nhận số lần chí mạng)
	if event.is_crit:
		var crit_metric = CombatMetric.new(CombatMetric.MetricType.CRIT, event.source, event.target, 1.0)
		metric_recorded.emit(crit_metric)
		
	# Metric 3: Kill (Ghi nhận nếu mục tiêu vừa chết vì đòn đánh này)
	if event.target.is_dead:
		var kill_metric = CombatMetric.new(CombatMetric.MetricType.KILL, event.source, event.target, 1.0)
		metric_recorded.emit(kill_metric)
