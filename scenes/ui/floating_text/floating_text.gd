class_name FloatingText
extends Marker2D

@onready var label: Label = $Label

enum Type { DAMAGE, CRIT, HEAL, XP, SYSTEM }

func setup(value_str: String, type: Type) -> void:
	# Đảm bảo node đã sẵn sàng trước khi set text
	if not is_node_ready(): await ready
	
	label.text = value_str
	
	# Cấu hình màu sắc, kích thước và quỹ đạo bay theo từng loại
	var target_scale := Vector2(1.0, 1.0)
	var float_offset := Vector2(randf_range(-20, 20), -50) # Bay ngẫu nhiên nhẹ sang hai bên
	
	match type:
		Type.DAMAGE:
			label.modulate = Color.WHITE
		Type.CRIT:
			label.modulate = Color.ORANGE_RED
			target_scale = Vector2(1.5, 1.5)
			float_offset = Vector2(randf_range(-30, 30), -70) # Crit bay cao và nảy mạnh hơn
		Type.HEAL:
			label.modulate = Color.GREEN
			float_offset = Vector2(0, -60) # Hồi máu bay thẳng đứng
		Type.XP:
			label.modulate = Color.MEDIUM_PURPLE
			float_offset = Vector2(0, -40)
		Type.SYSTEM:
			label.modulate = Color.GOLD
	
	# Áp dụng scale ban đầu
	scale = target_scale * 0.5 # Bắt đầu nhỏ xíu
	
	# Bắt đầu chuỗi Hoạt ảnh (Tween)
	var tween = create_tween().set_parallel(true)
	
	# 1. Phóng to chữ (Pop-up effect)
	tween.tween_property(self, "scale", target_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. Bay lên trên (Float effect)
	tween.tween_property(self, "position", position + float_offset, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 3. Mờ dần (Fade-out effect) sau một khoảng delay nhỏ
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_LINEAR).set_delay(0.4)
	
	# Tự động hủy khi Tween kết thúc
	tween.chain().tween_callback(queue_free)
