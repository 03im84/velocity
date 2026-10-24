extends Node


## RigidBodyVehicleMotionSourceTest
##
## Verifica body validation, signed forward/yaw projections, local
## surge/sway/heave mapping, acceleration sampling, monotonic timestamps.


var _checks: int = 0
var _failures: int = 0
var _bodies: Array[RigidBody3D] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("RigidBodyVehicleMotionSourceTest")
	print("========================================")

	_test_invalid_body()
	_test_signed_scalar_behaviors()
	_test_motion_snapshot()
	_test_acceleration_sampling()
	_test_timestamp_rejection_and_recovery()
	_test_clear_history()
	_test_freed_body()
	_test_contract()

	_finish()


func _test_invalid_body() -> void:

	var source := RigidBodyVehicleMotionSource.new(null)

	_expect(
		not source.is_valid(),
		"RBVMS-U01: null body is invalid"
	)
	_expect(
		not is_finite(source.get_longitudinal_speed_meters_per_second())
		and not is_finite(source.get_yaw_rate_radians_per_second()),
		"RBVMS-U01: invalid scalar reads fail with non-finite sentinel"
	)
	_expect(
		source.sample_motion_state(0.0) == null,
		"RBVMS-U01: invalid body yields no snapshot"
	)
	var valid_source := RigidBodyVehicleMotionSource.new(_new_body())
	_expect(
		valid_source.sample_motion_state(-0.1) == null
		and valid_source.sample_motion_state(NAN) == null
		and valid_source.sample_motion_state(INF) == null,
		"RBVMS-U01: invalid capture timestamp yields no snapshot"
	)


func _test_signed_scalar_behaviors() -> void:

	var body := _new_body()
	var source := RigidBodyVehicleMotionSource.new(body)
	body.linear_velocity = Vector3(0.0, 0.0, -4.0)

	_expect(
		source.is_valid()
		and is_equal_approx(
			source.get_longitudinal_speed_meters_per_second(),
			4.0
		),
		"RBVMS-U02: local -Z forward produces positive longitudinal speed"
	)

	body.linear_velocity = Vector3(0.0, 0.0, 3.0)

	_expect(
		source.get_longitudinal_speed_meters_per_second() == -3.0,
		"RBVMS-U02: reverse world velocity produces negative speed"
	)

	body.global_rotation = Vector3(0.0, PI * 0.5, 0.0)
	var body_forward := -body.global_basis.z.normalized()
	body.linear_velocity = body_forward * 5.0
	body.angular_velocity = body.global_basis.y.normalized() * 0.75

	_expect(
		is_equal_approx(
			source.get_longitudinal_speed_meters_per_second(),
			5.0
		),
		"RBVMS-U02: longitudinal speed follows rotated body forward"
	)
	_expect(
		is_equal_approx(
			source.get_yaw_rate_radians_per_second(),
			0.75
		),
		"RBVMS-U02: yaw rate projects angular velocity onto body up"
	)


func _test_motion_snapshot() -> void:

	var body := _new_body()
	var source := RigidBodyVehicleMotionSource.new(body)
	body.global_rotation = Vector3(0.2, 0.3, -0.4)
	var body_basis := body.global_basis.orthonormalized()
	body.linear_velocity = body_basis * Vector3(3.0, 4.0, -5.0)
	body.angular_velocity = body_basis * Vector3(2.0, 3.0, -4.0)

	var state := source.sample_motion_state(12.0)

	_expect(
		state != null and state.is_valid(),
		"RBVMS-U03: finite body produces valid snapshot"
	)
	_expect(
		state != null
		and _vectors_are_equal_approximately(
			state.get_local_linear_velocity_meters_per_second(),
			Vector3(5.0, 3.0, 4.0)
		),
		"RBVMS-U03: local velocity maps surge/sway/heave components"
	)
	_expect(
		state != null
		and _vectors_are_equal_approximately(
			state.get_local_angular_velocity_radians_per_second(),
			Vector3(4.0, 2.0, 3.0)
		),
		"RBVMS-U03: local angular velocity maps roll/pitch/yaw"
	)
	_expect(
		state != null
		and is_equal_approx(
			state.get_orientation_roll_pitch_yaw_radians().x,
			0.4
		)
		and is_equal_approx(
			state.get_orientation_roll_pitch_yaw_radians().y,
			0.2
		)
		and is_equal_approx(
			state.get_orientation_roll_pitch_yaw_radians().z,
			0.3
		),
		"RBVMS-U03: Euler orientation maps roll/pitch/yaw convention"
	)
	_expect(
		state != null
		and state.get_timestamp_seconds() == 12.0
		and not state.has_acceleration_sample()
		and state.get_local_linear_acceleration_meters_per_second_squared()
		== Vector3.ZERO,
		"RBVMS-U03: first snapshot marks acceleration unavailable"
	)


func _test_acceleration_sampling() -> void:

	var body := _new_body()
	var source := RigidBodyVehicleMotionSource.new(body)
	body.linear_velocity = Vector3(0.0, 0.0, -2.0)
	var first := source.sample_motion_state(1.0)
	body.linear_velocity = Vector3(0.0, 0.0, -6.0)
	var second := source.sample_motion_state(2.0)

	_expect(
		first != null and not first.has_acceleration_sample(),
		"RBVMS-U04: first timestamp establishes baseline only"
	)
	_expect(
		second != null and second.has_acceleration_sample(),
		"RBVMS-U04: later monotonic timestamp exposes acceleration"
	)
	_expect(
		second != null
		and second.get_local_linear_acceleration_meters_per_second_squared()
		== Vector3(4.0, 0.0, 0.0),
		"RBVMS-U04: acceleration derives from world velocity delta"
	)


func _test_timestamp_rejection_and_recovery() -> void:

	var body := _new_body()
	var source := RigidBodyVehicleMotionSource.new(body)
	body.linear_velocity = Vector3(0.0, 0.0, -1.0)
	var initial := source.sample_motion_state(2.0)
	body.linear_velocity = Vector3(0.0, 0.0, -4.0)

	_expect(
		source.sample_motion_state(2.0) == null,
		"RBVMS-U05: repeated timestamp is rejected"
	)
	_expect(
		source.sample_motion_state(1.5) == null,
		"RBVMS-U05: regressive timestamp is rejected"
	)

	var recovered := source.sample_motion_state(3.0)

	_expect(
		initial != null
		and recovered != null
		and recovered.has_acceleration_sample()
		and recovered.get_local_linear_acceleration_meters_per_second_squared()
		== Vector3(3.0, 0.0, 0.0),
		"RBVMS-U05: rejected timestamps preserve prior sample baseline"
	)


func _test_clear_history() -> void:

	var body := _new_body()
	var source := RigidBodyVehicleMotionSource.new(body)
	body.linear_velocity = Vector3(0.0, 0.0, -1.0)
	source.sample_motion_state(10.0)
	source.clear_history()

	_expect(
		not source.has_previous_sample(),
		"RBVMS-U06: clear resets bounded history"
	)
	var restarted := source.sample_motion_state(1.0)
	_expect(
		restarted != null
		and not restarted.has_acceleration_sample()
		and restarted.get_timestamp_seconds() == 1.0,
		"RBVMS-U06: clear starts a fresh timestamp epoch"
	)


func _test_freed_body() -> void:

	var body := _new_body()
	var source := RigidBodyVehicleMotionSource.new(body)
	body.free()

	_expect(
		not source.is_valid(),
		"RBVMS-U07: freed scene-owned body invalidates source"
	)
	_expect(
		not is_finite(source.get_longitudinal_speed_meters_per_second())
		and source.sample_motion_state(1.0) == null,
		"RBVMS-U07: freed body fails neutral without stale snapshot"
	)


func _test_contract() -> void:

	var body := _new_body()
	var source := RigidBodyVehicleMotionSource.new(body)

	_expect(
		not source.has_method(&"apply_force")
		and not source.has_method(&"apply_torque")
		and not source.has_method(&"publish"),
		"RBVMS-U08: source never actuates or publishes"
	)
	_expect(
		not source.has_method(&"get_rigid_body")
		and not source.has_method(&"set_rigid_body"),
		"RBVMS-U08: source exposes no mutable body API"
	)


func _vectors_are_equal_approximately(
	actual: Vector3,
	expected: Vector3
) -> bool:

	return (
		is_equal_approx(actual.x, expected.x)
		and is_equal_approx(actual.y, expected.y)
		and is_equal_approx(actual.z, expected.z)
	)


func _new_body() -> RigidBody3D:

	var body := RigidBody3D.new()
	body.gravity_scale = 0.0
	body.freeze = true
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	add_child(body)
	_bodies.append(body)
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
	push_error("[FAIL] " + description)


func _finish() -> void:

	print("Checks: ", _checks)
	print("Failures: ", _failures)
	print("RESULT: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(_failures)
