class_name PlacementController
extends Node

# ==========================================
# PLACEMENT CONTROLLER - DRAG & DROP SYSTEM
# Quản lý tương tác kéo thả Hero và kiểm tra luật vùng
# ==========================================

signal entity_selected(entity: CombatEntity)
signal hero_selected(hero: HeroEntity)
signal hero_hovered(hero: HeroEntity)

const DRAG_THRESHOLD: float = 10.0

var board_grid: BoardGrid
var board_view: BoardView

var dragged_entity: CombatEntity = null
var original_cell: Vector2i = Vector2i(-1, -1)
var original_z_index: int = 0

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

func cancel_drag() -> void:
	if is_instance_valid(dragged_entity):
		if _snap_tweens.has(dragged_entity) and is_instance_valid(_snap_tweens[dragged_entity]):
			_snap_tweens[dragged_entity].kill()
			_snap_tweens.erase(dragged_entity)
		if board_view != null and original_cell != Vector2i(-1, -1):
			dragged_entity.global_position = board_view.grid_to_world(original_cell)
		dragged_entity.z_index = original_z_index
	dragged_entity = null
	_pending_entity = null
	_is_dragging = false
	original_cell = Vector2i(-1, -1)
	if board_view != null:
		board_view.hovered_cell = Vector2i(-1, -1)

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
		
	var cell: Vector2i = board_view.world_to_grid(mouse_pos)
	if not board_grid.is_in_bounds(cell):
		return
		
	var entity: CombatEntity = board_grid.get_occupant(cell)
	if entity != null:
		_pending_entity = entity
		_drag_start_pos = mouse_pos
		_is_dragging = false
		original_cell = cell
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
		if _pending_entity is HeroEntity and board_grid.config.is_hero_zone(original_cell):
			if mouse_pos.distance_to(_drag_start_pos) >= DRAG_THRESHOLD:
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
		var target_cell: Vector2i = board_view.world_to_grid(mouse_pos)
		var moved: bool = false
		if board_grid.is_in_bounds(target_cell) and board_grid.config.is_hero_zone(target_cell):
			if target_cell == original_cell:
				moved = true
			elif board_grid.is_cell_empty(target_cell):
				moved = board_grid.move_entity(original_cell, target_cell)
				
		var final_cell: Vector2i = target_cell if moved else original_cell
		_snap_to_cell(dragged_entity, final_cell)
		dragged_entity.z_index = original_z_index
	elif not _is_dragging and _pending_entity != null and is_instance_valid(_pending_entity):
		# Click thuần túy (không kéo rê vượt ngưỡng DRAG_THRESHOLD)
		var clicked := _pending_entity
		entity_selected.emit(clicked)
		if clicked is HeroEntity and board_grid.config.is_hero_zone(original_cell):
			hero_selected.emit(clicked as HeroEntity)
			
	dragged_entity = null
	_pending_entity = null
	_is_dragging = false
	original_cell = Vector2i(-1, -1)
	if board_view != null:
		board_view.hovered_cell = Vector2i(-1, -1)
	get_viewport().set_input_as_handled()

func _snap_to_cell(entity: CombatEntity, cell: Vector2i) -> void:
	if not is_instance_valid(entity) or board_view == null:
		return
	if _snap_tweens.has(entity) and is_instance_valid(_snap_tweens[entity]):
		_snap_tweens[entity].kill()
	var target_pos: Vector2 = board_view.grid_to_world(cell)
	var tween: Tween = create_tween()
	_snap_tweens[entity] = tween
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(entity, "global_position", target_pos, 0.15)
	tween.finished.connect(func(): _snap_tweens.erase(entity))

