extends Node


## InputRuntimePipelineIntegrationTest
##
## Verifica el recorrido concreto completo de Input Simulation:
## DeviceProfile -> DeviceCatalog -> SystemProfile
## -> DeviceGraphSnapshot -> CompositionPlan
## -> CompositionRuntime -> ACTIVE -> VehicleControlCommand
## -> SHUTDOWN.
##
## Usa GodotInputIntentProvider con una fuente determinista,
## InputRuntimeFactory y los adapters de producción.


const InputTestSource = preload(
	"res://test/core/input/input_test_source.gd"
)


const DEVICE_ID: String = "runtime_player_input"


var _checks: int = 0
var _failures: int = 0
var _messages: Array[BusMessage] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("InputRuntimePipelineIntegrationTest")
	print("========================================")

	await _test_full_pipeline()
	_finish()


func _test_full_pipeline() -> void:

	var profile := _create_profile()

	_expect(
		profile.is_valid()
		and profile.get_profile_id() == InputRuntimeFactory.PROFILE_ID
		and profile.get_profile_version()
		== InputRuntimeFactory.PROFILE_VERSION,
		"IRP-I01: canonical Input DeviceProfile is valid"
	)

	var catalog_draft := DeviceCatalogDraft.new()
	catalog_draft.profiles.append(profile)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)
	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog_result.get_report().is_empty()
		and catalog != null
		and catalog.is_valid(),
		"IRP-I01: Input DeviceCatalog compiles cleanly"
	)

	if catalog == null:
		return

	var configuration := _create_configuration()
	var system_draft := SystemProfileDraft.new()
	system_draft.system_profile_id = &"test.input.runtime.system"
	system_draft.system_profile_version = 1
	system_draft.display_name = "Input Runtime System"
	system_draft.description = "Concrete Input runtime slice fixture."
	system_draft.activation_context = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)
	system_draft.device_configurations.append(configuration)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)
	var system_profile := system_result.get_profile()

	_expect(
		system_result.is_success()
		and system_result.get_report().is_empty()
		and system_profile != null,
		"IRP-I01: Input SystemProfile compiles cleanly"
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
		and assembly_result.get_report().is_valid_for_simulation()
		and snapshot != null
		and snapshot.is_valid(),
		"IRP-I01: Input DeviceGraphSnapshot assembles safely"
	)

	if snapshot == null:
		return

	_expect(
		snapshot.get_devices().size() == 1
		and snapshot.get_devices()[0].get_device_id() == DEVICE_ID
		and snapshot.get_connections().is_empty()
		and _report_has_issue(
			assembly_result.get_report(),
			&"output_port_unconnected",
			ValidationIssue.Severity.INFO
		),
		"IRP-I01: source-only Input reports expected unconnected output INFO"
	)

	var factory := InputRuntimeFactory.new()
	var dependency_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			InputRuntimeFactory.DEPENDENCY_ID,
			RuntimeDependencyBinding.Ownership.BORROWED
		),
	]
	var descriptor := RuntimeFactoryDescriptor.new(
		RuntimeFactoryKey.new(
			InputRuntimeFactory.PROFILE_ID,
			InputRuntimeFactory.PROFILE_VERSION,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		factory,
		dependency_specs
	)
	var registry_draft := RuntimeFactoryRegistryDraft.new()
	registry_draft.descriptors.append(descriptor)

	var registry_result := RuntimeFactoryRegistryCompiler.new().compile(
		registry_draft
	)
	var registry := registry_result.get_registry()

	_expect(
		registry_result.is_success()
		and registry_result.get_report().is_empty()
		and registry != null
		and registry.is_valid(),
		"IRP-I01: Input Factory Registry compiles cleanly"
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
		"IRP-I01: Input CompositionPlan compiles cleanly"
	)

	if plan == null:
		return

	_expect(
		plan.get_device_entries().size() == 1
		and plan.get_device_entries()[0].get_device_id() == DEVICE_ID
		and plan.get_connection_directives().is_empty(),
		"IRP-I01: Plan contains one source-only Input entry"
	)

	var source := InputTestSource.new()
	source.strengths[&"throttle_positive"] = 0.8
	source.strengths[&"throttle_negative"] = 0.2
	source.strengths[&"steer_left"] = 0.55
	source.strengths[&"steer_right"] = 0.15
	source.strengths[&"brake"] = 0.35

	var provider := GodotInputIntentProvider.new(
		source,
		&"throttle_positive",
		&"throttle_negative",
		&"steer_left",
		&"steer_right",
		&"brake",
		0.0
	)

	_expect(
		provider.is_valid(),
		"IRP-I02: concrete Godot Input Provider is valid"
	)

	var dependency_values: Array[RuntimeDependencyValue] = [
		RuntimeDependencyValue.new(
			DEVICE_ID,
			InputRuntimeFactory.DEPENDENCY_ID,
			provider
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
		"IRP-I02: CompositionRuntime activates concrete Input"
	)
	_expect(
		runtime.is_active()
		and runtime.get_handles().size() == 1
		and host.get_attached_handle_count() == 1,
		"IRP-I02: ACTIVE owns one attached Input Handle"
	)

	var handle := runtime.get_handle(DEVICE_ID)

	_expect(
		handle != null
		and handle.is_valid()
		and handle.get_primary_runtime_object() is InputRuntimeUnit,
		"IRP-I02: ACTIVE exposes the concrete Input Handle"
	)

	if handle == null:
		return

	var unit: InputRuntimeUnit = handle.get_primary_runtime_object()
	var sampler := unit.get_sampler()
	var bus := runtime.get_device_bus()

	_expect(
		unit.get_state() == InputRuntimeUnit.State.RUNNING
		and sampler.get_parent() == self
		and sampler.is_sampling_enabled(),
		"IRP-I02: Unit is RUNNING and Sampler is hosted and enabled"
	)
	_expect(
		handle.get_dependency_binding(
			InputRuntimeFactory.DEPENDENCY_ID
		).get_value() == provider
		and handle.get_dependency_binding(
			InputRuntimeFactory.DEPENDENCY_ID
		).is_borrowed(),
		"IRP-I02: Handle preserves exact BORROWED Provider"
	)
	_expect(
		bus != null
		and bus.subscribe(
			BusTopics.VEHICLE_CONTROL_COMMAND,
			_on_message
		),
		"IRP-I03: active DeviceBus accepts command subscriber"
	)

	await get_tree().physics_frame
	await get_tree().physics_frame

	_expect(
		_messages.size() == 1,
		"IRP-I03: hosted Sampler publishes one command on physics tick"
	)

	if not _messages.is_empty():
		var message := _messages[0]
		var command: VehicleControlCommand

		if message.get_payload() is VehicleControlCommand:
			command = message.get_payload()

		_expect(
			message.is_valid()
			and message.get_source_id() == DEVICE_ID
			and message.get_topic()
			== BusTopics.VEHICLE_CONTROL_COMMAND
			and is_finite(message.get_timestamp())
			and message.get_timestamp() >= 0.0,
			"IRP-I03: BusMessage preserves Input identity and timestamp"
		)
		_expect(
			command != null
			and command.is_valid()
			and is_equal_approx(command.get_throttle(), 0.6)
			and is_equal_approx(command.get_steering(), -0.4)
			and is_equal_approx(command.get_brake(), 0.35)
			and command.get_timestamp() == message.get_timestamp(),
			"IRP-I03: command preserves normalized Provider intent"
		)

	var shutdown_result := runtime.shutdown()

	_expect(
		shutdown_result.is_success()
		and shutdown_result.get_report().is_empty(),
		"IRP-I04: concrete Input Runtime shutdown succeeds"
	)
	_expect(
		runtime.get_state() == CompositionRuntime.State.SHUTDOWN
		and host.get_attached_handle_count() == 0,
		"IRP-I04: shutdown clears Runtime and Host state"
	)
	_expect(
		not is_instance_valid(sampler),
		"IRP-I04: Factory release frees detached Sampler"
	)
	_expect(
		is_instance_valid(provider)
		and provider.is_valid()
		and is_instance_valid(source),
		"IRP-I04: BORROWED Provider and source remain alive"
	)
	_expect(
		bus.get_topics().is_empty(),
		"IRP-I04: DeviceBus subscriptions are cleared"
	)


func _create_profile() -> DeviceProfile:

	var capabilities: Array[String] = [
		"vehicle_control_input",
	]
	var publishes: Array[StringName] = [
		BusTopics.VEHICLE_CONTROL_COMMAND,
	]
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceProfile.new(
		InputRuntimeFactory.PROFILE_ID,
		InputRuntimeFactory.PROFILE_VERSION,
		"Player Input",
		"Normalized player vehicle-control intent source.",
		DeviceRoles.LOCAL_CONTROLLER,
		capabilities,
		publishes,
		subscribes,
		requirements,
		true,
		&"",
		0
	)


func _create_configuration() -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"vehicle_control_input",
	]
	var publishes: Array[StringName] = [
		BusTopics.VEHICLE_CONTROL_COMMAND,
	]
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		&"test.input.runtime.player",
		1,
		DEVICE_ID,
		InputRuntimeFactory.PROFILE_ID,
		InputRuntimeFactory.PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _on_message(
	message: BusMessage
) -> void:

	_messages.append(message)


func _report_has_issue(
	report: ValidationReport,
	code: StringName,
	severity: ValidationIssue.Severity
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
