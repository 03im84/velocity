extends RefCounted


## Controlled lifecycle adapter for CompositionRuntime tests.


var _fail_phase: StringName = &""
var _fail_device_id: String = ""
var _event_order: Array[String] = []
var _shutdown_handle_ids: Dictionary[int, bool] = {}


func set_failure(
	phase: StringName,
	device_id: String = ""
) -> void:

	_fail_phase = phase
	_fail_device_id = device_id


func initialize(
	handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
) -> ValidationReport:

	return _record_phase(
		&"initialize",
		handle,
		device_bus != null
	)


func set_ready(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	return _record_phase(
		&"ready",
		handle,
		true
	)


func start(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	return _record_phase(
		&"start",
		handle,
		true
	)


func shutdown(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null:
		_add_error(
			report,
			&"test_lifecycle_handle_missing",
			"RuntimeDeviceHandle is required.",
			""
		)
		return report

	var handle_id: int = handle.get_instance_id()

	if _shutdown_handle_ids.has(handle_id):
		return report

	_shutdown_handle_ids[handle_id] = true

	_event_order.append(
		"shutdown:" + handle.get_device_id()
	)

	if _should_fail(
		&"shutdown",
		handle.get_device_id()
	):
		_add_error(
			report,
			&"test_lifecycle_shutdown_failed",
			"Controlled lifecycle shutdown failure.",
			handle.get_device_id()
		)

	return report


func get_event_order(
) -> Array[String]:

	return _event_order.duplicate()


func _record_phase(
	phase: StringName,
	handle: RuntimeDeviceHandle,
	precondition: bool
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null or not precondition:
		_add_error(
			report,
			&"test_lifecycle_input_invalid",
			"Lifecycle input is invalid.",
			""
		)
		return report

	_event_order.append(
		String(phase) + ":" + handle.get_device_id()
	)

	if _should_fail(
		phase,
		handle.get_device_id()
	):
		_add_error(
			report,
			&"test_lifecycle_phase_failed",
			"Controlled lifecycle phase failure.",
			handle.get_device_id()
		)

	return report


func _should_fail(
	phase: StringName,
	device_id: String
) -> bool:

	return (
		phase == _fail_phase
		and (
			_fail_device_id.is_empty()
			or _fail_device_id == device_id
		)
	)


func _add_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	device_id: String
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			message,
			device_id,
			&"lifecycle"
		)
	)
