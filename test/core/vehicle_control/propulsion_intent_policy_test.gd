extends Node


## PropulsionIntentPolicyTest
##
## Verifica neutral/forward/reverse intent, brake attenuation, input
## clamping, non-finite fail-neutral y responsibility boundary.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("PropulsionIntentPolicyTest")
	print("========================================")

	_test_baseline_mapping()
	_test_brake_attenuation()
	_test_input_clamping()
	_test_non_finite_fail_neutral()
	_test_output_validation()
	_test_contract()

	_finish()


func _test_baseline_mapping() -> void:

	var policy := PropulsionIntentPolicy.new()

	_expect(
		policy.calculate_normalized_thrust(0.0, 0.0) == 0.0,
		"PIP-U01: neutral inputs produce neutral thrust"
	)
	_expect(
		policy.calculate_normalized_thrust(1.0, 0.0) == 1.0,
		"PIP-U01: full forward throttle is preserved"
	)
	_expect(
		policy.calculate_normalized_thrust(-1.0, 0.0) == -1.0,
		"PIP-U01: full reverse throttle is preserved"
	)


func _test_brake_attenuation() -> void:

	var policy := PropulsionIntentPolicy.new()

	_expect(
		policy.calculate_normalized_thrust(1.0, 0.25) == 0.75,
		"PIP-U02: partial brake attenuates forward throttle"
	)
	_expect(
		policy.calculate_normalized_thrust(-0.8, 0.5) == -0.4,
		"PIP-U02: partial brake attenuates reverse throttle"
	)
	_expect(
		policy.calculate_normalized_thrust(1.0, 1.0) == 0.0
		and policy.calculate_normalized_thrust(-1.0, 1.0) == 0.0,
		"PIP-U02: full brake suppresses signed throttle"
	)


func _test_input_clamping() -> void:

	var policy := PropulsionIntentPolicy.new()

	_expect(
		policy.calculate_normalized_thrust(2.0, 0.0) == 1.0,
		"PIP-U03: positive throttle overflow clamps"
	)
	_expect(
		policy.calculate_normalized_thrust(-2.0, 0.0) == -1.0,
		"PIP-U03: negative throttle overflow clamps"
	)
	_expect(
		policy.calculate_normalized_thrust(0.5, -1.0) == 0.5,
		"PIP-U03: negative brake clamps to zero"
	)
	_expect(
		policy.calculate_normalized_thrust(0.5, 2.0) == 0.0,
		"PIP-U03: brake overflow clamps to one"
	)


func _test_non_finite_fail_neutral() -> void:

	var policy := PropulsionIntentPolicy.new()

	_expect(
		policy.calculate_normalized_thrust(NAN, 0.0) == 0.0,
		"PIP-U04: NAN throttle fails neutral"
	)
	_expect(
		policy.calculate_normalized_thrust(INF, 0.0) == 0.0
		and policy.calculate_normalized_thrust(-INF, 0.0) == 0.0,
		"PIP-U04: infinite throttle fails neutral"
	)
	_expect(
		policy.calculate_normalized_thrust(1.0, NAN) == 0.0,
		"PIP-U04: NAN brake fails neutral"
	)
	_expect(
		policy.calculate_normalized_thrust(1.0, INF) == 0.0
		and policy.calculate_normalized_thrust(1.0, -INF) == 0.0,
		"PIP-U04: infinite brake fails neutral"
	)


func _test_output_validation() -> void:

	var policy := PropulsionIntentPolicy.new()

	_expect(
		policy.is_normalized_thrust_valid(-1.0)
		and policy.is_normalized_thrust_valid(0.0)
		and policy.is_normalized_thrust_valid(1.0),
		"PIP-U05: exact finite output range is valid"
	)
	_expect(
		not policy.is_normalized_thrust_valid(-1.001)
		and not policy.is_normalized_thrust_valid(1.001)
		and not policy.is_normalized_thrust_valid(NAN)
		and not policy.is_normalized_thrust_valid(INF),
		"PIP-U05: out-of-range/non-finite output is invalid"
	)


func _test_contract() -> void:

	var policy := PropulsionIntentPolicy.new()

	_expect(
		not policy.has_method(&"publish")
		and not policy.has_method(&"route")
		and not policy.has_method(&"create_command")
		and not policy.has_method(&"get_device_bus"),
		"PIP-U06: policy owns no Bus, routing or Command creation"
	)
	_expect(
		not policy.has_method(&"apply_force")
		and not policy.has_method(&"get_rigid_body")
		and not policy.has_method(&"set_throttle")
		and not policy.has_method(&"set_brake"),
		"PIP-U06: policy owns no physics or mutable intent state"
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
