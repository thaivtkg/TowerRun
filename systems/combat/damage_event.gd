class_name DamageEvent
extends RefCounted

enum DamageType { PHYSICAL, MAGIC, TRUE }

var source: CombatEntity = null
var target: CombatEntity = null
var base_damage: float = 0.0
var damage_type: DamageType = DamageType.PHYSICAL
var is_crit: bool = false
var crit_multiplier: float = 2.0 # Hệ số nhân (mặc định x2)
var final_damage: float = 0.0

func _init(_source: CombatEntity, _target: CombatEntity, _base: float, _type: DamageType = DamageType.PHYSICAL) -> void:
	source = _source
	target = _target
	base_damage = _base
	damage_type = _type
	final_damage = _base	
