extends RefCounted


##
## RuntimeTestObject
##
## Objeto observable para pruebas de:
##
## - attach;
## - detach;
## - release;
## - cleanup idempotente.
##
## No representa una implementación runtime
## de producción.
##


var _attach_count: int = 0

var _detach_count: int = 0

var _release_count: int = 0


func mark_attached(
) -> void:

	_attach_count += 1


func mark_detached(
) -> void:

	_detach_count += 1


func mark_released(
) -> void:

	_release_count += 1


func get_attach_count(
) -> int:

	return _attach_count


func get_detach_count(
) -> int:

	return _detach_count


func get_release_count(
) -> int:

	return _release_count


func is_attached(
) -> bool:

	return (
		_attach_count
		> _detach_count
	)


func is_released(
) -> bool:

	return _release_count > 0
