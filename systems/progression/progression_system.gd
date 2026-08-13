class_name ProgressionSystem
extends Node

# Dictionary tích lũy điểm Cống hiến thuần túy trong suốt trận đấu
var contributions: Dictionary = {}

func initialize(combat_system: CombatSystem) -> void:
	if combat_system != null:
		combat_system.metric_recorded.connect(_on_metric_recorded)

func _on_metric_recorded(metric: CombatMetric) -> void:
	if metric == null: return
	
	var source_hero = metric.source as HeroEntity
	var target_hero = metric.target as HeroEntity
	
	if is_instance_valid(source_hero) and source_hero.data != null:
		_calculate_source_contribution(source_hero, metric)
		
	if is_instance_valid(target_hero) and target_hero.data != null:
		_calculate_target_contribution(target_hero, metric)

func _calculate_source_contribution(hero: HeroEntity, metric: CombatMetric) -> void:
	var h_class: HeroData.HeroClass = hero.data.hero_class
	var points: float = 0.0
	
	match h_class:
		HeroData.HeroClass.ASSASSIN:
			# Prototype Balance: Có XP từ base damage để chống cướp mạng, bonus mạnh cho crit/kill
			if metric.type == CombatMetric.MetricType.DAMAGE: points += metric.value * 0.4
			elif metric.type == CombatMetric.MetricType.KILL: points += 30.0
			elif metric.type == CombatMetric.MetricType.CRIT: points += 10.0
			
		HeroData.HeroClass.MAGE, HeroData.HeroClass.MARKSMAN:
			if metric.type == CombatMetric.MetricType.DAMAGE: points += metric.value * 1.0
			
		HeroData.HeroClass.FIGHTER:
			if metric.type == CombatMetric.MetricType.DAMAGE: points += metric.value * 0.7
			
		HeroData.HeroClass.SUPPORT:
			# Prototype Balance: Tạm thời cho Support nhận XP từ đòn đánh thường để không bị khóa progression
			if metric.type == CombatMetric.MetricType.DAMAGE: points += metric.value * 1.0
			
	_add_contribution(hero, points)

func _calculate_target_contribution(hero: HeroEntity, metric: CombatMetric) -> void:
	var h_class: HeroData.HeroClass = hero.data.hero_class
	var points: float = 0.0
	
	match h_class:
		HeroData.HeroClass.TANK:
			if metric.type == CombatMetric.MetricType.DAMAGE: points += metric.value * 1.0
		HeroData.HeroClass.FIGHTER:
			if metric.type == CombatMetric.MetricType.DAMAGE: points += metric.value * 0.3
			
	_add_contribution(hero, points)

func _add_contribution(hero: HeroEntity, points: float) -> void:
	if points <= 0.0: return
	contributions[hero] = contributions.get(hero, 0.0) + points

# ==========================================
# GIAI ĐOẠN 3: BATTLE END CONVERSION
# Được gọi bởi BattleManager khi kết thúc trận
# ==========================================
func finalize_battle_xp(is_victory: bool) -> void:
	print("\n--- BATTLE XP CONVERSION ---")
	
	# Hệ số chiến thắng (Thắng x1.2, Thua x0.5)
	var win_multiplier: float = 1.2 if is_victory else 0.5
	
	for hero in contributions.keys():
		if not is_instance_valid(hero) or hero.progression == null:
			continue
			
		var raw_contribution: float = contributions[hero]
		# TODO: Sau này chèn logic Normalize / XP Budget tại đây
		var final_xp: float = raw_contribution * win_multiplier
		
		hero.progression.add_xp(final_xp)
		
		var class_str: String = HeroData.HeroClass.keys()[hero.data.hero_class]
		print("> %s (%s) | Raw Contrib: %.1f | Final XP (+%.1f) | Current: Lv%d (%.1f/%.1f)" % [
			hero.name, class_str, raw_contribution, final_xp, 
			hero.progression.level, hero.progression.current_xp, hero.progression.required_xp
		])
		
	# Xóa rác chuẩn bị cho màn tiếp theo
	contributions.clear()
	print("----------------------------\n")
