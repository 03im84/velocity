extends Node


##
## DistanceSensorLifecycleTest
##
## Prueba sucesora del comportamiento de
## lifecycle verificado anteriormente en:
##
## core/tests/distance_sensor_test/
##
## No verifica publicación ni mensajes.
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
	print("DistanceSensorLifecycleTest")
	print("========================================")

	var bus := DeviceBus.new()

	var provider := TEST_PROVIDER_SCRIPT.new()

	provider.set_measurement(
		12.5,
		true
	)

	var sensor := DistanceSensorDevice.new()

	add_child(sensor)

	# ---------------------------------------------------------
	# INITIALIZE
	# ---------------------------------------------------------

	var initialized: bool = (
		sensor.initialize_sensor(
			"distance_sensor_lifecycle_test",
			bus,
			provider
		)
	)

	_expect(
		initialized,
		"DS-L01: sensor initializes successfully"
	)

	_expect(
		sensor.device != null,
		"DS-L01: internal Device exists"
	)

	if sensor.device == null:
		_finish_test()
		return

	_expect(
		sensor.device.get_lifecycle().get_state()
		== DeviceLifeCycle.State.INITIALIZED,
		"DS-L01: state is INITIALIZED"
	)

	# ---------------------------------------------------------
	# READY
	# ---------------------------------------------------------

	var ready_result: bool = sensor.set_ready()

	_expect(
		ready_result,
		"DS-L01: set_ready succeeds"
	)

	_expect(
		sensor.device.get_lifecycle().get_state()
		== DeviceLifeCycle.State.READY,
		"DS-L01: state is READY"
	)

	# ---------------------------------------------------------
	# RUNNING
	# ---------------------------------------------------------

	var start_result: bool = sensor.start()

	_expect(
		start_result,
		"DS-L01: start succeeds"
	)

	_expect(
		sensor.device.get_lifecycle().get_state()
		== DeviceLifeCycle.State.RUNNING,
		"DS-L01: state is RUNNING"
	)

	# ---------------------------------------------------------
	# SHUTDOWN
	# ---------------------------------------------------------

	var shutdown_result: bool = sensor.shutdown()

	_expect(
		shutdown_result,
		"DS-L01: shutdown succeeds"
	)

	_expect(
		sensor.device.get_lifecycle().get_state()
		== DeviceLifeCycle.State.SHUTDOWN,
		"DS-L01: state is SHUTDOWN"
	)

	_finish_test()


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
