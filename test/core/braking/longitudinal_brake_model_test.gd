extends Node


## LongitudinalBrakeModelTest
##
## Verifica signed opposing force, brake scaling, speed deadzone,
## fail-neutral, force bounds y separación de motion/body responsibilities.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("LongitudinalBrakeModelTest")
	print("========================================")

	_test_validation()
	_test_force_mapping()
	_test_speed_deadzone()
	_test_fail_neutral()
	_test_force_bounds()
	_test_contract()

	_finish()


func _test_validation() -> void:

	var model := _model()

	_expect(
		model.is_valid(),
		"LBM-U01: finite non-negative configuration is valid"
	)
	_expect(
		model.get_max_brake_force_newtons() == 1000.0
		and model.get_speed_deadzone_meters_per_second() == 0.1,
		"LBM-U01: configured parameters are preserved"
	)
	_expect(
		LongitudinalBrakeModel.new(0.0, 0.0).is_valid(),
		"LBM-U01: zero-force zero-deadzone model is valid"
	)
	_expect(
		not LongitudinalBrakeModel.new(-0.001, 0.0).is_valid(),
		"LBM-U02: negative maximum force is rejected"
	)
	_expect(
		not LongitudinalBrakeModel.new(NAN, 0.0).is_valid()
		and not LongitudinalBrakeModel.new(INF, 0.0).is_valid(),
		"LBM-U02: non-finite maximum force is rejected"
	)
	_expect(
		not LongitudinalBrakeModel.new(1.0, -0.001).is_valid(),
		"LBM-U02: negative speed deadzone is rejected"
	)
	_expect(
		not LongitudinalBrakeModel.new(1.0, NAN).is_valid()
		and not LongitudinalBrakeModel.new(1.0, INF).is_valid(),
		"LBM-U02: non-finite speed deadzone is rejected"
	)


func _test_force_mapping() -> void:

	var model := _model()
	var zero_force_model := LongitudinalBrakeModel.new(0.0, 0.0)

	_expect(
		model.calculate_brake_force_newtons(1.0, 10.0)
		== -1000.0,
		"LBM-U03: full brake opposes forward speed"
	)
	_expect(
		model.calculate_brake_force_newtons(1.0, -10.0)
		== 1000.0,
		"LBM-U03: full brake opposes reverse speed"
	)
	_expect(
		model.calculate_brake_force_newtons(0.25, 10.0)
		== -250.0,
		"LBM-U03: partial brake scales forward opposing force"
	)
	_expect(
		model.calculate_brake_force_newtons(0.25, -10.0)
		== 250.0,
		"LBM-U03: partial brake scales reverse opposing force"
	)
	_expect(
		model.calculate_brake_force_newtons(0.0, 10.0) == 0.0
		and model.calculate_brake_force_newtons(0.0, -10.0) == 0.0,
		"LBM-U03: zero brake produces zero signed force"
	)
	_expect(
		zero_force_model.calculate_brake_force_newtons(1.0, 10.0)
		== 0.0,
		"LBM-U03: zero-force model remains neutral"
	)


func _test_speed_deadzone() -> void:

	var model := _model()

	_expect(
		model.calculate_brake_force_newtons(1.0, 0.0) == 0.0,
		"LBM-U04: rest produces zero force"
	)
	_expect(
		model.calculate_brake_force_newtons(1.0, 0.1) == 0.0,
		"LBM-U04: exact positive deadzone boundary is neutral"
	)
	_expect(
		model.calculate_brake_force_newtons(1.0, -0.1) == 0.0,
		"LBM-U04: exact negative deadzone boundary is neutral"
	)
	_expect(
		model.calculate_brake_force_newtons(1.0, 0.1001)
		== -1000.0,
		"LBM-U04: speed above positive deadzone enables braking"
	)
	_expect(
		model.calculate_brake_force_newtons(1.0, -0.1001)
		== 1000.0,
		"LBM-U04: speed below negative deadzone enables braking"
	)


func _test_fail_neutral() -> void:

	var model := _model()
	var invalid_model := LongitudinalBrakeModel.new(-1.0, 0.1)

	_expect(
		model.calculate_brake_force_newtons(-0.0001, 10.0)
		== 0.0,
		"LBM-U05: negative brake input fails neutral"
	)
	_expect(
		model.calculate_brake_force_newtons(1.0001, 10.0)
		== 0.0,
		"LBM-U05: brake overflow fails neutral"
	)
	_expect(
		model.calculate_brake_force_newtons(NAN, 10.0) == 0.0
		and model.calculate_brake_force_newtons(INF, 10.0) == 0.0,
		"LBM-U05: non-finite brake input fails neutral"
	)
	_expect(
		model.calculate_brake_force_newtons(1.0, NAN) == 0.0
		and model.calculate_brake_force_newtons(1.0, INF) == 0.0,
		"LBM-U05: non-finite speed fails neutral"
	)
	_expect(
		invalid_model.calculate_brake_force_newtons(1.0, 10.0)
		== 0.0,
		"LBM-U05: invalid model fails neutral"
	)


func _test_force_bounds() -> void:

	var model := _model()

	_expect(
		model.is_force_within_limits(-1000.0)
		and model.is_force_within_limits(1000.0),
		"LBM-U06: exact signed force limits are valid"
	)
	_expect(
		model.is_force_within_limits(0.0),
		"LBM-U06: neutral force is valid"
	)
	_expect(
		not model.is_force_within_limits(-1000.001)
		and not model.is_force_within_limits(1000.001),
		"LBM-U06: signed force overflow is rejected"
	)
	_expect(
		not model.is_force_within_limits(NAN)
		and not model.is_force_within_limits(INF),
		"LBM-U06: non-finite force is rejected"
	)


func _test_contract() -> void:

	var model := _model()

	_expect(
		model.has_method(&"get_max_brake_force_newtons")
		and model.has_method(&"get_speed_deadzone_meters_per_second")
		and not model.has_method(&"set_max_brake_force_newtons"),
		"LBM-U07: model exposes read-only configuration API"
	)
	_expect(
		not model.has_method(&"get_longitudinal_speed_meters_per_second")
		and not model.has_method(&"apply_brake_force")
		and not model.has_method(&"get_device_bus"),
		"LBM-U07: model owns no motion source, sink or Bus API"
	)
	_expect(
		not model.has_method(&"apply_force")
		and not model.has_method(&"get_rigid_body")
		and not model.has_method(&"set_speed_deadzone_meters_per_second"),
		"LBM-U07: model owns no spatial physics or mutation API"
	)


func _model() -> LongitudinalBrakeModel:

	return LongitudinalBrakeModel.new(1000.0, 0.1)


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
