extends RefCounted
class_name ScopedRuntimeDependencyResolver


##
## ScopedRuntimeDependencyResolver
##
## Snapshot inmutable de Dependency Values
## exactos para una activación runtime.
##
## No es service locator.
##


var _values: Array[RuntimeDependencyValue] = []
var _values_by_device: Dictionary[String, Dictionary] = {}
var _valid: bool = true


func _init(
	values: Array[RuntimeDependencyValue]
) -> void:

	_values = values.duplicate()
	_build_index()


func is_valid(
) -> bool:

	return _valid


func get_value_count(
) -> int:

	if not _valid:
		return 0

	return _values.size()


func has_value(
	device_id: String,
	dependency_id: StringName
) -> bool:

	if not _valid:
		return false

	if device_id.is_empty() or dependency_id == &"":
		return false

	if not _values_by_device.has(device_id):
		return false

	var values: Dictionary = _values_by_device[device_id]
	var value_entry: RuntimeDependencyValue = values.get(
		dependency_id,
		null
	)

	return (
		value_entry != null
		and value_entry.is_valid()
	)


func get_value(
	device_id: String,
	dependency_id: StringName
) -> Object:

	if not has_value(device_id, dependency_id):
		return null

	var values: Dictionary = _values_by_device[device_id]
	var value_entry: RuntimeDependencyValue = values.get(
		dependency_id,
		null
	)

	if value_entry == null:
		return null

	return value_entry.get_value()


func _build_index(
) -> void:

	_values_by_device.clear()
	_valid = true

	for value_entry: RuntimeDependencyValue in _values:

		if value_entry == null or not value_entry.is_valid():
			_invalidate()
			return

		var device_id: String = value_entry.get_device_id()
		var dependency_id: StringName = (
			value_entry.get_dependency_id()
		)
		var device_values: Dictionary = {}

		if _values_by_device.has(device_id):
			device_values = _values_by_device[device_id]

		if device_values.has(dependency_id):
			_invalidate()
			return

		device_values[dependency_id] = value_entry
		_values_by_device[device_id] = device_values


func _invalidate(
) -> void:

	_valid = false
	_values_by_device.clear()
