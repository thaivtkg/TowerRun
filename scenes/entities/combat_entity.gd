class_name CombatEntity
extends CharacterBody2D

signal died(entity: CombatEntity)
signal attack_requested(event: DamageEvent)
signal healed(entity: CombatEntity, amount: float)

var current_hp: float = 0.0
var max_hp: float = 0.0
var is_dead: bool = false
var target: CombatEntity = null # [FIX] Gom biến target về Base Class để TargetingSystem truy xuất an toàn

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
