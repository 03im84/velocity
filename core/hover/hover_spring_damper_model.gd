extends RefCounted
class_name HoverSpringDamperModel


## HoverSpringDamperModel
##
## Snapshot tratado como inmutable que calcula lift escalar,
## no negativo y acotado mediante spring-damper con bias.
##
## No conserva history, no conoce DeviceBus y no aplica física.
## ADR-016 / Hover Physics Slice Design 1.0.


var _target_height_meters: float
var _equilibrium_force_newtons: float
var _spring_stiffness_newtons_per_meter: float
var _damping_newton_seconds_per_meter: float
var _max_lift_force_newtons: float
var _max_sample_interval_seconds: float


func _init(
	target_height_meters: float,
	equilibrium_force_newtons: float,
	spring_stiffness_newtons_per_meter: float,
	damping_newton_seconds_per_meter: float,
	max_lift_force_newtons: float,
	max_sample_interval_seconds: float
) -> void:

	_target_height_meters = target_height_meters
	_equilibrium_force_newtons = equilibrium_force_newtons
	_spring_stiffness_newtons_per_meter = (
		spring_stiffness_newtons_per_meter
	)
	_damping_newton_seconds_per_meter = (
		damping_newton_seconds_per_meter
	)
	_max_lift_force_newtons = max_lift_force_newtons
	_max_sample_interval_seconds = max_sample_interval_seconds


func get_target_height_meters() -> float:

	return _target_height_meters


func get_equilibrium_force_newtons() -> float:

	return _equilibrium_force_newtons


func get_spring_stiffness_newtons_per_meter() -> float:

	return _spring_stiffness_newtons_per_meter


func get_damping_newton_seconds_per_meter() -> float:

	return _damping_newton_seconds_per_meter


func get_max_lift_force_newtons() -> float:

	return _max_lift_force_newtons


func get_max_sample_interval_seconds() -> float:

	return _max_sample_interval_seconds


func calculate_lift_force_newtons(
	distance_meters: float,
	distance_rate_meters_per_second: float
) -> float:

	if not is_valid():
		return 0.0

	if (
		not is_finite(distance_meters)
		or distance_meters < 0.0
		or not is_finite(
			distance_rate_meters_per_second
		)
	):
		return 0.0

	var height_error := (
		_target_height_meters - distance_meters
	)
	var spring_force := (
		_spring_stiffness_newtons_per_meter
		* height_error
	)
	var damping_force := (
		_damping_newton_seconds_per_meter
		* distance_rate_meters_per_second
	)
	var raw_lift := (
		_equilibrium_force_newtons
		+ spring_force
		- damping_force
	)

	if not is_finite(raw_lift):
		return 0.0

	return clampf(
		raw_lift,
		0.0,
		_max_lift_force_newtons
	)


func is_force_within_limits(
	force_newtons: float
) -> bool:

	return (
		is_valid()
		and is_finite(force_newtons)
		and force_newtons >= 0.0
		and force_newtons <= _max_lift_force_newtons
	)


func is_sample_interval_valid(
	delta_seconds: float
) -> bool:

	return (
		is_valid()
		and is_finite(delta_seconds)
		and delta_seconds > 0.0
		and delta_seconds
		<= _max_sample_interval_seconds
	)


func is_valid() -> bool:

	return (
		is_finite(_target_height_meters)
		and is_finite(_equilibrium_force_newtons)
		and is_finite(
			_spring_stiffness_newtons_per_meter
		)
		and is_finite(
			_damping_newton_seconds_per_meter
		)
		and is_finite(_max_lift_force_newtons)
		and is_finite(_max_sample_interval_seconds)
		and _target_height_meters > 0.0
		and _equilibrium_force_newtons >= 0.0
		and _spring_stiffness_newtons_per_meter >= 0.0
		and _damping_newton_seconds_per_meter >= 0.0
		and _max_lift_force_newtons
		>= _equilibrium_force_newtons
		and _max_sample_interval_seconds > 0.0
	)
