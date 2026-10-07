extends RefCounted
class_name BoundedLatencyBuffer


## BoundedLatencyBuffer
##
## FIFO determinista de señales con delay fijo, timestamps monotónicos
## y capacity estricta. Rechaza newest cuando está lleno.
##
## No usa timers, threads, SceneTree o memoria no acotada.
## Vehicle Environment and Realism Addendum.


class LatencyEntry:
	extends RefCounted

	var value: Variant
	var capture_timestamp: float
	var release_timestamp: float

	func _init(
		p_value: Variant,
		p_capture_timestamp: float,
		p_release_timestamp: float
	) -> void:
		value = p_value
		capture_timestamp = p_capture_timestamp
		release_timestamp = p_release_timestamp


var _delay_seconds: float
var _max_entries: int
var _entries: Array[LatencyEntry] = []
var _has_capture_timestamp: bool = false
var _last_capture_timestamp: float = 0.0


func _init(
	delay_seconds: float,
	max_entries: int
) -> void:

	_delay_seconds = delay_seconds
	_max_entries = max_entries


func get_delay_seconds() -> float:

	return _delay_seconds


func get_max_entries() -> int:

	return _max_entries


func get_pending_count() -> int:

	return _entries.size()


func is_empty() -> bool:

	return _entries.is_empty()


func enqueue(
	value: Variant,
	capture_timestamp: float
) -> bool:

	if not is_valid():
		return false

	if value == null:
		return false

	if (
		not is_finite(capture_timestamp)
		or capture_timestamp < 0.0
	):
		return false

	if (
		_has_capture_timestamp
		and capture_timestamp < _last_capture_timestamp
	):
		return false

	if _entries.size() >= _max_entries:
		return false

	var release_timestamp := (
		capture_timestamp + _delay_seconds
	)

	if not is_finite(release_timestamp):
		return false

	_entries.append(
		LatencyEntry.new(
			value,
			capture_timestamp,
			release_timestamp
		)
	)
	_has_capture_timestamp = true
	_last_capture_timestamp = capture_timestamp
	return true


func has_ready(
	current_timestamp: float
) -> bool:

	if not _timestamp_is_valid(current_timestamp):
		return false

	if _entries.is_empty():
		return false

	var release_timestamp := _entries[0].release_timestamp

	return (
		release_timestamp <= current_timestamp
		or is_equal_approx(
			release_timestamp,
			current_timestamp
		)
	)


func dequeue_ready(
	current_timestamp: float
) -> Variant:

	if not has_ready(current_timestamp):
		return null

	var entry: LatencyEntry = _entries.pop_front()
	return entry.value


func clear() -> void:

	_entries.clear()
	_has_capture_timestamp = false
	_last_capture_timestamp = 0.0


func is_valid() -> bool:

	return (
		is_finite(_delay_seconds)
		and _delay_seconds >= 0.0
		and _max_entries > 0
	)


func _timestamp_is_valid(
	timestamp: float
) -> bool:

	return (
		is_valid()
		and is_finite(timestamp)
		and timestamp >= 0.0
	)
