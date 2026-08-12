class_name CombatEntity
extends CharacterBody2D

signal died(entity: CombatEntity)
signal attack_requested(event: DamageEvent)

var current_hp: float = 0.0
var is_dead: bool = false

func take_damage(amount: float) -> void:
	if is_dead: return
	
	# Validate inputs to prevent unintended behaviors
	if amount < 0 or is_nan(amount) or is_inf(amount):
		printerr("[CombatEntity] WARNING: Invalid damage amount: ", amount)
		return
		
	current_hp -= amount
	
	# Format hiển thị cho gọn gàng
	print("[Combat] %s takes %.1f damage! (HP: %.1f)" % [name, amount, current_hp])
	
	if current_hp <= 0:
		_die()

func get_crit_chance() -> float: return 0.0
func get_crit_damage() -> float: return 2.0

func _die() -> void:
	is_dead = true
	
	# Chuyển sang trạng thái Xác chết (Corpse): 
	# Ẩn đồ họa và vô hiệu hóa mọi tiến trình update để tiết kiệm hiệu năng, KHÔNG xóa bằng queue_free().
	visible = false 
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	
	print("[Combat] ☠️ ", name, " has died (Became a Corpse).")
	died.emit(self)
