extends Node


## RigidBodyBrakeForceSinkTest
##
## Verifies validation and physical deceleration along the rotated craft's
## forward axis for both forward and reverse motion.


var _checks: int = 0
var _failures: int = 0
var _next_body_position_index: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RigidBodyBrakeForceSinkTest")
	print("========================================")

	await get_tree().physics_frame
	_test_invalid_body()
	_test_invalid_inputs()
	_test_frozen_body_gate()
	await _test_forward_braking_on_rotated_body()
	await _test_reverse_braking_on_rotated_body()
	_test_zero_force_and_contract()
	_test_freed_body()
	_finish()


func _test_invalid_body() -> void:

	var null_sink := RigidBodyBrakeForceSink.new(null)

	_expect(
		not null_sink.is_valid(),
		"RBBS-U01: null body is invalid"
	)
	_expect(
		not null_sink.apply_brake_force(100.0, 0.0),
		"RBBS-U01: null body rejects force"
	)

	var detached_body := RigidBody3D.new()
	var detached_sink := RigidBodyBrakeForceSink.new(detached_body)

	_expect(
		not detached_sink.is_valid(),
		"RBBS-U01: body outside SceneTree is invalid"
	)
	_expect(
		not detached_sink.apply_brake_force(100.0, 0.0),
		"RBBS-U01: body outside SceneTree rejects force"
	)
	detached_body.free()


func _test_invalid_inputs() -> void:

	var sink := RigidBodyBrakeForceSink.new(_new_body())

	_expect(
		sink.is_valid(),
		"RBBS-U02: active scene-owned body is valid"
	)
	_expect(
		not sink.apply_brake_force(NAN, 0.0)
		and not sink.apply_brake_force(INF, 0.0)
		and not sink.apply_brake_force(-INF, 0.0),
		"RBBS-U02: non-finite force is rejected"
	)
	_expect(
		not sink.apply_brake_force(100.0, -0.001)
		and not sink.apply_brake_force(100.0, NAN)
		and not sink.apply_brake_force(100.0, INF),
		"RBBS-U02: invalid timestamp is rejected"
	)


func _test_frozen_body_gate() -> void:

	var sink := RigidBodyBrakeForceSink.new(
		_new_body(Vector3.ZERO, true)
	)

	_expect(
		sink.is_valid(),
		"RBBS-U03: frozen body remains a valid configured dependency"
	)
	_expect(
		not sink.apply_brake_force(1000.0, 1.0),
		"RBBS-U03: frozen body rejects actuation before activation"
	)


func _test_forward_braking_on_rotated_body() -> void:

	var body := _new_body(Vector3(0.35, 0.2, -0.3))
	await get_tree().physics_frame

	var body_basis := body.global_basis.orthonormalized()
	var world_forward := -body_basis.z.normalized()
	var world_right := body_basis.x.normalized()
	var initial_forward_speed := 12.0
	body.linear_velocity = world_forward * initial_forward_speed

	var sink := RigidBodyBrakeForceSink.new(body)
	var accepted := sink.apply_brake_force(-1200.0, 2.0)
	await get_tree().physics_frame

	var final_forward_speed := body.linear_velocity.dot(world_forward)
	var lateral_speed := body.linear_velocity.dot(world_right)

	_expect(
		accepted
		and is_finite(final_forward_speed)
		and final_forward_speed < initial_forward_speed
		and final_forward_speed > 0.0,
		"RBBS-U04: negative force decelerates forward motion along rotated local -Z"
	)
	_expect(
		absf(lateral_speed) < 0.0001,
		"RBBS-U04: central braking force adds no lateral velocity"
	)
	_expect(
		body.angular_velocity.length() < 0.0001,
		"RBBS-U04: central braking force adds no angular velocity"
	)


func _test_reverse_braking_on_rotated_body() -> void:

	var body := _new_body(Vector3(-0.25, 0.7, 0.15))
	await get_tree().physics_frame

	var world_forward := (
		-body.global_basis.orthonormalized().z.normalized()
	)
	var initial_forward_speed := -12.0
	body.linear_velocity = world_forward * initial_forward_speed

	var sink := RigidBodyBrakeForceSink.new(body)
	var accepted := sink.apply_brake_force(1200.0, 3.0)
	await get_tree().physics_frame

	var final_forward_speed := body.linear_velocity.dot(world_forward)

	_expect(
		accepted
		and is_finite(final_forward_speed)
		and final_forward_speed > initial_forward_speed
		and final_forward_speed < 0.0,
		"RBBS-U05: positive force decelerates reverse motion along rotated local -Z"
	)


func _test_zero_force_and_contract() -> void:

	var sink := RigidBodyBrakeForceSink.new(_new_body())

	_expect(
		sink.apply_brake_force(0.0, 0.0),
		"RBBS-U06: finite neutral force is accepted"
	)
	_expect(
		not sink.has_method(&"get_rigid_body")
		and not sink.has_method(&"set_rigid_body")
		and not sink.has_method(&"apply_torque")
		and not sink.has_method(&"publish"),
		"RBBS-U06: sink exposes no body mutation, torque or Bus API"
	)


func _test_freed_body() -> void:

	var body := _new_body()
	var sink := RigidBodyBrakeForceSink.new(body)
	body.free()

	_expect(
		not sink.is_valid()
		and not sink.apply_brake_force(100.0, 1.0),
		"RBBS-U07: freed body fails closed"
	)


func _new_body(
	rotation: Vector3 = Vector3.ZERO,
	frozen: bool = false
) -> RigidBody3D:

	var body := RigidBody3D.new()
	body.mass = 10.0
	body.gravity_scale = 0.0
	body.linear_damp = 0.0
	body.angular_damp = 0.0
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
