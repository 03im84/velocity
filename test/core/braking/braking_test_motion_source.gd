extends RefCounted


var result: Variant = 0.0
var read_count: int = 0


func get_longitudinal_speed_meters_per_second() -> Variant:

	read_count += 1
	return result
