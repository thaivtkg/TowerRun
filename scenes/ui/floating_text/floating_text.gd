class_name FloatingText
extends Marker2D

@onready var label: Label = $Label

enum Type {
	DAMAGE, # Fallback/alias to DAMAGE_PHYSICAL
	DAMAGE_PHYSICAL,
	DAMAGE_MAGIC,
	DAMAGE_TRUE,
	CRIT,
	HEAL,
	XP,
	SYSTEM
}

func setup(value_str: String, type: Type) -> void:
	if label == null:
		label = get_node_or_null("Label")
	if label == null:
		if not is_node_ready(): await ready
		label = get_node_or_null("Label")
	if label == null:
		return

	# Typography rule: Viền đen sắc nét (#11141a, 3px), tương phản cao
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color("#11141a"))
	label.add_theme_constant_override("outline_size", 3)

	var display_str: String = value_str
	var target_scale := Vector2(1.0, 1.0)
	var float_offset := Vector2.ZERO
	var duration: float = 0.7
	var fade_delay: float = 0.35
	var fade_duration: float = 0.35
	var is_crit: bool = false
	var is_system: bool = false

	# Cấu hình màu sắc, kích thước và quỹ đạo bay theo GD Palette Matrix
	match type:
		Type.DAMAGE, Type.DAMAGE_PHYSICAL:
			label.modulate = Color("#ff7675")
			target_scale = Vector2(1.0, 1.0)
			float_offset = Vector2(randf_range(-15.0, 15.0), -45.0)
			duration = 0.7
			fade_delay = 0.35
			fade_duration = 0.35

		Type.DAMAGE_MAGIC:
			label.modulate = Color("#a29bfe")
			target_scale = Vector2(1.0, 1.0)
			float_offset = Vector2(randf_range(-10.0, 10.0), -55.0)
			duration = 0.75
			fade_delay = 0.35
			fade_duration = 0.4

		Type.DAMAGE_TRUE:
			label.modulate = Color("#ffffff")
			target_scale = Vector2(1.1, 1.1)
			float_offset = Vector2(0.0, -50.0)
			duration = 0.7
			fade_delay = 0.35
			fade_duration = 0.35

		Type.CRIT:
			label.modulate = Color("#fdcb6e")
			if not display_str.ends_with("!"):
				display_str += "!"
			target_scale = Vector2(1.6, 1.6)
			float_offset = Vector2(randf_range(-35.0, 35.0), -65.0)
			duration = 0.8
			fade_delay = 0.4
			fade_duration = 0.4
			is_crit = true

		Type.HEAL:
			label.modulate = Color("#2ecc71")
			if not display_str.begins_with("+"):
				display_str = "+" + display_str
			target_scale = Vector2(1.0, 1.0)
			float_offset = Vector2(0.0, -50.0)
			duration = 0.9
			fade_delay = 0.5
			fade_duration = 0.4

		Type.XP:
			label.modulate = Color("#fd79a8")
			if not display_str.ends_with("XP"):
				display_str += " XP"
			target_scale = Vector2(0.9, 0.9)
			float_offset = Vector2(0.0, -25.0)
			duration = 0.7
			fade_delay = 0.35
			fade_duration = 0.35

		Type.SYSTEM:
			label.modulate = Color("#f1c40f")
			target_scale = Vector2(1.2, 1.2)
			float_offset = Vector2(0.0, -40.0)
			duration = 1.0
			fade_delay = 0.5
			fade_duration = 0.5
			is_system = true

	label.text = display_str

	# Bắt đầu chuỗi Hoạt ảnh (Tween)
	var tween = create_tween().set_parallel(true)

	if is_crit:
		# Pop & Bounce: Phóng to nhanh 0.12s, nảy nhẹ rồi giữ quy mô
		scale = target_scale * 0.4
		tween.tween_property(self, "scale", target_scale * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", target_scale, 0.08).set_delay(0.12)
		tween.tween_property(self, "position", position + float_offset, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif is_system:
		# SYSTEM: Dừng 0.3s tại chỗ trước khi trượt lên
		scale = target_scale
		tween.tween_property(self, "position", position + float_offset, duration - 0.3).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		scale = target_scale * 0.5
		tween.tween_property(self, "scale", target_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", position + float_offset, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Mờ dần (Fade-out effect)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_LINEAR).set_delay(fade_delay)

	# Tự động hủy khi Tween kết thúc
	tween.chain().tween_callback(queue_free)
