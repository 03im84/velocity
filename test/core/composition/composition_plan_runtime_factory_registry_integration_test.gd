extends Node


##
## CompositionPlanRuntimeFactoryRegistryIntegrationTest
##
## Verifica integración declarativa entre
## CompositionPlan y RuntimeFactoryRegistry.
##
## No implementa CompositionCompiler.
## No ejecuta factories.
##


const RuntimeTestFactoryScript = preload(
	"res://test/core/runtime/runtime_test_factory.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("CompositionPlanRuntimeFactoryRegistryIntegrationTest")
	print("========================================")

	_test_plan_keys_resolve_exactly()
	_test_missing_dimensions_have_no_fallback()
	_test_dependency_specs_remain_declarative()
	_test_snapshot_stability()
	_test_contract_separation()

	_finish_test()


# =============================================================================
# EXACT PLAN KEY RESOLUTION
# =============================================================================

func _test_plan_keys_resolve_exactly() -> void:

	var shared_factory := RuntimeTestFactoryScript.new()

	var clock_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var provider_spec := RuntimeDependencySpec.new(
		&"distance_provider",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var version_one_specs: Array[RuntimeDependencySpec] = [
		clock_spec,
	]

	var version_two_specs: Array[RuntimeDependencySpec] = [
		provider_spec,
	]

	var descriptor_one := _descriptor(
		&"test.runtime.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		shared_factory,
		version_one_specs
	)

	var descriptor_two := _descriptor(
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION,
		shared_factory,
		version_two_specs
	)

	var descriptors: Array[RuntimeFactoryDescriptor] = [
		descriptor_one,
		descriptor_two,
	]

	var registry_result := _compile_registry(
		descriptors
	)

	var registry := registry_result.get_registry()

	_expect(
		registry_result.is_success()
		and registry != null,
		"CPRFR-I01: Registry compiles successfully"
	)

	if registry == null:
		return

	var entry_one := _entry(
		"sensor_v1",
		&"test.runtime.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		version_one_specs
	)

	var entry_two := _entry(
		"sensor_v2",
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION,
		version_two_specs
	)

	var entries: Array[CompositionDeviceEntry] = [
		entry_one,
		entry_two,
	]

	var plan := _plan(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries
	)

	_expect(
		plan.is_valid(),
		"CPRFR-I01: Plan with exact Keys is valid"
	)

	_expect(
		registry.has_factory(
			entry_one.get_factory_key()
		)
		and registry.has_factory(
			entry_two.get_factory_key()
		),
		"CPRFR-I01: every Plan Entry Key is available"
	)

	_expect(
		registry.get_descriptor(
			entry_one.get_factory_key()
		) == descriptor_one
		and registry.get_descriptor(
			entry_two.get_factory_key()
		) == descriptor_two,
		"CPRFR-I01: exact Keys resolve correct Descriptors"
	)

	_expect(
		registry.get_factory(
			entry_one.get_factory_key()
		) == shared_factory
		and registry.get_factory(
			entry_two.get_factory_key()
		) == shared_factory,
		"CPRFR-I01: same factory Object resolves under different Keys"
	)

	_expect(
		_specs_match(
			entry_one,
			descriptor_one
		)
		and _specs_match(
			entry_two,
			descriptor_two
		),
		"CPRFR-I01: Plan Entry Specs match Registry Descriptor Specs"
	)

	var plan_entries := plan.get_device_entries()

	_expect(
		plan_entries.size() == 2
		and plan_entries[0].get_factory_key()
		== entry_one.get_factory_key()
		and plan_entries[1].get_factory_key()
		== entry_two.get_factory_key(),
		"CPRFR-I01: Plan preserves exact Factory Key references"
	)

	_expect(
		shared_factory.get_build_count() == 0
		and shared_factory.get_release_count() == 0,
		"CPRFR-I01: compile, Plan validation and lookup do not execute factory"
	)


# =============================================================================
# NO FALLBACK
# =============================================================================

func _test_missing_dimensions_have_no_fallback() -> void:

	var factory := RuntimeTestFactoryScript.new()
	var empty_specs: Array[RuntimeDependencySpec] = []

	var available_descriptor := _descriptor(
		&"test.runtime.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		factory,
		empty_specs
	)

	var descriptors: Array[RuntimeFactoryDescriptor] = [
		available_descriptor,
	]

	var registry_result := _compile_registry(
		descriptors
	)

	var registry := registry_result.get_registry()

	_expect(
		registry_result.is_success()
		and registry != null,
		"CPRFR-I02: no-fallback Registry fixture compiles"
	)

	if registry == null:
		return

	var correct_entry := _entry(
		"correct_sensor",
		&"test.runtime.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		empty_specs
	)

	var missing_version_entry := _entry(
		"missing_version",
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION,
		empty_specs
	)

	var missing_context_entry := _entry(
		"missing_context",
		&"test.runtime.sensor",
		1,
		DeviceConfiguration.ActivationContext.HARDWARE,
		empty_specs
	)

	var missing_profile_entry := _entry(
		"missing_profile",
		&"test.runtime.other",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		empty_specs
	)

	var missing_version_entries: Array[CompositionDeviceEntry] = [
		missing_version_entry,
	]

	var missing_context_entries: Array[CompositionDeviceEntry] = [
		missing_context_entry,
	]

	var missing_profile_entries: Array[CompositionDeviceEntry] = [
		missing_profile_entry,
	]

	var missing_version_plan := _plan(
		DeviceConfiguration.ActivationContext.SIMULATION,
		missing_version_entries
	)

	var missing_context_plan := _plan(
		DeviceConfiguration.ActivationContext.HARDWARE,
		missing_context_entries
	)

	var missing_profile_plan := _plan(
		DeviceConfiguration.ActivationContext.SIMULATION,
		missing_profile_entries
	)

	_expect(
		registry.has_factory(
			correct_entry.get_factory_key()
		),
		"CPRFR-I02: exact available Key resolves"
	)

	_expect(
		missing_version_plan.is_valid()
		and not registry.has_factory(
			missing_version_entry.get_factory_key()
		)
		and registry.get_descriptor(
			missing_version_entry.get_factory_key()
		) == null
		and registry.get_factory(
			missing_version_entry.get_factory_key()
		) == null,
		"CPRFR-I02: missing Version has no fallback"
	)

	_expect(
		missing_context_plan.is_valid()
		and not registry.has_factory(
			missing_context_entry.get_factory_key()
		)
		and registry.get_descriptor(
			missing_context_entry.get_factory_key()
		) == null
		and registry.get_factory(
			missing_context_entry.get_factory_key()
		) == null,
		"CPRFR-I02: missing Context has no fallback"
	)

	_expect(
		missing_profile_plan.is_valid()
		and not registry.has_factory(
			missing_profile_entry.get_factory_key()
		)
		and registry.get_descriptor(
			missing_profile_entry.get_factory_key()
		) == null
		and registry.get_factory(
			missing_profile_entry.get_factory_key()
		) == null,
		"CPRFR-I02: missing Profile ID has no fallback"
	)

	_expect(
		registry.get_factory(
			correct_entry.get_factory_key()
		) == factory
		and not registry.has_method(
			&"get_latest"
		)
		and not registry.has_method(
			&"get_compatible"
		),
		"CPRFR-I02: exact binding remains stable without approximation API"
	)


# =============================================================================
# DECLARATIVE DEPENDENCIES
# =============================================================================

func _test_dependency_specs_remain_declarative() -> void:

	var factory := RuntimeTestFactoryScript.new()

	var dependency_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var specs: Array[RuntimeDependencySpec] = [
		dependency_spec,
	]

	var descriptor := _descriptor(
		&"test.runtime.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		factory,
		specs
	)

	var entry := _entry(
		"declarative_sensor",
		&"test.runtime.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		specs
	)

	_expect(
		_specs_match(
			entry,
			descriptor
		),
		"CPRFR-I03: Entry and Descriptor share declarative requirements"
	)

	_expect(
		not dependency_spec.has_method(
			&"get_value"
		)
		and not dependency_spec.has_method(
			&"get_dependency_value"
		),
		"CPRFR-I03: Dependency Spec contains no active Value"
	)

	_expect(
		not entry.has_method(
			&"get_dependency_binding"
		)
		and not entry.has_method(
			&"get_dependency_value"
		),
		"CPRFR-I03: Plan Entry contains no active Binding"
	)


# =============================================================================
# SNAPSHOT STABILITY
# =============================================================================

func _test_snapshot_stability() -> void:

	var factory := RuntimeTestFactoryScript.new()

	var spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var source_specs: Array[RuntimeDependencySpec] = [
		spec,
	]

	var descriptor := _descriptor(
		&"test.runtime.stable",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		factory,
		source_specs
	)

	var source_descriptors: Array[RuntimeFactoryDescriptor] = [
		descriptor,
	]

	var registry_result := _compile_registry(
		source_descriptors
	)

	var registry := registry_result.get_registry()

	var entry := _entry(
		"stable_device",
		&"test.runtime.stable",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		source_specs
	)

	var source_entries: Array[CompositionDeviceEntry] = [
		entry,
	]

	var plan := _plan(
		DeviceConfiguration.ActivationContext.SIMULATION,
		source_entries
	)

	source_specs.clear()
	source_descriptors.clear()
	source_entries.clear()

	_expect(
		registry_result.is_success()
		and registry != null
		and registry.get_descriptors().size() == 1,
		"CPRFR-I04: Registry remains stable after Draft source mutation"
	)

	if registry == null:
		return

	_expect(
		plan.get_device_entries().size() == 1
		and plan.get_device_entry(
			"stable_device"
		) == entry,
		"CPRFR-I04: Plan remains stable after source Array mutation"
	)

	_expect(
		registry.get_descriptor(
			entry.get_factory_key()
		) == descriptor
		and _specs_match(
			entry,
			descriptor
		),
		"CPRFR-I04: shared immutable references remain coherent"
	)


# =============================================================================
# CONTRACT SEPARATION
# =============================================================================

func _test_contract_separation() -> void:

	var entries: Array[CompositionDeviceEntry] = []

	var plan := _plan(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries
	)

	_expect(
		not plan.has_method(
			&"get_factory"
		)
		and not plan.has_method(
			&"get_factory_registry"
		)
		and not plan.has_method(
			&"get_callable"
		),
		"CPRFR-I05: Plan contains no factory, Registry or Callable"
	)

	_expect(
		not plan.has_method(
			&"get_runtime_handle"
		)
		and not plan.has_method(
			&"get_device_bus"
		)
		and not plan.has_method(
			&"get_dependency_binding"
		),
		"CPRFR-I05: Plan contains no active runtime resource"
	)

	_expect(
		not plan.has_method(
			&"execute"
		)
		and not plan.has_method(
			&"build"
		)
		and not plan.has_method(
			&"release"
		),
		"CPRFR-I05: Plan does not execute Registry factories"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _descriptor(
	profile_id: StringName,
	profile_version: int,
	activation_context: int,
	factory: Object,
	dependency_specs: Array[RuntimeDependencySpec]
) -> RuntimeFactoryDescriptor:

	return RuntimeFactoryDescriptor.new(
		RuntimeFactoryKey.new(
			profile_id,
			profile_version,
			activation_context
		),
		factory,
		dependency_specs
	)


func _entry(
	device_id: String,
	profile_id: StringName,
	profile_version: int,
	activation_context: int,
	dependency_specs: Array[RuntimeDependencySpec]
) -> CompositionDeviceEntry:

	var capabilities: Array[String] = [
		"registry_plan_integration",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	var configuration := DeviceConfiguration.new(
		StringName(
			"test.integration." + device_id
		),
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

	var factory_key := RuntimeFactoryKey.new(
		profile_id,
		profile_version,
		activation_context
	)

	return CompositionDeviceEntry.new(
		device_id,
		configuration,
		factory_key,
		dependency_specs
	)


func _plan(
	activation_context: int,
	entries: Array[CompositionDeviceEntry]
) -> CompositionPlan:

	var directives: Array[CompositionConnectionDirective] = []

	return CompositionPlan.new(
		activation_context,
		entries,
		directives,
		DeviceBusDispatchPolicy.new()
	)


func _compile_registry(
	descriptors: Array[RuntimeFactoryDescriptor]
) -> RuntimeFactoryRegistryCompileResult:

	var draft := RuntimeFactoryRegistryDraft.new()

	for descriptor: RuntimeFactoryDescriptor in descriptors:

		draft.descriptors.append(
			descriptor
		)

	return RuntimeFactoryRegistryCompiler.new().compile(
		draft
	)


func _specs_match(
	entry: CompositionDeviceEntry,
	descriptor: RuntimeFactoryDescriptor
) -> bool:

	var entry_specs := entry.get_dependency_specs()
	var descriptor_specs := descriptor.get_dependency_specs()

	if entry_specs.size() != descriptor_specs.size():
		return false

	for spec_index: int in range(
		entry_specs.size()
	):

		var entry_spec: RuntimeDependencySpec = entry_specs[
			spec_index
		]

		var descriptor_spec: RuntimeDependencySpec = descriptor_specs[
			spec_index
		]

		if entry_spec == null:
			return false

		if descriptor_spec == null:
			return false

		if (
			entry_spec.get_dependency_id()
			!= descriptor_spec.get_dependency_id()
		):
			return false

		if (
			entry_spec.get_ownership()
			!= descriptor_spec.get_ownership()
		):
			return false

	return true


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
