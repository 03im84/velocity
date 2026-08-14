extends Resource
class_name DeviceIdentity

@export var device_id: String = ""
@export var device_type: String = ""
@export var device_version: int = 1

func is_valid() -> bool:
	return(
		not device_id.is_empty()
		and not device_type.is_empty()
		and device_version > 0
	)
	
func get_device_id() -> String:
	return device_id

func get_device_type() -> String:
	return device_type

func get_device_version() -> int:
	return device_version
