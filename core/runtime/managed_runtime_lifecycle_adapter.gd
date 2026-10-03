extends RefCounted
class_name ManagedRuntimeLifecycleAdapter


##
## ManagedRuntimeLifecycleAdapter
##
## Delega lifecycle al behavior explícito
## del Primary Runtime Object de un Handle.
##


const METHOD_INITIALIZE: StringName = &"runtime_initialize"
const METHOD_READY: StringName = &"runtime_set_ready"
const METHOD_START: StringName = &"runtime_start"
const METHOD_SHUTDOWN: StringName = &"runtime_shutdown"


func initialize(
	handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
) -> ValidationReport:

	if device_bus == null:
		return _error_report(
			&"managed_runtime_lifecycle_bus_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"DeviceBus is required.",
			_handle_device_id(handle),
			&"device_bus"
		)

	return _invoke(
		handle,
		METHOD_INITIALIZE,
		[device_bus],
		&"initialize"
	)


func set_ready(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	return _invoke(
		handle,
		METHOD_READY,
		[],
		&"set_ready"
	)


func start(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	return _invoke(
		handle,
		METHOD_START,
		[],
		&"start"
	)


func shutdown(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	return _invoke(
		handle,
		METHOD_SHUTDOWN,
		[],
		&"shutdown"
	)


func _invoke(
	handle: RuntimeDeviceHandle,
	method_name: StringName,
	arguments: Array,
	related_field: StringName
) -> ValidationReport:

	var validation_report := _validate_handle(
		handle,
		method_name,
		related_field
	)

	if not validation_report.is_valid_for_simulation():
		return validation_report

	var primary := handle.get_primary_runtime_object()
	var result_value: Variant = primary.callv(
		method_name,
		arguments
	)

	if not (result_value is ValidationReport):
		return _error_report(
			&"managed_runtime_lifecycle_report_missing",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Managed lifecycle behavior returned invalid Report.",
			handle.get_device_id(),
			related_field
		)

	var operation_report: ValidationReport = result_value

	return operation_report


func _validate_handle(
	handle: RuntimeDeviceHandle,
	method_name: StringName,
	related_field: StringName
) -> ValidationReport:

	if handle == null:
		return _error_report(
			&"managed_runtime_lifecycle_handle_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"RuntimeDeviceHandle is required.",
			"",
			related_field
		)

	var primary := handle.get_primary_runtime_object()

	if primary == null:
		return _error_report(
			&"managed_runtime_lifecycle_primary_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Primary Runtime Object is required.",
			handle.get_device_id(),
			related_field
		)

	if not is_instance_valid(primary):
		return _error_report(
			&"managed_runtime_lifecycle_primary_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Primary Runtime Object instance is invalid.",
			handle.get_device_id(),
			related_field
		)

	if not handle.is_valid():
		return _error_report(
			&"managed_runtime_lifecycle_handle_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"RuntimeDeviceHandle is invalid.",
			handle.get_device_id(),
			related_field
		)

	if not primary.has_method(method_name):
		return _error_report(
			&"managed_runtime_lifecycle_behavior_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Primary Runtime Object lifecycle behavior is incomplete.",
			handle.get_device_id(),
			method_name
		)

	return ValidationReport.new()


func _handle_device_id(
	handle: RuntimeDeviceHandle
) -> String:

	if handle == null:
		return ""

	return handle.get_device_id()


func _error_report(
	code: StringName,
	severity: ValidationIssue.Severity,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> ValidationReport:

	var report := ValidationReport.new()

	report.add_issue(
		ValidationIssue.new(
			code,
			severity,
			message,
			related_object_id,
			related_field
		)
	)

	return report
