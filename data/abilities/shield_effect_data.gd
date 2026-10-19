class_name ShieldEffectData
extends EffectData

@export var shield_amount: float:
	get:
		return base_amount
	set(val):
		base_amount = val

@export var duration: float = 4.0

func _init() -> void:
	base_amount = 0.0

func _build_action_text(total_val: float, scale_str: String) -> String:
	if duration > 0.0:
		return "Tạo lá chắn [color=#2ecc71][b]%.0f[/b][/color]%s tồn tại trong %.0f giây." % [total_val, scale_str, duration]
	else:
		return "Tạo lá chắn [color=#2ecc71][b]%.0f[/b][/color]%s." % [total_val, scale_str]
