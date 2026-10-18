extends RefCounted
class_name BrakeRuntimeUnit


enum State {
	CREATED,
	INITIALIZED,
	READY,
	RUNNING,
	SHUTDOWN,
}


## BrakeRuntimeUnit
##
## Managed actuator que convierte BrakeCommand y signed longitudinal speed
## en force acotado mediante LongitudinalBrakeModel y BrakeForceSink BORROWED.
##
## No conoce RigidBody3D, ejes espaciales o Vehicle Control routing.
## ADR-017 / Playable Vehicle Composition Design 1.1.


const PROFILE_ID: StringName = &"velocity.brake.longitudinal"
const PROFILE_VERSION: int = 1
const INPUT_PORT_ID: StringName = &"in.brake_command"


var _device_id: String
var _configuration: DeviceConfiguration
var _model: LongitudinalBrakeModel
var _longitudinal_motion_source: Object
var _force_sink: Object
var _device_bus: DeviceBus
var _state: State = State.CREATED

var _has_actuation_result: bool = false
var _last_longitudinal_speed_meters_per_second: float = 0.0
var _last_force_newtons: float = 0.0
var _last_actuation_report: ValidationReport = ValidationReport.new()


func _init(
	device_id: String,
	configuration: DeviceConfiguration,
	model: LongitudinalBrakeModel,
	longitudinal_motion_source: Object,
	force_sink: Object
) -> void:

	_device_id = device_id
	_configuration = configuration
	_model = model
	_longitudinal_motion_source = longitudinal_motion_source
	_force_sink = force_sink


func is_valid() -> bool:

	return (
		not _device_id.is_empty()
		and _configuration != null
		and _configuration.is_valid()
		and _configuration.get_device_id() == _device_id
		and _configuration_is_supported()
		and _model != null
		and is_instance_valid(_model)
		and _model.is_valid()
		and _longitudinal_motion_source != null
		and is_instance_valid(_longitudinal_motion_source)
		and _longitudinal_motion_source.has_method(
			&"get_longitudinal_speed_meters_per_second"
		)
		and _force_sink != null
		and is_instance_valid(_force_sink)
		and _force_sink.has_method(&"apply_brake_force")
	)


func get_state() -> State:

	return _state


func get_model() -> LongitudinalBrakeModel:

	return _model


func get_longitudinal_motion_source() -> Object:

	return _longitudinal_motion_source


func get_force_sink() -> Object:

	return _force_sink


func has_actuation_result() -> bool:

	return _has_actuation_result


func get_last_longitudinal_speed_meters_per_second() -> float:

	return _last_longitudinal_speed_meters_per_second


func get_last_force_newtons() -> float:

	return _last_force_newtons


func get_last_actuation_report() -> ValidationReport:

	return _last_actuation_report


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
			&"brake_runtime_unit_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Brake Runtime Unit is invalid.",
			&"runtime_unit"
		)
		return report

	if device_bus == null:
		_add_error(
			report,
			&"brake_runtime_bus_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"DeviceBus is required.",
			&"device_bus"
		)
		return report

	_device_bus = device_bus
	_state = State.INITIALIZED
	return report


func runtime_set_ready() -> ValidationReport:

	return _transition(
		State.INITIALIZED,
		State.READY,
		&"set_ready"
	)


func runtime_start() -> ValidationReport:

	return _transition(
		State.READY,
		State.RUNNING,
		&"start"
	)


func runtime_shutdown() -> ValidationReport:

	var report := ValidationReport.new()

	if _state == State.SHUTDOWN:
		return report

	_device_bus = null
	_state = State.SHUTDOWN
	return report


func get_runtime_input_endpoint(
	port_id: StringName
) -> Callable:

	if port_id != INPUT_PORT_ID:
		return Callable()

	return _receive_brake_message


func _receive_brake_message(
	message_value: Variant
) -> void:

	_begin_actuation_result()

	if _state != State.RUNNING:
		_add_last_error(
			&"brake_runtime_state_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Brake Runtime state rejects actuation.",
			&"state"
		)
		return

	if not is_valid():
		_add_last_error(
			&"brake_runtime_unit_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Brake Runtime Unit became invalid.",
			&"runtime_unit"
		)
		return

	if not (message_value is BusMessage):
		_add_last_error(
			&"brake_runtime_message_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"BusMessage is required.",
			&"message"
		)
		return

	var message: BusMessage = message_value

	if not message.is_valid():
		_add_last_error(
			&"brake_runtime_message_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"BusMessage is invalid.",
			&"message"
		)
		return

	if message.get_topic() != BusTopics.BRAKE_COMMAND:
		_add_last_error(
			&"brake_runtime_topic_mismatch",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"BusMessage Topic is not brake_command.",
			&"topic"
		)
		return

	var message_timestamp := message.get_timestamp()

	if (
		not is_finite(message_timestamp)
		or message_timestamp < 0.0
	):
		_add_last_error(
			&"brake_runtime_timestamp_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"BusMessage timestamp is invalid.",
			&"timestamp"
		)
		return

	var payload_value: Variant = message.get_payload()

	if not (payload_value is BrakeCommand):
		_add_last_error(
			&"brake_runtime_payload_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"BrakeCommand payload is required.",
			&"payload"
		)
		return

	var command: BrakeCommand = payload_value

	if not command.is_valid():
		_add_last_error(
			&"brake_runtime_payload_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"BrakeCommand payload is invalid.",
			&"payload"
		)
		return

	if command.get_timestamp() != message_timestamp:
		_add_last_error(
			&"brake_runtime_timestamp_mismatch",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Command and BusMessage timestamps differ.",
			&"timestamp"
		)
		return

	var speed_value: Variant = _longitudinal_motion_source.call(
		&"get_longitudinal_speed_meters_per_second"
	)

	if not _variant_is_number(speed_value):
		_add_last_error(
			&"brake_runtime_motion_result_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Longitudinal Motion Source returned a non-numeric result.",
			&"longitudinal_motion_source"
		)
		return

	var longitudinal_speed := float(speed_value)

	if not is_finite(longitudinal_speed):
		_add_last_error(
			&"brake_runtime_longitudinal_speed_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Longitudinal speed is not finite.",
			&"longitudinal_speed"
		)
		return

	var force := _model.calculate_brake_force_newtons(
		command.get_normalized_brake(),
		longitudinal_speed
	)

	if not is_finite(force):
		_add_last_error(
			&"brake_runtime_force_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Calculated brake force is not finite.",
			&"force_newtons"
		)
		return

	if not _model.is_force_within_limits(force):
		_add_last_error(
			&"brake_runtime_force_out_of_bounds",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Calculated brake force exceeds model limits.",
			&"force_newtons"
		)
		return

	var accepted_value: Variant = _force_sink.call(
		&"apply_brake_force",
		force,
		message_timestamp
	)

	if typeof(accepted_value) != TYPE_BOOL:
		_add_last_error(
			&"brake_runtime_sink_result_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Brake Force Sink returned a non-boolean result.",
			&"brake_force_sink"
		)
		return

	if not bool(accepted_value):
		_add_last_error(
			&"brake_runtime_sink_rejected",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Brake Force Sink rejected force output.",
			&"brake_force_sink"
		)
		return

	_last_longitudinal_speed_meters_per_second = longitudinal_speed
	_last_force_newtons = force


func _configuration_is_supported() -> bool:

	var expected_capabilities: Array[String] = [
		"active_longitudinal_braking",
	]
	var expected_publishes: Array[StringName] = []
	var expected_subscribes: Array[StringName] = [
		BusTopics.BRAKE_COMMAND,
	]

	return (
		_configuration.get_profile_id() == PROFILE_ID
		and _configuration.get_profile_version() == PROFILE_VERSION
		and _configuration.get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION
		and _configuration.get_enabled_capabilities()
		== expected_capabilities
		and _configuration.get_enabled_publishes()
		== expected_publishes
		and _configuration.get_enabled_subscribes()
		== expected_subscribes
	)


func _begin_actuation_result() -> void:

	_has_actuation_result = true
	_last_longitudinal_speed_meters_per_second = 0.0
	_last_force_newtons = 0.0
	_last_actuation_report = ValidationReport.new()


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
		&"brake_runtime_state_invalid",
		ValidationIssue.Severity.STRUCTURAL_ERROR,
		"Brake Runtime state rejects operation.",
		field
	)


func _add_last_error(
	code: StringName,
	severity: ValidationIssue.Severity,
	message: String,
	field: StringName
) -> void:

	_add_error(
		_last_actuation_report,
		code,
		severity,
		message,
		field
	)


func _add_error(
	report: ValidationReport,
	code: StringName,
	severity: ValidationIssue.Severity,
	message: String,
	field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			severity,
			message,
			_device_id,
			field
		)
	)


func _variant_is_number(
	value: Variant
) -> bool:

	return (
		typeof(value) == TYPE_FLOAT
		or typeof(value) == TYPE_INT
	)
