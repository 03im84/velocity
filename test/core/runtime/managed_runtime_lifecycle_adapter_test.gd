extends Node


const ManagedRuntimeTestUnitScript = preload(
	"res://test/core/runtime/managed_runtime_test_unit.gd"
)
const RuntimeAdapterTestHelpersScript = preload(
	"res://test/core/runtime/runtime_adapter_test_helpers.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("ManagedRuntimeLifecycleAdapterTest")
	print("========================================")

	_test_exact_delegation()
	_test_input_validation()
	_test_missing_behavior()
	_test_invalid_report()
	_test_blocking_report_and_partial_shutdown()
	_test_contract()

	_finish_test()


func _test_exact_delegation() -> void:

	var unit := ManagedRuntimeTestUnitScript.new("device_a")
	var handle := RuntimeAdapterTestHelpersScript.create_handle(
		"device_a",
		unit
	)
	var adapter := ManagedRuntimeLifecycleAdapter.new()
	var bus := DeviceBus.new()

	var initialize_report := adapter.initialize(handle, bus)

	_expect(
		initialize_report == unit.get_last_report()
		and initialize_report.is_valid_for_simulation(),
		"MRLA-U01: initialize delegates and returns same Report"
	)
	_expect(
		adapter.set_ready(handle) == unit.get_last_report(),
		"MRLA-U01: set_ready delegates and returns same Report"
	)
	_expect(
		adapter.start(handle) == unit.get_last_report(),
		"MRLA-U01: start delegates and returns same Report"
	)
	_expect(
		adapter.shutdown(handle) == unit.get_last_report(),
		"MRLA-U01: shutdown delegates and returns same Report"
	)

	var expected_events: Array[String] = [
		"initialize:device_a",
		"ready:device_a",
		"start:device_a",
		"shutdown:device_a",
	]

	_expect(
		unit.get_events() == expected_events,
		"MRLA-U01: lifecycle order reaches managed Primary"
	)


func _test_input_validation() -> void:

	var adapter := ManagedRuntimeLifecycleAdapter.new()
	var bus := DeviceBus.new()
	var unit := ManagedRuntimeTestUnitScript.new("device_a")
	var handle := RuntimeAdapterTestHelpersScript.create_handle(
		"device_a",
		unit
	)

	_expect_code(
		adapter.start(null),
		&"managed_runtime_lifecycle_handle_missing",
		"MRLA-U02: null Handle"
	)
	_expect_code(
		adapter.initialize(handle, null),
		&"managed_runtime_lifecycle_bus_missing",
		"MRLA-U02: null DeviceBus"
	)

	var missing_primary := RuntimeAdapterTestHelpersScript.create_handle(
		"device_a",
		null
	)

	_expect_code(
		adapter.start(missing_primary),
		&"managed_runtime_lifecycle_primary_missing",
		"MRLA-U02: null Primary"
	)

	var invalid_host_objects: Array[Object] = []
	var invalid_bindings: Array[RuntimeDependencyBinding] = []
	var invalid_handle := RuntimeDeviceHandle.new(
		"device_a",
		null,
		RuntimeFactoryKey.new(
			&"test.managed.runtime",
			1,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		unit,
		invalid_host_objects,
		invalid_bindings
	)

	_expect_code(
		adapter.initialize(invalid_handle, bus),
		&"managed_runtime_lifecycle_handle_invalid",
		"MRLA-U02: invalid Handle"
	)


func _test_missing_behavior() -> void:

	var primary := RefCounted.new()
	var handle := RuntimeAdapterTestHelpersScript.create_handle(
		"device_a",
		primary
	)
	var adapter := ManagedRuntimeLifecycleAdapter.new()

	_expect_code(
		adapter.start(handle),
		&"managed_runtime_lifecycle_behavior_missing",
		"MRLA-U03: missing phase behavior"
	)


func _test_invalid_report() -> void:

	var unit := ManagedRuntimeTestUnitScript.new("device_a")
	unit.set_invalid_report_phase(&"ready")
	var handle := RuntimeAdapterTestHelpersScript.create_handle(
		"device_a",
		unit
	)
	var adapter := ManagedRuntimeLifecycleAdapter.new()
	var report := adapter.set_ready(handle)

	_expect_code(
		report,
		&"managed_runtime_lifecycle_report_missing",
		"MRLA-U04: invalid behavior return"
	)
	_expect(
		report.has_severity(
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR
		),
		"MRLA-U04: invalid return is Platform Safety Error"
	)


func _test_blocking_report_and_partial_shutdown() -> void:

	var unit := ManagedRuntimeTestUnitScript.new("device_a")
	unit.set_failure(&"initialize")
	var handle := RuntimeAdapterTestHelpersScript.create_handle(
		"device_a",
		unit
	)
	var adapter := ManagedRuntimeLifecycleAdapter.new()
	var initialize_report := adapter.initialize(
		handle,
		DeviceBus.new()
	)

	_expect(
		not initialize_report.is_valid_for_simulation()
		and RuntimeAdapterTestHelpersScript.report_has_code(
			initialize_report,
			&"managed_runtime_test_phase_failed"
		),
		"MRLA-U05: managed blocking Report is preserved"
	)

	var shutdown_report := adapter.shutdown(handle)
	var expected_events: Array[String] = [
		"initialize:device_a",
		"shutdown:device_a",
	]

	_expect(
		shutdown_report.is_valid_for_simulation()
		and unit.get_events() == expected_events,
		"MRLA-U05: shutdown follows partial initialize safely"
	)


func _test_contract() -> void:

	var adapter := ManagedRuntimeLifecycleAdapter.new()

	_expect(
		not adapter.has_method(&"register_adapter")
		and not adapter.has_method(&"get_adapter")
		and not adapter.has_method(&"get_service"),
		"MRLA-U06: Adapter has no Registry or service locator API"
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
