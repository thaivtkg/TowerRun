class_name CombatEntity
extends CharacterBody2D

signal died(entity: CombatEntity)
signal attack_requested(event: DamageEvent)
signal ability_requested(ability: Ability)
signal healed(entity: CombatEntity, amount: float)
signal hp_changed(current: float, max_val: float)
signal energy_changed(current: float, max_val: float)
signal shield_changed(omni: float, phys: float, magic: float)

const STATUS_BAR_SCENE: PackedScene = preload("res://scenes/ui/status_bar/EntityStatusBar.tscn")

var status_bar: EntityStatusBar = null

# S5.3: TRI-SHIELD MATRIX (Khiên Trắng, Khiên Vật Lý, Khiên Phép)
var omni_shield: float = 0.0:
	set(val):
		omni_shield = maxf(0.0, val)
		shield_changed.emit(omni_shield, physical_shield, magic_shield)

var physical_shield: float = 0.0:
	set(val):
		physical_shield = maxf(0.0, val)
		shield_changed.emit(omni_shield, physical_shield, magic_shield)

var magic_shield: float = 0.0:
	set(val):
		magic_shield = maxf(0.0, val)
		shield_changed.emit(omni_shield, physical_shield, magic_shield)

func get_total_shield() -> float:
	return omni_shield + physical_shield + magic_shield

func add_shield(amount: float, shield_type: int = 0) -> void:
	match shield_type:
		0:
			omni_shield += amount
		1:
			physical_shield += amount
		2:
			magic_shield += amount
var current_hp: float = 0.0:
	set(val):
		current_hp = val
		if max_hp > 0.0:
			hp_changed.emit(current_hp, max_hp)

var max_hp: float = 0.0:
	set(val):
		max_hp = val
		if max_hp > 0.0 and current_hp > 0.0:
			hp_changed.emit(current_hp, max_hp)

var level: int = 1
var is_invulnerable: bool = false
var current_energy: float = 0.0:
	set(val):
		current_energy = clampf(val, 0.0, max_energy)
		energy_changed.emit(current_energy, max_energy)

var max_energy: float = 100.0:
	set(val):
		max_energy = val
		energy_changed.emit(current_energy, max_energy)

var energy_per_attack: float = 25.0
var unlocked_abilities: Array[Ability] = []
var damage_reduction: float = 0.0 # Ví dụ: 0.30 cho Solo Raid Boss

func _gain_energy(amount: float) -> void:
	if is_dead:
		return
	self.current_energy += amount

var is_dead: bool = false
var target: CombatEntity = null # [FIX] Gom biến target về Base Class để TargetingSystem truy xuất an toàn
var deployed_cell: Vector2i = Vector2i(-1, -1)

var board_grid: BoardGrid = null
var board_view: BoardView = null
var targeting_system: TargetingSystem = null
var _movement_tween: Tween = null

@onready var sprite: Sprite2D = $Sprite2D
var _base_sprite_pos: Vector2 = Vector2.ZERO
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_sprite_modulate: Color = Color.WHITE

var _sprite_move_tween: Tween = null
var _sprite_flash_tween: Tween = null

func _ready() -> void:
	_capture_base_sprite_state()

func _capture_base_sprite_state() -> void:
	if sprite == null and has_node("Sprite2D"):
		sprite = $Sprite2D
	if sprite != null:
		_base_sprite_pos = sprite.position
		_base_sprite_scale = sprite.scale
		_base_sprite_modulate = sprite.modulate

# ==========================================
# COMBAT JUICE & VISUAL EFFECTS (SPRINT 5)
# Thao tác 100% trên $Sprite2D để không làm lệch Targeting & EntityStatusBar
# ==========================================
func play_lunge_vfx(target_pos: Vector2) -> void:
	if sprite == null:
		_capture_base_sprite_state()
	if sprite == null:
		return
		
	if _sprite_move_tween != null and _sprite_move_tween.is_running():
		_sprite_move_tween.kill()
		sprite.position = _base_sprite_pos
		sprite.scale = _base_sprite_scale
		
	var dir := (target_pos - global_position).normalized()
	_sprite_move_tween = create_tween()
	_sprite_move_tween.tween_property(sprite, "position", _base_sprite_pos + dir * 12.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sprite_move_tween.tween_property(sprite, "position", _base_sprite_pos, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func play_hit_vfx() -> void:
	if sprite == null:
		_capture_base_sprite_state()
	if sprite == null:
		return
		
	if _sprite_flash_tween != null and _sprite_flash_tween.is_running():
		_sprite_flash_tween.kill()
		sprite.self_modulate = Color.WHITE
		
	_sprite_flash_tween = create_tween()
	_sprite_flash_tween.tween_property(sprite, "self_modulate", Color(3.0, 0.4, 0.4), 0.05).set_trans(Tween.TRANS_SINE)
	_sprite_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.08).set_trans(Tween.TRANS_SINE)
	
	if _sprite_move_tween == null or not _sprite_move_tween.is_running():
		var shake_offset := Vector2(randf_range(-2.5, 2.5), randf_range(-1.5, 1.5))
		_sprite_move_tween = create_tween()
		_sprite_move_tween.tween_property(sprite, "position", _base_sprite_pos + shake_offset, 0.04)
		_sprite_move_tween.tween_property(sprite, "position", _base_sprite_pos, 0.04)
		_sprite_move_tween.tween_callback(func(): sprite.position = _base_sprite_pos)

func play_cast_vfx() -> void:
	if sprite == null:
		_capture_base_sprite_state()
	if sprite == null:
		return
		
	if _sprite_move_tween != null and _sprite_move_tween.is_running():
		_sprite_move_tween.kill()
		sprite.position = _base_sprite_pos
		sprite.scale = _base_sprite_scale
		
	_sprite_move_tween = create_tween()
	_sprite_move_tween.tween_property(sprite, "scale", _base_sprite_scale * 1.25, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sprite_move_tween.tween_property(sprite, "scale", _base_sprite_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	if _sprite_flash_tween != null and _sprite_flash_tween.is_running():
		_sprite_flash_tween.kill()
		sprite.self_modulate = Color.WHITE
		
	_sprite_flash_tween = create_tween()
	_sprite_flash_tween.tween_property(sprite, "self_modulate", Color(2.5, 2.2, 1.2), 0.08).set_trans(Tween.TRANS_SINE)
	_sprite_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.12).set_trans(Tween.TRANS_SINE)

func setup_status_bar(is_hero: bool, show_energy: bool = false) -> void:
	if status_bar != null and is_instance_valid(status_bar):
		status_bar.queue_free()
		
	if STATUS_BAR_SCENE != null:
		status_bar = STATUS_BAR_SCENE.instantiate() as EntityStatusBar
		add_child(status_bar)
		status_bar.position = Vector2(0, -35)
		
		if not hp_changed.is_connected(status_bar.on_hp_changed):
			hp_changed.connect(status_bar.on_hp_changed)
		if not shield_changed.is_connected(status_bar.on_shield_changed):
			shield_changed.connect(status_bar.on_shield_changed)
			
		var init_energy: float = 0.0
		var init_max_energy: float = 100.0
		if is_hero or show_energy:
			if not energy_changed.is_connected(status_bar.on_energy_changed):
				energy_changed.connect(status_bar.on_energy_changed)
			init_energy = get("current_energy") if get("current_energy") != null else 0.0
			init_max_energy = get("max_energy") if get("max_energy") != null else 100.0
			
		status_bar.setup(is_hero, current_hp, max_hp, init_energy, init_max_energy, show_energy)
		status_bar.set_damage_reduction(damage_reduction)

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var old_hp := current_hp
	var limit_hp: float = max_hp if max_hp > 0.0 else 9999.0
	current_hp = min(current_hp + amount, limit_hp)
	var actual_healed := current_hp - old_hp
	if actual_healed > 0.0:
		healed.emit(self, actual_healed)

func take_damage(amount: float, damage_type: DamageEvent.DamageType = DamageEvent.DamageType.PHYSICAL) -> void:
	if is_dead: return
	
	if amount < 0 or is_nan(amount) or is_inf(amount):
		printerr("[CombatEntity] WARNING: Invalid damage amount: ", amount)
		return
		
	if is_invulnerable:
		current_hp = max(1.0, current_hp - amount)
		print("[Combat] %s [GOD MODE] takes %.1f damage! (HP locked: %.1f)" % [name, amount, current_hp])
		hp_changed.emit(current_hp, max_hp)
		return

	var remaining := amount
	match damage_type:
		DamageEvent.DamageType.PHYSICAL:
			# Khấu trừ: Khiên Vật Lý -> Khiên Trắng -> Máu
			if physical_shield > 0.0:
				var absorbed := minf(physical_shield, remaining)
				physical_shield -= absorbed
				remaining -= absorbed
			if remaining > 0.0 and omni_shield > 0.0:
				var absorbed := minf(omni_shield, remaining)
				omni_shield -= absorbed
				remaining -= absorbed
		DamageEvent.DamageType.MAGIC:
			# Khấu trừ: Khiên Phép -> Khiên Trắng -> Máu
			if magic_shield > 0.0:
				var absorbed := minf(magic_shield, remaining)
				magic_shield -= absorbed
				remaining -= absorbed
			if remaining > 0.0 and omni_shield > 0.0:
				var absorbed := minf(omni_shield, remaining)
				omni_shield -= absorbed
				remaining -= absorbed
		DamageEvent.DamageType.TRUE:
			# Xuyên qua Khiên Vật Lý & Phép, chỉ Khiên Trắng chặn được
			if omni_shield > 0.0:
				var absorbed := minf(omni_shield, remaining)
				omni_shield -= absorbed
				remaining -= absorbed

	if remaining > 0.0:
		current_hp -= remaining
		
	print("[Combat] %s takes %.1f damage! (HP: %.1f | Shields: Omni=%.1f, Phys=%.1f, Mag=%.1f)" % [name, amount, current_hp, omni_shield, physical_shield, magic_shield])
	
	hp_changed.emit(current_hp, max_hp)
	shield_changed.emit(omni_shield, physical_shield, magic_shield)
	
	if current_hp <= 0:
		_die()

func _die() -> void:
	if _movement_tween != null and _movement_tween.is_running():
		_movement_tween.kill()
	is_dead = true
	visible = false
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	print("[Combat] ☠️ ", name, " has died (Became a Corpse).")
	died.emit(self)

func set_combat_active(active: bool) -> void:
	if not active:
		target = null
	set_process(active)

func reset_for_new_battle() -> void:
	if _movement_tween != null and _movement_tween.is_running():
		_movement_tween.kill()
	if is_dead:
		is_dead = false
		visible = true
		set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		
	if sprite != null:
		if _sprite_move_tween != null and _sprite_move_tween.is_running():
			_sprite_move_tween.kill()
		if _sprite_flash_tween != null and _sprite_flash_tween.is_running():
			_sprite_flash_tween.kill()
		sprite.position = _base_sprite_pos
		sprite.scale = _base_sprite_scale
		sprite.modulate = _base_sprite_modulate
		sprite.self_modulate = Color.WHITE
		
	target = null
	current_hp = max_hp
	
	if self is HeroEntity:
		var hero := self as HeroEntity
		if hero.data != null and "starting_energy" in hero.data:
			hero.current_energy = hero.data.starting_energy
		else:
			hero.current_energy = 0.0
		for ab in hero.unlocked_abilities:
			ab.current_cooldown = 0.0
		if hero.metrics != null:
			hero.metrics.reset()

# ==========================================
# [S2.3] MOVEMENT & PATHFINDING
# ==========================================

func get_attack_range() -> int:
	return 1

func is_target_in_attack_range() -> bool:
	if not is_instance_valid(target) or target.is_dead:
		return false
	if board_grid == null:
		return true
	var my_cell := board_grid.get_cell_for_entity(self)
	var target_cell := board_grid.get_cell_for_entity(target)
	if not board_grid.is_in_bounds(my_cell) or not board_grid.is_in_bounds(target_cell):
		return true
	var dist := board_grid.get_hex_distance(my_cell, target_cell)
	return dist <= get_attack_range()

func step_towards_target() -> bool:
	if not is_instance_valid(target) or target.is_dead or board_grid == null:
		return false
	var my_cell := board_grid.get_cell_for_entity(self)
	var target_cell := board_grid.get_cell_for_entity(target)
	if not board_grid.is_in_bounds(my_cell) or not board_grid.is_in_bounds(target_cell):
		return false
	var next_cell := board_grid.get_best_step_towards(my_cell, target_cell)
	if next_cell == my_cell:
		return false
	return move_to_grid_cell(next_cell)

func move_to_grid_cell(next_cell: Vector2i, duration: float = 0.25) -> bool:
	if board_grid == null:
		return false
	var my_cell := board_grid.get_cell_for_entity(self)
	if not board_grid.move_entity(my_cell, next_cell, true):
		return false
		
	var target_world_pos: Vector2
	if board_view != null:
		target_world_pos = board_view.grid_to_world(next_cell)
	else:
		target_world_pos = Vector2(next_cell * 80)
		
	if _movement_tween != null and _movement_tween.is_running():
		_movement_tween.kill()
		
	_movement_tween = create_tween()
	_movement_tween.tween_property(self, "global_position", target_world_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return true

func teleport_to_grid_cell(target_cell: Vector2i) -> bool:
	if board_grid == null:
		return false
	var my_cell := board_grid.get_cell_for_entity(self)
	if not board_grid.move_entity(my_cell, target_cell, true):
		return false
		
	var target_world_pos: Vector2
	if board_view != null:
		target_world_pos = board_view.grid_to_world(target_cell)
	else:
		target_world_pos = Vector2(target_cell * 80)
		
	if _movement_tween != null and _movement_tween.is_running():
		_movement_tween.kill()
		
	_movement_tween = create_tween()
	if sprite != null:
		_movement_tween.tween_property(sprite, "modulate:a", 0.0, 0.1).set_trans(Tween.TRANS_SINE)
		_movement_tween.tween_callback(func():
			global_position = target_world_pos
		)
		_movement_tween.tween_property(sprite, "modulate:a", 1.0, 0.1).set_trans(Tween.TRANS_SINE)
	else:
		global_position = target_world_pos
	return true


var _dr_aura_rot: float = 0.0

func _process(delta: float) -> void:
	if is_dead:
		return
	if damage_reduction > 0.0:
		_dr_aura_rot += delta * 1.5
		queue_redraw()
	for ability in unlocked_abilities:
		ability.process_cooldown(delta)
		if ability.data.ability_type == AbilityData.AbilityType.ACTIVE and ability.is_ready(current_energy):
			if ability.data.target_rule == AbilityData.TargetRule.SELF or (is_instance_valid(target) and not target.is_dead):
				ability_requested.emit(ability)

func _draw() -> void:
	if damage_reduction > 0.0 and not is_dead:
		var radius: float = 24.0
		var pts: PackedVector2Array = []
		var alpha: float = 0.4 + 0.3 * sin(_dr_aura_rot * 2.0)
		var aura_col := Color(0.95, 0.77, 0.06, alpha)
		for i in range(6):
			var a := _dr_aura_rot + deg_to_rad(60.0 * i)
			pts.append(Vector2(cos(a), sin(a)) * radius)
		pts.append(pts[0])
		draw_polyline(pts, aura_col, 2.0)

# ==========================================
# VIRTUAL METHODS (STATS CONTRACT)
# Các hệ thống như CombatSystem sẽ gọi các hàm này.
# Lớp con (Hero/Enemy) BẮT BUỘC phải override (ghi đè) để trỏ về Data thực tế.
# ==========================================

func get_defense() -> float:
	return 0.0

func get_crit_chance() -> float:
	return 0.0
	
func get_crit_damage() -> float:
	return 2.0

func get_attack() -> float:
	return 10.0

func get_spell_power() -> float:
	return 10.0

func get_attack_speed() -> float:
	return 1.0
