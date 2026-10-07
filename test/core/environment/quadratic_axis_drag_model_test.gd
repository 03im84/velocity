extends Node


## QuadraticAxisDragModelTest
##
## Verifica dirección opuesta, dependencia de density/speed²,
## vacuum, force clamp y ausencia de responsabilidad espacial.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("QuadraticAxisDragModelTest")
	print("========================================")

	_test_validation()
	_test_quadratic_drag()
	_test_environment_variation()
	_test_fail_neutral()
	_test_force_bounds()
	_test_contract()

	_finish()


func _test_validation() -> void:

	var model := _model()

	_expect(
		model.is_valid(),
		"QAD-U01: finite non-negative parameters are valid"
	)
	_expect(
		model.get_drag_coefficient() == 1.0
		and model.get_reference_area_square_meters() == 2.0
		and model.get_max_abs_drag_force_newtons() == 5000.0,
		"QAD-U01: configured parameters are preserved"
	)
	_expect(
		QuadraticAxisDragModel.new(0.0, 0.0, 0.0).is_valid(),
		"QAD-U01: zero-drag model is valid"
	)
	_expect(
		not QuadraticAxisDragModel.new(-0.001, 1.0, 1.0).is_valid(),
		"QAD-U02: negative coefficient is rejected"
	)
	_expect(
		not QuadraticAxisDragModel.new(1.0, -0.001, 1.0).is_valid(),
		"QAD-U02: negative reference area is rejected"
	)
	_expect(
		not QuadraticAxisDragModel.new(1.0, 1.0, -0.001).is_valid(),
		"QAD-U02: negative force limit is rejected"
	)
	_expect(
		not QuadraticAxisDragModel.new(NAN, 1.0, 1.0).is_valid()
		and not QuadraticAxisDragModel.new(INF, 1.0, 1.0).is_valid(),
		"QAD-U02: non-finite coefficient is rejected"
	)
	_expect(
		not QuadraticAxisDragModel.new(1.0, NAN, 1.0).is_valid()
		and not QuadraticAxisDragModel.new(1.0, INF, 1.0).is_valid(),
		"QAD-U02: non-finite area is rejected"
	)
	_expect(
		not QuadraticAxisDragModel.new(1.0, 1.0, NAN).is_valid()
		and not QuadraticAxisDragModel.new(1.0, 1.0, INF).is_valid(),
		"QAD-U02: non-finite force limit is rejected"
	)


func _test_quadratic_drag() -> void:

	var model := _model()

	_expect(
		is_equal_approx(
			model.calculate_drag_force_newtons(10.0, 1.225),
			-122.5
		),
		"QAD-U03: positive speed produces expected negative drag"
	)
	_expect(
		is_equal_approx(
			model.calculate_drag_force_newtons(-10.0, 1.225),
			122.5
		),
		"QAD-U03: negative speed produces expected positive drag"
	)
	_expect(
		model.calculate_drag_force_newtons(0.0, 1.225)
		== 0.0,
		"QAD-U03: zero speed produces zero drag"
	)
	_expect(
		is_equal_approx(
			model.calculate_drag_force_newtons(20.0, 1.225),
			-490.0
		),
		"QAD-U03: doubling speed quadruples drag magnitude"
	)


func _test_environment_variation() -> void:

	var model := _model()
	var earth_drag := model.calculate_drag_force_newtons(
		10.0,
		1.225
	)
	var thin_air_drag := model.calculate_drag_force_newtons(
		10.0,
		0.1225
	)

	_expect(
		is_equal_approx(thin_air_drag, earth_drag * 0.1),
		"QAD-U04: density scales drag linearly"
	)
	_expect(
		model.calculate_drag_force_newtons(100.0, 0.0)
		== 0.0,
		"QAD-U04: vacuum produces zero aerodynamic drag"
	)
	_expect(
		model.calculate_drag_force_newtons(1000.0, 1.225)
		== -5000.0
		and model.calculate_drag_force_newtons(-1000.0, 1.225)
		== 5000.0,
		"QAD-U04: large speeds clamp at signed force limits"
	)


func _test_fail_neutral() -> void:

	var model := _model()
	var invalid_model := QuadraticAxisDragModel.new(-1.0, 1.0, 1.0)

	_expect(
		model.calculate_drag_force_newtons(NAN, 1.0) == 0.0
		and model.calculate_drag_force_newtons(INF, 1.0) == 0.0,
		"QAD-U05: non-finite speed fails neutral"
	)
	_expect(
		model.calculate_drag_force_newtons(10.0, -0.1) == 0.0,
		"QAD-U05: negative density fails neutral"
	)
	_expect(
		model.calculate_drag_force_newtons(10.0, NAN) == 0.0
		and model.calculate_drag_force_newtons(10.0, INF) == 0.0,
		"QAD-U05: non-finite density fails neutral"
	)
	_expect(
		invalid_model.calculate_drag_force_newtons(10.0, 1.0)
		== 0.0,
		"QAD-U05: invalid model fails neutral"
	)


func _test_force_bounds() -> void:

	var model := _model()

	_expect(
		model.is_force_within_limits(-5000.0)
		and model.is_force_within_limits(5000.0),
		"QAD-U06: exact force limits are accepted"
	)
	_expect(
		not model.is_force_within_limits(-5000.001)
		and not model.is_force_within_limits(5000.001),
		"QAD-U06: force overflow is rejected"
	)
	_expect(
		not model.is_force_within_limits(NAN)
		and not model.is_force_within_limits(INF),
		"QAD-U06: non-finite force is rejected"
	)


func _test_contract() -> void:

	var model := _model()

	_expect(
		not model.has_method(&"apply_force")
		and not model.has_method(&"get_force_vector")
		and not model.has_method(&"get_rigid_body")
		and not model.has_method(&"get_environment"),
		"QAD-U07: model has no Vector, body, environment or physics API"
	)
	_expect(
		not model.has_method(&"set_drag_coefficient")
		and not model.has_method(&"set_reference_area_square_meters"),
		"QAD-U07: model exposes no public mutation API"
	)


func _model() -> QuadraticAxisDragModel:

	return QuadraticAxisDragModel.new(1.0, 2.0, 5000.0)


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
