extends RefCounted
class_name DistanceProvider


var distance: float = 0.0
var valid: bool = false


func set_distance(value: float) -> void:
	distance = value
	valid = true


func invalidate() -> void:
	valid = false


func get_distance() -> float:
	return 0.0


#func is_valid() -> bool:
#	return false
