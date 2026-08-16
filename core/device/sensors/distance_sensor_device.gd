extends Node
class_name DistanceSensorDevice


var device: Device
var device_bus: DeviceBus
var distance_provider : Object


func initialize_sensor(
	sensor_id: String,
	bus: DeviceBus,
	provider: Object
) -> bool:
	if device != null:
		return false
		
	if not provider.has_method("get_distance"):
		return false

	if not provider.has_method("is_valid"):
		return false

	device = Device.new()
	device_bus = bus
	distance_provider = provider

	device.get_identity().device_id = sensor_id
	device.get_identity().device_type = "distance_sensor"

	device.get_manifest().capabilities.append(
		"distance_measurement"
	)

	device.get_manifest().publishes.append(
		BusTopics.DISTANCE_MEASUREMENT
	)

	add_child(device)

	return device.initialize()


func set_ready() -> bool:
	if device == null:
		return false

	return device.set_ready()


func start() -> bool:
	if device == null:
		return false

	return device.start()


func shutdown() -> bool:
	if device == null:
		return false

	return device.shutdown()

func publish_measurement() -> void:

	if device == null:
		return

	if device_bus == null:
		return

	if distance_provider == null:
		return

	var measurement := DistanceMeasurement.new()

	measurement.distance = (
		distance_provider.get_distance()
	)

	measurement.valid = (
		distance_provider.is_valid()
	)

	measurement.timestamp = (
		Time.get_ticks_msec() / 1000.0
	)

	var message := BusMessage.new(
		device.get_identity().get_device_id(),
		BusTopics.DISTANCE_MEASUREMENT,
		measurement.timestamp,
		measurement
	)

	if not message.is_valid():
		return

	device_bus.publish(
		message.get_topic(),
		message
	)
