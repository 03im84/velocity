extends RefCounted


##
## DistanceSensorTestProvider
##
## Provider mínimo exclusivo de la prueba.
##
## No pertenece a Provider System.
## No utiliza class_name.
##


var _distance: float = 0.0
var _valid: bool = false


func set_measurement(
	p_distance: float,
	p_valid: bool
) -> void:

	_distance = p_distance
	_valid = p_valid


func get_distance() -> float:

	return _distance


func is_valid() -> bool:

	return _valid
