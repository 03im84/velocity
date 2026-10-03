extends RefCounted
class_name CompositionRuntime


##
## CompositionRuntime
##
## Owner one-shot de una composición
## runtime Simulation.
##
## Coordina activation, rollback y shutdown.
##


enum State {
	CREATED,
	ACTIVATING,
	ACTIVE,
	SHUTTING_DOWN,
	SHUTDOWN,
	FAILED,
}


var _factory_registry: RuntimeFactoryRegistry
var _dependency_value_resolver: Object
var _runtime_host: Object
var _lifecycle_adapter: Object
var _communication_binder: Object

var _state: State = State.CREATED
var _active_plan: CompositionPlan
var _device_bus: DeviceBus
var _handles: Array[RuntimeDeviceHandle] = []


func _init(
	factory_registry: RuntimeFactoryRegistry,
	dependency_value_resolver: Object,
	runtime_host: Object,
	lifecycle_adapter: Object,
	communication_binder: Object
) -> void:

	_factory_registry = factory_registry
	_dependency_value_resolver = dependency_value_resolver
	_runtime_host = runtime_host
	_lifecycle_adapter = lifecycle_adapter
	_communication_binder = communication_binder


# =============================================================================
# ACTIVATION
# =============================================================================

func activate(
	plan: CompositionPlan
) -> CompositionRuntimeOperationResult:

	var report := ValidationReport.new()

	if _state != State.CREATED:
		_add_structural_error(
			report,
			&"composition_runtime_state_invalid",
			"CompositionRuntime is not in CREATED state.",
			"",
			&"state"
		)
		return _operation_result(
			false,
			CompositionRuntimeOperationResult.OPERATION_ACTIVATE,
			report
		)

	_state = State.ACTIVATING

	var resolved_values: Dictionary[String, Dictionary] = {}

	if not _preflight(
		plan,
		resolved_values,
		report
	):
		_state = State.FAILED
		return _operation_result(
			false,
			CompositionRuntimeOperationResult.OPERATION_ACTIVATE,
			report
		)

	var candidate_bus := DeviceBus.new()

	if not candidate_bus.configure_dispatch_policy(
		plan.get_dispatch_policy()
	):
		_add_platform_error(
			report,
			&"composition_runtime_bus_policy_rejected",
			"DeviceBus rejected Dispatch Policy.",
			"",
			&"dispatch_policy"
		)
		_state = State.FAILED
		return _operation_result(
			false,
			CompositionRuntimeOperationResult.OPERATION_ACTIVATE,
			report
		)

	var built_handles: Array[RuntimeDeviceHandle] = []
	var attached_handles: Array[RuntimeDeviceHandle] = []
	var bound_directives: Array[CompositionConnectionDirective] = []
	var initialized_handles: Array[RuntimeDeviceHandle] = []

	if not _build_all(
		plan,
		resolved_values,
		built_handles,
		report
	):
		_rollback_candidate(
			candidate_bus,
			built_handles,
			attached_handles,
			bound_directives,
			initialized_handles,
			report
		)
		return _activation_failed(report)

	if not _attach_all(
		plan,
		built_handles,
		attached_handles,
		report
	):
		_rollback_candidate(
			candidate_bus,
			built_handles,
			attached_handles,
			bound_directives,
			initialized_handles,
			report
		)
		return _activation_failed(report)

	if not _bind_all(
		plan,
		candidate_bus,
		built_handles,
		bound_directives,
		report
	):
		_rollback_candidate(
			candidate_bus,
			built_handles,
			attached_handles,
			bound_directives,
			initialized_handles,
			report
		)
		return _activation_failed(report)

	if not _initialize_all(
		plan,
		candidate_bus,
		built_handles,
		initialized_handles,
		report
	):
		_rollback_candidate(
			candidate_bus,
			built_handles,
			attached_handles,
			bound_directives,
			initialized_handles,
			report
		)
		return _activation_failed(report)

	if not _ready_all(
		plan,
		built_handles,
		report
	):
		_rollback_candidate(
			candidate_bus,
			built_handles,
			attached_handles,
			bound_directives,
			initialized_handles,
			report
		)
		return _activation_failed(report)

	if not _start_all(
		plan,
		built_handles,
		report
	):
		_rollback_candidate(
			candidate_bus,
			built_handles,
			attached_handles,
			bound_directives,
			initialized_handles,
			report
		)
		return _activation_failed(report)

	_active_plan = plan
	_device_bus = candidate_bus
	_handles = built_handles.duplicate()
	_state = State.ACTIVE

	return _operation_result(
		true,
		CompositionRuntimeOperationResult.OPERATION_ACTIVATE,
		report
	)


# =============================================================================
# SHUTDOWN
# =============================================================================

func shutdown(
) -> CompositionRuntimeOperationResult:

	var report := ValidationReport.new()

	if _state != State.ACTIVE:
		_add_structural_error(
			report,
			&"composition_runtime_state_invalid",
			"CompositionRuntime is not in ACTIVE state.",
			"",
			&"state"
		)
		return _operation_result(
			false,
			CompositionRuntimeOperationResult.OPERATION_SHUTDOWN,
			report
		)

	_state = State.SHUTTING_DOWN

	var active_handles := _handles.duplicate()
	var active_directives := _active_plan.get_connection_directives()
	var active_bus := _device_bus

	_rollback_candidate(
		active_bus,
		active_handles,
		active_handles,
		active_directives,
		active_handles,
		report
	)

	_active_plan = null
	_device_bus = null
	_handles.clear()

	var success: bool = report.is_valid_for_simulation()

	_state = (
		State.SHUTDOWN
		if success
		else State.FAILED
	)

	return _operation_result(
		success,
		CompositionRuntimeOperationResult.OPERATION_SHUTDOWN,
		report
	)


# =============================================================================
# QUERY API
# =============================================================================

func get_state(
) -> State:

	return _state


func is_active(
) -> bool:

	return _state == State.ACTIVE


func get_active_plan(
) -> CompositionPlan:

	if not is_active():
		return null

	return _active_plan


func get_device_bus(
) -> DeviceBus:

	if not is_active():
		return null

	return _device_bus


func get_handles(
) -> Array[RuntimeDeviceHandle]:

	if not is_active():
		var empty_handles: Array[RuntimeDeviceHandle] = []
		return empty_handles

	return _handles.duplicate()


func get_handle(
	device_id: String
) -> RuntimeDeviceHandle:

	if not is_active():
		return null

	if device_id.is_empty():
		return null

	return _get_handle_from(
		_handles,
		device_id
	)


func get_last_dispatch_report(
) -> DeviceBusDispatchReport:

	if _device_bus == null:
		return null

	return _device_bus.get_last_dispatch_report()


# =============================================================================
# PREFLIGHT
# =============================================================================

func _preflight(
	plan: CompositionPlan,
	resolved_values: Dictionary[String, Dictionary],
	report: ValidationReport
) -> bool:

	if plan == null:
		_add_structural_error(
			report,
			&"composition_runtime_plan_missing",
			"CompositionPlan is required.",
			"",
			&"plan"
		)
		return false

	if not plan.is_valid():
		_add_structural_error(
			report,
			&"composition_runtime_plan_invalid",
			"CompositionPlan is invalid.",
			"",
			&"plan"
		)
		return false

	if (
		plan.get_activation_context()
		== DeviceConfiguration.ActivationContext.HARDWARE
	):
		_add_issue(
			report,
			&"composition_runtime_hardware_not_supported",
			ValidationIssue.Severity.HARDWARE_SAFETY_ERROR,
			"Hardware CompositionRuntime is not supported.",
			"",
			&"activation_context"
		)
		return false

	if _factory_registry == null:
		_add_structural_error(
			report,
			&"composition_runtime_registry_missing",
			"RuntimeFactoryRegistry is required.",
			"",
			&"factory_registry"
		)
		return false

	if not _factory_registry.is_valid():
		_add_structural_error(
			report,
			&"composition_runtime_registry_invalid",
			"RuntimeFactoryRegistry is invalid.",
			"",
			&"factory_registry"
		)
		return false

	if not _collaborators_are_valid(report):
		return false

	for entry: CompositionDeviceEntry in plan.get_device_entries():

		var factory_key := entry.get_factory_key()
		var device_id: String = entry.get_device_id()

		if not _factory_registry.has_factory(factory_key):
			_add_structural_error(
				report,
				&"composition_runtime_factory_missing",
				"Exact RuntimeFactoryDescriptor is not available.",
				device_id,
				&"factory_key"
			)
			continue

		var descriptor := _factory_registry.get_descriptor(
			factory_key
		)

		if (
			descriptor == null
			or not descriptor.is_valid()
		):
			_add_structural_error(
				report,
				&"composition_runtime_descriptor_invalid",
				"RuntimeFactoryDescriptor is invalid.",
				device_id,
				&"factory_descriptor"
			)
			continue

		if not _dependency_specs_match(
			entry.get_dependency_specs(),
			descriptor.get_dependency_specs()
		):
			_add_structural_error(
				report,
				&"composition_runtime_dependency_specs_mismatch",
				"Plan and Registry Dependency Specs do not match.",
				device_id,
				&"dependency_specs"
			)
			continue

		_resolve_entry_values(
			entry,
			resolved_values,
			report
		)

	return report.is_valid_for_simulation()


func _collaborators_are_valid(
	report: ValidationReport
) -> bool:

	var valid: bool = true

	var resolver_methods: Array[StringName] = [
		&"has_value",
		&"get_value",
	]

	var host_methods: Array[StringName] = [
		&"attach",
		&"detach",
	]

	var lifecycle_methods: Array[StringName] = [
		&"initialize",
		&"set_ready",
		&"start",
		&"shutdown",
	]

	var binder_methods: Array[StringName] = [
		&"bind",
		&"unbind",
	]

	valid = _validate_behavior(
		_dependency_value_resolver,
		resolver_methods,
		&"composition_runtime_dependency_resolver_missing",
		&"composition_runtime_dependency_resolver_contract_invalid",
		&"dependency_value_resolver",
		report
	) and valid

	valid = _validate_behavior(
		_runtime_host,
		host_methods,
		&"composition_runtime_host_missing",
		&"composition_runtime_host_contract_invalid",
		&"runtime_host",
		report
	) and valid

	valid = _validate_behavior(
		_lifecycle_adapter,
		lifecycle_methods,
		&"composition_runtime_lifecycle_adapter_missing",
		&"composition_runtime_lifecycle_adapter_contract_invalid",
		&"lifecycle_adapter",
		report
	) and valid

	valid = _validate_behavior(
		_communication_binder,
		binder_methods,
		&"composition_runtime_communication_binder_missing",
		&"composition_runtime_communication_binder_contract_invalid",
		&"communication_binder",
		report
	) and valid

	return valid


func _validate_behavior(
	target: Object,
	methods: Array[StringName],
	missing_code: StringName,
	contract_code: StringName,
	field: StringName,
	report: ValidationReport
) -> bool:

	if target == null:
		_add_structural_error(
			report,
			missing_code,
			"Required Runtime collaborator is missing.",
			"",
			field
		)
		return false

	if not is_instance_valid(target):
		_add_structural_error(
			report,
			contract_code,
			"Runtime collaborator instance is invalid.",
			"",
			field
		)
		return false

	for method_name: StringName in methods:
		if not target.has_method(method_name):
			_add_structural_error(
				report,
				contract_code,
				"Runtime collaborator contract is incomplete.",
				String(method_name),
				field
			)
			return false

	return true


func _resolve_entry_values(
	entry: CompositionDeviceEntry,
	resolved_values: Dictionary[String, Dictionary],
	report: ValidationReport
) -> void:

	var device_id: String = entry.get_device_id()
	var values: Dictionary = {}

	for spec: RuntimeDependencySpec in entry.get_dependency_specs():

		var dependency_id: StringName = spec.get_dependency_id()

		var availability: Variant = _dependency_value_resolver.call(
			&"has_value",
			device_id,
			dependency_id
		)

		if typeof(availability) != TYPE_BOOL:
			_add_structural_error(
				report,
				&"composition_runtime_dependency_availability_invalid",
				"Dependency Resolver returned invalid availability.",
				device_id,
				dependency_id
			)
			continue

		if not bool(availability):
			_add_structural_error(
				report,
				&"composition_runtime_dependency_missing",
				"Required Dependency Value is not available.",
				device_id,
				dependency_id
			)
			continue

		var value_variant: Variant = _dependency_value_resolver.call(
			&"get_value",
			device_id,
			dependency_id
		)

		var value: Object = value_variant as Object

		if (
			value == null
			or not is_instance_valid(value)
		):
			_add_structural_error(
				report,
				&"composition_runtime_dependency_value_invalid",
				"Resolved Dependency Value is invalid.",
				device_id,
				dependency_id
			)
			continue

		values[dependency_id] = value

	resolved_values[device_id] = values


# =============================================================================
# BUILD STAGE
# =============================================================================

func _build_all(
	plan: CompositionPlan,
	resolved_values: Dictionary[String, Dictionary],
	built_handles: Array[RuntimeDeviceHandle],
	report: ValidationReport
) -> bool:

	for device_id: String in plan.get_construction_order():

		var entry := plan.get_device_entry(device_id)
		var descriptor := _factory_registry.get_descriptor(
			entry.get_factory_key()
		)
		var factory := descriptor.get_factory()

		var bindings := _create_bindings(
			entry,
			resolved_values,
			report
		)

		if not report.is_valid_for_simulation():
			return false

		var request := RuntimeConstructionRequest.new(
			entry.get_device_id(),
			entry.get_configuration(),
			entry.get_factory_key(),
			bindings
		)

		if not request.is_valid():
			_add_structural_error(
				report,
				&"composition_runtime_request_invalid",
				"RuntimeConstructionRequest is invalid.",
				device_id,
				&"request"
			)
			return false

		var result_value: Variant = factory.call(
			&"build",
			request
		)

		var build_result: RuntimeFactoryBuildResult = (
			result_value as RuntimeFactoryBuildResult
		)

		if build_result == null:
			_add_platform_error(
				report,
				&"composition_runtime_factory_build_result_missing",
				"RuntimeFactory returned invalid Build Result.",
				device_id,
				&"build_result"
			)
			return false

		_merge_report(
			report,
			build_result.get_report(),
			device_id,
			&"build_report"
		)

		if not build_result.is_success():
			if report.is_valid_for_simulation():
				_add_structural_error(
					report,
					&"composition_runtime_factory_build_failed",
					"RuntimeFactory build failed.",
					device_id,
					&"factory"
				)
			return false

		var handle := build_result.get_handle()

		if (
			handle == null
			or not handle.is_valid()
		):
			_add_structural_error(
				report,
				&"composition_runtime_handle_invalid",
				"RuntimeFactory produced invalid Handle.",
				device_id,
				&"handle"
			)
			return false

		if (
			handle.get_device_id() != entry.get_device_id()
			or handle.get_configuration()
			!= entry.get_configuration()
			or not handle.get_factory_key().equals(
				entry.get_factory_key()
			)
		):
			_add_structural_error(
				report,
				&"composition_runtime_handle_identity_mismatch",
				"RuntimeDeviceHandle identity does not match Entry.",
				device_id,
				&"handle"
			)
			return false

		built_handles.append(handle)

	return true


func _create_bindings(
	entry: CompositionDeviceEntry,
	resolved_values: Dictionary[String, Dictionary],
	report: ValidationReport
) -> Array[RuntimeDependencyBinding]:

	var bindings: Array[RuntimeDependencyBinding] = []
	var values: Dictionary = resolved_values.get(
		entry.get_device_id(),
		{}
	)

	for spec: RuntimeDependencySpec in entry.get_dependency_specs():

		var dependency_id := spec.get_dependency_id()
		var value: Object = values.get(
			dependency_id,
			null
		)

		var binding := RuntimeDependencyBinding.new(
			dependency_id,
			value,
			spec.get_ownership()
		)

		if not binding.is_valid():
			_add_structural_error(
				report,
				&"composition_runtime_binding_invalid",
				"RuntimeDependencyBinding is invalid.",
				entry.get_device_id(),
				dependency_id
			)
			continue

		bindings.append(binding)

	return bindings


# =============================================================================
# ATTACH STAGE
# =============================================================================

func _attach_all(
	plan: CompositionPlan,
	built_handles: Array[RuntimeDeviceHandle],
	attached_handles: Array[RuntimeDeviceHandle],
	report: ValidationReport
) -> bool:

	for device_id: String in plan.get_attach_order():

		var handle := _get_handle_from(
			built_handles,
			device_id
		)

		if not _invoke_report(
			_runtime_host,
			&"attach",
			[handle],
			report,
			device_id,
			&"host_attach"
		):
			return false

		attached_handles.append(handle)

	return true


# =============================================================================
# COMMUNICATION STAGE
# =============================================================================

func _bind_all(
	plan: CompositionPlan,
	candidate_bus: DeviceBus,
	built_handles: Array[RuntimeDeviceHandle],
	bound_directives: Array[CompositionConnectionDirective],
	report: ValidationReport
) -> bool:

	for directive: CompositionConnectionDirective in plan.get_connection_directives():

		var source_handle := _get_handle_from(
			built_handles,
			directive.get_source_device_id()
		)

		var target_handle := _get_handle_from(
			built_handles,
			directive.get_target_device_id()
		)

		if not _invoke_report(
			_communication_binder,
			&"bind",
			[
				directive,
				source_handle,
				target_handle,
				candidate_bus,
			],
			report,
			String(directive.get_connection_id()),
			&"communication_bind"
		):
			return false

		bound_directives.append(directive)

	return true


# =============================================================================
# LIFECYCLE STAGES
# =============================================================================

func _initialize_all(
	plan: CompositionPlan,
	candidate_bus: DeviceBus,
	built_handles: Array[RuntimeDeviceHandle],
	initialized_handles: Array[RuntimeDeviceHandle],
	report: ValidationReport
) -> bool:

	for device_id: String in plan.get_initialization_order():

		var handle := _get_handle_from(
			built_handles,
			device_id
		)

		initialized_handles.append(handle)

		if not _invoke_report(
			_lifecycle_adapter,
			&"initialize",
			[handle, candidate_bus],
			report,
			device_id,
			&"initialize"
		):
			return false

	return true


func _ready_all(
	plan: CompositionPlan,
	built_handles: Array[RuntimeDeviceHandle],
	report: ValidationReport
) -> bool:

	for device_id: String in plan.get_ready_order():

		var handle := _get_handle_from(
			built_handles,
			device_id
		)

		if not _invoke_report(
			_lifecycle_adapter,
			&"set_ready",
			[handle],
			report,
			device_id,
			&"ready"
		):
			return false

	return true


func _start_all(
	plan: CompositionPlan,
	built_handles: Array[RuntimeDeviceHandle],
	report: ValidationReport
) -> bool:

	for device_id: String in plan.get_start_order():

		var handle := _get_handle_from(
			built_handles,
			device_id
		)

		if not _invoke_report(
			_lifecycle_adapter,
			&"start",
			[handle],
			report,
			device_id,
			&"start"
		):
			return false

	return true


# =============================================================================
# ROLLBACK
# =============================================================================

func _rollback_candidate(
	candidate_bus: DeviceBus,
	built_handles: Array[RuntimeDeviceHandle],
	attached_handles: Array[RuntimeDeviceHandle],
	bound_directives: Array[CompositionConnectionDirective],
	initialized_handles: Array[RuntimeDeviceHandle],
	report: ValidationReport
) -> void:

	for handle_index: int in range(
		initialized_handles.size() - 1,
		-1,
		-1
	):
		var handle := initialized_handles[handle_index]
		_invoke_report(
			_lifecycle_adapter,
			&"shutdown",
			[handle],
			report,
			handle.get_device_id(),
			&"shutdown"
		)

	for directive_index: int in range(
		bound_directives.size() - 1,
		-1,
		-1
	):
		var directive := bound_directives[directive_index]
		var source_handle := _get_handle_from(
			built_handles,
			directive.get_source_device_id()
		)
		var target_handle := _get_handle_from(
			built_handles,
			directive.get_target_device_id()
		)
		_invoke_report(
			_communication_binder,
			&"unbind",
			[
				directive,
				source_handle,
				target_handle,
				candidate_bus,
			],
			report,
			String(directive.get_connection_id()),
			&"communication_unbind"
		)

	for handle_index: int in range(
		attached_handles.size() - 1,
		-1,
		-1
	):
		var handle := attached_handles[handle_index]
		_invoke_report(
			_runtime_host,
			&"detach",
			[handle],
			report,
			handle.get_device_id(),
			&"host_detach"
		)

	for handle_index: int in range(
		built_handles.size() - 1,
		-1,
		-1
	):
		var handle := built_handles[handle_index]
		_release_handle(
			handle,
			report
		)

	if candidate_bus != null:
		candidate_bus.clear()


func _release_handle(
	handle: RuntimeDeviceHandle,
	report: ValidationReport
) -> void:

	var descriptor := _factory_registry.get_descriptor(
		handle.get_factory_key()
	)

	if descriptor == null:
		_add_platform_error(
			report,
			&"composition_runtime_factory_release_failed",
			"Factory Descriptor is unavailable during release.",
			handle.get_device_id(),
			&"factory"
		)
		return

	_invoke_report(
		descriptor.get_factory(),
		&"release",
		[handle],
		report,
		handle.get_device_id(),
		&"factory_release"
	)


# =============================================================================
# INVOCATION AND REPORTS
# =============================================================================

func _invoke_report(
	target: Object,
	method_name: StringName,
	arguments: Array,
	report: ValidationReport,
	related_object_id: String,
	related_field: StringName
) -> bool:

	var report_value: Variant = target.callv(
		method_name,
		arguments
	)

	var operation_report: ValidationReport = (
		report_value as ValidationReport
	)

	if operation_report == null:
		_add_platform_error(
			report,
			&"composition_runtime_report_missing",
			"Runtime collaborator returned invalid ValidationReport.",
			related_object_id,
			related_field
		)
		return false

	_merge_report(
		report,
		operation_report,
		related_object_id,
		related_field
	)

	return operation_report.is_valid_for_simulation()


func _merge_report(
	target: ValidationReport,
	source: ValidationReport,
	related_object_id: String,
	related_field: StringName
) -> void:

	if source == null:
		_add_platform_error(
			target,
			&"composition_runtime_report_missing",
			"Runtime operation returned null ValidationReport.",
			related_object_id,
			related_field
		)
		return

	for issue: ValidationIssue in source.get_issues():
		target.add_issue(issue)


# =============================================================================
# HELPERS
# =============================================================================

func _dependency_specs_match(
	entry_specs: Array[RuntimeDependencySpec],
	descriptor_specs: Array[RuntimeDependencySpec]
) -> bool:

	if entry_specs.size() != descriptor_specs.size():
		return false

	for spec_index: int in range(entry_specs.size()):
		var entry_spec := entry_specs[spec_index]
		var descriptor_spec := descriptor_specs[spec_index]

		if entry_spec == null or descriptor_spec == null:
			return false

		if (
			entry_spec.get_dependency_id()
			!= descriptor_spec.get_dependency_id()
			or entry_spec.get_ownership()
			!= descriptor_spec.get_ownership()
		):
			return false

	return true


func _get_handle_from(
	handles: Array[RuntimeDeviceHandle],
	device_id: String
) -> RuntimeDeviceHandle:

	for handle: RuntimeDeviceHandle in handles:
		if handle != null and handle.get_device_id() == device_id:
			return handle

	return null


func _operation_result(
	success: bool,
	operation: StringName,
	report: ValidationReport
) -> CompositionRuntimeOperationResult:

	return CompositionRuntimeOperationResult.new(
		success,
		operation,
		report
	)


func _activation_failed(
	report: ValidationReport
) -> CompositionRuntimeOperationResult:

	_active_plan = null
	_device_bus = null
	_handles.clear()
	_state = State.FAILED

	return _operation_result(
		false,
		CompositionRuntimeOperationResult.OPERATION_ACTIVATE,
		report
	)


func _add_structural_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> void:

	_add_issue(
		report,
		code,
		ValidationIssue.Severity.STRUCTURAL_ERROR,
		message,
		related_object_id,
		related_field
	)


func _add_platform_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> void:

	_add_issue(
		report,
		code,
		ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
		message,
		related_object_id,
		related_field
	)


func _add_issue(
	report: ValidationReport,
	code: StringName,
	severity: int,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			severity,
			message,
			related_object_id,
			related_field
		)
	)
