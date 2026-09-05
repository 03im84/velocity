extends Node


##
## RuntimeFactoryRegistryDraftTest
##
## Verifica colección editable,
## estado incompleto y límites de
## responsabilidad del Registry Draft.
##


const RuntimeTestFactoryScript = preload(
	"res://test/core/runtime/runtime_test_factory.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeFactoryRegistryDraftTest")
	print("========================================")

	_test_initial_state()
	_test_editable_descriptors()
	_test_incomplete_state()
	_test_no_factory_execution()
	_test_contract()

	_finish_test()


# =============================================================================
# INITIAL STATE
# =============================================================================

func _test_initial_state() -> void:

	var draft := RuntimeFactoryRegistryDraft.new()
	var draft_value: Variant = draft

	_expect(
		draft.descriptors.is_empty(),
		"RFRD-U01: initial Descriptors are empty"
	)

	_expect(
		draft_value is RefCounted,
		"RFRD-U01: Draft is RefCounted"
	)

	_expect(
		not (draft_value is Node),
		"RFRD-U01: Draft is not Node"
	)


# =============================================================================
# EDITABLE DESCRIPTORS
# =============================================================================

func _test_editable_descriptors() -> void:

	var draft := RuntimeFactoryRegistryDraft.new()
	var shared_factory := RuntimeTestFactoryScript.new()

	var version_one := _valid_descriptor(
		1,
		shared_factory
	)

	var version_two := _valid_descriptor(
		2,
		shared_factory
	)

	draft.descriptors.append(
		version_one
	)

	draft.descriptors.append(
		version_two
	)

	draft.descriptors.append(
		null
	)

	_expect(
		draft.descriptors.size() == 3,
		"RFRD-U02: Descriptors collection is editable"
	)

	_expect(
		draft.descriptors[0] == version_one
		and draft.descriptors[1] == version_two,
		"RFRD-U02: insertion order is preserved"
	)

	_expect(
		draft.descriptors[2] == null,
		"RFRD-U02: Draft can represent missing Descriptor"
	)

	_expect(
		version_one.is_valid()
		and version_two.is_valid(),
		"RFRD-U02: valid Descriptors are accepted"
	)

	_expect(
		version_one.get_factory()
		== version_two.get_factory()
		and version_one.get_factory()
		== shared_factory,
		"RFRD-U02: same factory Object can use different Keys"
	)

	var first_key := version_one.get_factory_key()
	var second_key := version_two.get_factory_key()

	_expect(
		first_key.get_profile_id()
		== second_key.get_profile_id()
		and first_key.get_profile_version()
		!= second_key.get_profile_version()
		and first_key.get_activation_context()
		== second_key.get_activation_context(),
		"RFRD-U02: different exact Keys remain independent"
	)

	draft.descriptors.clear()

	_expect(
		draft.descriptors.is_empty(),
		"RFRD-U02: Descriptors collection can be cleared"
	)


# =============================================================================
# INCOMPLETE STATE
# =============================================================================

func _test_incomplete_state() -> void:

	var draft := RuntimeFactoryRegistryDraft.new()
	var factory := RuntimeTestFactoryScript.new()

	var empty_specs: Array[RuntimeDependencySpec] = []

	var invalid_descriptor := RuntimeFactoryDescriptor.new(
		null,
		factory,
		empty_specs
	)

	var first_duplicate := _valid_descriptor(
		1,
		factory
	)

	var second_duplicate := _valid_descriptor(
		1,
		factory
	)

	draft.descriptors.append(
		invalid_descriptor
	)

	draft.descriptors.append(
		first_duplicate
	)

	draft.descriptors.append(
		second_duplicate
	)

	_expect(
		draft.descriptors.size() == 3,
		"RFRD-U03: Draft preserves incomplete collection state"
	)

	_expect(
		draft.descriptors[0] == invalid_descriptor
		and not invalid_descriptor.is_valid(),
		"RFRD-U03: Draft can contain invalid Descriptor"
	)

	var first_key := first_duplicate.get_factory_key()
	var second_key := second_duplicate.get_factory_key()

	_expect(
		first_duplicate.is_valid()
		and second_duplicate.is_valid()
		and first_key.equals(
			second_key
		),
		"RFRD-U03: Draft can contain duplicate exact Keys"
	)


# =============================================================================
# NO FACTORY EXECUTION
# =============================================================================

func _test_no_factory_execution() -> void:

	var draft := RuntimeFactoryRegistryDraft.new()
	var factory := RuntimeTestFactoryScript.new()

	var first_descriptor := _valid_descriptor(
		1,
		factory
	)

	var second_descriptor := _valid_descriptor(
		2,
		factory
	)

	draft.descriptors.append(
		first_descriptor
	)

	draft.descriptors.append(
		second_descriptor
	)

	var first_stored := draft.descriptors[0]
	var second_stored := draft.descriptors[1]

	draft.descriptors.clear()

	_expect(
		first_stored == first_descriptor
		and second_stored == second_descriptor
		and factory.get_build_count() == 0
		and factory.get_release_count() == 0,
		"RFRD-U04: editing Draft never executes factory"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var draft := RuntimeFactoryRegistryDraft.new()

	_expect(
		not draft.has_method(
			&"compile"
		)
		and not draft.has_method(
			&"is_valid"
		),
		"RFRD-U05: Draft does not compile or validate itself"
	)

	_expect(
		not draft.has_method(
			&"has_factory"
		)
		and not draft.has_method(
			&"get_factory"
		)
		and not draft.has_method(
			&"get_descriptor"
		),
		"RFRD-U05: Draft is not a resolver"
	)

	_expect(
		not draft.has_method(
			&"register_factory"
		)
		and not draft.has_method(
			&"unregister_factory"
		)
		and not draft.has_method(
			&"replace_factory"
		),
		"RFRD-U05: Draft exposes no Registry mutation API"
	)

	_expect(
		not draft.has_method(
			&"build"
		)
		and not draft.has_method(
			&"release"
		),
		"RFRD-U05: Draft does not execute factory behavior"
	)

	_expect(
		not draft.has_method(
			&"save"
		)
		and not draft.has_method(
			&"load"
		),
		"RFRD-U05: Draft has no persistence API"
	)

	_expect(
		not draft.has_method(
			&"create_device"
		)
		and not draft.has_method(
			&"execute"
		)
		and not draft.has_method(
			&"activate"
		),
		"RFRD-U05: Draft has no runtime responsibility"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _valid_descriptor(
	profile_version: int,
	factory: Object
) -> RuntimeFactoryDescriptor:

	var factory_key := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		profile_version,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var dependency_specs: Array[RuntimeDependencySpec] = []

	return RuntimeFactoryDescriptor.new(
		factory_key,
		factory,
		dependency_specs
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
