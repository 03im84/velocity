extends Node


## VehicleControlRouterRuntimeUnitTest
##
## Cubre validation, lifecycle, exact routing, timestamp/source preservation,
## message safety, ordered publication failure y shutdown.


class RecordingRejectBus:
	extends DeviceBus

	var rejected_topic: StringName = &""
	var accepted_topics: Array[StringName] = []

	func publish(
		topic: StringName,
		_message: Variant
	) -> bool:
		if topic == rejected_topic:
			return false

		accepted_topics.append(topic)
		return true


var _checks: int = 0
var _failures: int = 0
var _propulsion_messages: Array[BusMessage] = []
var _steering_messages: Array[BusMessage] = []
var _brake_messages: Array[BusMessage] = []
var _publication_order: Array[StringName] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("VehicleControlRouterRuntimeUnitTest")
	print("========================================")

	_test_validation()
	_test_lifecycle_and_endpoint()
	_test_successful_routing()
	_test_full_brake_routing()
	_test_message_validation()
	_test_publication_failure()
	_test_shutdown()

	_finish()


func _test_validation() -> void:

	var policy := PropulsionIntentPolicy.new()
	var unit := VehicleControlRouterRuntimeUnit.new(
		"router",
		_configuration("router"),
		policy
	)

	_expect(
		unit.is_valid(),
		"VCR-U01: exact Router Unit is valid"
	)
	_expect(
		unit.get_propulsion_intent_policy() == policy,
		"VCR-U01: exact BORROWED policy is preserved"
	)
	_expect(
		not VehicleControlRouterRuntimeUnit.new(
			"",
			_configuration("router"),
			policy
		).is_valid(),
		"VCR-U01: empty Device ID is invalid"
	)
	_expect(
		not VehicleControlRouterRuntimeUnit.new(
			"other",
			_configuration("router"),
			policy
		).is_valid(),
		"VCR-U01: Configuration identity mismatch is invalid"
	)
	_expect(
		not VehicleControlRouterRuntimeUnit.new(
			"missing_policy",
			_configuration("missing_policy"),
			null
		).is_valid(),
		"VCR-U01: missing policy is invalid"
	)

	var unsupported_capabilities: Array[String] = [
		"vehicle_physics",
	]

	_expect(
		not VehicleControlRouterRuntimeUnit.new(
			"unsupported",
			_configuration(
				"unsupported",
				unsupported_capabilities
			),
			policy
		).is_valid(),
		"VCR-U01: unsupported Configuration is rejected"
	)


func _test_lifecycle_and_endpoint() -> void:

	var unit := _unit("lifecycle_router")
	var endpoint := unit.get_runtime_input_endpoint(
		VehicleControlRouterRuntimeUnit.INPUT_PORT_ID
	)

	_expect(
		unit.get_state()
		== VehicleControlRouterRuntimeUnit.State.CREATED,
		"VCR-U02: Unit starts in CREATED"
	)
	_expect(
		endpoint.is_valid()
		and not unit.get_runtime_input_endpoint(&"").is_valid()
		and not unit.get_runtime_input_endpoint(
			&"in.steering_command"
		).is_valid(),
		"VCR-U02: only exact vehicle control endpoint is exposed"
	)
	_expect_code(
		unit.runtime_set_ready(),
		&"vehicle_control_router_state_invalid",
		"VCR-U02: ready before initialize"
	)
	_expect_code(
		unit.runtime_initialize(null),
		&"vehicle_control_router_bus_missing",
		"VCR-U02: initialize requires DeviceBus"
	)
	_expect(
		unit.runtime_initialize(DeviceBus.new()).is_empty()
		and unit.get_state()
		== VehicleControlRouterRuntimeUnit.State.INITIALIZED,
		"VCR-U02: initialize enters INITIALIZED"
	)
	_expect_code(
		unit.runtime_initialize(DeviceBus.new()),
		&"vehicle_control_router_state_invalid",
		"VCR-U02: repeated initialize"
	)
	_expect(
		unit.runtime_set_ready().is_empty()
		and unit.get_state()
		== VehicleControlRouterRuntimeUnit.State.READY,
		"VCR-U02: set_ready enters READY"
	)
	_expect(
		unit.runtime_start().is_empty()
		and unit.get_state()
		== VehicleControlRouterRuntimeUnit.State.RUNNING,
		"VCR-U02: start enters RUNNING"
	)


func _test_successful_routing() -> void:

	_clear_messages()
	var bus := _observed_bus()
	var unit := _running_unit("routing_router", bus)
	var endpoint := unit.get_runtime_input_endpoint(
		VehicleControlRouterRuntimeUnit.INPUT_PORT_ID
	)
	endpoint.call(_message(1.0, -0.5, 0.25, 10.0))

	_expect(
		_propulsion_messages.size() == 1
		and _steering_messages.size() == 1
		and _brake_messages.size() == 1,
		"VCR-U03: one input publishes exactly three Commands"
	)
	_expect(
		_publication_order == [
			BusTopics.PROPULSION_COMMAND,
			BusTopics.STEERING_COMMAND,
			BusTopics.BRAKE_COMMAND,
		],
		"VCR-U03: publication order is Propulsion, Steering, Brake"
	)

	var propulsion_message := _propulsion_messages[0]
	var steering_message := _steering_messages[0]
	var brake_message := _brake_messages[0]

	_expect(
		propulsion_message.get_source_id() == "routing_router"
		and steering_message.get_source_id() == "routing_router"
		and brake_message.get_source_id() == "routing_router",
		"VCR-U03: all outputs use Router source ID"
	)
	_expect(
		propulsion_message.get_timestamp() == 10.0
		and steering_message.get_timestamp() == 10.0
		and brake_message.get_timestamp() == 10.0,
		"VCR-U03: all envelopes preserve authoritative timestamp"
	)
	_expect(
		propulsion_message.get_payload() is PropulsionCommand
		and steering_message.get_payload() is SteeringCommand
		and brake_message.get_payload() is BrakeCommand,
		"VCR-U03: outputs contain exact specialized payload types"
	)

	var propulsion: PropulsionCommand = propulsion_message.get_payload()
	var steering: SteeringCommand = steering_message.get_payload()
	var brake: BrakeCommand = brake_message.get_payload()

	_expect(
		propulsion.get_normalized_thrust() == 0.75
		and steering.get_normalized_yaw() == -0.5
		and brake.get_normalized_brake() == 0.25,
		"VCR-U03: policy and direct mappings preserve intent"
	)
	_expect(
		propulsion.get_timestamp() == 10.0
		and steering.get_timestamp() == 10.0
		and brake.get_timestamp() == 10.0,
		"VCR-U03: specialized Commands share input timestamp"
	)
	_expect(
		unit.has_routing_result()
		and unit.get_last_propulsion_command() == propulsion
		and unit.get_last_steering_command() == steering
		and unit.get_last_brake_command() == brake
		and unit.get_last_routing_report().is_empty(),
		"VCR-U03: successful routing result is observable"
	)


func _test_full_brake_routing() -> void:

	_clear_messages()
	var bus := _observed_bus()
	var unit := _running_unit("brake_router", bus)
	var endpoint := unit.get_runtime_input_endpoint(
		VehicleControlRouterRuntimeUnit.INPUT_PORT_ID
	)
	endpoint.call(_message(-1.0, 0.75, 1.0, 20.0))
	var propulsion: PropulsionCommand = (
		_propulsion_messages[0].get_payload()
	)
	var steering: SteeringCommand = (
		_steering_messages[0].get_payload()
	)
	var brake: BrakeCommand = _brake_messages[0].get_payload()

	_expect(
		propulsion.get_normalized_thrust() == 0.0,
		"VCR-U04: full brake suppresses reverse propulsion intent"
	)
	_expect(
		steering.get_normalized_yaw() == 0.75
		and brake.get_normalized_brake() == 1.0,
		"VCR-U04: Steering and Brake remain independent outputs"
	)


func _test_message_validation() -> void:

	_clear_messages()
	var bus := _observed_bus()
	var unit := _running_unit("message_router", bus)
	var endpoint := unit.get_runtime_input_endpoint(
		VehicleControlRouterRuntimeUnit.INPUT_PORT_ID
	)

	endpoint.call("not a message")
	_expect_last_code(
		unit,
		&"vehicle_control_router_message_invalid",
		"VCR-U05: non-message value"
	)
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.STEERING_COMMAND,
			1.0,
			_control(0.0, 0.0, 0.0, 1.0)
		)
	)
	_expect_last_code(
		unit,
		&"vehicle_control_router_topic_mismatch",
		"VCR-U05: wrong Topic"
	)
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.VEHICLE_CONTROL_COMMAND,
			-1.0,
			_control(0.0, 0.0, 0.0, 0.0)
		)
	)
	_expect_last_code(
		unit,
		&"vehicle_control_router_timestamp_invalid",
		"VCR-U05: invalid envelope timestamp"
	)
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.VEHICLE_CONTROL_COMMAND,
			1.0,
			RefCounted.new()
		)
	)
	_expect_last_code(
		unit,
		&"vehicle_control_router_payload_invalid",
		"VCR-U05: wrong payload type"
	)
	endpoint.call(_message(2.0, 0.0, 0.0, 2.0))
	_expect_last_code(
		unit,
		&"vehicle_control_router_payload_invalid",
		"VCR-U05: invalid VehicleControlCommand"
	)
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.VEHICLE_CONTROL_COMMAND,
			3.0,
			_control(0.0, 0.0, 0.0, 2.9)
		)
	)
	_expect_last_code(
		unit,
		&"vehicle_control_router_timestamp_mismatch",
		"VCR-U05: payload and envelope timestamp mismatch"
	)
	_expect(
		_propulsion_messages.is_empty()
		and _steering_messages.is_empty()
		and _brake_messages.is_empty(),
		"VCR-U05: rejected inputs publish no specialized Commands"
	)


func _test_publication_failure() -> void:

	var bus := RecordingRejectBus.new()
	bus.rejected_topic = BusTopics.STEERING_COMMAND
	var unit := _running_unit("failure_router", bus)
	var endpoint := unit.get_runtime_input_endpoint(
		VehicleControlRouterRuntimeUnit.INPUT_PORT_ID
	)
	endpoint.call(_message(0.5, 0.5, 0.0, 1.0))

	_expect(
		bus.accepted_topics == [BusTopics.PROPULSION_COMMAND],
		"VCR-U06: publication stops after first rejected Topic"
	)
	_expect_last_code(
		unit,
		&"vehicle_control_router_publish_failed",
		"VCR-U06: rejected publication is observable"
	)
	_expect(
		unit.get_last_propulsion_command() == null
		and unit.get_last_steering_command() == null
		and unit.get_last_brake_command() == null,
		"VCR-U06: partial publication is not reported as success"
	)


func _test_shutdown() -> void:

	var policy := PropulsionIntentPolicy.new()
	var unit := VehicleControlRouterRuntimeUnit.new(
		"shutdown_router",
		_configuration("shutdown_router"),
		policy
	)
	var bus := RecordingRejectBus.new()
	unit.runtime_initialize(bus)
	unit.runtime_set_ready()
	unit.runtime_start()
	var endpoint := unit.get_runtime_input_endpoint(
		VehicleControlRouterRuntimeUnit.INPUT_PORT_ID
	)

	_expect(
		unit.runtime_shutdown().is_empty()
		and unit.get_state()
		== VehicleControlRouterRuntimeUnit.State.SHUTDOWN,
		"VCR-U07: shutdown enters SHUTDOWN"
	)
	_expect(
		unit.runtime_shutdown().is_empty(),
		"VCR-U07: repeated shutdown is idempotent"
	)
	endpoint.call(_message(1.0, 1.0, 0.0, 2.0))
	_expect(
		bus.accepted_topics.is_empty(),
		"VCR-U07: post-shutdown input never publishes"
	)
	_expect_last_code(
		unit,
		&"vehicle_control_router_state_invalid",
		"VCR-U07: post-shutdown routing is observable"
	)
	_expect(
		is_instance_valid(policy)
		and unit.get_propulsion_intent_policy() == policy,
		"VCR-U07: BORROWED policy remains alive"
	)


func _configuration(
	device_id: String,
	capabilities: Array[String] = [
		"vehicle_control_routing",
	]
) -> DeviceConfiguration:

	var publishes: Array[StringName] = [
		BusTopics.PROPULSION_COMMAND,
		BusTopics.STEERING_COMMAND,
		BusTopics.BRAKE_COMMAND,
	]
	var subscribes: Array[StringName] = [
		BusTopics.VEHICLE_CONTROL_COMMAND,
	]
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName("test.vehicle_control.router." + device_id),
		1,
		device_id,
		VehicleControlRouterRuntimeUnit.PROFILE_ID,
		VehicleControlRouterRuntimeUnit.PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _unit(
	device_id: String
) -> VehicleControlRouterRuntimeUnit:

	return VehicleControlRouterRuntimeUnit.new(
		device_id,
		_configuration(device_id),
		PropulsionIntentPolicy.new()
	)


func _running_unit(
	device_id: String,
	bus: DeviceBus
) -> VehicleControlRouterRuntimeUnit:

	var unit := _unit(device_id)
	unit.runtime_initialize(bus)
	unit.runtime_set_ready()
	unit.runtime_start()
	return unit


func _observed_bus() -> DeviceBus:

	var bus := DeviceBus.new()
	bus.subscribe(BusTopics.PROPULSION_COMMAND, _on_propulsion)
	bus.subscribe(BusTopics.STEERING_COMMAND, _on_steering)
	bus.subscribe(BusTopics.BRAKE_COMMAND, _on_brake)
	return bus


func _control(
	throttle: float,
	steering: float,
	brake: float,
	timestamp: float
) -> VehicleControlCommand:

	return VehicleControlCommand.new(
		throttle,
		steering,
		brake,
		timestamp
	)


func _message(
	throttle: float,
	steering: float,
	brake: float,
	timestamp: float
) -> BusMessage:

	return BusMessage.new(
		"input_source",
		BusTopics.VEHICLE_CONTROL_COMMAND,
		timestamp,
		_control(throttle, steering, brake, timestamp)
	)


func _on_propulsion(message: BusMessage) -> void:

	_propulsion_messages.append(message)
	_publication_order.append(message.get_topic())


func _on_steering(message: BusMessage) -> void:

	_steering_messages.append(message)
	_publication_order.append(message.get_topic())


func _on_brake(message: BusMessage) -> void:

	_brake_messages.append(message)
	_publication_order.append(message.get_topic())


func _clear_messages() -> void:

	_propulsion_messages.clear()
	_steering_messages.clear()
	_brake_messages.clear()
	_publication_order.clear()


func _expect_last_code(
	unit: VehicleControlRouterRuntimeUnit,
	code: StringName,
	description: String
) -> void:

	_expect(
		_report_has_code(unit.get_last_routing_report(), code),
		description + " reports " + String(code)
	)


func _expect_code(
	report: ValidationReport,
	code: StringName,
	description: String
) -> void:

	_expect(
		_report_has_code(report, code),
		description + " reports " + String(code)
	)


func _report_has_code(
	report: ValidationReport,
	code: StringName
) -> bool:

	if report == null:
		return false

	for issue: ValidationIssue in report.get_issues():
		if issue.get_code() == code:
			return true

	return false


func _expect(
	condition: bool,
	description: String
) -> void:

	_checks += 1

	if condition:
		print("[PASS] ", description)
		return

	_failures += 1
	push_error("[FAIL] " + description)


func _finish() -> void:

	_clear_messages()
	print("----------------------------------------")
	print("Checks: ", _checks)
	print("Failures: ", _failures)

	if _failures == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")

	print("========================================")
	print("")
	get_tree().quit(_failures)
