extends RefCounted


var result: Variant = true
var apply_count: int = 0
var last_torque_newton_meters: float = 0.0
var last_timestamp: float = 0.0


func apply_yaw_torque(
	torque_newton_meters: float,
	timestamp: float
) -> Variant:

	apply_count += 1
	last_torque_newton_meters = torque_newton_meters
	last_timestamp = timestamp
	return result
