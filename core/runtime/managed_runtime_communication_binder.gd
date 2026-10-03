extends RefCounted
class_name ManagedRuntimeCommunicationBinder


##
## ManagedRuntimeCommunicationBinder
##
## Resuelve target endpoints explícitos y
## posee subscriptions filtradas por source.
##


const ENDPOINT_METHOD: StringName = (
	&"get_runtime_input_endpoint"
)


var _bindings: Dictionary[StringName, RuntimeSourceFilteredSubscription] = {}


func bind(
	directive: CompositionConnectionDirective,
	source_handle: RuntimeDeviceHandle,
	target_handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
) -> ValidationReport:

	var report := _validate_inputs(
		directive,
		source_handle,
		target_handle,
		device_bus
	)

	if not report.is_valid_for_simulation():
		return report

	var connection_id := directive.get_connection_id()

	if _bindings.has(connection_id):
		_add_error(
			report,
			&"managed_runtime_communication_duplicate_binding",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Connection is already bound.",
			String(connection_id),
			&"connection_id"
		)
		return report

	var target_primary := (
		target_handle.get_primary_runtime_object()
	)

	if target_primary == null:
		_add_error(
			report,
			&"managed_runtime_communication_primary_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Target Primary Runtime Object is required.",
			target_handle.get_device_id(),
			&"primary_runtime_object"
		)
		return report

	if not is_instance_valid(target_primary):
		_add_error(
			report,
			&"managed_runtime_communication_primary_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Target Primary Runtime Object instance is invalid.",
			target_handle.get_device_id(),
			&"primary_runtime_object"
		)
		return report

	if not target_primary.has_method(ENDPOINT_METHOD):
		_add_error(
			report,
			&"managed_runtime_communication_endpoint_behavior_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Target endpoint behavior is missing.",
			target_handle.get_device_id(),
			&"target_port_id"
		)
		return report

	var endpoint_value: Variant = target_primary.call(
		ENDPOINT_METHOD,
		directive.get_target_port_id()
	)

	if typeof(endpoint_value) != TYPE_CALLABLE:
		_add_error(
			report,
			&"managed_runtime_communication_endpoint_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Target endpoint is not a Callable.",
			target_handle.get_device_id(),
			directive.get_target_port_id()
		)
		return report

	var endpoint: Callable = endpoint_value

	if not endpoint.is_valid():
		_add_error(
			report,
			&"managed_runtime_communication_endpoint_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Target endpoint Callable is invalid.",
			target_handle.get_device_id(),
			directive.get_target_port_id()
		)
		return report

	var subscription := RuntimeSourceFilteredSubscription.new(
		directive.get_source_device_id(),
		directive.get_topic(),
		endpoint
	)

	if not subscription.is_valid():
		_add_error(
			report,
			&"managed_runtime_communication_endpoint_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Source-filtered Subscription is invalid.",
			String(connection_id),
			&"subscription"
		)
		return report

	if not device_bus.subscribe(
		directive.get_topic(),
		subscription.receive
	):
		_add_error(
			report,
			&"managed_runtime_communication_subscribe_failed",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"DeviceBus rejected runtime Subscription.",
			String(connection_id),
			&"device_bus"
		)
		return report

	_bindings[connection_id] = subscription

	return report


func unbind(
	directive: CompositionConnectionDirective,
	source_handle: RuntimeDeviceHandle,
	target_handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
) -> ValidationReport:

	var report := _validate_inputs(
		directive,
		source_handle,
		target_handle,
		device_bus
	)

	if not report.is_valid_for_simulation():
		return report

	var connection_id := directive.get_connection_id()

	if not _bindings.has(connection_id):
		return report

	var subscription: RuntimeSourceFilteredSubscription = (
		_bindings[connection_id]
	)

	if (
		subscription == null
		or not is_instance_valid(subscription)
	):
		_add_error(
			report,
			&"managed_runtime_communication_endpoint_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Stored runtime Subscription instance is invalid.",
			String(connection_id),
			&"subscription"
		)
		return report

	if not device_bus.unsubscribe(
		directive.get_topic(),
		subscription.receive
	):
		_add_error(
			report,
			&"managed_runtime_communication_unsubscribe_failed",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"DeviceBus rejected runtime Unsubscription.",
			String(connection_id),
			&"device_bus"
		)
		return report

	_bindings.erase(connection_id)

	return report


func has_binding(
	connection_id: StringName
) -> bool:

	if connection_id == &"":
		return false

	return _bindings.has(connection_id)


func get_binding_count(
) -> int:

	return _bindings.size()


func _validate_inputs(
	directive: CompositionConnectionDirective,
	source_handle: RuntimeDeviceHandle,
	target_handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
) -> ValidationReport:

	var report := ValidationReport.new()

	if directive == null:
		_add_error(
			report,
			&"managed_runtime_communication_directive_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"CompositionConnectionDirective is required.",
			"",
			&"directive"
		)
		return report

	if not directive.is_valid_identity():
		_add_error(
			report,
			&"managed_runtime_communication_directive_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"CompositionConnectionDirective is invalid.",
			String(directive.get_connection_id()),
			&"directive"
		)

	if source_handle == null:
		_add_error(
			report,
			&"managed_runtime_communication_source_handle_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Source RuntimeDeviceHandle is required.",
			directive.get_source_device_id(),
			&"source_handle"
		)
	elif not source_handle.is_valid():
		_add_error(
			report,
			&"managed_runtime_communication_source_handle_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Source RuntimeDeviceHandle is invalid.",
			directive.get_source_device_id(),
			&"source_handle"
		)

	if target_handle == null:
		_add_error(
			report,
			&"managed_runtime_communication_target_handle_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Target RuntimeDeviceHandle is required.",
			directive.get_target_device_id(),
			&"target_handle"
		)
	elif not target_handle.is_valid():
		_add_error(
			report,
			&"managed_runtime_communication_target_handle_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Target RuntimeDeviceHandle is invalid.",
			directive.get_target_device_id(),
			&"target_handle"
		)

	if device_bus == null:
		_add_error(
			report,
			&"managed_runtime_communication_bus_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"DeviceBus is required.",
			String(directive.get_connection_id()),
			&"device_bus"
		)

	if (
		source_handle != null
		and source_handle.get_device_id()
		!= directive.get_source_device_id()
	):
		_add_error(
			report,
			&"managed_runtime_communication_source_mismatch",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Source Handle identity does not match Directive.",
			source_handle.get_device_id(),
			&"source_device_id"
		)

	if (
		target_handle != null
		and target_handle.get_device_id()
		!= directive.get_target_device_id()
	):
		_add_error(
			report,
			&"managed_runtime_communication_target_mismatch",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Target Handle identity does not match Directive.",
			target_handle.get_device_id(),
			&"target_device_id"
		)

	return report


func _add_error(
	report: ValidationReport,
	code: StringName,
	severity: ValidationIssue.Severity,
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
