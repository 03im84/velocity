extends Node


## HoverStabilityPolicyTest
##
## Simula un punto de masa 1D bajo gravedad con timestep fijo.
## Verifica bounds, finitud, oscilación decreciente y convergencia.


const MASS_KILOGRAMS: float = 1000.0
const GRAVITY_METERS_PER_SECOND_SQUARED: float = 9.81
const TARGET_HEIGHT_METERS: float = 2.0
const INITIAL_HEIGHT_METERS: float = 0.5
const DELTA_SECONDS: float = 1.0 / 120.0
const DURATION_SECONDS: float = 10.0
const STEP_COUNT: int = 1200


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("HoverStabilityPolicyTest")
	print("========================================")

	_test_deterministic_stability()
	_finish()


func _test_deterministic_stability() -> void:

	var model := HoverSpringDamperModel.new(
		TARGET_HEIGHT_METERS,
		9810.0,
		20000.0,
		8000.0,
		30000.0,
		0.1
	)
	var height_meters := INITIAL_HEIGHT_METERS
	var velocity_meters_per_second := 0.0
	var minimum_height := height_meters
	var maximum_height := height_meters
	var maximum_force := 0.0
	var all_finite: bool = true
	var all_forces_bounded: bool = true
	var state_bounded: bool = true
	var previous_velocity := velocity_meters_per_second
	var turning_point_errors: Array[float] = []

	for _step: int in range(STEP_COUNT):
		var lift_force := model.calculate_lift_force_newtons(
			height_meters,
			velocity_meters_per_second
		)
		var acceleration := (
			(lift_force / MASS_KILOGRAMS)
			- GRAVITY_METERS_PER_SECOND_SQUARED
		)

		velocity_meters_per_second += (
			acceleration * DELTA_SECONDS
		)
		height_meters += (
			velocity_meters_per_second
			* DELTA_SECONDS
		)

		minimum_height = minf(
			minimum_height,
			height_meters
		)
		maximum_height = maxf(
			maximum_height,
			height_meters
		)
		maximum_force = maxf(
			maximum_force,
			lift_force
		)

		all_finite = (
			all_finite
			and is_finite(lift_force)
			and is_finite(acceleration)
			and is_finite(velocity_meters_per_second)
			and is_finite(height_meters)
		)
		all_forces_bounded = (
			all_forces_bounded
			and model.is_force_within_limits(lift_force)
		)
		state_bounded = (
			state_bounded
			and absf(height_meters) < 100.0
			and absf(velocity_meters_per_second) < 100.0
		)

		if (
			previous_velocity > 0.0
			and velocity_meters_per_second <= 0.0
			or previous_velocity < 0.0
			and velocity_meters_per_second >= 0.0
		):
			turning_point_errors.append(
				absf(
					TARGET_HEIGHT_METERS
					- height_meters
				)
			)

		previous_velocity = velocity_meters_per_second

	var final_error := absf(
		TARGET_HEIGHT_METERS - height_meters
	)
	var initial_error := absf(
		TARGET_HEIGHT_METERS - INITIAL_HEIGHT_METERS
	)
	var turning_errors_decrease := (
		_turning_errors_strictly_decrease(
			turning_point_errors
		)
	)
	var final_lift := model.calculate_lift_force_newtons(
		height_meters,
		velocity_meters_per_second
	)

	_expect(
		model.is_valid(),
		"HSP-I01: canonical stability model is valid"
	)
	_expect(
		STEP_COUNT
		== int(DURATION_SECONDS / DELTA_SECONDS),
		"HSP-I01: fixture executes exact fixed-timestep duration"
	)
	_expect(
		all_finite,
		"HSP-I01: every simulated state remains finite"
	)
	_expect(
		all_forces_bounded
		and maximum_force <= 30000.0,
		"HSP-I01: lift remains within model bounds"
	)
	_expect(
		state_bounded,
		"HSP-I01: height and velocity never grow without bound"
	)
	_expect(
		minimum_height >= INITIAL_HEIGHT_METERS,
		"HSP-I02: fixture never crosses its initial safe floor"
	)
	_expect(
		maximum_height < 2.1,
		"HSP-I02: overshoot remains inside safe height bound"
	)
	_expect(
		final_error < initial_error
		and final_error < 0.01,
		"HSP-I02: final height converges near target"
	)
	_expect(
		absf(velocity_meters_per_second) < 0.01,
		"HSP-I02: final vertical velocity converges near zero"
	)
	_expect(
		turning_point_errors.size() >= 3,
		"HSP-I03: fixture observes multiple oscillation extrema"
	)
	_expect(
		turning_errors_decrease,
		"HSP-I03: successive oscillation errors strictly decrease"
	)
	_expect(
		is_equal_approx(final_lift, 9810.0),
		"HSP-I03: converged lift equals equilibrium force"
	)


func _turning_errors_strictly_decrease(
	errors: Array[float]
) -> bool:

	if errors.size() < 2:
		return false

	for index: int in range(1, errors.size()):
		if errors[index] >= errors[index - 1]:
			return false

	return true


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
