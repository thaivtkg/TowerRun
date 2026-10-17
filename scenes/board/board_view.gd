class_name BoardView
extends Node2D

# ==========================================
# BOARD VIEW - POINTY-TOP HEX GRID (ODD-R)
# Hiển thị bàn cờ Lục giác đỉnh nhọn và chuyển đổi tọa độ
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

# Tâm của ô lục giác (Odd-R Pointy-Top) trong hệ tọa độ local của BoardView
func grid_to_local(cell: Vector2i) -> Vector2:
	if config == null:
		config = BoardConfig.new()
	var w: float = config.get_hex_width()
	var row_step: float = config.get_row_vertical_spacing()
	var x_offset: float = (w * 0.5) if (cell.y & 1) == 1 else 0.0
	var cx: float = cell.x * w + x_offset + (w * 0.5)
	var cy: float = cell.y * row_step + config.hex_radius
	return Vector2(cx, cy)

func grid_to_world(cell: Vector2i) -> Vector2:
	return to_global(grid_to_local(cell))

# Chuyển từ tọa độ World sang ô Lục Giác bằng khoảng cách tâm gần nhất
func world_to_grid(world_pos: Vector2) -> Vector2i:
	if config == null:
		config = BoardConfig.new()
	var local_pos: Vector2 = to_local(world_pos)
	var best_cell := Vector2i(-1, -1)
	var best_dist_sq: float = INF
	var max_dist_sq: float = (config.hex_radius * 1.05) * (config.hex_radius * 1.05)
	
	for r in range(config.rows):
		for c in range(config.columns):
			var candidate := Vector2i(c, r)
			var center: Vector2 = grid_to_local(candidate)
			var d_sq: float = local_pos.distance_squared_to(center)
			if d_sq < best_dist_sq:
				best_dist_sq = d_sq
				best_cell = candidate
				
	if best_dist_sq <= max_dist_sq:
		return best_cell
	return Vector2i(-1, -1)

# Trả về 6 đỉnh (7 điểm khép kín) của lục giác Pointy-Top quanh tâm center
func _get_hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(7):
		var angle_deg: float = 60.0 * float(i % 6) - 30.0
		var angle_rad: float = deg_to_rad(angle_deg)
		pts.append(center + Vector2(cos(angle_rad), sin(angle_rad)) * radius)
	return pts

func _draw() -> void:
	if config == null:
		return
	var r: float = config.hex_radius - 2.0 # Chừa khe hở 2px giữa các ô cho đẹp
	
	for row in range(config.rows):
		for col in range(config.columns):
			var cell := Vector2i(col, row)
			var center: Vector2 = grid_to_local(cell)
			var poly: PackedVector2Array = _get_hex_points(center, r)
			
			# Màu nền theo phân vùng
			var fill_color := Color(0.18, 0.20, 0.25, 0.75)
			var border_color := Color(0.45, 0.50, 0.60, 0.85)
			if config.is_enemy_zone(cell):
				fill_color = Color(0.38, 0.14, 0.16, 0.55)
				border_color = Color(0.75, 0.28, 0.30, 0.8)
			elif config.is_hero_zone(cell):
				fill_color = Color(0.14, 0.26, 0.38, 0.55)
				border_color = Color(0.30, 0.60, 0.85, 0.8)
				
			draw_colored_polygon(poly.slice(0, 6), fill_color)
			draw_polyline(poly, border_color, 2.0, true)
			
	# Vẽ khung sáng trên ô đang Hover khi kéo thả
	if config.is_in_bounds(hovered_cell):
		var h_center: Vector2 = grid_to_local(hovered_cell)
		var h_poly: PackedVector2Array = _get_hex_points(h_center, r)
		var is_valid_hover: bool = config.is_hero_zone(hovered_cell) and (grid == null or grid.is_cell_empty(hovered_cell))
		var hl_color: Color = Color(0.2, 0.95, 0.4, 0.95) if is_valid_hover else Color(0.95, 0.25, 0.25, 0.95)
		draw_colored_polygon(h_poly.slice(0, 6), Color(hl_color.r, hl_color.g, hl_color.b, 0.25))
		draw_polyline(h_poly, hl_color, 3.5, true)
