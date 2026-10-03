extends RefCounted


## Transaction-observable communication binder for CompositionRuntime integration tests.


var _trace: Object
var _bind_failures: Dictionary[StringName, bool] = {}
var _unbind_failures: Dictionary[StringName, bool] = {}
var _bound_connection_ids: Dictionary[StringName, bool] = {}


func _init(
	trace: Object
) -> void:

	_trace = trace


func add_failure(
	phase: StringName,
	connection_id: StringName
) -> void:

	if phase == &"bind":
		_bind_failures[connection_id] = true
	elif phase == &"unbind":
		_unbind_failures[connection_id] = true


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
		device_bus,
		&"bind"
	)

	if not report.is_valid_for_simulation():
		return report

	var connection_id := directive.get_connection_id()

	if _bound_connection_ids.has(connection_id):
		return report

	_record(
		"bind:" + String(connection_id)
	)

	if _bind_failures.has(connection_id):
		_add_error(
			report,
			&"runtime_integration_binder_bind_failed",
			"Controlled communication bind failure.",
			connection_id,
			&"bind"
		)
		return report

	_bound_connection_ids[connection_id] = true

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
		device_bus,
		&"unbind"
	)

	if not report.is_valid_for_simulation():
		return report

	var connection_id := directive.get_connection_id()

	if not _bound_connection_ids.has(connection_id):
		return report

	_bound_connection_ids.erase(connection_id)

	_record(
		"unbind:" + String(connection_id)
	)

	if _unbind_failures.has(connection_id):
		_add_error(
			report,
			&"runtime_integration_binder_unbind_failed",
			"Controlled communication unbind failure.",
			connection_id,
			&"unbind"
		)

	return report


func get_bound_count(
) -> int:

	return _bound_connection_ids.size()


func _validate_inputs(
	directive: CompositionConnectionDirective,
	source_handle: RuntimeDeviceHandle,
	target_handle: RuntimeDeviceHandle,
	device_bus: DeviceBus,
	field: StringName
) -> ValidationReport:

	var report := ValidationReport.new()

	if (
		directive == null
		or source_handle == null
		or target_handle == null
		or device_bus == null
	):
		_add_error(
			report,
			&"runtime_integration_binder_input_invalid",
			"Communication binder input is invalid.",
			&"",
			field
		)

	return report


func _record(
	event: String
) -> void:

	if _trace != null and _trace.has_method(
		&"record_event"
	):
		_trace.call(
			&"record_event",
			event
		)


func _add_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	connection_id: StringName,
	field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			message,
			String(connection_id),
			field
		)
	)
