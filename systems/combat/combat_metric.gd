class_name CombatMetric
extends RefCounted

enum MetricType {
	DAMAGE, # Ghi nhận lượng sát thương thực tế
	CRIT,   # Ghi nhận một cú đánh chí mạng
	KILL    # Ghi nhận một pha kết liễu
}

var type: MetricType
var source: CombatEntity
var target: CombatEntity
var value: float

func _init(_type: MetricType, _source: CombatEntity, _target: CombatEntity, _value: float = 0.0) -> void:
	type = _type
	source = _source
	target = _target
	value = _value
