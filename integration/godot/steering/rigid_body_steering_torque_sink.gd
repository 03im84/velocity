extends RefCounted
class_name RigidBodySteeringTorqueSink


## RigidBodySteeringTorqueSink
##
## Scene-owned adapter that applies a signed yaw torque around the craft's
## normalized body-up axis.
##
## The RigidBody3D is injected explicitly and remains BORROWED. The sink
## validates body/tree/freeze/basis, torque and timestamp before actuation.
## ADR-017 / Playable Vehicle Composition Design 1.2.


const BASIS_DETERMINANT_EPSILON: float = 0.000001


var _body: RigidBody3D


func _init(body: RigidBody3D) -> void:

	_body = body


func is_valid() -> bool:

	if (
		_body == null
		or not is_instance_valid(_body)
		or not _body.is_inside_tree()
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


func apply_yaw_torque(
	torque_newton_meters: float,
	timestamp: float
) -> bool:

	if not is_valid() or _body.freeze:
		return false

	if (
		not is_finite(torque_newton_meters)
		or not is_finite(timestamp)
		or timestamp < 0.0
	):
		return false

	var body_basis := _body.global_basis.orthonormalized()
	var world_up := body_basis.y.normalized()
	var world_torque := world_up * torque_newton_meters

	if (
		not _vector_is_finite(world_up)
		or not _vector_is_finite(world_torque)
	):
		return false

	_body.apply_torque(world_torque)
	return true


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
