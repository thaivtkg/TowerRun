class_name BoardConfig
extends Resource

# ==========================================
# BOARD CONFIG - POINTY-TOP HEX GRID (ODD-R)
# Bố cục Lục Giác Đỉnh Nhọn chuẩn Auto Chess / TFT (7 cột x 6 hàng)
# ==========================================

@export var columns: int = 7 # Chuẩn TFT: 7 cột lục giác
@export var rows: int = 6    # 3 hàng trên (Enemy) + 3 hàng dưới (Hero)
@export var hex_radius: float = 44.0 # Bán kính tâm -> đỉnh lục giác
@export var enemy_zone_rows: int = 3
@export var hero_zone_rows: int = 3

# Kích thước bao (Bounding Box) của 1 ô lục giác Pointy-Top
var cell_size: Vector2:
	get:
		return Vector2(sqrt(3.0) * hex_radius, 2.0 * hex_radius)

func get_hex_width() -> float:
	return sqrt(3.0) * hex_radius

func get_row_vertical_spacing() -> float:
	return 1.5 * hex_radius

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows

# Nửa trên bàn cờ (Hàng 0, 1, 2)
func is_enemy_zone(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and cell.y < enemy_zone_rows

# Nửa dưới bàn cờ (Hàng 3, 4, 5)
func is_hero_zone(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and cell.y >= (rows - hero_zone_rows)
