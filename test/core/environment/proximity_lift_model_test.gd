extends Node


## ProximityLiftModelTest
##
## Verifica curve distance-only, exponent shaping, boundaries,
## fail-neutral y separación de Ground Effect aerodinámico.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("ProximityLiftModelTest")
	print("========================================")

	_test_validation()
	_test_proximity_curve()
	_test_response_exponent()
	_test_fail_neutral()
	_test_force_bounds()
	_test_contract()

	_finish()


func _test_validation() -> void:

	var model := _model()

	_expect(
		model.is_valid(),
		"PLM-U01: finite valid parameters are accepted"
	)
	_expect(
		model.get_influence_height_meters() == 2.0
		and model.get_max_proximity_lift_force_newtons()
		== 4000.0
		and model.get_response_exponent() == 2.0,
		"PLM-U01: configured parameters are preserved"
	)
	_expect(
		ProximityLiftModel.new(1.0, 0.0, 1.0).is_valid(),
		"PLM-U01: zero-force proximity model is valid"
	)
	_expect(
		not ProximityLiftModel.new(0.0, 1.0, 1.0).is_valid()
		and not ProximityLiftModel.new(-1.0, 1.0, 1.0).is_valid(),
		"PLM-U02: non-positive influence height is rejected"
	)
	_expect(
		not ProximityLiftModel.new(NAN, 1.0, 1.0).is_valid()
		and not ProximityLiftModel.new(INF, 1.0, 1.0).is_valid(),
		"PLM-U02: non-finite influence height is rejected"
	)
	_expect(
		not ProximityLiftModel.new(1.0, -1.0, 1.0).is_valid()
		and not ProximityLiftModel.new(1.0, NAN, 1.0).is_valid(),
		"PLM-U02: invalid maximum force is rejected"
	)
	_expect(
		not ProximityLiftModel.new(1.0, 1.0, 0.0).is_valid()
		and not ProximityLiftModel.new(1.0, 1.0, -1.0).is_valid(),
		"PLM-U02: non-positive exponent is rejected"
	)
	_expect(
		not ProximityLiftModel.new(1.0, 1.0, NAN).is_valid()
		and not ProximityLiftModel.new(1.0, 1.0, INF).is_valid(),
		"PLM-U02: non-finite exponent is rejected"
	)


func _test_proximity_curve() -> void:

	var model := _model()

	_expect(
		model.calculate_lift_force_newtons(0.0) == 4000.0,
		"PLM-U03: zero distance produces maximum proximity lift"
	)
	_expect(
		model.calculate_lift_force_newtons(0.5) == 2250.0,
		"PLM-U03: quarter influence distance follows squared curve"
	)
	_expect(
		model.calculate_lift_force_newtons(1.0) == 1000.0,
		"PLM-U03: half influence distance produces quarter force"
	)
	_expect(
		model.calculate_lift_force_newtons(2.0) == 0.0,
		"PLM-U03: exact influence boundary produces zero force"
	)
	_expect(
		model.calculate_lift_force_newtons(20.0) == 0.0,
		"PLM-U03: distance beyond influence remains zero"
	)


func _test_response_exponent() -> void:

	var linear_model := ProximityLiftModel.new(2.0, 4000.0, 1.0)
	var squared_model := _model()
	var steep_model := ProximityLiftModel.new(2.0, 4000.0, 4.0)

	_expect(
		linear_model.calculate_lift_force_newtons(1.0)
		== 2000.0,
		"PLM-U04: exponent one produces linear response"
	)
	_expect(
		steep_model.calculate_lift_force_newtons(1.0)
		== 250.0,
		"PLM-U04: larger exponent concentrates force near surface"
	)
	_expect(
		linear_model.calculate_lift_force_newtons(1.0)
		> squared_model.calculate_lift_force_newtons(1.0),
		"PLM-U04: exponent shapes response without changing bounds"
	)


func _test_fail_neutral() -> void:

	var model := _model()
	var invalid_model := ProximityLiftModel.new(0.0, 1.0, 1.0)

	_expect(
		model.calculate_lift_force_newtons(-0.001) == 0.0,
		"PLM-U05: negative distance fails neutral"
	)
	_expect(
		model.calculate_lift_force_newtons(NAN) == 0.0
		and model.calculate_lift_force_newtons(INF) == 0.0,
		"PLM-U05: non-finite distance fails neutral"
	)
	_expect(
		invalid_model.calculate_lift_force_newtons(0.0) == 0.0,
		"PLM-U05: invalid model fails neutral"
	)


func _test_force_bounds() -> void:

	var model := _model()

	_expect(
		model.is_force_within_limits(0.0)
		and model.is_force_within_limits(4000.0),
		"PLM-U06: exact force boundaries are accepted"
	)
	_expect(
		not model.is_force_within_limits(-0.001)
		and not model.is_force_within_limits(4000.001),
		"PLM-U06: force outside bounds is rejected"
	)
	_expect(
		not model.is_force_within_limits(NAN)
		and not model.is_force_within_limits(INF),
		"PLM-U06: non-finite force is rejected"
	)


func _test_contract() -> void:

	var model := _model()

	_expect(
		not model.has_method(&"get_atmospheric_density")
		and not model.has_method(&"get_angle_of_attack")
		and not model.has_method(&"get_surface_normal"),
		"PLM-U07: model is not aerodynamic Ground Effect"
	)
	_expect(
		not model.has_method(&"apply_force")
		and not model.has_method(&"get_rigid_body")
		and not model.has_method(&"set_response_exponent"),
		"PLM-U07: model has no body, physics or mutation API"
	)


func _model() -> ProximityLiftModel:

	return ProximityLiftModel.new(2.0, 4000.0, 2.0)


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
