extends Node


## BrakeRuntimeUnitTest
##
## Cubre validation, lifecycle, model/source/sink composition, message
## safety, dynamic dependency failures, recovery y shutdown.


const MotionSource = preload(
	"res://test/core/braking/braking_test_motion_source.gd"
)
const ForceSink = preload(
	"res://test/core/braking/braking_test_force_sink.gd"
)


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("BrakeRuntimeUnitTest")
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
	var sink := ForceSink.new()
	var valid_unit := BrakeRuntimeUnit.new(
		"braking_device",
		_configuration("braking_device"),
		model,
		source,
		sink
	)

	_expect(valid_unit.is_valid(), "BRU-U01: exact Unit is valid")
	_expect(
		valid_unit.get_model() == model
		and valid_unit.get_longitudinal_motion_source() == source
		and valid_unit.get_force_sink() == sink,
		"BRU-U01: exact BORROWED dependencies are preserved"
	)
	_expect(
		not BrakeRuntimeUnit.new(
			"",
			_configuration("braking_device"),
			model,
			source,
			sink
		).is_valid(),
		"BRU-U01: empty Device ID is invalid"
	)
	_expect(
		not BrakeRuntimeUnit.new(
			"other",
			_configuration("braking_device"),
			model,
			source,
			sink
		).is_valid(),
		"BRU-U01: Configuration identity mismatch is invalid"
	)
	_expect(
		not BrakeRuntimeUnit.new(
			"invalid_model",
			_configuration("invalid_model"),
			LongitudinalBrakeModel.new(-1.0, 0.1),
			source,
			sink
		).is_valid(),
		"BRU-U01: invalid model is rejected"
	)
	_expect(
		not BrakeRuntimeUnit.new(
			"invalid_source",
			_configuration("invalid_source"),
			model,
			RefCounted.new(),
			sink
		).is_valid(),
		"BRU-U01: incomplete motion source is rejected"
	)
	_expect(
		not BrakeRuntimeUnit.new(
			"invalid_sink",
			_configuration("invalid_sink"),
			model,
			source,
			RefCounted.new()
		).is_valid(),
		"BRU-U01: incomplete force sink is rejected"
	)


func _test_lifecycle_and_endpoint() -> void:

	var unit := _unit("lifecycle_device", MotionSource.new(), ForceSink.new())
	var endpoint := unit.get_runtime_input_endpoint(
		BrakeRuntimeUnit.INPUT_PORT_ID
	)

	_expect(
		unit.get_state() == BrakeRuntimeUnit.State.CREATED,
		"BRU-U02: Unit starts in CREATED"
	)
	_expect(
		endpoint.is_valid()
		and not unit.get_runtime_input_endpoint(&"").is_valid()
		and not unit.get_runtime_input_endpoint(
			&"in.steering_command"
		).is_valid(),
		"BRU-U02: only exact Brake endpoint is exposed"
	)
	_expect_code(
		unit.runtime_set_ready(),
		&"brake_runtime_state_invalid",
		"BRU-U02: ready before initialize"
	)
	_expect_code(
		unit.runtime_initialize(null),
		&"brake_runtime_bus_missing",
		"BRU-U02: initialize requires DeviceBus"
	)
	_expect(
		unit.runtime_initialize(DeviceBus.new()).is_empty()
		and unit.get_state() == BrakeRuntimeUnit.State.INITIALIZED,
		"BRU-U02: initialize enters INITIALIZED"
	)
	_expect_code(
		unit.runtime_initialize(DeviceBus.new()),
		&"brake_runtime_state_invalid",
		"BRU-U02: repeated initialize"
	)
	_expect(
		unit.runtime_set_ready().is_empty()
		and unit.get_state() == BrakeRuntimeUnit.State.READY,
		"BRU-U02: set_ready enters READY"
	)
	_expect(
		unit.runtime_start().is_empty()
		and unit.get_state() == BrakeRuntimeUnit.State.RUNNING,
		"BRU-U02: start enters RUNNING"
	)


func _test_actuation_pipeline() -> void:

	var source := MotionSource.new()
	var sink := ForceSink.new()
	var unit := _running_unit("actuation_device", source, sink)
	var endpoint := unit.get_runtime_input_endpoint(
		BrakeRuntimeUnit.INPUT_PORT_ID
	)

	source.result = 10.0
	endpoint.call(_message(1.0, 1.0))
	_expect(
		sink.apply_count == 1
		and sink.last_force_newtons == -1000.0
		and sink.last_timestamp == 1.0,
		"BRU-U03: full brake opposes forward speed"
	)

	source.result = -10.0
	endpoint.call(_message(0.5, 2.0))
	_expect(
		sink.apply_count == 2
		and sink.last_force_newtons == 500.0,
		"BRU-U03: partial brake opposes reverse speed"
	)

	source.result = 0.0
	endpoint.call(_message(1.0, 3.0))
	_expect(
		sink.apply_count == 3
		and sink.last_force_newtons == 0.0,
		"BRU-U03: rest applies explicit zero force"
	)
	_expect(
		unit.has_actuation_result()
		and unit.get_last_longitudinal_speed_meters_per_second() == 0.0
		and unit.get_last_force_newtons() == 0.0
		and unit.get_last_actuation_report().is_empty(),
		"BRU-U03: latest successful actuation is observable"
	)


func _test_message_validation() -> void:

	var source := MotionSource.new()
	var sink := ForceSink.new()
	var unit := _running_unit("message_device", source, sink)
	var endpoint := unit.get_runtime_input_endpoint(
		BrakeRuntimeUnit.INPUT_PORT_ID
	)

	endpoint.call("not a message")
	_expect_last_code(unit, &"brake_runtime_message_invalid", "BRU-U04: non-message")
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.STEERING_COMMAND,
			1.0,
			BrakeCommand.new(0.5, 1.0)
		)
	)
	_expect_last_code(unit, &"brake_runtime_topic_mismatch", "BRU-U04: wrong Topic")
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.BRAKE_COMMAND,
			-1.0,
			BrakeCommand.new(0.5, 0.0)
		)
	)
	_expect_last_code(unit, &"brake_runtime_timestamp_invalid", "BRU-U04: invalid envelope timestamp")
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.BRAKE_COMMAND,
			1.0,
			RefCounted.new()
		)
	)
	_expect_last_code(unit, &"brake_runtime_payload_invalid", "BRU-U04: wrong payload type")
	endpoint.call(_message(2.0, 2.0))
	_expect_last_code(unit, &"brake_runtime_payload_invalid", "BRU-U04: invalid Command")
	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.BRAKE_COMMAND,
			3.0,
			BrakeCommand.new(0.5, 2.9)
		)
	)
	_expect_last_code(unit, &"brake_runtime_timestamp_mismatch", "BRU-U04: timestamp mismatch")
	_expect(
		source.read_count == 0 and sink.apply_count == 0,
		"BRU-U04: rejected messages never read motion or apply force"
	)


func _test_motion_source_failure_and_recovery() -> void:

	var source := MotionSource.new()
	var sink := ForceSink.new()
	var unit := _running_unit("motion_device", source, sink)
	var endpoint := unit.get_runtime_input_endpoint(
		BrakeRuntimeUnit.INPUT_PORT_ID
	)

	source.result = "invalid"
	endpoint.call(_message(0.5, 1.0))
	_expect_last_code(unit, &"brake_runtime_motion_result_invalid", "BRU-U05: non-numeric motion result")
	_expect(sink.apply_count == 0, "BRU-U05: invalid motion result never reaches sink")

	source.result = NAN
	endpoint.call(_message(0.5, 2.0))
	_expect_last_code(unit, &"brake_runtime_longitudinal_speed_invalid", "BRU-U05: non-finite longitudinal speed")

	source.result = 10.0
	endpoint.call(_message(0.5, 3.0))
	_expect(
		sink.apply_count == 1
		and unit.get_last_force_newtons() == -500.0
		and unit.get_last_actuation_report().is_empty(),
		"BRU-U05: valid motion result recovers actuation"
	)


func _test_sink_failure_and_recovery() -> void:

	var source := MotionSource.new()
	source.result = 10.0
	var sink := ForceSink.new()
	var unit := _running_unit("sink_device", source, sink)
	var endpoint := unit.get_runtime_input_endpoint(
		BrakeRuntimeUnit.INPUT_PORT_ID
	)

	sink.result = false
	endpoint.call(_message(0.5, 1.0))
	_expect_last_code(unit, &"brake_runtime_sink_rejected", "BRU-U06: sink rejection")
	_expect(unit.get_last_force_newtons() == 0.0, "BRU-U06: rejection remains fail-neutral")

	sink.result = "invalid"
	endpoint.call(_message(0.5, 2.0))
	_expect_last_code(unit, &"brake_runtime_sink_result_invalid", "BRU-U06: non-boolean sink result")

	sink.result = true
	endpoint.call(_message(0.25, 3.0))
	_expect(
		sink.apply_count == 3
		and unit.get_last_force_newtons() == -250.0
		and unit.get_last_actuation_report().is_empty(),
		"BRU-U06: later valid sink result recovers actuation"
	)


func _test_shutdown() -> void:

	var model := _model()
	var source := MotionSource.new()
	var sink := ForceSink.new()
	var unit := BrakeRuntimeUnit.new(
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
		BrakeRuntimeUnit.INPUT_PORT_ID
	)

	_expect(
		unit.runtime_shutdown().is_empty()
		and unit.get_state() == BrakeRuntimeUnit.State.SHUTDOWN,
		"BRU-U07: shutdown enters SHUTDOWN"
	)
	_expect(unit.runtime_shutdown().is_empty(), "BRU-U07: shutdown is idempotent")
	endpoint.call(_message(1.0, 4.0))
	_expect(sink.apply_count == 0, "BRU-U07: post-shutdown command never reaches sink")
	_expect_last_code(unit, &"brake_runtime_state_invalid", "BRU-U07: post-shutdown actuation is observable")
	_expect(
		is_instance_valid(model)
		and is_instance_valid(source)
		and is_instance_valid(sink)
		and unit.get_model() == model
		and unit.get_longitudinal_motion_source() == source
		and unit.get_force_sink() == sink,
		"BRU-U07: BORROWED dependencies remain alive"
	)


func _configuration(
	device_id: String,
	capabilities: Array[String] = ["active_longitudinal_braking"]
) -> DeviceConfiguration:

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = [BusTopics.BRAKE_COMMAND]
	var requirements: Array[String] = []
	return DeviceConfiguration.new(
		StringName("test.braking.runtime." + device_id),
		1,
		device_id,
		BrakeRuntimeUnit.PROFILE_ID,
		BrakeRuntimeUnit.PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _model() -> LongitudinalBrakeModel:

	return LongitudinalBrakeModel.new(1000.0, 0.1)


func _unit(
	device_id: String,
	source: Object,
	sink: Object
) -> BrakeRuntimeUnit:

	return BrakeRuntimeUnit.new(
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
) -> BrakeRuntimeUnit:

	var unit := _unit(device_id, source, sink)
	unit.runtime_initialize(DeviceBus.new())
	unit.runtime_set_ready()
	unit.runtime_start()
	return unit


func _message(
	normalized_brake: float,
	timestamp: float
) -> BusMessage:

	return BusMessage.new(
		"braking_source",
		BusTopics.BRAKE_COMMAND,
		timestamp,
		BrakeCommand.new(normalized_brake, timestamp)
	)


func _expect_last_code(
	unit: BrakeRuntimeUnit,
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
