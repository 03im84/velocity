extends Node


##
## BusDebugListenerIntegrationTest
##
## Verifica attach(), detach() y recepción
## de BusMessage mediante DeviceBus.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("BusDebugListenerIntegrationTest")
	print("========================================")

	var bus_a := DeviceBus.new()
	var bus_b := DeviceBus.new()

	var listener := BusDebugListener.new()

	# ---------------------------------------------------------
	# ATTACH
	# ---------------------------------------------------------

	listener.attach(bus_a)

	_expect(
		bus_a.get_subscriber_count(
			BusTopics.DISTANCE_MEASUREMENT
		) == 1,
		"BD-I01: attach creates one subscription"
	)

	# ---------------------------------------------------------
	# SECOND ATTACH TO SAME BUS
	# ---------------------------------------------------------

	listener.attach(bus_a)

	_expect(
		bus_a.get_subscriber_count(
			BusTopics.DISTANCE_MEASUREMENT
		) == 1,
		"BD-I01: second attach does not duplicate subscription"
	)

	# ---------------------------------------------------------
	# MOVE TO ANOTHER BUS
	# ---------------------------------------------------------

	listener.attach(bus_b)

	_expect(
		bus_a.get_subscriber_count(
			BusTopics.DISTANCE_MEASUREMENT
		) == 0,
		"BD-I01: previous Bus loses subscription"
	)

	_expect(
		bus_b.get_subscriber_count(
			BusTopics.DISTANCE_MEASUREMENT
		) == 1,
		"BD-I01: new Bus receives subscription"
	)

	# ---------------------------------------------------------
	# PUBLISH DISTANCE MESSAGE
	# ---------------------------------------------------------

	var measurement := DistanceMeasurement.new()

	measurement.distance = 7.5
	measurement.valid = true
	measurement.timestamp = 21.0

	var message := BusMessage.new(
		"distance_sensor_debug_test",
		BusTopics.DISTANCE_MEASUREMENT,
		measurement.timestamp,
		measurement
	)

	_expect(
		message.is_valid(),
		"BD-I01: debug message is valid"
	)

	bus_b.publish(
		message.get_topic(),
		message
	)

	# ---------------------------------------------------------
	# DETACH
	# ---------------------------------------------------------

	listener.detach()

	_expect(
		bus_b.get_subscriber_count(
			BusTopics.DISTANCE_MEASUREMENT
		) == 0,
		"BD-I01: detach removes subscription"
	)

	listener.detach()

	_expect(
		bus_b.get_subscriber_count(
			BusTopics.DISTANCE_MEASUREMENT
		) == 0,
		"BD-I01: repeated detach is safe"
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
