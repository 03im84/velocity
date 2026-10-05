extends Node


## LongitudinalPropulsionModelTest
##
## Verifica límites, transferencia forward/reverse, fail-neutral,
## bounds de fuerza y ausencia de responsabilidad física espacial.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("LongitudinalPropulsionModelTest")
	print("========================================")

	_test_validation()
	_test_force_mapping()
	_test_fail_neutral()
	_test_force_bounds()
	_test_contract()

	_finish()


func _test_validation() -> void:

	var model := LongitudinalPropulsionModel.new(1200.0, 300.0)

	_expect(
		model.is_valid(),
		"LPM-U01: finite non-negative limits are valid"
	)
	_expect(
		model.get_max_forward_force_newtons() == 1200.0
		and model.get_max_reverse_force_newtons() == 300.0,
		"LPM-U01: configured limits are preserved"
	)
	_expect(
		LongitudinalPropulsionModel.new(0.0, 0.0).is_valid(),
		"LPM-U01: fully neutral model is valid"
	)
	_expect(
		LongitudinalPropulsionModel.new(1200.0, 0.0).is_valid(),
		"LPM-U01: reverse-disabled model is valid"
	)
	_expect(
		not LongitudinalPropulsionModel.new(-0.001, 0.0).is_valid(),
		"LPM-U02: negative forward limit is rejected"
	)
	_expect(
		not LongitudinalPropulsionModel.new(0.0, -0.001).is_valid(),
		"LPM-U02: negative reverse limit is rejected"
	)
	_expect(
		not LongitudinalPropulsionModel.new(NAN, 0.0).is_valid(),
		"LPM-U02: NAN forward limit is rejected"
	)
	_expect(
		not LongitudinalPropulsionModel.new(0.0, NAN).is_valid(),
		"LPM-U02: NAN reverse limit is rejected"
	)
	_expect(
		not LongitudinalPropulsionModel.new(INF, 0.0).is_valid(),
		"LPM-U02: infinite forward limit is rejected"
	)
	_expect(
		not LongitudinalPropulsionModel.new(0.0, INF).is_valid(),
		"LPM-U02: infinite reverse limit is rejected"
	)


func _test_force_mapping() -> void:

	var model := LongitudinalPropulsionModel.new(1200.0, 300.0)

	_expect(
		model.calculate_force_newtons(0.5) == 600.0,
		"LPM-U03: forward thrust maps linearly"
	)
	_expect(
		model.calculate_force_newtons(1.0) == 1200.0,
		"LPM-U03: forward boundary reaches forward limit"
	)
	_expect(
		model.calculate_force_newtons(-0.5) == -150.0,
		"LPM-U03: reverse thrust maps linearly"
	)
	_expect(
		model.calculate_force_newtons(-1.0) == -300.0,
		"LPM-U03: reverse boundary reaches reverse limit"
	)
	_expect(
		model.calculate_force_newtons(0.0) == 0.0,
		"LPM-U03: neutral thrust maps to neutral force"
	)
	_expect(
		LongitudinalPropulsionModel.new(
			1200.0,
			0.0
		).calculate_force_newtons(-1.0) == 0.0,
		"LPM-U03: disabled reverse fails neutral"
	)


func _test_fail_neutral() -> void:

	var model := LongitudinalPropulsionModel.new(1200.0, 300.0)
	var invalid_model := LongitudinalPropulsionModel.new(-1.0, 300.0)

	_expect(
		model.calculate_force_newtons(1.0001) == 0.0,
		"LPM-U04: forward overflow fails neutral"
	)
	_expect(
		model.calculate_force_newtons(-1.0001) == 0.0,
		"LPM-U04: reverse overflow fails neutral"
	)
	_expect(
		model.calculate_force_newtons(NAN) == 0.0,
		"LPM-U04: NAN thrust fails neutral"
	)
	_expect(
		model.calculate_force_newtons(INF) == 0.0,
		"LPM-U04: infinite thrust fails neutral"
	)
	_expect(
		invalid_model.calculate_force_newtons(0.5) == 0.0,
		"LPM-U04: invalid model fails neutral"
	)


func _test_force_bounds() -> void:

	var model := LongitudinalPropulsionModel.new(1200.0, 300.0)

	_expect(
		model.is_force_within_limits(-300.0)
		and model.is_force_within_limits(1200.0),
		"LPM-U05: exact force boundaries are accepted"
	)
	_expect(
		model.is_force_within_limits(0.0),
		"LPM-U05: neutral force is accepted"
	)
	_expect(
		not model.is_force_within_limits(1200.001),
		"LPM-U05: forward force overflow is rejected"
	)
	_expect(
		not model.is_force_within_limits(-300.001),
		"LPM-U05: reverse force overflow is rejected"
	)
	_expect(
		not model.is_force_within_limits(NAN)
		and not model.is_force_within_limits(INF),
		"LPM-U05: non-finite force is rejected"
	)


func _test_contract() -> void:

	var model := LongitudinalPropulsionModel.new(1200.0, 300.0)

	_expect(
		model.has_method(&"get_max_forward_force_newtons")
		and model.has_method(&"get_max_reverse_force_newtons")
		and not model.has_method(&"set_max_forward_force_newtons")
		and not model.has_method(&"set_max_reverse_force_newtons"),
		"LPM-U06: model exposes read-only limit API"
	)
	_expect(
		not model.has_method(&"apply_force")
		and not model.has_method(&"apply_central_force")
		and not model.has_method(&"get_force_vector")
		and not model.has_method(&"get_device_bus"),
		"LPM-U06: model has no Bus or spatial physics API"
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
