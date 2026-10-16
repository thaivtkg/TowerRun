class_name BoardConfig
extends Resource

# ==========================================
# BOARD CONFIG - TOP-DOWN AUTO CHESS DEFINITION
# Bố cục Trên–Dưới (8 cột x 6 hàng, ô 72x72)
# ==========================================

@export var columns: int = 8
@export var rows: int = 6
@export var cell_size: Vector2 = Vector2(72.0, 72.0)
@export var enemy_zone_rows: int = 3
@export var hero_zone_rows: int = 3

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows

# Nửa trên bàn cờ (Hàng 0, 1, 2)
func is_enemy_zone(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and cell.y < enemy_zone_rows

# Nửa dưới bàn cờ (Hàng 3, 4, 5)
func is_hero_zone(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and cell.y >= (rows - hero_zone_rows)
