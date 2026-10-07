extends Node


## HoverSpringDamperModelTest
##
## Verifica parámetros, bias de equilibrio, spring, damping,
## lift-only bounds, interval policy y ausencia de física espacial.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("HoverSpringDamperModelTest")
	print("========================================")

	_test_validation()
	_test_force_formula()
	_test_fail_neutral()
	_test_force_bounds()
	_test_sample_interval()
	_test_contract()

	_finish()


func _test_validation() -> void:

	var model := _model()

	_expect(
		model.is_valid(),
		"HSD-U01: canonical finite parameters are valid"
	)
	_expect(
		model.get_target_height_meters() == 2.0
		and model.get_equilibrium_force_newtons() == 9810.0
		and model.get_spring_stiffness_newtons_per_meter()
		== 20000.0
		and model.get_damping_newton_seconds_per_meter()
		== 8000.0
		and model.get_max_lift_force_newtons() == 30000.0
		and model.get_max_sample_interval_seconds() == 0.1,
		"HSD-U01: all configured parameters are preserved"
	)
	_expect(
		HoverSpringDamperModel.new(
			2.0,
			0.0,
			0.0,
			0.0,
			0.0,
			0.1
		).is_valid(),
		"HSD-U01: neutral zero-force model is valid"
	)
	_expect(
		not HoverSpringDamperModel.new(
			0.0, 0.0, 0.0, 0.0, 0.0, 0.1
		).is_valid()
		and not HoverSpringDamperModel.new(
			-1.0, 0.0, 0.0, 0.0, 0.0, 0.1
		).is_valid(),
		"HSD-U02: non-positive target height is rejected"
	)
	_expect(
		not HoverSpringDamperModel.new(
			NAN, 0.0, 0.0, 0.0, 0.0, 0.1
		).is_valid()
		and not HoverSpringDamperModel.new(
			INF, 0.0, 0.0, 0.0, 0.0, 0.1
		).is_valid(),
		"HSD-U02: non-finite target height is rejected"
	)
	_expect(
		not HoverSpringDamperModel.new(
			2.0, -1.0, 0.0, 0.0, 0.0, 0.1
		).is_valid()
		and not HoverSpringDamperModel.new(
			2.0, NAN, 0.0, 0.0, 0.0, 0.1
		).is_valid(),
		"HSD-U02: invalid equilibrium force is rejected"
	)
	_expect(
		not HoverSpringDamperModel.new(
			2.0, 0.0, -1.0, 0.0, 0.0, 0.1
		).is_valid()
		and not HoverSpringDamperModel.new(
			2.0, 0.0, INF, 0.0, 0.0, 0.1
		).is_valid(),
		"HSD-U02: invalid spring stiffness is rejected"
	)
	_expect(
		not HoverSpringDamperModel.new(
			2.0, 0.0, 0.0, -1.0, 0.0, 0.1
		).is_valid()
		and not HoverSpringDamperModel.new(
			2.0, 0.0, 0.0, NAN, 0.0, 0.1
		).is_valid(),
		"HSD-U02: invalid damping is rejected"
	)
	_expect(
		not HoverSpringDamperModel.new(
			2.0, 100.0, 0.0, 0.0, 99.0, 0.1
		).is_valid()
		and not HoverSpringDamperModel.new(
			2.0, 0.0, 0.0, 0.0, INF, 0.1
		).is_valid(),
		"HSD-U02: invalid maximum lift is rejected"
	)
	_expect(
		not HoverSpringDamperModel.new(
			2.0, 0.0, 0.0, 0.0, 0.0, 0.0
		).is_valid()
		and not HoverSpringDamperModel.new(
			2.0, 0.0, 0.0, 0.0, 0.0, NAN
		).is_valid(),
		"HSD-U02: invalid sample interval limit is rejected"
	)


func _test_force_formula() -> void:

	var model := _model()

	_expect(
		model.calculate_lift_force_newtons(2.0, 0.0)
		== 9810.0,
		"HSD-U03: target and zero rate produce equilibrium force"
	)
	_expect(
		model.calculate_lift_force_newtons(1.5, 0.0)
		== 19810.0,
		"HSD-U03: below-target distance adds spring lift"
	)
	_expect(
		model.calculate_lift_force_newtons(2.5, 0.0)
		== 0.0,
		"HSD-U03: above-target negative raw force clamps to zero"
	)
	_expect(
		model.calculate_lift_force_newtons(2.0, 0.5)
		== 5810.0,
		"HSD-U03: increasing distance reduces lift"
	)
	_expect(
		model.calculate_lift_force_newtons(2.0, -0.5)
		== 13810.0,
		"HSD-U03: decreasing distance increases lift"
	)
	_expect(
		model.calculate_lift_force_newtons(2.0, -10.0)
		== 30000.0,
		"HSD-U03: large falling rate clamps at maximum lift"
	)
	_expect(
		model.calculate_lift_force_newtons(2.0, 10.0)
		== 0.0,
		"HSD-U03: large rising rate remains lift-only"
	)


func _test_fail_neutral() -> void:

	var model := _model()
	var invalid_model := HoverSpringDamperModel.new(
		0.0, 0.0, 0.0, 0.0, 0.0, 0.1
	)

	_expect(
		model.calculate_lift_force_newtons(-0.1, 0.0)
		== 0.0,
		"HSD-U04: negative distance fails neutral"
	)
	_expect(
		model.calculate_lift_force_newtons(NAN, 0.0)
		== 0.0
		and model.calculate_lift_force_newtons(INF, 0.0)
		== 0.0,
		"HSD-U04: non-finite distance fails neutral"
	)
	_expect(
		model.calculate_lift_force_newtons(2.0, NAN)
		== 0.0
		and model.calculate_lift_force_newtons(2.0, INF)
		== 0.0,
		"HSD-U04: non-finite distance rate fails neutral"
	)
	_expect(
		invalid_model.calculate_lift_force_newtons(2.0, 0.0)
		== 0.0,
		"HSD-U04: invalid model fails neutral"
	)


func _test_force_bounds() -> void:

	var model := _model()

	_expect(
		model.is_force_within_limits(0.0)
		and model.is_force_within_limits(30000.0),
		"HSD-U05: exact lift boundaries are valid"
	)
	_expect(
		not model.is_force_within_limits(-0.001),
		"HSD-U05: negative force is rejected"
	)
	_expect(
		not model.is_force_within_limits(30000.001),
		"HSD-U05: maximum lift overflow is rejected"
	)
	_expect(
		not model.is_force_within_limits(NAN)
		and not model.is_force_within_limits(INF),
		"HSD-U05: non-finite force is rejected"
	)


func _test_sample_interval() -> void:

	var model := _model()

	_expect(
		model.is_sample_interval_valid(0.001)
		and model.is_sample_interval_valid(0.1),
		"HSD-U06: positive interval through exact maximum is valid"
	)
	_expect(
		not model.is_sample_interval_valid(0.0)
		and not model.is_sample_interval_valid(-0.001),
		"HSD-U06: non-positive interval is rejected"
	)
	_expect(
		not model.is_sample_interval_valid(0.1001),
		"HSD-U06: interval above maximum is rejected"
	)
	_expect(
		not model.is_sample_interval_valid(NAN)
		and not model.is_sample_interval_valid(INF),
		"HSD-U06: non-finite interval is rejected"
	)


func _test_contract() -> void:

	var model := _model()

	_expect(
		not model.has_method(&"apply_force")
		and not model.has_method(&"apply_hover_force")
		and not model.has_method(&"get_previous_sample")
		and not model.has_method(&"get_device_bus"),
		"HSD-U07: model has no sink, history, Bus or physics API"
	)
	_expect(
		not model.has_method(&"set_target_height_meters")
		and not model.has_method(&"set_max_lift_force_newtons"),
		"HSD-U07: model exposes no public mutation API"
	)


func _model() -> HoverSpringDamperModel:

	return HoverSpringDamperModel.new(
		2.0,
		9810.0,
		20000.0,
		8000.0,
		30000.0,
		0.1
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
