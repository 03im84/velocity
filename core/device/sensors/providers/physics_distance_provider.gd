extends Node3D
class_name PhysicsDistanceProvider

@export var ray_cast: RayCast3D


func get_distance() -> float:
	if ray_cast == null:
		return 0.0
		
	ray_cast.force_raycast_update()

	if not ray_cast.is_colliding():
		return 0.0

	return ray_cast.global_position.distance_to(
		ray_cast.get_collision_point()
	)


func is_valid() -> bool:
	if ray_cast == null:
		return false
	
	ray_cast.force_raycast_update()

	return ray_cast.is_colliding()
