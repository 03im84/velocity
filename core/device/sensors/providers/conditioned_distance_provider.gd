extends RefCounted
class_name ConditionedDistanceProvider


## ConditionedDistanceProvider
##
## Adapter stateful que captura un Distance Provider, aplica un
## DistanceNoiseModel y madura distance/validity mediante una cola
## BoundedLatencyBuffer dedicada.
##
## Conserva Last Known Good distance cuando madura una lectura inválida.
## No conoce DeviceBus, DistanceMeasurement, RuntimeUnit o SceneTree.
## Vehicle Environment and Realism Addendum.


class ConditionedSample:
	extends RefCounted

	var distance_meters: float
	var valid: bool

	func _init(
		p_distance_meters: float,
		p_valid: bool
	) -> void:
		distance_meters = p_distance_meters
		valid = p_valid


var _raw_provider: Object
var _noise_model: DistanceNoiseModel
var _noise_source: Object
var _latency_buffer: BoundedLatencyBuffer
var _distance_meters: float = 0.0
var _current_valid: bool = false


func _init(
	raw_provider: Object,
	noise_model: DistanceNoiseModel,
	noise_source: Object,
	latency_buffer: BoundedLatencyBuffer
) -> void:

	_raw_provider = raw_provider
	_noise_model = noise_model
	_noise_source = noise_source
	_latency_buffer = latency_buffer


func get_distance() -> float:

	return _distance_meters


func is_valid() -> bool:

	return _current_valid


func get_pending_count() -> int:

	if (
		_latency_buffer == null
		or not is_instance_valid(_latency_buffer)
	):
		return 0

	return _latency_buffer.get_pending_count()


func get_max_pending_entries() -> int:

	if (
		_latency_buffer == null
		or not is_instance_valid(_latency_buffer)
	):
		return 0

	return _latency_buffer.get_max_entries()


func sample(
	capture_timestamp: float
) -> bool:

	if not is_configuration_valid():
		return false

	if (
		not is_finite(capture_timestamp)
		or capture_timestamp < 0.0
	):
		return false

	_release_ready(capture_timestamp)

	var captured_sample := _capture_sample()

	if not _latency_buffer.enqueue(
		captured_sample,
		capture_timestamp
	):
		return false

	_release_ready(capture_timestamp)
	return true


func clear() -> void:

	if (
		_latency_buffer != null
		and is_instance_valid(_latency_buffer)
	):
		_latency_buffer.clear()

	_distance_meters = 0.0
	_current_valid = false


func is_configuration_valid() -> bool:

	if (
		_raw_provider == null
		or not is_instance_valid(_raw_provider)
		or not _raw_provider.has_method(&"get_distance")
		or not _raw_provider.has_method(&"is_valid")
	):
		return false

	if (
		_noise_model == null
		or not is_instance_valid(_noise_model)
		or not _noise_model.is_valid()
	):
		return false

	if (
		_latency_buffer == null
		or not is_instance_valid(_latency_buffer)
		or not _latency_buffer.is_valid()
	):
		return false

	if _noise_source == null:
		return _noise_model.get_max_abs_noise_meters() == 0.0

	return (
		is_instance_valid(_noise_source)
		and _noise_source.has_method(&"next_normalized_sample")
	)


func _capture_sample() -> ConditionedSample:

	var raw_valid_value: Variant = _raw_provider.is_valid()

	if (
		typeof(raw_valid_value) != TYPE_BOOL
		or not raw_valid_value
	):
		return ConditionedSample.new(0.0, false)

	var raw_distance_value: Variant = _raw_provider.get_distance()

	if not _variant_is_number(raw_distance_value):
		return ConditionedSample.new(0.0, false)

	var raw_distance_meters := float(raw_distance_value)

	if (
		not is_finite(raw_distance_meters)
		or raw_distance_meters < 0.0
	):
		return ConditionedSample.new(0.0, false)

	var normalized_noise_sample: float = 0.0

	if _noise_model.get_max_abs_noise_meters() > 0.0:
		var noise_value: Variant = (
			_noise_source.next_normalized_sample()
		)

		if not _variant_is_number(noise_value):
			return ConditionedSample.new(0.0, false)

		normalized_noise_sample = float(noise_value)

		if not is_finite(normalized_noise_sample):
			return ConditionedSample.new(0.0, false)

	var conditioned_distance := (
		_noise_model.condition_distance_meters(
			raw_distance_meters,
			normalized_noise_sample
		)
	)

	if not _noise_model.is_distance_valid(conditioned_distance):
		return ConditionedSample.new(0.0, false)

	return ConditionedSample.new(
		conditioned_distance,
		true
	)


func _release_ready(
	current_timestamp: float
) -> void:

	var release_budget := _latency_buffer.get_max_entries()

	while (
		release_budget > 0
		and _latency_buffer.has_ready(current_timestamp)
	):
		var ready_value: Variant = (
			_latency_buffer.dequeue_ready(current_timestamp)
		)
		release_budget -= 1

		if not (ready_value is ConditionedSample):
			_current_valid = false
			continue

		var ready_sample: ConditionedSample = ready_value

		if ready_sample.valid:
			_distance_meters = ready_sample.distance_meters

		_current_valid = ready_sample.valid


func _variant_is_number(
	value: Variant
) -> bool:

	return (
		typeof(value) == TYPE_FLOAT
		or typeof(value) == TYPE_INT
	)
