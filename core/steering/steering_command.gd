extends RefCounted
class_name SteeringCommand


## SteeringCommand
##
## Snapshot tratado como inmutable que representa una orden
## normalizada de yaw steering.
##
## No calcula torque, no conoce DeviceBus y no conoce física.
## ADR-017 / Playable Vehicle Composition Design 1.1.


var _normalized_yaw: float
var _timestamp: float


func _init(
	normalized_yaw: float,
	timestamp: float
) -> void:

	_normalized_yaw = normalized_yaw
	_timestamp = timestamp


func get_normalized_yaw() -> float:

	return _normalized_yaw


func get_timestamp() -> float:

	return _timestamp


func is_valid() -> bool:

	return (
		is_finite(_normalized_yaw)
		and is_finite(_timestamp)
		and _normalized_yaw >= -1.0
		and _normalized_yaw <= 1.0
		and _timestamp >= 0.0
	)
