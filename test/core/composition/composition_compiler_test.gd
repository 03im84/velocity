extends Node


##
## CompositionCompilerTest
##
## Verifica inputs, Hardware gate,
## compilación por stages, orden,
## transaccionalidad y no ejecución.
##


const RuntimeTestFactoryScript = preload(
	"res://test/core/runtime/runtime_test_factory.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("CompositionCompilerTest")
	print("========================================")

	_test_required_inputs()
	_test_hardware_gate()
	_test_invalid_inputs()
	_test_empty_compilation()
	_test_context_mismatch()
	_test_missing_factories_aggregate_and_gate()
	_test_valid_compilation()
	_test_cycle_compilation()
	_test_input_non_mutation()
	_test_compiler_contract()

	_finish_test()


# =============================================================================
# REQUIRED INPUTS
# =============================================================================

func _test_required_inputs() -> void:

	var compiler := CompositionCompiler.new()
	var snapshot := DeviceGraphSnapshot.new()
	var registry := RuntimeFactoryRegistry.new()
	var policy := DeviceBusDispatchPolicy.new()

	_expect_compile_failure(
		compiler.compile(
			snapshot,
			registry,
			-1,
			policy
		),
		&"composition_compile_activation_context_invalid",
		"CC-U01: invalid Activation Context"
	)

	_expect_compile_failure(
		compiler.compile(
			null,
			registry,
			DeviceConfiguration.ActivationContext.SIMULATION,
			policy
		),
		&"composition_compile_snapshot_missing",
		"CC-U01: null Snapshot"
	)

	_expect_compile_failure(
		compiler.compile(
			snapshot,
			null,
			DeviceConfiguration.ActivationContext.SIMULATION,
			policy
		),
		&"composition_compile_registry_missing",
		"CC-U01: null Registry"
	)

	_expect_compile_failure(
		compiler.compile(
			snapshot,
			registry,
			DeviceConfiguration.ActivationContext.SIMULATION,
			null
		),
		&"composition_compile_dispatch_policy_missing",
		"CC-U01: null Dispatch Policy"
	)


# =============================================================================
# HARDWARE GATE
# =============================================================================

func _test_hardware_gate() -> void:

	var result := CompositionCompiler.new().compile(
		DeviceGraphSnapshot.new(),
		RuntimeFactoryRegistry.new(),
		DeviceConfiguration.ActivationContext.HARDWARE,
		DeviceBusDispatchPolicy.new()
	)

	_expect(
		not result.is_success()
		and result.get_plan() == null,
		"CC-U02: Hardware compilation produces no Plan"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"composition_compile_hardware_not_supported"
		),
		"CC-U02: Hardware gate reports canonical code"
	)

	_expect(
		_report_has_severity(
			result.get_report(),
			&"composition_compile_hardware_not_supported",
			ValidationIssue.Severity.HARDWARE_SAFETY_ERROR
		),
		"CC-U02: Hardware gate uses Hardware Safety Error"
	)

	_expect(
		result.get_report().is_valid_for_simulation()
		and not result.get_report().is_valid_for_hardware(),
		"CC-U02: Hardware rejection remains modelable in Simulation"
	)


# =============================================================================
# INVALID INPUTS
# =============================================================================

func _test_invalid_inputs() -> void:

	var null_nodes: Array[DeviceGraphNode] = [
		null,
	]

	var invalid_snapshot := DeviceGraphSnapshot.new(
		null_nodes,
		_empty_connections(),
		_empty_channels()
	)

	_expect_compile_failure(
		CompositionCompiler.new().compile(
			invalid_snapshot,
			RuntimeFactoryRegistry.new(),
			DeviceConfiguration.ActivationContext.SIMULATION,
			DeviceBusDispatchPolicy.new()
		),
		&"composition_compile_snapshot_invalid",
		"CC-U03: invalid Snapshot"
	)

	var factory := RuntimeTestFactoryScript.new()
	var empty_specs: Array[RuntimeDependencySpec] = []

	var descriptor := RuntimeFactoryDescriptor.new(
		RuntimeFactoryKey.new(
			&"test.compiler.duplicate",
			1,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		factory,
		empty_specs
	)

	var duplicate_descriptors: Array[RuntimeFactoryDescriptor] = [
		descriptor,
		descriptor,
	]

	var invalid_registry := RuntimeFactoryRegistry.new(
		duplicate_descriptors
	)

	_expect_compile_failure(
		CompositionCompiler.new().compile(
			DeviceGraphSnapshot.new(),
			invalid_registry,
			DeviceConfiguration.ActivationContext.SIMULATION,
			DeviceBusDispatchPolicy.new()
		),
		&"composition_compile_registry_invalid",
		"CC-U03: invalid Registry"
	)

	var invalid_policy := DeviceBusDispatchPolicy.new(
		0,
		1,
		1,
		1
	)

	_expect_compile_failure(
		CompositionCompiler.new().compile(
			DeviceGraphSnapshot.new(),
			RuntimeFactoryRegistry.new(),
			DeviceConfiguration.ActivationContext.SIMULATION,
			invalid_policy
		),
		&"composition_compile_dispatch_policy_invalid",
		"CC-U03: invalid Dispatch Policy"
	)


# =============================================================================
# EMPTY COMPILATION
# =============================================================================

func _test_empty_compilation() -> void:

	var policy := DeviceBusDispatchPolicy.new()

	var result := CompositionCompiler.new().compile(
		DeviceGraphSnapshot.new(),
		RuntimeFactoryRegistry.new(),
		DeviceConfiguration.ActivationContext.SIMULATION,
		policy
	)

	var plan := result.get_plan()

	_expect(
		result.is_success(),
		"CC-U04: empty Compilation succeeds"
	)

	_expect(
		plan != null,
		"CC-U04: empty Compilation produces Plan"
	)

	if plan == null:
		return

	_expect(
		result.get_report().get_issues().is_empty(),
		"CC-U04: empty Compilation has no Issues"
	)

	_expect(
		plan.is_valid()
		and plan.get_device_entries().is_empty()
		and plan.get_connection_directives().is_empty(),
		"CC-U04: empty Plan is valid and contains no instructions"
	)

	_expect(
		plan.get_construction_order().is_empty()
		and plan.get_shutdown_order().is_empty(),
		"CC-U04: empty Plan orders are empty"
	)

	_expect(
		plan.get_dispatch_policy() == policy
		and plan.get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION,
		"CC-U04: explicit Context and Policy are preserved"
	)


# =============================================================================
# CONTEXT MISMATCH
# =============================================================================

func _test_context_mismatch() -> void:

	var hardware_node := _node(
		"hardware_node",
		_profile(
			&"test.compiler.hardware_node",
			1,
			_empty_topics(),
			_empty_topics()
		),
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	var nodes: Array[DeviceGraphNode] = [
		hardware_node,
	]

	var snapshot := DeviceGraphSnapshot.new(
		nodes,
		_empty_connections(),
		_empty_channels()
	)

	_expect(
		snapshot.is_valid(),
		"CC-U05: Context mismatch fixture is valid Graph topology"
	)

	var result := CompositionCompiler.new().compile(
		snapshot,
		RuntimeFactoryRegistry.new(),
		DeviceConfiguration.ActivationContext.SIMULATION,
		DeviceBusDispatchPolicy.new()
	)

	_expect_compile_failure(
		result,
		&"composition_compile_configuration_context_mismatch",
		"CC-U05: Configuration Context mismatch"
	)

	_expect(
		not _report_has_code(
			result.get_report(),
			&"composition_compile_factory_missing"
		),
		"CC-U05: mismatch does not fabricate factory error"
	)


# =============================================================================
# DEVICE STAGE GATE
# =============================================================================

func _test_missing_factories_aggregate_and_gate() -> void:

	var snapshot := _connected_snapshot()

	var result := CompositionCompiler.new().compile(
		snapshot,
		RuntimeFactoryRegistry.new(),
		DeviceConfiguration.ActivationContext.SIMULATION,
		DeviceBusDispatchPolicy.new()
	)

	_expect(
		not result.is_success()
		and result.get_plan() == null,
		"CC-U06: missing factories block Plan"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"composition_compile_factory_missing"
		),
		"CC-U06: missing factory code is reported"
	)

	_expect(
		_report_code_count(
			result.get_report(),
			&"composition_compile_factory_missing"
		) == 2,
		"CC-U06: Device stage aggregates both missing factories"
	)

	_expect(
		not _report_has_code(
			result.get_report(),
			&"composition_compile_directive_invalid"
		)
		and not _report_has_code(
			result.get_report(),
			&"composition_compile_connection_invalid"
		),
		"CC-U06: Connection stage is gated after Device errors"
	)


# =============================================================================
# VALID COMPILATION
# =============================================================================

func _test_valid_compilation() -> void:

	var snapshot := _connected_snapshot()
	var nodes := snapshot.get_devices()
	var connections := snapshot.get_connections()

	var shared_factory := RuntimeTestFactoryScript.new()

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

	var source_descriptor := _descriptor_for_node(
		nodes[0],
		shared_factory,
		source_specs
	)

	var target_descriptor := _descriptor_for_node(
		nodes[1],
		shared_factory,
		target_specs
	)

	var descriptors: Array[RuntimeFactoryDescriptor] = [
		source_descriptor,
		target_descriptor,
	]

	var registry := _registry(
		descriptors
	)

	var policy := DeviceBusDispatchPolicy.new(
		64,
		256,
		32,
		10000
	)

	var result := CompositionCompiler.new().compile(
		snapshot,
		registry,
		DeviceConfiguration.ActivationContext.SIMULATION,
		policy
	)

	var plan := result.get_plan()

	_expect(
		result.is_success()
		and plan != null,
		"CC-U07: valid inputs compile successfully"
	)

	if plan == null:
		return

	_expect(
		result.get_report().get_issues().is_empty(),
		"CC-U07: valid Compilation has no Issues"
	)

	var entries := plan.get_device_entries()

	_expect(
		entries.size() == 2
		and entries[0].get_device_id()
		== nodes[0].get_device_id()
		and entries[1].get_device_id()
		== nodes[1].get_device_id(),
		"CC-U07: Device order is preserved"
	)

	_expect(
		entries[0].get_factory_key().get_profile_version()
		== nodes[0].get_configuration().get_profile_version()
		and entries[1].get_factory_key().get_profile_version()
		== nodes[1].get_configuration().get_profile_version(),
		"CC-U07: exact Factory Keys are derived"
	)

	_expect(
		entries[0].get_dependency_spec(
			&"runtime_clock"
		) == source_spec
		and entries[1].get_dependency_spec(
			&"distance_provider"
		) == target_spec,
		"CC-U07: Descriptor Specs are transferred to Entries"
	)

	var directives := plan.get_connection_directives()

	_expect(
		directives.size() == 1
		and directives[0].get_source_device_id()
		== connections[0].get_source_device_id()
		and directives[0].get_target_device_id()
		== connections[0].get_target_device_id()
		and directives[0].get_topic()
		== connections[0].get_topic(),
		"CC-U07: Connection fields compile in order"
	)

	_expect(
		directives[0].get_connection_id()
		== connections[0].get_connection_id(),
		"CC-U07: Connection ID is preserved"
	)

	_expect(
		plan.get_dispatch_policy() == policy
		and plan.is_valid(),
		"CC-U07: Policy reference and final Plan are valid"
	)

	_expect(
		shared_factory.get_build_count() == 0
		and shared_factory.get_release_count() == 0,
		"CC-U07: Compilation never executes shared factory"
	)

	_expect(
		plan.get_construction_order().size() == 2
		and plan.get_shutdown_order()[0]
		== nodes[1].get_device_id(),
		"CC-U07: Plan lifecycle orders derive from Node order"
	)


# =============================================================================
# CYCLE COMPILATION
# =============================================================================

func _test_cycle_compilation() -> void:

	var snapshot := _cycle_snapshot()
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

	var result := CompositionCompiler.new().compile(
		snapshot,
		_registry(
			descriptors
		),
		DeviceConfiguration.ActivationContext.SIMULATION,
		DeviceBusDispatchPolicy.new()
	)

	var plan := result.get_plan()

	_expect(
		result.is_success()
		and plan != null,
		"CC-U08: cycle compiles for Simulation"
	)

	if plan == null:
		return

	var compiled_directives := plan.get_connection_directives()

	_expect(
		compiled_directives.size() == 2
		and compiled_directives[0].get_source_device_id()
		== "cycle_a"
		and compiled_directives[1].get_source_device_id()
		== "cycle_b",
		"CC-U08: cycle Directive order is preserved"
	)

	var forward_order: Array[String] = [
		"cycle_a",
		"cycle_b",
	]

	var reverse_order: Array[String] = [
		"cycle_b",
		"cycle_a",
	]

	_expect(
		plan.get_construction_order() == forward_order
		and plan.get_shutdown_order() == reverse_order,
		"CC-U08: cycle does not require topological sort"
	)


# =============================================================================
# INPUT NON-MUTATION
# =============================================================================

func _test_input_non_mutation() -> void:

	var snapshot := _connected_snapshot()
	var nodes_before := snapshot.get_devices()
	var connections_before := snapshot.get_connections()
	var factory := RuntimeTestFactoryScript.new()
	var descriptors: Array[RuntimeFactoryDescriptor] = []

	for node: DeviceGraphNode in nodes_before:

		var specs: Array[RuntimeDependencySpec] = []

		descriptors.append(
			_descriptor_for_node(
				node,
				factory,
				specs
			)
		)

	var registry := _registry(
		descriptors
	)

	var policy := DeviceBusDispatchPolicy.new()

	var result := CompositionCompiler.new().compile(
		snapshot,
		registry,
		DeviceConfiguration.ActivationContext.SIMULATION,
		policy
	)

	var plan := result.get_plan()

	_expect(
		result.is_success()
		and plan != null,
		"CC-U09: non-mutation fixture compiles"
	)

	if plan == null:
		return

	nodes_before.clear()
	connections_before.clear()
	descriptors.clear()

	var registry_copy := registry.get_descriptors()

	registry_copy.clear()

	_expect(
		snapshot.get_devices().size() == 2
		and snapshot.get_connections().size() == 1,
		"CC-U09: Snapshot collections remain unchanged"
	)

	_expect(
		registry.get_descriptors().size() == 2,
		"CC-U09: Registry collection remains unchanged"
	)

	_expect(
		plan.get_device_entries().size() == 2
		and plan.get_connection_directives().size() == 1
		and plan.get_dispatch_policy() == policy,
		"CC-U09: Plan remains stable after source copy mutation"
	)


# =============================================================================
# COMPILER CONTRACT
# =============================================================================

func _test_compiler_contract() -> void:

	var compiler := CompositionCompiler.new()
	var compiler_value: Variant = compiler

	_expect(
		compiler_value is RefCounted
		and not (compiler_value is Node),
		"CC-U10: Compiler is RefCounted and not Node"
	)

	_expect(
		not compiler.has_method(
			&"set_snapshot"
		)
		and not compiler.has_method(
			&"set_registry"
		)
		and not compiler.has_method(
			&"set_dispatch_policy"
		),
		"CC-U10: Compiler stores no mutable inputs"
	)

	_expect(
		not compiler.has_method(
			&"execute"
		)
		and not compiler.has_method(
			&"activate"
		)
		and not compiler.has_method(
			&"build"
		)
		and not compiler.has_method(
			&"release"
		),
		"CC-U10: Compiler exposes no runtime execution"
	)

	_expect(
		not compiler.has_method(
			&"get_service"
		)
		and not compiler.has_method(
			&"load"
		)
		and not compiler.has_method(
			&"save"
		),
		"CC-U10: Compiler has no service locator or persistence"
	)


# =============================================================================
# GRAPH FIXTURES
# =============================================================================

func _connected_snapshot() -> DeviceGraphSnapshot:

	var distance_topics: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var source_profile := _profile(
		&"test.compiler.source",
		1,
		distance_topics,
		_empty_topics()
	)

	var target_profile := _profile(
		&"test.compiler.target",
		2,
		_empty_topics(),
		distance_topics
	)

	var source_node := _node(
		"compiler_source",
		source_profile,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var target_node := _node(
		"compiler_target",
		target_profile,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var draft := DeviceGraphDraft.new()

	draft.add_device(
		source_node
	)

	draft.add_device(
		target_node
	)

	draft.connect_ports(
		"compiler_source",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"compiler_target",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	var snapshot_result := draft.create_snapshot()

	return snapshot_result.get_snapshot()


func _cycle_snapshot() -> DeviceGraphSnapshot:

	var distance_topics: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var health_topics: Array[StringName] = [
		BusTopics.HEALTH_REPORT,
	]

	var profile_a := _profile(
		&"test.compiler.cycle_a",
		1,
		distance_topics,
		health_topics
	)

	var profile_b := _profile(
		&"test.compiler.cycle_b",
		1,
		health_topics,
		distance_topics
	)

	var node_a := _node(
		"cycle_a",
		profile_a,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var node_b := _node(
		"cycle_b",
		profile_b,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var draft := DeviceGraphDraft.new()

	draft.add_device(
		node_a
	)

	draft.add_device(
		node_b
	)

	draft.connect_ports(
		"cycle_a",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"cycle_b",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	draft.connect_ports(
		"cycle_b",
		_output_port_id(
			BusTopics.HEALTH_REPORT
		),
		"cycle_a",
		_input_port_id(
			BusTopics.HEALTH_REPORT
		)
	)

	return draft.create_snapshot().get_snapshot()


func _node(
	device_id: String,
	profile: DeviceProfile,
	activation_context: int
) -> DeviceGraphNode:

	var configuration := _configuration(
		device_id,
		profile,
		activation_context
	)

	var manifest := DeviceManifest.new()

	manifest.capabilities = (
		configuration.get_enabled_capabilities()
	)

	manifest.publishes = (
		configuration.get_enabled_publishes()
	)

	manifest.subscribes = (
		configuration.get_enabled_subscribes()
	)

	manifest.requirements = (
		configuration.get_additional_requirements()
	)

	var node_result := DeviceGraphNodeBuilder.new().build(
		device_id,
		profile,
		configuration,
		manifest
	)

	return node_result.get_node()


func _profile(
	profile_id: StringName,
	profile_version: int,
	publishes: Array[StringName],
	subscribes: Array[StringName]
) -> DeviceProfile:

	var capabilities: Array[String] = [
		"composition_compiler",
	]

	var requirements: Array[String] = []

	return DeviceProfile.new(
		profile_id,
		profile_version,
		"Composition Compiler Profile",
		"CompositionCompilerTest fixture.",
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
	activation_context: int
) -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"composition_compiler",
	]

	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName(
			"test.compiler." + device_id
		),
		1,
		device_id,
		profile.get_profile_id(),
		profile.get_profile_version(),
		activation_context,
		&"",
		0,
		capabilities,
		profile.get_supported_publishes(),
		profile.get_supported_subscribes(),
		requirements
	)


# =============================================================================
# REGISTRY FIXTURES
# =============================================================================

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


func _registry(
	descriptors: Array[RuntimeFactoryDescriptor]
) -> RuntimeFactoryRegistry:

	var draft := RuntimeFactoryRegistryDraft.new()

	for descriptor: RuntimeFactoryDescriptor in descriptors:

		draft.descriptors.append(
			descriptor
		)

	return RuntimeFactoryRegistryCompiler.new().compile(
		draft
	).get_registry()


# =============================================================================
# ID HELPERS
# =============================================================================

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


func _empty_connections(
) -> Array[DeviceGraphConnection]:

	var connections: Array[DeviceGraphConnection] = []

	return connections


func _empty_channels(
) -> Array[DeviceGraphTopicChannel]:

	var channels: Array[DeviceGraphTopicChannel] = []

	return channels


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


func _expect_compile_failure(
	result: CompositionCompileResult,
	code: StringName,
	description: String
) -> void:

	_expect(
		not result.is_success(),
		description + " is rejected"
	)

	_expect(
		result.get_plan() == null,
		description + " produces null Plan"
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
