extends Node


##
## DeviceCatalogDraftTest
##
## Verifica colección editable y
## límites de responsabilidad del Draft.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceCatalogDraftTest")
	print("========================================")

	_test_initial_state()
	_test_editable_profiles()
	_test_contract()

	_finish_test()


# =============================================================================
# INITIAL STATE
# =============================================================================

func _test_initial_state() -> void:

	var draft := DeviceCatalogDraft.new()
	var draft_value: Variant = draft

	_expect(
		draft.profiles.is_empty(),
		"DCD-U01: initial Profiles are empty"
	)

	_expect(
		draft_value is RefCounted,
		"DCD-U01: Draft is RefCounted"
	)

	_expect(
		not (draft_value is Node),
		"DCD-U01: Draft is not Node"
	)


# =============================================================================
# EDITABLE PROFILES
# =============================================================================

func _test_editable_profiles() -> void:

	var draft := DeviceCatalogDraft.new()

	var version_one := _device_profile(
		&"test.sensor",
		1
	)

	var version_two := _device_profile(
		&"test.sensor",
		2
	)

	draft.profiles.append(
		version_one
	)

	draft.profiles.append(
		version_two
	)

	draft.profiles.append(
		null
	)

	_expect(
		draft.profiles.size() == 3,
		"DCD-U02: Profiles collection is editable"
	)

	_expect(
		draft.profiles[0] == version_one
		and draft.profiles[1] == version_two,
		"DCD-U02: insertion order is preserved"
	)

	_expect(
		draft.profiles[2] == null,
		"DCD-U02: Draft can represent missing Profile"
	)

	_expect(
		version_one.is_valid()
		and version_two.is_valid(),
		"DCD-U02: valid Profile snapshots are accepted"
	)

	_expect(
		version_one.get_profile_id()
		== version_two.get_profile_id()
		and version_one.get_profile_version()
		!= version_two.get_profile_version(),
		"DCD-U02: same ID can hold different versions"
	)

	draft.profiles.clear()

	_expect(
		draft.profiles.is_empty(),
		"DCD-U02: Profiles collection can be cleared"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var draft := DeviceCatalogDraft.new()

	_expect(
		not draft.has_method(
			&"compile"
		),
		"DCD-U03: Draft does not compile itself"
	)

	_expect(
		not draft.has_method(
			&"has_profile"
		)
		and not draft.has_method(
			&"get_profile"
		),
		"DCD-U03: Draft is not a resolver"
	)

	_expect(
		not draft.has_method(
			&"register_profile"
		)
		and not draft.has_method(
			&"remove_profile"
		)
		and not draft.has_method(
			&"replace_profile"
		),
		"DCD-U03: Draft adds no premature registry API"
	)

	_expect(
		not draft.has_method(
			&"save"
		)
		and not draft.has_method(
			&"load"
		),
		"DCD-U03: Draft has no persistence API"
	)

	_expect(
		not draft.has_method(
			&"create_device"
		)
		and not draft.has_method(
			&"get_factory"
		)
		and not draft.has_method(
			&"execute"
		),
		"DCD-U03: Draft has no runtime responsibility"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _device_profile(
	profile_id: StringName,
	profile_version: int
) -> DeviceProfile:

	var capabilities: Array[String] = [
		"catalog_test",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceProfile.new(
		profile_id,
		profile_version,
		"Catalog Test Profile",
		"DeviceCatalogDraft fixture.",
		DeviceRoles.LOCAL_CONTROLLER,
		capabilities,
		publishes,
		subscribes,
		requirements,
		false,
		&"",
		0
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
