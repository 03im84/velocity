extends RefCounted
class_name ManualDistanceProvider


##
## ManualDistanceProvider
##
## Produce una distancia controlada manualmente.
##
## No conoce DistanceSensorDevice.
## No conoce DeviceBus.
## No construye Measurements ni mensajes.
##


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _distance: float = 0.0
var _valid: bool = false


# =============================================================================
# PUBLIC API
# =============================================================================

## Establece una distancia en metros
## y marca la lectura como válida.
func set_distance(
	value: float
) -> void:

	_distance = value
	_valid = true


## Invalida la lectura actual.
##
## Conserva el último valor de distancia.
func invalidate() -> void:

	_valid = false


## Devuelve la distancia actual en metros.
func get_distance() -> float:

	return _distance


## Indica si la lectura actual es utilizable.
func is_valid() -> bool:

	return _valid
