class_name TargetingSystem
extends Node

# Tham chiếu mảng dữ liệu từ BattleManager
var heroes: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []

# Liên tục quét và phân bổ mục tiêu mỗi frame
func _process(_delta: float) -> void:
	_assign_targets(heroes, enemies)
	_assign_targets(enemies, heroes)

# Xử lý gán mục tiêu cho một phe
func _assign_targets(attackers: Array[CombatEntity], defenders: Array[CombatEntity]) -> void:
	for attacker in attackers:
		if not is_instance_valid(attacker) or attacker.is_dead:
			continue
			
		# Nếu chưa có mục tiêu hoặc mục tiêu đã chết -> Tìm mục tiêu mới
		if attacker.target == null or not is_instance_valid(attacker.target) or attacker.target.is_dead:
			attacker.target = _find_closest_target(attacker, defenders)

# Thuật toán tìm mục tiêu gần nhất
func _find_closest_target(attacker: CombatEntity, defenders: Array[CombatEntity]) -> CombatEntity:
	var closest_target: CombatEntity = null
	var min_dist: float = INF
	
	for defender in defenders:
		if not is_instance_valid(defender) or defender.is_dead:
			continue
			
		# Sử dụng distance_squared_to để tối ưu hiệu suất (không cần tính căn bậc 2)
		var dist := attacker.global_position.distance_squared_to(defender.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_target = defender
			
	return closest_target
