extends Node


##
## SystemProfileDraftTest
##
## Verifica identidad editable,
## Activation Context y colecciones Draft.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("SystemProfileDraftTest")
	print("========================================")

	_test_initial_state()
	_test_invalid_identity()
	_test_valid_contexts()
	_test_editable_fields()
	_test_editable_collections()
	_test_contract()

	_finish_test()


# =============================================================================
# INITIAL STATE
# =============================================================================

func _test_initial_state() -> void:

	var draft := SystemProfileDraft.new()

	_expect(
		draft.system_profile_id == &"",
		"SPD-U01: initial System Profile ID is empty"
	)

	_expect(
		draft.system_profile_version == 1,
		"SPD-U01: initial version is one"
	)

	_expect(
		draft.display_name.is_empty(),
		"SPD-U01: initial Display Name is empty"
	)

	_expect(
		draft.description.is_empty(),
		"SPD-U01: initial description is empty"
	)

	_expect(
		draft.activation_context
		== DeviceConfiguration.ActivationContext.SIMULATION,
		"SPD-U01: initial context is Simulation"
	)

	_expect(
		draft.device_configurations.is_empty(),
		"SPD-U01: initial Configurations are empty"
	)

	_expect(
		draft.connection_specs.is_empty(),
		"SPD-U01: initial Connection Specs are empty"
	)

	_expect(
		not draft.has_valid_identity(),
		"SPD-U01: initial identity is invalid"
	)


# =============================================================================
# INVALID IDENTITY
# =============================================================================

func _test_invalid_identity() -> void:

	var missing_id := _valid_draft()

	missing_id.system_profile_id = &""

	_expect(
		not missing_id.has_valid_identity(),
		"SPD-U02: System Profile ID is required"
	)

	var zero_version := _valid_draft()

	zero_version.system_profile_version = 0

	_expect(
		not zero_version.has_valid_identity(),
		"SPD-U02: version zero is invalid"
	)

	var negative_version := _valid_draft()

	negative_version.system_profile_version = -1

	_expect(
		not negative_version.has_valid_identity(),
		"SPD-U02: negative version is invalid"
	)

	var whitespace_name := _valid_draft()

	whitespace_name.display_name = "   "

	_expect(
		not whitespace_name.has_valid_identity(),
		"SPD-U02: whitespace Display Name is invalid"
	)

	var invalid_context := _valid_draft()

	invalid_context.activation_context = -1

	_expect(
		not invalid_context.has_valid_identity(),
		"SPD-U02: unknown Activation Context is invalid"
	)


# =============================================================================
# VALID CONTEXTS
# =============================================================================

func _test_valid_contexts() -> void:

	var simulation_draft := _valid_draft()

	simulation_draft.activation_context = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	_expect(
		simulation_draft.has_valid_identity(),
		"SPD-U03: Simulation context is valid"
	)

	var hardware_draft := _valid_draft()

	hardware_draft.activation_context = (
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	_expect(
		hardware_draft.has_valid_identity(),
		"SPD-U03: Hardware context is valid"
	)

	var optional_description := _valid_draft()

	optional_description.description = ""

	_expect(
		optional_description.has_valid_identity(),
		"SPD-U03: description is optional"
	)


# =============================================================================
# EDITABLE FIELDS
# =============================================================================

func _test_editable_fields() -> void:

	var draft := SystemProfileDraft.new()

	draft.system_profile_id = &"test.edited_system"
	draft.system_profile_version = 7
	draft.display_name = "Edited System"
	draft.description = "Editable composition."
	draft.activation_context = (
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	_expect(
		draft.system_profile_id
		== &"test.edited_system",
		"SPD-U04: System Profile ID is editable"
	)

	_expect(
		draft.system_profile_version == 7,
		"SPD-U04: version is editable"
	)

	_expect(
		draft.display_name
		== "Edited System",
		"SPD-U04: Display Name is editable"
	)

	_expect(
		draft.description
		== "Editable composition.",
		"SPD-U04: description is editable"
	)

	_expect(
		draft.activation_context
		== DeviceConfiguration.ActivationContext.HARDWARE,
		"SPD-U04: Activation Context is editable"
	)

	_expect(
		draft.has_valid_identity(),
		"SPD-U04: edited identity is valid"
	)


# =============================================================================
# EDITABLE COLLECTIONS
# =============================================================================

func _test_editable_collections() -> void:

	var draft := _valid_draft()

	var configuration: DeviceConfiguration = null

	var spec := SystemConnectionSpec.new(
		"source",
		&"out.topic",
		"target",
		&"in.topic"
	)

	draft.device_configurations.append(
		configuration
	)

	draft.connection_specs.append(
		spec
	)

	_expect(
		draft.device_configurations.size() == 1,
		"SPD-U05: Configuration collection is editable"
	)

	_expect(
		draft.connection_specs.size() == 1,
		"SPD-U05: Connection collection is editable"
	)

	_expect(
		draft.connection_specs[0] == spec,
		"SPD-U05: Connection Spec reference is preserved"
	)

	_expect(
		draft.has_valid_identity(),
		"SPD-U05: identity validation ignores collection contents"
	)

	draft.device_configurations.clear()
	draft.connection_specs.clear()

	_expect(
		draft.device_configurations.is_empty()
		and draft.connection_specs.is_empty(),
		"SPD-U05: Draft collections can be cleared"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var draft := SystemProfileDraft.new()
	var draft_value: Variant = draft

	_expect(
		draft_value is RefCounted,
		"SPD-U06: Draft is RefCounted"
	)

	_expect(
		not (draft_value is Node),
		"SPD-U06: Draft is not Node"
	)

	_expect(
		not draft.has_method(
			&"execute"
		)
		and not draft.has_method(
			&"activate"
		),
		"SPD-U06: Draft is not executable"
	)

	_expect(
		not draft.has_method(
			&"save"
		)
		and not draft.has_method(
			&"load"
		),
		"SPD-U06: Draft has no persistence API"
	)

	_expect(
		not draft.has_method(
			&"create_snapshot"
		)
		and not draft.has_method(
			&"connect_ports"
		),
		"SPD-U06: Draft does not construct DeviceGraph"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _valid_draft() -> SystemProfileDraft:

	var draft := SystemProfileDraft.new()

	draft.system_profile_id = &"test.system_profile"
	draft.system_profile_version = 1
	draft.display_name = "Test System Profile"
	draft.description = "SystemProfileDraft fixture."
	draft.activation_context = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)

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
