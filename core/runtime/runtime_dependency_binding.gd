extends RefCounted
class_name RuntimeDependencyBinding


##
## RuntimeDependencyBinding
##
## Dependencia runtime pre-resuelta
## con ownership explícito.
##


enum Ownership {
	BORROWED,
	TRANSFERRED,
}


var _dependency_id: StringName

var _value: Object

var _ownership: int


func _init(
	dependency_id: StringName,
	value: Object,
	ownership: int
) -> void:

	_dependency_id = dependency_id

	_value = value

	_ownership = ownership


func get_dependency_id(
) -> StringName:

	return _dependency_id


func get_value(
) -> Object:

	return _value


func get_ownership(
) -> int:

	return _ownership


func is_borrowed(
) -> bool:

	return _ownership == Ownership.BORROWED


func is_transferred(
) -> bool:

	return _ownership == Ownership.TRANSFERRED


func is_valid(
) -> bool:

	if _dependency_id == &"":
		return false

	if _value == null:
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
		ownership == Ownership.BORROWED
		or ownership == Ownership.TRANSFERRED
	)
