extends RefCounted


## Shared ordered trace for CompositionRuntime integration test doubles.


var _events: Array[String] = []


func record_event(
	event: String
) -> void:

	_events.append(event)


func get_events(
) -> Array[String]:

	return _events.duplicate()


func get_event_count(
	event: String
) -> int:

	var count: int = 0

	for recorded_event: String in _events:
		if recorded_event == event:
			count += 1

	return count


func clear(
) -> void:

	_events.clear()
