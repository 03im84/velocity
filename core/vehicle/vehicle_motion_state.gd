extends RefCounted
class_name VehicleMotionState


## VehicleMotionState
##
## Snapshot inmutable de velocidades, aceleración, angular rates y
## orientación de una vehicle instance.
##
## Vector component conventions:
## - linear vectors: x=surge, y=sway, z=heave;
## - angular/orientation vectors: x=roll, y=pitch, z=yaw.
##
## No conoce SceneTree, RigidBody3D o DeviceBus.
## ADR-017 / Playable Vehicle Composition Design 1.1.


var _local_linear_velocity_meters_per_second: Vector3
var _local_linear_acceleration_meters_per_second_squared: Vector3
var _local_angular_velocity_radians_per_second: Vector3
var _orientation_roll_pitch_yaw_radians: Vector3
var _timestamp_seconds: float
var _has_acceleration_sample: bool


func _init(
	local_linear_velocity_meters_per_second: Vector3,
	local_linear_acceleration_meters_per_second_squared: Vector3,
	local_angular_velocity_radians_per_second: Vector3,
	orientation_roll_pitch_yaw_radians: Vector3,
	timestamp_seconds: float,
	has_acceleration_sample: bool
) -> void:

	_local_linear_velocity_meters_per_second = (
		local_linear_velocity_meters_per_second
	)
	_local_linear_acceleration_meters_per_second_squared = (
		local_linear_acceleration_meters_per_second_squared
	)
	_local_angular_velocity_radians_per_second = (
		local_angular_velocity_radians_per_second
	)
	_orientation_roll_pitch_yaw_radians = (
		orientation_roll_pitch_yaw_radians
	)
	_timestamp_seconds = timestamp_seconds
	_has_acceleration_sample = has_acceleration_sample


func get_local_linear_velocity_meters_per_second() -> Vector3:

	return _local_linear_velocity_meters_per_second


func get_local_linear_acceleration_meters_per_second_squared() -> Vector3:

	return _local_linear_acceleration_meters_per_second_squared


func get_local_angular_velocity_radians_per_second() -> Vector3:

	return _local_angular_velocity_radians_per_second


func get_orientation_roll_pitch_yaw_radians() -> Vector3:

	return _orientation_roll_pitch_yaw_radians


func get_timestamp_seconds() -> float:

	return _timestamp_seconds


func has_acceleration_sample() -> bool:

	return _has_acceleration_sample


func is_valid() -> bool:

	return (
		_vector_is_finite(
			_local_linear_velocity_meters_per_second
		)
		and _vector_is_finite(
			_local_linear_acceleration_meters_per_second_squared
		)
		and _vector_is_finite(
			_local_angular_velocity_radians_per_second
		)
		and _vector_is_finite(
			_orientation_roll_pitch_yaw_radians
		)
		and is_finite(_timestamp_seconds)
		and _timestamp_seconds >= 0.0
	)


func _vector_is_finite(
	value: Vector3
) -> bool:

	return (
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
	)
