class_name BoardGrid
extends RefCounted

# ==========================================
# BOARD GRID - RUNTIME GROUND TRUTH
# Nguồn sự thật quản lý trạng thái lưới và chiếm dụng ô
# ==========================================

var config: BoardConfig
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

# ==========================================
# MUTATION (OCCUPANCY)
# ==========================================

func place_entity(entity: CombatEntity, cell: Vector2i) -> bool:
	if entity == null:
		return false
	if not is_in_bounds(cell):
		return false
	if not is_cell_empty(cell):
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
			if _entity_cells.has(entity):
				remove_entity(_entity_cells[entity])
		_entity_cleanup_callables[entity] = cleanup
		entity.tree_exiting.connect(cleanup)

	return true

func remove_entity(cell: Vector2i) -> CombatEntity:
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

func move_entity(from_cell: Vector2i, to_cell: Vector2i) -> bool:
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
# TACTICAL & ADJACENCY
# ==========================================

func get_neighbors_8(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var candidate := Vector2i(cell.x + dx, cell.y + dy)
			if is_in_bounds(candidate):
				neighbors.append(candidate)
	return neighbors

func clear() -> void:
	for entity in _entity_cleanup_callables.keys():
		if is_instance_valid(entity):
			var cleanup: Callable = _entity_cleanup_callables[entity]
			if entity.tree_exiting.is_connected(cleanup):
				entity.tree_exiting.disconnect(cleanup)
	_cell_occupants.clear()
	_entity_cells.clear()
	_entity_cleanup_callables.clear()
