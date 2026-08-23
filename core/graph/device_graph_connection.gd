extends RefCounted
class_name DeviceGraphConnection


##
## DeviceGraphConnection
##
## Relación lógica e inmutable entre
## Source OutputPort, TopicChannel
## y Target InputPort.
##
## No crea comunicación directa.
##


const RESERVED_SEPARATOR: String = "|"


var _connection_id: StringName

var _source_device_id: String

var _source_port_id: StringName

var _topic: StringName

var _target_device_id: String

var _target_port_id: StringName


func _init(
	connection_id: StringName,
	source_device_id: String,
	source_port_id: StringName,
	topic: StringName,
	target_device_id: String,
	target_port_id: StringName
) -> void:

	_connection_id = connection_id

	_source_device_id = source_device_id

	_source_port_id = source_port_id

	_topic = topic

	_target_device_id = target_device_id

	_target_port_id = target_port_id


func get_connection_id() -> StringName:

	return _connection_id


func get_source_device_id() -> String:

	return _source_device_id


func get_source_port_id() -> StringName:

	return _source_port_id


func get_topic() -> StringName:

	return _topic


func get_target_device_id() -> String:

	return _target_device_id


func get_target_port_id() -> StringName:

	return _target_port_id


func is_valid_identity() -> bool:

	return (
		_connection_id != &""
		and not _source_device_id.is_empty()
		and _source_port_id != &""
		and _topic != &""
		and not _target_device_id.is_empty()
		and _target_port_id != &""
		and not _source_device_id.contains(
			RESERVED_SEPARATOR
		)
		and not String(
			_source_port_id
		).contains(
			RESERVED_SEPARATOR
		)
		and not _target_device_id.contains(
			RESERVED_SEPARATOR
		)
		and not String(
			_target_port_id
		).contains(
			RESERVED_SEPARATOR
		)
	)
