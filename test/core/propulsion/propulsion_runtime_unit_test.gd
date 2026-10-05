extends Node


## PropulsionRuntimeUnitTest
##
## Cubre validación, lifecycle, endpoint exacto, message contract,
## fuerza forward/reverse/neutral, sink failures, recovery y shutdown.


const ForceSink = preload(
	"res://test/core/propulsion/propulsion_test_force_sink.gd"
)


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("PropulsionRuntimeUnitTest")
	print("========================================")

	_test_validation()
	_test_lifecycle_and_endpoint()
	_test_force_output()
	_test_message_validation()
	_test_sink_failure_and_recovery()
	_test_shutdown()

	_finish()


func _test_validation() -> void:

	var model := LongitudinalPropulsionModel.new(1200.0, 300.0)
	var sink := ForceSink.new()
	var valid_unit := PropulsionRuntimeUnit.new(
		"propulsion_device",
		_configuration("propulsion_device"),
		model,
		sink
	)

	_expect(
		valid_unit.is_valid(),
		"PRU-U01: exact Unit is valid"
	)
	_expect(
		not PropulsionRuntimeUnit.new(
			"",
			_configuration("propulsion_device"),
			model,
			sink
		).is_valid(),
		"PRU-U01: empty Device ID is invalid"
	)
	_expect(
		not PropulsionRuntimeUnit.new(
			"other_device",
			_configuration("propulsion_device"),
			model,
			sink
		).is_valid(),
		"PRU-U01: Configuration identity mismatch is invalid"
	)
	_expect(
		not PropulsionRuntimeUnit.new(
			"invalid_model",
			_configuration("invalid_model"),
			LongitudinalPropulsionModel.new(-1.0, 300.0),
			sink
		).is_valid(),
		"PRU-U01: invalid model is rejected"
	)
	_expect(
		not PropulsionRuntimeUnit.new(
			"invalid_sink",
			_configuration("invalid_sink"),
			model,
			RefCounted.new()
		).is_valid(),
		"PRU-U01: incomplete sink behavior is rejected"
	)

	var unsupported_capabilities: Array[String] = [
		"radial_propulsion_force",
	]

	_expect(
		not PropulsionRuntimeUnit.new(
			"unsupported",
			_configuration(
				"unsupported",
				unsupported_capabilities
			),
			model,
			sink
		).is_valid(),
		"PRU-U01: unsupported Configuration is rejected"
	)


func _test_lifecycle_and_endpoint() -> void:

	var unit := _unit("lifecycle_device", ForceSink.new())
	var endpoint := unit.get_runtime_input_endpoint(
		PropulsionRuntimeUnit.INPUT_PORT_ID
	)

	_expect(
		unit.get_state() == PropulsionRuntimeUnit.State.CREATED,
		"PRU-U02: Unit starts in CREATED"
	)
	_expect(
		endpoint.is_valid()
		and not unit.get_runtime_input_endpoint(&"").is_valid()
		and not unit.get_runtime_input_endpoint(
			&"in.vehicle_control_command"
		).is_valid(),
		"PRU-U02: only exact propulsion input endpoint is exposed"
	)
	_expect_code(
		unit.runtime_set_ready(),
		&"propulsion_runtime_state_invalid",
		"PRU-U02: ready before initialize"
	)
	_expect_code(
		unit.runtime_initialize(null),
		&"propulsion_runtime_bus_missing",
		"PRU-U02: initialize requires DeviceBus"
	)

	var initialize_report := unit.runtime_initialize(DeviceBus.new())

	_expect(
		initialize_report.is_empty()
		and unit.get_state()
		== PropulsionRuntimeUnit.State.INITIALIZED,
		"PRU-U02: initialize enters INITIALIZED"
	)
	_expect_code(
		unit.runtime_initialize(DeviceBus.new()),
		&"propulsion_runtime_state_invalid",
		"PRU-U02: repeated initialize"
	)
	_expect(
		unit.runtime_set_ready().is_empty()
		and unit.get_state() == PropulsionRuntimeUnit.State.READY,
		"PRU-U02: set_ready enters READY"
	)
	_expect(
		unit.runtime_start().is_empty()
		and unit.get_state() == PropulsionRuntimeUnit.State.RUNNING,
		"PRU-U02: start enters RUNNING"
	)


func _test_force_output() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("force_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		PropulsionRuntimeUnit.INPUT_PORT_ID
	)

	endpoint.call(_message(PropulsionCommand.new(0.5, 10.0)))

	_expect(
		sink.apply_count == 1
		and sink.last_force_newtons == 600.0
		and sink.last_timestamp == 10.0,
		"PRU-U03: forward command reaches sink as bounded force"
	)
	_expect(
		unit.has_actuation_result()
		and unit.get_last_force_newtons() == 600.0
		and unit.get_last_actuation_report().is_empty(),
		"PRU-U03: forward success is observable"
	)

	endpoint.call(_message(PropulsionCommand.new(-1.0, 11.0)))

	_expect(
		sink.apply_count == 2
		and sink.last_force_newtons == -300.0,
		"PRU-U03: reverse command respects reverse limit"
	)
	_expect(
		unit.get_last_force_newtons() == -300.0
		and unit.get_last_actuation_report().is_empty(),
		"PRU-U03: reverse success replaces previous result"
	)

	endpoint.call(_message(PropulsionCommand.new(0.0, 12.0)))

	_expect(
		sink.apply_count == 3
		and sink.last_force_newtons == 0.0,
		"PRU-U03: neutral command produces explicit zero force"
	)


func _test_message_validation() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("message_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		PropulsionRuntimeUnit.INPUT_PORT_ID
	)

	endpoint.call("not a message")
	_expect_last_code(
		unit,
		&"propulsion_runtime_message_invalid",
		"PRU-U04: non-message payload"
	)

	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.VEHICLE_CONTROL_COMMAND,
			1.0,
			PropulsionCommand.new(0.5, 1.0)
		)
	)
	_expect_last_code(
		unit,
		&"propulsion_runtime_topic_mismatch",
		"PRU-U04: wrong Topic"
	)

	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.PROPULSION_COMMAND,
			-1.0,
			PropulsionCommand.new(0.5, 0.0)
		)
	)
	_expect_last_code(
		unit,
		&"propulsion_runtime_timestamp_invalid",
		"PRU-U04: invalid envelope timestamp"
	)

	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.PROPULSION_COMMAND,
			1.0,
			RefCounted.new()
		)
	)
	_expect_last_code(
		unit,
		&"propulsion_runtime_payload_invalid",
		"PRU-U04: wrong payload type"
	)

	endpoint.call(
		_message(PropulsionCommand.new(1.1, 1.0))
	)
	_expect_last_code(
		unit,
		&"propulsion_runtime_payload_invalid",
		"PRU-U04: invalid command"
	)

	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.PROPULSION_COMMAND,
			2.0,
			PropulsionCommand.new(0.5, 1.0)
		)
	)
	_expect_last_code(
		unit,
		&"propulsion_runtime_timestamp_mismatch",
		"PRU-U04: command and envelope timestamp mismatch"
	)
	_expect(
		sink.apply_count == 0,
		"PRU-U04: rejected messages never reach sink"
	)


func _test_sink_failure_and_recovery() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("sink_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		PropulsionRuntimeUnit.INPUT_PORT_ID
	)

	sink.result = false
	endpoint.call(_message(PropulsionCommand.new(0.5, 1.0)))
	_expect_last_code(
		unit,
		&"propulsion_runtime_sink_rejected",
		"PRU-U05: sink rejection"
	)
	_expect(
		unit.get_last_force_newtons() == 0.0,
		"PRU-U05: rejected sink output remains fail-neutral"
	)

	sink.result = "invalid"
	endpoint.call(_message(PropulsionCommand.new(0.5, 2.0)))
	_expect_last_code(
		unit,
		&"propulsion_runtime_sink_result_invalid",
		"PRU-U05: non-boolean sink result"
	)

	sink.result = true
	endpoint.call(_message(PropulsionCommand.new(0.25, 3.0)))
	_expect(
		sink.apply_count == 3
		and unit.get_last_force_newtons() == 300.0
		and unit.get_last_actuation_report().is_empty(),
		"PRU-U05: later valid command recovers observable state"
	)


func _test_shutdown() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("shutdown_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		PropulsionRuntimeUnit.INPUT_PORT_ID
	)
	var model := unit.get_model()

	_expect(
		unit.runtime_shutdown().is_empty()
		and unit.get_state() == PropulsionRuntimeUnit.State.SHUTDOWN,
		"PRU-U06: shutdown enters SHUTDOWN"
	)
	_expect(
		unit.runtime_shutdown().is_empty(),
		"PRU-U06: shutdown is idempotent"
	)

	endpoint.call(_message(PropulsionCommand.new(1.0, 5.0)))

	_expect(
		sink.apply_count == 0,
		"PRU-U06: command after shutdown never reaches sink"
	)
	_expect_last_code(
		unit,
		&"propulsion_runtime_state_invalid",
		"PRU-U06: post-shutdown actuation is observable"
	)
	_expect(
		is_instance_valid(model)
		and is_instance_valid(sink)
		and unit.get_model() == model
		and unit.get_force_sink() == sink,
		"PRU-U06: BORROWED model and sink remain alive"
	)


func _configuration(
	device_id: String,
	capabilities: Array[String] = [
		"longitudinal_propulsion_force",
	]
) -> DeviceConfiguration:

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = [
		BusTopics.PROPULSION_COMMAND,
	]
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName("test.propulsion." + device_id),
		1,
		device_id,
		PropulsionRuntimeUnit.PROFILE_ID,
		PropulsionRuntimeUnit.PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _unit(
	device_id: String,
	sink: Object
) -> PropulsionRuntimeUnit:

	return PropulsionRuntimeUnit.new(
		device_id,
		_configuration(device_id),
		LongitudinalPropulsionModel.new(1200.0, 300.0),
		sink
	)


func _running_unit(
	device_id: String,
	sink: Object
) -> PropulsionRuntimeUnit:

	var unit := _unit(device_id, sink)
	unit.runtime_initialize(DeviceBus.new())
	unit.runtime_set_ready()
	unit.runtime_start()
	return unit


func _message(
	command: PropulsionCommand
) -> BusMessage:

	return BusMessage.new(
		"propulsion_source",
		BusTopics.PROPULSION_COMMAND,
		command.get_timestamp(),
		command
	)


func _expect_last_code(
	unit: PropulsionRuntimeUnit,
	code: StringName,
	description: String
) -> void:

	_expect(
		_report_has_code(
			unit.get_last_actuation_report(),
			code
		),
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
