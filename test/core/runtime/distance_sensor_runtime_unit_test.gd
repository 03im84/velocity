extends Node


const Helpers = preload(
	"res://test/core/runtime/distance_sensor_runtime_test_helpers.gd"
)


var _checks: int = 0
var _failures: int = 0
var _messages: Array[BusMessage] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("DistanceSensorRuntimeUnitTest")
	print("========================================")

	_test_constructor_validation()
	_test_lifecycle_and_publication()
	_test_state_gates_and_shutdown()
	_test_endpoint_contract()

	_finish()


func _test_constructor_validation() -> void:

	var provider := ManualDistanceProvider.new()
	var sensor := DistanceSensorDevice.new()
	var configuration := Helpers.create_configuration("sensor_a")
	var unit := DistanceSensorRuntimeUnit.new(
		"sensor_a",
		configuration,
		sensor,
		provider
	)

	_expect(unit.is_valid(), "DSRU-U01: complete Unit is valid")
	_expect(
		unit.get_state() == DistanceSensorRuntimeUnit.State.CREATED,
		"DSRU-U01: initial State is CREATED"
	)
	_expect(
		unit.get_sensor() == sensor
		and unit.get_provider() == provider,
		"DSRU-U01: Unit preserves Sensor and Provider references"
	)

	var invalid_provider := RefCounted.new()
	var invalid_unit := DistanceSensorRuntimeUnit.new(
		"sensor_a",
		configuration,
		DistanceSensorDevice.new(),
		invalid_provider
	)

	_expect(
		not invalid_unit.is_valid(),
		"DSRU-U01: Provider behavior is required"
	)

	sensor.free()
	invalid_unit.get_sensor().free()


func _test_lifecycle_and_publication() -> void:

	var provider := ManualDistanceProvider.new()
	provider.set_distance(12.5)
	var sensor := DistanceSensorDevice.new()
	var unit := DistanceSensorRuntimeUnit.new(
		"runtime_sensor",
		Helpers.create_configuration("runtime_sensor"),
		sensor,
		provider
	)
	var bus := DeviceBus.new()
	bus.subscribe(
		BusTopics.DISTANCE_MEASUREMENT,
		_on_message
	)

	_expect(
		unit.runtime_initialize(bus).is_valid_for_simulation(),
		"DSRU-U02: initialize succeeds"
	)
	_expect(
		unit.get_state() == DistanceSensorRuntimeUnit.State.INITIALIZED
		and sensor.device != null,
		"DSRU-U02: initialize commits Device and State"
	)
	_expect(
		sensor.device.get_manifest().capabilities
		== unit_configuration_capabilities()
		and sensor.device.get_manifest().publishes
		== unit_configuration_publishes(),
		"DSRU-U02: runtime Manifest matches supported Configuration"
	)
	_expect(
		unit.runtime_set_ready().is_valid_for_simulation()
		and unit.get_state() == DistanceSensorRuntimeUnit.State.READY,
		"DSRU-U02: set_ready succeeds"
	)
	_expect(
		unit.runtime_start().is_valid_for_simulation()
		and unit.get_state() == DistanceSensorRuntimeUnit.State.RUNNING,
		"DSRU-U02: start succeeds"
	)
	_expect(
		unit.publish_measurement().is_valid_for_simulation(),
		"DSRU-U02: RUNNING Unit publishes"
	)
	_expect(
		_messages.size() == 1,
		"DSRU-U02: one BusMessage is received"
	)

	if not _messages.is_empty():
		var message := _messages[0]
		var payload: Variant = message.get_payload()
		_expect(
			message.get_source_id() == "runtime_sensor"
			and message.get_topic() == BusTopics.DISTANCE_MEASUREMENT,
			"DSRU-U02: BusMessage preserves Source and Topic"
		)
		var measurement: DistanceMeasurement
		if payload is DistanceMeasurement:
			measurement = payload
		_expect(
			measurement != null
			and measurement.distance == 12.5
			and measurement.valid,
			"DSRU-U02: payload preserves Provider measurement"
		)

	unit.runtime_shutdown()
	sensor.free()


func _test_state_gates_and_shutdown() -> void:

	var provider := ManualDistanceProvider.new()
	var sensor := DistanceSensorDevice.new()
	var unit := DistanceSensorRuntimeUnit.new(
		"state_sensor",
		Helpers.create_configuration("state_sensor"),
		sensor,
		provider
	)

	_expect_code(
		unit.runtime_start(),
		&"distance_sensor_runtime_state_invalid",
		"DSRU-U03: start from CREATED"
	)
	_expect_code(
		unit.publish_measurement(),
		&"distance_sensor_runtime_publish_not_running",
		"DSRU-U03: publish before RUNNING"
	)
	_expect_code(
		unit.runtime_initialize(null),
		&"distance_sensor_runtime_bus_missing",
		"DSRU-U03: null Bus"
	)
	_expect(
		unit.runtime_shutdown().is_valid_for_simulation()
		and unit.get_state() == DistanceSensorRuntimeUnit.State.SHUTDOWN,
		"DSRU-U03: shutdown from CREATED is safe"
	)
	_expect(
		unit.runtime_shutdown().is_valid_for_simulation(),
		"DSRU-U03: repeated shutdown is idempotent"
	)
	_expect(
		is_instance_valid(provider),
		"DSRU-U03: BORROWED Provider remains alive"
	)

	sensor.free()


func _test_endpoint_contract() -> void:

	var sensor := DistanceSensorDevice.new()
	var unit := DistanceSensorRuntimeUnit.new(
		"endpoint_sensor",
		Helpers.create_configuration("endpoint_sensor"),
		sensor,
		ManualDistanceProvider.new()
	)

	_expect(
		not unit.get_runtime_input_endpoint(&"any").is_valid(),
		"DSRU-U04: source-only Sensor exposes no input endpoint"
	)

	sensor.free()


func unit_configuration_capabilities() -> Array[String]:

	return ["distance_measurement"]


func unit_configuration_publishes() -> Array[StringName]:

	return [BusTopics.DISTANCE_MEASUREMENT]


func _on_message(message: BusMessage) -> void:

	_messages.append(message)


func _expect_code(
	report: ValidationReport,
	code: StringName,
	description: String
) -> void:

	_expect(
		Helpers.report_has_code(report, code),
		description + " reports " + String(code)
	)


func _expect(condition: bool, description: String) -> void:

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
