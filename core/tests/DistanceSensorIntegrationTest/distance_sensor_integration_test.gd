extends Node3D

@onready var device_bus: DeviceBus = $DeviceBus
@onready var distance_sensor: DistanceSensorDevice = $DistanceSensor
@onready var distance_provider: PhysicsDistanceProvider = $PhysicsDistanceProvider

func _enter_tree() -> void:
	print(">>> ENTER TREE")

func _ready() -> void:
	print(">>> READY")
	
	await get_tree().physics_frame
	
	device_bus.subscribe(
	BusTopics.DISTANCE_MEASUREMENT,
	Callable(self, "_on_distance_measurement")
	)

	var initialized := distance_sensor.initialize_sensor(
		"distance_sensor_physics_test",
		device_bus,
		distance_provider
	)

	print("Initialize: ", initialized)

	if not initialized:
		return

	print(
		"Provider valid: ",
		distance_provider.is_valid()
	)

	print(
		"Provider distance: ",
		distance_provider.get_distance()
	)

	print(">>> Antes de publicar")
	distance_sensor.publish_measurement()
	print(">>> Después de publicar")

func _on_distance_measurement(message: BusMessage) -> void:
	var measurement: DistanceMeasurement = message.get_data()["measurement"]

	print("Distance measurement received!")
	print("Source: ", message.source_id)
	print("Distance: ", measurement.distance)
	print("Valid: ", measurement.valid)
