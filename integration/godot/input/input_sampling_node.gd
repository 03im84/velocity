extends Node
class_name InputSamplingNode

var _runtime_unit: Object
var _sampling_enabled: bool = false

func configure(runtime_unit: Object) -> bool:
	if _runtime_unit != null or runtime_unit == null:
		return false
	if not runtime_unit.has_method(&"sample_and_publish"):
		return false
	_runtime_unit = runtime_unit
	return true

func set_sampling_enabled(enabled: bool) -> bool:
	if _runtime_unit == null or not is_instance_valid(_runtime_unit):
		return false
	_sampling_enabled = enabled
	return true

func is_sampling_enabled() -> bool:
	return _sampling_enabled

func _physics_process(_delta: float) -> void:
	if not _sampling_enabled:
		return
	if _runtime_unit == null or not is_instance_valid(_runtime_unit):
		_sampling_enabled = false
		return
	_runtime_unit.call(&"sample_and_publish", Time.get_ticks_msec() / 1000.0)
