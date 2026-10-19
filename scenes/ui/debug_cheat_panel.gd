class_name DebugCheatPanel
extends CanvasLayer

# ==============================================================================
# DEBUG CHEAT PANEL - QA & DEV CHEAT TOOLS (SPRINT 4 SIGN-OFF / SPRINT 5)
# Phím tắt: F1 hoặc ~ (Tilde) để bật/tắt menu
# ==============================================================================

var battle_manager: Node = null

var panel: PanelContainer
var info_label: Label
var god_mode_btn: Button
var speed_btn: Button

func _init(p_battle_manager: Node = null) -> void:
	battle_manager = p_battle_manager
	layer = 100 # Hiển thị trên mọi UI khác

func _ready() -> void:
	_build_ui()
	visible = false # Mặc định ẩn, bật bằng F1 hoặc ~

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 320)
	panel.position = Vector2(20, 20)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_color = Color("#f39c12")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# Header
	var title := Label.new()
	title.text = "🛠️ QA CHEAT MENU (F1 / ~)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#f1c40f"))
	vbox.add_child(title)
	
	# Status Info
	info_label = Label.new()
	info_label.text = "Đang tải dữ liệu..."
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.add_theme_color_override("font_color", Color("#ecf0f1"))
	vbox.add_child(info_label)
	
	# Button: God Mode
	god_mode_btn = Button.new()
	god_mode_btn.text = "🛡️ Bất tử: TẮT (G)"
	god_mode_btn.pressed.connect(_on_god_mode_pressed)
	vbox.add_child(god_mode_btn)
	
	# Button: Kill All
	var kill_all_btn := Button.new()
	kill_all_btn.text = "⚡ Diệt toàn bộ quái (K)"
	kill_all_btn.pressed.connect(_on_kill_all_pressed)
	vbox.add_child(kill_all_btn)
	
	# Button: Add Gold
	var add_gold_btn := Button.new()
	add_gold_btn.text = "💰 +50 Vàng (F6)"
	add_gold_btn.pressed.connect(_on_add_gold_pressed)
	vbox.add_child(add_gold_btn)
	
	# Button: Game Speed
	speed_btn = Button.new()
	speed_btn.text = "⏩ Tốc độ: 1.0x"
	speed_btn.pressed.connect(_on_speed_pressed)
	vbox.add_child(speed_btn)
	
	# Warp Floors Label & Buttons
	var warp_label := Label.new()
	warp_label.text = "🌀 Nhảy tầng (Warp Floor):"
	warp_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(warp_label)
	
	var warp_hbox := HBoxContainer.new()
	warp_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(warp_hbox)
	
	var floors = [1, 3, 5, 10, 15]
	for f in floors:
		var btn := Button.new()
		var label_str: String = "T%d" % f
		if f == 5 or f == 15:
			label_str += "👑"
		elif f == 3:
			label_str += "🔥"
		btn.text = label_str
		btn.pressed.connect(func(): _on_warp_pressed(f))
		warp_hbox.add_child(btn)
		
	# Button: Run All Tests
	var test_btn := Button.new()
	test_btn.text = "🧪 Chạy Test Suite (0)"
	test_btn.pressed.connect(_on_run_tests_pressed)
	vbox.add_child(test_btn)

func toggle_visibility() -> void:
	visible = not visible
	if visible:
		update_info()

func update_info() -> void:
	if not is_instance_valid(battle_manager):
		return
	var floor_num: int = battle_manager.current_floor if "current_floor" in battle_manager else 1
	var gold_amt: int = RunManager.current_gold if RunManager != null else 0
	var lives_amt: int = RunManager.current_lives if RunManager != null else 0
	var is_god: bool = battle_manager.is_god_mode if "is_god_mode" in battle_manager else false
	
	info_label.text = "Tầng: %d | Vàng: %d | Mạng: %d\nBất tử: %s | Tốc độ: %.1fx" % [
		floor_num, gold_amt, lives_amt,
		"BẬT" if is_god else "TẮT",
		Engine.time_scale
	]
	if god_mode_btn != null:
		god_mode_btn.text = "🛡️ Bất tử: %s (G)" % ("BẬT" if is_god else "TẮT")
	if speed_btn != null:
		speed_btn.text = "⏩ Tốc độ: %.1fx" % Engine.time_scale

func _on_god_mode_pressed() -> void:
	if is_instance_valid(battle_manager) and battle_manager.has_method("toggle_god_mode"):
		battle_manager.toggle_god_mode()
		update_info()

func _on_kill_all_pressed() -> void:
	if is_instance_valid(battle_manager) and battle_manager.has_method("cheat_kill_all_enemies"):
		battle_manager.cheat_kill_all_enemies()
		update_info()

func _on_add_gold_pressed() -> void:
	if RunManager != null:
		RunManager.add_gold(50)
		update_info()

func _on_speed_pressed() -> void:
	if is_instance_valid(battle_manager) and battle_manager.has_method("cheat_cycle_speed"):
		battle_manager.cheat_cycle_speed()
		update_info()

func _on_warp_pressed(target_floor: int) -> void:
	if is_instance_valid(battle_manager) and battle_manager.has_method("cheat_warp_floor"):
		battle_manager.cheat_warp_floor(target_floor)
		update_info()

func _on_run_tests_pressed() -> void:
	if is_instance_valid(battle_manager) and battle_manager.has_method("_run_all_tests"):
		battle_manager._run_all_tests()
