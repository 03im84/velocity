extends RefCounted


## Controlled dependency value resolver for CompositionRuntime tests.


var _values_by_device: Dictionary[String, Dictionary] = {}
var _query_order: Array[String] = []


func register_value(
	device_id: String,
	dependency_id: StringName,
	value: Object
) -> void:

	var values: Dictionary = {}

	if _values_by_device.has(device_id):
		values = _values_by_device[device_id]

	values[dependency_id] = value
	_values_by_device[device_id] = values


func has_value(
	device_id: String,
	dependency_id: StringName
) -> bool:

	_query_order.append(
		device_id + ":has:" + String(dependency_id)
	)

	if not _values_by_device.has(device_id):
		return false

	var values: Dictionary = _values_by_device[device_id]

	return values.has(dependency_id)


func get_value(
	device_id: String,
	dependency_id: StringName
) -> Object:

	_query_order.append(
		device_id + ":get:" + String(dependency_id)
	)

	if not _values_by_device.has(device_id):
		return null

	var values: Dictionary = _values_by_device[device_id]

	return values.get(
		dependency_id,
		null
	)


func get_query_order(
) -> Array[String]:

	return _query_order.duplicate()
