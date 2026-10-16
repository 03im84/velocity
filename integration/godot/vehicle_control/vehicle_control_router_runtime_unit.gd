extends RefCounted
class_name VehicleControlRouterRuntimeUnit


enum State {
	CREATED,
	INITIALIZED,
	READY,
	RUNNING,
	SHUTDOWN,
}


## VehicleControlRouterRuntimeUnit
##
## Managed controller que transforma VehicleControlCommand en Commands
## especializados y los publica en orden Propulsion, Steering, Brake.
##
## No calcula force/torque y no conoce sinks, motion sources o RigidBody3D.
## ADR-017 / Playable Vehicle Composition Design 1.1.


const PROFILE_ID: StringName = &"velocity.vehicle_control.router"
const PROFILE_VERSION: int = 1
const INPUT_PORT_ID: StringName = &"in.vehicle_control_command"


var _device_id: String
var _configuration: DeviceConfiguration
var _propulsion_intent_policy: PropulsionIntentPolicy
var _device_bus: DeviceBus
var _state: State = State.CREATED

var _has_routing_result: bool = false
var _last_propulsion_command: PropulsionCommand
var _last_steering_command: SteeringCommand
var _last_brake_command: BrakeCommand
var _last_routing_report: ValidationReport = ValidationReport.new()


func _init(
	device_id: String,
	configuration: DeviceConfiguration,
	propulsion_intent_policy: PropulsionIntentPolicy
) -> void:

	_device_id = device_id
	_configuration = configuration
	_propulsion_intent_policy = propulsion_intent_policy


func is_valid() -> bool:

	return (
		not _device_id.is_empty()
		and _configuration != null
		and _configuration.is_valid()
		and _configuration.get_device_id() == _device_id
		and _configuration_is_supported()
		and _propulsion_intent_policy != null
		and is_instance_valid(_propulsion_intent_policy)
	)


func get_state() -> State:

	return _state


func get_propulsion_intent_policy() -> PropulsionIntentPolicy:

	return _propulsion_intent_policy


func has_routing_result() -> bool:

	return _has_routing_result


func get_last_propulsion_command() -> PropulsionCommand:

	return _last_propulsion_command


func get_last_steering_command() -> SteeringCommand:

	return _last_steering_command


func get_last_brake_command() -> BrakeCommand:

	return _last_brake_command


func get_last_routing_report() -> ValidationReport:

	return _last_routing_report


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
			&"vehicle_control_router_unit_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Vehicle Control Router Runtime Unit is invalid.",
			&"runtime_unit"
		)
		return report

	if device_bus == null:
		_add_error(
			report,
			&"vehicle_control_router_bus_missing",
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

	return _receive_vehicle_control_message


func _receive_vehicle_control_message(
	message_value: Variant
) -> void:

	_begin_routing_result()

	if _state != State.RUNNING:
		_add_last_error(
			&"vehicle_control_router_state_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Vehicle Control Router state rejects routing.",
			&"state"
		)
		return

	if not is_valid() or _device_bus == null:
		_add_last_error(
			&"vehicle_control_router_unit_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Vehicle Control Router became invalid.",
			&"runtime_unit"
		)
		return

	if not (message_value is BusMessage):
		_add_last_error(
			&"vehicle_control_router_message_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"BusMessage is required.",
			&"message"
		)
		return

	var message: BusMessage = message_value

	if not message.is_valid():
		_add_last_error(
			&"vehicle_control_router_message_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"BusMessage is invalid.",
			&"message"
		)
		return

	if message.get_topic() != BusTopics.VEHICLE_CONTROL_COMMAND:
		_add_last_error(
			&"vehicle_control_router_topic_mismatch",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"BusMessage Topic is not vehicle_control_command.",
			&"topic"
		)
		return

	var message_timestamp := message.get_timestamp()

	if (
		not is_finite(message_timestamp)
		or message_timestamp < 0.0
	):
		_add_last_error(
			&"vehicle_control_router_timestamp_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"BusMessage timestamp is invalid.",
			&"timestamp"
		)
		return

	var payload_value: Variant = message.get_payload()

	if not (payload_value is VehicleControlCommand):
		_add_last_error(
			&"vehicle_control_router_payload_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"VehicleControlCommand payload is required.",
			&"payload"
		)
		return

	var control_command: VehicleControlCommand = payload_value

	if not control_command.is_valid():
		_add_last_error(
			&"vehicle_control_router_payload_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"VehicleControlCommand is invalid.",
			&"payload"
		)
		return

	if control_command.get_timestamp() != message_timestamp:
		_add_last_error(
			&"vehicle_control_router_timestamp_mismatch",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Command and BusMessage timestamps differ.",
			&"timestamp"
		)
		return

	var normalized_thrust := (
		_propulsion_intent_policy.calculate_normalized_thrust(
			control_command.get_throttle(),
			control_command.get_brake()
		)
	)

	if not _propulsion_intent_policy.is_normalized_thrust_valid(
		normalized_thrust
	):
		_add_last_error(
			&"vehicle_control_router_policy_output_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Propulsion Intent Policy output is invalid.",
			&"propulsion_intent_policy"
		)
		return

	var propulsion_command := PropulsionCommand.new(
		normalized_thrust,
		message_timestamp
	)
	var steering_command := SteeringCommand.new(
		control_command.get_steering(),
		message_timestamp
	)
	var brake_command := BrakeCommand.new(
		control_command.get_brake(),
		message_timestamp
	)

	if (
		not propulsion_command.is_valid()
		or not steering_command.is_valid()
		or not brake_command.is_valid()
	):
		_add_last_error(
			&"vehicle_control_router_command_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Specialized Command construction failed.",
			&"commands"
		)
		return

	var propulsion_message := _create_message(
		BusTopics.PROPULSION_COMMAND,
		message_timestamp,
		propulsion_command
	)
	var steering_message := _create_message(
		BusTopics.STEERING_COMMAND,
		message_timestamp,
		steering_command
	)
	var brake_message := _create_message(
		BusTopics.BRAKE_COMMAND,
		message_timestamp,
		brake_command
	)

	if not _publish_message(propulsion_message):
		return

	if not _publish_message(steering_message):
		return

	if not _publish_message(brake_message):
		return

	_last_propulsion_command = propulsion_command
	_last_steering_command = steering_command
	_last_brake_command = brake_command


func _create_message(
	topic: StringName,
	timestamp: float,
	payload: Variant
) -> BusMessage:

	return BusMessage.new(
		_device_id,
		topic,
		timestamp,
		payload
	)


func _publish_message(
	message: BusMessage
) -> bool:

	if message == null or not message.is_valid():
		_add_last_error(
			&"vehicle_control_router_message_creation_failed",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Specialized BusMessage construction failed.",
			&"message"
		)
		return false

	if not _device_bus.publish(message.get_topic(), message):
		_add_last_error(
			&"vehicle_control_router_publish_failed",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"DeviceBus rejected specialized publication.",
			message.get_topic()
		)
		return false

	return true


func _configuration_is_supported() -> bool:

	var expected_capabilities: Array[String] = [
		"vehicle_control_routing",
	]
	var expected_publishes: Array[StringName] = [
		BusTopics.PROPULSION_COMMAND,
		BusTopics.STEERING_COMMAND,
		BusTopics.BRAKE_COMMAND,
	]
	var expected_subscribes: Array[StringName] = [
		BusTopics.VEHICLE_CONTROL_COMMAND,
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


func _begin_routing_result() -> void:

	_has_routing_result = true
	_last_propulsion_command = null
	_last_steering_command = null
	_last_brake_command = null
	_last_routing_report = ValidationReport.new()


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
		&"vehicle_control_router_state_invalid",
		ValidationIssue.Severity.STRUCTURAL_ERROR,
		"Vehicle Control Router state rejects operation.",
		field
	)


func _add_last_error(
	code: StringName,
	severity: ValidationIssue.Severity,
	message: String,
	field: StringName
) -> void:

	_add_error(
		_last_routing_report,
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
