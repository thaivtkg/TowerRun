class_name PlacementController
extends Node

# ==========================================
# PLACEMENT CONTROLLER - DUAL-ZONE DRAG & DROP
# Quản lý tương tác kéo thả Hero trên cả Sàn Đấu và Hàng Chờ Dự Bị (Sprint 7)
# ==========================================

signal entity_selected(entity: CombatEntity)
signal hero_selected(hero: HeroEntity)
signal hero_hovered(hero: HeroEntity)

const DRAG_THRESHOLD: float = 10.0

var board_grid: BoardGrid
var board_view: BoardView
var hero_bench: HeroBench = null

var dragged_entity: CombatEntity = null
var original_cell: Vector2i = Vector2i(-1, -1)
var original_bench_slot: int = -1
var original_z_index: int = 0
var max_board_heroes: int = 5

var _pending_entity: CombatEntity = null
var _drag_start_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

var is_locked: bool = false:
	get:
		return _is_locked
	set(val):
		set_locked(val)
var _is_locked: bool = false
var _snap_tweens: Dictionary = {} # CombatEntity -> Tween

# Biến alias tương thích ngược
var is_placement_locked: bool:
	get:
		return _is_locked
	set(val):
		set_locked(val)

func set_locked(locked: bool) -> void:
	_is_locked = locked
	if _is_locked:
		cancel_drag()

func _cleanup_drag_state() -> void:
	if is_instance_valid(dragged_entity):
		dragged_entity.z_index = original_z_index
	if hero_bench != null:
		for s in range(hero_bench.MAX_BENCH_SLOTS):
			hero_bench.highlight_slot(s, false)
	dragged_entity = null
	_pending_entity = null
	_is_dragging = false
	original_cell = Vector2i(-1, -1)
	original_bench_slot = -1
	if board_view != null:
		board_view.hovered_cell = Vector2i(-1, -1)

func cancel_drag() -> void:
	if is_instance_valid(dragged_entity):
		if _snap_tweens.has(dragged_entity) and is_instance_valid(_snap_tweens[dragged_entity]):
			_snap_tweens[dragged_entity].kill()
			_snap_tweens.erase(dragged_entity)
		if original_bench_slot != -1 and hero_bench != null:
			hero_bench.snap_to_slot(dragged_entity as HeroEntity, original_bench_slot)
		elif board_view != null and original_cell != Vector2i(-1, -1):
			_snap_to_cell(dragged_entity, original_cell)
		dragged_entity.z_index = original_z_index
	_cleanup_drag_state()

func get_board_hero_count() -> int:
	if board_grid == null:
		return 0
	var count: int = 0
	for occupant in board_grid._cell_occupants.values():
		if is_instance_valid(occupant) and occupant is HeroEntity:
			count += 1
	return count

func start_drag_entity(entity: CombatEntity, from_cell: Vector2i = Vector2i(-1, -1), from_bench_slot: int = -1) -> void:
	if not is_instance_valid(entity):
		return
	if _snap_tweens.has(entity) and is_instance_valid(_snap_tweens[entity]):
		_snap_tweens[entity].kill()
		_snap_tweens.erase(entity)
	dragged_entity = entity
	_pending_entity = entity
	_is_dragging = true
	original_cell = from_cell
	original_bench_slot = from_bench_slot
	original_z_index = entity.z_index
	dragged_entity.z_index = 100

func drop_at_position(mouse_pos: Vector2) -> bool:
	if dragged_entity == null or not is_instance_valid(dragged_entity):
		return false

	# 1. Thả vào ô Hàng Chờ (Hero Bench)
	if hero_bench != null:
		var target_bench_slot := hero_bench.get_slot_at_position(mouse_pos)
		if target_bench_slot == -1 and hero_bench.get_global_rect().has_point(mouse_pos):
			target_bench_slot = hero_bench.get_first_empty_slot()
			
		if target_bench_slot != -1:
			if original_bench_slot != -1:
				if target_bench_slot == original_bench_slot:
					hero_bench.snap_to_slot(dragged_entity as HeroEntity, original_bench_slot)
					return true
				hero_bench.swap_slots(original_bench_slot, target_bench_slot)
				return true
			elif original_cell != Vector2i(-1, -1):
				var hero := dragged_entity as HeroEntity
				if hero_bench.bench_slots[target_bench_slot] == null:
					board_grid.remove_entity(original_cell)
					hero_bench.add_hero(hero, target_bench_slot)
					return true
				else:
					var benched_hero := hero_bench.bench_slots[target_bench_slot]
					hero_bench.remove_hero(target_bench_slot)
					board_grid.remove_entity(original_cell)
					board_grid.place_entity(benched_hero, original_cell)
					hero_bench.add_hero(hero, target_bench_slot)
					_snap_to_cell(benched_hero, original_cell)
					return true

	# 2. Thả vào ô Cờ Sàn Đấu (Board Grid)
	if board_grid != null and board_view != null:
		var target_cell: Vector2i = board_view.world_to_grid(mouse_pos)
		if board_grid.is_in_bounds(target_cell) and board_grid.config.is_hero_zone(target_cell):
			if original_bench_slot != -1:
				var hero := dragged_entity as HeroEntity
				if board_grid.is_cell_empty(target_cell):
					if get_board_hero_count() >= max_board_heroes:
						hero_bench.snap_to_slot(hero, original_bench_slot)
						return false
					hero_bench.remove_hero(original_bench_slot)
					board_grid.place_entity(hero, target_cell)
					_snap_to_cell(hero, target_cell)
					return true
				else:
					var occupant = board_grid.get_occupant(target_cell)
					if occupant is HeroEntity:
						board_grid.remove_entity(target_cell)
						hero_bench.remove_hero(original_bench_slot)
						board_grid.place_entity(hero, target_cell)
						hero_bench.add_hero(occupant as HeroEntity, original_bench_slot)
						_snap_to_cell(hero, target_cell)
						return true
					else:
						hero_bench.snap_to_slot(hero, original_bench_slot)
						return false
			elif original_cell != Vector2i(-1, -1):
				if target_cell == original_cell:
					_snap_to_cell(dragged_entity, original_cell)
					return true
				elif board_grid.is_cell_empty(target_cell):
					var moved := board_grid.move_entity(original_cell, target_cell)
					var final_cell := target_cell if moved else original_cell
					_snap_to_cell(dragged_entity, final_cell)
					return moved
				else:
					var occupant = board_grid.get_occupant(target_cell)
					if occupant is HeroEntity:
						board_grid._cell_occupants[original_cell] = occupant
						board_grid._cell_occupants[target_cell] = dragged_entity
						board_grid._entity_cells[occupant] = original_cell
						board_grid._entity_cells[dragged_entity] = target_cell
						_snap_to_cell(dragged_entity, target_cell)
						_snap_to_cell(occupant, original_cell)
						return true
					else:
						_snap_to_cell(dragged_entity, original_cell)
						return false

	# 3. Thả ngoài vùng hợp lệ (Rebound an toàn)
	if original_bench_slot != -1 and hero_bench != null:
		hero_bench.snap_to_slot(dragged_entity as HeroEntity, original_bench_slot)
	elif original_cell != Vector2i(-1, -1):
		_snap_to_cell(dragged_entity, original_cell)
	return false

func _find_badge_hero_at(pos: Vector2) -> HeroEntity:
	if board_grid == null:
		return null
	for entity in board_grid._entity_cells.keys():
		if is_instance_valid(entity) and entity is HeroEntity:
			var hero := entity as HeroEntity
			if hero.has_pending_milestone:
				var badge_pos: Vector2 = hero.global_position + Vector2(0, -56)
				if pos.distance_to(badge_pos) <= 32.0:
					return hero
	return null

func _unhandled_input(event: InputEvent) -> void:
	if _is_locked or (board_grid != null and board_grid.is_locked):
		return
	if board_grid == null or board_view == null:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_on_mouse_pressed()
		else:
			_on_mouse_released()
	elif event is InputEventMouseMotion:
		_on_mouse_moved()

func _on_mouse_pressed() -> void:
	if _is_locked or (board_grid != null and board_grid.is_locked):
		return
		
	var mouse_pos: Vector2 = board_view.get_global_mouse_position()
	
	# 1. Click trúng huy hiệu nâng cấp "⬆️ NÂNG CẤP" trên đầu Tướng
	var badge_hero := _find_badge_hero_at(mouse_pos)
	if badge_hero != null:
		hero_selected.emit(badge_hero)
		get_viewport().set_input_as_handled()
		return
		
	# 2. Click trúng Tướng trên Hàng Chờ (HeroBench)
	if hero_bench != null:
		var slot_idx := hero_bench.get_slot_at_position(mouse_pos)
		if slot_idx != -1 and hero_bench.bench_slots[slot_idx] != null:
			var hero := hero_bench.bench_slots[slot_idx]
			_pending_entity = hero
			_drag_start_pos = mouse_pos
			_is_dragging = false
			original_bench_slot = slot_idx
			original_cell = Vector2i(-1, -1)
			original_z_index = hero.z_index
			get_viewport().set_input_as_handled()
			return
		
	# 3. Click trên Sàn Đấu (BoardGrid)
	var cell: Vector2i = board_view.world_to_grid(mouse_pos)
	if not board_grid.is_in_bounds(cell):
		return
		
	var entity: CombatEntity = board_grid.get_occupant(cell)
	if entity != null:
		_pending_entity = entity
		_drag_start_pos = mouse_pos
		_is_dragging = false
		original_cell = cell
		original_bench_slot = -1
		original_z_index = entity.z_index
		get_viewport().set_input_as_handled()

func _on_mouse_moved() -> void:
	if _is_locked or (board_grid != null and board_grid.is_locked):
		if board_view != null and board_view.hovered_cell != Vector2i(-1, -1):
			board_view.hovered_cell = Vector2i(-1, -1)
		return
		
	var mouse_pos: Vector2 = board_view.get_global_mouse_position()
	var current_cell: Vector2i = board_view.world_to_grid(mouse_pos)
	
	# Kiểm tra chuyển trạng thái từ Pending Click sang Dragging
	if not _is_dragging and _pending_entity != null and is_instance_valid(_pending_entity):
		var can_drag: bool = false
		if original_bench_slot != -1:
			can_drag = true
		elif original_cell != Vector2i(-1, -1) and board_grid != null and board_grid.config.is_hero_zone(original_cell):
			can_drag = (_pending_entity is HeroEntity)
			
		if can_drag and mouse_pos.distance_to(_drag_start_pos) >= DRAG_THRESHOLD:
			_is_dragging = true
			dragged_entity = _pending_entity
			if _snap_tweens.has(dragged_entity) and is_instance_valid(_snap_tweens[dragged_entity]):
				_snap_tweens[dragged_entity].kill()
				_snap_tweens.erase(dragged_entity)
			dragged_entity.z_index = 100
			board_view.hovered_cell = current_cell
				
	if _is_dragging and dragged_entity != null and is_instance_valid(dragged_entity):
		dragged_entity.global_position = mouse_pos
		board_view.hovered_cell = current_cell
		if hero_bench != null:
			var hover_slot := hero_bench.get_slot_at_position(mouse_pos)
			for s in range(hero_bench.MAX_BENCH_SLOTS):
				hero_bench.highlight_slot(s, s == hover_slot)
		get_viewport().set_input_as_handled()
	else:
		if board_grid.is_in_bounds(current_cell):
			board_view.hovered_cell = current_cell
			var occupant: CombatEntity = board_grid.get_occupant(current_cell)
			if occupant != null and occupant is HeroEntity:
				hero_hovered.emit(occupant)
		else:
			board_view.hovered_cell = Vector2i(-1, -1)

func _on_mouse_released() -> void:
	if _pending_entity == null and dragged_entity == null:
		return
		
	var mouse_pos: Vector2 = board_view.get_global_mouse_position()
	
	if _is_dragging and dragged_entity != null and is_instance_valid(dragged_entity):
		drop_at_position(mouse_pos)
	elif not _is_dragging and _pending_entity != null and is_instance_valid(_pending_entity):
		var clicked := _pending_entity
		entity_selected.emit(clicked)
		if clicked is HeroEntity:
			if original_bench_slot != -1 or (original_cell != Vector2i(-1, -1) and board_grid.config.is_hero_zone(original_cell)):
				hero_selected.emit(clicked as HeroEntity)
				
	_cleanup_drag_state()
	get_viewport().set_input_as_handled()

func _snap_to_cell(entity: CombatEntity, cell: Vector2i) -> void:
	if not is_instance_valid(entity) or board_view == null:
		return
	if _snap_tweens.has(entity) and is_instance_valid(_snap_tweens[entity]):
		_snap_tweens[entity].kill()
	var target_pos: Vector2 = board_view.grid_to_world(cell)
	var from_pos: Vector2 = entity.global_position
	entity.global_position = target_pos
	var tween: Tween = create_tween()
	if tween != null:
		_snap_tweens[entity] = tween
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(entity, "global_position", target_pos, 0.15).from(from_pos)
		tween.finished.connect(func(): _snap_tweens.erase(entity))
