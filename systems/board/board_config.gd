class_name BoardConfig
extends Resource

# ==========================================
# BOARD CONFIG - STATIC GRID DEFINITION
# Tài nguyên cấu hình kích thước và phân vùng bàn cờ
# ==========================================

@export var columns: int = 8
@export var rows: int = 5
@export var cell_size: Vector2 = Vector2(80.0, 80.0)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows

func is_hero_zone(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and cell.x < 3

func is_enemy_zone(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and cell.x >= (columns - 3)
