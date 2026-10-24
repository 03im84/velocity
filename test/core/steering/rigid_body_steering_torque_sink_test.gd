extends Node


## RigidBodySteeringTorqueSinkTest
##
## Verifica body/freeze/input validation and that signed torque is applied
## around the rotated craft's local-up axis, without central-force motion.


var _checks: int = 0
var _failures: int = 0
var _next_body_position_index: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RigidBodySteeringTorqueSinkTest")
	print("========================================")

	await get_tree().physics_frame
	_test_invalid_body()
	_test_invalid_inputs()
	_test_frozen_body_gate()
	await _test_positive_torque_about_rotated_body_up()
	await _test_negative_torque_about_body_up()
	_test_zero_torque_and_contract()
	_test_freed_body()
	_finish()


func _test_invalid_body() -> void:

	var sink := RigidBodySteeringTorqueSink.new(null)

	_expect(
		not sink.is_valid(),
		"RST-U01: null body is invalid"
	)
	_expect(
		not sink.apply_yaw_torque(100.0, 0.0),
		"RST-U01: null body rejects torque"
	)


func _test_invalid_inputs() -> void:

	var sink := RigidBodySteeringTorqueSink.new(_new_body())

	_expect(sink.is_valid(), "RST-U02: active scene-owned body is valid")
	_expect(
		not sink.apply_yaw_torque(NAN, 0.0)
		and not sink.apply_yaw_torque(INF, 0.0)
		and not sink.apply_yaw_torque(-INF, 0.0),
		"RST-U02: non-finite torque is rejected"
	)
	_expect(
		not sink.apply_yaw_torque(100.0, -0.001)
		and not sink.apply_yaw_torque(100.0, NAN)
		and not sink.apply_yaw_torque(100.0, INF),
		"RST-U02: invalid timestamp is rejected"
	)


func _test_frozen_body_gate() -> void:

	var sink := RigidBodySteeringTorqueSink.new(
		_new_body(Vector3.ZERO, true)
	)

	_expect(
		sink.is_valid(),
		"RST-U03: frozen body remains a valid configured dependency"
	)
	_expect(
		not sink.apply_yaw_torque(100.0, 1.0),
		"RST-U03: frozen body rejects torque before activation"
	)


func _test_positive_torque_about_rotated_body_up() -> void:

	var body := _new_body(Vector3(0.4, 0.2, -0.3))
	await get_tree().physics_frame
	var sink := RigidBodySteeringTorqueSink.new(body)
	var body_up := body.global_basis.orthonormalized().y.normalized()
	var accepted := sink.apply_yaw_torque(1000.0, 2.0)
	await get_tree().physics_frame
	var signed_up_angular_velocity := body.angular_velocity.dot(body_up)
	var lateral_angular_velocity := body.angular_velocity.dot(
		body.global_basis.orthonormalized().x.normalized()
	)

	_expect(
		accepted
		and is_finite(signed_up_angular_velocity)
		and signed_up_angular_velocity > 0.0,
		"RST-U04: positive torque accelerates about rotated body up"
	)
	_expect(
		absf(lateral_angular_velocity) < 0.0001,
		"RST-U04: yaw torque introduces no right-axis angular velocity"
	)
	_expect(
		body.linear_velocity.length() < 0.0001,
		"RST-U04: pure central torque adds no linear velocity"
	)


func _test_negative_torque_about_body_up() -> void:

	var body := _new_body(Vector3(-0.25, 0.0, 0.15))
	await get_tree().physics_frame
	var sink := RigidBodySteeringTorqueSink.new(body)
	var body_up := body.global_basis.orthonormalized().y.normalized()
	var accepted := sink.apply_yaw_torque(-800.0, 3.0)
	await get_tree().physics_frame
	var signed_up_angular_velocity := body.angular_velocity.dot(body_up)

	_expect(
		accepted
		and is_finite(signed_up_angular_velocity)
		and signed_up_angular_velocity < 0.0,
		"RST-U05: negative torque produces negative body-up yaw rate"
	)


func _test_zero_torque_and_contract() -> void:

	var sink := RigidBodySteeringTorqueSink.new(_new_body())

	_expect(
		sink.apply_yaw_torque(0.0, 0.0),
		"RST-U06: finite neutral torque is accepted"
	)
	_expect(
		not sink.has_method(&"get_rigid_body")
		and not sink.has_method(&"set_rigid_body")
		and not sink.has_method(&"apply_force")
		and not sink.has_method(&"publish"),
		"RST-U06: sink exposes no body mutation, force or Bus API"
	)


func _test_freed_body() -> void:

	var body := _new_body()
	var sink := RigidBodySteeringTorqueSink.new(body)
	body.free()

	_expect(
		not sink.is_valid()
		and not sink.apply_yaw_torque(100.0, 1.0),
		"RST-U07: freed body fails closed"
	)


func _new_body(
	rotation: Vector3 = Vector3.ZERO,
	frozen: bool = false
) -> RigidBody3D:

	var body := RigidBody3D.new()
	body.mass = 10.0
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.sleeping = false
	body.freeze = frozen
	body.rotation = rotation
	body.position = Vector3(
		float(_next_body_position_index) * 5.0,
		0.0,
		0.0
	)
	_next_body_position_index += 1

	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	add_child(body)
	return body


func _expect(
	condition: bool,
	description: String
) -> void:

	_checks += 1
	if condition:
		print("[PASS] ", description)
		return
	_failures += 1
	push_error("[FAIL] ", description)


func _finish() -> void:

	print("----------------------------------------")
	print("Checks: ", _checks)
	print("Failures: ", _failures)
	print("RESULT: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(_failures)
