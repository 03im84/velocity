extends RefCounted
class_name ProximityLiftModel


## ProximityLiftModel
##
## Snapshot tratado como inmutable que calcula lift ficticio
## adicional por proximidad a una superficie válida.
##
## No depende de atmósfera, velocidad, wing geometry o surface normal.
## Aerodynamic Ground Effect pertenece a un model sucesor.
## Vehicle Environment and Realism Addendum.


var _influence_height_meters: float
var _max_proximity_lift_force_newtons: float
var _response_exponent: float


func _init(
	influence_height_meters: float,
	max_proximity_lift_force_newtons: float,
	response_exponent: float
) -> void:

	_influence_height_meters = influence_height_meters
	_max_proximity_lift_force_newtons = (
		max_proximity_lift_force_newtons
	)
	_response_exponent = response_exponent


func get_influence_height_meters() -> float:

	return _influence_height_meters


func get_max_proximity_lift_force_newtons() -> float:

	return _max_proximity_lift_force_newtons


func get_response_exponent() -> float:

	return _response_exponent


func calculate_lift_force_newtons(
	distance_meters: float
) -> float:

	if not is_valid():
		return 0.0

	if (
		not is_finite(distance_meters)
		or distance_meters < 0.0
	):
		return 0.0

	var normalized_proximity := clampf(
		1.0 - (distance_meters / _influence_height_meters),
		0.0,
		1.0
	)
	var force_newtons := (
		_max_proximity_lift_force_newtons
		* pow(normalized_proximity, _response_exponent)
	)

	if not is_finite(force_newtons):
		return 0.0

	return clampf(
		force_newtons,
		0.0,
		_max_proximity_lift_force_newtons
	)


func is_force_within_limits(
	force_newtons: float
) -> bool:

	return (
		is_valid()
		and is_finite(force_newtons)
		and force_newtons >= 0.0
		and force_newtons
		<= _max_proximity_lift_force_newtons
	)


func is_valid() -> bool:

	return (
		is_finite(_influence_height_meters)
		and is_finite(
			_max_proximity_lift_force_newtons
		)
		and is_finite(_response_exponent)
		and _influence_height_meters > 0.0
		and _max_proximity_lift_force_newtons >= 0.0
		and _response_exponent > 0.0
	)
