extends Node

# ==========================================
# DATA MANAGER - RESOURCE REGISTRY
# ==========================================

@export var debug_mode: bool = true

const HERO_DATA_DIR: String = "res://data/heroes/"
const ENEMY_DATA_DIR: String = "res://data/enemies/"
const ABILITY_DATA_DIR: String = "res://data/abilities/"

# Dictionaries lưu trữ data sau khi load (Key: ID, Value: Resource)
var heroes: Dictionary = {}
var enemies: Dictionary = {}
var abilities: Dictionary = {}

func _ready() -> void:
	if debug_mode:
		print("[DataManager] Initializing data...")
	
	_load_all_data()

# 🔮 PREDICTIVE ERROR HANDLING:
# Lỗi 1: Đường dẫn thư mục không tồn tại -> Bỏ qua an toàn, trả về Dict rỗng.
# Lỗi 2: Export game trên Godot sẽ tự đổi đuôi file .tres thành .tres.remap -> Lỗi load file.
# Khắc phục: Chủ động cắt hậu tố .remap nếu có.
func _load_all_data() -> void:
	abilities = _load_resources_from_dir(ABILITY_DATA_DIR)
	heroes = _load_resources_from_dir(HERO_DATA_DIR)
	enemies = _load_resources_from_dir(ENEMY_DATA_DIR)
	
	if debug_mode:
		print("[DataManager] Loaded %d skills, %d heroes, %d enemies." % [abilities.size(), heroes.size(), enemies.size()])

func _load_resources_from_dir(path: String) -> Dictionary:
	var result_dict: Dictionary = {}
	
	var dir := DirAccess.open(path)
	var err := DirAccess.get_open_error()
	
	if err != OK or dir == null:
		if debug_mode:
			printerr("[DataManager] WARNING: Cannot open directory: ", path, " | Error: ", err)
		return result_dict
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		# Chỉ lấy file .tres (và xử lý luôn .remap cho bản Export)
		if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")):
			var actual_file_name = file_name.trim_suffix(".remap")
			var full_path = path + actual_file_name
			
			var resource = ResourceLoader.load(full_path)
			
			if resource != null:
				# 🔮 Lỗi 3: File Resource quên không nhập ID -> Bỏ qua để tránh null key.
				if "id" in resource and typeof(resource.id) == TYPE_STRING and resource.id != "":
					# 🔮 Lỗi 4: Trùng ID giữa các file -> Cảnh báo cho người dùng.
					if result_dict.has(resource.id):
						printerr("[DataManager] WARNING: Duplicate ID found: ", resource.id, " at ", full_path)
					else:
						result_dict[resource.id] = resource
				else:
					printerr("[DataManager] WARNING: Resource missing 'id' property or ID is empty: ", full_path)
			else:
				printerr("[DataManager] ERROR: Failed to load resource: ", full_path)
				
		file_name = dir.get_next()
		
	return result_dict

# Các hàm API truy xuất an toàn (Trả về null nếu không tìm thấy)
func get_hero(id: String) -> HeroData:
	return heroes.get(id, null)
	
func get_enemy(id: String) -> EnemyData:
	return enemies.get(id, null)
	
# Nếu bạn đã đổi biến dict thành `abilities`:
func get_ability(id: String) -> AbilityData:
	return abilities.get(id, null) as AbilityData
