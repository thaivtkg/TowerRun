class_name PlacementController
extends Node

# ==========================================
# PLACEMENT CONTROLLER - DRAG & DROP SYSTEM
# Quản lý tương tác kéo thả Hero và kiểm tra luật vùng
# ==========================================

var board_grid: BoardGrid
var board_view: BoardView

var dragged_entity: CombatEntity = null
var original_cell: Vector2i = Vector2i(-1, -1)
var original_z_index: int = 0
var is_placement_locked: bool = false

func _unhandled_input(event: InputEvent) -> void:
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
	if is_placement_locked:
		return
		
	var mouse_pos: Vector2 = board_view.get_global_mouse_position()
	var cell: Vector2i = board_view.world_to_grid(mouse_pos)
	
	if not board_grid.is_in_bounds(cell):
		return
		
	if not board_grid.config.is_hero_zone(cell):
		return
		
	var entity: CombatEntity = board_grid.get_occupant(cell)
	if entity != null and entity is HeroEntity:
		dragged_entity = entity
		original_cell = cell
		original_z_index = entity.z_index
		entity.z_index = 100
		board_view.hovered_cell = cell
		get_viewport().set_input_as_handled()

func _on_mouse_moved() -> void:
	var mouse_pos: Vector2 = board_view.get_global_mouse_position()
	var current_cell: Vector2i = board_view.world_to_grid(mouse_pos)
	
	if dragged_entity != null:
		if is_instance_valid(dragged_entity):
			dragged_entity.global_position = mouse_pos
			board_view.hovered_cell = current_cell
			get_viewport().set_input_as_handled()
		else:
			dragged_entity = null
			original_cell = Vector2i(-1, -1)
			board_view.hovered_cell = Vector2i(-1, -1)
	else:
		if not is_placement_locked and board_grid.is_in_bounds(current_cell):
			board_view.hovered_cell = current_cell
		else:
			board_view.hovered_cell = Vector2i(-1, -1)

func _on_mouse_released() -> void:
	if dragged_entity == null:
		return
		
	if not is_instance_valid(dragged_entity):
		dragged_entity = null
		original_cell = Vector2i(-1, -1)
		board_view.hovered_cell = Vector2i(-1, -1)
		return
		
	var mouse_pos: Vector2 = board_view.get_global_mouse_position()
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
	dragged_entity = null
	original_cell = Vector2i(-1, -1)
	board_view.hovered_cell = Vector2i(-1, -1)
	get_viewport().set_input_as_handled()

func _snap_to_cell(entity: CombatEntity, cell: Vector2i) -> void:
	if not is_instance_valid(entity) or board_view == null:
		return
	var target_pos: Vector2 = board_view.grid_to_world(cell)
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(entity, "global_position", target_pos, 0.15)
