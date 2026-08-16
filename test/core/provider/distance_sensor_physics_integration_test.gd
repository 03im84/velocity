extends Node3D


##
## DistanceSensorPhysicsIntegrationTest
##
## Verifica el recorrido físico completo:
##
## PhysicsDistanceProvider
##         ↓
## DistanceSensorDevice
##         ↓
## DistanceMeasurement
##         ↓
## BusMessage
##         ↓
## DeviceBus
##         ↓
## Consumer
##


@onready var _distance_sensor: DistanceSensorDevice = (
	$DistanceSensor
)

@onready var _physics_provider: PhysicsDistanceProvider = (
	$PhysicsDistanceProvider
)


var _check_count: int = 0
var _failure_count: int = 0

var _received_messages: Array[BusMessage] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("DistanceSensorPhysicsIntegrationTest")
	print("========================================")

	await get_tree().physics_frame

	var bus := DeviceBus.new()

	_expect(
		bus.subscribe(
			BusTopics.DISTANCE_MEASUREMENT,
			_on_distance_message
		),
		"DSP-I01: consumer is subscribed"
	)

	var initialized: bool = (
		_distance_sensor.initialize_sensor(
			"distance_sensor_physics_test",
			bus,
			_physics_provider
		)
	)

	_expect(
		initialized,
		"DSP-I01: sensor initializes successfully"
	)

	if not initialized:
		_finish_test()
		return

	_expect(
		_distance_sensor.device != null,
		"DSP-I01: internal Device exists"
	)

	_expect(
		_physics_provider.is_valid(),
		"DSP-I02: Physics Provider is valid"
	)

	var provider_distance: float = (
		_physics_provider.get_distance()
	)

	_expect(
		provider_distance > 4.8
		and provider_distance < 5.0,
		"DSP-I02: Provider distance matches geometry"
	)

	_distance_sensor.publish_measurement()

	_expect(
		_received_messages.size() == 1,
		"DSP-I02: one message is received"
	)

	if _received_messages.is_empty():
		_finish_test()
		return

	var message: BusMessage = (
		_received_messages[0]
	)

	_expect(
		message.is_valid(),
		"DSP-I03: BusMessage is valid"
	)

	_expect(
		message.get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"DSP-I03: message uses distance topic"
	)

	_expect(
		message.get_source_id()
		== "distance_sensor_physics_test",
		"DSP-I03: source ID matches Sensor"
	)

	var payload: Variant = message.get_payload()

	_expect(
		payload is DistanceMeasurement,
		"DSP-I03: payload is DistanceMeasurement"
	)

	if not (payload is DistanceMeasurement):
		_finish_test()
		return

	var measurement: DistanceMeasurement = payload

	_expect(
		measurement.valid,
		"DSP-I03: measurement is valid"
	)

	_expect(
		measurement.distance > 4.8
		and measurement.distance < 5.0,
		"DSP-I03: measurement distance matches geometry"
	)

	_expect(
		abs(
			measurement.distance
			- provider_distance
		) < 0.001,
		"DSP-I03: measurement matches Provider"
	)

	_expect(
		message.get_timestamp()
		== measurement.timestamp,
		"DSP-I03: timestamps are consistent"
	)

	_expect(
		get_node_or_null(
			"DeviceBus"
		) == null,
		"DSP-I04: DeviceBus is not a Node"
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
