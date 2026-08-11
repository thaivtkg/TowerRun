class_name HeroEntity
extends CharacterBody2D

signal died(entity: HeroEntity)

@export var data: HeroData
var current_hp: float = 0.0
var target: Node2D = null # Tham chiếu tới Enemy
var is_dead: bool = false

@onready var attack_timer: Timer = $AttackTimer

func initialize(initial_data: HeroData) -> void:
	data = initial_data
	if data == null:
		printerr("[HeroEntity] FATAL: HeroData is null.")
		return
		
	current_hp = data.base_hp
	
	# Thiết lập tốc độ đánh (Ví dụ: attack_speed = 2.0 nghĩa là 0.5s đánh 1 lần)
	attack_timer.wait_time = 1.0 / data.attack_speed
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()
	
	print("[HeroEntity] Initialized: ", data.name, " | HP: ", current_hp)

func take_damage(amount: float) -> void:
	if is_dead: return
	
	current_hp -= amount
	print("[Combat] ", data.name, " takes ", amount, " damage! (HP: ", current_hp, "/", data.base_hp, ")")
	
	if current_hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	attack_timer.stop()
	print("[Combat] ☠️ ", data.name, " has died.")
	died.emit(self)
	queue_free()

# 🔮 Defensive Error Handling: Kiểm tra tính hợp lệ của target
func _on_attack_timer_timeout() -> void:
	if is_dead or data == null: return
	
	if is_instance_valid(target) and not target.is_dead:
		target.take_damage(data.base_attack)
	else:
		attack_timer.stop() # Ngừng vung vũ khí nếu target đã chết
