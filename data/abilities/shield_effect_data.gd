class_name ShieldEffectData
extends EffectData

@export var base_shield: float:
	get:
		return base_amount
	set(val):
		base_amount = val

@export var shield_amount: float:
	get:
		return base_amount
	set(val):
		base_amount = val

@export var duration: float = 4.0
@export var shield_type: int = 0 # 0: Omni (Trắng), 1: Physical (Cam), 2: Magic (Tím)
@export var apply_to_self: bool = true

func _init() -> void:
	base_amount = 0.0

func _build_action_text(total_val: float, scale_str: String) -> String:
	var num_str := fmt_val(total_val)
	if duration > 0.0:
		return "Tạo lá chắn [color=#2ecc71][b]%s[/b][/color]%s trong %.0f giây." % [num_str, scale_str, duration]
	else:
		return "Tạo lá chắn [color=#2ecc71][b]%s[/b][/color]%s." % [num_str, scale_str]
