extends Node


## VehicleMotionStateTest
##
## Verifica snapshot read-only, component ordering, finitud,
## acceleration availability y timestamp validation.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("VehicleMotionStateTest")
	print("========================================")

	_test_valid_snapshot()
	_test_first_sample_snapshot()
	_test_invalid_vectors_and_timestamp()
	_test_contract()

	_finish()


func _test_valid_snapshot() -> void:

	var state := VehicleMotionState.new(
		Vector3(1.0, 2.0, 3.0),
		Vector3(4.0, 5.0, 6.0),
		Vector3(7.0, 8.0, 9.0),
		Vector3(0.1, 0.2, 0.3),
		12.5,
		true
	)

	_expect(state.is_valid(), "VMS-U01: finite snapshot is valid")
	_expect(
		state.get_local_linear_velocity_meters_per_second()
		== Vector3(1.0, 2.0, 3.0),
		"VMS-U01: surge/sway/heave velocity is preserved"
	)
	_expect(
		state.get_local_linear_acceleration_meters_per_second_squared()
		== Vector3(4.0, 5.0, 6.0),
		"VMS-U01: surge/sway/heave acceleration is preserved"
	)
	_expect(
		state.get_local_angular_velocity_radians_per_second()
		== Vector3(7.0, 8.0, 9.0),
		"VMS-U01: roll/pitch/yaw rates are preserved"
	)
	_expect(
		state.get_orientation_roll_pitch_yaw_radians()
		== Vector3(0.1, 0.2, 0.3),
		"VMS-U01: roll/pitch/yaw orientation is preserved"
	)
	_expect(
		state.get_timestamp_seconds() == 12.5
		and state.has_acceleration_sample(),
		"VMS-U01: timestamp and acceleration availability are preserved"
	)


func _test_first_sample_snapshot() -> void:

	var state := VehicleMotionState.new(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		0.0,
		false
	)

	_expect(
		state.is_valid()
		and not state.has_acceleration_sample()
		and state.get_local_linear_acceleration_meters_per_second_squared()
		== Vector3.ZERO,
		"VMS-U02: first sample represents unavailable acceleration explicitly"
	)


func _test_invalid_vectors_and_timestamp() -> void:

	_expect(
		not VehicleMotionState.new(
			Vector3(NAN, 0.0, 0.0),
			Vector3.ZERO,
			Vector3.ZERO,
			Vector3.ZERO,
			1.0,
			false
		).is_valid(),
		"VMS-U03: non-finite linear velocity is rejected"
	)
	_expect(
		not VehicleMotionState.new(
			Vector3.ZERO,
			Vector3(0.0, INF, 0.0),
			Vector3.ZERO,
			Vector3.ZERO,
			1.0,
			true
		).is_valid(),
		"VMS-U03: non-finite linear acceleration is rejected"
	)
	_expect(
		not VehicleMotionState.new(
			Vector3.ZERO,
			Vector3.ZERO,
			Vector3(0.0, 0.0, NAN),
			Vector3.ZERO,
			1.0,
			false
		).is_valid(),
		"VMS-U03: non-finite angular velocity is rejected"
	)
	_expect(
		not VehicleMotionState.new(
			Vector3.ZERO,
			Vector3.ZERO,
			Vector3.ZERO,
			Vector3(INF, 0.0, 0.0),
			1.0,
			false
		).is_valid(),
		"VMS-U03: non-finite orientation is rejected"
	)
	_expect(
		not VehicleMotionState.new(
			Vector3.ZERO,
			Vector3.ZERO,
			Vector3.ZERO,
			Vector3.ZERO,
			-0.001,
			false
		).is_valid(),
		"VMS-U03: negative timestamp is rejected"
	)
	_expect(
		not VehicleMotionState.new(
			Vector3.ZERO,
			Vector3.ZERO,
			Vector3.ZERO,
			Vector3.ZERO,
			NAN,
			false
		).is_valid(),
		"VMS-U03: non-finite timestamp is rejected"
	)


func _test_contract() -> void:

	var state := VehicleMotionState.new(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		0.0,
		false
	)

	_expect(
		state.has_method(&"get_local_linear_velocity_meters_per_second")
		and state.has_method(&"get_orientation_roll_pitch_yaw_radians")
		and not state.has_method(&"set_timestamp_seconds"),
		"VMS-U04: snapshot exposes read-only motion API"
	)
	_expect(
		not state.has_method(&"get_rigid_body")
		and not state.has_method(&"apply_force")
		and not state.has_method(&"publish"),
		"VMS-U04: snapshot has no body, physics or Bus responsibility"
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

	print("Checks: ", _checks)
	print("Failures: ", _failures)
	print("RESULT: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(_failures)
