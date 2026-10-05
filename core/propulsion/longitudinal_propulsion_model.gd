extends RefCounted
class_name LongitudinalPropulsionModel


## LongitudinalPropulsionModel
##
## Snapshot tratado como inmutable que convierte thrust normalizado
## en una fuerza longitudinal escalar y acotada.
##
## La transferencia es lineal. No define Vector3, eje físico,
## punto de aplicación, torque o dispersión radial.
## ADR-015 / Propulsion Runtime Slice Design 1.0.


var _max_forward_force_newtons: float
var _max_reverse_force_newtons: float


func _init(
	max_forward_force_newtons: float,
	max_reverse_force_newtons: float
) -> void:

	_max_forward_force_newtons = max_forward_force_newtons
	_max_reverse_force_newtons = max_reverse_force_newtons


func get_max_forward_force_newtons() -> float:

	return _max_forward_force_newtons


func get_max_reverse_force_newtons() -> float:

	return _max_reverse_force_newtons


func calculate_force_newtons(
	normalized_thrust: float
) -> float:

	if not is_valid():
		return 0.0

	if (
		not is_finite(normalized_thrust)
		or normalized_thrust < -1.0
		or normalized_thrust > 1.0
	):
		return 0.0

	if normalized_thrust >= 0.0:
		return (
			normalized_thrust
			* _max_forward_force_newtons
		)

	return (
		normalized_thrust
		* _max_reverse_force_newtons
	)


func is_force_within_limits(
	force_newtons: float
) -> bool:

	return (
		is_valid()
		and is_finite(force_newtons)
		and force_newtons
		>= -_max_reverse_force_newtons
		and force_newtons
		<= _max_forward_force_newtons
	)


func is_valid() -> bool:

	return (
		is_finite(_max_forward_force_newtons)
		and is_finite(_max_reverse_force_newtons)
		and _max_forward_force_newtons >= 0.0
		and _max_reverse_force_newtons >= 0.0
	)
