extends Resource
class_name DeviceHealth


##
## DeviceHealth
##
## Representa la condición operacional
## y los diagnósticos de un Device.
##
## Health no representa Lifecycle.
##


enum Status {
	HEALTHY,
	DEGRADED,
	CRITICAL,
	FAILED
}


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _status: Status = Status.HEALTHY

var _faults: Array[String] = []

var _warnings: Array[String] = []


# =============================================================================
# STATUS
# =============================================================================

## Establece explícitamente la condición
## operacional del Device.
func set_status(
	new_status: Status
) -> void:

	_status = new_status


## Devuelve la condición operacional actual.
func get_status() -> Status:

	return _status


# =============================================================================
# FAULTS
# =============================================================================

## Añade un fault sin permitir duplicados.
##
## No modifica automáticamente el status.
func add_fault(
	fault: String
) -> void:

	if not _faults.has(fault):
		_faults.append(fault)


## Elimina un fault si existe.
##
## No modifica automáticamente el status.
func remove_fault(
	fault: String
) -> void:

	_faults.erase(fault)


## Devuelve una copia de los faults.
func get_faults() -> Array[String]:

	return _faults.duplicate()


## Indica si existen faults registrados.
func has_faults() -> bool:

	return not _faults.is_empty()


# =============================================================================
# WARNINGS
# =============================================================================

## Añade un warning sin permitir duplicados.
##
## No modifica automáticamente el status.
func add_warning(
	warning: String
) -> void:

	if not _warnings.has(warning):
		_warnings.append(warning)


## Elimina un warning si existe.
##
## No modifica automáticamente el status.
func remove_warning(
	warning: String
) -> void:

	_warnings.erase(warning)


## Devuelve una copia de los warnings.
func get_warnings() -> Array[String]:

	return _warnings.duplicate()


## Indica si existen warnings registrados.
func has_warnings() -> bool:

	return not _warnings.is_empty()


# =============================================================================
# OPERATIONAL STATE
# =============================================================================

## Indica si el Device puede considerarse
## operacional según su Health.
func is_operational() -> bool:

	return _status != Status.FAILED
