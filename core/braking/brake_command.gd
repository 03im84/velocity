extends RefCounted
class_name BrakeCommand


## BrakeCommand
##
## Snapshot tratado como inmutable que representa una orden
## normalizada de active braking.
##
## No calcula fuerza, no conoce DeviceBus y no conoce física.
## ADR-017 / Playable Vehicle Composition Design 1.1.


var _normalized_brake: float
var _timestamp: float


func _init(
	normalized_brake: float,
	timestamp: float
) -> void:

	_normalized_brake = normalized_brake
	_timestamp = timestamp


func get_normalized_brake() -> float:

	return _normalized_brake


func get_timestamp() -> float:

	return _timestamp


func is_valid() -> bool:

	return (
		is_finite(_normalized_brake)
		and is_finite(_timestamp)
		and _normalized_brake >= 0.0
		and _normalized_brake <= 1.0
		and _timestamp >= 0.0
	)
