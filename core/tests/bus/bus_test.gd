extends Node

@onready var device_bus: DeviceBus = $DeviceBus


func _ready() -> void:
	device_bus.subscribe(
		BusTopics.TEST_MESSAGE,
		_on_test_message
	)

	var message := BusMessage.new()

	message.source_id = "test_publisher"
	message.topic = BusTopics.TEST_MESSAGE
	message.timestamp = Time.get_ticks_msec() / 1000.0
	message.set_data({
		"value": 42,
		"text": "Hello Velocity"
	})

	print("Publishing message...")

	device_bus.publish(message)


func _on_test_message(message: BusMessage) -> void:
	print("Message received!")
	print("Source: ", message.source_id)
	print("Topic: ", message.topic)
	print("Data: ", message.get_data())
