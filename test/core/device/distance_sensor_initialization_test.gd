extends Node


##
## DistanceSensorInitializationTest
##
## Verifica inicialización transaccional,
## sensor_id obligatorio y protección contra
## inicialización repetida.
##


const TEST_PROVIDER_SCRIPT := preload(
	"res://test/core/device/"
	+ "distance_sensor_test_provider.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DistanceSensorInitializationTest")
	print("========================================")

	_test_empty_sensor_id()
	_test_successful_initialization()
	_test_second_initialization()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_empty_sensor_id() -> void:

	var sensor := _create_sensor()

	var bus := DeviceBus.new()

	var provider := TEST_PROVIDER_SCRIPT.new()

	provider.set_measurement(
		10.0,
		true
	)

	var initialized: bool = (
		sensor.initialize_sensor(
			"",
			bus,
			provider
		)
	)

	_expect(
		not initialized,
		"DSI-U01: empty sensor_id is rejected"
	)

	_expect(
		sensor.device == null,
		"DSI-U01: rejected ID creates no Device"
	)

	_expect(
		sensor.device_bus == null,
		"DSI-U01: rejected ID stores no DeviceBus"
	)

	_expect(
		sensor.distance_provider == null,
		"DSI-U01: rejected ID stores no Provider"
	)


func _test_successful_initialization() -> void:

	var sensor := _create_sensor()

	var bus := DeviceBus.new()

	var provider := TEST_PROVIDER_SCRIPT.new()

	provider.set_measurement(
		12.5,
		true
	)

	var initialized: bool = (
		sensor.initialize_sensor(
			"transactional_sensor",
			bus,
			provider
		)
	)

	_expect(
		initialized,
		"DSI-U02: valid initialization succeeds"
	)

	_expect(
		sensor.device != null,
		"DSI-U02: Device is committed"
	)

	_expect(
		sensor.device_bus == bus,
		"DSI-U02: DeviceBus is committed"
	)

	_expect(
		sensor.distance_provider == provider,
		"DSI-U02: Provider is committed"
	)

	_expect(
		sensor.device.get_identity().get_device_id()
		== "transactional_sensor",
		"DSI-U02: Device identity is configured"
	)

	_expect(
		sensor.device.get_lifecycle().get_state()
		== DeviceLifecycle.State.INITIALIZED,
		"DSI-U02: Lifecycle is INITIALIZED"
	)


func _test_second_initialization() -> void:

	var sensor := _create_sensor()

	var original_bus := DeviceBus.new()

	var original_provider := (
		TEST_PROVIDER_SCRIPT.new()
	)

	original_provider.set_measurement(
		5.0,
		true
	)

	sensor.initialize_sensor(
		"original_sensor",
		original_bus,
		original_provider
	)

	var original_device: Device = sensor.device

	var replacement_bus := DeviceBus.new()

	var replacement_provider := (
		TEST_PROVIDER_SCRIPT.new()
	)

	replacement_provider.set_measurement(
		20.0,
		true
	)

	var second_result: bool = (
		sensor.initialize_sensor(
			"replacement_sensor",
			replacement_bus,
			replacement_provider
		)
	)

	_expect(
		not second_result,
		"DSI-U03: second initialization is rejected"
	)

	_expect(
		sensor.device == original_device,
		"DSI-U03: original Device is preserved"
	)

	_expect(
		sensor.device_bus == original_bus,
		"DSI-U03: original DeviceBus is preserved"
	)

	_expect(
		sensor.distance_provider
		== original_provider,
		"DSI-U03: original Provider is preserved"
	)


# =============================================================================
# TEST HELPERS
# =============================================================================

func _create_sensor() -> DistanceSensorDevice:

	var sensor := DistanceSensorDevice.new()

	add_child(sensor)

	return sensor


# =============================================================================
# TEST UTILITIES
# =============================================================================

func _expect(
	condition: bool,
	description: String
) -> void:

	_check_count += 1

	if condition:
		print("[PASS] ", description)
		return

	_failure_count += 1

	push_error(
		"[FAIL] " + description
	)


func _finish_test() -> void:

	print("----------------------------------------")
	print("Checks: ", _check_count)
	print("Failures: ", _failure_count)

	if _failure_count == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")

	print("========================================")
	print("")

	get_tree().quit(
		_failure_count
	)
