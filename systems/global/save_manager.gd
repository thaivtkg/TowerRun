extends Node

# ==========================================
# SAVE MANAGER - ATOMIC SAVE IMPLEMENTATION
# ==========================================

const SAVE_PATH: String = "user://run_state.save"
const BACKUP_PATH: String = "user://run_state.bak"
const TEMP_PATH: String = "user://run_state.tmp"

@export var debug_mode: bool = true

func _ready() -> void:
	if debug_mode:
		print("[SaveManager] Ready. Save path: ", ProjectSettings.globalize_path("user://"))

# 🔮 PREDICTIVE ERROR HANDLING:
# Lỗi: Sập nguồn hoặc crash khi đang ghi file -> Hỏng file save.
# Khắc phục: Ghi ra file .tmp trước. Nếu thành công mới ghi đè lên file chính.
func save_game(data: Dictionary) -> Error:
	if debug_mode:
		print("[SaveManager] Attempting to save game...")
		
	# Bước 1: Mở file tạm để ghi
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	var err := FileAccess.get_open_error()
	
	if err != OK or file == null:
		printerr("[SaveManager] FATAL: Cannot open temp file for saving. Error code: ", err)
		return err
		
	# Bước 2: Ghi dữ liệu
	var json_string := JSON.stringify(data)
	file.store_string(json_string)
	file.close()
	
	# Bước 3: Backup file save cũ (nếu có)
	if FileAccess.file_exists(SAVE_PATH):
		var copy_err := DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
		if copy_err != OK:
			printerr("[SaveManager] WARNING: Failed to create backup. Error code: ", copy_err)
			# Tiếp tục vì backup lỗi không nguy hiểm bằng việc dừng save
			
	# Bước 4: Đổi tên file tạm thành file chính thức (Atomic operation)
	var rename_err := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_err != OK:
		printerr("[SaveManager] FATAL: Failed to finalize save. Error code: ", rename_err)
		return rename_err
		
	if debug_mode:
		print("[SaveManager] Game saved successfully.")
		
	return OK

# 🔮 PREDICTIVE ERROR HANDLING:
# Lỗi: File save bị hỏng (corrupted) hoặc JSON parse lỗi.
# Khắc phục: Fallback đọc từ file .bak. Nếu vẫn lỗi, trả về Dictionary rỗng (New Game).
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		if debug_mode:
			print("[SaveManager] No save file found. Starting fresh.")
		return {}
		
	var data := _read_and_parse_file(SAVE_PATH)
	
	if data.is_empty() and FileAccess.file_exists(BACKUP_PATH):
		printerr("[SaveManager] Save file corrupted. Attempting to load backup...")
		data = _read_and_parse_file(BACKUP_PATH)
		
	return data

# Hàm nội bộ hỗ trợ đọc và parse JSON
func _read_and_parse_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("[SaveManager] ERROR: Cannot open file at: ", path)
		return {}
		
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_err := json.parse(content)
	
	if parse_err != OK:
		printerr("[SaveManager] ERROR: JSON Parse failed at line ", json.get_error_line(), ": ", json.get_error_message())
		return {}
		
	if typeof(json.data) == TYPE_DICTIONARY:
		return json.data as Dictionary
	else:
		printerr("[SaveManager] ERROR: Save data is not a Dictionary.")
		return {}
