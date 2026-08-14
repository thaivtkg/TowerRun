class_name HeroProgression
extends RefCounted

signal leveled_up(new_level: int)
signal milestone_reached(level: int) # [ADDED] Tín hiệu chuyên dụng cho Milestone

const MAX_LEVEL: int = 25
var level: int = 1
var current_xp: float = 0.0
var required_xp: float = 100.0

func add_xp(amount: float) -> void:
	if amount <= 0.0 or level >= MAX_LEVEL:
		return
		
	current_xp += amount
	var leveled: bool = false
	
	while current_xp >= required_xp and level < MAX_LEVEL:
		current_xp -= required_xp
		level += 1
		required_xp = _calculate_required_xp(level)
		leveled = true
		
		# Kích hoạt Milestone ngay trong vòng lặp để bắt dính trường hợp nhảy nhiều cấp
		if level in [5, 10, 15, 20, 25]:
			milestone_reached.emit(level)
		
	if leveled:
		leveled_up.emit(level)
		
	if level >= MAX_LEVEL:
		current_xp = required_xp

func _calculate_required_xp(target_level: int) -> float:
	return 100.0 + (target_level - 1) * 50.0
