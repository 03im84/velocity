extends RefCounted
class_name YawSteeringModel


## YawSteeringModel
##
## Snapshot inmutable que convierte normalized yaw intent y yaw rate en
## torque escalar acotado con damping explícito.
##
## No conoce motion sources, sinks, Vector3, RigidBody3D o DeviceBus.
## ADR-017 / Playable Vehicle Composition Design 1.1.


var _max_yaw_torque_newton_meters: float
var _yaw_damping_newton_meter_seconds: float
var _max_abs_yaw_rate_radians_per_second: float


func _init(
	max_yaw_torque_newton_meters: float,
	yaw_damping_newton_meter_seconds: float,
	max_abs_yaw_rate_radians_per_second: float
) -> void:

	_max_yaw_torque_newton_meters = max_yaw_torque_newton_meters
	_yaw_damping_newton_meter_seconds = (
		yaw_damping_newton_meter_seconds
	)
	_max_abs_yaw_rate_radians_per_second = (
		max_abs_yaw_rate_radians_per_second
	)


func get_max_yaw_torque_newton_meters() -> float:

	return _max_yaw_torque_newton_meters


func get_yaw_damping_newton_meter_seconds() -> float:

	return _yaw_damping_newton_meter_seconds


func get_max_abs_yaw_rate_radians_per_second() -> float:

	return _max_abs_yaw_rate_radians_per_second


func calculate_yaw_torque_newton_meters(
	normalized_yaw: float,
	yaw_rate_radians_per_second: float
) -> float:

	if not is_valid():
		return 0.0

	if (
		not is_finite(normalized_yaw)
		or normalized_yaw < -1.0
		or normalized_yaw > 1.0
		or not is_finite(yaw_rate_radians_per_second)
	):
		return 0.0

	var command_torque := (
		normalized_yaw * _max_yaw_torque_newton_meters
	)

	if (
		absf(yaw_rate_radians_per_second)
		>= _max_abs_yaw_rate_radians_per_second
		and normalized_yaw * yaw_rate_radians_per_second > 0.0
	):
		command_torque = 0.0

	var damping_torque := (
		-yaw_rate_radians_per_second
		* _yaw_damping_newton_meter_seconds
	)
	var raw_torque := command_torque + damping_torque

	if not is_finite(raw_torque):
		return 0.0

	return clampf(
		raw_torque,
		-_max_yaw_torque_newton_meters,
		_max_yaw_torque_newton_meters
	)


func is_torque_within_limits(
	torque_newton_meters: float
) -> bool:

	return (
		is_valid()
		and is_finite(torque_newton_meters)
		and torque_newton_meters
		>= -_max_yaw_torque_newton_meters
		and torque_newton_meters
		<= _max_yaw_torque_newton_meters
	)


func is_valid() -> bool:

	return (
		is_finite(_max_yaw_torque_newton_meters)
		and is_finite(_yaw_damping_newton_meter_seconds)
		and is_finite(
			_max_abs_yaw_rate_radians_per_second
		)
		and _max_yaw_torque_newton_meters >= 0.0
		and _yaw_damping_newton_meter_seconds >= 0.0
		and _max_abs_yaw_rate_radians_per_second > 0.0
	)
