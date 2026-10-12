extends RefCounted
class_name PropulsionIntentPolicy


## PropulsionIntentPolicy
##
## Policy pura/stateless que combina throttle y brake intent para producir
## normalized propulsion thrust. Inputs finitos fuera de range se acotan;
## inputs no finitos fallan neutral.
##
## No conoce Commands, DeviceBus, models, sinks o física.
## ADR-017 / Playable Vehicle Composition Design 1.1.


func calculate_normalized_thrust(
	throttle: float,
	brake: float
) -> float:

	if not is_finite(throttle) or not is_finite(brake):
		return 0.0

	var bounded_throttle := clampf(throttle, -1.0, 1.0)
	var bounded_brake := clampf(brake, 0.0, 1.0)
	var normalized_thrust := (
		bounded_throttle * (1.0 - bounded_brake)
	)

	if not is_finite(normalized_thrust):
		return 0.0

	return clampf(normalized_thrust, -1.0, 1.0)


func is_normalized_thrust_valid(
	normalized_thrust: float
) -> bool:

	return (
		is_finite(normalized_thrust)
		and normalized_thrust >= -1.0
		and normalized_thrust <= 1.0
	)
