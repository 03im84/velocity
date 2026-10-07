extends Node


## DistanceNoiseModelTest
##
## Verifica bias, noise acotado, quantization, sequence determinista,
## modo baseline, fail-neutral y separación de source/provider.


class SequenceNoiseSource:
	extends RefCounted

	var _samples: Array[float] = []
	var _index: int = 0

	func _init(samples: Array[float]) -> void:
		_samples.assign(samples)

	func next_normalized_sample() -> float:
		if _index >= _samples.size():
			return 0.0

		var sample := _samples[_index]
		_index += 1
		return sample


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DistanceNoiseModelTest")
	print("========================================")

	_test_validation()
	_test_bias_and_noise_bounds()
	_test_quantization()
	_test_deterministic_sequence()
	_test_zero_configuration()
	_test_fail_neutral()
	_test_distance_validation()
	_test_contract()

	_finish()


func _test_validation() -> void:

	var model := _model()

	_expect(
		model.is_valid(),
		"DNM-U01: finite non-negative configuration is valid"
	)
	_expect(
		model.get_max_abs_noise_meters() == 0.5
		and model.get_quantization_step_meters() == 0.0
		and model.get_bias_meters() == 0.25,
		"DNM-U01: configured values are preserved"
	)
	_expect(
		DistanceNoiseModel.new(0.0, 0.0, 0.0).is_valid(),
		"DNM-U01: zero-noise baseline configuration is valid"
	)
	_expect(
		not DistanceNoiseModel.new(-0.001, 0.0, 0.0).is_valid(),
		"DNM-U02: negative maximum noise is rejected"
	)
	_expect(
		not DistanceNoiseModel.new(NAN, 0.0, 0.0).is_valid()
		and not DistanceNoiseModel.new(INF, 0.0, 0.0).is_valid(),
		"DNM-U02: non-finite maximum noise is rejected"
	)
	_expect(
		not DistanceNoiseModel.new(0.0, -0.001, 0.0).is_valid(),
		"DNM-U02: negative quantization step is rejected"
	)
	_expect(
		not DistanceNoiseModel.new(0.0, NAN, 0.0).is_valid()
		and not DistanceNoiseModel.new(0.0, INF, 0.0).is_valid(),
		"DNM-U02: non-finite quantization step is rejected"
	)
	_expect(
		not DistanceNoiseModel.new(0.0, 0.0, NAN).is_valid()
		and not DistanceNoiseModel.new(0.0, 0.0, INF).is_valid(),
		"DNM-U02: non-finite bias is rejected"
	)


func _test_bias_and_noise_bounds() -> void:

	var model := _model()
	var negative_model := DistanceNoiseModel.new(1.0, 0.0, -0.5)

	_expect(
		model.condition_distance_meters(10.0, 0.0) == 10.25,
		"DNM-U03: zero sample applies bias without noise"
	)
	_expect(
		model.condition_distance_meters(10.0, 1.0) == 10.75,
		"DNM-U03: positive unit sample applies maximum noise"
	)
	_expect(
		model.condition_distance_meters(10.0, -1.0) == 9.75,
		"DNM-U03: negative unit sample applies minimum noise"
	)
	_expect(
		model.condition_distance_meters(10.0, 2.0) == 10.75,
		"DNM-U03: high sample clamps to positive noise bound"
	)
	_expect(
		model.condition_distance_meters(10.0, -2.0) == 9.75,
		"DNM-U03: low sample clamps to negative noise bound"
	)
	_expect(
		negative_model.condition_distance_meters(0.25, -1.0)
		== 0.0,
		"DNM-U03: negative conditioned distance clamps to zero"
	)


func _test_quantization() -> void:

	var quantized := DistanceNoiseModel.new(0.0, 0.1, 0.0)
	var ordered := DistanceNoiseModel.new(0.02, 0.1, 0.04)
	var negative_model := DistanceNoiseModel.new(0.0, 0.5, -1.0)
	var baseline_model := DistanceNoiseModel.new(0.0, 0.0, 0.0)

	_expect(
		is_equal_approx(
			quantized.condition_distance_meters(1.04, 0.0),
			1.0
		),
		"DNM-U04: distance below midpoint rounds down"
	)
	_expect(
		is_equal_approx(
			quantized.condition_distance_meters(1.06, 0.0),
			1.1
		),
		"DNM-U04: distance above midpoint rounds up"
	)
	_expect(
		is_equal_approx(
			ordered.condition_distance_meters(1.0, 1.0),
			1.1
		),
		"DNM-U04: quantization follows bias and bounded noise"
	)
	_expect(
		negative_model.condition_distance_meters(0.25, 0.0)
		== 0.0,
		"DNM-U04: non-negative clamp occurs before quantization"
	)
	_expect(
		baseline_model.condition_distance_meters(1.234567, 0.0)
		== 1.234567,
		"DNM-U04: zero quantization step preserves precision"
	)


func _test_deterministic_sequence() -> void:

	var model := DistanceNoiseModel.new(0.5, 0.0, 0.0)
	var first_source := SequenceNoiseSource.new(
		[-1.0, 0.5, 1.0]
	)
	var second_source := SequenceNoiseSource.new(
		[-1.0, 0.5, 1.0]
	)
	var first_outputs := _condition_sequence(
		model,
		first_source,
		5.0,
		3
	)
	var second_outputs := _condition_sequence(
		model,
		second_source,
		5.0,
		3
	)

	_expect(
		first_outputs == [4.5, 5.25, 5.5],
		"DNM-U05: explicit sequence produces expected outputs"
	)
	_expect(
		second_outputs == first_outputs,
		"DNM-U05: equal sequences produce equal outputs"
	)
	_expect(
		first_source.next_normalized_sample() == 0.0,
		"DNM-U05: test source exhaustion is deterministic"
	)


func _test_zero_configuration() -> void:

	var model := DistanceNoiseModel.new(0.0, 0.0, 0.0)

	_expect(
		model.condition_distance_meters(0.0, -1.0) == 0.0,
		"DNM-U06: zero distance remains zero in baseline mode"
	)
	_expect(
		model.condition_distance_meters(12.345, -1.0) == 12.345
		and model.condition_distance_meters(12.345, 1.0) == 12.345,
		"DNM-U06: samples cannot alter zero-noise baseline"
	)
	_expect(
		model.condition_distance_meters(999.125, 0.25) == 999.125,
		"DNM-U06: baseline mode preserves arbitrary valid distance"
	)


func _test_fail_neutral() -> void:

	var model := _model()
	var invalid_model := DistanceNoiseModel.new(-1.0, 0.0, 0.0)

	_expect(
		model.condition_distance_meters(-0.001, 0.0) == 0.0,
		"DNM-U07: negative raw distance fails neutral"
	)
	_expect(
		model.condition_distance_meters(NAN, 0.0) == 0.0
		and model.condition_distance_meters(INF, 0.0) == 0.0,
		"DNM-U07: non-finite raw distance fails neutral"
	)
	_expect(
		model.condition_distance_meters(1.0, NAN) == 0.0
		and model.condition_distance_meters(1.0, INF) == 0.0,
		"DNM-U07: non-finite sample fails neutral"
	)
	_expect(
		invalid_model.condition_distance_meters(1.0, 0.0) == 0.0,
		"DNM-U07: invalid model fails neutral"
	)


func _test_distance_validation() -> void:

	var model := _model()
	var invalid_model := DistanceNoiseModel.new(-1.0, 0.0, 0.0)

	_expect(
		model.is_distance_valid(0.0)
		and model.is_distance_valid(1000.0),
		"DNM-U08: finite non-negative outputs are valid"
	)
	_expect(
		not model.is_distance_valid(-0.001)
		and not model.is_distance_valid(NAN)
		and not model.is_distance_valid(INF),
		"DNM-U08: invalid distance outputs are rejected"
	)
	_expect(
		not invalid_model.is_distance_valid(0.0),
		"DNM-U08: invalid model cannot validate outputs"
	)


func _test_contract() -> void:

	var model := _model()

	_expect(
		not model.has_method(&"set_max_abs_noise_meters")
		and not model.has_method(&"set_quantization_step_meters")
		and not model.has_method(&"set_bias_meters"),
		"DNM-U09: model exposes no public mutation API"
	)
	_expect(
		not model.has_method(&"next_normalized_sample")
		and not model.has_method(&"seed")
		and not model.has_method(&"randomize"),
		"DNM-U09: model owns no source or RNG responsibility"
	)
	_expect(
		not model.has_method(&"sample")
		and not model.has_method(&"enqueue")
		and not model.has_method(&"get_distance")
		and not model.has_method(&"apply_force"),
		"DNM-U09: model owns no provider, latency or physics API"
	)


func _condition_sequence(
	model: DistanceNoiseModel,
	source: SequenceNoiseSource,
	raw_distance_meters: float,
	count: int
) -> Array[float]:

	var outputs: Array[float] = []

	for _index in range(count):
		outputs.append(
			model.condition_distance_meters(
				raw_distance_meters,
				source.next_normalized_sample()
			)
		)

	return outputs


func _model() -> DistanceNoiseModel:

	return DistanceNoiseModel.new(0.5, 0.0, 0.25)


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
