extends Node


##
## SystemCompositionCompilerIntegrationTest
##
## Verifica el pipeline completo hasta
## CompositionPlan sin ejecutar runtime.
##


const RuntimeTestFactoryScript = preload(
	"res://test/core/runtime/runtime_test_factory.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("SystemCompositionCompilerIntegrationTest")
	print("========================================")

	_test_valid_pipeline()
	_test_empty_pipeline()
	_test_cycle_pipeline()
	_test_missing_factory_pipeline()
	_test_pipeline_contract()

	_finish_test()


# =============================================================================
# VALID PIPELINE
# =============================================================================

func _test_valid_pipeline() -> void:

	var distance_topics: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var source_profile := _profile(
		&"test.full_pipeline.source",
		distance_topics,
		_empty_topics()
	)

	var target_profile := _profile(
		&"test.full_pipeline.target",
		_empty_topics(),
		distance_topics
	)

	var catalog_draft := DeviceCatalogDraft.new()

	catalog_draft.profiles.append(
		source_profile
	)

	catalog_draft.profiles.append(
		target_profile
	)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)

	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog != null,
		"SCCI-I01: DeviceCatalog compiles"
	)

	if catalog == null:
		return

	var source_configuration := _configuration(
		"full_source",
		source_profile,
		distance_topics,
		_empty_topics(),
		"full_source"
	)

	var target_configuration := _configuration(
		"full_target",
		target_profile,
		_empty_topics(),
		distance_topics,
		"full_target"
	)

	var system_draft := _system_draft(
		&"test.full_pipeline.system"
	)

	system_draft.device_configurations.append(
		source_configuration
	)

	system_draft.device_configurations.append(
		target_configuration
	)

	var system_spec := SystemConnectionSpec.new(
		"full_source",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"full_target",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	system_draft.connection_specs.append(
		system_spec
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	var system_profile := system_result.get_profile()

	_expect(
		system_result.is_success()
		and system_profile != null,
		"SCCI-I01: SystemProfile compiles"
	)

	if system_profile == null:
		return

	var assembly_result := DeviceGraphAssembler.new().assemble(
		system_profile,
		catalog
	)

	var snapshot := assembly_result.get_snapshot()

	_expect(
		assembly_result.is_success()
		and snapshot != null,
		"SCCI-I01: DeviceGraphAssembler creates Snapshot"
	)

	if snapshot == null:
		return

	var source_factory := RuntimeTestFactoryScript.new()
	var target_factory := RuntimeTestFactoryScript.new()

	var source_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var target_spec := RuntimeDependencySpec.new(
		&"distance_provider",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var source_specs: Array[RuntimeDependencySpec] = [
		source_spec,
	]

	var target_specs: Array[RuntimeDependencySpec] = [
		target_spec,
	]

	var nodes := snapshot.get_devices()

	var descriptors: Array[RuntimeFactoryDescriptor] = [
		_descriptor_for_node(
			nodes[0],
			source_factory,
			source_specs
		),
		_descriptor_for_node(
			nodes[1],
			target_factory,
			target_specs
		),
	]

	var registry_result := _compile_registry(
		descriptors
	)

	var registry := registry_result.get_registry()

	_expect(
		registry_result.is_success()
		and registry != null,
		"SCCI-I01: RuntimeFactoryRegistry compiles"
	)

	if registry == null:
		return

	var policy := DeviceBusDispatchPolicy.new(
		64,
		256,
		32,
		10000
	)

	var composition_result := CompositionCompiler.new().compile(
		snapshot,
		registry,
		DeviceConfiguration.ActivationContext.SIMULATION,
		policy
	)

	var plan := composition_result.get_plan()

	_expect(
		composition_result.is_success()
		and plan != null,
		"SCCI-I01: CompositionCompiler creates Plan"
	)

	if plan == null:
		return

	_expect(
		catalog_result.get_report().get_issues().is_empty()
		and system_result.get_report().get_issues().is_empty()
		and assembly_result.get_report().get_issues().is_empty()
		and registry_result.get_report().get_issues().is_empty()
		and composition_result.get_report().get_issues().is_empty(),
		"SCCI-I01: valid full pipeline has no Issues"
	)

	_expect(
		plan.is_valid(),
		"SCCI-I01: final CompositionPlan is valid"
	)

	var entries := plan.get_device_entries()

	_expect(
		entries.size() == 2
		and entries[0].get_device_id() == "full_source"
		and entries[1].get_device_id() == "full_target",
		"SCCI-I01: Device order reaches Plan"
	)

	_expect(
		entries[0].get_configuration()
		== source_configuration
		and entries[1].get_configuration()
		== target_configuration,
		"SCCI-I01: Configuration references reach Plan"
	)

	_expect(
		entries[0].get_factory_key().get_profile_id()
		== source_profile.get_profile_id()
		and entries[1].get_factory_key().get_profile_id()
		== target_profile.get_profile_id(),
		"SCCI-I01: exact Profile identities reach Factory Keys"
	)

	_expect(
		entries[0].get_dependency_spec(
			&"runtime_clock"
		) == source_spec
		and entries[1].get_dependency_spec(
			&"distance_provider"
		) == target_spec,
		"SCCI-I01: Registry Dependency Specs reach Plan"
	)

	var directives := plan.get_connection_directives()

	_expect(
		directives.size() == 1
		and directives[0].get_connection_id()
		== system_spec.get_connection_id()
		and directives[0].get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"SCCI-I01: System connection reaches Plan Directive"
	)

	_expect(
		plan.get_dispatch_policy() == policy,
		"SCCI-I01: explicit Dispatch Policy reaches Plan"
	)

	var forward_order: Array[String] = [
		"full_source",
		"full_target",
	]

	var reverse_order: Array[String] = [
		"full_target",
		"full_source",
	]

	_expect(
		plan.get_start_order() == forward_order
		and plan.get_shutdown_order() == reverse_order,
		"SCCI-I01: deterministic lifecycle orders reach Plan"
	)

	_expect(
		source_factory.get_build_count() == 0
		and source_factory.get_release_count() == 0
		and target_factory.get_build_count() == 0
		and target_factory.get_release_count() == 0,
		"SCCI-I01: full compile pipeline never executes factories"
	)

	_expect(
		not plan.has_method(
			&"execute"
		)
		and not plan.has_method(
			&"get_device_bus"
		)
		and not plan.has_method(
			&"get_runtime_handle"
		),
		"SCCI-I01: final Plan remains declarative"
	)


# =============================================================================
# EMPTY PIPELINE
# =============================================================================

func _test_empty_pipeline() -> void:

	var catalog_result := DeviceCatalogCompiler.new().compile(
		DeviceCatalogDraft.new()
	)

	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog != null,
		"SCCI-I02: empty Catalog compiles"
	)

	if catalog == null:
		return

	var system_result := SystemProfileCompiler.new().compile(
		_system_draft(
			&"test.empty_compiler_pipeline"
		),
		catalog
	)

	var system_profile := system_result.get_profile()

	_expect(
		system_result.is_success()
		and system_profile != null,
		"SCCI-I02: empty SystemProfile compiles"
	)

	if system_profile == null:
		return

	var assembly_result := DeviceGraphAssembler.new().assemble(
		system_profile,
		catalog
	)

	var snapshot := assembly_result.get_snapshot()

	_expect(
		assembly_result.is_success()
		and snapshot != null,
		"SCCI-I02: empty Graph assembly succeeds"
	)

	if snapshot == null:
		return

	var registry_result := RuntimeFactoryRegistryCompiler.new().compile(
		RuntimeFactoryRegistryDraft.new()
	)

	var registry := registry_result.get_registry()

	_expect(
		registry_result.is_success()
		and registry != null,
		"SCCI-I02: empty Registry compiles"
	)

	if registry == null:
		return

	var composition_result := CompositionCompiler.new().compile(
		snapshot,
		registry,
		DeviceConfiguration.ActivationContext.SIMULATION,
		DeviceBusDispatchPolicy.new()
	)

	var plan := composition_result.get_plan()

	_expect(
		composition_result.is_success()
		and plan != null,
		"SCCI-I02: empty Composition compiles"
	)

	_expect(
		plan != null
		and plan.get_device_entries().is_empty()
		and plan.get_connection_directives().is_empty()
		and plan.get_start_order().is_empty(),
		"SCCI-I02: empty pipeline produces no-op Plan"
	)


# =============================================================================
# CYCLE PIPELINE
# =============================================================================

func _test_cycle_pipeline() -> void:

	var distance_topics: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var health_topics: Array[StringName] = [
		BusTopics.HEALTH_REPORT,
	]

	var profile_a := _profile(
		&"test.full_cycle.a",
		distance_topics,
		health_topics
	)

	var profile_b := _profile(
		&"test.full_cycle.b",
		health_topics,
		distance_topics
	)

	var catalog_draft := DeviceCatalogDraft.new()

	catalog_draft.profiles.append(
		profile_a
	)

	catalog_draft.profiles.append(
		profile_b
	)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)

	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog != null,
		"SCCI-I03: cycle Catalog compiles"
	)

	if catalog == null:
		return

	var configuration_a := _configuration(
		"full_cycle_a",
		profile_a,
		distance_topics,
		health_topics,
		"full_cycle_a"
	)

	var configuration_b := _configuration(
		"full_cycle_b",
		profile_b,
		health_topics,
		distance_topics,
		"full_cycle_b"
	)

	var system_draft := _system_draft(
		&"test.full_cycle.system"
	)

	system_draft.device_configurations.append(
		configuration_a
	)

	system_draft.device_configurations.append(
		configuration_b
	)

	system_draft.connection_specs.append(
		SystemConnectionSpec.new(
			"full_cycle_a",
			_output_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			),
			"full_cycle_b",
			_input_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			)
		)
	)

	system_draft.connection_specs.append(
		SystemConnectionSpec.new(
			"full_cycle_b",
			_output_port_id(
				BusTopics.HEALTH_REPORT
			),
			"full_cycle_a",
			_input_port_id(
				BusTopics.HEALTH_REPORT
			)
		)
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	var system_profile := system_result.get_profile()

	_expect(
		system_result.is_success()
		and system_profile != null,
		"SCCI-I03: cycle SystemProfile compiles"
	)

	if system_profile == null:
		return

	var assembly_result := DeviceGraphAssembler.new().assemble(
		system_profile,
		catalog
	)

	var snapshot := assembly_result.get_snapshot()

	_expect(
		assembly_result.is_success()
		and snapshot != null,
		"SCCI-I03: cycle Graph assembles for Simulation"
	)

	if snapshot == null:
		return

	_expect(
		_report_has_severity(
			assembly_result.get_report(),
			&"graph_cycle_requires_temporal_analysis",
			ValidationIssue.Severity.SIMULATION_HAZARD
		)
		and not assembly_result.get_report().is_valid_for_hardware(),
		"SCCI-I03: upstream cycle Hazard is retained"
	)

	var factory := RuntimeTestFactoryScript.new()
	var descriptors: Array[RuntimeFactoryDescriptor] = []

	for node: DeviceGraphNode in snapshot.get_devices():

		var specs: Array[RuntimeDependencySpec] = []

		descriptors.append(
			_descriptor_for_node(
				node,
				factory,
				specs
			)
		)

	var registry_result := _compile_registry(
		descriptors
	)

	var registry := registry_result.get_registry()

	_expect(
		registry_result.is_success()
		and registry != null,
		"SCCI-I03: cycle Registry compiles"
	)

	if registry == null:
		return

	var composition_result := CompositionCompiler.new().compile(
		snapshot,
		registry,
		DeviceConfiguration.ActivationContext.SIMULATION,
		DeviceBusDispatchPolicy.new()
	)

	var plan := composition_result.get_plan()

	_expect(
		composition_result.is_success()
		and plan != null,
		"SCCI-I03: cycle Composition compiles for Simulation"
	)

	_expect(
		composition_result.get_report().get_issues().is_empty(),
		"SCCI-I03: Compiler Report scope does not duplicate upstream Hazard"
	)

	_expect(
		plan != null
		and plan.get_connection_directives().size() == 2,
		"SCCI-I03: cycle Plan preserves both Directives"
	)

	var forward_order: Array[String] = [
		"full_cycle_a",
		"full_cycle_b",
	]

	_expect(
		plan != null
		and plan.get_start_order() == forward_order,
		"SCCI-I03: cycle Plan preserves insertion order"
	)

	_expect(
		factory.get_build_count() == 0
		and factory.get_release_count() == 0,
		"SCCI-I03: cycle compile never executes factory"
	)


# =============================================================================
# MISSING FACTORY
# =============================================================================

func _test_missing_factory_pipeline() -> void:

	var snapshot := _build_connected_snapshot()

	_expect(
		snapshot != null
		and snapshot.is_valid(),
		"SCCI-I04: missing-factory Snapshot fixture is valid"
	)

	if snapshot == null:
		return

	var nodes := snapshot.get_devices()
	var source_factory := RuntimeTestFactoryScript.new()
	var empty_specs: Array[RuntimeDependencySpec] = []

	var source_descriptor := _descriptor_for_node(
		nodes[0],
		source_factory,
		empty_specs
	)

	var descriptors: Array[RuntimeFactoryDescriptor] = [
		source_descriptor,
	]

	var registry_result := _compile_registry(
		descriptors
	)

	var registry := registry_result.get_registry()

	_expect(
		registry_result.is_success()
		and registry != null,
		"SCCI-I04: partial Registry fixture is valid"
	)

	if registry == null:
		return

	var result := CompositionCompiler.new().compile(
		snapshot,
		registry,
		DeviceConfiguration.ActivationContext.SIMULATION,
		DeviceBusDispatchPolicy.new()
	)

	_expect(
		not result.is_success()
		and result.get_plan() == null,
		"SCCI-I04: missing exact factory blocks Plan"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"composition_compile_factory_missing"
		),
		"SCCI-I04: missing factory code reaches final Result"
	)

	_expect(
		_report_code_count(
			result.get_report(),
			&"composition_compile_factory_missing"
		) == 1,
		"SCCI-I04: only missing target factory is reported"
	)

	_expect(
		source_factory.get_build_count() == 0
		and source_factory.get_release_count() == 0,
		"SCCI-I04: available factory is not executed on failure"
	)


# =============================================================================
# PIPELINE CONTRACT
# =============================================================================

func _test_pipeline_contract() -> void:

	var compiler := CompositionCompiler.new()

	_expect(
		not compiler.has_method(
			&"execute"
		)
		and not compiler.has_method(
			&"activate"
		)
		and not compiler.has_method(
			&"create_device"
		),
		"SCCI-I05: Compiler exposes no runtime API"
	)

	var empty_entries: Array[CompositionDeviceEntry] = []
	var empty_directives: Array[CompositionConnectionDirective] = []

	var empty_plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		empty_entries,
		empty_directives,
		DeviceBusDispatchPolicy.new()
	)

	_expect(
		not empty_plan.has_method(
			&"get_factory_registry"
		)
		and not empty_plan.has_method(
			&"get_runtime_handle"
		)
		and not empty_plan.has_method(
			&"get_device_bus"
		),
		"SCCI-I05: Plan remains separate from active runtime"
	)


# =============================================================================
# CONNECTED SNAPSHOT FIXTURE
# =============================================================================

func _build_connected_snapshot() -> DeviceGraphSnapshot:

	var distance_topics: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var source_profile := _profile(
		&"test.missing_factory.source",
		distance_topics,
		_empty_topics()
	)

	var target_profile := _profile(
		&"test.missing_factory.target",
		_empty_topics(),
		distance_topics
	)

	var catalog_draft := DeviceCatalogDraft.new()

	catalog_draft.profiles.append(
		source_profile
	)

	catalog_draft.profiles.append(
		target_profile
	)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)

	var catalog := catalog_result.get_catalog()

	if catalog == null:
		return null

	var source_configuration := _configuration(
		"missing_factory_source",
		source_profile,
		distance_topics,
		_empty_topics(),
		"missing_factory_source"
	)

	var target_configuration := _configuration(
		"missing_factory_target",
		target_profile,
		_empty_topics(),
		distance_topics,
		"missing_factory_target"
	)

	var system_draft := _system_draft(
		&"test.missing_factory.system"
	)

	system_draft.device_configurations.append(
		source_configuration
	)

	system_draft.device_configurations.append(
		target_configuration
	)

	system_draft.connection_specs.append(
		SystemConnectionSpec.new(
			"missing_factory_source",
			_output_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			),
			"missing_factory_target",
			_input_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			)
		)
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	var system_profile := system_result.get_profile()

	if system_profile == null:
		return null

	var assembly_result := DeviceGraphAssembler.new().assemble(
		system_profile,
		catalog
	)

	return assembly_result.get_snapshot()


# =============================================================================
# FIXTURES
# =============================================================================

func _system_draft(
	system_profile_id: StringName
) -> SystemProfileDraft:

	var draft := SystemProfileDraft.new()

	draft.system_profile_id = system_profile_id
	draft.system_profile_version = 1
	draft.display_name = "System Composition Compiler"
	draft.description = "CompositionCompiler integration fixture."
	draft.activation_context = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	return draft


func _profile(
	profile_id: StringName,
	publishes: Array[StringName],
	subscribes: Array[StringName]
) -> DeviceProfile:

	var capabilities: Array[String] = [
		"composition_compiler_integration",
	]

	var requirements: Array[String] = []

	return DeviceProfile.new(
		profile_id,
		1,
		"Composition Compiler Integration Profile",
		"End-to-end CompositionCompiler fixture.",
		DeviceRoles.LOCAL_CONTROLLER,
		capabilities,
		publishes,
		subscribes,
		requirements,
		false,
		&"",
		0
	)


func _configuration(
	device_id: String,
	profile: DeviceProfile,
	publishes: Array[StringName],
	subscribes: Array[StringName],
	suffix: String
) -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"composition_compiler_integration",
	]

	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName(
			"test." + suffix + ".configuration"
		),
		1,
		device_id,
		profile.get_profile_id(),
		profile.get_profile_version(),
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _descriptor_for_node(
	node: DeviceGraphNode,
	factory: Object,
	dependency_specs: Array[RuntimeDependencySpec]
) -> RuntimeFactoryDescriptor:

	var configuration := node.get_configuration()

	return RuntimeFactoryDescriptor.new(
		RuntimeFactoryKey.new(
			configuration.get_profile_id(),
			configuration.get_profile_version(),
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		factory,
		dependency_specs
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


func _output_port_id(
	topic: StringName
) -> StringName:

	return StringName(
		"out." + String(topic)
	)


func _input_port_id(
	topic: StringName
) -> StringName:

	return StringName(
		"in." + String(topic)
	)


func _empty_topics(
) -> Array[StringName]:

	var topics: Array[StringName] = []

	return topics


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


func _report_code_count(
	report: ValidationReport,
	code: StringName
) -> int:

	var count: int = 0

	if report == null:
		return count

	for issue: ValidationIssue in report.get_issues():

		if issue.get_code() == code:
			count += 1

	return count


func _report_has_severity(
	report: ValidationReport,
	code: StringName,
	severity: int
) -> bool:

	if report == null:
		return false

	for issue: ValidationIssue in report.get_issues():

		if (
			issue.get_code() == code
			and issue.get_severity() == severity
		):

			return true

	return false


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
