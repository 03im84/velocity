extends RefCounted
class_name RuntimeDependencySpec


##
## RuntimeDependencySpec
##
## Declaración inmutable de una dependencia
## requerida por una RuntimeFactory.
##
## No contiene un Value runtime activo.
##


var _dependency_id: StringName

var _ownership: int


func _init(
	dependency_id: StringName,
	ownership: int
) -> void:

	_dependency_id = dependency_id

	_ownership = ownership


func get_dependency_id(
) -> StringName:

	return _dependency_id


func get_ownership(
) -> int:

	return _ownership


func is_borrowed(
) -> bool:

	return (
		_ownership
		== RuntimeDependencyBinding.Ownership.BORROWED
	)


func is_transferred(
) -> bool:

	return (
		_ownership
		== RuntimeDependencyBinding.Ownership.TRANSFERRED
	)


func is_valid(
) -> bool:

	if _dependency_id == &"":
		return false

	if not _ownership_is_valid(
		_ownership
	):
		return false

	return true


func _ownership_is_valid(
	ownership: int
) -> bool:

	return (
		ownership
		== RuntimeDependencyBinding.Ownership.BORROWED
		or ownership
		== RuntimeDependencyBinding.Ownership.TRANSFERRED
	)
