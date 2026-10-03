extends RefCounted


## Transaction-observable lifecycle adapter for CompositionRuntime integration tests.


var _trace: Object
var _failures: Dictionary[String, bool] = {}
var _shutdown_handle_ids: Dictionary[int, bool] = {}


func _init(
	trace: Object
) -> void:

	_trace = trace


func add_failure(
	phase: StringName,
	device_id: String
) -> void:

	_failures[
		_failure_key(
			phase,
			device_id
		)
	] = true


func initialize(
	handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
) -> ValidationReport:

	if device_bus == null:
		return _invalid_input_report(
			&"initialize"
		)

	return _phase_report(
		&"initialize",
		handle
	)


func set_ready(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	return _phase_report(
		&"ready",
		handle
	)


func start(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	return _phase_report(
		&"start",
		handle
	)


func shutdown(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null or not handle.is_valid():
		_add_error(
			report,
			&"runtime_integration_lifecycle_input_invalid",
			"Lifecycle input is invalid.",
			"",
			&"shutdown"
		)
		return report

	var handle_id: int = handle.get_instance_id()

	if _shutdown_handle_ids.has(handle_id):
		return report

	_shutdown_handle_ids[handle_id] = true

	var device_id: String = handle.get_device_id()

	_record(
		"shutdown:" + device_id
	)

	if _should_fail(
		&"shutdown",
		device_id
	):
		_add_error(
			report,
			&"runtime_integration_lifecycle_shutdown_failed",
			"Controlled lifecycle shutdown failure.",
			device_id,
			&"shutdown"
		)

	return report


func get_shutdown_count(
) -> int:

	return _shutdown_handle_ids.size()


func _phase_report(
	phase: StringName,
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null or not handle.is_valid():
		_add_error(
			report,
			&"runtime_integration_lifecycle_input_invalid",
			"Lifecycle input is invalid.",
			"",
			phase
		)
		return report

	var device_id: String = handle.get_device_id()

	_record(
		String(phase) + ":" + device_id
	)

	if _should_fail(
		phase,
		device_id
	):
		_add_error(
			report,
			&"runtime_integration_lifecycle_phase_failed",
			"Controlled lifecycle phase failure.",
			device_id,
			phase
		)

	return report


func _invalid_input_report(
	phase: StringName
) -> ValidationReport:

	var report := ValidationReport.new()

	_add_error(
		report,
		&"runtime_integration_lifecycle_input_invalid",
		"Lifecycle input is invalid.",
		"",
		phase
	)

	return report


func _should_fail(
	phase: StringName,
	device_id: String
) -> bool:

	return _failures.has(
		_failure_key(
			phase,
			device_id
		)
	)


func _failure_key(
	phase: StringName,
	device_id: String
) -> String:

	return String(phase) + ":" + device_id


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
	device_id: String,
	field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			message,
			device_id,
			field
		)
	)
