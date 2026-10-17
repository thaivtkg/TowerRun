class_name DamageEffectData
extends EffectData

@export var base_damage: float:
	get:
		return base_amount
	set(val):
		base_amount = val

@export var damage_type: DamageEvent.DamageType = DamageEvent.DamageType.MAGIC
@export var can_crit: bool = true

func _init() -> void:
	base_amount = 20.0

func _build_action_text(total_val: float, scale_str: String) -> String:
	var type_name := "phép" if damage_type == DamageEvent.DamageType.MAGIC else "vật lý"
	var type_color := "#ff5555" if damage_type == DamageEvent.DamageType.PHYSICAL else "#9b59b6"
	return "Gây [color=%s][b]%.0f[/b][/color]%s sát thương %s." % [type_color, total_val, scale_str, type_name]
