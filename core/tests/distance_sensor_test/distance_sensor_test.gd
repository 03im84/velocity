extends Node

var distance_provider := ManualDistanceProvider.new()

@onready var device_bus: DeviceBus = $DeviceBus
@onready var distance_sensor: DistanceSensorDevice = $DistanceSensor


func _ready() -> void:
	print("Initializing distance sensor...")
	
	distance_provider.set_distance(12.5)

	var initialized := distance_sensor.initialize_sensor(
		"distance_sensor_test",
		device_bus,
		distance_provider
	)

	print("Initialize: ", initialized)

	print(
		"Lifecycle: ",
		distance_sensor.device.get_lifecycle().get_state()
	)

	var ready_result := distance_sensor.set_ready()

	print("Ready: ", ready_result)

	print(
		"Lifecycle: ",
		distance_sensor.device.get_lifecycle().get_state()
	)

	var started := distance_sensor.start()

	print("Start: ", started)
	
	device_bus.subscribe(
	BusTopics.DISTANCE_MEASUREMENT,
	_on_distance_measurement
	)

	print(
		"Lifecycle: ",
		distance_sensor.device.get_lifecycle().get_state()
	)

	print(
		"Device ID: ",
		distance_sensor.device.get_identity().get_device_id()
	)

	print(
		"Device Type: ",
		distance_sensor.device.get_identity().get_device_type()
	)

	print(
		"Can measure distance: ",
		distance_sensor.device.get_manifest().has_capability(
			"distance_measurement"
		)
	)
	
	print("\n")
	distance_sensor.publish_measurement()
	
func _on_distance_measurement(message: BusMessage) -> void:
	print("Distance measurement received!")

	print(
		"Source: ",
		message.source_id
	)

	var measurement: DistanceMeasurement = (
		message.get_data()["measurement"]
	)

	print(
		"Distance: ",
		measurement.distance
	)

	print(
		"Valid: ",
		measurement.valid
	)
