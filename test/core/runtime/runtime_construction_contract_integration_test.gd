extends Node


##
## RuntimeConstructionContractIntegrationTest
##
## Verifica factory build, ownership,
## RuntimeHost y rollback controlado.
##


const RuntimeTestObjectScript = preload(
	"res://test/core/runtime/runtime_test_object.gd"
)

const RuntimeTestFactoryScript = preload(
	"res://test/core/runtime/runtime_test_factory.gd"
)

const RuntimeTestHostScript = preload(
	"res://test/core/runtime/runtime_test_host.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeConstructionContractIntegrationTest")
	print("========================================")

	_test_successful_build()
	_test_host_attach_and_detach()
	_test_factory_release_ownership()
	_test_failed_build_cleanup()
	_test_host_partial_rollback()
	_test_reverse_global_rollback()
	_test_behavior_contracts()

	_finish_test()


# =============================================================================
# SUCCESSFUL BUILD
# =============================================================================

func _test_successful_build() -> void:

	var borrowed_dependency := RuntimeTestObjectScript.new()
	var transferred_dependency := RuntimeTestObjectScript.new()

	var request := _request_with_dependencies(
		"successful_device",
		borrowed_dependency,
		transferred_dependency
	)

	var factory := RuntimeTestFactoryScript.new()

	var result := factory.build(
		request
	)

	var handle := result.get_handle()

	_expect(
		request.is_valid(),
		"RCCI-I01: construction Request is valid"
	)

	_expect(
		result.is_success()
		and handle != null,
		"RCCI-I01: factory build produces valid Handle"
	)

	if handle == null:
		return

	_expect(
		result.get_report().get_issues().is_empty()
		and factory.get_build_count() == 1,
		"RCCI-I01: successful build has no Issues"
	)

	_expect(
		handle.get_device_id() == "successful_device"
		and handle.get_configuration()
		== request.get_configuration()
		and handle.get_factory_key()
		== request.get_factory_key(),
		"RCCI-I01: Handle preserves Request identity"
	)

	_expect(
		handle.get_dependency_bindings().size() == 2
		and handle.get_dependency_binding(
			&"runtime_clock"
		).get_value() == borrowed_dependency
		and handle.get_dependency_binding(
			&"distance_provider"
		).get_value() == transferred_dependency,
		"RCCI-I01: Handle preserves dependency bindings"
	)

	var primary: Variant = (
		handle.get_primary_runtime_object()
	)

	var host_object: Variant = (
		handle.get_host_objects()[0]
	)

	_expect(
		primary.get_attach_count() == 0
		and host_object.get_attach_count() == 0
		and not primary.is_released()
		and not host_object.is_released()
		and not borrowed_dependency.is_released()
		and not transferred_dependency.is_released(),
		"RCCI-I01: build has no attach or premature cleanup"
	)


# =============================================================================
# HOST ATTACH AND DETACH
# =============================================================================

func _test_host_attach_and_detach() -> void:

	var factory := RuntimeTestFactoryScript.new()

	var build_result := factory.build(
		_request(
			"host_device"
		)
	)

	var handle := build_result.get_handle()
	var host := RuntimeTestHostScript.new()

	if handle == null:

		_expect(
			false,
			"RCCI-I02: Host fixture Handle is created"
		)

		return

	var host_object: Variant = (
		handle.get_host_objects()[0]
	)

	var attach_report := host.attach(
		handle
	)

	_expect(
		attach_report.is_valid_for_simulation(),
		"RCCI-I02: RuntimeHost attach succeeds"
	)

	_expect(
		host.is_handle_attached(handle)
		and host.get_attached_handle_count() == 1
		and host.get_attach_order() == ["host_device"],
		"RCCI-I02: RuntimeHost records attached Handle"
	)

	_expect(
		host_object.get_attach_count() == 1
		and host_object.get_detach_count() == 0
		and host_object.is_attached(),
		"RCCI-I02: Host Object is attached once"
	)

	var repeated_attach_report := host.attach(
		handle
	)

	_expect(
		repeated_attach_report.is_valid_for_simulation()
		and host_object.get_attach_count() == 1
		and host.get_attached_handle_count() == 1,
		"RCCI-I02: repeated attach is idempotent"
	)

	var detach_report := host.detach(
		handle
	)

	_expect(
		detach_report.is_valid_for_simulation(),
		"RCCI-I02: RuntimeHost detach succeeds"
	)

	_expect(
		not host.is_handle_attached(handle)
		and host.get_attached_handle_count() == 0
		and host.get_detach_order() == ["host_device"]
		and host_object.get_detach_count() == 1
		and not host_object.is_attached(),
		"RCCI-I02: RuntimeHost detaches and records order"
	)

	var repeated_detach_report := host.detach(
		handle
	)

	_expect(
		repeated_detach_report.is_valid_for_simulation()
		and host_object.get_detach_count() == 1,
		"RCCI-I02: repeated detach is idempotent"
	)


# =============================================================================
# FACTORY RELEASE OWNERSHIP
# =============================================================================

func _test_factory_release_ownership() -> void:

	var borrowed_dependency := RuntimeTestObjectScript.new()
	var transferred_dependency := RuntimeTestObjectScript.new()

	var factory := RuntimeTestFactoryScript.new()

	var build_result := factory.build(
		_request_with_dependencies(
			"release_device",
			borrowed_dependency,
			transferred_dependency
		)
	)

	var handle := build_result.get_handle()

	_expect(
		build_result.is_success()
		and handle != null,
		"RCCI-I03: release fixture builds successfully"
	)

	if handle == null:
		return

	var primary: Variant = (
		handle.get_primary_runtime_object()
	)

	var host_object: Variant = (
		handle.get_host_objects()[0]
	)

	var release_report := factory.release(
		handle
	)

	_expect(
		release_report.is_valid_for_simulation(),
		"RCCI-I03: factory release succeeds"
	)

	_expect(
		primary.get_release_count() == 1
		and host_object.get_release_count() == 1
		and transferred_dependency.get_release_count() == 1,
		"RCCI-I03: owned and TRANSFERRED resources are released"
	)

	_expect(
		borrowed_dependency.get_release_count() == 0,
		"RCCI-I03: BORROWED dependency is preserved"
	)

	_expect(
		factory.get_release_count() == 1
		and factory.get_release_order() == ["release_device"],
		"RCCI-I03: factory records one release"
	)

	var repeated_release_report := factory.release(
		handle
	)

	_expect(
		repeated_release_report.is_valid_for_simulation()
		and factory.get_release_count() == 1
		and primary.get_release_count() == 1
		and host_object.get_release_count() == 1
		and transferred_dependency.get_release_count() == 1,
		"RCCI-I03: repeated release performs no double cleanup"
	)


# =============================================================================
# FAILED BUILD CLEANUP
# =============================================================================

func _test_failed_build_cleanup() -> void:

	var borrowed_dependency := RuntimeTestObjectScript.new()
	var transferred_dependency := RuntimeTestObjectScript.new()

	var factory := RuntimeTestFactoryScript.new()

	factory.set_fail_next_build(
		true
	)

	var result := factory.build(
		_request_with_dependencies(
			"failed_device",
			borrowed_dependency,
			transferred_dependency
		)
	)

	_expect(
		not result.is_success()
		and result.get_handle() == null,
		"RCCI-I04: controlled build failure produces null Handle"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"test_factory_build_failed"
		),
		"RCCI-I04: controlled failure is reported"
	)

	_expect(
		transferred_dependency.get_release_count() == 1,
		"RCCI-I04: failed build cleans TRANSFERRED dependency"
	)

	_expect(
		borrowed_dependency.get_release_count() == 0,
		"RCCI-I04: failed build preserves BORROWED dependency"
	)

	_expect(
		factory.get_build_count() == 1
		and factory.get_last_primary_object() == null
		and factory.get_last_host_objects().is_empty(),
		"RCCI-I04: failed build exposes no partial runtime objects"
	)


# =============================================================================
# HOST PARTIAL ROLLBACK
# =============================================================================

func _test_host_partial_rollback() -> void:

	var primary := RuntimeTestObjectScript.new()
	var first_host_object := RuntimeTestObjectScript.new()
	var second_host_object := RuntimeTestObjectScript.new()

	var host_objects: Array[Object] = [
		first_host_object,
		second_host_object,
	]

	var request := _request(
		"partial_attach_device"
	)

	var handle := RuntimeDeviceHandle.new(
		request.get_device_id(),
		request.get_configuration(),
		request.get_factory_key(),
		primary,
		host_objects,
		request.get_dependency_bindings()
	)

	var host := RuntimeTestHostScript.new()

	host.set_fail_after_host_count(
		1
	)

	var report := host.attach(
		handle
	)

	_expect(
		handle.is_valid(),
		"RCCI-I05: partial rollback Handle is valid"
	)

	_expect(
		not report.is_valid_for_simulation()
		and _report_has_code(
			report,
			&"test_host_attach_failed"
		),
		"RCCI-I05: controlled attach failure is reported"
	)

	_expect(
		not host.is_handle_attached(handle)
		and host.get_attached_handle_count() == 0
		and host.get_attach_order().is_empty(),
		"RCCI-I05: failed attach does not commit Handle"
	)

	_expect(
		first_host_object.get_attach_count() == 1
		and first_host_object.get_detach_count() == 1
		and not first_host_object.is_attached(),
		"RCCI-I05: first Host Object is rolled back"
	)

	_expect(
		second_host_object.get_attach_count() == 0
		and second_host_object.get_detach_count() == 0,
		"RCCI-I05: later Host Object remains untouched"
	)

	_expect(
		primary.get_release_count() == 0
		and first_host_object.get_release_count() == 0
		and second_host_object.get_release_count() == 0,
		"RCCI-I05: RuntimeHost does not perform factory release"
	)


# =============================================================================
# REVERSE GLOBAL ROLLBACK
# =============================================================================

func _test_reverse_global_rollback() -> void:

	var factory := RuntimeTestFactoryScript.new()
	var host := RuntimeTestHostScript.new()
	var handles: Array[RuntimeDeviceHandle] = []

	var device_ids: Array[String] = [
		"rollback_a",
		"rollback_b",
		"rollback_c",
	]

	var build_and_attach_succeeded: bool = true

	for device_id: String in device_ids:

		var build_result := factory.build(
			_request(device_id)
		)

		var handle := build_result.get_handle()

		if (
			not build_result.is_success()
			or handle == null
		):

			build_and_attach_succeeded = false
			continue

		handles.append(
			handle
		)

		var attach_report := host.attach(
			handle
		)

		if not attach_report.is_valid_for_simulation():
			build_and_attach_succeeded = false

	_expect(
		build_and_attach_succeeded
		and handles.size() == 3,
		"RCCI-I06: three Handles build and attach"
	)

	var expected_attach_order: Array[String] = [
		"rollback_a",
		"rollback_b",
		"rollback_c",
	]

	_expect(
		host.get_attach_order()
		== expected_attach_order,
		"RCCI-I06: Handles attach in acquisition order"
	)

	factory.set_fail_next_build(
		true
	)

	var failed_result := factory.build(
		_request(
			"rollback_d"
		)
	)

	_expect(
		not failed_result.is_success()
		and _report_has_code(
			failed_result.get_report(),
			&"test_factory_build_failed"
		),
		"RCCI-I06: later factory failure triggers rollback condition"
	)

	var rollback_reports_valid: bool = true

	for handle_index: int in range(
		handles.size() - 1,
		-1,
		-1
	):

		var handle: RuntimeDeviceHandle = handles[
			handle_index
		]

		var detach_report := host.detach(
			handle
		)

		var release_report := factory.release(
			handle
		)

		if (
			not detach_report.is_valid_for_simulation()
			or not release_report.is_valid_for_simulation()
		):

			rollback_reports_valid = false

	_expect(
		rollback_reports_valid,
		"RCCI-I06: reverse rollback reports remain valid"
	)

	var expected_reverse_order: Array[String] = [
		"rollback_c",
		"rollback_b",
		"rollback_a",
	]

	_expect(
		host.get_detach_order()
		== expected_reverse_order
		and factory.get_release_order()
		== expected_reverse_order,
		"RCCI-I06: detach and release use reverse order"
	)

	_expect(
		host.get_attached_handle_count() == 0
		and factory.get_release_count() == 3
		and factory.get_build_count() == 4,
		"RCCI-I06: rollback leaves no attached Handles"
	)

	var all_runtime_objects_released: bool = true

	for handle: RuntimeDeviceHandle in handles:

		var primary: Variant = (
			handle.get_primary_runtime_object()
		)

		var host_object: Variant = (
			handle.get_host_objects()[0]
		)

		if (
			primary.get_release_count() != 1
			or host_object.get_release_count() != 1
		):

			all_runtime_objects_released = false

	_expect(
		all_runtime_objects_released,
		"RCCI-I06: rollback releases all constructed runtime objects"
	)


# =============================================================================
# BEHAVIOR CONTRACTS
# =============================================================================

func _test_behavior_contracts() -> void:

	var factory := RuntimeTestFactoryScript.new()
	var host := RuntimeTestHostScript.new()

	_expect(
		factory.has_method(
			&"build"
		)
		and factory.has_method(
			&"release"
		),
		"RCCI-I07: Test Factory exposes build and release"
	)

	_expect(
		not factory.has_method(
			&"initialize"
		)
		and not factory.has_method(
			&"start"
		)
		and not factory.has_method(
			&"attach"
		),
		"RCCI-I07: Factory does not own lifecycle or host attach"
	)

	_expect(
		host.has_method(
			&"attach"
		)
		and host.has_method(
			&"detach"
		),
		"RCCI-I07: Test Host exposes attach and detach"
	)

	_expect(
		not host.has_method(
			&"build"
		)
		and not host.has_method(
			&"release"
		)
		and not host.has_method(
			&"create_device"
		),
		"RCCI-I07: RuntimeHost has no factory behavior"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _request(
	device_id: String
) -> RuntimeConstructionRequest:

	var bindings: Array[RuntimeDependencyBinding] = []

	return RuntimeConstructionRequest.new(
		device_id,
		_configuration(device_id),
		_factory_key(),
		bindings
	)


func _request_with_dependencies(
	device_id: String,
	borrowed_dependency: Object,
	transferred_dependency: Object
) -> RuntimeConstructionRequest:

	var bindings: Array[RuntimeDependencyBinding] = [
		RuntimeDependencyBinding.new(
			&"runtime_clock",
			borrowed_dependency,
			RuntimeDependencyBinding.Ownership.BORROWED
		),
		RuntimeDependencyBinding.new(
			&"distance_provider",
			transferred_dependency,
			RuntimeDependencyBinding.Ownership.TRANSFERRED
		),
	]

	return RuntimeConstructionRequest.new(
		device_id,
		_configuration(device_id),
		_factory_key(),
		bindings
	)


func _factory_key() -> RuntimeFactoryKey:

	return RuntimeFactoryKey.new(
		&"test.runtime.integration",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)


func _configuration(
	device_id: String
) -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"runtime_integration",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	var configuration_id := StringName(
		"test."
		+ device_id
		+ ".configuration"
	)

	return DeviceConfiguration.new(
		configuration_id,
		1,
		device_id,
		&"test.runtime.integration",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


# =============================================================================
# REPORT HELPERS
# =============================================================================

func _report_has_code(
	report: ValidationReport,
	code: StringName
) -> bool:

	for issue: ValidationIssue in report.get_issues():

		if issue.get_code() == code:
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
