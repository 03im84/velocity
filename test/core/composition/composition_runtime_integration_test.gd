extends Node


##
## CompositionRuntimeIntegrationTest
##
## Verifies transactional phase barriers,
## reverse rollback, cleanup error aggregation
## and no double cleanup across collaborators.
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


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("CompositionRuntimeIntegrationTest")
	print("========================================")

	_test_successful_transaction()
	_test_build_failure_rollback()
	_test_attach_failure_rollback()
	_test_bind_failure_rollback()
	_test_initialize_failure_rollback()
	_test_ready_failure_rollback()
	_test_start_failure_rollback()
	_test_activation_cleanup_error_aggregation()
	_test_shutdown_cleanup_error_aggregation()

	_finish_test()


# =============================================================================
# SUCCESSFUL TRANSACTION
# =============================================================================

func _test_successful_transaction() -> void:

	var fixture := _fixture()

	if not _expect_fixture(
		fixture,
		"CRT-I01"
	):
		return

	var runtime := _runtime_from(fixture)
	var plan := _plan_from(fixture)
	var activation_result := runtime.activate(plan)

	_expect(
		activation_result.is_success()
		and activation_result.get_report().is_empty()
		and runtime.get_state() == CompositionRuntime.State.ACTIVE,
		"CRT-I01: activation commits one clean transaction"
	)

	var expected_activation: Array[String] = [
		"build:device_a",
		"build:device_b",
		"build:device_c",
		"attach:device_a",
		"attach:device_b",
		"attach:device_c",
		"bind:device_a|out_distance|device_b|in_distance",
		"bind:device_b|out_health|device_c|in_health",
		"initialize:device_a",
		"initialize:device_b",
		"initialize:device_c",
		"ready:device_a",
		"ready:device_b",
		"ready:device_c",
		"start:device_a",
		"start:device_b",
		"start:device_c",
	]

	_expect(
		_events(fixture) == expected_activation,
		"CRT-I01: activation respects every forward phase barrier"
	)

	_expect(
		runtime.get_handles().size() == 3
		and runtime.get_device_bus() != null
		and _call_int(
			fixture["host"],
			&"get_attached_count"
		) == 3
		and _call_int(
			fixture["binder"],
			&"get_bound_count"
		) == 2,
		"CRT-I01: ACTIVE owns all built, attached and bound resources"
	)

	var shutdown_result := runtime.shutdown()

	_expect(
		shutdown_result.is_success()
		and shutdown_result.get_report().is_empty()
		and runtime.get_state() == CompositionRuntime.State.SHUTDOWN,
		"CRT-I01: clean shutdown commits SHUTDOWN"
	)

	var expected_complete := expected_activation.duplicate()

	expected_complete.append_array(
		[
			"shutdown:device_c",
			"shutdown:device_b",
			"shutdown:device_a",
			"unbind:device_b|out_health|device_c|in_health",
			"unbind:device_a|out_distance|device_b|in_distance",
			"detach:device_c",
			"detach:device_b",
			"detach:device_a",
			"release:device_c",
			"release:device_b",
			"release:device_a",
		]
	)

	_expect(
		_events(fixture) == expected_complete,
		"CRT-I01: shutdown executes exact reverse cleanup order"
	)

	_expect(
		_runtime_resources_are_clear(runtime)
		and _all_external_resources_are_clear(fixture)
		and _call_int(
			fixture["factory"],
			&"get_release_count"
		) == 3,
		"CRT-I01: shutdown leaves no owned active resource"
	)


# =============================================================================
# BUILD FAILURE
# =============================================================================

func _test_build_failure_rollback() -> void:

	var fixture := _fixture()

	if not _expect_fixture(
		fixture,
		"CRT-I02"
	):
		return

	_call_failure(
		fixture["factory"],
		&"build",
		"device_b"
	)

	var runtime := _runtime_from(fixture)
	var result := runtime.activate(
		_plan_from(fixture)
	)

	_expect_failed_activation(
		runtime,
		result,
		"CRT-I02: controlled build failure"
	)

	_expect(
		_report_has_issue(
			result.get_report(),
			&"runtime_integration_factory_build_failed",
			"device_b",
			&"build"
		),
		"CRT-I02: build root cause is preserved"
	)

	var expected: Array[String] = [
		"build:device_a",
		"build:device_b",
		"release:device_a",
	]

	_expect(
		_events(fixture) == expected,
		"CRT-I02: build failure releases only completed Handles"
	)

	_expect(
		_call_int(
			fixture["factory"],
			&"get_build_count"
		) == 2
		and _call_int(
			fixture["factory"],
			&"get_release_count"
		) == 1
		and _all_external_resources_are_clear(fixture),
		"CRT-I02: build failure crosses no later phase"
	)


# =============================================================================
# ATTACH FAILURE
# =============================================================================

func _test_attach_failure_rollback() -> void:

	var fixture := _fixture()

	if not _expect_fixture(
		fixture,
		"CRT-I03"
	):
		return

	_call_failure(
		fixture["host"],
		&"attach",
		"device_b"
	)

	var runtime := _runtime_from(fixture)
	var result := runtime.activate(
		_plan_from(fixture)
	)

	_expect_failed_activation(
		runtime,
		result,
		"CRT-I03: controlled attach failure"
	)

	_expect(
		_report_has_issue(
			result.get_report(),
			&"runtime_integration_host_attach_failed",
			"device_b",
			&"attach"
		),
		"CRT-I03: attach root cause is preserved"
	)

	var expected: Array[String] = [
		"build:device_a",
		"build:device_b",
		"build:device_c",
		"attach:device_a",
		"attach:device_b",
		"detach:device_a",
		"release:device_c",
		"release:device_b",
		"release:device_a",
	]

	_expect(
		_events(fixture) == expected,
		"CRT-I03: attach failure rolls back completed attach then all builds"
	)

	_expect(
		_all_external_resources_are_clear(fixture)
		and _call_int(
			fixture["factory"],
			&"get_release_count"
		) == 3,
		"CRT-I03: attach rollback leaves no external resource"
	)


# =============================================================================
# BIND FAILURE
# =============================================================================

func _test_bind_failure_rollback() -> void:

	var fixture := _fixture()

	if not _expect_fixture(
		fixture,
		"CRT-I04"
	):
		return

	var connection_bc: StringName = fixture["connection_bc"]

	_call_failure(
		fixture["binder"],
		&"bind",
		connection_bc
	)

	var runtime := _runtime_from(fixture)
	var result := runtime.activate(
		_plan_from(fixture)
	)

	_expect_failed_activation(
		runtime,
		result,
		"CRT-I04: controlled bind failure"
	)

	_expect(
		_report_has_issue(
			result.get_report(),
			&"runtime_integration_binder_bind_failed",
			String(connection_bc),
			&"bind"
		),
		"CRT-I04: bind root cause is preserved"
	)

	var expected: Array[String] = [
		"build:device_a",
		"build:device_b",
		"build:device_c",
		"attach:device_a",
		"attach:device_b",
		"attach:device_c",
		"bind:device_a|out_distance|device_b|in_distance",
		"bind:device_b|out_health|device_c|in_health",
		"unbind:device_a|out_distance|device_b|in_distance",
		"detach:device_c",
		"detach:device_b",
		"detach:device_a",
		"release:device_c",
		"release:device_b",
		"release:device_a",
	]

	_expect(
		_events(fixture) == expected,
		"CRT-I04: bind failure reverses only confirmed Directives"
	)

	_expect(
		_all_external_resources_are_clear(fixture),
		"CRT-I04: bind rollback leaves no external resource"
	)


# =============================================================================
# INITIALIZE FAILURE
# =============================================================================

func _test_initialize_failure_rollback() -> void:

	var fixture := _fixture()

	if not _expect_fixture(
		fixture,
		"CRT-I05"
	):
		return

	_call_failure(
		fixture["lifecycle"],
		&"initialize",
		"device_b"
	)

	var runtime := _runtime_from(fixture)
	var result := runtime.activate(
		_plan_from(fixture)
	)

	_expect_failed_activation(
		runtime,
		result,
		"CRT-I05: controlled initialize failure"
	)

	_expect(
		_report_has_issue(
			result.get_report(),
			&"runtime_integration_lifecycle_phase_failed",
			"device_b",
			&"initialize"
		),
		"CRT-I05: initialize root cause is preserved"
	)

	var expected: Array[String] = [
		"build:device_a",
		"build:device_b",
		"build:device_c",
		"attach:device_a",
		"attach:device_b",
		"attach:device_c",
		"bind:device_a|out_distance|device_b|in_distance",
		"bind:device_b|out_health|device_c|in_health",
		"initialize:device_a",
		"initialize:device_b",
		"shutdown:device_b",
		"shutdown:device_a",
		"unbind:device_b|out_health|device_c|in_health",
		"unbind:device_a|out_distance|device_b|in_distance",
		"detach:device_c",
		"detach:device_b",
		"detach:device_a",
		"release:device_c",
		"release:device_b",
		"release:device_a",
	]

	_expect(
		_events(fixture) == expected,
		"CRT-I05: partial initialize includes current Handle in shutdown"
	)

	_expect(
		_call_int(
			fixture["lifecycle"],
			&"get_shutdown_count"
		) == 2
		and _all_external_resources_are_clear(fixture),
		"CRT-I05: uninitialized Handle is released without lifecycle shutdown"
	)


# =============================================================================
# READY FAILURE
# =============================================================================

func _test_ready_failure_rollback() -> void:

	var fixture := _fixture()

	if not _expect_fixture(
		fixture,
		"CRT-I06"
	):
		return

	_call_failure(
		fixture["lifecycle"],
		&"ready",
		"device_b"
	)

	var runtime := _runtime_from(fixture)
	var result := runtime.activate(
		_plan_from(fixture)
	)

	_expect_failed_activation(
		runtime,
		result,
		"CRT-I06: controlled ready failure"
	)

	_expect(
		_report_has_issue(
			result.get_report(),
			&"runtime_integration_lifecycle_phase_failed",
			"device_b",
			&"ready"
		),
		"CRT-I06: ready root cause is preserved"
	)

	var expected := _events_through_initialize()

	expected.append_array(
		[
			"ready:device_a",
			"ready:device_b",
		]
	)

	_append_full_reverse_cleanup(expected)

	_expect(
		_events(fixture) == expected,
		"CRT-I06: ready failure shuts down every initialized Handle"
	)

	_expect(
		_call_int(
			fixture["lifecycle"],
			&"get_shutdown_count"
		) == 3
		and _all_external_resources_are_clear(fixture),
		"CRT-I06: ready rollback completes all cleanup phases"
	)


# =============================================================================
# START FAILURE
# =============================================================================

func _test_start_failure_rollback() -> void:

	var fixture := _fixture()

	if not _expect_fixture(
		fixture,
		"CRT-I07"
	):
		return

	_call_failure(
		fixture["lifecycle"],
		&"start",
		"device_b"
	)

	var runtime := _runtime_from(fixture)
	var result := runtime.activate(
		_plan_from(fixture)
	)

	_expect_failed_activation(
		runtime,
		result,
		"CRT-I07: controlled start failure"
	)

	_expect(
		_report_has_issue(
			result.get_report(),
			&"runtime_integration_lifecycle_phase_failed",
			"device_b",
			&"start"
		),
		"CRT-I07: start root cause is preserved"
	)

	var expected := _events_through_ready()

	expected.append_array(
		[
			"start:device_a",
			"start:device_b",
		]
	)

	_append_full_reverse_cleanup(expected)

	_expect(
		_events(fixture) == expected,
		"CRT-I07: start failure prevents later start and reverses all ownership"
	)

	_expect(
		_all_external_resources_are_clear(fixture),
		"CRT-I07: start rollback leaves no external resource"
	)


# =============================================================================
# ACTIVATION CLEANUP ERRORS
# =============================================================================

func _test_activation_cleanup_error_aggregation() -> void:

	var fixture := _fixture()

	if not _expect_fixture(
		fixture,
		"CRT-I08"
	):
		return

	_call_failure(
		fixture["lifecycle"],
		&"start",
		"device_b"
	)

	_call_failure(
		fixture["lifecycle"],
		&"shutdown",
		"device_b"
	)

	_call_failure(
		fixture["binder"],
		&"unbind",
		fixture["connection_ab"]
	)

	_call_failure(
		fixture["host"],
		&"detach",
		"device_b"
	)

	_call_failure(
		fixture["factory"],
		&"release",
		"device_b"
	)

	var runtime := _runtime_from(fixture)
	var result := runtime.activate(
		_plan_from(fixture)
	)

	_expect_failed_activation(
		runtime,
		result,
		"CRT-I08: activation and cleanup failures"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"runtime_integration_lifecycle_phase_failed"
		)
		and _report_has_code(
			result.get_report(),
			&"runtime_integration_lifecycle_shutdown_failed"
		)
		and _report_has_code(
			result.get_report(),
			&"runtime_integration_binder_unbind_failed"
		)
		and _report_has_code(
			result.get_report(),
			&"runtime_integration_host_detach_failed"
		)
		and _report_has_code(
			result.get_report(),
			&"runtime_integration_factory_release_failed"
		),
		"CRT-I08: root cause and four cleanup errors are aggregated"
	)

	_expect(
		result.get_report().get_issue_count() == 5,
		"CRT-I08: cleanup aggregation introduces no duplicate Issues"
	)

	var expected := _events_through_ready()

	expected.append_array(
		[
			"start:device_a",
			"start:device_b",
		]
	)

	_append_full_reverse_cleanup(expected)

	_expect(
		_events(fixture) == expected,
		"CRT-I08: cleanup errors never short-circuit later cleanup"
	)

	_expect(
		_all_external_resources_are_clear(fixture)
		and _call_int(
			fixture["factory"],
			&"get_release_count"
		) == 3,
		"CRT-I08: failed cleanup reports attempts but abandons no owned state"
	)

	var event_snapshot := _events(fixture)
	var rejected_shutdown := runtime.shutdown()

	_expect(
		not rejected_shutdown.is_success()
		and runtime.get_state() == CompositionRuntime.State.FAILED
		and _events(fixture) == event_snapshot,
		"CRT-I08: FAILED Runtime rejects shutdown without double cleanup"
	)


# =============================================================================
# SHUTDOWN CLEANUP ERRORS
# =============================================================================

func _test_shutdown_cleanup_error_aggregation() -> void:

	var fixture := _fixture()

	if not _expect_fixture(
		fixture,
		"CRT-I09"
	):
		return

	var runtime := _runtime_from(fixture)
	var activation_result := runtime.activate(
		_plan_from(fixture)
	)

	_expect(
		activation_result.is_success()
		and runtime.is_active(),
		"CRT-I09: cleanup-error fixture reaches ACTIVE"
	)

	_call_failure(
		fixture["lifecycle"],
		&"shutdown",
		"device_b"
	)

	_call_failure(
		fixture["binder"],
		&"unbind",
		fixture["connection_ab"]
	)

	_call_failure(
		fixture["host"],
		&"detach",
		"device_b"
	)

	_call_failure(
		fixture["factory"],
		&"release",
		"device_b"
	)

	var shutdown_result := runtime.shutdown()

	_expect(
		not shutdown_result.is_success()
		and runtime.get_state() == CompositionRuntime.State.FAILED,
		"CRT-I09: cleanup error makes shutdown fail closed"
	)

	_expect(
		shutdown_result.get_report().get_issue_count() == 4
		and _report_has_code(
			shutdown_result.get_report(),
			&"runtime_integration_lifecycle_shutdown_failed"
		)
		and _report_has_code(
			shutdown_result.get_report(),
			&"runtime_integration_binder_unbind_failed"
		)
		and _report_has_code(
			shutdown_result.get_report(),
			&"runtime_integration_host_detach_failed"
		)
		and _report_has_code(
			shutdown_result.get_report(),
			&"runtime_integration_factory_release_failed"
		),
		"CRT-I09: shutdown aggregates every cleanup error"
	)

	_expect(
		_runtime_resources_are_clear(runtime)
		and _all_external_resources_are_clear(fixture)
		and _call_int(
			fixture["factory"],
			&"get_release_count"
		) == 3,
		"CRT-I09: failed shutdown clears internal and external ownership"
	)

	var events_after_shutdown := _events(fixture)
	var repeated_shutdown := runtime.shutdown()

	_expect(
		not repeated_shutdown.is_success()
		and _events(fixture) == events_after_shutdown,
		"CRT-I09: terminal FAILED state prevents repeated cleanup"
	)


# =============================================================================
# FIXTURE
# =============================================================================

func _fixture(
) -> Dictionary:

	var trace := RuntimeIntegrationTraceScript.new()
	var factory := RuntimeIntegrationFactoryScript.new(trace)
	var host := RuntimeIntegrationHostScript.new(trace)
	var lifecycle := RuntimeIntegrationLifecycleScript.new(trace)
	var binder := RuntimeIntegrationBinderScript.new(trace)
	var resolver := RuntimeDependencyResolverScript.new()

	var specs: Array[RuntimeDependencySpec] = []

	var entry_a := _entry(
		"device_a",
		specs
	)

	var entry_b := _entry(
		"device_b",
		specs
	)

	var entry_c := _entry(
		"device_c",
		specs
	)

	var entries: Array[CompositionDeviceEntry] = [
		entry_a,
		entry_b,
		entry_c,
	]

	var directive_ab := CompositionConnectionDirective.new(
		"device_a",
		&"out_distance",
		BusTopics.DISTANCE_MEASUREMENT,
		"device_b",
		&"in_distance"
	)

	var directive_bc := CompositionConnectionDirective.new(
		"device_b",
		&"out_health",
		BusTopics.HEALTH_REPORT,
		"device_c",
		&"in_health"
	)

	var directives: Array[CompositionConnectionDirective] = [
		directive_ab,
		directive_bc,
	]

	var plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		DeviceBusDispatchPolicy.new(
			32,
			128,
			16,
			5000
		)
	)

	var descriptor := RuntimeFactoryDescriptor.new(
		entry_a.get_factory_key(),
		factory,
		specs
	)

	var draft := RuntimeFactoryRegistryDraft.new()

	draft.descriptors.append(descriptor)

	var registry_result := RuntimeFactoryRegistryCompiler.new().compile(
		draft
	)

	var registry := registry_result.get_registry()

	var runtime := CompositionRuntime.new(
		registry,
		resolver,
		host,
		lifecycle,
		binder
	)

	return {
		"trace": trace,
		"factory": factory,
		"host": host,
		"lifecycle": lifecycle,
		"binder": binder,
		"resolver": resolver,
		"registry_result": registry_result,
		"registry": registry,
		"plan": plan,
		"runtime": runtime,
		"connection_ab": directive_ab.get_connection_id(),
		"connection_bc": directive_bc.get_connection_id(),
	}


func _entry(
	device_id: String,
	dependency_specs: Array[RuntimeDependencySpec]
) -> CompositionDeviceEntry:

	var capabilities: Array[String] = [
		"runtime_integration",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	var configuration := DeviceConfiguration.new(
		StringName(
			"test.runtime.integration." + device_id
		),
		1,
		device_id,
		&"test.runtime.integration.profile",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)

	var factory_key := RuntimeFactoryKey.new(
		&"test.runtime.integration.profile",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	return CompositionDeviceEntry.new(
		device_id,
		configuration,
		factory_key,
		dependency_specs
	)


# =============================================================================
# EXPECTED EVENTS
# =============================================================================

func _events_through_initialize(
) -> Array[String]:

	return [
		"build:device_a",
		"build:device_b",
		"build:device_c",
		"attach:device_a",
		"attach:device_b",
		"attach:device_c",
		"bind:device_a|out_distance|device_b|in_distance",
		"bind:device_b|out_health|device_c|in_health",
		"initialize:device_a",
		"initialize:device_b",
		"initialize:device_c",
	]


func _events_through_ready(
) -> Array[String]:

	var events := _events_through_initialize()

	events.append_array(
		[
			"ready:device_a",
			"ready:device_b",
			"ready:device_c",
		]
	)

	return events


func _append_full_reverse_cleanup(
	events: Array[String]
) -> void:

	events.append_array(
		[
			"shutdown:device_c",
			"shutdown:device_b",
			"shutdown:device_a",
			"unbind:device_b|out_health|device_c|in_health",
			"unbind:device_a|out_distance|device_b|in_distance",
			"detach:device_c",
			"detach:device_b",
			"detach:device_a",
			"release:device_c",
			"release:device_b",
			"release:device_a",
		]
	)


# =============================================================================
# HELPERS
# =============================================================================

func _expect_fixture(
	fixture: Dictionary,
	case_id: String
) -> bool:

	var registry_result: RuntimeFactoryRegistryCompileResult = (
		fixture["registry_result"]
	)
	var registry: RuntimeFactoryRegistry = fixture["registry"]
	var plan: CompositionPlan = fixture["plan"]
	var runtime: CompositionRuntime = fixture["runtime"]

	var valid: bool = (
		registry_result != null
		and registry_result.is_success()
		and registry != null
		and plan != null
		and plan.is_valid()
		and runtime != null
	)

	_expect(
		valid,
		case_id + ": integration fixture is valid"
	)

	return valid


func _expect_failed_activation(
	runtime: CompositionRuntime,
	result: CompositionRuntimeOperationResult,
	description: String
) -> void:

	_expect(
		result != null
		and not result.is_success()
		and runtime.get_state() == CompositionRuntime.State.FAILED,
		description + " leaves terminal FAILED"
	)

	_expect(
		_runtime_resources_are_clear(runtime),
		description + " exposes no partial active state"
	)


func _runtime_resources_are_clear(
	runtime: CompositionRuntime
) -> bool:

	return (
		not runtime.is_active()
		and runtime.get_active_plan() == null
		and runtime.get_device_bus() == null
		and runtime.get_handles().is_empty()
	)


func _all_external_resources_are_clear(
	fixture: Dictionary
) -> bool:

	return (
		_call_int(
			fixture["host"],
			&"get_attached_count"
		) == 0
		and _call_int(
			fixture["binder"],
			&"get_bound_count"
		) == 0
	)


func _runtime_from(
	fixture: Dictionary
) -> CompositionRuntime:

	return fixture["runtime"]


func _plan_from(
	fixture: Dictionary
) -> CompositionPlan:

	return fixture["plan"]


func _events(
	fixture: Dictionary
) -> Array[String]:

	var events: Array[String] = []
	var trace: Object = fixture["trace"]
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


func _call_failure(
	target_value: Variant,
	phase: StringName,
	related_id: Variant
) -> void:

	var target: Object = target_value as Object

	if target == null:
		return

	target.call(
		&"add_failure",
		phase,
		related_id
	)


func _call_int(
	target_value: Variant,
	method_name: StringName
) -> int:

	var target: Object = target_value as Object

	if target == null:
		return -1

	return int(
		target.call(method_name)
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


func _report_has_issue(
	report: ValidationReport,
	code: StringName,
	related_object_id: String,
	related_field: StringName
) -> bool:

	if report == null:
		return false

	for issue: ValidationIssue in report.get_issues():
		if (
			issue.get_code() == code
			and issue.get_related_object_id()
			== related_object_id
			and issue.get_related_field()
			== related_field
		):
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
