class_name EntityStatusBar
extends Node2D

@onready var health_bar: ProgressBar = $HealthBar
@onready var energy_bar: ProgressBar = $EnergyBar

var _is_hero: bool = false
var _hp_tween: Tween = null
var _energy_tween: Tween = null
var _energy_flash_tween: Tween = null

func _ready() -> void:
	if health_bar != null:
		health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if energy_bar != null:
		energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(is_hero: bool, init_hp: float, init_max_hp: float, init_energy: float = 0.0, init_max_energy: float = 100.0) -> void:
	if not is_node_ready():
		await ready
		
	_is_hero = is_hero
	
	# Health Bar Styling
	_apply_bar_style(health_bar, Color(0.2, 0.85, 0.3) if is_hero else Color(0.9, 0.2, 0.2))
	health_bar.max_value = max(1.0, init_max_hp)
	health_bar.value = init_hp
	
	# Energy Bar Styling
	if is_hero:
		energy_bar.visible = true
		_apply_bar_style(energy_bar, Color(1.0, 0.85, 0.2)) # Màu vàng kim báo hiệu Ultimate
		energy_bar.max_value = max(1.0, init_max_energy)
		energy_bar.value = init_energy
		if init_energy >= init_max_energy and init_max_energy > 0.0:
			_start_energy_flash()
	else:
		energy_bar.visible = false

func on_hp_changed(current: float, max_val: float) -> void:
	if not is_node_ready():
		await ready
		
	if max_val > 0.0:
		health_bar.max_value = max_val
		
	var target_val: float = clampf(current, 0.0, health_bar.max_value)
	
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
		
	_hp_tween = create_tween()
	_hp_tween.tween_property(health_bar, "value", target_val, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func on_energy_changed(current: float, max_val: float) -> void:
	if not _is_hero or energy_bar == null or not is_node_ready():
		return
		
	if max_val > 0.0:
		energy_bar.max_value = max_val
		
	var target_val: float = clampf(current, 0.0, energy_bar.max_value)
	
	if _energy_tween != null and _energy_tween.is_valid():
		_energy_tween.kill()
		
	_energy_tween = create_tween()
	_energy_tween.tween_property(energy_bar, "value", target_val, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if current >= energy_bar.max_value and energy_bar.max_value > 0.0:
		_start_energy_flash()
	else:
		_stop_energy_flash()

func update_energy(current: float, max_val: float) -> void:
	on_energy_changed(current, max_val)

func _apply_bar_style(bar: ProgressBar, fill_color: Color) -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	bg_style.set_corner_radius_all(2)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(2)
	
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

func _start_energy_flash() -> void:
	if _energy_flash_tween != null and _energy_flash_tween.is_valid():
		return
	_energy_flash_tween = create_tween().set_loops()
	_energy_flash_tween.tween_property(energy_bar, "modulate", Color(2.0, 2.0, 2.0), 0.25).set_trans(Tween.TRANS_SINE)
	_energy_flash_tween.tween_property(energy_bar, "modulate", Color(1.0, 1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE)

func _stop_energy_flash() -> void:
	if _energy_flash_tween != null and _energy_flash_tween.is_valid():
		_energy_flash_tween.kill()
		_energy_flash_tween = null
	if energy_bar != null:
		energy_bar.modulate = Color.WHITE
