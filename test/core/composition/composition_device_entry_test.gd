extends Node


##
## CompositionDeviceEntryTest
##
## Verifica identidad, Configuration,
## Factory Key, Dependency Specs,
## inmutabilidad y ausencia de runtime activo.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("CompositionDeviceEntryTest")
	print("========================================")

	_test_valid_simulation_entry()
	_test_valid_hardware_entry()
	_test_required_components()
	_test_identity_mismatches()
	_test_dependency_validation()
	_test_dependency_lookup()
	_test_collection_independence()
	_test_contract()

	_finish_test()


# =============================================================================
# VALID SIMULATION ENTRY
# =============================================================================

func _test_valid_simulation_entry() -> void:

	var configuration := _valid_configuration()
	var factory_key := _valid_factory_key()

	var borrowed_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var transferred_spec := RuntimeDependencySpec.new(
		&"distance_provider",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var dependency_specs: Array[RuntimeDependencySpec] = [
		borrowed_spec,
		transferred_spec,
	]

	var entry := CompositionDeviceEntry.new(
		"runtime_sensor",
		configuration,
		factory_key,
		dependency_specs
	)

	var entry_value: Variant = entry

	_expect(
		entry.is_valid(),
		"CDE-U01: complete Simulation Entry is valid"
	)

	_expect(
		entry.get_device_id() == "runtime_sensor",
		"CDE-U01: Device ID is preserved"
	)

	_expect(
		entry.get_configuration() == configuration,
		"CDE-U01: Configuration reference is preserved"
	)

	_expect(
		entry.get_factory_key() == factory_key,
		"CDE-U01: Factory Key reference is preserved"
	)

	var returned_specs := entry.get_dependency_specs()

	_expect(
		returned_specs.size() == 2
		and returned_specs[0] == borrowed_spec
		and returned_specs[1] == transferred_spec,
		"CDE-U01: Dependency Spec order is preserved"
	)

	_expect(
		entry.has_dependency(
			&"runtime_clock"
		)
		and entry.has_dependency(
			&"distance_provider"
		),
		"CDE-U01: declared Dependencies are discoverable"
	)

	_expect(
		entry_value is RefCounted
		and not (entry_value is Node),
		"CDE-U01: Entry is RefCounted and not Node"
	)


# =============================================================================
# VALID HARDWARE ENTRY
# =============================================================================

func _test_valid_hardware_entry() -> void:

	var configuration := _configuration(
		"hardware_sensor",
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	var factory_key := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	var dependency_specs: Array[RuntimeDependencySpec] = []

	var entry := CompositionDeviceEntry.new(
		"hardware_sensor",
		configuration,
		factory_key,
		dependency_specs
	)

	_expect(
		entry.is_valid(),
		"CDE-U02: complete Hardware Entry is valid"
	)

	_expect(
		entry.get_configuration().get_activation_context()
		== DeviceConfiguration.ActivationContext.HARDWARE
		and entry.get_factory_key().get_activation_context()
		== DeviceConfiguration.ActivationContext.HARDWARE,
		"CDE-U02: Hardware context is preserved"
	)


# =============================================================================
# REQUIRED COMPONENTS
# =============================================================================

func _test_required_components() -> void:

	var valid_configuration := _valid_configuration()
	var valid_key := _valid_factory_key()
	var empty_specs: Array[RuntimeDependencySpec] = []

	var missing_device_id := CompositionDeviceEntry.new(
		"",
		valid_configuration,
		valid_key,
		empty_specs
	)

	var missing_configuration := CompositionDeviceEntry.new(
		"runtime_sensor",
		null,
		valid_key,
		empty_specs
	)

	var invalid_configuration := CompositionDeviceEntry.new(
		"runtime_sensor",
		_invalid_configuration(),
		valid_key,
		empty_specs
	)

	var missing_factory_key := CompositionDeviceEntry.new(
		"runtime_sensor",
		valid_configuration,
		null,
		empty_specs
	)

	var invalid_factory_key := CompositionDeviceEntry.new(
		"runtime_sensor",
		valid_configuration,
		RuntimeFactoryKey.new(
			&"",
			2,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		empty_specs
	)

	_expect(
		not missing_device_id.is_valid(),
		"CDE-U03: missing Device ID is invalid"
	)

	_expect(
		not missing_configuration.is_valid(),
		"CDE-U03: null Configuration is invalid"
	)

	_expect(
		not invalid_configuration.is_valid(),
		"CDE-U03: invalid Configuration is rejected"
	)

	_expect(
		not missing_factory_key.is_valid(),
		"CDE-U03: null Factory Key is invalid"
	)

	_expect(
		not invalid_factory_key.is_valid(),
		"CDE-U03: invalid Factory Key is rejected"
	)


# =============================================================================
# IDENTITY MISMATCHES
# =============================================================================

func _test_identity_mismatches() -> void:

	var configuration := _valid_configuration()
	var empty_specs: Array[RuntimeDependencySpec] = []

	var device_id_mismatch := CompositionDeviceEntry.new(
		"different_device",
		configuration,
		_valid_factory_key(),
		empty_specs
	)

	var profile_id_mismatch := CompositionDeviceEntry.new(
		"runtime_sensor",
		configuration,
		RuntimeFactoryKey.new(
			&"test.runtime.other",
			2,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		empty_specs
	)

	var profile_version_mismatch := CompositionDeviceEntry.new(
		"runtime_sensor",
		configuration,
		RuntimeFactoryKey.new(
			&"test.runtime.sensor",
			3,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		empty_specs
	)

	var context_mismatch := CompositionDeviceEntry.new(
		"runtime_sensor",
		configuration,
		RuntimeFactoryKey.new(
			&"test.runtime.sensor",
			2,
			DeviceConfiguration.ActivationContext.HARDWARE
		),
		empty_specs
	)

	_expect(
		not device_id_mismatch.is_valid(),
		"CDE-U04: Device ID mismatch is rejected"
	)

	_expect(
		not profile_id_mismatch.is_valid(),
		"CDE-U04: Profile ID mismatch is rejected"
	)

	_expect(
		not profile_version_mismatch.is_valid(),
		"CDE-U04: Profile Version mismatch is rejected"
	)

	_expect(
		not context_mismatch.is_valid(),
		"CDE-U04: Activation Context mismatch is rejected"
	)


# =============================================================================
# DEPENDENCY VALIDATION
# =============================================================================

func _test_dependency_validation() -> void:

	var null_specs: Array[RuntimeDependencySpec] = [
		null,
	]

	var invalid_id_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			&"",
			RuntimeDependencyBinding.Ownership.BORROWED
		),
	]

	var invalid_ownership_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			&"runtime_clock",
			99
		),
	]

	var shared_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var duplicate_reference_specs: Array[RuntimeDependencySpec] = [
		shared_spec,
		shared_spec,
	]

	var duplicate_id_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			&"runtime_clock",
			RuntimeDependencyBinding.Ownership.BORROWED
		),
		RuntimeDependencySpec.new(
			&"runtime_clock",
			RuntimeDependencyBinding.Ownership.TRANSFERRED
		),
	]

	var distinct_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			&"runtime_clock",
			RuntimeDependencyBinding.Ownership.BORROWED
		),
		RuntimeDependencySpec.new(
			&"distance_provider",
			RuntimeDependencyBinding.Ownership.TRANSFERRED
		),
	]

	var null_spec_entry := _entry_with_specs(
		null_specs
	)

	var invalid_id_entry := _entry_with_specs(
		invalid_id_specs
	)

	var invalid_ownership_entry := _entry_with_specs(
		invalid_ownership_specs
	)

	var duplicate_reference_entry := _entry_with_specs(
		duplicate_reference_specs
	)

	var duplicate_id_entry := _entry_with_specs(
		duplicate_id_specs
	)

	var distinct_specs_entry := _entry_with_specs(
		distinct_specs
	)

	_expect(
		not null_spec_entry.is_valid(),
		"CDE-U05: null Dependency Spec is rejected"
	)

	_expect(
		not invalid_id_entry.is_valid(),
		"CDE-U05: invalid Dependency ID is rejected"
	)

	_expect(
		not invalid_ownership_entry.is_valid(),
		"CDE-U05: invalid Dependency Ownership is rejected"
	)

	_expect(
		not duplicate_reference_entry.is_valid(),
		"CDE-U05: duplicate Dependency Spec reference is rejected"
	)

	_expect(
		not duplicate_id_entry.is_valid(),
		"CDE-U05: duplicate Dependency ID is rejected"
	)

	_expect(
		distinct_specs_entry.is_valid(),
		"CDE-U05: distinct valid Dependency Specs are accepted"
	)


# =============================================================================
# DEPENDENCY LOOKUP
# =============================================================================

func _test_dependency_lookup() -> void:

	var first_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var second_spec := RuntimeDependencySpec.new(
		&"distance_provider",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var specs: Array[RuntimeDependencySpec] = [
		first_spec,
		second_spec,
	]

	var entry := _entry_with_specs(
		specs
	)

	_expect(
		entry.has_dependency(
			&"runtime_clock"
		)
		and entry.has_dependency(
			&"distance_provider"
		)
		and not entry.has_dependency(
			&"missing"
		),
		"CDE-U06: exact Dependency presence lookup works"
	)

	_expect(
		entry.get_dependency_spec(
			&"runtime_clock"
		) == first_spec
		and entry.get_dependency_spec(
			&"distance_provider"
		) == second_spec,
		"CDE-U06: exact Dependency lookup preserves references"
	)

	_expect(
		entry.get_dependency_spec(
			&"missing"
		) == null,
		"CDE-U06: missing Dependency lookup returns null"
	)

	_expect(
		not entry.has_dependency(
			&""
		)
		and entry.get_dependency_spec(
			&""
		) == null,
		"CDE-U06: empty Dependency ID does not resolve"
	)


# =============================================================================
# COLLECTION INDEPENDENCE
# =============================================================================

func _test_collection_independence() -> void:

	var first_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var second_spec := RuntimeDependencySpec.new(
		&"distance_provider",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var source_specs: Array[RuntimeDependencySpec] = [
		first_spec,
	]

	var entry := CompositionDeviceEntry.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		source_specs
	)

	source_specs.append(
		second_spec
	)

	var stored_after_source_change := (
		entry.get_dependency_specs()
	)

	_expect(
		stored_after_source_change.size() == 1
		and stored_after_source_change[0] == first_spec
		and not entry.has_dependency(
			&"distance_provider"
		),
		"CDE-U07: constructor copies Dependency Spec Array"
	)

	var returned_specs := entry.get_dependency_specs()

	returned_specs.clear()

	var stored_after_return_change := (
		entry.get_dependency_specs()
	)

	_expect(
		stored_after_return_change.size() == 1
		and stored_after_return_change[0] == first_spec,
		"CDE-U07: getter returns independent Dependency Spec Array"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var empty_specs: Array[RuntimeDependencySpec] = []

	var entry := CompositionDeviceEntry.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		empty_specs
	)

	_expect(
		not entry.has_method(
			&"set_device_id"
		)
		and not entry.has_method(
			&"set_configuration"
		)
		and not entry.has_method(
			&"set_factory_key"
		)
		and not entry.has_method(
			&"set_dependency_specs"
		),
		"CDE-U08: Entry exposes no setters"
	)

	_expect(
		not entry.has_method(
			&"get_factory"
		)
		and not entry.has_method(
			&"build"
		)
		and not entry.has_method(
			&"release"
		),
		"CDE-U08: Entry contains no factory execution"
	)

	_expect(
		not entry.has_method(
			&"get_dependency_binding"
		)
		and not entry.has_method(
			&"get_dependency_value"
		)
		and not entry.has_method(
			&"get_value"
		),
		"CDE-U08: Entry contains no active Dependency Values"
	)

	_expect(
		not entry.has_method(
			&"get_runtime_handle"
		)
		and not entry.has_method(
			&"get_primary_runtime_object"
		)
		and not entry.has_method(
			&"get_host_objects"
		),
		"CDE-U08: Entry contains no active Runtime Objects"
	)

	_expect(
		not entry.has_method(
			&"get_device_bus"
		)
		and not entry.has_method(
			&"publish"
		)
		and not entry.has_method(
			&"subscribe"
		),
		"CDE-U08: Entry contains no active DeviceBus"
	)

	_expect(
		not entry.has_method(
			&"execute"
		)
		and not entry.has_method(
			&"activate"
		)
		and not entry.has_method(
			&"create_device"
		),
		"CDE-U08: Entry is not executable"
	)

	_expect(
		not entry.has_method(
			&"resolve"
		)
		and not entry.has_method(
			&"get_service"
		),
		"CDE-U08: Entry is not a service locator"
	)

	_expect(
		not entry.has_method(
			&"add_dependency"
		)
		and not entry.has_method(
			&"remove_dependency"
		)
		and not entry.has_method(
			&"clear_dependencies"
		),
		"CDE-U08: Entry exposes no collection mutation"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _valid_factory_key(
) -> RuntimeFactoryKey:

	return RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)


func _valid_configuration(
) -> DeviceConfiguration:

	return _configuration(
		"runtime_sensor",
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)


func _invalid_configuration(
) -> DeviceConfiguration:

	return _configuration(
		"",
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)


func _configuration(
	device_id: String,
	profile_id: StringName,
	profile_version: int,
	activation_context: int
) -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"composition_plan",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		&"test.composition.device_entry.configuration",
		1,
		device_id,
		profile_id,
		profile_version,
		activation_context,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _entry_with_specs(
	specs: Array[RuntimeDependencySpec]
) -> CompositionDeviceEntry:

	return CompositionDeviceEntry.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		specs
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
