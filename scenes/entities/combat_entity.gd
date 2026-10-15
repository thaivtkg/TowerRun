class_name CombatEntity
extends CharacterBody2D

signal died(entity: CombatEntity)
signal attack_requested(event: DamageEvent)
signal healed(entity: CombatEntity, amount: float)
signal hp_changed(current: float, max_val: float)

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
		if is_hero and has_signal("energy_changed"):
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
