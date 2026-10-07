extends Node


## SimulationEnvironmentProfileTest
##
## Verifica unidades, boundaries, vacuum/zero-gravity y ausencia de
## responsabilidades Godot o models derivados.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("SimulationEnvironmentProfileTest")
	print("========================================")

	_test_valid_profiles()
	_test_invalid_gravity()
	_test_invalid_atmosphere()
	_test_contract()

	_finish()


func _test_valid_profiles() -> void:

	var earth_like := SimulationEnvironmentProfile.new(
		9.81,
		1.225
	)
	var vacuum := SimulationEnvironmentProfile.new(
		1.62,
		0.0
	)
	var zero_environment := SimulationEnvironmentProfile.new(
		0.0,
		0.0
	)

	_expect(
		earth_like.is_valid(),
		"SEP-U01: finite Earth-like values are valid"
	)
	_expect(
		earth_like.get_gravity_meters_per_second_squared()
		== 9.81,
		"SEP-U01: gravity magnitude is preserved"
	)
	_expect(
		earth_like.get_atmospheric_density_kg_per_cubic_meter()
		== 1.225,
		"SEP-U01: atmospheric density is preserved"
	)
	_expect(
		vacuum.is_valid()
		and vacuum.get_atmospheric_density_kg_per_cubic_meter()
		== 0.0,
		"SEP-U02: vacuum density is valid"
	)
	_expect(
		zero_environment.is_valid(),
		"SEP-U02: zero-gravity vacuum is valid"
	)


func _test_invalid_gravity() -> void:

	_expect(
		not SimulationEnvironmentProfile.new(-0.001, 1.0).is_valid(),
		"SEP-U03: negative gravity magnitude is rejected"
	)
	_expect(
		not SimulationEnvironmentProfile.new(NAN, 1.0).is_valid(),
		"SEP-U03: NAN gravity is rejected"
	)
	_expect(
		not SimulationEnvironmentProfile.new(INF, 1.0).is_valid()
		and not SimulationEnvironmentProfile.new(-INF, 1.0).is_valid(),
		"SEP-U03: infinite gravity is rejected"
	)


func _test_invalid_atmosphere() -> void:

	_expect(
		not SimulationEnvironmentProfile.new(9.81, -0.001).is_valid(),
		"SEP-U04: negative atmospheric density is rejected"
	)
	_expect(
		not SimulationEnvironmentProfile.new(9.81, NAN).is_valid(),
		"SEP-U04: NAN atmospheric density is rejected"
	)
	_expect(
		not SimulationEnvironmentProfile.new(9.81, INF).is_valid()
		and not SimulationEnvironmentProfile.new(9.81, -INF).is_valid(),
		"SEP-U04: infinite atmospheric density is rejected"
	)


func _test_contract() -> void:

	var profile := SimulationEnvironmentProfile.new(9.81, 1.225)

	_expect(
		not profile.has_method(
			&"set_gravity_meters_per_second_squared"
		)
		and not profile.has_method(
			&"set_atmospheric_density_kg_per_cubic_meter"
		),
		"SEP-U05: Profile exposes no public mutation API"
	)
	_expect(
		not profile.has_method(&"apply_force")
		and not profile.has_method(&"configure_world")
		and not profile.has_method(&"get_rigid_body")
		and not profile.has_method(&"calculate_drag_force"),
		"SEP-U05: Profile has no Godot, body or model responsibility"
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

	print("----------------------------------------")
	print("Checks: ", _checks)
	print("Failures: ", _failures)

	if _failures == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")

	print("========================================")
	print("")
	get_tree().quit(_failures)
