extends RefCounted
class_name RuntimeSourceFilteredSubscription


##
## RuntimeSourceFilteredSubscription
##
## Reenvía BusMessages que coinciden
## con Source Device ID y Topic exactos.
##


var _source_device_id: String
var _topic: StringName
var _target_endpoint: Callable


func _init(
	source_device_id: String,
	topic: StringName,
	target_endpoint: Callable
) -> void:

	_source_device_id = source_device_id
	_topic = topic
	_target_endpoint = target_endpoint


func receive(
	message_value: Variant
) -> void:

	if not is_valid():
		return

	if not (message_value is BusMessage):
		return

	var message: BusMessage = message_value

	if not message.is_valid():
		return

	if message.get_source_id() != _source_device_id:
		return

	if message.get_topic() != _topic:
		return

	_target_endpoint.call(message)


func is_valid(
) -> bool:

	return (
		not _source_device_id.is_empty()
		and _topic != &""
		and _target_endpoint.is_valid()
	)


func get_source_device_id(
) -> String:

	return _source_device_id


func get_topic(
) -> StringName:

	return _topic


func get_target_endpoint(
) -> Callable:

	return _target_endpoint
