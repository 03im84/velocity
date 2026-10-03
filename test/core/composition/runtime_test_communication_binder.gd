extends RefCounted


## Controlled communication binder for CompositionRuntime tests.


var _fail_connection_id: StringName = &""
var _bound_connection_ids: Dictionary[StringName, bool] = {}
var _bind_order: Array[StringName] = []
var _unbind_order: Array[StringName] = []


func set_fail_connection_id(
	connection_id: StringName
) -> void:

	_fail_connection_id = connection_id


func bind(
	directive: CompositionConnectionDirective,
	source_handle: RuntimeDeviceHandle,
	target_handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
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
			&"test_binder_input_invalid",
			"Communication bind input is invalid.",
			&""
		)
		return report

	var connection_id := directive.get_connection_id()

	if connection_id == _fail_connection_id:
		_add_error(
			report,
			&"test_binder_bind_failed",
			"Controlled communication bind failure.",
			connection_id
		)
		return report

	if _bound_connection_ids.has(connection_id):
		return report

	_bound_connection_ids[connection_id] = true
	_bind_order.append(connection_id)

	return report


func unbind(
	directive: CompositionConnectionDirective,
	source_handle: RuntimeDeviceHandle,
	target_handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
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
			&"test_binder_input_invalid",
			"Communication unbind input is invalid.",
			&""
		)
		return report

	var connection_id := directive.get_connection_id()

	if not _bound_connection_ids.has(connection_id):
		return report

	_bound_connection_ids.erase(connection_id)
	_unbind_order.append(connection_id)

	return report


func get_bind_order(
) -> Array[StringName]:

	return _bind_order.duplicate()


func get_unbind_order(
) -> Array[StringName]:

	return _unbind_order.duplicate()


func get_bound_count(
) -> int:

	return _bound_connection_ids.size()


func _add_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	connection_id: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			message,
			String(connection_id),
			&"communication"
		)
	)
