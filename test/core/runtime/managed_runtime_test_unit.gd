extends RefCounted


## Controlled managed runtime unit for adapter tests.


var _device_id: String
var _events: Array[String] = []
var _fail_phase: StringName = &""
var _invalid_report_phase: StringName = &""
var _endpoints: Dictionary[StringName, Callable] = {}
var _received_messages: Array[BusMessage] = []
var _shutdown_complete: bool = false
var _last_report: ValidationReport


func _init(
	device_id: String
) -> void:

	_device_id = device_id


func set_failure(
	phase: StringName
) -> void:

	_fail_phase = phase


func set_invalid_report_phase(
	phase: StringName
) -> void:

	_invalid_report_phase = phase


func register_endpoint(
	port_id: StringName,
	endpoint: Callable
) -> void:

	_endpoints[port_id] = endpoint


func runtime_initialize(
	device_bus: DeviceBus
) -> Variant:

	return _lifecycle_result(
		&"initialize",
		device_bus != null
	)


func runtime_set_ready(
) -> Variant:

	return _lifecycle_result(
		&"ready",
		true
	)


func runtime_start(
) -> Variant:

	return _lifecycle_result(
		&"start",
		true
	)


func runtime_shutdown(
) -> Variant:

	var report := ValidationReport.new()
	_last_report = report

	if _shutdown_complete:
		return report

	_shutdown_complete = true
	_events.append(
		"shutdown:" + _device_id
	)

	if _invalid_report_phase == &"shutdown":
		return false

	if _fail_phase == &"shutdown":
		_add_error(
			report,
			&"managed_runtime_test_phase_failed",
			&"shutdown"
		)

	return report


func get_runtime_input_endpoint(
	port_id: StringName
) -> Variant:

	return _endpoints.get(
		port_id,
		Callable()
	)


func receive_message(
	message: BusMessage
) -> void:

	_received_messages.append(message)


func get_received_messages(
) -> Array[BusMessage]:

	return _received_messages.duplicate()


func get_events(
) -> Array[String]:

	return _events.duplicate()


func get_last_report(
) -> ValidationReport:

	return _last_report


func _lifecycle_result(
	phase: StringName,
	precondition: bool
) -> Variant:

	var report := ValidationReport.new()
	_last_report = report

	_events.append(
		String(phase) + ":" + _device_id
	)

	if phase == _invalid_report_phase:
		return false

	if not precondition or phase == _fail_phase:
		_add_error(
			report,
			&"managed_runtime_test_phase_failed",
			phase
		)

	return report


func _add_error(
	report: ValidationReport,
	code: StringName,
	field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Controlled managed runtime phase failure.",
			_device_id,
			field
		)
	)
