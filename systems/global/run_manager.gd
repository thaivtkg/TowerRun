# res://systems/global/run_manager.gd
# ==========================================
# ROGUELIKE RUN MANAGER (SPRINT 3 - TASK S3.3)
# Quản lý vòng đời lượt chơi: Mạng sống (Lives), Vàng (Gold), Số Tầng (Floor)
extends Node

signal gold_changed(new_gold: int, delta: int)
signal lives_changed(new_lives: int, delta: int)
signal floor_advanced(new_floor: int)
signal run_ended(is_victory: bool)

@export var max_lives: int = 2
var current_lives: int = 2
var current_gold: int = 10
var current_floor: int = 1

func _ready() -> void:
	print("[RunManager] Sẵn sàng. Tầng: %d | Vàng: %d | Mạng: %d/%d" % [current_floor, current_gold, current_lives, max_lives])

func start_new_run(starting_gold: int = 10, starting_lives: int = 2) -> void:
	max_lives = starting_lives
	current_lives = starting_lives
	current_gold = starting_gold
	current_floor = 1
	print("[RunManager] 🌟 KHỞI TẠO RUN MỚI! Tầng: 1 | Vàng: %d | Mạng: %d/%d" % [current_gold, current_lives, max_lives])

func on_battle_won() -> Dictionary:
	var old_floor := current_floor
	# Lãi suất vàng: 10% số vàng hiện có, tối đa +5 vàng lãi (chuẩn Auto Chess)
	var interest: int = mini(5, current_gold / 10)
	var base_reward: int = 5 + old_floor
	var total_reward: int = base_reward + interest
	
	current_gold += total_reward
	current_floor += 1
	
	gold_changed.emit(current_gold, total_reward)
	floor_advanced.emit(current_floor)
	print("[RunManager] 🏆 Thắng Tầng %d! Vàng: +%d (Cơ bản: %d, Lãi: %d) -> Tổng Vàng: %d | Lên Tầng: %d" % [old_floor, total_reward, base_reward, interest, current_gold, current_floor])
	
	return {
		"is_victory": true,
		"floor": old_floor,
		"next_floor": current_floor,
		"gold_earned": total_reward,
		"base_gold": base_reward,
		"interest_gold": interest,
		"total_gold": current_gold,
		"lives_left": current_lives,
		"max_lives": max_lives,
		"can_continue": true
	}

func on_battle_lost() -> Dictionary:
	current_lives = maxi(0, current_lives - 1)
	# Vàng an ủi khi thua trận: bằng số tầng hiện tại
	var consol_gold: int = current_floor
	current_gold += consol_gold
	
	gold_changed.emit(current_gold, consol_gold)
	lives_changed.emit(current_lives, -1)
	
	var can_retry: bool = current_lives > 0
	print("[RunManager] ❌ Thua Tầng %d! Mạng: %d/%d | Vàng an ủi: +%d -> Tổng: %d | Cho phép đánh lại: %s" % [current_floor, current_lives, max_lives, consol_gold, current_gold, str(can_retry)])
	
	if not can_retry:
		run_ended.emit(false)
		print("[RunManager] ☠️ TẬN DIỆT (PERMA-DEATH)! Hết mạng sống ở Tầng %d." % current_floor)
		
	return {
		"is_victory": false,
		"floor": current_floor,
		"next_floor": current_floor,
		"gold_earned": consol_gold,
		"base_gold": consol_gold,
		"interest_gold": 0,
		"total_gold": current_gold,
		"lives_left": current_lives,
		"max_lives": max_lives,
		"can_continue": can_retry
	}
