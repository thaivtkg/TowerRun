class_name BoardGrid
extends RefCounted

# ==========================================
# BOARD GRID - RUNTIME GROUND TRUTH
# Nguồn sự thật quản lý trạng thái lưới và chiếm dụng ô
# ==========================================

var config: BoardConfig
var is_locked: bool = false
var _cell_occupants: Dictionary = {} # Vector2i -> CombatEntity
var _entity_cells: Dictionary = {}    # CombatEntity -> Vector2i
var _entity_cleanup_callables: Dictionary = {} # CombatEntity -> Callable

func _init(_config: BoardConfig = null) -> void:
	if _config != null:
		config = _config
	else:
		config = BoardConfig.new()

# ==========================================
# QUERY & BOUNDS
# ==========================================

func is_in_bounds(cell: Vector2i) -> bool:
	if config == null:
		return false
	return config.is_in_bounds(cell)

func is_cell_empty(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	return not _cell_occupants.has(cell)

func get_occupant(cell: Vector2i) -> CombatEntity:
	return _cell_occupants.get(cell, null)

func get_cell_for_entity(entity: CombatEntity) -> Vector2i:
	if entity == null or not _entity_cells.has(entity):
		return Vector2i(-1, -1)
	return _entity_cells[entity]

# Kiểm tra hợp lệ vùng đặt quân (BG-08) và trạng thái khóa (BG-10)
func can_place(entity: CombatEntity, cell: Vector2i, enforce_zone: bool = false) -> bool:
	if is_locked or entity == null:
		return false
	if not is_in_bounds(cell) or not is_cell_empty(cell):
		return false
	if enforce_zone and config != null:
		if entity is HeroEntity and not config.is_hero_zone(cell):
			return false
		if entity is EnemyEntity and not config.is_enemy_zone(cell):
			return false
	return true

# ==========================================
# MUTATION (OCCUPANCY)
# ==========================================

func place_entity(entity: CombatEntity, cell: Vector2i, enforce_zone: bool = false) -> bool:
	if not can_place(entity, cell, enforce_zone):
		return false
		
	# Nếu entity đang ở ô khác, giải phóng ô cũ
	if _entity_cells.has(entity):
		var old_cell: Vector2i = _entity_cells[entity]
		_cell_occupants.erase(old_cell)
		
	_cell_occupants[cell] = entity
	_entity_cells[entity] = cell

	# Tự động dọn dẹp khi Entity bị hủy hoặc rời khỏi Scene Tree (tránh dangling reference)
	if not _entity_cleanup_callables.has(entity):
		var cleanup := func():
			remove_dead_entity(entity)
		_entity_cleanup_callables[entity] = cleanup
		entity.tree_exiting.connect(cleanup)

	return true

func remove_entity(cell: Vector2i) -> CombatEntity:
	if is_locked:
		return null
	return _do_remove_entity(cell)

func remove_dead_entity(entity: CombatEntity) -> CombatEntity:
	if entity == null or not _entity_cells.has(entity):
		return null
	var cell: Vector2i = _entity_cells[entity]
	return _do_remove_entity(cell)

func _do_remove_entity(cell: Vector2i) -> CombatEntity:
	if not _cell_occupants.has(cell):
		return null
		
	var entity: CombatEntity = _cell_occupants[cell]
	_cell_occupants.erase(cell)
	if entity != null:
		_entity_cells.erase(entity)
		if _entity_cleanup_callables.has(entity):
			var cleanup: Callable = _entity_cleanup_callables[entity]
			if entity.tree_exiting.is_connected(cleanup):
				entity.tree_exiting.disconnect(cleanup)
			_entity_cleanup_callables.erase(entity)
	return entity

func move_entity(from_cell: Vector2i, to_cell: Vector2i, ignore_lock: bool = false) -> bool:
	if is_locked and not ignore_lock:
		return false
	if from_cell == to_cell:
		return true
	if not is_in_bounds(from_cell) or not is_in_bounds(to_cell):
		return false
	if not _cell_occupants.has(from_cell):
		return false
	if not is_cell_empty(to_cell):
		return false
		
	var entity: CombatEntity = _cell_occupants[from_cell]
	_cell_occupants.erase(from_cell)
	_cell_occupants[to_cell] = entity
	_entity_cells[entity] = to_cell
	return true

# ==========================================
# TACTICAL & ADJACENCY (HEX ODD-R)
# ==========================================

const EVEN_ROW_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1),
	Vector2i(-1, 0),  Vector2i(1, 0),
	Vector2i(-1, 1),  Vector2i(0, 1)
]
const ODD_ROW_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),  Vector2i(1, -1),
	Vector2i(-1, 0),  Vector2i(1, 0),
	Vector2i(0, 1),   Vector2i(1, 1)
]

func get_hex_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_in_bounds(cell):
		return result
	var offsets := ODD_ROW_OFFSETS if (cell.y & 1) == 1 else EVEN_ROW_OFFSETS
	for d in offsets:
		var n := cell + d
		if is_in_bounds(n):
			result.append(n)
	return result

func get_neighbors_8(cell: Vector2i) -> Array[Vector2i]:
	return get_hex_neighbors(cell)

func get_hex_distance(cell_a: Vector2i, cell_b: Vector2i) -> int:
	if config != null:
		return config.get_hex_distance(cell_a, cell_b)
	return 0

func get_empty_enemy_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if config == null:
		return cells
	for r in range(config.rows):
		for c in range(config.columns):
			var cell := Vector2i(c, r)
			if config.is_enemy_zone(cell) and is_cell_empty(cell):
				cells.append(cell)
	return cells

func get_empty_hero_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if config == null:
		return cells
	for r in range(config.rows):
		for c in range(config.columns):
			var cell := Vector2i(c, r)
			if config.is_hero_zone(cell) and is_cell_empty(cell):
				cells.append(cell)
	return cells

func clear() -> void:
	for entity in _entity_cleanup_callables.keys():
		if is_instance_valid(entity):
			var cleanup: Callable = _entity_cleanup_callables[entity]
			if entity.tree_exiting.is_connected(cleanup):
				entity.tree_exiting.disconnect(cleanup)
	_cell_occupants.clear()
	_entity_cells.clear()
	_entity_cleanup_callables.clear()
