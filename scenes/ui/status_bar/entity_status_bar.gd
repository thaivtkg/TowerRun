class_name EntityStatusBar
extends Node2D

@onready var health_bar: ProgressBar = $HealthBar
@onready var energy_bar: ProgressBar = $EnergyBar

var ghost_bar: ProgressBar = null
var omni_shield_bar: ProgressBar = null
var physical_shield_bar: ProgressBar = null
var magic_shield_bar: ProgressBar = null
var dr_badge: Label = null

var _is_hero: bool = false
var _current_hp: float = 0.0
var _max_hp: float = 1.0
var _omni_shield: float = 0.0
var _phys_shield: float = 0.0
var _magic_shield: float = 0.0

var _hp_tween: Tween = null
var _ghost_tween: Tween = null
var _energy_tween: Tween = null
var _energy_flash_tween: Tween = null

func _ready() -> void:
	if health_bar != null:
		health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if energy_bar != null:
		energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_sub_bars()

func _init_sub_bars() -> void:
	if ghost_bar != null or health_bar == null:
		return
		
	# 1. Ghost HP Bar (nằm dưới cùng của thanh máu)
	ghost_bar = ProgressBar.new()
	ghost_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_bar.show_percentage = false
	ghost_bar.offset_left = health_bar.offset_left
	ghost_bar.offset_top = health_bar.offset_top
	ghost_bar.offset_right = health_bar.offset_right
	ghost_bar.offset_bottom = health_bar.offset_bottom
	_apply_bar_style(ghost_bar, Color(0.88, 0.44, 0.33, 0.85)) # Đỏ cam nhạt #e17055
	add_child(ghost_bar)
	move_child(ghost_bar, 0)
	
	# 2. Tri-Shield Bars (Xếp lớp đồng trục từ dưới lên trên)
	# Magic Shield (Tím #a29bfe)
	magic_shield_bar = _create_shield_bar(Color(0.63, 0.61, 0.99, 0.85))
	move_child(magic_shield_bar, 1)
	
	# Physical Shield (Cam Hổ Phách #e67e22)
	physical_shield_bar = _create_shield_bar(Color(0.90, 0.49, 0.13, 0.85))
	move_child(physical_shield_bar, 2)
	
	# Omni Shield (Trắng Bạc #ffffff)
	omni_shield_bar = _create_shield_bar(Color(1.0, 1.0, 1.0, 0.85))
	move_child(omni_shield_bar, 3)
	
	# 3. DR Status Badge (Icon khiên nhỏ báo hiệu giảm sát thương)
	dr_badge = Label.new()
	dr_badge.text = "🛡️"
	dr_badge.visible = false
	dr_badge.offset_left = 27.0
	dr_badge.offset_top = -8.0
	dr_badge.offset_right = 45.0
	dr_badge.offset_bottom = 8.0
	dr_badge.add_theme_font_size_override("font_size", 10)
	add_child(dr_badge)

func _create_shield_bar(fill_color: Color) -> ProgressBar:
	var sb := ProgressBar.new()
	sb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sb.show_percentage = false
	sb.offset_left = health_bar.offset_left
	sb.offset_top = health_bar.offset_top
	sb.offset_right = health_bar.offset_right
	sb.offset_bottom = health_bar.offset_bottom
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(2)
	var bg_style := StyleBoxEmpty.new()
	sb.add_theme_stylebox_override("background", bg_style)
	sb.add_theme_stylebox_override("fill", fill_style)
	add_child(sb)
	return sb

func setup(is_hero: bool, init_hp: float, init_max_hp: float, init_energy: float = 0.0, init_max_energy: float = 100.0, show_energy: bool = false) -> void:
	if not is_node_ready():
		await ready
	_init_sub_bars()
		
	_is_hero = is_hero or show_energy
	_current_hp = init_hp
	_max_hp = max(1.0, init_max_hp)
	
	# Health Bar Styling
	_apply_bar_style(health_bar, Color(0.2, 0.85, 0.3) if is_hero else Color(0.9, 0.2, 0.2))
	health_bar.max_value = _max_hp
	health_bar.value = init_hp
	if ghost_bar != null:
		ghost_bar.max_value = _max_hp
		ghost_bar.value = init_hp
	
	# Energy Bar Styling
	if is_hero or show_energy:
		energy_bar.visible = true
		_apply_bar_style(energy_bar, Color(1.0, 0.85, 0.2)) # Màu vàng kim báo hiệu Ultimate
		energy_bar.max_value = max(1.0, init_max_energy)
		energy_bar.value = init_energy
		if init_energy >= init_max_energy and init_max_energy > 0.0:
			_start_energy_flash()
	else:
		energy_bar.visible = false
		
	_update_shields_and_pool()

func on_hp_changed(current: float, max_val: float) -> void:
	if not is_node_ready():
		await ready
	_init_sub_bars()
		
	if max_val > 0.0:
		_max_hp = max_val
		
	var old_hp := _current_hp
	_current_hp = clampf(current, 0.0, _max_hp)
	
	_update_shields_and_pool()
	
	# Animation cho HealthBar
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(health_bar, "value", _current_hp, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Animation cho GhostBar (Delay 0.2s, co rút trong 0.25s)
	if ghost_bar != null:
		if _ghost_tween != null and _ghost_tween.is_valid():
			_ghost_tween.kill()
		if _current_hp < old_hp:
			_ghost_tween = create_tween()
			_ghost_tween.tween_interval(0.2)
			_ghost_tween.tween_property(ghost_bar, "value", _current_hp, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			ghost_bar.value = _current_hp

func on_shield_changed(omni: float, phys: float, magic: float) -> void:
	if not is_node_ready():
		await ready
	_init_sub_bars()
	
	_omni_shield = maxf(0.0, omni)
	_phys_shield = maxf(0.0, phys)
	_magic_shield = maxf(0.0, magic)
	_update_shields_and_pool()

func set_damage_reduction(pct: float) -> void:
	if not is_node_ready():
		await ready
	_init_sub_bars()
	if dr_badge != null:
		if pct > 0.0:
			dr_badge.visible = true
			dr_badge.tooltip_text = "Kháng sát thương: -%d%%" % int(round(pct * 100.0))
		else:
			dr_badge.visible = false

func _update_shields_and_pool() -> void:
	# Thuật toán phân đoạn khiên khi tràn thanh máu (Over-Shield Clamping):
	# Total Visual Pool = max(max_hp, current_hp + omni + phys + magic)
	var total_pool := maxf(_max_hp, _current_hp + _omni_shield + _phys_shield + _magic_shield)
	if total_pool <= 0.0:
		total_pool = 1.0
		
	health_bar.max_value = total_pool
	if ghost_bar != null:
		ghost_bar.max_value = total_pool
	if omni_shield_bar != null:
		omni_shield_bar.max_value = total_pool
		omni_shield_bar.value = _current_hp + _omni_shield
	if physical_shield_bar != null:
		physical_shield_bar.max_value = total_pool
		physical_shield_bar.value = _current_hp + _omni_shield + _phys_shield
	if magic_shield_bar != null:
		magic_shield_bar.max_value = total_pool
		magic_shield_bar.value = _current_hp + _omni_shield + _phys_shield + _magic_shield

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
