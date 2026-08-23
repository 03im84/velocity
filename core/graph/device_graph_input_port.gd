extends RefCounted
class_name DeviceGraphInputPort


##
## DeviceGraphInputPort
##
## Entrada lógica e inmutable de un
## DeviceGraphNode.
##


const RESERVED_SEPARATOR: String = "|"


var _port_id: StringName

var _device_id: String

var _topic: StringName

var _semantic_kind: StringName


func _init(
	port_id: StringName,
	device_id: String,
	topic: StringName,
	semantic_kind: StringName
		= PortSemanticKinds.UNSPECIFIED
) -> void:

	_port_id = port_id

	_device_id = device_id

	_topic = topic

	_semantic_kind = semantic_kind


func get_port_id() -> StringName:

	return _port_id


func get_device_id() -> String:

	return _device_id


func get_topic() -> StringName:

	return _topic


func get_semantic_kind() -> StringName:

	return _semantic_kind


func is_valid() -> bool:

	return (
		_port_id != &""
		and not _device_id.is_empty()
		and _topic != &""
		and PortSemanticKinds.is_valid(
			_semantic_kind
		)
		and not String(_port_id).contains(
			RESERVED_SEPARATOR
		)
		and not _device_id.contains(
			RESERVED_SEPARATOR
		)
	)
