extends Resource
class_name  DeviceState

var data_valid: bool = false
var last_update_time: float = 0.0

func invalidate() -> void:
	data_valid = false
	
func validate() -> void:
	data_valid = true
	
func update_timestamp(time:float) -> void:
	last_update_time = time

func is_valid() -> bool:
	return data_valid
	
func get_last_update_time() -> float:
	return last_update_time
