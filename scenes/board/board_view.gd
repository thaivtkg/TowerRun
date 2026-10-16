class_name BoardView
extends Node2D

# ==========================================
# BOARD VIEW - VISUAL PRESENTATION & MATH
# Hiển thị lưới bàn cờ và tính toán chuyển đổi tọa độ
# ==========================================

@export var config: BoardConfig
var grid: BoardGrid

var hovered_cell: Vector2i = Vector2i(-1, -1):
	set(val):
		if hovered_cell != val:
			hovered_cell = val
			queue_redraw()

func _ready() -> void:
	if config == null:
		config = BoardConfig.new()
	if grid == null:
		grid = BoardGrid.new(config)
	queue_redraw()

func grid_to_world(cell: Vector2i) -> Vector2:
	if config == null:
		config = BoardConfig.new()
	var local_center: Vector2 = (Vector2(cell) * config.cell_size) + (config.cell_size / 2.0)
	return to_global(local_center)

func world_to_grid(pos: Vector2) -> Vector2i:
	if config == null:
		config = BoardConfig.new()
	var local_pos: Vector2 = to_local(pos)
	return Vector2i(
		int(floor(local_pos.x / config.cell_size.x)),
		int(floor(local_pos.y / config.cell_size.y))
	)

func _draw() -> void:
	if config == null:
		return
		
	var cell_w: float = config.cell_size.x
	var cell_h: float = config.cell_size.y
	
	# Màu sắc các vùng (phong cách thanh lịch, dễ nhìn)
	var hero_color := Color(0.18, 0.45, 0.85, 0.16)
	var enemy_color := Color(0.85, 0.25, 0.25, 0.16)
	var neutral_color := Color(0.15, 0.15, 0.2, 0.08)
	var grid_line_color := Color(0.4, 0.45, 0.55, 0.35)
	
	for col in range(config.columns):
		for row in range(config.rows):
			var cell := Vector2i(col, row)
			var cell_rect := Rect2(Vector2(col * cell_w, row * cell_h), config.cell_size)
			
			# Tô màu theo Zone
			if config.is_hero_zone(cell):
				draw_rect(cell_rect, hero_color, true)
			elif config.is_enemy_zone(cell):
				draw_rect(cell_rect, enemy_color, true)
			else:
				draw_rect(cell_rect, neutral_color, true)
				
			# Vẽ viền từng ô
			draw_rect(cell_rect, grid_line_color, false, 1.0)
			
	# Đường phân chia ranh giới giữa 2 phần sân (Giữa hàng 2 và hàng 3)
	var divider_y: float = config.enemy_zone_rows * cell_h
	draw_line(
		Vector2(0, divider_y),
		Vector2(config.columns * cell_w, divider_y),
		Color(0.8, 0.85, 1.0, 0.5),
		2.0
	)
			
	# Viền ngoài cùng của toàn bộ bàn cờ
	var board_rect := Rect2(Vector2.ZERO, Vector2(config.columns * cell_w, config.rows * cell_h))
	draw_rect(board_rect, Color(0.6, 0.65, 0.75, 0.6), false, 2.0)
	
	# Vẽ highlight ô chuột hover
	if config.is_in_bounds(hovered_cell):
		var hover_rect := Rect2(
			Vector2(hovered_cell.x * cell_w, hovered_cell.y * cell_h),
			config.cell_size
		)
		var highlight_fill: Color
		var highlight_border: Color
		
		if config.is_hero_zone(hovered_cell):
			var is_empty: bool = true
			if grid != null:
				is_empty = grid.is_cell_empty(hovered_cell)
			if is_empty:
				highlight_fill = Color(0.2, 0.8, 0.4, 0.25)
				highlight_border = Color(0.3, 1.0, 0.5, 0.9)
			else:
				highlight_fill = Color(0.95, 0.65, 0.15, 0.25)
				highlight_border = Color(1.0, 0.75, 0.2, 0.9)
		else:
			highlight_fill = Color(0.8, 0.2, 0.2, 0.2)
			highlight_border = Color(0.9, 0.3, 0.3, 0.7)
			
		draw_rect(hover_rect, highlight_fill, true)
		draw_rect(hover_rect, highlight_border, false, 2.0)
