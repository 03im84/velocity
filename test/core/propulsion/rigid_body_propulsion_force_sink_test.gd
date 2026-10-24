extends Node


## RigidBodyPropulsionForceSinkTest
##
## Verifica body/basis/input validation, activation freeze gate and the
## physical central-force direction for forward/reverse propulsion.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RigidBodyPropulsionForceSinkTest")
	print("========================================")

	await get_tree().physics_frame
	_test_invalid_body()
	_test_invalid_inputs()
	_test_frozen_body_gate()
	await _test_forward_force_direction()
	await _test_reverse_force_direction_on_rotated_body()
	_test_zero_force_and_contract()
	_test_freed_body()
	_finish()


func _test_invalid_body() -> void:

	var sink := RigidBodyPropulsionForceSink.new(null)

	_expect(
		not sink.is_valid(),
		"RPS-U01: null body is invalid"
	)
	_expect(
		not sink.apply_propulsion_force(100.0, 0.0),
		"RPS-U01: null body rejects force"
	)


func _test_invalid_inputs() -> void:

	var body := _new_body()
	var sink := RigidBodyPropulsionForceSink.new(body)

	_expect(
		sink.is_valid(),
		"RPS-U02: active scene-owned body is valid"
	)
	_expect(
		not sink.apply_propulsion_force(NAN, 0.0)
		and not sink.apply_propulsion_force(INF, 0.0)
		and not sink.apply_propulsion_force(-INF, 0.0),
		"RPS-U02: non-finite force is rejected"
	)
	_expect(
		not sink.apply_propulsion_force(100.0, -0.001)
		and not sink.apply_propulsion_force(100.0, NAN)
		and not sink.apply_propulsion_force(100.0, INF),
		"RPS-U02: invalid timestamp is rejected"
	)


func _test_frozen_body_gate() -> void:

	var body := _new_body(Vector3.ZERO, true)
	var sink := RigidBodyPropulsionForceSink.new(body)

	_expect(
		sink.is_valid(),
		"RPS-U03: frozen body remains a valid configured dependency"
	)
	_expect(
		not sink.apply_propulsion_force(1000.0, 1.0),
		"RPS-U03: frozen body rejects actuation before activation"
	)


func _test_forward_force_direction() -> void:

	var body := _new_body()
	await get_tree().physics_frame
	var sink := RigidBodyPropulsionForceSink.new(body)
	var body_basis := body.global_basis.orthonormalized()
	var world_forward := -body_basis.z.normalized()
	var world_right := body_basis.x.normalized()
	var accepted := sink.apply_propulsion_force(1200.0, 2.0)
	await get_tree().physics_frame
	var forward_speed := body.linear_velocity.dot(world_forward)
	var lateral_speed := body.linear_velocity.dot(world_right)

	_expect(
		accepted and is_finite(forward_speed) and forward_speed > 0.0,
		"RPS-U04: positive force accelerates along local -Z forward"
	)
	_expect(
		absf(lateral_speed) < 0.0001,
		"RPS-U04: central forward force introduces no lateral velocity"
	)


func _test_reverse_force_direction_on_rotated_body() -> void:

	var body := _new_body(Vector3(0.0, PI * 0.5, 0.0))
	await get_tree().physics_frame
	var sink := RigidBodyPropulsionForceSink.new(body)
	var world_forward := -body.global_basis.orthonormalized().z.normalized()
	var accepted := sink.apply_propulsion_force(-900.0, 3.0)
	await get_tree().physics_frame
	var signed_forward_speed := body.linear_velocity.dot(world_forward)

	_expect(
		accepted
		and is_finite(signed_forward_speed)
		and signed_forward_speed < 0.0,
		"RPS-U05: reverse force follows the rotated craft forward axis"
	)


func _test_zero_force_and_contract() -> void:

	var body := _new_body()
	var sink := RigidBodyPropulsionForceSink.new(body)

	_expect(
		sink.apply_propulsion_force(0.0, 0.0),
		"RPS-U06: finite neutral force is accepted"
	)
	_expect(
		not sink.has_method(&"get_rigid_body")
		and not sink.has_method(&"set_rigid_body")
		and not sink.has_method(&"apply_torque")
		and not sink.has_method(&"publish"),
		"RPS-U06: sink exposes no body mutation, torque or Bus API"
	)


func _test_freed_body() -> void:

	var body := _new_body()
	var sink := RigidBodyPropulsionForceSink.new(body)
	body.free()

	_expect(
		not sink.is_valid()
		and not sink.apply_propulsion_force(100.0, 1.0),
		"RPS-U07: freed body fails closed"
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
