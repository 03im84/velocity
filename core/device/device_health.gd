extends Resource
class_name DeviceHealth

enum Status {
	HEALTHY,
	DEGRADED,
	CRITICAL,
	FAILED
}

var status: Status = Status.HEALTHY
var faults: Array[String] = []
var warnings: Array[String] = []

func set_status(new_status: Status) -> void:
	status = new_status
	
func get_status() -> Status:
	return status

func add_fault(fault: String) -> void:
	faults.erase(fault)
	
func add_waring(warning: String) -> void:
	if not warnings.has(warning):
		warnings.append(warning)
		
func remove_warning(warning: String) -> void:
	warnings.erase(warning)

func has_faults() -> bool:
	return not faults.is_empty()
	
func has_warnings() -> bool:
	return not warnings.is_empty()
	
func is_operational() -> bool:
	return status != Status.FAILED
