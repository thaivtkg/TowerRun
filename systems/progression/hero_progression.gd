class_name HeroProgression
extends RefCounted

signal leveled_up(new_level: int)
signal level_up(new_level: int)
signal xp_gained(amount: float)
signal milestone_reached(level: int)

const MAX_LEVEL: int = 25
const BASE_XP: float = 100.0
const GROWTH_FACTOR: float = 1.15
const MILESTONES: Array[int] = [5, 10, 15, 20, 25]

var current_level: int = 1:
	set(val):
		current_level = val
		level = val
var level: int = 1

var current_xp: float = 0.0
var required_xp: float = 100.0
var pending_milestones: Array[int] = []

func add_xp(amount: float) -> void:
	if amount <= 0.0 or current_level >= MAX_LEVEL:
		return
		
	current_xp += amount
	xp_gained.emit(amount)
	var leveled: bool = false
	
	while current_xp >= required_xp and current_level < MAX_LEVEL:
		current_xp -= required_xp
		current_level += 1
		required_xp = _calculate_required_xp(current_level)
		leveled = true
		
		# Kích hoạt Milestone ngay trong vòng lặp để bắt dính trường hợp nhảy nhiều cấp
		if current_level in MILESTONES:
			if not pending_milestones.has(current_level):
				pending_milestones.append(current_level)
			milestone_reached.emit(current_level)
		
	if leveled:
		leveled_up.emit(current_level)
		level_up.emit(current_level)
		
	if current_level >= MAX_LEVEL:
		current_xp = required_xp

func _calculate_required_xp(target_level: int) -> float:
	return BASE_XP * pow(GROWTH_FACTOR, target_level - 1)
