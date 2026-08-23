extends Node


##
## DeviceConfigurationDraftTest
##
## Verifica identidad, derivación y edición
## de DeviceConfigurationDraft.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceConfigurationDraftTest")
	print("========================================")

	_test_initial_draft()
	_test_required_identity_fields()
	_test_based_on_rules()
	_test_complete_draft()
	_test_editability()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_initial_draft() -> void:

	var draft := DeviceConfigurationDraft.new()

	_expect(
		not draft.is_valid_identity(),
		"DCD-U01: initial Draft is invalid"
	)


func _test_required_identity_fields() -> void:

	var empty_configuration_id := (
		_valid_draft()
	)

	empty_configuration_id.configuration_id = &""

	_expect(
		not empty_configuration_id
			.is_valid_identity(),
		"DCD-U02: configuration ID is required"
	)

	var invalid_configuration_version := (
		_valid_draft()
	)

	invalid_configuration_version.configuration_version = 0

	_expect(
		not invalid_configuration_version
			.is_valid_identity(),
		"DCD-U02: positive configuration version is required"
	)

	var empty_device_id := _valid_draft()

	empty_device_id.device_id = ""

	_expect(
		not empty_device_id.is_valid_identity(),
		"DCD-U02: Device ID is required"
	)

	var empty_profile_id := _valid_draft()

	empty_profile_id.profile_id = &""

	_expect(
		not empty_profile_id.is_valid_identity(),
		"DCD-U02: Profile ID is required"
	)

	var invalid_profile_version := (
		_valid_draft()
	)

	invalid_profile_version.profile_version = 0

	_expect(
		not invalid_profile_version
			.is_valid_identity(),
		"DCD-U02: positive Profile version is required"
	)


func _test_based_on_rules() -> void:

	var root_with_parent_version := (
		_valid_draft()
	)

	root_with_parent_version.based_on_configuration_id = &""

	root_with_parent_version.based_on_configuration_version = 1

	_expect(
		not root_with_parent_version
			.is_valid_identity(),
		"DCD-U03: root Draft requires parent version zero"
	)

	var derived_without_parent_version := (
		_valid_draft()
	)

	derived_without_parent_version.based_on_configuration_id = (
		&"ship_a.base_sensor_configuration"
	)

	derived_without_parent_version.based_on_configuration_version = 0

	_expect(
		not derived_without_parent_version
			.is_valid_identity(),
		"DCD-U03: derived Draft requires parent version"
	)

	var valid_derived := _valid_draft()

	valid_derived.based_on_configuration_id = (
		&"ship_a.base_sensor_configuration"
	)

	valid_derived.based_on_configuration_version = 1

	_expect(
		valid_derived.is_valid_identity(),
		"DCD-U03: valid parent reference is accepted"
	)


func _test_complete_draft() -> void:

	var draft := _valid_draft()

	_expect(
		draft.is_valid_identity(),
		"DCD-U04: complete Draft identity is valid"
	)


func _test_editability() -> void:

	var draft := _valid_draft()

	draft.device_id = (
		"edited_distance_sensor"
	)

	_expect(
		draft.device_id
		== "edited_distance_sensor",
		"DCD-U05: Draft fields are editable"
	)

	draft.enabled_capabilities.append(
		"distance_measurement"
	)

	_expect(
		draft.enabled_capabilities == [
			"distance_measurement",
		],
		"DCD-U05: Draft lists are editable"
	)


# =============================================================================
# HELPERS
# =============================================================================

func _valid_draft() -> DeviceConfigurationDraft:

	var draft := DeviceConfigurationDraft.new()

	draft.configuration_id = (
		&"ship_a.distance_sensor_front_left"
	)

	draft.configuration_version = 1

	draft.device_id = (
		"front_left_distance_sensor"
	)

	draft.profile_id = (
		&"velocity.distance_sensor.ideal"
	)

	draft.profile_version = 1

	draft.based_on_configuration_id = &""

	draft.based_on_configuration_version = 0

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
