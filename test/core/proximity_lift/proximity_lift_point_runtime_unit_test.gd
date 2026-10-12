extends Node


## ProximityLiftPointRuntimeUnitTest
##
## Cubre validation, lifecycle, exact endpoint, distance-only force curve,
## message safety, sink failures, recovery y shutdown.


const ForceSink = preload(
	"res://test/core/proximity_lift/proximity_lift_test_force_sink.gd"
)


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("ProximityLiftPointRuntimeUnitTest")
	print("========================================")

	_test_validation()
	_test_lifecycle_and_endpoint()
	_test_force_output()
	_test_message_validation()
	_test_sink_failure_and_recovery()
	_test_shutdown()

	_finish()


func _test_validation() -> void:

	var model := _model()
	var sink := ForceSink.new()
	var valid_unit := ProximityLiftPointRuntimeUnit.new(
		"proximity_device",
		_configuration("proximity_device"),
		model,
		sink
	)

	_expect(
		valid_unit.is_valid(),
		"PLR-U01: exact Unit is valid"
	)
	_expect(
		not ProximityLiftPointRuntimeUnit.new(
			"",
			_configuration("proximity_device"),
			model,
			sink
		).is_valid(),
		"PLR-U01: empty Device ID is invalid"
	)
	_expect(
		not ProximityLiftPointRuntimeUnit.new(
			"other_device",
			_configuration("proximity_device"),
			model,
			sink
		).is_valid(),
		"PLR-U01: Configuration identity mismatch is invalid"
	)
	_expect(
		not ProximityLiftPointRuntimeUnit.new(
			"invalid_model",
			_configuration("invalid_model"),
			ProximityLiftModel.new(0.0, 1.0, 1.0),
			sink
		).is_valid(),
		"PLR-U01: invalid model is rejected"
	)
	_expect(
		not ProximityLiftPointRuntimeUnit.new(
			"invalid_sink",
			_configuration("invalid_sink"),
			model,
			RefCounted.new()
		).is_valid(),
		"PLR-U01: incomplete sink behavior is rejected"
	)

	var unsupported_capabilities: Array[String] = [
		"hover_lift_force",
	]

	_expect(
		not ProximityLiftPointRuntimeUnit.new(
			"unsupported",
			_configuration(
				"unsupported",
				unsupported_capabilities
			),
			model,
			sink
		).is_valid(),
		"PLR-U01: unsupported Configuration is rejected"
	)


func _test_lifecycle_and_endpoint() -> void:

	var unit := _unit("lifecycle_device", ForceSink.new())
	var endpoint := unit.get_runtime_input_endpoint(
		ProximityLiftPointRuntimeUnit.INPUT_PORT_ID
	)

	_expect(
		unit.get_state()
		== ProximityLiftPointRuntimeUnit.State.CREATED,
		"PLR-U02: Unit starts in CREATED"
	)
	_expect(
		endpoint.is_valid()
		and not unit.get_runtime_input_endpoint(&"").is_valid()
		and not unit.get_runtime_input_endpoint(
			&"in.propulsion_command"
		).is_valid(),
		"PLR-U02: only exact distance input endpoint is exposed"
	)
	_expect_code(
		unit.runtime_set_ready(),
		&"proximity_lift_runtime_state_invalid",
		"PLR-U02: ready before initialize"
	)
	_expect_code(
		unit.runtime_initialize(null),
		&"proximity_lift_runtime_bus_missing",
		"PLR-U02: initialize requires DeviceBus"
	)
	_expect(
		unit.runtime_initialize(DeviceBus.new()).is_empty()
		and unit.get_state()
		== ProximityLiftPointRuntimeUnit.State.INITIALIZED,
		"PLR-U02: initialize enters INITIALIZED"
	)
	_expect_code(
		unit.runtime_initialize(DeviceBus.new()),
		&"proximity_lift_runtime_state_invalid",
		"PLR-U02: repeated initialize"
	)
	_expect(
		unit.runtime_set_ready().is_empty()
		and unit.get_state()
		== ProximityLiftPointRuntimeUnit.State.READY,
		"PLR-U02: set_ready enters READY"
	)
	_expect(
		unit.runtime_start().is_empty()
		and unit.get_state()
		== ProximityLiftPointRuntimeUnit.State.RUNNING,
		"PLR-U02: start enters RUNNING"
	)


func _test_force_output() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("force_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		ProximityLiftPointRuntimeUnit.INPUT_PORT_ID
	)

	endpoint.call(_message(0.0, true, 10.0))

	_expect(
		sink.apply_count == 1
		and sink.last_force_newtons == 4000.0
		and sink.last_timestamp == 10.0,
		"PLR-U03: zero distance produces maximum proximity lift"
	)
	_expect(
		unit.has_actuation_result()
		and unit.get_last_force_newtons() == 4000.0
		and unit.get_last_actuation_report().is_empty(),
		"PLR-U03: maximum-force success is observable"
	)

	endpoint.call(_message(1.0, true, 11.0))

	_expect(
		sink.apply_count == 2
		and sink.last_force_newtons == 1000.0,
		"PLR-U03: half influence distance follows model curve"
	)

	endpoint.call(_message(2.0, true, 12.0))

	_expect(
		sink.apply_count == 3
		and sink.last_force_newtons == 0.0,
		"PLR-U03: influence boundary applies explicit zero force"
	)

	endpoint.call(_message(20.0, true, 13.0))

	_expect(
		sink.apply_count == 4
		and sink.last_force_newtons == 0.0
		and unit.get_last_force_newtons() == 0.0,
		"PLR-U03: distant valid sample remains zero and bounded"
	)


func _test_message_validation() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("message_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		ProximityLiftPointRuntimeUnit.INPUT_PORT_ID
	)

	endpoint.call("not a message")
	_expect_last_code(
		unit,
		&"proximity_lift_runtime_message_invalid",
		"PLR-U04: non-message value"
	)

	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.PROPULSION_COMMAND,
			1.0,
			_measurement(1.0, true, 1.0)
		)
	)
	_expect_last_code(
		unit,
		&"proximity_lift_runtime_topic_mismatch",
		"PLR-U04: wrong Topic"
	)

	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.DISTANCE_MEASUREMENT,
			-1.0,
			_measurement(1.0, true, 0.0)
		)
	)
	_expect_last_code(
		unit,
		&"proximity_lift_runtime_timestamp_invalid",
		"PLR-U04: invalid envelope timestamp"
	)

	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.DISTANCE_MEASUREMENT,
			1.0,
			RefCounted.new()
		)
	)
	_expect_last_code(
		unit,
		&"proximity_lift_runtime_payload_invalid",
		"PLR-U04: wrong payload type"
	)

	endpoint.call(_message(-0.1, true, 2.0))
	_expect_last_code(
		unit,
		&"proximity_lift_runtime_measurement_invalid",
		"PLR-U04: negative distance"
	)

	endpoint.call(_message(1.0, false, 3.0))
	_expect_last_code(
		unit,
		&"proximity_lift_runtime_measurement_invalid",
		"PLR-U04: invalid measurement flag"
	)

	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.DISTANCE_MEASUREMENT,
			4.0,
			_measurement(1.0, true, 3.9)
		)
	)
	_expect_last_code(
		unit,
		&"proximity_lift_runtime_timestamp_mismatch",
		"PLR-U04: payload and envelope timestamp mismatch"
	)
	_expect(
		sink.apply_count == 0,
		"PLR-U04: rejected messages never reach sink"
	)


func _test_sink_failure_and_recovery() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("sink_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		ProximityLiftPointRuntimeUnit.INPUT_PORT_ID
	)

	sink.result = false
	endpoint.call(_message(1.0, true, 1.0))
	_expect_last_code(
		unit,
		&"proximity_lift_runtime_sink_rejected",
		"PLR-U05: sink rejection"
	)
	_expect(
		unit.get_last_force_newtons() == 0.0,
		"PLR-U05: rejected sink output remains fail-neutral"
	)

	sink.result = "invalid"
	endpoint.call(_message(1.0, true, 2.0))
	_expect_last_code(
		unit,
		&"proximity_lift_runtime_sink_result_invalid",
		"PLR-U05: non-boolean sink result"
	)

	sink.result = true
	endpoint.call(_message(1.0, true, 3.0))
	_expect(
		sink.apply_count == 3
		and unit.get_last_force_newtons() == 1000.0
		and unit.get_last_actuation_report().is_empty(),
		"PLR-U05: later valid sink result recovers actuation"
	)


func _test_shutdown() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("shutdown_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		ProximityLiftPointRuntimeUnit.INPUT_PORT_ID
	)
	var model := unit.get_model()

	_expect(
		unit.runtime_shutdown().is_empty()
		and unit.get_state()
		== ProximityLiftPointRuntimeUnit.State.SHUTDOWN,
		"PLR-U06: shutdown enters SHUTDOWN"
	)
	_expect(
		unit.runtime_shutdown().is_empty(),
		"PLR-U06: shutdown is idempotent"
	)

	endpoint.call(_message(0.0, true, 5.0))

	_expect(
		sink.apply_count == 0,
		"PLR-U06: measurement after shutdown never reaches sink"
	)
	_expect_last_code(
		unit,
		&"proximity_lift_runtime_state_invalid",
		"PLR-U06: post-shutdown actuation is observable"
	)
	_expect(
		is_instance_valid(model)
		and is_instance_valid(sink)
		and unit.get_model() == model
		and unit.get_force_sink() == sink,
		"PLR-U06: BORROWED model and sink remain alive"
	)


func _configuration(
	device_id: String,
	capabilities: Array[String] = [
		"proximity_lift_force",
	]
) -> DeviceConfiguration:

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName("test.proximity_lift.runtime." + device_id),
		1,
		device_id,
		ProximityLiftPointRuntimeUnit.PROFILE_ID,
		ProximityLiftPointRuntimeUnit.PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _model() -> ProximityLiftModel:

	return ProximityLiftModel.new(2.0, 4000.0, 2.0)


func _unit(
	device_id: String,
	sink: Object
) -> ProximityLiftPointRuntimeUnit:

	return ProximityLiftPointRuntimeUnit.new(
		device_id,
		_configuration(device_id),
		_model(),
		sink
	)


func _running_unit(
	device_id: String,
	sink: Object
) -> ProximityLiftPointRuntimeUnit:

	var unit := _unit(device_id, sink)
	unit.runtime_initialize(DeviceBus.new())
	unit.runtime_set_ready()
	unit.runtime_start()
	return unit


func _measurement(
	distance: float,
	valid: bool,
	timestamp: float
) -> DistanceMeasurement:

	var measurement := DistanceMeasurement.new()
	measurement.distance = distance
	measurement.valid = valid
	measurement.timestamp = timestamp
	return measurement


func _message(
	distance: float,
	valid: bool,
	timestamp: float
) -> BusMessage:

	return BusMessage.new(
		"distance_sensor",
		BusTopics.DISTANCE_MEASUREMENT,
		timestamp,
		_measurement(distance, valid, timestamp)
	)


func _expect_last_code(
	unit: ProximityLiftPointRuntimeUnit,
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
