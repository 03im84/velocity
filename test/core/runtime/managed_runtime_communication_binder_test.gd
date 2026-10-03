extends Node


const ManagedRuntimeTestUnitScript = preload(
	"res://test/core/runtime/managed_runtime_test_unit.gd"
)
const ManagedRuntimeTestBusScript = preload(
	"res://test/core/runtime/managed_runtime_test_bus.gd"
)
const RuntimeAdapterTestHelpersScript = preload(
	"res://test/core/runtime/runtime_adapter_test_helpers.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("ManagedRuntimeCommunicationBinderTest")
	print("========================================")

	_test_bind_filter_and_unbind()
	_test_input_validation()
	_test_endpoint_validation()
	_test_bus_rejection()
	_test_contract()

	_finish_test()


func _test_bind_filter_and_unbind() -> void:

	var fixture := _fixture()
	var binder: ManagedRuntimeCommunicationBinder = fixture["binder"]
	var directive: CompositionConnectionDirective = fixture["directive"]
	var source_handle: RuntimeDeviceHandle = fixture["source_handle"]
	var target_handle: RuntimeDeviceHandle = fixture["target_handle"]
	var target_unit: Object = fixture["target_unit"]
	var bus: DeviceBus = fixture["bus"]

	var bind_report := binder.bind(
		directive,
		source_handle,
		target_handle,
		bus
	)

	_expect(
		bind_report.is_valid_for_simulation()
		and binder.has_binding(directive.get_connection_id())
		and binder.get_binding_count() == 1,
		"MRCB-U01: valid Directive creates one binding"
	)
	_expect(
		bus.get_subscriber_count(BusTopics.TEST_MESSAGE) == 1,
		"MRCB-U01: Binder registers one DeviceBus subscription"
	)

	bus.publish(
		BusTopics.TEST_MESSAGE,
		BusMessage.new(
			"other_source",
			BusTopics.TEST_MESSAGE,
			0.0,
			null
		)
	)

	var received_after_wrong_source: Array = target_unit.call(
		&"get_received_messages"
	)

	_expect(
		received_after_wrong_source.is_empty(),
		"MRCB-U01: wrong Source is filtered"
	)

	var matching_message := BusMessage.new(
		"source",
		BusTopics.TEST_MESSAGE,
		1.0,
		RefCounted.new()
	)

	bus.publish(
		BusTopics.TEST_MESSAGE,
		matching_message
	)

	var received_matching: Array = target_unit.call(
		&"get_received_messages"
	)

	_expect(
		received_matching.size() == 1
		and received_matching[0] == matching_message,
		"MRCB-U01: exact Source forwards same BusMessage"
	)

	var duplicate_report := binder.bind(
		directive,
		source_handle,
		target_handle,
		bus
	)

	_expect_code(
		duplicate_report,
		&"managed_runtime_communication_duplicate_binding",
		"MRCB-U01: duplicate bind"
	)
	_expect(
		binder.get_binding_count() == 1
		and bus.get_subscriber_count(
			BusTopics.TEST_MESSAGE
		) == 1,
		"MRCB-U01: duplicate bind creates no second subscription"
	)

	var unbind_report := binder.unbind(
		directive,
		source_handle,
		target_handle,
		bus
	)

	_expect(
		unbind_report.is_valid_for_simulation()
		and binder.get_binding_count() == 0
		and bus.get_subscriber_count(
			BusTopics.TEST_MESSAGE
		) == 0,
		"MRCB-U01: unbind removes exact Subscription"
	)
	_expect(
		binder.unbind(
			directive,
			source_handle,
			target_handle,
			bus
		).is_valid_for_simulation(),
		"MRCB-U01: repeated unknown unbind is valid no-op"
	)


func _test_input_validation() -> void:

	var fixture := _fixture()
	var binder: ManagedRuntimeCommunicationBinder = fixture["binder"]
	var directive: CompositionConnectionDirective = fixture["directive"]
	var source_handle: RuntimeDeviceHandle = fixture["source_handle"]
	var target_handle: RuntimeDeviceHandle = fixture["target_handle"]
	var bus: DeviceBus = fixture["bus"]

	_expect_code(
		binder.bind(null, source_handle, target_handle, bus),
		&"managed_runtime_communication_directive_missing",
		"MRCB-U02: null Directive"
	)
	_expect_code(
		binder.bind(directive, null, target_handle, bus),
		&"managed_runtime_communication_source_handle_missing",
		"MRCB-U02: null Source Handle"
	)
	_expect_code(
		binder.bind(directive, source_handle, null, bus),
		&"managed_runtime_communication_target_handle_missing",
		"MRCB-U02: null Target Handle"
	)
	_expect_code(
		binder.bind(
			directive,
			source_handle,
			target_handle,
			null
		),
		&"managed_runtime_communication_bus_missing",
		"MRCB-U02: null DeviceBus"
	)

	var wrong_source := RuntimeAdapterTestHelpersScript.create_handle(
		"wrong_source",
		ManagedRuntimeTestUnitScript.new("wrong_source")
	)

	_expect_code(
		binder.bind(
			directive,
			wrong_source,
			target_handle,
			bus
		),
		&"managed_runtime_communication_source_mismatch",
		"MRCB-U02: Source identity mismatch"
	)


func _test_endpoint_validation() -> void:

	var source_unit := ManagedRuntimeTestUnitScript.new("source")
	var source_handle := RuntimeAdapterTestHelpersScript.create_handle(
		"source",
		source_unit
	)
	var directive := _directive()
	var binder := ManagedRuntimeCommunicationBinder.new()
	var bus := DeviceBus.new()
	var missing_behavior := RefCounted.new()
	var missing_behavior_handle := (
		RuntimeAdapterTestHelpersScript.create_handle(
			"target",
			missing_behavior
		)
	)

	_expect_code(
		binder.bind(
			directive,
			source_handle,
			missing_behavior_handle,
			bus
		),
		&"managed_runtime_communication_endpoint_behavior_missing",
		"MRCB-U03: missing endpoint behavior"
	)

	var target_unit := ManagedRuntimeTestUnitScript.new("target")
	var target_handle := RuntimeAdapterTestHelpersScript.create_handle(
		"target",
		target_unit
	)

	_expect_code(
		binder.bind(
			directive,
			source_handle,
			target_handle,
			bus
		),
		&"managed_runtime_communication_endpoint_invalid",
		"MRCB-U03: invalid endpoint Callable"
	)


func _test_bus_rejection() -> void:

	var fixture := _fixture()
	var binder: ManagedRuntimeCommunicationBinder = fixture["binder"]
	var directive: CompositionConnectionDirective = fixture["directive"]
	var source_handle: RuntimeDeviceHandle = fixture["source_handle"]
	var target_handle: RuntimeDeviceHandle = fixture["target_handle"]
	var rejecting_bus := ManagedRuntimeTestBusScript.new()

	rejecting_bus.reject_subscribe = true

	_expect_code(
		binder.bind(
			directive,
			source_handle,
			target_handle,
			rejecting_bus
		),
		&"managed_runtime_communication_subscribe_failed",
		"MRCB-U04: DeviceBus subscribe rejection"
	)
	_expect(
		binder.get_binding_count() == 0,
		"MRCB-U04: subscribe rejection stores no binding"
	)

	rejecting_bus.reject_subscribe = false
	var bind_report := binder.bind(
		directive,
		source_handle,
		target_handle,
		rejecting_bus
	)

	_expect(
		bind_report.is_valid_for_simulation(),
		"MRCB-U04: fixture binds before unsubscribe rejection"
	)

	rejecting_bus.reject_unsubscribe = true

	_expect_code(
		binder.unbind(
			directive,
			source_handle,
			target_handle,
			rejecting_bus
		),
		&"managed_runtime_communication_unsubscribe_failed",
		"MRCB-U04: DeviceBus unsubscribe rejection"
	)
	_expect(
		binder.get_binding_count() == 1,
		"MRCB-U04: failed unsubscribe preserves binding state"
	)


func _test_contract() -> void:

	var binder := ManagedRuntimeCommunicationBinder.new()

	_expect(
		not binder.has_method(&"register_endpoint")
		and not binder.has_method(&"get_endpoint")
		and not binder.has_method(&"get_service"),
		"MRCB-U05: Binder has no endpoint Registry or service locator"
	)


func _fixture() -> Dictionary:

	var source_unit := ManagedRuntimeTestUnitScript.new("source")
	var target_unit := ManagedRuntimeTestUnitScript.new("target")

	target_unit.register_endpoint(
		&"in.test_message",
		target_unit.receive_message
	)

	return {
		"binder": ManagedRuntimeCommunicationBinder.new(),
		"directive": _directive(),
		"source_handle": (
			RuntimeAdapterTestHelpersScript.create_handle(
				"source",
				source_unit
			)
		),
		"target_handle": (
			RuntimeAdapterTestHelpersScript.create_handle(
				"target",
				target_unit
			)
		),
		"target_unit": target_unit,
		"bus": DeviceBus.new(),
	}


func _directive() -> CompositionConnectionDirective:

	return CompositionConnectionDirective.new(
		"source",
		&"out.test_message",
		BusTopics.TEST_MESSAGE,
		"target",
		&"in.test_message"
	)


func _expect_code(
	report: ValidationReport,
	code: StringName,
	description: String
) -> void:

	_expect(
		RuntimeAdapterTestHelpersScript.report_has_code(
			report,
			code
		),
		description + " reports " + String(code)
	)


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
