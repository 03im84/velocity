extends Resource
class_name BusMessage


@export var source_id: String = ""
@export var topic: String = ""
@export var timestamp: float = 0.0
@export var data: Dictionary = {}


func is_valid() -> bool:
	return (
		not source_id.is_empty()
		and not topic.is_empty()
	)


func set_data(new_data: Dictionary) -> void:
	data = new_data


func get_data() -> Dictionary:
	return data
