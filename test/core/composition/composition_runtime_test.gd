extends Node


##
## CompositionRuntimeTest
##
## Verifica preflight, one-shot state,
## dependencies, phase barriers,
## activation y shutdown.
##


const RuntimeTestFactoryScript = preload(
	"res://test/core/runtime/runtime_test_factory.gd"
)

const RuntimeTestHostScript = preload(
	"res://test/core/runtime/runtime_test_host.gd"
)

const RuntimeTestObjectScript = preload(
	"res://test/core/runtime/runtime_test_object.gd"
)

const TestResolverScript = preload(
	"res://test/core/composition/runtime_test_dependency_value_resolver.gd"
)

const TestLifecycleScript = preload(
	"res://test/core/composition/runtime_test_lifecycle_adapter.gd"
)

const TestBinderScript = preload(
	"res://test/core/composition/runtime_test_communication_binder.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("CompositionRuntimeTest")
	print("========================================")

	_test_initial_state()
	_test_required_collaborators()
	_test_incomplete_collaborator_contracts()
	_test_plan_validation_and_hardware_gate()
	_test_empty_activation_and_shutdown()
	_test_dependency_preflight_and_ownership()
	_test_phase_barriers_and_reverse_shutdown()
	_test_contract()

	_finish_test()


# =============================================================================
# INITIAL STATE
# =============================================================================

func _test_initial_state() -> void:

	var runtime := _runtime(
		RuntimeFactoryRegistry.new(),
		TestResolverScript.new(),
		RuntimeTestHostScript.new(),
		TestLifecycleScript.new(),
		TestBinderScript.new()
	)

	var runtime_value: Variant = runtime

	_expect(
		runtime.get_state() == CompositionRuntime.State.CREATED,
		"CRT-U01: initial State is CREATED"
	)

	_expect(
		not runtime.is_active(),
		"CRT-U01: initial Runtime is not active"
	)

	_expect(
		runtime.get_active_plan() == null
		and runtime.get_device_bus() == null
		and runtime.get_handles().is_empty()
		and runtime.get_handle(
			"missing"
		) == null,
		"CRT-U01: initial active state is empty"
	)

	_expect(
		runtime.get_last_dispatch_report() == null,
		"CRT-U01: initial Dispatch Report is unavailable"
	)

	_expect(
		runtime_value is RefCounted
		and not (runtime_value is Node),
		"CRT-U01: Runtime is RefCounted and not Node"
	)


# =============================================================================
# REQUIRED COLLABORATORS
# =============================================================================

func _test_required_collaborators() -> void:

	var registry := RuntimeFactoryRegistry.new()
	var resolver := TestResolverScript.new()
	var host := RuntimeTestHostScript.new()
	var lifecycle := TestLifecycleScript.new()
	var binder := TestBinderScript.new()
	var plan := _empty_plan(
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	_expect_activation_failure(
		_runtime(
			null,
			resolver,
			host,
			lifecycle,
			binder
		),
		plan,
		&"composition_runtime_registry_missing",
		"CRT-U02: null Registry"
	)

	_expect_activation_failure(
		_runtime(
			registry,
			null,
			host,
			lifecycle,
			binder
		),
		plan,
		&"composition_runtime_dependency_resolver_missing",
		"CRT-U02: null Dependency Resolver"
	)

	_expect_activation_failure(
		_runtime(
			registry,
			resolver,
			null,
			lifecycle,
			binder
		),
		plan,
		&"composition_runtime_host_missing",
		"CRT-U02: null RuntimeHost"
	)

	_expect_activation_failure(
		_runtime(
			registry,
			resolver,
			host,
			null,
			binder
		),
		plan,
		&"composition_runtime_lifecycle_adapter_missing",
		"CRT-U02: null Lifecycle Adapter"
	)

	_expect_activation_failure(
		_runtime(
			registry,
			resolver,
			host,
			lifecycle,
			null
		),
		plan,
		&"composition_runtime_communication_binder_missing",
		"CRT-U02: null Communication Binder"
	)


# =============================================================================
# INCOMPLETE CONTRACTS
# =============================================================================

func _test_incomplete_collaborator_contracts() -> void:

	var runtime := _runtime(
		RuntimeFactoryRegistry.new(),
		RefCounted.new(),
		RefCounted.new(),
		RefCounted.new(),
		RefCounted.new()
	)

	var result := runtime.activate(
		_empty_plan(
			DeviceConfiguration.ActivationContext.SIMULATION
		)
	)

	_expect(
		not result.is_success()
		and runtime.get_state() == CompositionRuntime.State.FAILED,
		"CRT-U03: incomplete collaborator contracts fail activation"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"composition_runtime_dependency_resolver_contract_invalid"
		)
		and _report_has_code(
			result.get_report(),
			&"composition_runtime_host_contract_invalid"
		)
		and _report_has_code(
			result.get_report(),
			&"composition_runtime_lifecycle_adapter_contract_invalid"
		)
		and _report_has_code(
			result.get_report(),
			&"composition_runtime_communication_binder_contract_invalid"
		),
		"CRT-U03: all incomplete contracts are reported"
	)

	_expect(
		runtime.get_device_bus() == null
		and runtime.get_handles().is_empty(),
		"CRT-U03: contract failure acquires no active resources"
	)


# =============================================================================
# PLAN AND HARDWARE
# =============================================================================

func _test_plan_validation_and_hardware_gate() -> void:

	var valid_runtime := _runtime_with_empty_registry()

	_expect_activation_failure(
		valid_runtime,
		null,
		&"composition_runtime_plan_missing",
		"CRT-U04: null Plan"
	)

	var invalid_entries: Array[CompositionDeviceEntry] = [
		null,
	]

	var directives: Array[CompositionConnectionDirective] = []

	var invalid_plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		invalid_entries,
		directives,
		DeviceBusDispatchPolicy.new()
	)

	_expect_activation_failure(
		_runtime_with_empty_registry(),
		invalid_plan,
		&"composition_runtime_plan_invalid",
		"CRT-U04: invalid Plan"
	)

	var hardware_runtime := _runtime_with_empty_registry()

	var hardware_result := hardware_runtime.activate(
		_empty_plan(
			DeviceConfiguration.ActivationContext.HARDWARE
		)
	)

	_expect(
		not hardware_result.is_success()
		and hardware_runtime.get_state()
		== CompositionRuntime.State.FAILED,
		"CRT-U04: Hardware activation is rejected"
	)

	_expect(
		_report_has_severity(
			hardware_result.get_report(),
			&"composition_runtime_hardware_not_supported",
			ValidationIssue.Severity.HARDWARE_SAFETY_ERROR
		),
		"CRT-U04: Hardware gate uses Hardware Safety Error"
	)

	_expect(
		hardware_runtime.get_device_bus() == null,
		"CRT-U04: Hardware gate creates no active Bus"
	)


# =============================================================================
# EMPTY ACTIVATION
# =============================================================================

func _test_empty_activation_and_shutdown() -> void:

	var runtime := _runtime_with_empty_registry()
	var plan := _empty_plan(
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var activation_result := runtime.activate(
		plan
	)

	_expect(
		activation_result.is_success(),
		"CRT-U05: empty Plan activation succeeds"
	)

	_expect(
		runtime.get_state() == CompositionRuntime.State.ACTIVE
		and runtime.is_active(),
		"CRT-U05: successful activation commits ACTIVE"
	)

	_expect(
		runtime.get_active_plan() == plan
		and runtime.get_device_bus() != null,
		"CRT-U05: active Plan and owned Bus are exposed"
	)

	_expect(
		runtime.get_device_bus().get_dispatch_policy()
		== plan.get_dispatch_policy()
		and runtime.get_handles().is_empty(),
		"CRT-U05: empty Runtime preserves Policy and zero Handles"
	)

	_expect(
		runtime.get_last_dispatch_report() != null,
		"CRT-U05: active Bus exposes Dispatch Report"
	)

	var duplicate_activation := runtime.activate(
		plan
	)

	_expect(
		not duplicate_activation.is_success()
		and runtime.get_state() == CompositionRuntime.State.ACTIVE,
		"CRT-U05: duplicate activation is rejected without losing ACTIVE"
	)

	var shutdown_result := runtime.shutdown()

	_expect(
		shutdown_result.is_success(),
		"CRT-U05: empty Runtime shutdown succeeds"
	)

	_expect(
		runtime.get_state() == CompositionRuntime.State.SHUTDOWN
		and not runtime.is_active(),
		"CRT-U05: shutdown commits SHUTDOWN"
	)

	_expect(
		runtime.get_active_plan() == null
		and runtime.get_device_bus() == null
		and runtime.get_handles().is_empty(),
		"CRT-U05: shutdown clears active references"
	)

	var repeated_shutdown := runtime.shutdown()

	_expect(
		not repeated_shutdown.is_success()
		and runtime.get_state() == CompositionRuntime.State.SHUTDOWN,
		"CRT-U05: repeated shutdown is rejected"
	)


# =============================================================================
# DEPENDENCY PREFLIGHT AND OWNERSHIP
# =============================================================================

func _test_dependency_preflight_and_ownership() -> void:

	var factory := RuntimeTestFactoryScript.new()
	var spec := RuntimeDependencySpec.new(
		&"private_dependency",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var specs: Array[RuntimeDependencySpec] = [
		spec,
	]

	var entry := _entry(
		"dependency_device",
		&"test.runtime.dependency",
		1,
		specs
	)

	var entries: Array[CompositionDeviceEntry] = [
		entry,
	]

	var plan := _plan(entries)
	var registry := _registry_for_entries(
		entries,
		factory
	)

	var missing_runtime := _runtime(
		registry,
		TestResolverScript.new(),
		RuntimeTestHostScript.new(),
		TestLifecycleScript.new(),
		TestBinderScript.new()
	)

	var missing_result := missing_runtime.activate(
		plan
	)

	_expect(
		not missing_result.is_success()
		and _report_has_code(
			missing_result.get_report(),
			&"composition_runtime_dependency_missing"
		),
		"CRT-U06: missing Dependency Value blocks activation"
	)

	_expect(
		factory.get_build_count() == 0
		and missing_runtime.get_device_bus() == null,
		"CRT-U06: dependency preflight fails before acquisition"
	)

	var resolver := TestResolverScript.new()
	var dependency := RuntimeTestObjectScript.new()

	resolver.register_value(
		"dependency_device",
		&"private_dependency",
		dependency
	)

	var runtime := _runtime(
		registry,
		resolver,
		RuntimeTestHostScript.new(),
		TestLifecycleScript.new(),
		TestBinderScript.new()
	)

	var activation_result := runtime.activate(
		plan
	)

	_expect(
		activation_result.is_success(),
		"CRT-U06: resolved Dependency activates Runtime"
	)

	var handle := runtime.get_handle(
		"dependency_device"
	)

	var binding := handle.get_dependency_binding(
		&"private_dependency"
	)

	_expect(
		binding != null
		and binding.get_value() == dependency
		and binding.is_transferred(),
		"CRT-U06: Binding uses resolved Value and Spec Ownership"
	)

	var expected_queries: Array[String] = [
		"dependency_device:has:private_dependency",
		"dependency_device:get:private_dependency",
	]

	_expect(
		resolver.get_query_order() == expected_queries,
		"CRT-U06: Resolver is queried only for declared Spec"
	)

	_expect(
		runtime.shutdown().is_success()
		and dependency.is_released(),
		"CRT-U06: shutdown releases transferred Dependency"
	)


# =============================================================================
# PHASE BARRIERS AND SHUTDOWN ORDER
# =============================================================================

func _test_phase_barriers_and_reverse_shutdown() -> void:

	var factory := RuntimeTestFactoryScript.new()
	var empty_specs: Array[RuntimeDependencySpec] = []

	var entry_a := _entry(
		"device_a",
		&"test.runtime.shared",
		1,
		empty_specs
	)

	var entry_b := _entry(
		"device_b",
		&"test.runtime.shared",
		1,
		empty_specs
	)

	var entries: Array[CompositionDeviceEntry] = [
		entry_a,
		entry_b,
	]

	var host := RuntimeTestHostScript.new()
	var lifecycle := TestLifecycleScript.new()

	var runtime := _runtime(
		_registry_for_entries(
			entries,
			factory
		),
		TestResolverScript.new(),
		host,
		lifecycle,
		TestBinderScript.new()
	)

	var activation_result := runtime.activate(
		_plan(entries)
	)

	_expect(
		activation_result.is_success(),
		"CRT-U07: two-Device activation succeeds"
	)

	_expect(
		runtime.get_handles().size() == 2
		and runtime.get_handles()[0].get_device_id()
		== "device_a"
		and runtime.get_handles()[1].get_device_id()
		== "device_b"
		and factory.get_build_count() == 2,
		"CRT-U07: build order follows Plan Entries"
	)

	var expected_attach: Array[String] = [
		"device_a",
		"device_b",
	]

	_expect(
		host.get_attach_order() == expected_attach,
		"CRT-U07: attach phase completes in forward order"
	)

	var expected_lifecycle: Array[String] = [
		"initialize:device_a",
		"initialize:device_b",
		"ready:device_a",
		"ready:device_b",
		"start:device_a",
		"start:device_b",
	]

	_expect(
		lifecycle.get_event_order() == expected_lifecycle,
		"CRT-U07: lifecycle uses phase barriers"
	)

	var handles_copy := runtime.get_handles()

	handles_copy.clear()

	_expect(
		runtime.get_handles().size() == 2
		and runtime.get_handle(
			"device_a"
		) != null
		and runtime.get_handle(
			"missing"
		) == null,
		"CRT-U07: Handle queries are protected and exact"
	)

	var duplicate_result := runtime.activate(
		_plan(entries)
	)

	_expect(
		not duplicate_result.is_success()
		and runtime.is_active(),
		"CRT-U07: active one-shot Runtime rejects replacement"
	)

	var shutdown_result := runtime.shutdown()

	_expect(
		shutdown_result.is_success(),
		"CRT-U07: active Runtime shutdown succeeds"
	)

	var expected_lifecycle_after_shutdown: Array[String] = [
		"initialize:device_a",
		"initialize:device_b",
		"ready:device_a",
		"ready:device_b",
		"start:device_a",
		"start:device_b",
		"shutdown:device_b",
		"shutdown:device_a",
	]

	_expect(
		lifecycle.get_event_order()
		== expected_lifecycle_after_shutdown,
		"CRT-U07: lifecycle shutdown uses reverse order"
	)

	var expected_reverse: Array[String] = [
		"device_b",
		"device_a",
	]

	_expect(
		host.get_detach_order() == expected_reverse
		and factory.get_release_order() == expected_reverse,
		"CRT-U07: detach and release use reverse order"
	)

	_expect(
		runtime.get_state() == CompositionRuntime.State.SHUTDOWN
		and runtime.get_device_bus() == null
		and runtime.get_handles().is_empty(),
		"CRT-U07: shutdown clears owned runtime state"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var runtime := _runtime_with_empty_registry()

	_expect(
		not runtime.has_method(
			&"set_plan"
		)
		and not runtime.has_method(
			&"set_registry"
		)
		and not runtime.has_method(
			&"set_device_bus"
		)
		and not runtime.has_method(
			&"set_handles"
		),
		"CRT-U08: Runtime exposes no state setters"
	)

	_expect(
		not runtime.has_method(
			&"replace"
		)
		and not runtime.has_method(
			&"restart"
		)
		and not runtime.has_method(
			&"hot_swap"
		),
		"CRT-U08: Runtime 1.0 exposes no hot swap"
	)

	_expect(
		not runtime.has_method(
			&"get_service"
		)
		and not runtime.has_method(
			&"load"
		)
		and not runtime.has_method(
			&"save"
		),
		"CRT-U08: Runtime has no service locator or persistence"
	)

	_expect(
		not runtime.has_method(
			&"activate_hardware"
		),
		"CRT-U08: Runtime 1.0 exposes no Hardware activation"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _runtime_with_empty_registry(
) -> CompositionRuntime:

	return _runtime(
		RuntimeFactoryRegistry.new(),
		TestResolverScript.new(),
		RuntimeTestHostScript.new(),
		TestLifecycleScript.new(),
		TestBinderScript.new()
	)


func _runtime(
	registry: RuntimeFactoryRegistry,
	resolver: Object,
	host: Object,
	lifecycle: Object,
	binder: Object
) -> CompositionRuntime:

	return CompositionRuntime.new(
		registry,
		resolver,
		host,
		lifecycle,
		binder
	)


func _empty_plan(
	activation_context: int
) -> CompositionPlan:

	var entries: Array[CompositionDeviceEntry] = []
	var directives: Array[CompositionConnectionDirective] = []

	return CompositionPlan.new(
		activation_context,
		entries,
		directives,
		DeviceBusDispatchPolicy.new()
	)


func _plan(
	entries: Array[CompositionDeviceEntry]
) -> CompositionPlan:

	var directives: Array[CompositionConnectionDirective] = []

	return CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		DeviceBusDispatchPolicy.new()
	)


func _entry(
	device_id: String,
	profile_id: StringName,
	profile_version: int,
	dependency_specs: Array[RuntimeDependencySpec]
) -> CompositionDeviceEntry:

	var capabilities: Array[String] = [
		"composition_runtime",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	var configuration := DeviceConfiguration.new(
		StringName(
			"test.runtime." + device_id
		),
		1,
		device_id,
		profile_id,
		profile_version,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)

	var factory_key := RuntimeFactoryKey.new(
		profile_id,
		profile_version,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	return CompositionDeviceEntry.new(
		device_id,
		configuration,
		factory_key,
		dependency_specs
	)


func _registry_for_entries(
	entries: Array[CompositionDeviceEntry],
	factory: Object
) -> RuntimeFactoryRegistry:

	var draft := RuntimeFactoryRegistryDraft.new()
	var seen_keys: Array[RuntimeFactoryKey] = []

	for entry: CompositionDeviceEntry in entries:

		var key := entry.get_factory_key()
		var already_registered: bool = false

		for existing_key: RuntimeFactoryKey in seen_keys:
			if existing_key.equals(key):
				already_registered = true
				break

		if already_registered:
			continue

		draft.descriptors.append(
			RuntimeFactoryDescriptor.new(
				key,
				factory,
				entry.get_dependency_specs()
			)
		)

		seen_keys.append(key)

	var result := RuntimeFactoryRegistryCompiler.new().compile(
		draft
	)

	return result.get_registry()


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


func _expect_activation_failure(
	runtime: CompositionRuntime,
	plan: CompositionPlan,
	code: StringName,
	description: String
) -> void:

	var result := runtime.activate(
		plan
	)

	_expect(
		not result.is_success(),
		description + " is rejected"
	)

	_expect(
		runtime.get_state() == CompositionRuntime.State.FAILED,
		description + " leaves FAILED state"
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
