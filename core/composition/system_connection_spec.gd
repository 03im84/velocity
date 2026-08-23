extends RefCounted
class_name SystemConnectionSpec


##
## SystemConnectionSpec
##
## Representa endpoints persistibles
## antes de construir DeviceGraph.
##
## No almacena Topic ni Semantic Kind.
##


const CONNECTION_ID_SEPARATOR: String = "|"


var _connection_id: StringName

var _source_device_id: String

var _source_port_id: StringName

var _target_device_id: String

var _target_port_id: StringName


func _init(
	source_device_id: String,
	source_port_id: StringName,
	target_device_id: String,
	target_port_id: StringName
) -> void:

	_source_device_id = source_device_id

	_source_port_id = source_port_id

	_target_device_id = target_device_id

	_target_port_id = target_port_id

	_connection_id = _build_connection_id(
		source_device_id,
		source_port_id,
		target_device_id,
		target_port_id
	)


func get_connection_id(
) -> StringName:

	return _connection_id


func get_source_device_id(
) -> String:

	return _source_device_id


func get_source_port_id(
) -> StringName:

	return _source_port_id


func get_target_device_id(
) -> String:

	return _target_device_id


func get_target_port_id(
) -> StringName:

	return _target_port_id


func is_valid_identity(
) -> bool:

	if _connection_id == &"":
		return false

	if _source_device_id.is_empty():
		return false

	if _source_port_id == &"":
		return false

	if _target_device_id.is_empty():
		return false

	if _target_port_id == &"":
		return false

	if _source_device_id == _target_device_id:
		return false

	if _identifier_contains_reserved_separator(
		_source_device_id
	):
		return false

	if _identifier_contains_reserved_separator(
		String(_source_port_id)
	):
		return false

	if _identifier_contains_reserved_separator(
		_target_device_id
	):
		return false

	if _identifier_contains_reserved_separator(
		String(_target_port_id)
	):
		return false

	var expected_connection_id := _build_connection_id(
		_source_device_id,
		_source_port_id,
		_target_device_id,
		_target_port_id
	)

	return _connection_id == expected_connection_id


func _build_connection_id(
	source_device_id: String,
	source_port_id: StringName,
	target_device_id: String,
	target_port_id: StringName
) -> StringName:

	var id_text: String = (
		source_device_id
		+ CONNECTION_ID_SEPARATOR
		+ String(source_port_id)
		+ CONNECTION_ID_SEPARATOR
		+ target_device_id
		+ CONNECTION_ID_SEPARATOR
		+ String(target_port_id)
	)

	return StringName(id_text)


func _identifier_contains_reserved_separator(
	identifier: String
) -> bool:

	return identifier.contains(
		CONNECTION_ID_SEPARATOR
	)
