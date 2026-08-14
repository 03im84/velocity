extends DistanceProvider
class_name ManualDistanceProvider


#var distance: float = 0.0
#var valid: bool = false


func set_distance(value: float) -> void:
	distance = value
	valid = true


func invalidate() -> void:
	valid = false


func get_distance() -> float:
	return distance


func is_valid() -> bool:
	return valid
