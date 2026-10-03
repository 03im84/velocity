extends Node


const Helpers = preload(
	"res://test/core/runtime/distance_sensor_runtime_test_helpers.gd"
)


var _checks: int = 0
var _failures: int = 0
var _messages: Array[BusMessage] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("DistanceSensorRuntimePipelineIntegrationTest")
	print("========================================")

	_test_full_pipeline()
	_finish()


func _test_full_pipeline() -> void:

	var profile := BuiltinDeviceProfiles.create_ideal_distance_sensor()
	var catalog_draft := DeviceCatalogDraft.new()
	catalog_draft.profiles.append(profile)
	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)
	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success() and catalog != null,
		"DSRP-I01: canonical DeviceCatalog compiles"
	)

	if catalog == null:
		return

	var configuration := Helpers.create_configuration(
		"runtime_distance_sensor"
	)
	var system_draft := SystemProfileDraft.new()
	system_draft.system_profile_id = &"test.distance.runtime.system"
	system_draft.system_profile_version = 1
	system_draft.display_name = "Distance Sensor Runtime System"
	system_draft.description = "Concrete runtime slice fixture."
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
		system_result.is_success() and system_profile != null,
		"DSRP-I01: SystemProfile compiles"
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
		and snapshot != null
		and snapshot.is_valid(),
		"DSRP-I01: DeviceGraphSnapshot assembles"
	)

	if snapshot == null:
		return

	var factory := DistanceSensorRuntimeFactory.new()
	var specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			DistanceSensorRuntimeFactory.DEPENDENCY_ID,
			RuntimeDependencyBinding.Ownership.BORROWED
		),
	]
	var registry_draft := RuntimeFactoryRegistryDraft.new()
	registry_draft.descriptors.append(
		RuntimeFactoryDescriptor.new(
			RuntimeFactoryKey.new(
				DistanceSensorRuntimeFactory.PROFILE_ID,
				DistanceSensorRuntimeFactory.PROFILE_VERSION,
				DeviceConfiguration.ActivationContext.SIMULATION
			),
			factory,
			specs
		)
	)
	var registry_result := RuntimeFactoryRegistryCompiler.new().compile(
		registry_draft
	)
	var registry := registry_result.get_registry()

	_expect(
		registry_result.is_success()
		and registry != null
		and registry.is_valid(),
		"DSRP-I01: concrete Factory Registry compiles"
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
		and plan != null
		and plan.is_valid(),
		"DSRP-I01: CompositionPlan compiles"
	)

	if plan == null:
		return

	_expect(
		plan.get_device_entries().size() == 1
		and plan.get_connection_directives().is_empty(),
		"DSRP-I01: Plan contains one source-only Device"
	)

	var provider := ManualDistanceProvider.new()
	provider.set_distance(8.75)
	var dependency_values: Array[RuntimeDependencyValue] = [
		RuntimeDependencyValue.new(
			"runtime_distance_sensor",
			DistanceSensorRuntimeFactory.DEPENDENCY_ID,
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
		"DSRP-I02: CompositionRuntime activates concrete Sensor"
	)
	_expect(
		runtime.is_active()
		and runtime.get_handles().size() == 1
		and host.get_attached_handle_count() == 1,
		"DSRP-I02: ACTIVE owns one attached Handle"
	)

	var handle := runtime.get_handle("runtime_distance_sensor")
	var unit: DistanceSensorRuntimeUnit = (
		handle.get_primary_runtime_object()
	)
	var sensor := unit.get_sensor()
	var bus := runtime.get_device_bus()

	_expect(
		unit.get_state() == DistanceSensorRuntimeUnit.State.RUNNING
		and sensor.get_parent() == self,
		"DSRP-I02: concrete Unit is RUNNING and Sensor is hosted"
	)
	_expect(
		sensor.device.get_manifest().capabilities
		== configuration.get_enabled_capabilities()
		and sensor.device.get_manifest().publishes
		== configuration.get_enabled_publishes(),
		"DSRP-I02: runtime Manifest matches Configuration"
	)
	_expect(
		handle.get_dependency_binding(
			DistanceSensorRuntimeFactory.DEPENDENCY_ID
		).get_value() == provider
		and handle.get_dependency_binding(
			DistanceSensorRuntimeFactory.DEPENDENCY_ID
		).is_borrowed(),
		"DSRP-I02: Handle preserves exact BORROWED Provider"
	)

	bus.subscribe(
		BusTopics.DISTANCE_MEASUREMENT,
		_on_message
	)
	var publish_report := unit.publish_measurement()

	_expect(
		publish_report.is_valid_for_simulation()
		and _messages.size() == 1,
		"DSRP-I03: RUNNING Unit publishes one message"
	)

	if not _messages.is_empty():
		var message := _messages[0]
		var payload: DistanceMeasurement
		if message.get_payload() is DistanceMeasurement:
			payload = message.get_payload()

		_expect(
			message.get_source_id() == "runtime_distance_sensor"
			and message.get_topic()
			== BusTopics.DISTANCE_MEASUREMENT,
			"DSRP-I03: BusMessage preserves concrete Sensor identity"
		)
		_expect(
			payload != null
			and payload.distance == 8.75
			and payload.valid,
			"DSRP-I03: Measurement preserves Provider data"
		)

	var shutdown_result := runtime.shutdown()

	_expect(
		shutdown_result.is_success()
		and shutdown_result.get_report().is_empty(),
		"DSRP-I04: concrete Runtime shutdown succeeds"
	)
	_expect(
		runtime.get_state() == CompositionRuntime.State.SHUTDOWN
		and host.get_attached_handle_count() == 0,
		"DSRP-I04: shutdown clears Runtime and Host state"
	)
	_expect(
		not is_instance_valid(sensor),
		"DSRP-I04: Factory release frees detached Sensor Node"
	)
	_expect(
		is_instance_valid(provider)
		and provider.get_distance() == 8.75,
		"DSRP-I04: BORROWED Provider remains alive"
	)
	_expect(
		bus.get_topics().is_empty(),
		"DSRP-I04: DeviceBus subscriptions are cleared"
	)


func _on_message(message: BusMessage) -> void:

	_messages.append(message)


func _expect(condition: bool, description: String) -> void:

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
