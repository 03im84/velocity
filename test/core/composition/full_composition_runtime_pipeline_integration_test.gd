extends Node


##
## FullCompositionRuntimePipelineIntegrationTest
##
## Verifies the complete logical-to-runtime path:
## DeviceProfiles -> DeviceCatalog -> SystemProfile
## -> DeviceGraphSnapshot -> CompositionPlan
## -> CompositionRuntime -> ACTIVE -> SHUTDOWN.
##


const RuntimeIntegrationTraceScript = preload(
	"res://test/core/composition/runtime_integration_test_trace.gd"
)

const RuntimeIntegrationFactoryScript = preload(
	"res://test/core/composition/runtime_integration_test_factory.gd"
)

const RuntimeIntegrationHostScript = preload(
	"res://test/core/composition/runtime_integration_test_host.gd"
)

const RuntimeIntegrationLifecycleScript = preload(
	"res://test/core/composition/runtime_integration_test_lifecycle_adapter.gd"
)

const RuntimeIntegrationBinderScript = preload(
	"res://test/core/composition/runtime_integration_test_communication_binder.gd"
)

const RuntimeDependencyResolverScript = preload(
	"res://test/core/composition/runtime_test_dependency_value_resolver.gd"
)

const RuntimeTestObjectScript = preload(
	"res://test/core/runtime/runtime_test_object.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("FullCompositionRuntimePipelineIntegrationTest")
	print("========================================")

	_test_full_pipeline_activation_and_shutdown()

	_finish_test()


# =============================================================================
# FULL PIPELINE
# =============================================================================

func _test_full_pipeline_activation_and_shutdown() -> void:

	var distance_topics: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var empty_topics: Array[StringName] = []

	var source_profile := _profile(
		&"test.full_runtime_pipeline.source",
		DeviceRoles.SENSOR,
		distance_topics,
		empty_topics
	)

	var target_profile := _profile(
		&"test.full_runtime_pipeline.target",
		DeviceRoles.LOCAL_CONTROLLER,
		empty_topics,
		distance_topics
	)

	_expect(
		source_profile.is_valid(),
		"FCRP-I01: source DeviceProfile is valid"
	)

	_expect(
		target_profile.is_valid(),
		"FCRP-I01: target DeviceProfile is valid"
	)

	var catalog_draft := DeviceCatalogDraft.new()

	catalog_draft.profiles.append(source_profile)
	catalog_draft.profiles.append(target_profile)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)

	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog != null
		and catalog.is_valid(),
		"FCRP-I01: DeviceCatalog compiles as a valid Snapshot"
	)

	_expect(
		catalog_result.get_report().is_empty(),
		"FCRP-I01: DeviceCatalog stage reports no Issue"
	)

	if catalog == null:
		return

	_expect(
		catalog.get_profile(
			source_profile.get_profile_id(),
			source_profile.get_profile_version()
		) == source_profile
		and catalog.get_profile(
			target_profile.get_profile_id(),
			target_profile.get_profile_version()
		) == target_profile,
		"FCRP-I01: DeviceCatalog preserves exact Profile identities"
	)

	var source_configuration := _configuration(
		"pipeline_source",
		source_profile,
		distance_topics,
		empty_topics
	)

	var target_configuration := _configuration(
		"pipeline_target",
		target_profile,
		empty_topics,
		distance_topics
	)

	_expect(
		source_configuration.is_valid(),
		"FCRP-I01: source DeviceConfiguration is valid"
	)

	_expect(
		target_configuration.is_valid(),
		"FCRP-I01: target DeviceConfiguration is valid"
	)

	var connection_spec := SystemConnectionSpec.new(
		"pipeline_source",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"pipeline_target",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	var system_draft := _system_draft()

	system_draft.device_configurations.append(
		source_configuration
	)

	system_draft.device_configurations.append(
		target_configuration
	)

	system_draft.connection_specs.append(
		connection_spec
	)

	_expect(
		connection_spec.is_valid_identity(),
		"FCRP-I01: System Connection identity is valid"
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	var system_profile := system_result.get_profile()

	_expect(
		system_result.is_success()
		and system_profile != null
		and system_profile.is_valid_identity(),
		"FCRP-I01: SystemProfile compiles as a valid Snapshot"
	)

	_expect(
		system_result.get_report().is_empty(),
		"FCRP-I01: SystemProfile stage reports no Issue"
	)

	if system_profile == null:
		return

	var system_configurations := (
		system_profile.get_device_configurations()
	)

	_expect(
		system_configurations.size() == 2
		and system_configurations[0]
		== source_configuration
		and system_configurations[1]
		== target_configuration,
		"FCRP-I01: SystemProfile preserves deterministic Configuration order"
	)

	var system_connections := (
		system_profile.get_connection_specs()
	)

	_expect(
		system_connections.size() == 1
		and system_connections[0] == connection_spec,
		"FCRP-I01: SystemProfile preserves the Connection Spec"
	)

	var assembly_result := DeviceGraphAssembler.new().assemble(
		system_profile,
		catalog
	)

	var snapshot := assembly_result.get_snapshot()

	_expect(
		assembly_result.is_success()
		and snapshot != null
		and snapshot.is_valid(),
		"FCRP-I01: DeviceGraphAssembler creates a valid Snapshot"
	)

	_expect(
		assembly_result.get_report().is_empty(),
		"FCRP-I01: DeviceGraph assembly reports no Issue"
	)

	if snapshot == null:
		return

	var nodes := snapshot.get_devices()
	var graph_connections := snapshot.get_connections()

	_expect(
		nodes.size() == 2
		and graph_connections.size() == 1,
		"FCRP-I01: Graph contains two Devices and one Connection"
	)

	_expect(
		nodes[0].get_device_id() == "pipeline_source"
		and nodes[0].get_profile() == source_profile
		and nodes[0].get_configuration()
		== source_configuration
		and nodes[1].get_device_id()
		== "pipeline_target"
		and nodes[1].get_profile() == target_profile
		and nodes[1].get_configuration()
		== target_configuration,
		"FCRP-I01: Profile and Configuration references reach Graph Nodes"
	)

	var graph_connection := graph_connections[0]

	_expect(
		graph_connection.get_connection_id()
		== connection_spec.get_connection_id()
		and graph_connection.get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"FCRP-I01: Graph resolves Connection Topic without changing identity"
	)

	var trace := RuntimeIntegrationTraceScript.new()
	var source_factory := RuntimeIntegrationFactoryScript.new(
		trace
	)
	var target_factory := RuntimeIntegrationFactoryScript.new(
		trace
	)

	var source_dependency_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var target_dependency_spec := RuntimeDependencySpec.new(
		&"distance_provider",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var source_dependency_specs: Array[RuntimeDependencySpec] = [
		source_dependency_spec,
	]

	var target_dependency_specs: Array[RuntimeDependencySpec] = [
		target_dependency_spec,
	]

	var source_descriptor := _descriptor_for_node(
		nodes[0],
		source_factory,
		source_dependency_specs
	)

	var target_descriptor := _descriptor_for_node(
		nodes[1],
		target_factory,
		target_dependency_specs
	)

	var registry_draft := RuntimeFactoryRegistryDraft.new()

	registry_draft.descriptors.append(
		source_descriptor
	)

	registry_draft.descriptors.append(
		target_descriptor
	)

	var registry_result := RuntimeFactoryRegistryCompiler.new().compile(
		registry_draft
	)

	var registry := registry_result.get_registry()

	_expect(
		registry_result.is_success()
		and registry != null
		and registry.is_valid(),
		"FCRP-I01: RuntimeFactoryRegistry compiles exactly"
	)

	_expect(
		registry_result.get_report().is_empty(),
		"FCRP-I01: Registry stage reports no Issue"
	)

	if registry == null:
		return

	_expect(
		registry.get_descriptor(
			source_descriptor.get_factory_key()
		) == source_descriptor
		and registry.get_descriptor(
			target_descriptor.get_factory_key()
		) == target_descriptor,
		"FCRP-I01: Registry preserves both exact Factory bindings"
	)

	_expect(
		source_factory.get_build_count() == 0
		and target_factory.get_build_count() == 0,
		"FCRP-I01: Registry compilation does not execute factories"
	)

	var dispatch_policy := DeviceBusDispatchPolicy.new(
		64,
		256,
		32,
		10000
	)

	var composition_result := CompositionCompiler.new().compile(
		snapshot,
		registry,
		DeviceConfiguration.ActivationContext.SIMULATION,
		dispatch_policy
	)

	var plan := composition_result.get_plan()

	_expect(
		composition_result.is_success()
		and plan != null
		and plan.is_valid(),
		"FCRP-I01: CompositionCompiler creates a valid Plan"
	)

	_expect(
		composition_result.get_report().is_empty(),
		"FCRP-I01: CompositionCompiler stage reports no Issue"
	)

	if plan == null:
		return

	_expect(
		catalog_result.get_report().is_empty()
		and system_result.get_report().is_empty()
		and assembly_result.get_report().is_empty()
		and registry_result.get_report().is_empty()
		and composition_result.get_report().is_empty(),
		"FCRP-I01: complete declarative pipeline is clean"
	)

	var entries := plan.get_device_entries()
	var directives := plan.get_connection_directives()

	_expect(
		entries.size() == 2
		and entries[0].get_device_id()
		== "pipeline_source"
		and entries[1].get_device_id()
		== "pipeline_target",
		"FCRP-I01: deterministic Device order reaches CompositionPlan"
	)

	_expect(
		entries[0].get_configuration()
		== source_configuration
		and entries[1].get_configuration()
		== target_configuration,
		"FCRP-I01: exact Configuration references reach CompositionPlan"
	)

	_expect(
		entries[0].get_factory_key().get_profile_id()
		== source_profile.get_profile_id()
		and entries[1].get_factory_key().get_profile_id()
		== target_profile.get_profile_id()
		and entries[0].get_factory_key().get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION
		and entries[1].get_factory_key().get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION,
		"FCRP-I01: exact Factory identities reach CompositionPlan"
	)

	_expect(
		entries[0].get_dependency_spec(
			&"runtime_clock"
		) == source_dependency_spec
		and entries[1].get_dependency_spec(
			&"distance_provider"
		) == target_dependency_spec,
		"FCRP-I01: declarative Dependency Specs reach CompositionPlan"
	)

	_expect(
		directives.size() == 1
		and directives[0].get_connection_id()
		== connection_spec.get_connection_id()
		and directives[0].get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"FCRP-I01: Graph Connection reaches the runtime Directive"
	)

	var expected_forward_order: Array[String] = [
		"pipeline_source",
		"pipeline_target",
	]

	var expected_reverse_order: Array[String] = [
		"pipeline_target",
		"pipeline_source",
	]

	_expect(
		plan.get_dispatch_policy() == dispatch_policy
		and plan.get_start_order()
		== expected_forward_order
		and plan.get_shutdown_order()
		== expected_reverse_order,
		"FCRP-I01: Dispatch Policy and lifecycle order reach CompositionPlan"
	)

	_expect(
		source_factory.get_build_count() == 0
		and target_factory.get_build_count() == 0
		and _trace_events(trace).is_empty(),
		"FCRP-I01: declarative pipeline acquires no runtime resource"
	)

	var dependency_resolver := RuntimeDependencyResolverScript.new()
	var runtime_clock := RuntimeTestObjectScript.new()
	var distance_provider := RuntimeTestObjectScript.new()

	dependency_resolver.register_value(
		"pipeline_source",
		&"runtime_clock",
		runtime_clock
	)

	dependency_resolver.register_value(
		"pipeline_target",
		&"distance_provider",
		distance_provider
	)

	var host := RuntimeIntegrationHostScript.new(trace)
	var lifecycle := RuntimeIntegrationLifecycleScript.new(
		trace
	)
	var binder := RuntimeIntegrationBinderScript.new(trace)

	var runtime := CompositionRuntime.new(
		registry,
		dependency_resolver,
		host,
		lifecycle,
		binder
	)

	_expect(
		runtime.get_state() == CompositionRuntime.State.CREATED
		and not runtime.is_active(),
		"FCRP-I01: Runtime starts clean in CREATED"
	)

	var activation_result := runtime.activate(plan)

	_expect(
		activation_result.is_success()
		and activation_result.get_report().is_empty(),
		"FCRP-I01: CompositionRuntime activation succeeds cleanly"
	)

	_expect(
		runtime.get_state() == CompositionRuntime.State.ACTIVE
		and runtime.is_active()
		and runtime.get_active_plan() == plan,
		"FCRP-I01: successful activation commits exact Plan as ACTIVE"
	)

	_expect(
		runtime.get_device_bus() != null
		and runtime.get_device_bus().get_dispatch_policy()
		== dispatch_policy,
		"FCRP-I01: Runtime owns a Bus configured with compiled Policy"
	)

	var source_handle := runtime.get_handle(
		"pipeline_source"
	)
	var target_handle := runtime.get_handle(
		"pipeline_target"
	)

	_expect(
		runtime.get_handles().size() == 2
		and source_handle != null
		and target_handle != null,
		"FCRP-I01: ACTIVE exposes exactly two runtime Handles"
	)

	if source_handle == null or target_handle == null:
		return

	_expect(
		source_handle.get_configuration()
		== source_configuration
		and target_handle.get_configuration()
		== target_configuration,
		"FCRP-I01: exact Configuration references reach runtime Handles"
	)

	var clock_binding := source_handle.get_dependency_binding(
		&"runtime_clock"
	)

	var provider_binding := target_handle.get_dependency_binding(
		&"distance_provider"
	)

	_expect(
		clock_binding != null
		and clock_binding.get_value() == runtime_clock
		and clock_binding.is_borrowed(),
		"FCRP-I01: source Handle receives BORROWED runtime clock"
	)

	_expect(
		provider_binding != null
		and provider_binding.get_value()
		== distance_provider
		and provider_binding.is_transferred(),
		"FCRP-I01: target Handle receives TRANSFERRED provider"
	)

	var expected_queries: Array[String] = [
		"pipeline_source:has:runtime_clock",
		"pipeline_source:get:runtime_clock",
		"pipeline_target:has:distance_provider",
		"pipeline_target:get:distance_provider",
	]

	_expect(
		dependency_resolver.get_query_order()
		== expected_queries,
		"FCRP-I01: dependency values resolve once in Plan order"
	)

	var connection_id_text: String = String(
		connection_spec.get_connection_id()
	)

	var expected_activation_events: Array[String] = [
		"build:pipeline_source",
		"build:pipeline_target",
		"attach:pipeline_source",
		"attach:pipeline_target",
		"bind:" + connection_id_text,
		"initialize:pipeline_source",
		"initialize:pipeline_target",
		"ready:pipeline_source",
		"ready:pipeline_target",
		"start:pipeline_source",
		"start:pipeline_target",
	]

	_expect(
		_trace_events(trace)
		== expected_activation_events,
		"FCRP-I01: Runtime executes every activation phase barrier"
	)

	_expect(
		source_factory.get_build_count() == 1
		and target_factory.get_build_count() == 1
		and int(
			host.call(
				&"get_attached_count"
			)
		) == 2
		and int(
			binder.call(
				&"get_bound_count"
			)
		) == 1,
		"FCRP-I01: ACTIVE owns all built, attached and bound resources"
	)

	_expect(
		not runtime_clock.is_released()
		and not distance_provider.is_released(),
		"FCRP-I01: ACTIVE releases no dependency prematurely"
	)

	var shutdown_result := runtime.shutdown()

	_expect(
		shutdown_result.is_success()
		and shutdown_result.get_report().is_empty()
		and runtime.get_state() == CompositionRuntime.State.SHUTDOWN,
		"FCRP-I01: Runtime shutdown succeeds cleanly"
	)

	var expected_complete_events := (
		expected_activation_events.duplicate()
	)

	expected_complete_events.append_array(
		[
			"shutdown:pipeline_target",
			"shutdown:pipeline_source",
			"unbind:" + connection_id_text,
			"detach:pipeline_target",
			"detach:pipeline_source",
			"release:pipeline_target",
			"release:pipeline_source",
		]
	)

	_expect(
		_trace_events(trace)
		== expected_complete_events,
		"FCRP-I01: shutdown reverses lifecycle, communication, host and factory"
	)

	_expect(
		not runtime.is_active()
		and runtime.get_active_plan() == null
		and runtime.get_device_bus() == null
		and runtime.get_handles().is_empty(),
		"FCRP-I01: SHUTDOWN exposes no active runtime state"
	)

	_expect(
		int(
			host.call(
				&"get_attached_count"
			)
		) == 0
		and int(
			binder.call(
				&"get_bound_count"
			)
		) == 0,
		"FCRP-I01: SHUTDOWN leaves no external attachment or binding"
	)

	_expect(
		source_factory.get_release_count() == 1
		and target_factory.get_release_count() == 1,
		"FCRP-I01: each built Handle is released exactly once"
	)

	_expect(
		not runtime_clock.is_released()
		and distance_provider.is_released(),
		"FCRP-I01: shutdown preserves BORROWED and releases TRANSFERRED"
	)

	var final_events := _trace_events(trace)
	var repeated_shutdown := runtime.shutdown()

	_expect(
		not repeated_shutdown.is_success()
		and runtime.get_state()
		== CompositionRuntime.State.SHUTDOWN
		and _trace_events(trace) == final_events,
		"FCRP-I01: terminal SHUTDOWN prevents double cleanup"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _profile(
	profile_id: StringName,
	primary_role: StringName,
	publishes: Array[StringName],
	subscribes: Array[StringName]
) -> DeviceProfile:

	var capabilities: Array[String] = [
		"full_runtime_pipeline",
	]

	var requirements: Array[String] = []

	return DeviceProfile.new(
		profile_id,
		1,
		"Full Runtime Pipeline Profile",
		"End-to-end CompositionRuntime fixture.",
		primary_role,
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
	subscribes: Array[StringName]
) -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"full_runtime_pipeline",
	]

	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName(
			"test.full_runtime_pipeline."
			+ device_id
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


func _system_draft(
) -> SystemProfileDraft:

	var draft := SystemProfileDraft.new()

	draft.system_profile_id = (
		&"test.full_runtime_pipeline.system"
	)
	draft.system_profile_version = 1
	draft.display_name = "Full Composition Runtime Pipeline"
	draft.description = "End-to-end runtime activation fixture."
	draft.activation_context = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	return draft


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


func _trace_events(
	trace: Object
) -> Array[String]:

	var events: Array[String] = []
	var values: Variant = trace.call(
		&"get_events"
	)

	if not (values is Array):
		return events

	for value: Variant in values:
		events.append(
			String(value)
		)

	return events


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
