class_name CombatEntity
extends CharacterBody2D

signal died(entity: CombatEntity)
signal attack_requested(event: DamageEvent)
signal healed(entity: CombatEntity, amount: float)
signal hp_changed(current: float, max_val: float)
signal energy_changed(current: float, max_val: float)

const STATUS_BAR_SCENE: PackedScene = preload("res://scenes/ui/status_bar/EntityStatusBar.tscn")

var status_bar: EntityStatusBar = null
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

var is_dead: bool = false
var target: CombatEntity = null # [FIX] Gom biến target về Base Class để TargetingSystem truy xuất an toàn

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

func setup_status_bar(is_hero: bool) -> void:
	if status_bar != null and is_instance_valid(status_bar):
		status_bar.queue_free()
		
	if STATUS_BAR_SCENE != null:
		status_bar = STATUS_BAR_SCENE.instantiate() as EntityStatusBar
		add_child(status_bar)
		status_bar.position = Vector2(0, -35)
		
		if not hp_changed.is_connected(status_bar.on_hp_changed):
			hp_changed.connect(status_bar.on_hp_changed)
			
		var init_energy: float = 0.0
		var init_max_energy: float = 100.0
		if is_hero:
			if not energy_changed.is_connected(status_bar.on_energy_changed):
				energy_changed.connect(status_bar.on_energy_changed)
			init_energy = get("current_energy") if get("current_energy") != null else 0.0
			init_max_energy = get("max_energy") if get("max_energy") != null else 100.0
			
		status_bar.setup(is_hero, current_hp, max_hp, init_energy, init_max_energy)

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var old_hp := current_hp
	var limit_hp: float = max_hp if max_hp > 0.0 else 9999.0
	current_hp = min(current_hp + amount, limit_hp)
	var actual_healed := current_hp - old_hp
	if actual_healed > 0.0:
		healed.emit(self, actual_healed)

func take_damage(amount: float) -> void:
	if is_dead: return
	
	if amount < 0 or is_nan(amount) or is_inf(amount):
		printerr("[CombatEntity] WARNING: Invalid damage amount: ", amount)
		return
		
	current_hp -= amount
	print("[Combat] %s takes %.1f damage! (HP: %.1f)" % [name, amount, current_hp])
	
	if current_hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	visible = false
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	print("[Combat] ☠️ ", name, " has died (Became a Corpse).")
	died.emit(self)

func set_combat_active(active: bool) -> void:
	if not active:
		target = null
	set_process(active)

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
