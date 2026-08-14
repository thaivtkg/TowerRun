class_name SkillChoiceUI
extends CanvasLayer

signal skill_chosen(chosen: AbilityData, all_choices: Array[AbilityData])

var center_container: CenterContainer
var container: VBoxContainer
var current_choices: Array[AbilityData] = []

func _init() -> void:
	# Đảm bảo UI vẫn hoạt động khi Game Tree bị paused
	process_mode = Node.PROCESS_MODE_ALWAYS 
	layer = 100
	
	# Lớp nền đen mờ bao phủ toàn màn hình
	var dim_bg = ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.85)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim_bg)
	
	# CenterContainer ép mọi thứ bên trong ra chính giữa màn hình
	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	# Container chứa các nút bấm
	container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 20) # Khoảng cách giữa các nút
	center_container.add_child(container)
	
	hide()

func show_choices(hero_name: String, milestone: int, choices: Array[AbilityData]) -> void:
	current_choices = choices
	
	# Xóa nút cũ nếu có
	for child in container.get_children():
		child.queue_free()
		
	var title = Label.new()
	title.text = "=== %s REACHED LEVEL %d ===\nCHOOSE 1 ABILITY" % [hero_name.to_upper(), milestone]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	# Thêm margin dưới cho title
	title.custom_minimum_size = Vector2(0, 60) 
	container.add_child(title)
	
	# Sinh ra các nút bấm
	for ability in choices:
		var btn = Button.new()
		var type_str = AbilityData.AbilityType.keys()[ability.ability_type]
		btn.text = "[%s] %s\n%s" % [type_str, ability.name, ability.description]
		btn.custom_minimum_size = Vector2(450, 90) # Nút to hơn một chút để dễ nhìn
		btn.pressed.connect(_on_button_pressed.bind(ability))
		container.add_child(btn)
		
	show()
	get_tree().paused = true # Khóa chặt Combat Progression

func _on_button_pressed(chosen: AbilityData) -> void:
	hide()
	get_tree().paused = false # Tiếp tục combat
	skill_chosen.emit(chosen, current_choices)
