extends Node


##
## DistanceSensorMessageTest
##
## Verifica que DistanceSensorDevice publique
## el contrato BusMessage nuevo mediante
## una Composition Root explícita.
##


const TEST_PROVIDER_SCRIPT := preload(
	"res://test/core/device/"
	+ "distance_sensor_test_provider.gd"
)


var _check_count: int = 0
var _failure_count: int = 0

var _received_messages: Array[BusMessage] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("DistanceSensorMessageTest")
	print("========================================")

	var bus := DeviceBus.new()

	var provider := TEST_PROVIDER_SCRIPT.new()

	provider.set_measurement(
		12.5,
		true
	)

	var sensor := DistanceSensorDevice.new()

	add_child(sensor)

	var initialized: bool = (
		sensor.initialize_sensor(
			"distance_sensor_message_test",
			bus,
			provider
		)
	)

	_expect(
		initialized,
		"DS-I01: sensor initializes successfully"
	)

	_expect(
		sensor.device != null,
		"DS-I01: internal Device is created"
	)

	_expect(
		sensor.device.get_identity().get_device_id()
		== "distance_sensor_message_test",
		"DS-I01: Device identity is preserved"
	)

	_expect(
		sensor.device.get_manifest().publishes_topic(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"DS-I01: manifest declares distance topic"
	)

	_expect(
		bus.subscribe(
			BusTopics.DISTANCE_MEASUREMENT,
			_on_distance_message
		),
		"DS-I01: consumer is subscribed"
	)

	sensor.publish_measurement()

	_expect(
		_received_messages.size() == 1,
		"DS-I01: one message is received"
	)

	if _received_messages.is_empty():
		_finish_test()
		return

	var message: BusMessage = (
		_received_messages[0]
	)

	_expect(
		message.is_valid(),
		"DS-I01: published message is valid"
	)

	_expect(
		message.get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"DS-I01: envelope contains canonical topic"
	)

	_expect(
		message.get_source_id()
		== "distance_sensor_message_test",
		"DS-I01: envelope contains Device ID"
	)

	var payload: Variant = message.get_payload()

	_expect(
		payload is DistanceMeasurement,
		"DS-I01: payload is DistanceMeasurement"
	)

	if not (payload is DistanceMeasurement):
		_finish_test()
		return

	var measurement: DistanceMeasurement = payload

	_expect(
		measurement.distance == 12.5,
		"DS-I01: measurement preserves distance"
	)

	_expect(
		measurement.valid,
		"DS-I01: measurement preserves validity"
	)

	_expect(
		message.get_timestamp()
		== measurement.timestamp,
		"DS-I01: envelope and payload share timestamp"
	)

	_expect(
		measurement.timestamp >= 0.0,
		"DS-I01: timestamp is generated"
	)

	_finish_test()


# =============================================================================
# CONSUMER
# =============================================================================

func _on_distance_message(
	message: BusMessage
) -> void:

	_received_messages.append(message)


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
