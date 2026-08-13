class_name ProgressionSystem
extends Node

var contributions: Dictionary = {}

func initialize(combat_system: CombatSystem) -> void:
	if combat_system != null:
		combat_system.metric_recorded.connect(_on_metric_recorded)
		print("[ProgressionSystem] Initialized and listening to Combat Metrics.")

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
			if metric.type == CombatMetric.MetricType.KILL:
				points += 50.0
			elif metric.type == CombatMetric.MetricType.CRIT:
				points += 15.0
		HeroData.HeroClass.MAGE, HeroData.HeroClass.MARKSMAN:
			if metric.type == CombatMetric.MetricType.DAMAGE:
				points += metric.value * 1.0
		HeroData.HeroClass.FIGHTER:
			if metric.type == CombatMetric.MetricType.DAMAGE:
				points += metric.value * 0.5
				
	_add_contribution(hero, points)

func _calculate_target_contribution(hero: HeroEntity, metric: CombatMetric) -> void:
	var h_class: HeroData.HeroClass = hero.data.hero_class
	var points: float = 0.0
	
	match h_class:
		HeroData.HeroClass.TANK:
			if metric.type == CombatMetric.MetricType.DAMAGE:
				points += metric.value * 1.0
		HeroData.HeroClass.FIGHTER:
			if metric.type == CombatMetric.MetricType.DAMAGE:
				points += metric.value * 0.5
				
	_add_contribution(hero, points)

func _add_contribution(hero: HeroEntity, points: float) -> void:
	if points <= 0.0: return
	
	# Lưu điểm tổng
	contributions[hero] = contributions.get(hero, 0.0) + points
	
	# Bơm XP trực tiếp vào thanh Progression của Tướng
	if hero.progression != null:
		hero.progression.add_xp(points)
		
		# Log chi tiết quá trình thăng tiến
		var class_str: String = HeroData.HeroClass.keys()[hero.data.hero_class]
		print("[Progression] %s (%s) earned %.1f XP. (Level: %d | XP: %.1f/%.1f)" % [
			hero.name, class_str, points, 
			hero.progression.level, hero.progression.current_xp, hero.progression.required_xp
		])
