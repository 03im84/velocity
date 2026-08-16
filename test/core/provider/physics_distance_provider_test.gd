extends Node3D


##
## PhysicsDistanceProviderTest
##
## Verifica el contrato físico de
## PhysicsDistanceProvider sin utilizar
## DeviceBus o DistanceSensorDevice.
##


@onready var _configured_provider: PhysicsDistanceProvider = (
	$ConfiguredProvider
)

@onready var _ray_cast: RayCast3D = (
	$ConfiguredProvider/RayCast3D
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("PhysicsDistanceProviderTest")
	print("========================================")

	_test_provider_without_raycast()

	await _test_provider_without_collision()

	await _test_provider_with_surface()

	_test_bus_independence()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_provider_without_raycast() -> void:

	var provider := PhysicsDistanceProvider.new()

	add_child(provider)

	_expect(
		not provider.is_valid(),
		"PDP-I01: Provider without RayCast is invalid"
	)

	_expect(
		provider.get_distance() == 0.0,
		"PDP-I01: Provider without RayCast returns zero"
	)


func _test_provider_without_collision() -> void:

	_ray_cast.collision_mask = 0

	await get_tree().physics_frame

	_expect(
		not _configured_provider.is_valid(),
		"PDP-I02: RayCast without collision is invalid"
	)

	_expect(
		_configured_provider.get_distance() == 0.0,
		"PDP-I02: no collision returns zero"
	)


func _test_provider_with_surface() -> void:

	_ray_cast.collision_mask = 1

	await get_tree().physics_frame

	_expect(
		_configured_provider.is_valid(),
		"PDP-I03: surface produces valid reading"
	)

	var distance: float = (
		_configured_provider.get_distance()
	)

	_expect(
		distance > 4.8
		and distance < 5.0,
		"PDP-I03: physical distance matches geometry"
	)


func _test_bus_independence() -> void:

	_expect(
		get_node_or_null(
			"DeviceBus"
		) == null,
		"PDP-I04: scene has no DeviceBus Node"
	)


# =============================================================================
# TEST UTILITIES
# =============================================================================

func _expect(
	condition: bool,
	description: String
) -> void:

	_check_count += 1

	if condition:
		print("[PASS] ", description)
		return

	_failure_count += 1

	push_error(
		"[FAIL] " + description
	)


func _finish_test() -> void:

	print("----------------------------------------")
	print("Checks: ", _check_count)
	print("Failures: ", _failure_count)

	if _failure_count == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")

	print("========================================")
	print("")

	get_tree().quit(
		_failure_count
	)
