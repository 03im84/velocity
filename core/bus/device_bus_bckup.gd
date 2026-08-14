extends Node
#class_name DeviceBus


var subscribers: Dictionary = {}


func subscribe(topic: String, callback: Callable) -> void:
	if not subscribers.has(topic):
		subscribers[topic] = []

	if not subscribers[topic].has(callback):
		subscribers[topic].append(callback)


func unsubscribe(topic: String, callback: Callable) -> void:
	
	if not subscribers.has(topic):
		return

	subscribers[topic].erase(callback)

	if subscribers[topic].is_empty():
		subscribers.erase(topic)


func publish(message: BusMessage) -> void:
	if not message.is_valid():
		return

	if not subscribers.has(message.topic):
		return

	for callback: Callable in subscribers[message.topic]:
		if callback.is_valid():
			callback.call(message)
