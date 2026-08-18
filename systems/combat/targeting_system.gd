class_name TargetingSystem
extends Node

var heroes: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []

func _process(_delta: float) -> void:
	_assign_targets(heroes, enemies)
	_assign_targets(enemies, heroes)

func _assign_targets(attackers: Array[CombatEntity], potential_targets: Array[CombatEntity]) -> void:
	var alive_targets: Array[CombatEntity] = potential_targets.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	if alive_targets.is_empty():
		return
		
	for attacker in attackers:
		if attacker.is_dead:
			continue
			
		if attacker.target == null or attacker.target.is_dead or not is_instance_valid(attacker.target):
			attacker.target = _find_closest_target(attacker, alive_targets)

func _find_closest_target(attacker: CombatEntity, targets: Array[CombatEntity]) -> CombatEntity:
	var closest_target: CombatEntity = null
	var min_distance: float = INF
	
	for candidate in targets:
		var dist = attacker.global_position.distance_to(candidate.global_position)
		if dist < min_distance:
			min_distance = dist
			closest_target = candidate
			
	return closest_target

# ==========================================
# ABILITY TARGETING (SPRINT 4)
# ==========================================
func get_targets_for_rule(source: CombatEntity, rule: AbilityData.TargetRule) -> Array[CombatEntity]:
	var valid_targets: Array[CombatEntity] = []
	var is_source_hero: bool = source in heroes
	
	var allies: Array[CombatEntity] = heroes if is_source_hero else enemies
	var opponents: Array[CombatEntity] = enemies if is_source_hero else heroes
	
	# Lọc bỏ xác chết
	allies = allies.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	opponents = opponents.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	
	match rule:
		AbilityData.TargetRule.SELF:
			valid_targets.append(source)
			
		AbilityData.TargetRule.SINGLE_ENEMY, AbilityData.TargetRule.NEAREST_ENEMY:
			var t = _find_closest_target(source, opponents)
			if t: valid_targets.append(t)
			
		AbilityData.TargetRule.ALL_ENEMIES:
			valid_targets = opponents
			
		AbilityData.TargetRule.SINGLE_ALLY:
			var t = _find_closest_target(source, allies)
			if t: valid_targets.append(t)
			
		AbilityData.TargetRule.ALL_ALLIES:
			valid_targets = allies
			
		AbilityData.TargetRule.LOWEST_HP_ENEMY:
			var t = _find_lowest_hp_target(opponents)
			if t: valid_targets.append(t)
			
		AbilityData.TargetRule.LOWEST_HP_ALLY:
			var t = _find_lowest_hp_target(allies)
			if t: valid_targets.append(t)
			
	return valid_targets

func _find_lowest_hp_target(candidates: Array[CombatEntity]) -> CombatEntity:
	var best_target: CombatEntity = null
	var lowest_hp: float = INF
	
	for candidate in candidates:
		if candidate.current_hp < lowest_hp:
			lowest_hp = candidate.current_hp
			best_target = candidate
	return best_target
