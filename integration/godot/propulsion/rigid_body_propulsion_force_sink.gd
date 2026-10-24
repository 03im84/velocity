extends RefCounted
class_name RigidBodyPropulsionForceSink


## RigidBodyPropulsionForceSink
##
## Scene-owned adapter that applies a signed scalar propulsion force
## centrally along the body forward axis (local -Z).
##
## The body is injected explicitly and remains BORROWED. This adapter
## validates body, axis, force and timestamp; it does not own propulsion
## policy, Commands, Runtime lifecycle or source discovery.
## ADR-017 / Playable Vehicle Composition Design 1.1.


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


func apply_propulsion_force(
	force_newtons: float,
	timestamp: float
) -> bool:

	if not is_valid() or _body.freeze:
		return false

	if (
		not is_finite(force_newtons)
		or not is_finite(timestamp)
		or timestamp < 0.0
	):
		return false

	var body_basis := _body.global_basis.orthonormalized()
	var world_forward := -body_basis.z.normalized()
	var world_force := world_forward * force_newtons

	if (
		not _vector_is_finite(world_forward)
		or not _vector_is_finite(world_force)
	):
		return false

	_body.apply_central_force(world_force)
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
