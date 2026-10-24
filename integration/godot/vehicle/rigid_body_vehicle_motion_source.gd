extends RefCounted
class_name RigidBodyVehicleMotionSource


## RigidBodyVehicleMotionSource
##
## Scene-owned adapter that observes an explicitly injected RigidBody3D.
## Implements scalar Steering/Brake motion behaviors and produces an
## immutable VehicleMotionState snapshot.
##
## Forward is local -Z, up local +Y, right local +X. The adapter never
## mutates or owns the body. Acceleration uses one previous world-velocity
## sample and a strictly increasing caller-supplied monotonic timestamp.
## ADR-017 / Playable Vehicle Composition Design 1.1.


const BASIS_DETERMINANT_EPSILON: float = 0.000001


var _body: RigidBody3D
var _has_previous_sample: bool = false
var _previous_world_linear_velocity: Vector3 = Vector3.ZERO
var _previous_timestamp_seconds: float = 0.0


func _init(body: RigidBody3D) -> void:

	_body = body


func is_valid() -> bool:

	if _body == null or not is_instance_valid(_body):
		return false

	return _body_kinematics_are_valid()


func has_previous_sample() -> bool:

	return _has_previous_sample


func get_longitudinal_speed_meters_per_second() -> float:

	if not is_valid():
		return NAN

	var body_basis := _orthonormal_body_basis()
	var world_forward := -body_basis.z.normalized()
	var speed := _body.linear_velocity.dot(world_forward)

	if not is_finite(speed):
		return NAN

	return speed


func get_yaw_rate_radians_per_second() -> float:

	if not is_valid():
		return NAN

	var body_basis := _orthonormal_body_basis()
	var world_up := body_basis.y.normalized()
	var yaw_rate := _body.angular_velocity.dot(world_up)

	if not is_finite(yaw_rate):
		return NAN

	return yaw_rate


func sample_motion_state(
	timestamp_seconds: float
) -> VehicleMotionState:

	if (
		not is_valid()
		or not is_finite(timestamp_seconds)
		or timestamp_seconds < 0.0
	):
		return null

	if (
		_has_previous_sample
		and timestamp_seconds <= _previous_timestamp_seconds
	):
		return null

	var body_basis := _orthonormal_body_basis()
	var inverse_basis := body_basis.inverse()
	var world_linear_velocity := _body.linear_velocity
	var local_linear_velocity := (
		inverse_basis * world_linear_velocity
	)
	var local_linear_velocity_surge_sway_heave := Vector3(
		-local_linear_velocity.z,
		local_linear_velocity.x,
		local_linear_velocity.y
	)
	var world_angular_velocity := _body.angular_velocity
	var local_angular_velocity := (
		inverse_basis * world_angular_velocity
	)
	var local_angular_velocity_roll_pitch_yaw := Vector3(
		-local_angular_velocity.z,
		local_angular_velocity.x,
		local_angular_velocity.y
	)
	var euler_rotation := _body.global_rotation
	var orientation_roll_pitch_yaw := Vector3(
		-euler_rotation.z,
		euler_rotation.x,
		euler_rotation.y
	)
	var local_linear_acceleration_surge_sway_heave := Vector3.ZERO
	var acceleration_sample_available := false

	if _has_previous_sample:
		var delta_seconds := (
			timestamp_seconds - _previous_timestamp_seconds
		)
		var world_linear_acceleration := (
			world_linear_velocity
			- _previous_world_linear_velocity
		) / delta_seconds
		var local_linear_acceleration := (
			inverse_basis * world_linear_acceleration
		)

		if not _vector_is_finite(local_linear_acceleration):
			return null

		local_linear_acceleration_surge_sway_heave = Vector3(
			-local_linear_acceleration.z,
			local_linear_acceleration.x,
			local_linear_acceleration.y
		)
		acceleration_sample_available = true

	var state := VehicleMotionState.new(
		local_linear_velocity_surge_sway_heave,
		local_linear_acceleration_surge_sway_heave,
		local_angular_velocity_roll_pitch_yaw,
		orientation_roll_pitch_yaw,
		timestamp_seconds,
		acceleration_sample_available
	)

	if not state.is_valid():
		return null

	_has_previous_sample = true
	_previous_world_linear_velocity = world_linear_velocity
	_previous_timestamp_seconds = timestamp_seconds
	return state


func clear_history() -> void:

	_has_previous_sample = false
	_previous_world_linear_velocity = Vector3.ZERO
	_previous_timestamp_seconds = 0.0


func _body_kinematics_are_valid() -> bool:

	if (
		not _vector_is_finite(_body.linear_velocity)
		or not _vector_is_finite(_body.angular_velocity)
		or not _vector_is_finite(_body.global_rotation)
	):
		return false

	var basis := _body.global_basis

	if not _basis_is_finite(basis):
		return false

	var determinant := basis.determinant()

	return (
		is_finite(determinant)
		and determinant > BASIS_DETERMINANT_EPSILON
	)


func _orthonormal_body_basis() -> Basis:

	return _body.global_basis.orthonormalized()


func _basis_is_finite(
	basis: Basis
) -> bool:

	return (
		_vector_is_finite(basis.x)
		and _vector_is_finite(basis.y)
		and _vector_is_finite(basis.z)
	)


func _vector_is_finite(
	value: Vector3
) -> bool:

	return (
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
	)
