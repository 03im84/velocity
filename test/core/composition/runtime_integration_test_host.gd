extends RefCounted


## Transaction-observable RuntimeHost for CompositionRuntime integration tests.


var _trace: Object
var _attach_failures: Dictionary[String, bool] = {}
var _detach_failures: Dictionary[String, bool] = {}
var _attached_handle_ids: Dictionary[int, bool] = {}


func _init(
	trace: Object
) -> void:

	_trace = trace


func add_failure(
	phase: StringName,
	device_id: String
) -> void:

	if phase == &"attach":
		_attach_failures[device_id] = true
	elif phase == &"detach":
		_detach_failures[device_id] = true


func attach(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null or not handle.is_valid():
		_add_error(
			report,
			&"runtime_integration_host_handle_invalid",
			"RuntimeDeviceHandle is invalid.",
			"",
			&"attach"
		)
		return report

	var handle_id: int = handle.get_instance_id()

	if _attached_handle_ids.has(handle_id):
		return report

	var device_id: String = handle.get_device_id()

	_record(
		"attach:" + device_id
	)

	if _attach_failures.has(device_id):
		_add_error(
			report,
			&"runtime_integration_host_attach_failed",
			"Controlled RuntimeHost attach failure.",
			device_id,
			&"attach"
		)
		return report

	for host_object: Object in handle.get_host_objects():
		_mark(
			host_object,
			&"mark_attached"
		)

	_attached_handle_ids[handle_id] = true

	return report


func detach(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null or not handle.is_valid():
		_add_error(
			report,
			&"runtime_integration_host_handle_invalid",
			"RuntimeDeviceHandle is invalid.",
			"",
			&"detach"
		)
		return report

	var handle_id: int = handle.get_instance_id()

	if not _attached_handle_ids.has(handle_id):
		return report

	_attached_handle_ids.erase(handle_id)

	var host_objects := handle.get_host_objects()

	for host_index: int in range(
		host_objects.size() - 1,
		-1,
		-1
	):
		_mark(
			host_objects[host_index],
			&"mark_detached"
		)

	var device_id: String = handle.get_device_id()

	_record(
		"detach:" + device_id
	)

	if _detach_failures.has(device_id):
		_add_error(
			report,
			&"runtime_integration_host_detach_failed",
			"Controlled RuntimeHost detach failure.",
			device_id,
			&"detach"
		)

	return report


func get_attached_count(
) -> int:

	return _attached_handle_ids.size()


func _mark(
	value: Object,
	method_name: StringName
) -> void:

	if value == null or not is_instance_valid(value):
		return

	if value.has_method(method_name):
		value.call(method_name)


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
