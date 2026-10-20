class_name ItemPassiveSystem
extends Node

# ==========================================
# ITEM PASSIVE SYSTEM (SPRINT 6 - TASK S6.2)
# Xử lý kích hoạt nội tại Bậc 2 & Bậc 3 Thần Thoại
# ==========================================

static var instance: ItemPassiveSystem = null

func _init() -> void:
	instance = self

func _ready() -> void:
	instance = self

func check_execute_crit(hero: HeroEntity, victim: CombatEntity, event: DamageEvent) -> void:
	if hero == null or victim == null or event == null:
		return
	# Nội tại Tuyệt Diệt Bạo Kích: chí mạng kết liễu kẻ địch dưới 15% máu hoặc tăng 25% sát thương khi mục tiêu < 40% máu
	if hero.has_item_passive("execute_crit") and event.is_crit:
		if victim.max_hp > 0.0 and (victim.current_hp / victim.max_hp) <= 0.40:
			event.final_damage *= 1.25

func check_immortal_revive(hero: HeroEntity) -> bool:
	if hero == null or hero.is_dead:
		return false
	if hero.has_item_passive("immortal_stone") and not hero.get_meta("immortal_used", false):
		hero.set_meta("immortal_used", true)
		hero.current_hp = hero.max_hp * 0.40
		hero.is_dead = false
		return true
	return false
