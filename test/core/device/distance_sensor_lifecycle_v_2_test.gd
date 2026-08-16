extends Node


##
## DistanceSensorLifecycleV2Test
##
## Prueba sucesora del lifecycle de
## DistanceSensorDevice con Device RefCounted
## y DeviceLifecycle canónico.
##


const TEST_PROVIDER_SCRIPT := preload(
	"res://test/core/device/"
	+ "distance_sensor_test_provider.gd"
)


var _check_count: int = 0
var _failure_count: int = 0

var _received_message_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DistanceSensorLifecycleV2Test")
	print("========================================")

	var bus := DeviceBus.new()

	var provider := TEST_PROVIDER_SCRIPT.new()

	provider.set_measurement(
		12.5,
		true
	)

	var sensor := DistanceSensorDevice.new()

	add_child(sensor)

	_expect(
		bus.subscribe(
			BusTopics.DISTANCE_MEASUREMENT,
			_on_distance_message
		),
		"DSL2-I01: consumer is subscribed"
	)

	var initialized: bool = (
		sensor.initialize_sensor(
			"distance_sensor_lifecycle_v2",
			bus,
			provider
		)
	)

	_expect(
		initialized,
		"DSL2-I01: sensor initializes"
	)

	_expect(
		sensor.device != null,
		"DSL2-I01: Device exists"
	)

	if sensor.device == null:
		_finish_test()
		return

	var device_as_variant: Variant = (
		sensor.device
	)

	_expect(
		device_as_variant is RefCounted,
		"DSL2-I01: Device is RefCounted"
	)

	_expect(
		not (device_as_variant is Node),
		"DSL2-I01: Device is not Node"
	)

	_expect(
		sensor.get_child_count() == 0,
		"DSL2-I01: Device is not a Sensor child"
	)

	_expect(
		sensor.device.get_lifecycle().get_state()
		== DeviceLifecycle.State.INITIALIZED,
		"DSL2-I02: state is INITIALIZED"
	)

	# ---------------------------------------------------------
	# READY
	# ---------------------------------------------------------

	_expect(
		sensor.set_ready(),
		"DSL2-I02: set_ready succeeds"
	)

	_expect(
		sensor.device.get_lifecycle().get_state()
		== DeviceLifecycle.State.READY,
		"DSL2-I02: state is READY"
	)

	# ---------------------------------------------------------
	# RUNNING
	# ---------------------------------------------------------

	_expect(
		sensor.start(),
		"DSL2-I02: start succeeds"
	)

	_expect(
		sensor.device.get_lifecycle().get_state()
		== DeviceLifecycle.State.RUNNING,
		"DSL2-I02: state is RUNNING"
	)

	# ---------------------------------------------------------
	# PUBLICATION BEFORE SHUTDOWN
	# ---------------------------------------------------------

	sensor.publish_measurement()

	_expect(
		_received_message_count == 1,
		"DSL2-I03: running Sensor publishes"
	)

	var original_device: Device = sensor.device

	# ---------------------------------------------------------
	# SHUTDOWN
	# ---------------------------------------------------------

	_expect(
		sensor.shutdown(),
		"DSL2-I04: shutdown succeeds"
	)

	_expect(
		sensor.device.get_lifecycle().get_state()
		== DeviceLifecycle.State.SHUTDOWN,
		"DSL2-I04: state is SHUTDOWN"
	)

	_expect(
		sensor.device == original_device,
		"DSL2-I04: Device remains available"
	)

	_expect(
		sensor.device_bus == null,
		"DSL2-I04: DeviceBus reference is released"
	)

	_expect(
		sensor.distance_provider == null,
		"DSL2-I04: Provider reference is released"
	)

	# ---------------------------------------------------------
	# PUBLICATION AFTER SHUTDOWN
	# ---------------------------------------------------------

	sensor.publish_measurement()

	_expect(
		_received_message_count == 1,
		"DSL2-I04: shutdown Sensor does not publish"
	)

	# ---------------------------------------------------------
	# SECOND SHUTDOWN
	# ---------------------------------------------------------

	_expect(
		not sensor.shutdown(),
		"DSL2-I04: second shutdown is rejected"
	)

	_expect(
		sensor.device.get_lifecycle().get_state()
		== DeviceLifecycle.State.SHUTDOWN,
		"DSL2-I04: second shutdown preserves state"
	)

	_finish_test()


# =============================================================================
# CONSUMER
# =============================================================================

func _on_distance_message(
	_message: BusMessage
) -> void:

	_received_message_count += 1


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
