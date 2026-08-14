class_name Ability
extends RefCounted

var data: AbilityData
var owner: CombatEntity
var current_cooldown: float = 0.0

func _init(_owner: CombatEntity, _data: AbilityData) -> void:
	owner = _owner
	data = _data

func is_ready(current_energy: float = 0.0) -> bool:
	if data == null: return false
	
	# Passive luôn sẵn sàng để trigger bởi Event
	if data.ability_type == AbilityData.AbilityType.PASSIVE:
		return true
		
	return current_cooldown <= 0.0 and current_energy >= data.energy_cost

func start_cooldown() -> void:
	if data != null:
		current_cooldown = data.cooldown

func process_cooldown(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown -= delta
		if current_cooldown < 0.0:
			current_cooldown = 0.0
