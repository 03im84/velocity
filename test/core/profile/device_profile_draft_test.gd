extends Node


##
## DeviceProfileDraftTest
##
## Verifica identidad, derivación
## y edición de DeviceProfileDraft.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceProfileDraftTest")
	print("========================================")

	_test_initial_draft()
	_test_required_identity_fields()
	_test_unknown_role()
	_test_based_on_rules()
	_test_complete_draft()
	_test_editability()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_initial_draft() -> void:

	var draft := DeviceProfileDraft.new()

	_expect(
		not draft.is_valid_identity(),
		"DPD-U01: initial Draft is invalid"
	)


func _test_required_identity_fields() -> void:

	var empty_id := _valid_draft()

	empty_id.profile_id = &""

	_expect(
		not empty_id.is_valid_identity(),
		"DPD-U02: profile ID is required"
	)

	var invalid_version := _valid_draft()

	invalid_version.profile_version = 0

	_expect(
		not invalid_version.is_valid_identity(),
		"DPD-U02: positive version is required"
	)

	var empty_name := _valid_draft()

	empty_name.display_name = ""

	_expect(
		not empty_name.is_valid_identity(),
		"DPD-U02: display name is required"
	)

	var empty_role := _valid_draft()

	empty_role.primary_role = &""

	_expect(
		not empty_role.is_valid_identity(),
		"DPD-U02: primary role is required"
	)


func _test_unknown_role() -> void:

	var draft := _valid_draft()

	draft.primary_role = &"unknown_role"

	_expect(
		not draft.is_valid_identity(),
		"DPD-U03: unknown role is invalid"
	)


func _test_based_on_rules() -> void:

	var root_with_parent_version := (
		_valid_draft()
	)

	root_with_parent_version.based_on_profile_id = &""

	root_with_parent_version.based_on_profile_version = 1

	_expect(
		not root_with_parent_version
			.is_valid_identity(),
		"DPD-U04: root Draft requires parent version zero"
	)

	var derived_without_parent_version := (
		_valid_draft()
	)

	derived_without_parent_version.based_on_profile_id = (
			&"user.base_profile"
		)

	derived_without_parent_version.based_on_profile_version = 0

	_expect(
		not derived_without_parent_version
			.is_valid_identity(),
		"DPD-U04: derived Draft requires parent version"
	)

	var valid_derived := _valid_draft()

	valid_derived.based_on_profile_id = (
		&"user.base_profile"
	)

	valid_derived.based_on_profile_version = 1

	_expect(
		valid_derived.is_valid_identity(),
		"DPD-U04: valid parent reference is accepted"
	)


func _test_complete_draft() -> void:

	var draft := _valid_draft()

	_expect(
		draft.is_valid_identity(),
		"DPD-U05: complete Draft identity is valid"
	)


func _test_editability() -> void:

	var draft := _valid_draft()

	draft.display_name = (
		"Edited Profile Name"
	)

	_expect(
		draft.display_name
		== "Edited Profile Name",
		"DPD-U06: Draft fields are editable"
	)

	draft.capabilities.append(
		"distance_measurement"
	)

	_expect(
		draft.capabilities == [
			"distance_measurement",
		],
		"DPD-U06: Draft lists are editable"
	)


# =============================================================================
# HELPERS
# =============================================================================

func _valid_draft() -> DeviceProfileDraft:

	var draft := DeviceProfileDraft.new()

	draft.profile_id = (
		&"user.distance_sensor.test"
	)

	draft.profile_version = 1

	draft.display_name = (
		"Test Distance Sensor"
	)

	draft.primary_role = (
		DeviceRoles.SENSOR
	)

	draft.based_on_profile_id = &""

	draft.based_on_profile_version = 0

	return draft


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
