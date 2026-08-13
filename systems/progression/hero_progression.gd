class_name HeroProgression
extends RefCounted

signal leveled_up(new_level: int)

const MAX_LEVEL: int = 25
var level: int = 1
var current_xp: float = 0.0
var required_xp: float = 100.0

func add_xp(amount: float) -> void:
	if amount <= 0.0 or level >= MAX_LEVEL:
		return
		
	current_xp += amount
	var leveled: bool = false
	
	# Xử lý vòng lặp cấp độ để giải quyết lượng XP tràn (Overflow)
	while current_xp >= required_xp and level < MAX_LEVEL:
		current_xp -= required_xp
		level += 1
		required_xp = _calculate_required_xp(level)
		leveled = true
		
	if leveled:
		leveled_up.emit(level)
		
	# Khóa XP nếu đã đạt cấp độ tối đa
	if level >= MAX_LEVEL:
		current_xp = required_xp

# Công thức tính kinh nghiệm yêu cầu: Cứ mỗi cấp tăng thêm 50 XP
# Level 1 -> 2: 100 XP
# Level 2 -> 3: 150 XP ...
func _calculate_required_xp(target_level: int) -> float:
	return 100.0 + (target_level - 1) * 50.0
