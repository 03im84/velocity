extends Node


## HoverPointRuntimePipelineIntegrationTest
##
## Verifica el pipeline completo desde DistanceSensorRuntimeUnit de
## producción hasta lift acotado en HoverPointRuntimeUnit.


const ForceSink = preload(
	"res://test/core/hover/hover_test_force_sink.gd"
)


const SENSOR_DEVICE_ID: String = "hover_distance_sensor"
const HOVER_DEVICE_ID: String = "front_left_hover_point"


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("HoverPointRuntimePipelineIntegrationTest")
	print("========================================")

	_test_full_pipeline()
	_finish()


func _test_full_pipeline() -> void:

	var sensor_profile := (
		BuiltinDeviceProfiles.create_ideal_distance_sensor()
	)
	var hover_profile := (
		BuiltinDeviceProfiles.create_spring_damper_hover_point()
	)

	_expect(
		sensor_profile.is_valid()
		and hover_profile.is_valid(),
		"HRP-I01: production Sensor and Hover Profiles are valid"
	)

	var catalog_draft := DeviceCatalogDraft.new()
	catalog_draft.profiles.append(sensor_profile)
	catalog_draft.profiles.append(hover_profile)
	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)
	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog_result.get_report().is_empty()
		and catalog != null,
		"HRP-I01: DeviceCatalog compiles cleanly"
	)

	if catalog == null:
		return

	var sensor_configuration := _sensor_configuration()
	var hover_configuration := _hover_configuration()
	var connection := SystemConnectionSpec.new(
		SENSOR_DEVICE_ID,
		&"out.distance_measurement",
		HOVER_DEVICE_ID,
		HoverPointRuntimeUnit.INPUT_PORT_ID
	)
	var system_draft := SystemProfileDraft.new()
	system_draft.system_profile_id = &"test.hover.runtime.system"
	system_draft.system_profile_version = 1
	system_draft.display_name = "Hover Runtime System"
	system_draft.description = "Distance Sensor to Hover Point fixture."
	system_draft.activation_context = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)
	system_draft.device_configurations.append(
		sensor_configuration
	)
	system_draft.device_configurations.append(
		hover_configuration
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
		"HRP-I01: connected SystemProfile compiles cleanly"
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
		"HRP-I01: connected DeviceGraphSnapshot assembles cleanly"
	)

	if snapshot == null:
		return

	_expect(
		snapshot.get_devices().size() == 2
		and snapshot.get_connections().size() == 1
		and snapshot.get_connections()[0].get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"HRP-I01: Graph preserves Sensor-to-Hover connection"
	)

	var sensor_factory := DistanceSensorRuntimeFactory.new()
	var hover_factory := HoverPointRuntimeFactory.new()
	var sensor_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			DistanceSensorRuntimeFactory.DEPENDENCY_ID,
			RuntimeDependencyBinding.Ownership.BORROWED
		),
	]
	var hover_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			HoverPointRuntimeFactory.MODEL_DEPENDENCY_ID,
			RuntimeDependencyBinding.Ownership.BORROWED
		),
		RuntimeDependencySpec.new(
			HoverPointRuntimeFactory.SINK_DEPENDENCY_ID,
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
			sensor_factory,
			sensor_specs
		)
	)
	registry_draft.descriptors.append(
		RuntimeFactoryDescriptor.new(
			RuntimeFactoryKey.new(
				HoverPointRuntimeFactory.PROFILE_ID,
				HoverPointRuntimeFactory.PROFILE_VERSION,
				DeviceConfiguration.ActivationContext.SIMULATION
			),
			hover_factory,
			hover_specs
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
		"HRP-I01: production Factory Registry compiles"
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
		"HRP-I01: CompositionPlan compiles cleanly"
	)

	if plan == null:
		return

	_expect(
		plan.get_device_entries().size() == 2
		and plan.get_connection_directives().size() == 1,
		"HRP-I01: Plan contains two entries and one Directive"
	)

	var provider := ManualDistanceProvider.new()
	provider.set_distance(2.0)
	var model := HoverSpringDamperModel.new(
		2.0, 9810.0, 20000.0, 8000.0, 30000.0, 0.1
	)
	var sink := ForceSink.new()
	var dependency_values: Array[RuntimeDependencyValue] = [
		RuntimeDependencyValue.new(
			SENSOR_DEVICE_ID,
			DistanceSensorRuntimeFactory.DEPENDENCY_ID,
			provider
		),
		RuntimeDependencyValue.new(
			HOVER_DEVICE_ID,
			HoverPointRuntimeFactory.MODEL_DEPENDENCY_ID,
			model
		),
		RuntimeDependencyValue.new(
			HOVER_DEVICE_ID,
			HoverPointRuntimeFactory.SINK_DEPENDENCY_ID,
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
		"HRP-I02: CompositionRuntime activates Sensor-to-Hover pipeline"
	)
	_expect(
		runtime.is_active()
		and runtime.get_handles().size() == 2
		and host.get_attached_handle_count() == 2
		and binder.get_binding_count() == 1,
		"HRP-I02: ACTIVE owns two Handles and one binding"
	)

	var sensor_handle := runtime.get_handle(SENSOR_DEVICE_ID)
	var hover_handle := runtime.get_handle(HOVER_DEVICE_ID)

	_expect(
		sensor_handle != null
		and hover_handle != null
		and sensor_handle.get_primary_runtime_object()
		is DistanceSensorRuntimeUnit
		and hover_handle.get_primary_runtime_object()
		is HoverPointRuntimeUnit,
		"HRP-I02: ACTIVE exposes both production Runtime Units"
	)

	if sensor_handle == null or hover_handle == null:
		return

	var sensor_unit: DistanceSensorRuntimeUnit = (
		sensor_handle.get_primary_runtime_object()
	)
	var hover_unit: HoverPointRuntimeUnit = (
		hover_handle.get_primary_runtime_object()
	)
	var sensor_node := sensor_unit.get_sensor()
	var bus := runtime.get_device_bus()

	_expect(
		sensor_unit.get_state()
		== DistanceSensorRuntimeUnit.State.RUNNING
		and hover_unit.get_state()
		== HoverPointRuntimeUnit.State.RUNNING
		and sensor_node.get_parent() == self,
		"HRP-I02: both Units are RUNNING and Sensor Node is hosted"
	)
	_expect(
		hover_handle.get_host_objects().is_empty()
		and hover_handle.get_dependency_binding(
			HoverPointRuntimeFactory.MODEL_DEPENDENCY_ID
		).get_value() == model
		and hover_handle.get_dependency_binding(
			HoverPointRuntimeFactory.SINK_DEPENDENCY_ID
		).get_value() == sink,
		"HRP-I02: Hover Handle preserves no Hosts and exact dependencies"
	)

	var first_report := sensor_unit.publish_measurement()

	_expect(
		first_report.is_valid_for_simulation()
		and sink.apply_count == 1,
		"HRP-I03: production Sensor publishes first Hover sample"
	)
	_expect(
		sink.last_force_newtons == 9810.0
		and hover_unit.get_last_distance_rate_meters_per_second()
		== 0.0
		and hover_unit.get_last_actuation_report().is_empty(),
		"HRP-I03: first sample produces equilibrium lift with zero rate"
	)

	var intruder_measurement := DistanceMeasurement.new()
	intruder_measurement.distance = 1.0
	intruder_measurement.valid = true
	intruder_measurement.timestamp = (
		Time.get_ticks_msec() / 1000.0
	)
	bus.publish(
		BusTopics.DISTANCE_MEASUREMENT,
		BusMessage.new(
			"intruder_sensor",
			BusTopics.DISTANCE_MEASUREMENT,
			intruder_measurement.timestamp,
			intruder_measurement
		)
	)

	_expect(
		sink.apply_count == 1,
		"HRP-I03: source filtering rejects another Sensor identity"
	)

	provider.invalidate()
	sensor_unit.publish_measurement()

	_expect(
		sink.apply_count == 1
		and not hover_unit.has_previous_sample()
		and _report_has_code(
			hover_unit.get_last_actuation_report(),
			&"hover_runtime_measurement_invalid"
		),
		"HRP-I04: invalid Sensor reading clears history without force"
	)

	provider.set_distance(1.5)
	sensor_unit.publish_measurement()

	_expect(
		sink.apply_count == 2
		and sink.last_force_newtons == 19810.0
		and hover_unit.get_last_distance_rate_meters_per_second()
		== 0.0
		and hover_unit.get_last_actuation_report().is_empty(),
		"HRP-I04: recovered reading acts as safe first sample"
	)

	var shutdown_result := runtime.shutdown()

	_expect(
		shutdown_result.is_success()
		and shutdown_result.get_report().is_empty(),
		"HRP-I05: Hover Runtime shutdown succeeds"
	)
	_expect(
		runtime.get_state() == CompositionRuntime.State.SHUTDOWN
		and host.get_attached_handle_count() == 0
		and binder.get_binding_count() == 0,
		"HRP-I05: shutdown clears Runtime, Host and binding state"
	)
	_expect(
		hover_unit.get_state() == HoverPointRuntimeUnit.State.SHUTDOWN
		and not hover_unit.has_previous_sample()
		and not is_instance_valid(sensor_node),
		"HRP-I05: Hover history clears and Sensor Node is released"
	)
	_expect(
		is_instance_valid(provider)
		and is_instance_valid(model)
		and is_instance_valid(sink)
		and hover_unit.get_model() == model
		and hover_unit.get_force_sink() == sink,
		"HRP-I05: all BORROWED dependencies remain alive"
	)
	_expect(
		bus.get_topics().is_empty(),
		"HRP-I05: DeviceBus subscriptions are cleared"
	)


func _sensor_configuration() -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"distance_measurement",
	]
	var publishes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		&"test.hover.sensor.configuration",
		1,
		SENSOR_DEVICE_ID,
		DistanceSensorRuntimeFactory.PROFILE_ID,
		DistanceSensorRuntimeFactory.PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _hover_configuration() -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"hover_lift_force",
	]
	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		&"test.hover.point.configuration",
		1,
		HOVER_DEVICE_ID,
		HoverPointRuntimeFactory.PROFILE_ID,
		HoverPointRuntimeFactory.PROFILE_VERSION,
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
