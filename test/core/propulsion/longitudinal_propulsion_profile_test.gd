extends Node


## LongitudinalPropulsionProfileTest
##
## Verifica el Profile canónico del actuator longitudinal sin
## modificar baselines aceptadas de BuiltinDeviceProfiles.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("LongitudinalPropulsionProfileTest")
	print("========================================")

	_test_identity_and_metadata()
	_test_effective_contract()
	_test_snapshot_contract()

	_finish()


func _test_identity_and_metadata() -> void:

	var profile := BuiltinDeviceProfiles.create_longitudinal_propulsion_actuator()

	_expect(
		profile.is_valid(),
		"LPP-U01: canonical Profile is valid"
	)
	_expect(
		profile.get_profile_id()
		== &"velocity.propulsion.longitudinal"
		and profile.get_profile_version() == 1,
		"LPP-U01: exact Profile identity is preserved"
	)
	_expect(
		profile.get_display_name()
		== "Longitudinal Propulsion Actuator"
		and not profile.get_description().is_empty(),
		"LPP-U01: canonical metadata is present"
	)
	_expect(
		profile.get_primary_role() == DeviceRoles.ACTUATOR,
		"LPP-U01: primary role is ACTUATOR"
	)


func _test_effective_contract() -> void:

	var profile := BuiltinDeviceProfiles.create_longitudinal_propulsion_actuator()
	var expected_capabilities: Array[String] = [
		"longitudinal_propulsion_force",
	]
	var expected_subscribes: Array[StringName] = [
		BusTopics.PROPULSION_COMMAND,
	]

	_expect(
		profile.get_capabilities() == expected_capabilities,
		"LPP-U02: Profile declares exact longitudinal capability"
	)
	_expect(
		profile.get_supported_publishes().is_empty(),
		"LPP-U02: actuator publishes no Topic"
	)
	_expect(
		profile.get_supported_subscribes()
		== expected_subscribes,
		"LPP-U02: actuator subscribes exact Propulsion Topic"
	)
	_expect(
		profile.get_requirements().is_empty(),
		"LPP-U02: runtime dependencies do not leak into Profile requirements"
	)
	_expect(
		not profile.has_method(&"get_max_forward_force_newtons")
		and not profile.has_method(&"apply_propulsion_force"),
		"LPP-U02: Profile contains no model limits or sink behavior"
	)


func _test_snapshot_contract() -> void:

	var first := BuiltinDeviceProfiles.create_longitudinal_propulsion_actuator()
	var second := BuiltinDeviceProfiles.create_longitudinal_propulsion_actuator()

	_expect(
		first != second
		and first.get_profile_id() == second.get_profile_id(),
		"LPP-U03: each call returns a new Snapshot with canonical identity"
	)
	_expect(
		first.is_canonical()
		and first.get_based_on_profile_id() == &""
		and first.get_based_on_profile_version() == 0,
		"LPP-U03: Profile is canonical and not derived"
	)

	var capabilities := first.get_capabilities()
	capabilities.append("external_mutation")

	_expect(
		first.get_capabilities()
		== ["longitudinal_propulsion_force"],
		"LPP-U03: returned capability Array is isolated"
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
