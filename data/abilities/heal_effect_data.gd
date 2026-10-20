class_name HealEffectData
extends EffectData

@export var base_heal: float:
	get:
		return base_amount
	set(val):
		base_amount = val

@export var heal_amount: float:
	get:
		return base_amount
	set(val):
		base_amount = val

@export var apply_to_self: bool = false

func _init() -> void:
	base_amount = 20.0

func _build_action_text(total_val: float, scale_str: String) -> String:
	var num_str := fmt_val(total_val)
	if base_amount == 0.0:
		return "Hồi phục [color=#2ecc71][b]%s[/b][/color]%s Máu cho bản thân." % [num_str, scale_str]
	return "Hồi phục [color=#2ecc71][b]%s[/b][/color]%s Máu." % [num_str, scale_str]
