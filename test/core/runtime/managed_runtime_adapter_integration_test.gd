extends Node


const ManagedRuntimeTestFactoryScript = preload(
	"res://test/core/runtime/managed_runtime_test_factory.gd"
)
const RuntimeAdapterTestHelpersScript = preload(
	"res://test/core/runtime/runtime_adapter_test_helpers.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("ManagedRuntimeAdapterIntegrationTest")
	print("========================================")

	_test_full_adapter_activation_and_shutdown()
	_test_contract_boundaries()

	_finish_test()


func _test_full_adapter_activation_and_shutdown() -> void:

	var factory := ManagedRuntimeTestFactoryScript.new()
	var source_entry := _entry(
		"source",
		&"test.managed.source"
	)
	var target_entry := _entry(
		"target",
		&"test.managed.target"
	)
	var entries: Array[CompositionDeviceEntry] = [
		source_entry,
		target_entry,
	]
	var directive := CompositionConnectionDirective.new(
		"source",
		&"out.test_message",
		BusTopics.TEST_MESSAGE,
		"target",
		&"in.test_message"
	)
	var directives: Array[CompositionConnectionDirective] = [
		directive,
	]
	var plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		DeviceBusDispatchPolicy.new()
	)
	var registry := _registry(entries, factory)
	var dependency_values: Array[RuntimeDependencyValue] = []
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

	_expect(
		plan.is_valid()
		and registry != null
		and registry.is_valid()
		and resolver.is_valid(),
		"MRA-I01: Plan, Registry and Resolver fixtures are valid"
	)

	var activation_result := runtime.activate(plan)

	_expect(
		activation_result.is_success()
		and activation_result.get_report().is_empty(),
		"MRA-I01: production adapters activate CompositionRuntime"
	)
	_expect(
		runtime.is_active()
		and runtime.get_handles().size() == 2,
		"MRA-I01: Runtime commits ACTIVE with two Handles"
	)

	var expected_forward: Array[String] = [
		"source",
		"target",
	]

	_expect(
		factory.get_build_order() == expected_forward,
		"MRA-I01: controlled factory builds in Plan order"
	)
	_expect(
		host.get_attached_handle_count() == 2
		and get_child_count() == 2,
		"MRA-I01: Godot Host attaches both explicit Nodes"
	)
	_expect(
		factory.get_host_node("source").get_parent() == self
		and factory.get_host_node("target").get_parent() == self,
		"MRA-I01: Host uses explicit parent only"
	)
	_expect(
		binder.get_binding_count() == 1
		and runtime.get_device_bus().get_subscriber_count(
			BusTopics.TEST_MESSAGE
		) == 1,
		"MRA-I01: Communication Binder owns one Subscription"
	)

	var source_unit: Object = factory.get_unit("source")
	var target_unit: Object = factory.get_unit("target")
	var expected_source_events: Array[String] = [
		"initialize:source",
		"ready:source",
		"start:source",
	]
	var expected_target_events: Array[String] = [
		"initialize:target",
		"ready:target",
		"start:target",
	]

	_expect(
		source_unit.call(&"get_events")
		== expected_source_events
		and target_unit.call(&"get_events")
		== expected_target_events,
		"MRA-I01: Lifecycle Adapter delegates every phase"
	)

	runtime.get_device_bus().publish(
		BusTopics.TEST_MESSAGE,
		BusMessage.new(
			"other_source",
			BusTopics.TEST_MESSAGE,
			0.0,
			null
		)
	)

	var messages_after_wrong_source: Array = target_unit.call(
		&"get_received_messages"
	)

	_expect(
		messages_after_wrong_source.is_empty(),
		"MRA-I01: source-filtered Subscription rejects other Device"
	)

	var matching_message := BusMessage.new(
		"source",
		BusTopics.TEST_MESSAGE,
		1.0,
		RefCounted.new()
	)

	runtime.get_device_bus().publish(
		BusTopics.TEST_MESSAGE,
		matching_message
	)

	var matching_messages: Array = target_unit.call(
		&"get_received_messages"
	)

	_expect(
		matching_messages.size() == 1
		and matching_messages[0] == matching_message,
		"MRA-I01: matching BusMessage reaches exact target endpoint"
	)

	var shutdown_result := runtime.shutdown()

	_expect(
		shutdown_result.is_success()
		and shutdown_result.get_report().is_empty(),
		"MRA-I01: production adapters shutdown cleanly"
	)
	_expect(
		runtime.get_state() == CompositionRuntime.State.SHUTDOWN
		and not runtime.is_active(),
		"MRA-I01: Runtime commits terminal SHUTDOWN"
	)

	var expected_source_after_shutdown: Array[String] = [
		"initialize:source",
		"ready:source",
		"start:source",
		"shutdown:source",
	]
	var expected_target_after_shutdown: Array[String] = [
		"initialize:target",
		"ready:target",
		"start:target",
		"shutdown:target",
	]

	_expect(
		source_unit.call(&"get_events")
		== expected_source_after_shutdown
		and target_unit.call(&"get_events")
		== expected_target_after_shutdown,
		"MRA-I01: shutdown reaches both managed runtime units"
	)
	_expect(
		binder.get_binding_count() == 0
		and host.get_attached_handle_count() == 0
		and get_child_count() == 0,
		"MRA-I01: unbind and detach clear adapter state"
	)

	var expected_reverse: Array[String] = [
		"target",
		"source",
	]

	_expect(
		factory.get_release_order() == expected_reverse,
		"MRA-I01: factories release in reverse order"
	)
	_expect(
		factory.get_host_node("source") == null
		and factory.get_host_node("target") == null,
		"MRA-I01: factory release owns final Node destruction"
	)


func _test_contract_boundaries() -> void:

	var lifecycle := ManagedRuntimeLifecycleAdapter.new()
	var binder := ManagedRuntimeCommunicationBinder.new()
	var values: Array[RuntimeDependencyValue] = []
	var resolver := ScopedRuntimeDependencyResolver.new(values)
	var host := GodotNodeRuntimeHost.new(self)

	_expect(
		not lifecycle.has_method(&"build")
		and not binder.has_method(&"build")
		and not host.has_method(&"release"),
		"MRA-I02: adapters do not take factory responsibility"
	)
	_expect(
		not resolver.has_method(&"register_value")
		and not binder.has_method(&"register_endpoint")
		and not host.has_method(&"find_parent"),
		"MRA-I02: adapters expose no mutation Registry or discovery API"
	)


func _entry(
	device_id: String,
	profile_id: StringName
) -> CompositionDeviceEntry:

	var dependency_specs: Array[RuntimeDependencySpec] = []

	return CompositionDeviceEntry.new(
		device_id,
		RuntimeAdapterTestHelpersScript.create_configuration(
			device_id,
			profile_id
		),
		RuntimeFactoryKey.new(
			profile_id,
			1,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		dependency_specs
	)


func _registry(
	entries: Array[CompositionDeviceEntry],
	factory: Object
) -> RuntimeFactoryRegistry:

	var draft := RuntimeFactoryRegistryDraft.new()

	for entry: CompositionDeviceEntry in entries:
		var specs: Array[RuntimeDependencySpec] = []
		draft.descriptors.append(
			RuntimeFactoryDescriptor.new(
				entry.get_factory_key(),
				factory,
				specs
			)
		)

	var result := RuntimeFactoryRegistryCompiler.new().compile(
		draft
	)

	return result.get_registry()


func _expect(
	condition: bool,
	description: String
) -> void:

	_check_count += 1

	if condition:
		print("[PASS] ", description)
		return

	_failure_count += 1
	push_error("[FAIL] " + description)


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
	get_tree().quit(_failure_count)
