extends RefCounted
class_name RuntimeDependencyValue


##
## RuntimeDependencyValue
##
## Asocia un Device y Dependency ID
## con un Object scoped a una activación.
##
## No declara ownership.
##


var _device_id: String
var _dependency_id: StringName
var _value: Object


func _init(
	device_id: String,
	dependency_id: StringName,
	value: Object
) -> void:

	_device_id = device_id
	_dependency_id = dependency_id
	_value = value


func get_device_id(
) -> String:

	return _device_id


func get_dependency_id(
) -> StringName:

	return _dependency_id


func get_value(
) -> Object:

	return _value


func is_valid(
) -> bool:

	return (
		not _device_id.is_empty()
		and _dependency_id != &""
		and _value != null
		and is_instance_valid(_value)
	)
