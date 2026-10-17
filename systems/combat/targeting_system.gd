class_name TargetingSystem
extends Node

var heroes: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []
var board_grid: BoardGrid = null

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
			
		attacker.targeting_system = self
		
		if attacker.target == null or attacker.target.is_dead or not is_instance_valid(attacker.target):
			var in_range := find_closest_target_in_range(attacker, attacker.get_attack_range(), alive_targets)
			if in_range != null:
				attacker.target = in_range
			else:
				attacker.target = _find_closest_target(attacker, alive_targets)
		elif not attacker.is_target_in_attack_range():
			var in_range := find_closest_target_in_range(attacker, attacker.get_attack_range(), alive_targets)
			if in_range != null:
				attacker.target = in_range

func find_closest_target_in_range(attacker: CombatEntity, max_range: int, candidate_pool: Array[CombatEntity] = []) -> CombatEntity:
	if attacker == null or attacker.is_dead or board_grid == null:
		return null
	var is_hero: bool = (attacker is HeroEntity) or (attacker in heroes)
	var opponents: Array[CombatEntity] = candidate_pool if candidate_pool.size() > 0 else (enemies if is_hero else heroes)
	var alive_opponents: Array[CombatEntity] = []
	for e in opponents:
		if is_instance_valid(e) and not e.is_dead:
			alive_opponents.append(e)
			
	if alive_opponents.is_empty():
		return null
		
	var my_cell := board_grid.get_cell_for_entity(attacker)
	if not board_grid.is_in_bounds(my_cell):
		return null
		
	var best_target: CombatEntity = null
	var min_hex_dist: int = max_range + 1
	
	for candidate in alive_opponents:
		var cand_cell := board_grid.get_cell_for_entity(candidate)
		if not board_grid.is_in_bounds(cand_cell):
			continue
		var dist: int = board_grid.get_hex_distance(my_cell, cand_cell)
		if dist <= max_range:
			if dist < min_hex_dist:
				min_hex_dist = dist
				best_target = candidate
			elif dist == min_hex_dist and best_target != null:
				if candidate.current_hp < best_target.current_hp:
					best_target = candidate
					
	return best_target

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
# ABILITY TARGETING & AOE
# ==========================================
func get_targets_for_ability(source: CombatEntity, ability_data: AbilityData) -> Array[CombatEntity]:
	if ability_data == null:
		return []
	var primary_targets = get_targets_for_rule(source, ability_data.target_rule, ability_data)
	if ability_data.aoe_shape == AbilityData.AoEShape.HEX_RADIUS and not primary_targets.is_empty():
		return _expand_aoe_hex_radius(source, primary_targets[0], ability_data.aoe_radius, ability_data.target_rule)
	return primary_targets

func get_targets_for_rule(source: CombatEntity, rule: AbilityData.TargetRule, ability_data: AbilityData = null) -> Array[CombatEntity]:
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
			
		AbilityData.TargetRule.FURTHEST_ENEMY:
			var t = _find_furthest_target(source, opponents)
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
			
		AbilityData.TargetRule.LOWEST_HP_PERCENT_ENEMY:
			var t = _find_lowest_hp_percent_target(opponents)
			if t: valid_targets.append(t)
			
		AbilityData.TargetRule.LOWEST_HP_ALLY:
			var t = _find_lowest_hp_target(allies)
			if t: valid_targets.append(t)
			
		AbilityData.TargetRule.DENSEST_ENEMY_CLUSTER:
			var radius: int = ability_data.aoe_radius if ability_data != null else 1
			var t = _find_densest_cluster_target(source, opponents, radius)
			if t: valid_targets.append(t)
			
	return valid_targets

func _find_furthest_target(source: CombatEntity, targets: Array[CombatEntity]) -> CombatEntity:
	var furthest: CombatEntity = null
	var max_dist_sq: float = -1.0
	for candidate in targets:
		var d_sq = source.global_position.distance_squared_to(candidate.global_position)
		if d_sq > max_dist_sq:
			max_dist_sq = d_sq
			furthest = candidate
	return furthest

func _find_lowest_hp_target(candidates: Array[CombatEntity]) -> CombatEntity:
	var best_target: CombatEntity = null
	var lowest_hp: float = INF
	
	for candidate in candidates:
		if candidate.current_hp < lowest_hp:
			lowest_hp = candidate.current_hp
			best_target = candidate
	return best_target

func _find_lowest_hp_percent_target(candidates: Array[CombatEntity]) -> CombatEntity:
	var best_target: CombatEntity = null
	var lowest_pct: float = INF
	
	for candidate in candidates:
		var m_hp = candidate.max_hp if candidate.max_hp > 0.0 else 1.0
		var pct = candidate.current_hp / m_hp
		if pct < lowest_pct:
			lowest_pct = pct
			best_target = candidate
	return best_target

func _get_entity_cell(entity: CombatEntity) -> Vector2i:
	if board_grid != null:
		var c = board_grid.get_cell_for_entity(entity)
		if c != Vector2i(-1, -1):
			return c
	return Vector2i(-1, -1)

func _get_hex_distance_between(a: CombatEntity, b: CombatEntity) -> int:
	var cell_a := _get_entity_cell(a)
	var cell_b := _get_entity_cell(b)
	if cell_a != Vector2i(-1, -1) and cell_b != Vector2i(-1, -1) and board_grid != null:
		return board_grid.get_hex_distance(cell_a, cell_b)
	var hex_r: float = board_grid.config.hex_radius if (board_grid and board_grid.config) else 44.0
	var approx_step: float = sqrt(3.0) * hex_r
	return maxi(0, roundi(a.global_position.distance_to(b.global_position) / approx_step))

func _find_densest_cluster_target(source: CombatEntity, targets: Array[CombatEntity], radius: int) -> CombatEntity:
	var best_target: CombatEntity = null
	var max_count: int = -1
	var min_dist_sq: float = INF
	
	for center_candidate in targets:
		var cluster_count: int = 0
		for other in targets:
			if _get_hex_distance_between(center_candidate, other) <= radius:
				cluster_count += 1
				
		var d_sq: float = source.global_position.distance_squared_to(center_candidate.global_position)
		if cluster_count > max_count:
			max_count = cluster_count
			min_dist_sq = d_sq
			best_target = center_candidate
		elif cluster_count == max_count and d_sq < min_dist_sq:
			# Tie-breaker: Ưu tiên mục tiêu gần Caster nhất
			min_dist_sq = d_sq
			best_target = center_candidate
			
	return best_target

func _expand_aoe_hex_radius(source: CombatEntity, anchor: CombatEntity, radius: int, rule: AbilityData.TargetRule) -> Array[CombatEntity]:
	var result: Array[CombatEntity] = [anchor]
	var is_source_hero: bool = source in heroes
	var is_target_ally: bool = (rule == AbilityData.TargetRule.SINGLE_ALLY or rule == AbilityData.TargetRule.LOWEST_HP_ALLY or rule == AbilityData.TargetRule.ALL_ALLIES)
	var pool: Array[CombatEntity] = (heroes if is_source_hero else enemies) if is_target_ally else (enemies if is_source_hero else heroes)
	pool = pool.filter(func(e): return is_instance_valid(e) and not e.is_dead and e != anchor)
	
	for other in pool:
		if _get_hex_distance_between(anchor, other) <= radius:
			result.append(other)
			
	return result
