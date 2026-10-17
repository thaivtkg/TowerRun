class_name CombatMetric
extends RefCounted

# ==========================================
# COMBAT METRIC (SPRINT 3)
# Sổ sách ghi nhận đóng góp chiến đấu của Hero
# ==========================================

var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var healing_done: float = 0.0
var kills: int = 0

func reset() -> void:
	damage_dealt = 0.0
	damage_taken = 0.0
	healing_done = 0.0
	kills = 0
