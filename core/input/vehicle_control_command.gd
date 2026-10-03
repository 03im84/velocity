extends RefCounted
class_name VehicleControlCommand


var _throttle: float
var _steering: float
var _brake: float
var _timestamp: float


func _init(
	throttle: float,
	steering: float,
	brake: float,
	timestamp: float
) -> void:

	_throttle = throttle
	_steering = steering
	_brake = brake
	_timestamp = timestamp


func get_throttle() -> float:

	return _throttle


func get_steering() -> float:

	return _steering


func get_brake() -> float:

	return _brake


func get_timestamp() -> float:

	return _timestamp


func is_valid() -> bool:

	return (
		is_finite(_throttle)
		and is_finite(_steering)
		and is_finite(_brake)
		and is_finite(_timestamp)
		and _throttle >= -1.0
		and _throttle <= 1.0
		and _steering >= -1.0
		and _steering <= 1.0
		and _brake >= 0.0
		and _brake <= 1.0
		and _timestamp >= 0.0
	)
