extends Node


## HoverPointProfileTest
##
## Verifica el Profile canónico del actuator Hover Point sin
## modificar baselines aceptadas de BuiltinDeviceProfiles.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("HoverPointProfileTest")
	print("========================================")

	_test_identity_and_metadata()
	_test_effective_contract()
	_test_snapshot_contract()

	_finish()


func _test_identity_and_metadata() -> void:

	var profile := BuiltinDeviceProfiles.create_spring_damper_hover_point()

	_expect(
		profile.is_valid(),
		"HPP-U01: canonical Profile is valid"
	)
	_expect(
		profile.get_profile_id()
		== &"velocity.hover.spring_damper_point"
		and profile.get_profile_version() == 1,
		"HPP-U01: exact Profile identity is preserved"
	)
	_expect(
		profile.get_display_name()
		== "Spring-Damper Hover Point"
		and not profile.get_description().is_empty(),
		"HPP-U01: canonical metadata is present"
	)
	_expect(
		profile.get_primary_role() == DeviceRoles.ACTUATOR,
		"HPP-U01: primary role is ACTUATOR"
	)


func _test_effective_contract() -> void:

	var profile := BuiltinDeviceProfiles.create_spring_damper_hover_point()
	var expected_capabilities: Array[String] = [
		"hover_lift_force",
	]
	var expected_subscribes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	_expect(
		profile.get_capabilities() == expected_capabilities,
		"HPP-U02: Profile declares exact hover capability"
	)
	_expect(
		profile.get_supported_publishes().is_empty(),
		"HPP-U02: actuator publishes no Topic"
	)
	_expect(
		profile.get_supported_subscribes()
		== expected_subscribes,
		"HPP-U02: actuator subscribes exact Distance Topic"
	)
	_expect(
		profile.get_requirements().is_empty(),
		"HPP-U02: runtime dependencies do not leak into Profile requirements"
	)
	_expect(
		not profile.has_method(&"get_target_height_meters")
		and not profile.has_method(&"apply_hover_force"),
		"HPP-U02: Profile contains no model parameters or sink behavior"
	)


func _test_snapshot_contract() -> void:

	var first := BuiltinDeviceProfiles.create_spring_damper_hover_point()
	var second := BuiltinDeviceProfiles.create_spring_damper_hover_point()

	_expect(
		first != second
		and first.get_profile_id() == second.get_profile_id(),
		"HPP-U03: each call returns a new Snapshot with canonical identity"
	)
	_expect(
		first.is_canonical()
		and first.get_based_on_profile_id() == &""
		and first.get_based_on_profile_version() == 0,
		"HPP-U03: Profile is canonical and not derived"
	)

	var capabilities := first.get_capabilities()
	capabilities.append("external_mutation")

	_expect(
		first.get_capabilities() == ["hover_lift_force"],
		"HPP-U03: returned capability Array is isolated"
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
