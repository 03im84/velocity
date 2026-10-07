extends RefCounted
class_name DelayedScalarSinkAdapter


## DelayedScalarSinkAdapter
##
## Adapter genérico que difiere comandos escalares finitos mediante un
## BoundedLatencyBuffer y los entrega a un Callable de dos argumentos:
## value y conceptual application timestamp.
##
## No conoce force/torque semantics, RigidBody3D, RuntimeUnit o SceneTree.
## Vehicle Environment and Realism Addendum.


class ScalarCommand:
	extends RefCounted

	var value: float
	var capture_timestamp: float
	var application_timestamp: float

	func _init(
		p_value: float,
		p_capture_timestamp: float,
		p_application_timestamp: float
	) -> void:
		value = p_value
		capture_timestamp = p_capture_timestamp
		application_timestamp = p_application_timestamp


var _target_callable: Callable
var _latency_buffer: BoundedLatencyBuffer
var _has_flush_timestamp: bool = false
var _last_flush_timestamp: float = 0.0
var _last_flush_count: int = 0
var _total_applied_count: int = 0


func _init(
	target_callable: Callable,
	latency_buffer: BoundedLatencyBuffer
) -> void:

	_target_callable = target_callable
	_latency_buffer = latency_buffer


func get_pending_count() -> int:

	if (
		_latency_buffer == null
		or not is_instance_valid(_latency_buffer)
	):
		return 0

	return _latency_buffer.get_pending_count()


func get_max_pending_entries() -> int:

	if (
		_latency_buffer == null
		or not is_instance_valid(_latency_buffer)
	):
		return 0

	return _latency_buffer.get_max_entries()


func get_delay_seconds() -> float:

	if (
		_latency_buffer == null
		or not is_instance_valid(_latency_buffer)
	):
		return 0.0

	return _latency_buffer.get_delay_seconds()


func get_last_flush_count() -> int:

	return _last_flush_count


func get_total_applied_count() -> int:

	return _total_applied_count


func submit_scalar(
	value: float,
	capture_timestamp: float
) -> bool:

	if not is_configuration_valid():
		return false

	if (
		not is_finite(value)
		or not is_finite(capture_timestamp)
		or capture_timestamp < 0.0
	):
		return false

	var application_timestamp := (
		capture_timestamp + _latency_buffer.get_delay_seconds()
	)

	if not is_finite(application_timestamp):
		return false

	return _latency_buffer.enqueue(
		ScalarCommand.new(
			value,
			capture_timestamp,
			application_timestamp
		),
		capture_timestamp
	)


func flush(
	current_timestamp: float
) -> bool:

	_last_flush_count = 0

	if not is_configuration_valid():
		return false

	if (
		not is_finite(current_timestamp)
		or current_timestamp < 0.0
	):
		return false

	if (
		_has_flush_timestamp
		and current_timestamp < _last_flush_timestamp
	):
		return false

	_has_flush_timestamp = true
	_last_flush_timestamp = current_timestamp

	var release_budget := _latency_buffer.get_max_entries()

	while (
		release_budget > 0
		and _latency_buffer.has_ready(current_timestamp)
	):
		var ready_value: Variant = (
			_latency_buffer.dequeue_ready(current_timestamp)
		)
		release_budget -= 1

		if not (ready_value is ScalarCommand):
			return false

		var command: ScalarCommand = ready_value
		var accepted_value: Variant = _target_callable.call(
			command.value,
			command.application_timestamp
		)

		if typeof(accepted_value) != TYPE_BOOL:
			return false

		if not bool(accepted_value):
			return false

		_last_flush_count += 1
		_total_applied_count += 1

	return true


func clear() -> void:

	if (
		_latency_buffer != null
		and is_instance_valid(_latency_buffer)
	):
		_latency_buffer.clear()

	_has_flush_timestamp = false
	_last_flush_timestamp = 0.0
	_last_flush_count = 0
	_total_applied_count = 0


func is_configuration_valid() -> bool:

	return (
		_target_callable.is_valid()
		and _target_callable.get_argument_count() == 2
		and _latency_buffer != null
		and is_instance_valid(_latency_buffer)
		and _latency_buffer.is_valid()
	)
