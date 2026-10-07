extends Node


## HoverPointRuntimeUnitTest
##
## Cubre lifecycle, endpoint, first sample, derivative, temporal
## safety, invalid-data reset, sink failures, recovery y shutdown.


const ForceSink = preload(
	"res://test/core/hover/hover_test_force_sink.gd"
)


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("HoverPointRuntimeUnitTest")
	print("========================================")

	_test_validation()
	_test_lifecycle_and_endpoint()
	_test_first_and_subsequent_samples()
	_test_invalid_measurement_reset()
	_test_temporal_safety()
	_test_sink_failure_and_recovery()
	_test_shutdown()

	_finish()


func _test_validation() -> void:

	var model := _model()
	var sink := ForceSink.new()
	var valid_unit := HoverPointRuntimeUnit.new(
		"hover_device",
		_configuration("hover_device"),
		model,
		sink
	)

	_expect(
		valid_unit.is_valid(),
		"HPR-U01: exact Unit is valid"
	)
	_expect(
		not HoverPointRuntimeUnit.new(
			"",
			_configuration("hover_device"),
			model,
			sink
		).is_valid(),
		"HPR-U01: empty Device ID is invalid"
	)
	_expect(
		not HoverPointRuntimeUnit.new(
			"other_device",
			_configuration("hover_device"),
			model,
			sink
		).is_valid(),
		"HPR-U01: Configuration identity mismatch is invalid"
	)
	_expect(
		not HoverPointRuntimeUnit.new(
			"invalid_model",
			_configuration("invalid_model"),
			HoverSpringDamperModel.new(
				0.0, 0.0, 0.0, 0.0, 0.0, 0.1
			),
			sink
		).is_valid(),
		"HPR-U01: invalid model is rejected"
	)
	_expect(
		not HoverPointRuntimeUnit.new(
			"invalid_sink",
			_configuration("invalid_sink"),
			model,
			RefCounted.new()
		).is_valid(),
		"HPR-U01: incomplete sink behavior is rejected"
	)

	var unsupported_capabilities: Array[String] = [
		"central_hover_controller",
	]

	_expect(
		not HoverPointRuntimeUnit.new(
			"unsupported",
			_configuration(
				"unsupported",
				unsupported_capabilities
			),
			model,
			sink
		).is_valid(),
		"HPR-U01: unsupported Configuration is rejected"
	)


func _test_lifecycle_and_endpoint() -> void:

	var unit := _unit("lifecycle_device", ForceSink.new())
	var endpoint := unit.get_runtime_input_endpoint(
		HoverPointRuntimeUnit.INPUT_PORT_ID
	)

	_expect(
		unit.get_state() == HoverPointRuntimeUnit.State.CREATED,
		"HPR-U02: Unit starts in CREATED"
	)
	_expect(
		endpoint.is_valid()
		and not unit.get_runtime_input_endpoint(&"").is_valid()
		and not unit.get_runtime_input_endpoint(
			&"in.propulsion_command"
		).is_valid(),
		"HPR-U02: only exact distance input endpoint is exposed"
	)
	_expect_code(
		unit.runtime_set_ready(),
		&"hover_runtime_state_invalid",
		"HPR-U02: ready before initialize"
	)
	_expect_code(
		unit.runtime_initialize(null),
		&"hover_runtime_bus_missing",
		"HPR-U02: initialize requires DeviceBus"
	)
	_expect(
		unit.runtime_initialize(DeviceBus.new()).is_empty()
		and unit.get_state()
		== HoverPointRuntimeUnit.State.INITIALIZED,
		"HPR-U02: initialize enters INITIALIZED"
	)
	_expect_code(
		unit.runtime_initialize(DeviceBus.new()),
		&"hover_runtime_state_invalid",
		"HPR-U02: repeated initialize"
	)
	_expect(
		unit.runtime_set_ready().is_empty()
		and unit.get_state() == HoverPointRuntimeUnit.State.READY,
		"HPR-U02: set_ready enters READY"
	)
	_expect(
		unit.runtime_start().is_empty()
		and unit.get_state() == HoverPointRuntimeUnit.State.RUNNING,
		"HPR-U02: start enters RUNNING"
	)


func _test_first_and_subsequent_samples() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("sample_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		HoverPointRuntimeUnit.INPUT_PORT_ID
	)

	endpoint.call(_message(2.0, true, 1.0))

	_expect(
		sink.apply_count == 1
		and sink.last_force_newtons == 9810.0
		and sink.last_timestamp == 1.0,
		"HPR-U03: first sample produces equilibrium lift"
	)
	_expect(
		unit.has_previous_sample()
		and unit.has_actuation_result()
		and unit.get_last_distance_rate_meters_per_second()
		== 0.0
		and unit.get_last_actuation_report().is_empty(),
		"HPR-U03: first sample stores baseline with zero rate"
	)

	endpoint.call(_message(2.01, true, 1.1))

	_expect(
		sink.apply_count == 2
		and is_equal_approx(
			unit.get_last_distance_rate_meters_per_second(),
			0.1
		)
		and is_equal_approx(sink.last_force_newtons, 8810.0),
		"HPR-U03: increasing distance reduces lift through damping"
	)

	endpoint.call(_message(1.99, true, 1.2))

	_expect(
		sink.apply_count == 3
		and is_equal_approx(
			unit.get_last_distance_rate_meters_per_second(),
			-0.2
		)
		and is_equal_approx(sink.last_force_newtons, 11610.0),
		"HPR-U03: decreasing distance increases bounded lift"
	)
	_expect(
		unit.get_last_force_newtons() == sink.last_force_newtons
		and unit.get_last_actuation_report().is_empty(),
		"HPR-U03: latest successful actuation is observable"
	)


func _test_invalid_measurement_reset() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("invalid_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		HoverPointRuntimeUnit.INPUT_PORT_ID
	)

	endpoint.call(_message(2.0, true, 1.0))
	endpoint.call(_message(2.0, false, 1.1))

	_expect_last_code(
		unit,
		&"hover_runtime_measurement_invalid",
		"HPR-U04: invalid measurement"
	)
	_expect(
		not unit.has_previous_sample()
		and sink.apply_count == 1,
		"HPR-U04: invalid measurement clears history and applies no force"
	)

	endpoint.call(_message(1.5, true, 2.0))

	_expect(
		sink.apply_count == 2
		and unit.has_previous_sample()
		and unit.get_last_distance_rate_meters_per_second()
		== 0.0
		and sink.last_force_newtons == 19810.0,
		"HPR-U04: next valid measurement recovers as first sample"
	)

	endpoint.call("not a message")
	_expect_last_code(
		unit,
		&"hover_runtime_message_invalid",
		"HPR-U04: non-message value"
	)
	_expect(
		not unit.has_previous_sample(),
		"HPR-U04: malformed message also clears temporal history"
	)

	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.PROPULSION_COMMAND,
			3.0,
			_measurement(2.0, true, 3.0)
		)
	)
	_expect_last_code(
		unit,
		&"hover_runtime_topic_mismatch",
		"HPR-U04: wrong Topic"
	)

	endpoint.call(
		BusMessage.new(
			"source",
			BusTopics.DISTANCE_MEASUREMENT,
			4.0,
			_measurement(2.0, true, 3.9)
		)
	)
	_expect_last_code(
		unit,
		&"hover_runtime_timestamp_mismatch",
		"HPR-U04: payload and envelope timestamp mismatch"
	)


func _test_temporal_safety() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("temporal_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		HoverPointRuntimeUnit.INPUT_PORT_ID
	)

	endpoint.call(_message(2.0, true, 1.0))
	endpoint.call(_message(1.9, true, 1.0))

	_expect_last_code(
		unit,
		&"hover_runtime_timestamp_non_monotonic",
		"HPR-U05: non-monotonic timestamp"
	)
	_expect(
		sink.apply_count == 1
		and unit.has_previous_sample(),
		"HPR-U05: non-monotonic sample rebases without sink call"
	)

	endpoint.call(_message(1.8, true, 1.05))

	_expect(
		sink.apply_count == 2
		and is_equal_approx(
			unit.get_last_distance_rate_meters_per_second(),
			-2.0
		),
		"HPR-U05: sample after temporal rebase recovers derivative"
	)

	endpoint.call(_message(1.7, true, 1.25))

	_expect_last_code(
		unit,
		&"hover_runtime_sample_gap_exceeded",
		"HPR-U05: excessive sample gap"
	)
	_expect(
		sink.apply_count == 2
		and unit.has_previous_sample(),
		"HPR-U05: excessive gap rebases without stale force"
	)

	endpoint.call(_message(1.7, true, 1.3))

	_expect(
		sink.apply_count == 3
		and is_equal_approx(
			unit.get_last_distance_rate_meters_per_second(),
			0.0
		),
		"HPR-U05: sample after gap rebase recovers"
	)


func _test_sink_failure_and_recovery() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("sink_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		HoverPointRuntimeUnit.INPUT_PORT_ID
	)

	sink.result = false
	endpoint.call(_message(2.0, true, 1.0))

	_expect_last_code(
		unit,
		&"hover_runtime_sink_rejected",
		"HPR-U06: sink rejection"
	)
	_expect(
		unit.has_previous_sample()
		and unit.get_last_force_newtons() == 0.0,
		"HPR-U06: sink rejection preserves sample and fails neutral"
	)

	sink.result = "invalid"
	endpoint.call(_message(2.0, true, 1.05))

	_expect_last_code(
		unit,
		&"hover_runtime_sink_result_invalid",
		"HPR-U06: non-boolean sink result"
	)

	sink.result = true
	endpoint.call(_message(2.0, true, 1.1))

	_expect(
		sink.apply_count == 3
		and unit.get_last_force_newtons() == 9810.0
		and unit.get_last_actuation_report().is_empty(),
		"HPR-U06: later valid sink result recovers actuation"
	)


func _test_shutdown() -> void:

	var sink := ForceSink.new()
	var unit := _running_unit("shutdown_device", sink)
	var endpoint := unit.get_runtime_input_endpoint(
		HoverPointRuntimeUnit.INPUT_PORT_ID
	)
	var model := unit.get_model()

	endpoint.call(_message(2.0, true, 1.0))

	_expect(
		unit.runtime_shutdown().is_empty()
		and unit.get_state() == HoverPointRuntimeUnit.State.SHUTDOWN,
		"HPR-U07: shutdown enters SHUTDOWN"
	)
	_expect(
		not unit.has_previous_sample(),
		"HPR-U07: shutdown clears temporal history"
	)
	_expect(
		unit.runtime_shutdown().is_empty(),
		"HPR-U07: shutdown is idempotent"
	)

	var count_before := sink.apply_count
	endpoint.call(_message(1.0, true, 2.0))

	_expect(
		sink.apply_count == count_before,
		"HPR-U07: command after shutdown never reaches sink"
	)
	_expect_last_code(
		unit,
		&"hover_runtime_state_invalid",
		"HPR-U07: post-shutdown actuation is observable"
	)
	_expect(
		is_instance_valid(model)
		and is_instance_valid(sink)
		and unit.get_model() == model
		and unit.get_force_sink() == sink,
		"HPR-U07: BORROWED model and sink remain alive"
	)


func _configuration(
	device_id: String,
	capabilities: Array[String] = [
		"hover_lift_force",
	]
) -> DeviceConfiguration:

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName("test.hover.runtime." + device_id),
		1,
		device_id,
		HoverPointRuntimeUnit.PROFILE_ID,
		HoverPointRuntimeUnit.PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _model() -> HoverSpringDamperModel:

	return HoverSpringDamperModel.new(
		2.0, 9810.0, 20000.0, 8000.0, 30000.0, 0.1
	)


func _unit(
	device_id: String,
	sink: Object
) -> HoverPointRuntimeUnit:

	return HoverPointRuntimeUnit.new(
		device_id,
		_configuration(device_id),
		_model(),
		sink
	)


func _running_unit(
	device_id: String,
	sink: Object
) -> HoverPointRuntimeUnit:

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
	unit: HoverPointRuntimeUnit,
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
