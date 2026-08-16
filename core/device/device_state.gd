extends Resource
class_name DeviceState


##
## DeviceState
##
## Representa la validez y el timestamp
## de los datos de un Device.
##
## No representa Lifecycle ni Health.
##


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _data_valid: bool = false
var _last_update_time: float = 0.0


# =============================================================================
# PUBLIC API
# =============================================================================

## Marca los datos actuales como válidos.
func validate() -> void:

	_data_valid = true


## Marca los datos actuales como inválidos.
##
## Conserva el último timestamp.
func invalidate() -> void:

	_data_valid = false


## Actualiza el timestamp sin interpretar
## el origen del reloj.
func update_timestamp(
	time: float
) -> void:

	_last_update_time = time


## Indica si los datos actuales son válidos.
func is_valid() -> bool:

	return _data_valid


## Devuelve el último timestamp registrado.
func get_last_update_time() -> float:

	return _last_update_time
