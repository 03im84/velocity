extends Node


##
## BuiltinDeviceProfilesTest
##
## Verifica el primer Profile canónico
## e ideal incluido con Velocity.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("BuiltinDeviceProfilesTest")
	print("========================================")

	_test_ideal_distance_sensor()

	_finish_test()


# =============================================================================
# TEST
# =============================================================================

func _test_ideal_distance_sensor() -> void:

	var first_profile := (
		BuiltinDeviceProfiles
			.create_ideal_distance_sensor()
	)

	var second_profile := (
		BuiltinDeviceProfiles
			.create_ideal_distance_sensor()
	)

	_expect(
		first_profile != null,
		"BDP-U01: Profile is created"
	)

	_expect(
		first_profile.is_valid(),
		"BDP-U01: Profile is valid"
	)

	_expect(
		first_profile.get_profile_id()
		== &"velocity.distance_sensor.ideal",
		"BDP-U01: canonical ID is correct"
	)

	_expect(
		first_profile.get_profile_version() == 1,
		"BDP-U01: version is one"
	)

	_expect(
		first_profile.get_display_name()
		== "Ideal Distance Sensor",
		"BDP-U01: display name is correct"
	)

	_expect(
		first_profile.get_primary_role()
		== DeviceRoles.SENSOR,
		"BDP-U01: primary role is SENSOR"
	)

	_expect(
		first_profile.is_canonical(),
		"BDP-U01: Profile is canonical"
	)

	_expect(
		first_profile.get_capabilities() == [
			"distance_measurement",
			"health_reporting",
		],
		"BDP-U01: capabilities are correct"
	)

	_expect(
		first_profile.get_supported_publishes()
		== [
			BusTopics.DISTANCE_MEASUREMENT,
			BusTopics.HEALTH_REPORT,
		],
		"BDP-U01: published topics are correct"
	)

	_expect(
		first_profile
			.get_supported_subscribes()
			.is_empty(),
		"BDP-U01: subscribes are empty"
	)

	_expect(
		first_profile.get_requirements().is_empty(),
		"BDP-U01: requirements are empty"
	)

	_expect(
		first_profile != second_profile,
		"BDP-U01: factory returns different instances"
	)

	_expect(
		first_profile.get_profile_id()
		== second_profile.get_profile_id(),
		"BDP-U01: snapshots have equivalent identity"
	)

	var capabilities_copy: Array[String] = (
		first_profile.get_capabilities()
	)

	capabilities_copy.clear()

	_expect(
		first_profile.get_capabilities().size() == 2,
		"BDP-U01: capabilities copy is independent"
	)

	var publishes_copy: Array[StringName] = (
		first_profile.get_supported_publishes()
	)

	publishes_copy.clear()

	_expect(
		first_profile
			.get_supported_publishes()
			.size() == 2,
		"BDP-U01: publishes copy is independent"
	)

	_expect(
		not first_profile.has_method(
			&"set_profile_id"
		),
		"BDP-U01: canonical Profile has no setters"
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
