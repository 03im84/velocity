extends Node


## PropulsionRuntimePipelineIntegrationTest
##
## Verifica el pipeline declarativo completo desde una fuente de
## PropulsionCommand hasta fuerza longitudinal acotada y shutdown.


const SourceFactoryScript = preload(
	"res://test/core/propulsion/propulsion_pipeline_test_source_factory.gd"
)
const ForceSink = preload(
	"res://test/core/propulsion/propulsion_test_force_sink.gd"
)


const SOURCE_DEVICE_ID: String = "propulsion_command_source"
const TARGET_DEVICE_ID: String = "longitudinal_propulsion_actuator"
const SOURCE_PROFILE_ID: StringName = &"test.propulsion.command_source"
const SOURCE_PROFILE_VERSION: int = 1


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("PropulsionRuntimePipelineIntegrationTest")
	print("========================================")

	_test_full_pipeline()
	_finish()


func _test_full_pipeline() -> void:

	var source_profile := _create_source_profile()
	var target_profile := BuiltinDeviceProfiles.create_longitudinal_propulsion_actuator()

	_expect(
		source_profile.is_valid()
		and target_profile.is_valid(),
		"PRP-I01: source and canonical target Profiles are valid"
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
		and catalog_result.get_report().is_empty()
		and catalog != null,
		"PRP-I01: DeviceCatalog compiles cleanly"
	)

	if catalog == null:
		return

	var source_configuration := _create_source_configuration()
	var target_configuration := _create_target_configuration()
	var connection := SystemConnectionSpec.new(
		SOURCE_DEVICE_ID,
		&"out.propulsion_command",
		TARGET_DEVICE_ID,
		PropulsionRuntimeUnit.INPUT_PORT_ID
	)
	var system_draft := SystemProfileDraft.new()
	system_draft.system_profile_id = &"test.propulsion.runtime.system"
	system_draft.system_profile_version = 1
	system_draft.display_name = "Propulsion Runtime System"
	system_draft.description = "Concrete Propulsion runtime fixture."
	system_draft.activation_context = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)
	system_draft.device_configurations.append(
		source_configuration
	)
	system_draft.device_configurations.append(
		target_configuration
	)
	system_draft.connection_specs.append(connection)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)
	var system_profile := system_result.get_profile()

	_expect(
		system_result.is_success()
		and system_result.get_report().is_empty()
		and system_profile != null,
		"PRP-I01: connected SystemProfile compiles cleanly"
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
		and assembly_result.get_report().is_empty()
		and snapshot != null
		and snapshot.is_valid(),
		"PRP-I01: connected DeviceGraphSnapshot assembles cleanly"
	)

	if snapshot == null:
		return

	_expect(
		snapshot.get_devices().size() == 2
		and snapshot.get_connections().size() == 1
		and snapshot.get_connections()[0].get_topic()
		== BusTopics.PROPULSION_COMMAND,
		"PRP-I01: Graph preserves two Devices and Propulsion connection"
	)

	var source_factory := SourceFactoryScript.new()
	var target_factory := PropulsionRuntimeFactory.new()
	var source_specs: Array[RuntimeDependencySpec] = []
	var target_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			PropulsionRuntimeFactory.MODEL_DEPENDENCY_ID,
			RuntimeDependencyBinding.Ownership.BORROWED
		),
		RuntimeDependencySpec.new(
			PropulsionRuntimeFactory.SINK_DEPENDENCY_ID,
			RuntimeDependencyBinding.Ownership.BORROWED
		),
	]
	var registry_draft := RuntimeFactoryRegistryDraft.new()
	registry_draft.descriptors.append(
		RuntimeFactoryDescriptor.new(
			RuntimeFactoryKey.new(
				SOURCE_PROFILE_ID,
				SOURCE_PROFILE_VERSION,
				DeviceConfiguration.ActivationContext.SIMULATION
			),
			source_factory,
			source_specs
		)
	)
	registry_draft.descriptors.append(
		RuntimeFactoryDescriptor.new(
			RuntimeFactoryKey.new(
				PropulsionRuntimeFactory.PROFILE_ID,
				PropulsionRuntimeFactory.PROFILE_VERSION,
				DeviceConfiguration.ActivationContext.SIMULATION
			),
			target_factory,
			target_specs
		)
	)

	var registry_result := RuntimeFactoryRegistryCompiler.new().compile(
		registry_draft
	)
	var registry := registry_result.get_registry()

	_expect(
		registry_result.is_success()
		and registry_result.get_report().is_empty()
		and registry != null
		and registry.is_valid(),
		"PRP-I01: source and production Factory Registry compiles"
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
		and composition_result.get_report().is_empty()
		and plan != null
		and plan.is_valid(),
		"PRP-I01: CompositionPlan compiles cleanly"
	)

	if plan == null:
		return

	_expect(
		plan.get_device_entries().size() == 2
		and plan.get_connection_directives().size() == 1,
		"PRP-I01: Plan contains two entries and one Directive"
	)

	var model := LongitudinalPropulsionModel.new(1200.0, 300.0)
	var sink := ForceSink.new()
	var dependency_values: Array[RuntimeDependencyValue] = [
		RuntimeDependencyValue.new(
			TARGET_DEVICE_ID,
			PropulsionRuntimeFactory.MODEL_DEPENDENCY_ID,
			model
		),
		RuntimeDependencyValue.new(
			TARGET_DEVICE_ID,
			PropulsionRuntimeFactory.SINK_DEPENDENCY_ID,
			sink
		),
	]
	var resolver := ScopedRuntimeDependencyResolver.new(
		dependency_values
	)
	var host := GodotNodeRuntimeHost.new(self)
	var lifecycle := ManagedRuntimeLifecycleAdapter.new()
	var binder := ManagedRuntimeCommunicationBinder.new()
	var runtime := CompositionRuntime.new(
		registry,
		resolver,
		host,
		lifecycle,
		binder
	)
	var activation_result := runtime.activate(plan)

	_expect(
		activation_result.is_success()
		and activation_result.get_report().is_empty(),
		"PRP-I02: CompositionRuntime activates Propulsion pipeline"
	)
	_expect(
		runtime.is_active()
		and runtime.get_handles().size() == 2
		and host.get_attached_handle_count() == 2
		and binder.get_binding_count() == 1,
		"PRP-I02: ACTIVE owns two Handles and one binding"
	)

	var source_handle := runtime.get_handle(SOURCE_DEVICE_ID)
	var target_handle := runtime.get_handle(TARGET_DEVICE_ID)

	_expect(
		source_handle != null
		and target_handle != null
		and target_handle.get_primary_runtime_object()
		is PropulsionRuntimeUnit,
		"PRP-I02: ACTIVE exposes source and production target Handles"
	)

	if source_handle == null or target_handle == null:
		return

	var source_unit: Object = (
		source_handle.get_primary_runtime_object()
	)
	var target_unit: PropulsionRuntimeUnit = (
		target_handle.get_primary_runtime_object()
	)
	var bus := runtime.get_device_bus()

	_expect(
		source_unit.call(&"is_running")
		and target_unit.get_state()
		== PropulsionRuntimeUnit.State.RUNNING,
		"PRP-I02: source and target are RUNNING"
	)
	_expect(
		target_handle.get_host_objects().is_empty()
		and target_handle.get_dependency_binding(
			PropulsionRuntimeFactory.MODEL_DEPENDENCY_ID
		).get_value() == model
		and target_handle.get_dependency_binding(
			PropulsionRuntimeFactory.SINK_DEPENDENCY_ID
		).get_value() == sink,
		"PRP-I02: target Handle preserves no Hosts and exact dependencies"
	)

	_expect(
		source_unit.call(
			&"publish_command",
			PropulsionCommand.new(0.5, 10.0)
		),
		"PRP-I03: RUNNING source publishes forward command"
	)
	_expect(
		sink.apply_count == 1
		and sink.last_force_newtons == 600.0
		and sink.last_timestamp == 10.0
		and target_unit.get_last_actuation_report().is_empty(),
		"PRP-I03: forward command reaches sink as exact bounded force"
	)

	bus.publish(
		BusTopics.PROPULSION_COMMAND,
		BusMessage.new(
			"intruder_source",
			BusTopics.PROPULSION_COMMAND,
			11.0,
			PropulsionCommand.new(1.0, 11.0)
		)
	)

	_expect(
		sink.apply_count == 1,
		"PRP-I03: source filtering rejects another Device identity"
	)

	source_unit.call(
		&"publish_command",
		PropulsionCommand.new(-1.0, 12.0)
	)
	_expect(
		sink.apply_count == 2
		and sink.last_force_newtons == -300.0,
		"PRP-I03: reverse command respects reverse force limit"
	)

	source_unit.call(
		&"publish_command",
		PropulsionCommand.new(0.0, 13.0)
	)
	_expect(
		sink.apply_count == 3
		and sink.last_force_newtons == 0.0,
		"PRP-I03: neutral command produces explicit zero force"
	)

	sink.result = false
	source_unit.call(
		&"publish_command",
		PropulsionCommand.new(0.5, 14.0)
	)
	_expect(
		sink.apply_count == 4
		and target_unit.get_last_force_newtons() == 0.0
		and _report_has_code(
			target_unit.get_last_actuation_report(),
			&"propulsion_runtime_sink_rejected"
		),
		"PRP-I04: sink rejection is fail-neutral and observable"
	)

	sink.result = true
	source_unit.call(
		&"publish_command",
		PropulsionCommand.new(0.25, 15.0)
	)
	_expect(
		sink.apply_count == 5
		and sink.last_force_newtons == 300.0
		and target_unit.get_last_force_newtons() == 300.0
		and target_unit.get_last_actuation_report().is_empty(),
		"PRP-I04: later valid command recovers actuation"
	)

	var shutdown_result := runtime.shutdown()

	_expect(
		shutdown_result.is_success()
		and shutdown_result.get_report().is_empty(),
		"PRP-I05: Propulsion Runtime shutdown succeeds"
	)
	_expect(
		runtime.get_state() == CompositionRuntime.State.SHUTDOWN
		and host.get_attached_handle_count() == 0
		and binder.get_binding_count() == 0,
		"PRP-I05: shutdown clears Runtime, Host and binding state"
	)
	_expect(
		target_unit.get_state()
		== PropulsionRuntimeUnit.State.SHUTDOWN
		and not source_unit.call(&"is_running"),
		"PRP-I05: both Runtime Units are shutdown"
	)
	_expect(
		is_instance_valid(model)
		and is_instance_valid(sink)
		and target_unit.get_model() == model
		and target_unit.get_force_sink() == sink,
		"PRP-I05: BORROWED model and sink remain alive"
	)
	_expect(
		source_factory.release_count == 1
		and bus.get_topics().is_empty(),
		"PRP-I05: factories released and DeviceBus subscriptions cleared"
	)


func _create_source_profile() -> DeviceProfile:

	var capabilities: Array[String] = [
		"propulsion_command_source",
	]
	var publishes: Array[StringName] = [
		BusTopics.PROPULSION_COMMAND,
	]
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceProfile.new(
		SOURCE_PROFILE_ID,
		SOURCE_PROFILE_VERSION,
		"Propulsion Command Source",
		"Deterministic integration test command source.",
		DeviceRoles.LOCAL_CONTROLLER,
		capabilities,
		publishes,
		subscribes,
		requirements,
		false,
		&"",
		0
	)


func _create_source_configuration() -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"propulsion_command_source",
	]
	var publishes: Array[StringName] = [
		BusTopics.PROPULSION_COMMAND,
	]
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		&"test.propulsion.source.configuration",
		1,
		SOURCE_DEVICE_ID,
		SOURCE_PROFILE_ID,
		SOURCE_PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _create_target_configuration() -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"longitudinal_propulsion_force",
	]
	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = [
		BusTopics.PROPULSION_COMMAND,
	]
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		&"test.propulsion.target.configuration",
		1,
		TARGET_DEVICE_ID,
		PropulsionRuntimeFactory.PROFILE_ID,
		PropulsionRuntimeFactory.PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


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


func _expect(
	condition: bool,
	description: String
) -> void:

	_checks += 1

	if condition:
		print("[PASS] ", description)
		return

	_failures += 1
	push_error("[FAIL] " + description)


func _finish() -> void:

	print("----------------------------------------")
	print("Checks: ", _checks)
	print("Failures: ", _failures)

	if _failures == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")

	print("========================================")
	print("")
	get_tree().quit(_failures)
