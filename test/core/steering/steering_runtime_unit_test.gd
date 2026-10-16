extends Node


## SteeringRuntimeUnitTest
##
## Cubre validation, lifecycle, model/source/sink composition, message
## safety, dynamic dependency failures, recovery y shutdown.


const MotionSource = preload(
	"res://test/core/steering/steering_test_motion_source.gd"
)
const TorqueSink = preload(
	"res://test/core/steering/steering_test_torque_sink.gd"
)


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("SteeringRuntimeUnitTest")
	print("========================================")

	_test_validation()
	_test_lifecycle_and_endpoint()
	_test_actuation_pipeline()
	_test_message_validation()
	_test_motion_source_failure_and_recovery()
	_test_sink_failure_and_recovery()
	_test_shutdown()

	_finish()


func _test_validation() -> void:

	var model := _model()
	var source := MotionSource.new()
	var sink := TorqueSink.new()
	var valid_unit := SteeringRuntimeUnit.new(
		"steering_device",
		_configuration("steering_device"),
		model,
		source,
		sink
	)

	_expect(valid_unit.is_valid(), "SRU-U01: exact Unit is valid")
	_expect(
		valid_unit.get_model() == model
		and valid_unit.get_yaw_motion_source() == source
		and valid_unit.get_torque_sink() == sink,
		"SRU-U01: exact BORROWED dependencies are preserved"
	)
	_expect(
		not SteeringRuntimeUnit.new(
			"",
			_configuration("steering_device"),
			model,
			source,
			sink
		).is_valid(),
		"SRU-U01: empty Device ID is invalid"
	)
	_expect(
		not SteeringRuntimeUnit.new(
			"other",
			_configuration("steering_device"),
			model,
			source,
			sink
		).is_valid(),
		"SRU-U01: Configuration identity mismatch is invalid"
	)
	_expect(
		not SteeringRuntimeUnit.new(
			"invalid_model",
			_configuration("invalid_model"),
			YawSteeringModel.new(-1.0, 1.0, 1.0),
			source,
			sink
		).is_valid(),
		"SRU-U01: invalid model is rejected"
	)
	_expect(
		not SteeringRuntimeUnit.new(
			"invalid_source",
			_configuration("invalid_source"),
			model,
			RefCounted.new(),
			sink
		).is_valid(),
		"SRU-U01: incomplete motion source is rejected"
	)
	_expect(
		not SteeringRuntimeUnit.new(
			"invalid_sink",
			_configuration("invalid_sink"),
			model,
			source,
			RefCounted.new()
		).is_valid(),
		"SRU-U01: incomplete torque sink is rejected"
	)


func _test_lifecycle_and_endpoint() -> void:

	var unit := _unit("lifecycle_device", MotionSource.new(), TorqueSink.new())
	var endpoint := unit.get_runtime_input_endpoint(
		SteeringRuntimeUnit.INPUT_PORT_ID
	)

	_expect(
		unit.get_state() == SteeringRuntimeUnit.State.CREATED,
		"SRU-U02: Unit starts in CREATED"
	)
	_expect(
		endpoint.is_valid()
		and not unit.get_runtime_input_endpoint(&"").is_valid()
		and not unit.get_runtime_input_endpoint(
			&"in.brake_command"
		).is_valid(),
		"SRU-U02: only exact Steering endpoint is exposed"
	)
	_expect_code(
		unit.runtime_set_ready(),
		&"steering_runtime_state_invalid",
		"SRU-U02: ready before initialize"
	)
	_expect_code(
		unit.runtime_initialize(null),
		&"steering_runtime_bus_missing",
		"SRU-U02: initialize requires DeviceBus"
	)
	_expect(
		unit.runtime_initialize(DeviceBus.new()).is_empty()
		and unit.get_state() == SteeringRuntimeUnit.State.INITIALIZED,
		"SRU-U02: initialize enters INITIALIZED"
	)
	_expect_code(
		unit.runtime_initialize(DeviceBus.new()),
		&"steering_runtime_state_invalid",
		"SRU-U02: repeated initialize"
	)
	_expect(
		unit.runtime_set_ready().is_empty()
		and unit.get_state() == SteeringRuntimeUnit.State.READY,
		"SRU-U02: set_ready enters READY"
	)
	_expect(
		unit.runtime_start().is_empty()
		and unit.get_state() == SteeringRuntimeUnit.State.RUNNING,
		"SRU-U02: start enters RUNNING"
	)


func _test_actuation_pipeline() -> void:

	var source := MotionSource.new()
	var sink := TorqueSink.new()
	var unit := _running_unit("actuation_device", source, sink)
	var endpoint := unit.get_runtime_input_endpoint(
		SteeringRuntimeUnit.INPUT_PORT_ID
	)

	source.result = 0.0
	endpoint.call(_message(1.0, 1.0))
	_expect(
		sink.apply_count == 1
		and sink.last_torque_newton_meters == 100.0
		and sink.last_timestamp == 1.0,
		"SRU-U03: command and zero rate reach sink"
	)

	source.result = 1.0
	endpoint.call(_message(1.0, 2.0))
	_expect(
		sink.apply_count == 2
		and sink.last_torque_newton_meters == 90.0,
		"SRU-U03: observed yaw rate contributes damping"
	)

	source.result = 2.0
	endpoint.call(_message(1.0, 3.0))
	_expect(
		sink.apply_count == 3
		and sink.last_torque_newton_meters == -20.0,
		"SRU-U03: at-limit same-direction command is suppressed"
	)
	_expect(
		unit.has_actuation_result()
		and unit.get_last_yaw_rate_radians_per_second() == 2.0
		and unit.get_last_torque_newton_meters() == -20.0
		and unit.get_last_actuation_report().is_empty(),
		"SRU-U03: latest successful actuation is observable"
	)


func _test_message_validation() -> void:

	var source := MotionSource.new()
	var sink := TorqueSink.new()
	var unit := _running_unit("message_device", source, sink)
	var endpoint := unit.get_runtime_input_endpoint(
		SteeringRuntimeUnit.INPUT_PORT_ID
	)

	endpoint.call("not a message")
	_expect_last_code(unit, &"steering_runtime_message_invalid", "SRU-U04: non-message")
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.BRAKE_COMMAND,
			1.0,
			SteeringCommand.new(0.5, 1.0)
		)
	)
	_expect_last_code(unit, &"steering_runtime_topic_mismatch", "SRU-U04: wrong Topic")
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.STEERING_COMMAND,
			-1.0,
			SteeringCommand.new(0.5, 0.0)
		)
	)
	_expect_last_code(unit, &"steering_runtime_timestamp_invalid", "SRU-U04: invalid envelope timestamp")
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.STEERING_COMMAND,
			1.0,
			RefCounted.new()
		)
	)
	_expect_last_code(unit, &"steering_runtime_payload_invalid", "SRU-U04: wrong payload type")
	endpoint.call(_message(2.0, 2.0))
	_expect_last_code(unit, &"steering_runtime_payload_invalid", "SRU-U04: invalid Command")
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.STEERING_COMMAND,
			3.0,
			SteeringCommand.new(0.5, 2.9)
		)
	)
	_expect_last_code(unit, &"steering_runtime_timestamp_mismatch", "SRU-U04: timestamp mismatch")
	_expect(
		source.read_count == 0 and sink.apply_count == 0,
		"SRU-U04: rejected messages never read motion or apply torque"
	)


func _test_motion_source_failure_and_recovery() -> void:

	var source := MotionSource.new()
	var sink := TorqueSink.new()
	var unit := _running_unit("motion_device", source, sink)
	var endpoint := unit.get_runtime_input_endpoint(
		SteeringRuntimeUnit.INPUT_PORT_ID
	)

	source.result = "invalid"
	endpoint.call(_message(0.5, 1.0))
	_expect_last_code(unit, &"steering_runtime_motion_result_invalid", "SRU-U05: non-numeric motion result")
	_expect(sink.apply_count == 0, "SRU-U05: invalid motion result never reaches sink")

	source.result = NAN
	endpoint.call(_message(0.5, 2.0))
	_expect_last_code(unit, &"steering_runtime_yaw_rate_invalid", "SRU-U05: non-finite yaw rate")

	source.result = 0.0
	endpoint.call(_message(0.5, 3.0))
	_expect(
		sink.apply_count == 1
		and unit.get_last_torque_newton_meters() == 50.0
		and unit.get_last_actuation_report().is_empty(),
		"SRU-U05: valid motion result recovers actuation"
	)


func _test_sink_failure_and_recovery() -> void:

	var source := MotionSource.new()
	var sink := TorqueSink.new()
	var unit := _running_unit("sink_device", source, sink)
	var endpoint := unit.get_runtime_input_endpoint(
		SteeringRuntimeUnit.INPUT_PORT_ID
	)

	sink.result = false
	endpoint.call(_message(0.5, 1.0))
	_expect_last_code(unit, &"steering_runtime_sink_rejected", "SRU-U06: sink rejection")
	_expect(unit.get_last_torque_newton_meters() == 0.0, "SRU-U06: rejection remains fail-neutral")

	sink.result = "invalid"
	endpoint.call(_message(0.5, 2.0))
	_expect_last_code(unit, &"steering_runtime_sink_result_invalid", "SRU-U06: non-boolean sink result")

	sink.result = true
	endpoint.call(_message(0.25, 3.0))
	_expect(
		sink.apply_count == 3
		and unit.get_last_torque_newton_meters() == 25.0
		and unit.get_last_actuation_report().is_empty(),
		"SRU-U06: later valid sink result recovers actuation"
	)


func _test_shutdown() -> void:

	var model := _model()
	var source := MotionSource.new()
	var sink := TorqueSink.new()
	var unit := SteeringRuntimeUnit.new(
		"shutdown_device",
		_configuration("shutdown_device"),
		model,
		source,
		sink
	)
	unit.runtime_initialize(DeviceBus.new())
	unit.runtime_set_ready()
	unit.runtime_start()
	var endpoint := unit.get_runtime_input_endpoint(
		SteeringRuntimeUnit.INPUT_PORT_ID
	)

	_expect(
		unit.runtime_shutdown().is_empty()
		and unit.get_state() == SteeringRuntimeUnit.State.SHUTDOWN,
		"SRU-U07: shutdown enters SHUTDOWN"
	)
	_expect(unit.runtime_shutdown().is_empty(), "SRU-U07: shutdown is idempotent")
	endpoint.call(_message(1.0, 4.0))
	_expect(sink.apply_count == 0, "SRU-U07: post-shutdown command never reaches sink")
	_expect_last_code(unit, &"steering_runtime_state_invalid", "SRU-U07: post-shutdown actuation is observable")
	_expect(
		is_instance_valid(model)
		and is_instance_valid(source)
		and is_instance_valid(sink)
		and unit.get_model() == model
		and unit.get_yaw_motion_source() == source
		and unit.get_torque_sink() == sink,
		"SRU-U07: BORROWED dependencies remain alive"
	)


func _configuration(
	device_id: String,
	capabilities: Array[String] = ["bounded_yaw_torque"]
) -> DeviceConfiguration:

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = [BusTopics.STEERING_COMMAND]
	var requirements: Array[String] = []
	return DeviceConfiguration.new(
		StringName("test.steering.runtime." + device_id),
		1,
		device_id,
		SteeringRuntimeUnit.PROFILE_ID,
		SteeringRuntimeUnit.PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _model() -> YawSteeringModel:

	return YawSteeringModel.new(100.0, 10.0, 2.0)


func _unit(
	device_id: String,
	source: Object,
	sink: Object
) -> SteeringRuntimeUnit:

	return SteeringRuntimeUnit.new(
		device_id,
		_configuration(device_id),
		_model(),
		source,
		sink
	)


func _running_unit(
	device_id: String,
	source: Object,
	sink: Object
) -> SteeringRuntimeUnit:

	var unit := _unit(device_id, source, sink)
	unit.runtime_initialize(DeviceBus.new())
	unit.runtime_set_ready()
	unit.runtime_start()
	return unit


func _message(
	normalized_yaw: float,
	timestamp: float
) -> BusMessage:

	return BusMessage.new(
		"steering_source",
		BusTopics.STEERING_COMMAND,
		timestamp,
		SteeringCommand.new(normalized_yaw, timestamp)
	)


func _expect_last_code(
	unit: SteeringRuntimeUnit,
	code: StringName,
	description: String
) -> void:

	_expect(
		_report_has_code(unit.get_last_actuation_report(), code),
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
	print("RESULT: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(_failures)
