extends Node


##
## CompositionPlanTest
##
## Verifica Plan vacío, Context,
## Dispatch Policy, Entries, Directives,
## órdenes por fases e inmutabilidad.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("CompositionPlanTest")
	print("========================================")

	_test_empty_plan()
	_test_valid_plan()
	_test_hardware_plan()
	_test_required_context_and_policy()
	_test_entry_validation()
	_test_directive_validation()
	_test_lifecycle_orders()
	_test_collection_independence()
	_test_contract()

	_finish_test()


# =============================================================================
# EMPTY PLAN
# =============================================================================

func _test_empty_plan() -> void:

	var entries: Array[CompositionDeviceEntry] = []
	var directives: Array[CompositionConnectionDirective] = []
	var policy := DeviceBusDispatchPolicy.new()

	var plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		policy
	)

	var plan_value: Variant = plan

	_expect(
		plan.is_valid(),
		"CP-U01: empty Plan with valid Context and Policy is valid"
	)

	_expect(
		plan.get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION,
		"CP-U01: Activation Context is preserved"
	)

	_expect(
		plan.get_dispatch_policy() == policy,
		"CP-U01: Dispatch Policy reference is preserved"
	)

	_expect(
		plan.get_device_entries().is_empty()
		and plan.get_connection_directives().is_empty(),
		"CP-U01: empty Plan preserves empty collections"
	)

	_expect(
		plan.get_construction_order().is_empty()
		and plan.get_attach_order().is_empty()
		and plan.get_initialization_order().is_empty()
		and plan.get_ready_order().is_empty()
		and plan.get_start_order().is_empty()
		and plan.get_shutdown_order().is_empty()
		and plan.get_rollback_order().is_empty(),
		"CP-U01: empty Plan produces empty lifecycle orders"
	)

	_expect(
		plan_value is RefCounted
		and not (plan_value is Node),
		"CP-U01: Plan is RefCounted and not Node"
	)


# =============================================================================
# VALID PLAN
# =============================================================================

func _test_valid_plan() -> void:

	var entry_a := _entry(
		"device_a",
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var entry_b := _entry(
		"device_b",
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var entry_c := _entry(
		"device_c",
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var directive_ab := _directive(
		"device_a",
		"device_b",
		&"velocity.topic.ab"
	)

	var directive_bc := _directive(
		"device_b",
		"device_c",
		&"velocity.topic.bc"
	)

	var entries: Array[CompositionDeviceEntry] = [
		entry_a,
		entry_b,
		entry_c,
	]

	var directives: Array[CompositionConnectionDirective] = [
		directive_ab,
		directive_bc,
	]

	var policy := DeviceBusDispatchPolicy.new(
		64,
		256,
		32,
		10000
	)

	var plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		policy
	)

	_expect(
		plan.is_valid(),
		"CP-U02: complete Plan is valid"
	)

	_expect(
		plan.get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION,
		"CP-U02: Simulation Context is preserved"
	)

	_expect(
		plan.get_dispatch_policy() == policy,
		"CP-U02: explicit Dispatch Policy is preserved"
	)

	var returned_entries := plan.get_device_entries()

	_expect(
		returned_entries.size() == 3
		and returned_entries[0] == entry_a
		and returned_entries[1] == entry_b
		and returned_entries[2] == entry_c,
		"CP-U02: Device Entry order is preserved"
	)

	var returned_directives := plan.get_connection_directives()

	_expect(
		returned_directives.size() == 2
		and returned_directives[0] == directive_ab
		and returned_directives[1] == directive_bc,
		"CP-U02: Connection Directive order is preserved"
	)

	_expect(
		plan.get_device_entry(
			"device_a"
		) == entry_a
		and plan.get_device_entry(
			"device_b"
		) == entry_b
		and plan.get_device_entry(
			"device_c"
		) == entry_c,
		"CP-U02: exact Device Entry lookup works"
	)

	_expect(
		plan.get_device_entry(
			"missing"
		) == null
		and plan.get_device_entry(
			""
		) == null,
		"CP-U02: missing Device Entry lookup returns null"
	)

	_expect(
		plan.get_connection_directive(
			directive_ab.get_connection_id()
		) == directive_ab
		and plan.get_connection_directive(
			directive_bc.get_connection_id()
		) == directive_bc,
		"CP-U02: exact Connection Directive lookup works"
	)

	_expect(
		plan.get_connection_directive(
			&"missing"
		) == null
		and plan.get_connection_directive(
			&""
		) == null,
		"CP-U02: missing Connection Directive lookup returns null"
	)


# =============================================================================
# HARDWARE PLAN
# =============================================================================

func _test_hardware_plan() -> void:

	var entries: Array[CompositionDeviceEntry] = [
		_entry(
			"hardware_device",
			DeviceConfiguration.ActivationContext.HARDWARE
		),
	]

	var directives: Array[CompositionConnectionDirective] = []

	var plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.HARDWARE,
		entries,
		directives,
		DeviceBusDispatchPolicy.new()
	)

	_expect(
		plan.is_valid(),
		"CP-U03: Hardware Plan is structurally valid"
	)

	var hardware_entry := plan.get_device_entries()[0]

	var hardware_key := hardware_entry.get_factory_key()

	_expect(
		plan.get_activation_context()
		== DeviceConfiguration.ActivationContext.HARDWARE
		and hardware_key.get_activation_context()
		== DeviceConfiguration.ActivationContext.HARDWARE,
		"CP-U03: Hardware Context is consistent"
	)


# =============================================================================
# REQUIRED CONTEXT AND POLICY
# =============================================================================

func _test_required_context_and_policy() -> void:

	var entries: Array[CompositionDeviceEntry] = []
	var directives: Array[CompositionConnectionDirective] = []

	var invalid_context := CompositionPlan.new(
		-1,
		entries,
		directives,
		DeviceBusDispatchPolicy.new()
	)

	var missing_policy := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		null
	)

	var zero_policy := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		DeviceBusDispatchPolicy.new(
			0,
			1,
			1,
			1
		)
	)

	var excessive_policy := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		DeviceBusDispatchPolicy.new(
			DeviceBusDispatchPolicy.HARD_MAX_PUBLICATIONS_PER_CYCLE + 1,
			1,
			1,
			1
		)
	)

	_expect(
		not invalid_context.is_valid(),
		"CP-U04: unknown Activation Context is invalid"
	)

	_expect(
		not missing_policy.is_valid(),
		"CP-U04: null Dispatch Policy is invalid"
	)

	_expect(
		not zero_policy.is_valid(),
		"CP-U04: zero Dispatch Policy budget is invalid"
	)

	_expect(
		not excessive_policy.is_valid(),
		"CP-U04: Policy above hard maximum is invalid"
	)


# =============================================================================
# ENTRY VALIDATION
# =============================================================================

func _test_entry_validation() -> void:

	var directives: Array[CompositionConnectionDirective] = []
	var policy := DeviceBusDispatchPolicy.new()

	var null_entries: Array[CompositionDeviceEntry] = [
		null,
	]

	var null_entry_plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		null_entries,
		directives,
		policy
	)

	var invalid_entry := CompositionDeviceEntry.new(
		"different_device",
		_configuration(
			"runtime_sensor",
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		_factory_key(
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		[]
	)

	var invalid_entries: Array[CompositionDeviceEntry] = [
		invalid_entry,
	]

	var invalid_entry_plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		invalid_entries,
		directives,
		policy
	)

	var duplicate_entries: Array[CompositionDeviceEntry] = [
		_entry(
			"duplicate_device",
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		_entry(
			"duplicate_device",
			DeviceConfiguration.ActivationContext.SIMULATION
		),
	]

	var duplicate_entry_plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		duplicate_entries,
		directives,
		policy
	)

	var mismatched_context_entries: Array[CompositionDeviceEntry] = [
		_entry(
			"hardware_device",
			DeviceConfiguration.ActivationContext.HARDWARE
		),
	]

	var mismatched_context_plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		mismatched_context_entries,
		directives,
		policy
	)

	_expect(
		not null_entry_plan.is_valid(),
		"CP-U05: null Device Entry is rejected"
	)

	_expect(
		not invalid_entry_plan.is_valid(),
		"CP-U05: invalid Device Entry is rejected"
	)

	_expect(
		not duplicate_entry_plan.is_valid(),
		"CP-U05: duplicate Device ID is rejected"
	)

	_expect(
		not mismatched_context_plan.is_valid(),
		"CP-U05: Entry Context mismatch is rejected"
	)


# =============================================================================
# DIRECTIVE VALIDATION
# =============================================================================

func _test_directive_validation() -> void:

	var entries: Array[CompositionDeviceEntry] = [
		_entry(
			"device_a",
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		_entry(
			"device_b",
			DeviceConfiguration.ActivationContext.SIMULATION
		),
	]

	var policy := DeviceBusDispatchPolicy.new()

	var null_directives: Array[CompositionConnectionDirective] = [
		null,
	]

	var null_directive_plan := _plan_with(
		entries,
		null_directives,
		policy
	)

	var invalid_directives: Array[CompositionConnectionDirective] = [
		_directive(
			"device_a",
			"device_a",
			&"velocity.self"
		),
	]

	var invalid_directive_plan := _plan_with(
		entries,
		invalid_directives,
		policy
	)

	var duplicate_directive := _directive(
		"device_a",
		"device_b",
		&"velocity.duplicate"
	)

	var duplicate_directives: Array[CompositionConnectionDirective] = [
		duplicate_directive,
		duplicate_directive,
	]

	var duplicate_directive_plan := _plan_with(
		entries,
		duplicate_directives,
		policy
	)

	var unknown_source_directives: Array[CompositionConnectionDirective] = [
		_directive(
			"unknown_source",
			"device_b",
			&"velocity.unknown_source"
		),
	]

	var unknown_source_plan := _plan_with(
		entries,
		unknown_source_directives,
		policy
	)

	var unknown_target_directives: Array[CompositionConnectionDirective] = [
		_directive(
			"device_a",
			"unknown_target",
			&"velocity.unknown_target"
		),
	]

	var unknown_target_plan := _plan_with(
		entries,
		unknown_target_directives,
		policy
	)

	_expect(
		not null_directive_plan.is_valid(),
		"CP-U06: null Connection Directive is rejected"
	)

	_expect(
		not invalid_directive_plan.is_valid(),
		"CP-U06: invalid Connection Directive is rejected"
	)

	_expect(
		not duplicate_directive_plan.is_valid(),
		"CP-U06: duplicate Connection ID is rejected"
	)

	_expect(
		not unknown_source_plan.is_valid(),
		"CP-U06: unknown Source Device is rejected"
	)

	_expect(
		not unknown_target_plan.is_valid(),
		"CP-U06: unknown Target Device is rejected"
	)


# =============================================================================
# LIFECYCLE ORDERS
# =============================================================================

func _test_lifecycle_orders() -> void:

	var entries: Array[CompositionDeviceEntry] = [
		_entry(
			"device_a",
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		_entry(
			"device_b",
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		_entry(
			"device_c",
			DeviceConfiguration.ActivationContext.SIMULATION
		),
	]

	var cycle_directives: Array[CompositionConnectionDirective] = [
		_directive(
			"device_a",
			"device_b",
			&"velocity.cycle.ab"
		),
		_directive(
			"device_b",
			"device_a",
			&"velocity.cycle.ba"
		),
	]

	var plan := _plan_with(
		entries,
		cycle_directives,
		DeviceBusDispatchPolicy.new()
	)

	var forward: Array[String] = [
		"device_a",
		"device_b",
		"device_c",
	]

	var reverse: Array[String] = [
		"device_c",
		"device_b",
		"device_a",
	]

	_expect(
		plan.is_valid(),
		"CP-U07: cycle does not invalidate Plan ordering"
	)

	_expect(
		plan.get_construction_order() == forward,
		"CP-U07: Construction order follows Device Entries"
	)

	_expect(
		plan.get_attach_order() == forward,
		"CP-U07: Attach order follows Device Entries"
	)

	_expect(
		plan.get_initialization_order() == forward,
		"CP-U07: Initialization order follows Device Entries"
	)

	_expect(
		plan.get_ready_order() == forward,
		"CP-U07: Ready order follows Device Entries"
	)

	_expect(
		plan.get_start_order() == forward,
		"CP-U07: Start order follows Device Entries"
	)

	_expect(
		plan.get_shutdown_order() == reverse,
		"CP-U07: Shutdown order reverses Device Entries"
	)

	_expect(
		plan.get_rollback_order() == reverse,
		"CP-U07: Rollback order reverses Device Entries"
	)

	var construction_order := plan.get_construction_order()
	var start_order := plan.get_start_order()

	construction_order.clear()
	start_order.reverse()

	_expect(
		plan.get_construction_order() == forward
		and plan.get_start_order() == forward,
		"CP-U07: phase order Arrays are independent"
	)


# =============================================================================
# COLLECTION INDEPENDENCE
# =============================================================================

func _test_collection_independence() -> void:

	var entry_a := _entry(
		"device_a",
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var entry_b := _entry(
		"device_b",
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var directive := _directive(
		"device_a",
		"device_b",
		&"velocity.independent"
	)

	var source_entries: Array[CompositionDeviceEntry] = [
		entry_a,
		entry_b,
	]

	var source_directives: Array[CompositionConnectionDirective] = [
		directive,
	]

	var plan := _plan_with(
		source_entries,
		source_directives,
		DeviceBusDispatchPolicy.new()
	)

	source_entries.clear()
	source_directives.clear()

	_expect(
		plan.get_device_entries().size() == 2
		and plan.get_connection_directives().size() == 1,
		"CP-U08: constructor copies collection Arrays"
	)

	var entries_copy := plan.get_device_entries()
	var directives_copy := plan.get_connection_directives()

	entries_copy.clear()
	directives_copy.clear()

	_expect(
		plan.get_device_entries().size() == 2
		and plan.get_connection_directives().size() == 1,
		"CP-U08: collection getters return independent Arrays"
	)

	var order_copy := plan.get_rollback_order()

	order_copy.clear()

	_expect(
		plan.get_rollback_order().size() == 2,
		"CP-U08: order getters return independent Arrays"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var entries: Array[CompositionDeviceEntry] = []
	var directives: Array[CompositionConnectionDirective] = []

	var plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		DeviceBusDispatchPolicy.new()
	)

	_expect(
		not plan.has_method(
			&"set_activation_context"
		)
		and not plan.has_method(
			&"set_device_entries"
		)
		and not plan.has_method(
			&"set_connection_directives"
		)
		and not plan.has_method(
			&"set_dispatch_policy"
		),
		"CP-U09: Plan exposes no setters"
	)

	_expect(
		not plan.has_method(
			&"execute"
		)
		and not plan.has_method(
			&"activate"
		)
		and not plan.has_method(
			&"build"
		)
		and not plan.has_method(
			&"create_device"
		),
		"CP-U09: Plan is not executable"
	)

	_expect(
		not plan.has_method(
			&"attach"
		)
		and not plan.has_method(
			&"initialize"
		)
		and not plan.has_method(
			&"set_ready"
		)
		and not plan.has_method(
			&"start"
		)
		and not plan.has_method(
			&"shutdown"
		),
		"CP-U09: Plan does not execute lifecycle"
	)

	_expect(
		not plan.has_method(
			&"get_device_bus"
		)
		and not plan.has_method(
			&"publish"
		)
		and not plan.has_method(
			&"subscribe"
		),
		"CP-U09: Plan contains no active DeviceBus"
	)

	_expect(
		not plan.has_method(
			&"get_factory"
		)
		and not plan.has_method(
			&"get_runtime_handle"
		)
		and not plan.has_method(
			&"get_primary_runtime_object"
		),
		"CP-U09: Plan contains no active runtime resources"
	)

	_expect(
		not plan.has_method(
			&"get_factory_registry"
		)
		and not plan.has_method(
			&"set_factory_registry"
		),
		"CP-U09: Plan does not contain RuntimeFactoryRegistry"
	)

	_expect(
		not plan.has_method(
			&"get_plan_id"
		)
		and not plan.has_method(
			&"get_plan_version"
		),
		"CP-U09: Plan 1.0 has no artificial identity"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _entry(
	device_id: String,
	activation_context: int
) -> CompositionDeviceEntry:

	var dependency_specs: Array[RuntimeDependencySpec] = []

	return CompositionDeviceEntry.new(
		device_id,
		_configuration(
			device_id,
			activation_context
		),
		_factory_key(
			activation_context
		),
		dependency_specs
	)


func _configuration(
	device_id: String,
	activation_context: int
) -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"composition_plan",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	var configuration_id := StringName(
		"test.composition." + device_id
	)

	return DeviceConfiguration.new(
		configuration_id,
		1,
		device_id,
		&"test.runtime.sensor",
		2,
		activation_context,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _factory_key(
	activation_context: int
) -> RuntimeFactoryKey:

	return RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		2,
		activation_context
	)


func _directive(
	source_device_id: String,
	target_device_id: String,
	topic: StringName
) -> CompositionConnectionDirective:

	return CompositionConnectionDirective.new(
		source_device_id,
		&"out.topic",
		topic,
		target_device_id,
		&"in.topic"
	)


func _plan_with(
	entries: Array[CompositionDeviceEntry],
	directives: Array[CompositionConnectionDirective],
	policy: DeviceBusDispatchPolicy
) -> CompositionPlan:

	return CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		policy
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
