extends RefCounted
class_name PropulsionCommand


## PropulsionCommand
##
## Snapshot tratado como inmutable que representa una orden
## longitudinal normalizada de propulsión.
##
## No calcula fuerza, no conoce DeviceBus y no conoce física.
## ADR-015 / Propulsion Runtime Slice Design 1.0.


var _normalized_thrust: float
var _timestamp: float


func _init(
	normalized_thrust: float,
	timestamp: float
) -> void:

	_normalized_thrust = normalized_thrust
	_timestamp = timestamp


func get_normalized_thrust() -> float:

	return _normalized_thrust


func get_timestamp() -> float:

	return _timestamp


func is_valid() -> bool:

	return (
		is_finite(_normalized_thrust)
		and is_finite(_timestamp)
		and _normalized_thrust >= -1.0
		and _normalized_thrust <= 1.0
		and _timestamp >= 0.0
	)
