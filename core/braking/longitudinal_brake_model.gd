extends RefCounted
class_name LongitudinalBrakeModel


## LongitudinalBrakeModel
##
## Snapshot inmutable que convierte normalized brake y signed longitudinal
## speed en fuerza escalar acotada opuesta al movimiento.
##
## No conoce motion sources, sinks, timestep, RigidBody3D o DeviceBus.
## ADR-017 / Playable Vehicle Composition Design 1.1.


var _max_brake_force_newtons: float
var _speed_deadzone_meters_per_second: float


func _init(
	max_brake_force_newtons: float,
	speed_deadzone_meters_per_second: float
) -> void:

	_max_brake_force_newtons = max_brake_force_newtons
	_speed_deadzone_meters_per_second = (
		speed_deadzone_meters_per_second
	)


func get_max_brake_force_newtons() -> float:

	return _max_brake_force_newtons


func get_speed_deadzone_meters_per_second() -> float:

	return _speed_deadzone_meters_per_second


func calculate_brake_force_newtons(
	normalized_brake: float,
	longitudinal_speed_meters_per_second: float
) -> float:

	if not is_valid():
		return 0.0

	if (
		not is_finite(normalized_brake)
		or normalized_brake < 0.0
		or normalized_brake > 1.0
		or not is_finite(
			longitudinal_speed_meters_per_second
		)
	):
		return 0.0

	if (
		absf(longitudinal_speed_meters_per_second)
		<= _speed_deadzone_meters_per_second
	):
		return 0.0

	var magnitude := normalized_brake * _max_brake_force_newtons
	var force_newtons := (
		-magnitude
		if longitudinal_speed_meters_per_second > 0.0
		else magnitude
	)

	if not is_finite(force_newtons):
		return 0.0

	return clampf(
		force_newtons,
		-_max_brake_force_newtons,
		_max_brake_force_newtons
	)


func is_force_within_limits(
	force_newtons: float
) -> bool:

	return (
		is_valid()
		and is_finite(force_newtons)
		and force_newtons >= -_max_brake_force_newtons
		and force_newtons <= _max_brake_force_newtons
	)


func is_valid() -> bool:

	return (
		is_finite(_max_brake_force_newtons)
		and is_finite(_speed_deadzone_meters_per_second)
		and _max_brake_force_newtons >= 0.0
		and _speed_deadzone_meters_per_second >= 0.0
	)
