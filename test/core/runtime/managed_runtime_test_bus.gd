extends DeviceBus


## Controlled DeviceBus rejection behavior for Binder tests.


var reject_subscribe: bool = false
var reject_unsubscribe: bool = false


func subscribe(
	topic: StringName,
	subscriber: Callable
) -> bool:

	if reject_subscribe:
		return false

	return super.subscribe(topic, subscriber)


func unsubscribe(
	topic: StringName,
	subscriber: Callable
) -> bool:

	if reject_unsubscribe:
		return false

	return super.unsubscribe(topic, subscriber)
