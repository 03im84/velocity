extends RefCounted
class_name DistanceNoiseModel


## DistanceNoiseModel
##
## Snapshot inmutable y sin estado RNG que aplica bias, noise acotado
## y quantization opcional a una distancia no negativa.
##
## El normalized sample es explícito. La fuente determinista/seedable
## pertenece al futuro ConditionedDistanceProvider.
## Vehicle Environment and Realism Addendum.


var _max_abs_noise_meters: float
var _quantization_step_meters: float
var _bias_meters: float


func _init(
	max_abs_noise_meters: float,
	quantization_step_meters: float,
	bias_meters: float
) -> void:

	_max_abs_noise_meters = max_abs_noise_meters
	_quantization_step_meters = quantization_step_meters
	_bias_meters = bias_meters


func get_max_abs_noise_meters() -> float:

	return _max_abs_noise_meters


func get_quantization_step_meters() -> float:

	return _quantization_step_meters


func get_bias_meters() -> float:

	return _bias_meters


func condition_distance_meters(
	raw_distance_meters: float,
	normalized_noise_sample: float
) -> float:

	if not is_valid():
		return 0.0

	if (
		not is_finite(raw_distance_meters)
		or raw_distance_meters < 0.0
		or not is_finite(normalized_noise_sample)
	):
		return 0.0

	var bounded_sample := clampf(
		normalized_noise_sample,
		-1.0,
		1.0
	)
	var bounded_noise_meters := (
		bounded_sample * _max_abs_noise_meters
	)
	var conditioned_distance_meters := maxf(
		0.0,
		raw_distance_meters
		+ _bias_meters
		+ bounded_noise_meters
	)

	if not is_finite(conditioned_distance_meters):
		return 0.0

	if _quantization_step_meters == 0.0:
		return conditioned_distance_meters

	var quantization_units := floorf(
		(conditioned_distance_meters / _quantization_step_meters)
		+ 0.5
	)
	var quantized_distance_meters := (
		quantization_units * _quantization_step_meters
	)

	if not is_finite(quantized_distance_meters):
		return 0.0

	return maxf(0.0, quantized_distance_meters)


func is_distance_valid(
	distance_meters: float
) -> bool:

	return (
		is_valid()
		and is_finite(distance_meters)
		and distance_meters >= 0.0
	)


func is_valid() -> bool:

	return (
		is_finite(_max_abs_noise_meters)
		and is_finite(_quantization_step_meters)
		and is_finite(_bias_meters)
		and _max_abs_noise_meters >= 0.0
		and _quantization_step_meters >= 0.0
	)
