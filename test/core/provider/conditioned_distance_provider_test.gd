extends Node


## ConditionedDistanceProviderTest
##
## Verifica conditioning pipeline, latency, bounded overflow,
## Last Known Good, zero-noise baseline y provider compatibility.


class SequenceNoiseSource:
	extends RefCounted

	var _samples: Array[float] = []
	var _index: int = 0
	var _call_count: int = 0

	func _init(samples: Array[float]) -> void:
		_samples.assign(samples)

	func next_normalized_sample() -> float:
		_call_count += 1

		if _index >= _samples.size():
			return 0.0

		var sample := _samples[_index]
		_index += 1
		return sample

	func get_call_count() -> int:
		return _call_count


class InvalidValidityProvider:
	extends RefCounted

	func get_distance() -> float:
		return 2.0

	func is_valid() -> String:
		return "invalid_contract"


class InvalidDistanceProvider:
	extends RefCounted

	func get_distance() -> String:
		return "invalid_contract"

	func is_valid() -> bool:
		return true


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("ConditionedDistanceProviderTest")
	print("========================================")

	_test_configuration_validation()
	_test_zero_delay_baseline()
	_test_noise_and_quantization_pipeline()
	_test_delayed_release()
	_test_last_known_good()
	_test_invalid_noise_sample()
	_test_capacity_monotonicity_and_clear()
	_test_dynamic_provider_contracts()
	_test_responsibility_boundary()

	_finish()


func _test_configuration_validation() -> void:

	var raw_provider := ManualDistanceProvider.new()
	var zero_model := DistanceNoiseModel.new(0.0, 0.0, 0.0)
	var noise_model := DistanceNoiseModel.new(0.5, 0.0, 0.0)
	var source := SequenceNoiseSource.new([0.0])
	var buffer := BoundedLatencyBuffer.new(0.0, 4)
	var provider := ConditionedDistanceProvider.new(
		raw_provider,
		zero_model,
		null,
		buffer
	)

	_expect(
		provider.is_configuration_valid(),
		"CDP-U01: zero-noise configuration permits null source"
	)
	_expect(
		not provider.is_valid()
		and provider.get_distance() == 0.0,
		"CDP-U01: provider begins without a matured reading"
	)
	_expect(
		provider.get_pending_count() == 0
		and provider.get_max_pending_entries() == 4,
		"CDP-U01: queue observability exposes bounded capacity"
	)
	_expect(
		not ConditionedDistanceProvider.new(
			raw_provider,
			noise_model,
			null,
			BoundedLatencyBuffer.new(0.0, 1)
		).is_configuration_valid(),
		"CDP-U02: active noise requires an explicit source"
	)
	_expect(
		ConditionedDistanceProvider.new(
			raw_provider,
			noise_model,
			source,
			BoundedLatencyBuffer.new(0.0, 1)
		).is_configuration_valid(),
		"CDP-U02: source contract satisfies active noise"
	)
	_expect(
		not ConditionedDistanceProvider.new(
			null,
			zero_model,
			null,
			BoundedLatencyBuffer.new(0.0, 1)
		).is_configuration_valid()
		and not ConditionedDistanceProvider.new(
			RefCounted.new(),
			zero_model,
			null,
			BoundedLatencyBuffer.new(0.0, 1)
		).is_configuration_valid(),
		"CDP-U02: raw provider contract is required"
	)
	_expect(
		not ConditionedDistanceProvider.new(
			raw_provider,
			DistanceNoiseModel.new(-1.0, 0.0, 0.0),
			null,
			BoundedLatencyBuffer.new(0.0, 1)
		).is_configuration_valid(),
		"CDP-U02: invalid noise model is rejected"
	)
	_expect(
		not ConditionedDistanceProvider.new(
			raw_provider,
			zero_model,
			null,
			BoundedLatencyBuffer.new(-1.0, 1)
		).is_configuration_valid(),
		"CDP-U02: invalid latency buffer is rejected"
	)
	_expect(
		not ConditionedDistanceProvider.new(
			raw_provider,
			zero_model,
			RefCounted.new(),
			BoundedLatencyBuffer.new(0.0, 1)
		).is_configuration_valid(),
		"CDP-U02: provided source must satisfy source contract"
	)


func _test_zero_delay_baseline() -> void:

	var raw_provider := ManualDistanceProvider.new()
	var provider := _provider(raw_provider, 0.0, 4)
	raw_provider.set_distance(5.25)

	_expect(
		provider.sample(1.0),
		"CDP-U03: valid zero-delay sample is accepted"
	)
	_expect(
		provider.is_valid()
		and provider.get_distance() == 5.25,
		"CDP-U03: zero-delay baseline matures immediately"
	)
	_expect(
		provider.get_pending_count() == 0,
		"CDP-U03: immediate sample leaves no pending entry"
	)

	raw_provider.set_distance(7.5)

	_expect(
		provider.sample(2.0)
		and provider.is_valid()
		and provider.get_distance() == 7.5,
		"CDP-U03: repeated sampling replaces current reading"
	)


func _test_noise_and_quantization_pipeline() -> void:

	var raw_provider := ManualDistanceProvider.new()
	var source := SequenceNoiseSource.new([-1.0, 1.0])
	var provider := ConditionedDistanceProvider.new(
		raw_provider,
		DistanceNoiseModel.new(0.5, 0.0, 0.25),
		source,
		BoundedLatencyBuffer.new(0.0, 2)
	)
	raw_provider.set_distance(10.0)

	_expect(
		provider.sample(0.0)
		and provider.get_distance() == 9.75,
		"CDP-U04: first explicit noise sample conditions distance"
	)
	_expect(
		provider.sample(1.0)
		and provider.get_distance() == 10.75
		and source.get_call_count() == 2,
		"CDP-U04: sequence source advances once per valid capture"
	)

	var clamped_source := SequenceNoiseSource.new([2.0])
	var clamped_provider := ConditionedDistanceProvider.new(
		raw_provider,
		DistanceNoiseModel.new(0.5, 0.0, 0.0),
		clamped_source,
		BoundedLatencyBuffer.new(0.0, 1)
	)

	_expect(
		clamped_provider.sample(0.0)
		and clamped_provider.get_distance() == 10.5,
		"CDP-U04: model clamps out-of-range finite source sample"
	)

	var quantized_provider := ConditionedDistanceProvider.new(
		raw_provider,
		DistanceNoiseModel.new(0.0, 0.1, 0.04),
		null,
		BoundedLatencyBuffer.new(0.0, 1)
	)
	raw_provider.set_distance(1.02)

	_expect(
		quantized_provider.sample(0.0)
		and is_equal_approx(
			quantized_provider.get_distance(),
			1.1
		),
		"CDP-U04: provider composes bias and quantization"
	)

	var unused_source := SequenceNoiseSource.new([1.0])
	var zero_noise_provider := ConditionedDistanceProvider.new(
		raw_provider,
		DistanceNoiseModel.new(0.0, 0.0, 0.0),
		unused_source,
		BoundedLatencyBuffer.new(0.0, 1)
	)

	_expect(
		zero_noise_provider.sample(0.0)
		and unused_source.get_call_count() == 0,
		"CDP-U04: zero-noise mode does not consume source state"
	)


func _test_delayed_release() -> void:

	var raw_provider := ManualDistanceProvider.new()
	var provider := _provider(raw_provider, 1.0, 4)
	raw_provider.set_distance(3.0)

	_expect(
		provider.sample(0.0)
		and not provider.is_valid()
		and provider.get_pending_count() == 1,
		"CDP-U05: delayed sample remains pending"
	)

	raw_provider.set_distance(4.0)

	_expect(
		provider.sample(0.5)
		and not provider.is_valid()
		and provider.get_pending_count() == 2,
		"CDP-U05: later sample queues behind first"
	)

	raw_provider.set_distance(5.0)

	_expect(
		provider.sample(1.0)
		and provider.is_valid()
		and provider.get_distance() == 3.0
		and provider.get_pending_count() == 2,
		"CDP-U05: first sample matures at release boundary"
	)

	raw_provider.set_distance(6.0)

	_expect(
		provider.sample(1.5)
		and provider.get_distance() == 4.0,
		"CDP-U05: FIFO maturity advances Last Known Good"
	)


func _test_last_known_good() -> void:

	var raw_provider := ManualDistanceProvider.new()
	var source := SequenceNoiseSource.new([0.0, 1.0])
	var provider := ConditionedDistanceProvider.new(
		raw_provider,
		DistanceNoiseModel.new(0.5, 0.0, 0.0),
		source,
		BoundedLatencyBuffer.new(0.0, 2)
	)
	raw_provider.set_distance(5.0)
	provider.sample(0.0)

	_expect(
		provider.is_valid()
		and provider.get_distance() == 5.0,
		"CDP-U06: valid sample establishes Last Known Good"
	)

	raw_provider.invalidate()

	_expect(
		provider.sample(1.0)
		and not provider.is_valid()
		and provider.get_distance() == 5.0,
		"CDP-U06: invalid sample preserves Last Known Good distance"
	)
	_expect(
		source.get_call_count() == 1,
		"CDP-U06: invalid raw reading does not consume noise source"
	)

	raw_provider.set_distance(6.0)

	_expect(
		provider.sample(2.0)
		and provider.is_valid()
		and provider.get_distance() == 6.5
		and source.get_call_count() == 2,
		"CDP-U06: later valid sample restores validity"
	)


func _test_invalid_noise_sample() -> void:

	var raw_provider := ManualDistanceProvider.new()
	var source := SequenceNoiseSource.new([0.0, NAN])
	var provider := ConditionedDistanceProvider.new(
		raw_provider,
		DistanceNoiseModel.new(0.5, 0.0, 0.0),
		source,
		BoundedLatencyBuffer.new(0.0, 2)
	)
	raw_provider.set_distance(8.0)
	provider.sample(0.0)
	raw_provider.set_distance(9.0)

	_expect(
		provider.sample(1.0),
		"CDP-U07: invalid source reading is captured explicitly"
	)
	_expect(
		not provider.is_valid()
		and provider.get_distance() == 8.0,
		"CDP-U07: invalid source preserves Last Known Good"
	)


func _test_capacity_monotonicity_and_clear() -> void:

	var raw_provider := ManualDistanceProvider.new()
	var provider := _provider(raw_provider, 10.0, 2)
	raw_provider.set_distance(1.0)

	_expect(
		provider.sample(1.0)
		and provider.sample(2.0),
		"CDP-U08: queue accepts entries up to capacity"
	)
	_expect(
		not provider.sample(3.0)
		and provider.get_pending_count() == 2,
		"CDP-U08: full queue reports rejection without growth"
	)

	raw_provider.set_distance(4.0)

	_expect(
		provider.sample(11.0)
		and provider.is_valid()
		and provider.get_distance() == 1.0
		and provider.get_pending_count() == 2,
		"CDP-U08: matured entry frees capacity before capture"
	)
	_expect(
		not provider.sample(0.5)
		and provider.get_pending_count() == 2,
		"CDP-U08: regressive timestamp is rejected"
	)

	provider.clear()

	_expect(
		provider.get_pending_count() == 0
		and not provider.is_valid()
		and provider.get_distance() == 0.0,
		"CDP-U08: clear resets queue and current reading"
	)
	_expect(
		provider.sample(0.5)
		and provider.get_pending_count() == 1,
		"CDP-U08: clear resets timestamp epoch"
	)


func _test_dynamic_provider_contracts() -> void:

	var zero_model := DistanceNoiseModel.new(0.0, 0.0, 0.0)
	var invalid_validity := ConditionedDistanceProvider.new(
		InvalidValidityProvider.new(),
		zero_model,
		null,
		BoundedLatencyBuffer.new(0.0, 1)
	)
	var invalid_distance := ConditionedDistanceProvider.new(
		InvalidDistanceProvider.new(),
		zero_model,
		null,
		BoundedLatencyBuffer.new(0.0, 1)
	)

	_expect(
		invalid_validity.is_configuration_valid()
		and invalid_validity.sample(0.0)
		and not invalid_validity.is_valid(),
		"CDP-U09: non-boolean validity matures as invalid"
	)
	_expect(
		invalid_distance.is_configuration_valid()
		and invalid_distance.sample(0.0)
		and not invalid_distance.is_valid(),
		"CDP-U09: non-numeric distance matures as invalid"
	)


func _test_responsibility_boundary() -> void:

	var raw_provider := ManualDistanceProvider.new()
	var provider := _provider(raw_provider, 0.0, 2)

	_expect(
		not provider.has_method(&"publish_measurement")
		and not provider.has_method(&"publish")
		and not provider.has_method(&"get_device_bus"),
		"CDP-U10: provider owns no DeviceBus or publishing API"
	)
	_expect(
		not provider.has_method(&"apply_force")
		and not provider.has_method(&"physics_process")
		and not provider.has_method(&"get_tree"),
		"CDP-U10: provider owns no physics or SceneTree API"
	)
	_expect(
		provider.get_pending_count()
		<= provider.get_max_pending_entries(),
		"CDP-U10: observable pending count is always bounded"
	)


func _provider(
	raw_provider: Object,
	delay_seconds: float,
	max_entries: int
) -> ConditionedDistanceProvider:

	return ConditionedDistanceProvider.new(
		raw_provider,
		DistanceNoiseModel.new(0.0, 0.0, 0.0),
		null,
		BoundedLatencyBuffer.new(delay_seconds, max_entries)
	)


func _expect(
	condition: bool,
	description: String
) -> void:

	_checks += 1

	if condition:
		print("[PASS] ", description)
		return

	_failures += 1
	push_error("[FAIL] " + description)


func _finish() -> void:

	print("----------------------------------------")
	print("Checks: ", _checks)
	print("Failures: ", _failures)

	if _failures == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")

	print("========================================")
	print("")
	get_tree().quit(_failures)
