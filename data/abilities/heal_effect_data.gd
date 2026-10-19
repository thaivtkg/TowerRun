class_name HealEffectData
extends EffectData

@export var heal_amount: float:
	get:
		return base_amount
	set(val):
		base_amount = val

func _init() -> void:
	base_amount = 20.0

func _build_action_text(total_val: float, scale_str: String) -> String:
	if base_amount == 0.0:
		return "Hồi phục [color=#2ecc71][b]%.0f[/b][/color]%s Máu cho bản thân." % [total_val, scale_str]
	return "Hồi [color=#2ecc71][b]%.0f[/b][/color]%s Máu cho mục tiêu." % [total_val, scale_str]
