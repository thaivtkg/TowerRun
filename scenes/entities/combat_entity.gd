class_name CombatEntity
extends CharacterBody2D

signal died(entity: CombatEntity)

var current_hp: float = 0.0
var is_dead: bool = false

func take_damage(amount: float) -> void:
	if is_dead: return
	
	# Validate inputs to prevent unintended behaviors
	if amount < 0 or is_nan(amount) or is_inf(amount):
		printerr("[CombatEntity] WARNING: Invalid damage amount: ", amount)
		return
		
	current_hp -= amount
	print("[Combat] ", name, " takes ", amount, " damage! (HP: ", current_hp, ")")
	
	if current_hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	print("[Combat] ☠️ ", name, " has died.")
	died.emit(self)
	queue_free()
