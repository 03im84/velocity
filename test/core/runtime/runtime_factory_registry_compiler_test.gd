extends Node


##
## RuntimeFactoryRegistryCompilerTest
##
## Verifica compilación inmutable,
## resolución exacta, múltiples versiones,
## múltiples contextos y ausencia
## de ejecución de factories.
##


const RuntimeTestFactoryScript = preload(
	"res://test/core/runtime/runtime_test_factory.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeFactoryRegistryCompilerTest")
	print("========================================")

	_test_null_draft()
	_test_empty_registry()
	_test_descriptor_validation()
	_test_duplicate_factory_key()
	_test_exact_resolution()
	_test_snapshot_independence()
	_test_direct_registry_validation()
	_test_result_contract()
	_test_no_factory_execution()
	_test_registry_contract()

	_finish_test()


# =============================================================================
# NULL DRAFT
# =============================================================================

func _test_null_draft() -> void:

	var result := RuntimeFactoryRegistryCompiler.new().compile(
		null
	)

	_expect_compile_failure(
		result,
		&"runtime_factory_registry_draft_missing",
		"RFRC-U01: null Draft"
	)


# =============================================================================
# EMPTY REGISTRY
# =============================================================================

func _test_empty_registry() -> void:

	var draft := RuntimeFactoryRegistryDraft.new()

	var result := RuntimeFactoryRegistryCompiler.new().compile(
		draft
	)

	var registry := result.get_registry()

	_expect(
		result.is_success(),
		"RFRC-U02: empty Draft compiles successfully"
	)

	_expect(
		registry != null,
		"RFRC-U02: empty Draft produces Registry"
	)

	if registry == null:
		return

	_expect(
		result.get_report() != null
		and result.get_report().get_issues().is_empty(),
		"RFRC-U02: empty compilation has no Issues"
	)

	_expect(
		registry.is_valid(),
		"RFRC-U02: empty Registry is valid"
	)

	_expect(
		registry.get_descriptors().is_empty(),
		"RFRC-U02: empty Registry has no Descriptors"
	)

	_expect(
		not registry.has_factory(
			null
		)
		and registry.get_descriptor(
			null
		) == null
		and registry.get_factory(
			null
		) == null,
		"RFRC-U02: null Key query is rejected safely"
	)

	var invalid_key := _factory_key(
		&"",
		0,
		-1
	)

	_expect(
		not registry.has_factory(
			invalid_key
		)
		and registry.get_descriptor(
			invalid_key
		) == null
		and registry.get_factory(
			invalid_key
		) == null,
		"RFRC-U02: invalid Key query is rejected safely"
	)

	var missing_key := _factory_key(
		&"test.missing",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	_expect(
		not registry.has_factory(
			missing_key
		)
		and registry.get_descriptor(
			missing_key
		) == null
		and registry.get_factory(
			missing_key
		) == null,
		"RFRC-U02: empty Registry returns no fallback"
	)


# =============================================================================
# DESCRIPTOR VALIDATION
# =============================================================================

func _test_descriptor_validation() -> void:

	var null_descriptor_draft := RuntimeFactoryRegistryDraft.new()

	null_descriptor_draft.descriptors.append(
		null
	)

	_expect_compile_failure(
		RuntimeFactoryRegistryCompiler.new().compile(
			null_descriptor_draft
		),
		&"runtime_factory_descriptor_missing",
		"RFRC-U03: null Descriptor"
	)

	var invalid_descriptor_draft := RuntimeFactoryRegistryDraft.new()

	invalid_descriptor_draft.descriptors.append(
		_invalid_descriptor()
	)

	_expect_compile_failure(
		RuntimeFactoryRegistryCompiler.new().compile(
			invalid_descriptor_draft
		),
		&"runtime_factory_descriptor_invalid",
		"RFRC-U03: invalid Descriptor"
	)


# =============================================================================
# DUPLICATE FACTORY KEY
# =============================================================================

func _test_duplicate_factory_key() -> void:

	var first_factory := RuntimeTestFactoryScript.new()
	var second_factory := RuntimeTestFactoryScript.new()

	var empty_specs: Array[RuntimeDependencySpec] = []

	var first_descriptor := _descriptor(
		&"test.duplicate",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		first_factory,
		empty_specs
	)

	var second_descriptor := _descriptor(
		&"test.duplicate",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		second_factory,
		empty_specs
	)

	var duplicate_instances := RuntimeFactoryRegistryDraft.new()

	duplicate_instances.descriptors.append(
		first_descriptor
	)

	duplicate_instances.descriptors.append(
		second_descriptor
	)

	_expect_compile_failure(
		RuntimeFactoryRegistryCompiler.new().compile(
			duplicate_instances
		),
		&"duplicate_runtime_factory_key",
		"RFRC-U04: duplicate Key from different Descriptors"
	)

	var repeated_descriptor := RuntimeFactoryRegistryDraft.new()

	repeated_descriptor.descriptors.append(
		first_descriptor
	)

	repeated_descriptor.descriptors.append(
		first_descriptor
	)

	_expect_compile_failure(
		RuntimeFactoryRegistryCompiler.new().compile(
			repeated_descriptor
		),
		&"duplicate_runtime_factory_key",
		"RFRC-U04: repeated Descriptor instance"
	)


# =============================================================================
# EXACT RESOLUTION
# =============================================================================

func _test_exact_resolution() -> void:

	var shared_factory := RuntimeTestFactoryScript.new()
	var hardware_factory := RuntimeTestFactoryScript.new()
	var controller_factory := RuntimeTestFactoryScript.new()

	var sensor_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			&"runtime_clock",
			RuntimeDependencyBinding.Ownership.BORROWED
		),
	]

	var empty_specs: Array[RuntimeDependencySpec] = []

	var sensor_v1_simulation := _descriptor(
		&"test.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		shared_factory,
		sensor_specs
	)

	var sensor_v2_simulation := _descriptor(
		&"test.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION,
		shared_factory,
		empty_specs
	)

	var sensor_v1_hardware := _descriptor(
		&"test.sensor",
		1,
		DeviceConfiguration.ActivationContext.HARDWARE,
		hardware_factory,
		empty_specs
	)

	var controller_v1_simulation := _descriptor(
		&"test.controller",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		controller_factory,
		empty_specs
	)

	var draft := RuntimeFactoryRegistryDraft.new()

	draft.descriptors.append(
		sensor_v1_simulation
	)

	draft.descriptors.append(
		sensor_v2_simulation
	)

	draft.descriptors.append(
		sensor_v1_hardware
	)

	draft.descriptors.append(
		controller_v1_simulation
	)

	var result := RuntimeFactoryRegistryCompiler.new().compile(
		draft
	)

	var registry := result.get_registry()

	_expect(
		result.is_success()
		and registry != null,
		"RFRC-U05: multiple dimensions compile successfully"
	)

	if registry == null:
		return

	_expect(
		result.get_report().get_issues().is_empty(),
		"RFRC-U05: valid compilation has no Issues"
	)

	_expect(
		registry.is_valid(),
		"RFRC-U05: compiled Registry is valid"
	)

	var descriptors := registry.get_descriptors()

	_expect(
		descriptors.size() == 4
		and descriptors[0] == sensor_v1_simulation
		and descriptors[1] == sensor_v2_simulation
		and descriptors[2] == sensor_v1_hardware
		and descriptors[3] == controller_v1_simulation,
		"RFRC-U05: Descriptor order is preserved"
	)

	var sensor_v1_simulation_key := _factory_key(
		&"test.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var sensor_v2_simulation_key := _factory_key(
		&"test.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var sensor_v1_hardware_key := _factory_key(
		&"test.sensor",
		1,
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	var controller_v1_simulation_key := _factory_key(
		&"test.controller",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	_expect(
		registry.has_factory(
			sensor_v1_simulation_key
		)
		and registry.has_factory(
			sensor_v2_simulation_key
		)
		and registry.has_factory(
			sensor_v1_hardware_key
		)
		and registry.has_factory(
			controller_v1_simulation_key
		),
		"RFRC-U05: all exact Keys are available"
	)

	_expect(
		registry.get_descriptor(
			sensor_v1_simulation_key
		) == sensor_v1_simulation
		and registry.get_descriptor(
			sensor_v2_simulation_key
		) == sensor_v2_simulation
		and registry.get_descriptor(
			sensor_v1_hardware_key
		) == sensor_v1_hardware
		and registry.get_descriptor(
			controller_v1_simulation_key
		) == controller_v1_simulation,
		"RFRC-U05: exact lookup returns correct Descriptors"
	)

	_expect(
		registry.get_factory(
			sensor_v1_simulation_key
		) == shared_factory
		and registry.get_factory(
			sensor_v2_simulation_key
		) == shared_factory
		and registry.get_factory(
			sensor_v1_hardware_key
		) == hardware_factory
		and registry.get_factory(
			controller_v1_simulation_key
		) == controller_factory,
		"RFRC-U05: exact lookup returns correct factories"
	)

	var missing_profile_key := _factory_key(
		&"test.unknown",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	_expect(
		not registry.has_factory(
			missing_profile_key
		)
		and registry.get_descriptor(
			missing_profile_key
		) == null
		and registry.get_factory(
			missing_profile_key
		) == null,
		"RFRC-U05: missing Profile ID returns no fallback"
	)

	var missing_version_key := _factory_key(
		&"test.sensor",
		3,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	_expect(
		not registry.has_factory(
			missing_version_key
		)
		and registry.get_descriptor(
			missing_version_key
		) == null
		and registry.get_factory(
			missing_version_key
		) == null,
		"RFRC-U05: missing Profile Version returns no fallback"
	)

	var missing_context_key := _factory_key(
		&"test.controller",
		1,
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	_expect(
		not registry.has_factory(
			missing_context_key
		)
		and registry.get_descriptor(
			missing_context_key
		) == null
		and registry.get_factory(
			missing_context_key
		) == null,
		"RFRC-U05: missing Activation Context returns no fallback"
	)

	_expect(
		sensor_v1_simulation.get_factory()
		== sensor_v2_simulation.get_factory()
		and sensor_v1_simulation.get_factory()
		== shared_factory,
		"RFRC-U05: same factory Object may use different Keys"
	)

	_expect(
		registry.get_descriptor(
			sensor_v1_simulation_key
		) != registry.get_descriptor(
			sensor_v1_hardware_key
		),
		"RFRC-U05: Activation Context participates in exact identity"
	)


# =============================================================================
# SNAPSHOT INDEPENDENCE
# =============================================================================

func _test_snapshot_independence() -> void:

	var factory := RuntimeTestFactoryScript.new()
	var empty_specs: Array[RuntimeDependencySpec] = []

	var first_descriptor := _descriptor(
		&"test.independent",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		factory,
		empty_specs
	)

	var second_descriptor := _descriptor(
		&"test.independent",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION,
		factory,
		empty_specs
	)

	var draft := RuntimeFactoryRegistryDraft.new()

	draft.descriptors.append(
		first_descriptor
	)

	draft.descriptors.append(
		second_descriptor
	)

	var result := RuntimeFactoryRegistryCompiler.new().compile(
		draft
	)

	var registry := result.get_registry()

	_expect(
		result.is_success()
		and registry != null,
		"RFRC-U06: independence fixture compiles"
	)

	if registry == null:
		return

	draft.descriptors.clear()

	_expect(
		registry.get_descriptors().size() == 2,
		"RFRC-U06: Draft mutation does not affect Registry"
	)

	var descriptors_copy := registry.get_descriptors()

	descriptors_copy.clear()

	_expect(
		registry.get_descriptors().size() == 2,
		"RFRC-U06: getter returns independent Descriptor Array"
	)

	_expect(
		registry.get_descriptors()[0] == first_descriptor
		and registry.get_descriptors()[1] == second_descriptor,
		"RFRC-U06: immutable Descriptor references are preserved"
	)

	var first_key := _factory_key(
		&"test.independent",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var second_key := _factory_key(
		&"test.independent",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	_expect(
		registry.get_descriptor(
			first_key
		) == first_descriptor
		and registry.get_descriptor(
			second_key
		) == second_descriptor,
		"RFRC-U06: resolver remains stable after Draft mutation"
	)


# =============================================================================
# DIRECT REGISTRY VALIDATION
# =============================================================================

func _test_direct_registry_validation() -> void:

	var empty_registry := RuntimeFactoryRegistry.new()

	_expect(
		empty_registry.is_valid(),
		"RFRC-U07: directly constructed empty Registry is valid"
	)

	var null_descriptors: Array[RuntimeFactoryDescriptor] = [
		null,
	]

	var null_descriptor_registry := RuntimeFactoryRegistry.new(
		null_descriptors
	)

	_expect(
		not null_descriptor_registry.is_valid(),
		"RFRC-U07: directly constructed null Descriptor Registry is invalid"
	)

	var invalid_descriptors: Array[RuntimeFactoryDescriptor] = [
		_invalid_descriptor(),
	]

	var invalid_descriptor_registry := RuntimeFactoryRegistry.new(
		invalid_descriptors
	)

	_expect(
		not invalid_descriptor_registry.is_valid(),
		"RFRC-U07: directly constructed invalid Descriptor Registry is invalid"
	)

	var duplicate_factory := RuntimeTestFactoryScript.new()
	var empty_specs: Array[RuntimeDependencySpec] = []

	var duplicate_descriptor := _descriptor(
		&"test.direct_duplicate",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		duplicate_factory,
		empty_specs
	)

	var duplicate_descriptors: Array[RuntimeFactoryDescriptor] = [
		duplicate_descriptor,
		duplicate_descriptor,
	]

	var duplicate_registry := RuntimeFactoryRegistry.new(
		duplicate_descriptors
	)

	_expect(
		not duplicate_registry.is_valid(),
		"RFRC-U07: directly constructed duplicate Registry is invalid"
	)


# =============================================================================
# RESULT CONTRACT
# =============================================================================

func _test_result_contract() -> void:

	var valid_report := ValidationReport.new()
	var valid_registry := RuntimeFactoryRegistry.new()

	var duplicate_factory := RuntimeTestFactoryScript.new()
	var empty_specs: Array[RuntimeDependencySpec] = []

	var duplicate_descriptor := _descriptor(
		&"test.result_duplicate",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		duplicate_factory,
		empty_specs
	)

	var duplicate_descriptors: Array[RuntimeFactoryDescriptor] = [
		duplicate_descriptor,
		duplicate_descriptor,
	]

	var invalid_registry := RuntimeFactoryRegistry.new(
		duplicate_descriptors
	)

	_expect(
		not invalid_registry.is_valid(),
		"RFRC-U08: duplicate Registry fixture is invalid"
	)

	var null_registry_result := RuntimeFactoryRegistryCompileResult.new(
		null,
		valid_report
	)

	_expect(
		not null_registry_result.is_success(),
		"RFRC-U08: null Registry produces failed Result"
	)

	var null_report_result := RuntimeFactoryRegistryCompileResult.new(
		valid_registry,
		null
	)

	_expect(
		not null_report_result.is_success(),
		"RFRC-U08: null Report produces failed Result"
	)

	var invalid_registry_result := RuntimeFactoryRegistryCompileResult.new(
		invalid_registry,
		valid_report
	)

	_expect(
		not invalid_registry_result.is_success(),
		"RFRC-U08: valid Report cannot approve invalid Registry"
	)

	var blocking_report := _blocking_report()

	var blocking_result := RuntimeFactoryRegistryCompileResult.new(
		valid_registry,
		blocking_report
	)

	_expect(
		not blocking_result.is_success(),
		"RFRC-U08: blocking Report produces failed Result"
	)

	var valid_result := RuntimeFactoryRegistryCompileResult.new(
		valid_registry,
		valid_report
	)

	_expect(
		valid_result.is_success(),
		"RFRC-U08: valid Registry and Report produce success"
	)

	_expect(
		valid_result.get_registry() == valid_registry
		and valid_result.get_report() == valid_report,
		"RFRC-U08: Result preserves Registry and Report"
	)

	_expect(
		not valid_result.has_method(
			&"set_registry"
		)
		and not valid_result.has_method(
			&"set_report"
		),
		"RFRC-U08: Result exposes no setters"
	)


# =============================================================================
# NO FACTORY EXECUTION
# =============================================================================

func _test_no_factory_execution() -> void:

	var factory := RuntimeTestFactoryScript.new()
	var empty_specs: Array[RuntimeDependencySpec] = []

	var first_descriptor := _descriptor(
		&"test.execution",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		factory,
		empty_specs
	)

	var second_descriptor := _descriptor(
		&"test.execution",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION,
		factory,
		empty_specs
	)

	var draft := RuntimeFactoryRegistryDraft.new()

	draft.descriptors.append(
		first_descriptor
	)

	draft.descriptors.append(
		second_descriptor
	)

	var result := RuntimeFactoryRegistryCompiler.new().compile(
		draft
	)

	var registry := result.get_registry()

	_expect(
		result.is_success()
		and registry != null,
		"RFRC-U09: no-execution fixture compiles"
	)

	if registry != null:

		var first_key := first_descriptor.get_factory_key()

		registry.is_valid()
		registry.get_descriptors()
		registry.has_factory(
			first_key
		)
		registry.get_descriptor(
			first_key
		)
		registry.get_factory(
			first_key
		)

	_expect(
		factory.get_build_count() == 0
		and factory.get_release_count() == 0,
		"RFRC-U09: compile, validation and lookup never execute factory"
	)


# =============================================================================
# REGISTRY CONTRACT
# =============================================================================

func _test_registry_contract() -> void:

	var registry := RuntimeFactoryRegistry.new()
	var registry_value: Variant = registry

	_expect(
		registry_value is RefCounted,
		"RFRC-U10: Registry is RefCounted"
	)

	_expect(
		not (registry_value is Node),
		"RFRC-U10: Registry is not Node"
	)

	_expect(
		not registry.has_method(
			&"register_factory"
		)
		and not registry.has_method(
			&"unregister_factory"
		)
		and not registry.has_method(
			&"replace_factory"
		)
		and not registry.has_method(
			&"clear"
		),
		"RFRC-U10: Registry exposes no mutation API"
	)

	_expect(
		not registry.has_method(
			&"get_latest"
		)
		and not registry.has_method(
			&"get_compatible"
		)
		and not registry.has_method(
			&"get_nearest"
		),
		"RFRC-U10: Registry exposes no fallback resolution"
	)

	_expect(
		not registry.has_method(
			&"save"
		)
		and not registry.has_method(
			&"load"
		),
		"RFRC-U10: Registry has no persistence API"
	)

	_expect(
		not registry.has_method(
			&"build"
		)
		and not registry.has_method(
			&"release"
		)
		and not registry.has_method(
			&"execute"
		),
		"RFRC-U10: Registry does not execute factories"
	)

	_expect(
		not registry.has_method(
			&"get_profile"
		)
		and not registry.has_method(
			&"has_profile"
		),
		"RFRC-U10: Registry is separate from DeviceCatalog"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _factory_key(
	profile_id: StringName,
	profile_version: int,
	activation_context: int
) -> RuntimeFactoryKey:

	return RuntimeFactoryKey.new(
		profile_id,
		profile_version,
		activation_context
	)


func _descriptor(
	profile_id: StringName,
	profile_version: int,
	activation_context: int,
	factory: Object,
	dependency_specs: Array[RuntimeDependencySpec]
) -> RuntimeFactoryDescriptor:

	var factory_key := _factory_key(
		profile_id,
		profile_version,
		activation_context
	)

	return RuntimeFactoryDescriptor.new(
		factory_key,
		factory,
		dependency_specs
	)


func _invalid_descriptor(
) -> RuntimeFactoryDescriptor:

	var empty_specs: Array[RuntimeDependencySpec] = []

	return RuntimeFactoryDescriptor.new(
		_factory_key(
			&"test.invalid",
			1,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		null,
		empty_specs
	)


func _blocking_report(
) -> ValidationReport:

	var report := ValidationReport.new()

	report.add_issue(
		ValidationIssue.new(
			&"test_registry_blocking_issue",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Controlled blocking Registry issue.",
			"test.registry",
			&"registry"
		)
	)

	return report


# =============================================================================
# REPORT HELPERS
# =============================================================================

func _report_has_code(
	report: ValidationReport,
	code: StringName
) -> bool:

	if report == null:
		return false

	for issue: ValidationIssue in report.get_issues():

		if issue.get_code() == code:
			return true

	return false


func _expect_compile_failure(
	result: RuntimeFactoryRegistryCompileResult,
	code: StringName,
	description: String
) -> void:

	_expect(
		not result.is_success(),
		description + " is rejected"
	)

	_expect(
		result.get_registry() == null,
		description + " produces null Registry"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			code
		),
		description + " reports " + String(code)
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
