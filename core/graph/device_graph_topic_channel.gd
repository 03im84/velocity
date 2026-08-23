extends RefCounted
class_name DeviceGraphTopicChannel


##
## DeviceGraphTopicChannel
##
## Representación lógica e inmutable
## de un Topic de DeviceBus.
##
## No almacena ni transporta mensajes.
##


var _topic: StringName


func _init(
	topic: StringName
) -> void:

	_topic = topic


func get_topic() -> StringName:

	return _topic


func is_valid() -> bool:

	return _topic != &""
