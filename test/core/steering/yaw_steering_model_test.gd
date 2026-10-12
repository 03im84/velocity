extends Node


## YawSteeringModelTest
##
## Verifica command torque, opposing damping, yaw-rate limit suppression,
## output bounds, fail-neutral y separación de física espacial.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("YawSteeringModelTest")
	print("========================================")

	_test_validation()
	_test_command_and_damping()
	_test_yaw_rate_limit_policy()
	_test_output_clamping()
	_test_fail_neutral()
	_test_torque_bounds()
	_test_contract()

	_finish()


func _test_validation() -> void:

	var model := _model()

	_expect(
		model.is_valid(),
		"YSM-U01: finite configured model is valid"
	)
	_expect(
		model.get_max_yaw_torque_newton_meters() == 100.0
		and model.get_yaw_damping_newton_meter_seconds() == 10.0
		and model.get_max_abs_yaw_rate_radians_per_second() == 2.0,
		"YSM-U01: configured parameters are preserved"
	)
	_expect(
		YawSteeringModel.new(0.0, 0.0, 1.0).is_valid(),
		"YSM-U01: zero-torque zero-damping model is valid"
	)
	_expect(
		not YawSteeringModel.new(-0.001, 0.0, 1.0).is_valid(),
		"YSM-U02: negative torque limit is rejected"
	)
	_expect(
		not YawSteeringModel.new(NAN, 0.0, 1.0).is_valid()
		and not YawSteeringModel.new(INF, 0.0, 1.0).is_valid(),
		"YSM-U02: non-finite torque limit is rejected"
	)
	_expect(
		not YawSteeringModel.new(1.0, -0.001, 1.0).is_valid(),
		"YSM-U02: negative damping is rejected"
	)
	_expect(
		not YawSteeringModel.new(1.0, NAN, 1.0).is_valid()
		and not YawSteeringModel.new(1.0, INF, 1.0).is_valid(),
		"YSM-U02: non-finite damping is rejected"
	)
	_expect(
		not YawSteeringModel.new(1.0, 0.0, 0.0).is_valid()
		and not YawSteeringModel.new(1.0, 0.0, -1.0).is_valid(),
		"YSM-U02: non-positive yaw-rate limit is rejected"
	)
	_expect(
		not YawSteeringModel.new(1.0, 0.0, NAN).is_valid()
		and not YawSteeringModel.new(1.0, 0.0, INF).is_valid(),
		"YSM-U02: non-finite yaw-rate limit is rejected"
	)


func _test_command_and_damping() -> void:

	var model := _model()

	_expect(
		model.calculate_yaw_torque_newton_meters(1.0, 0.0)
		== 100.0,
		"YSM-U03: positive command reaches positive torque limit"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(-1.0, 0.0)
		== -100.0,
		"YSM-U03: negative command reaches negative torque limit"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(0.5, 0.0)
		== 50.0,
		"YSM-U03: partial command maps linearly"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(0.0, 0.0)
		== 0.0,
		"YSM-U03: neutral command and rate produce zero torque"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(0.0, 1.0)
		== -10.0,
		"YSM-U03: damping opposes positive yaw rate"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(0.0, -1.0)
		== 10.0,
		"YSM-U03: damping opposes negative yaw rate"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(1.0, 1.0)
		== 90.0,
		"YSM-U03: positive command composes with opposing damping"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(-1.0, -1.0)
		== -90.0,
		"YSM-U03: negative command composes with opposing damping"
	)


func _test_yaw_rate_limit_policy() -> void:

	var model := _model()

	_expect(
		model.calculate_yaw_torque_newton_meters(1.0, 2.0)
		== -20.0,
		"YSM-U04: positive command is suppressed at positive limit"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(-1.0, -2.0)
		== 20.0,
		"YSM-U04: negative command is suppressed at negative limit"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(-1.0, 2.0)
		== -100.0,
		"YSM-U04: opposing command remains active at positive limit"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(1.0, -2.0)
		== 100.0,
		"YSM-U04: opposing command remains active at negative limit"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(1.0, 3.0)
		== -30.0,
		"YSM-U04: damping still recovers rate beyond positive limit"
	)


func _test_output_clamping() -> void:

	var model := _model()

	_expect(
		model.calculate_yaw_torque_newton_meters(1.0, -1.0)
		== 100.0,
		"YSM-U05: positive raw overflow clamps to max torque"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(-1.0, 1.0)
		== -100.0,
		"YSM-U05: negative raw overflow clamps to min torque"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(0.0, 100.0)
		== -100.0
		and model.calculate_yaw_torque_newton_meters(0.0, -100.0)
		== 100.0,
		"YSM-U05: damping-only overflow remains bounded"
	)


func _test_fail_neutral() -> void:

	var model := _model()
	var invalid_model := YawSteeringModel.new(-1.0, 1.0, 1.0)

	_expect(
		model.calculate_yaw_torque_newton_meters(1.0001, 0.0)
		== 0.0,
		"YSM-U06: positive command overflow fails neutral"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(-1.0001, 0.0)
		== 0.0,
		"YSM-U06: negative command overflow fails neutral"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(NAN, 0.0)
		== 0.0
		and model.calculate_yaw_torque_newton_meters(INF, 0.0)
		== 0.0,
		"YSM-U06: non-finite command fails neutral"
	)
	_expect(
		model.calculate_yaw_torque_newton_meters(0.0, NAN)
		== 0.0
		and model.calculate_yaw_torque_newton_meters(0.0, INF)
		== 0.0,
		"YSM-U06: non-finite yaw rate fails neutral"
	)
	_expect(
		invalid_model.calculate_yaw_torque_newton_meters(1.0, 0.0)
		== 0.0,
		"YSM-U06: invalid model fails neutral"
	)


func _test_torque_bounds() -> void:

	var model := _model()

	_expect(
		model.is_torque_within_limits(-100.0)
		and model.is_torque_within_limits(100.0),
		"YSM-U07: exact torque limits are accepted"
	)
	_expect(
		model.is_torque_within_limits(0.0),
		"YSM-U07: neutral torque is accepted"
	)
	_expect(
		not model.is_torque_within_limits(-100.001)
		and not model.is_torque_within_limits(100.001)
		and not model.is_torque_within_limits(NAN)
		and not model.is_torque_within_limits(INF),
		"YSM-U07: out-of-range/non-finite torque is rejected"
	)


func _test_contract() -> void:

	var model := _model()

	_expect(
		not model.has_method(&"get_yaw_rate_radians_per_second")
		and not model.has_method(&"apply_yaw_torque")
		and not model.has_method(&"get_device_bus"),
		"YSM-U08: model owns no source, sink or Bus API"
	)
	_expect(
		not model.has_method(&"apply_torque")
		and not model.has_method(&"get_rigid_body")
		and not model.has_method(&"set_max_yaw_torque_newton_meters"),
		"YSM-U08: model owns no spatial physics or mutation API"
	)


func _model() -> YawSteeringModel:

	return YawSteeringModel.new(100.0, 10.0, 2.0)


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
