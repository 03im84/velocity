extends Node
class_name DistanceSensorDevice


##
## DistanceSensorDevice
##
## Device especializado que obtiene datos
## desde un Distance Provider y publica
## DistanceMeasurement mediante DeviceBus.
##
## Compone un Device lógico RefCounted.
##


var device: Device = null

var device_bus: DeviceBus = null

var distance_provider: Object = null


# =============================================================================
# INITIALIZATION
# =============================================================================

func initialize_sensor(
	sensor_id: String,
	bus: DeviceBus,
	provider: Object
) -> bool:

	if device != null:
		return false

	if sensor_id.is_empty():
		return false

	if bus == null:
		return false

	if provider == null:
		return false

	if not provider.has_method(
		&"get_distance"
	):
		return false

	if not provider.has_method(
		&"is_valid"
	):
		return false

	var new_device := Device.new()

	new_device.get_identity().device_id = (
		sensor_id
	)

	new_device.get_identity().device_type = (
		"distance_sensor"
	)

	new_device.get_manifest().capabilities.append(
		"distance_measurement"
	)

	new_device.get_manifest().publishes.append(
		BusTopics.DISTANCE_MEASUREMENT
	)

	if not new_device.initialize():
		return false

	device = new_device
	device_bus = bus
	distance_provider = provider

	return true


# =============================================================================
# LIFECYCLE
# =============================================================================

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

	var shutdown_result: bool = (
		device.shutdown()
	)

	if not shutdown_result:
		return false

	device_bus = null
	distance_provider = null

	return true


# =============================================================================
# MEASUREMENT
# =============================================================================

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
