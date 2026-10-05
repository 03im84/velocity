extends RefCounted


var result: Variant = true
var apply_count: int = 0
var last_force_newtons: float = 0.0
var last_timestamp: float = 0.0


func apply_propulsion_force(
	force_newtons: float,
	timestamp: float
) -> Variant:

	apply_count += 1
	last_force_newtons = force_newtons
	last_timestamp = timestamp
	return result
