class_name BusDebugListener
extends RefCounted


var _bus: DeviceBus = null
var _enabled: bool = true


func attach(bus: DeviceBus) -> void:
	if _bus != null:
		detach()

	_bus = bus

	_bus.subscribe(
		BusTopics.DISTANCE_MEASUREMENT,
		Callable(self, "_on_distance_measurement")
	)


func detach() -> void:
	if _bus == null:
		return

	# Lo implementaremos cuando DeviceBus tenga unsubscribe()
	_bus = null


func set_enabled(value: bool) -> void:
	_enabled = value


func _on_distance_measurement(message: BusMessage) -> void:
	if not _enabled:
		return

	var measurement: DistanceMeasurement = \
		message.get_data()["measurement"]

	print("--------------------------------------")
	print("Topic    :", message.topic)
	print("Source   :", message.source_id)
	print("Distance :", measurement.distance)
	print("Valid    :", measurement.valid)
	print("--------------------------------------")
