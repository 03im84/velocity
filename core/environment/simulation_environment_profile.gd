extends RefCounted
class_name SimulationEnvironmentProfile


## SimulationEnvironmentProfile
##
## Snapshot tratado como inmutable que describe magnitudes físicas
## globales requeridas por models y scene adapters.
##
## Gravity direction pertenece al world/scene adapter. Este Profile
## no conoce RigidBody3D, Atmosphere Nodes o ProjectSettings.
## ADR-017 / Vehicle Environment and Realism Addendum.


var _gravity_meters_per_second_squared: float
var _atmospheric_density_kg_per_cubic_meter: float


func _init(
	gravity_meters_per_second_squared: float,
	atmospheric_density_kg_per_cubic_meter: float
) -> void:

	_gravity_meters_per_second_squared = (
		gravity_meters_per_second_squared
	)
	_atmospheric_density_kg_per_cubic_meter = (
		atmospheric_density_kg_per_cubic_meter
	)


func get_gravity_meters_per_second_squared() -> float:

	return _gravity_meters_per_second_squared


func get_atmospheric_density_kg_per_cubic_meter() -> float:

	return _atmospheric_density_kg_per_cubic_meter


func is_valid() -> bool:

	return (
		is_finite(_gravity_meters_per_second_squared)
		and is_finite(
			_atmospheric_density_kg_per_cubic_meter
		)
		and _gravity_meters_per_second_squared >= 0.0
		and _atmospheric_density_kg_per_cubic_meter >= 0.0
	)
