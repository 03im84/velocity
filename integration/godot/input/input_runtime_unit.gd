extends RefCounted
class_name InputRuntimeUnit


enum State {
	CREATED,
	INITIALIZED,
	READY,
	RUNNING,
	SHUTDOWN,
}


var _device_id: String
var _configuration: DeviceConfiguration
var _provider: Object
var _sampler: InputSamplingNode
var _device_bus: DeviceBus
var _state: State = State.CREATED


func _init(
	device_id: String,
	configuration: DeviceConfiguration,
	provider: Object,
	sampler: InputSamplingNode
) -> void:

	_device_id = device_id
	_configuration = configuration
	_provider = provider
	_sampler = sampler


func is_valid() -> bool:

	return (
		not _device_id.is_empty()
		and _configuration != null
		and _configuration.is_valid()
		and _configuration.get_device_id() == _device_id
		and _provider != null
		and is_instance_valid(_provider)
		and _provider.has_method(&"sample_intent")
		and _sampler != null
		and is_instance_valid(_sampler)
		and _configuration_is_supported()
	)


func get_state() -> State:

	return _state


func get_sampler() -> InputSamplingNode:

	return _sampler


func get_provider() -> Object:

	return _provider


func runtime_initialize(
	device_bus: DeviceBus
) -> ValidationReport:

	var report := ValidationReport.new()

	if _state != State.CREATED:
		_add_state_error(report, &"initialize")
		return report

	if not is_valid():
		_add_error(
			report,
			&"input_runtime_unit_invalid",
			"Input Runtime Unit is invalid.",
			&"runtime_unit"
		)
		return report

	if device_bus == null:
		_add_error(
			report,
			&"input_runtime_bus_missing",
			"DeviceBus is required.",
			&"device_bus"
		)
		return report

	if not _sampler.configure(self):
		_add_error(
			report,
			&"input_runtime_sampler_configuration_failed",
			"InputSamplingNode rejected Runtime Unit.",
			&"sampler"
		)
		return report

	_device_bus = device_bus
	_state = State.INITIALIZED
	return report


func runtime_set_ready(
) -> ValidationReport:

	return _transition(
		State.INITIALIZED,
		State.READY,
		&"set_ready"
	)


func runtime_start(
) -> ValidationReport:

	var report := ValidationReport.new()

	if _state != State.READY:
		_add_state_error(report, &"start")
		return report

	if not _sampler.set_sampling_enabled(true):
		_add_error(
			report,
			&"input_runtime_sampler_enable_failed",
			"InputSamplingNode could not be enabled.",
			&"sampler"
		)
		return report

	_state = State.RUNNING
	return report


func runtime_shutdown(
) -> ValidationReport:

	var report := ValidationReport.new()

	if _state == State.SHUTDOWN:
		return report

	if _sampler != null and is_instance_valid(_sampler):
		if _sampler.is_sampling_enabled():
			if not _sampler.set_sampling_enabled(false):
				_add_error(
					report,
					&"input_runtime_sampler_disable_failed",
					"InputSamplingNode could not be disabled.",
					&"sampler"
				)
				return report

	_device_bus = null
	_provider = null
	_state = State.SHUTDOWN
	return report


func sample_and_publish(
	timestamp: float
) -> void:

	if _state != State.RUNNING:
		return

	if _device_bus == null or _provider == null:
		return

	if not is_finite(timestamp) or timestamp < 0.0:
		return

	var sampled_value: Variant = _provider.call(&"sample_intent")

	if not (sampled_value is VehicleControlCommand):
		return

	var sampled: VehicleControlCommand = sampled_value

	if not sampled.is_valid():
		return

	var command := VehicleControlCommand.new(
		sampled.get_throttle(),
		sampled.get_steering(),
		sampled.get_brake(),
		timestamp
	)

	if not command.is_valid():
		return

	var message := BusMessage.new(
		_device_id,
		BusTopics.VEHICLE_CONTROL_COMMAND,
		timestamp,
		command
	)

	if message.is_valid():
		_device_bus.publish(
			BusTopics.VEHICLE_CONTROL_COMMAND,
			message
		)


func get_runtime_input_endpoint(
	_port_id: StringName
) -> Callable:

	return Callable()


func _configuration_is_supported() -> bool:

	var capabilities: Array[String] = [
		"vehicle_control_input",
	]
	var publishes: Array[StringName] = [
		BusTopics.VEHICLE_CONTROL_COMMAND,
	]
	var subscribes: Array[StringName] = []

	return (
		_configuration.get_enabled_capabilities() == capabilities
		and _configuration.get_enabled_publishes() == publishes
		and _configuration.get_enabled_subscribes() == subscribes
		and _configuration.get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION
	)


func _transition(
	expected: State,
	target: State,
	field: StringName
) -> ValidationReport:

	var report := ValidationReport.new()

	if _state != expected:
		_add_state_error(report, field)
		return report

	_state = target
	return report


func _add_state_error(
	report: ValidationReport,
	field: StringName
) -> void:

	_add_error(
		report,
		&"input_runtime_state_invalid",
		"Input Runtime state rejects operation.",
		field
	)


func _add_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			message,
			_device_id,
			field
		)
	)
