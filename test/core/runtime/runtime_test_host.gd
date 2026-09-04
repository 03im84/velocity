extends RefCounted


##
## RuntimeTestHost
##
## RuntimeHost controlado para probar:
##
## - attach por Handle;
## - detach por Handle;
## - orden;
## - idempotencia;
## - rollback de attach parcial.
##
## No representa un host de producción.
##


var _fail_after_host_count: int = -1

var _attached_handle_ids: Dictionary[int, bool] = {}

var _attach_order: Array[String] = []

var _detach_order: Array[String] = []


func set_fail_after_host_count(
	host_count: int
) -> void:

	_fail_after_host_count = host_count


func attach(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null:

		_add_structural_error(
			report,
			&"test_host_handle_missing",
			"RuntimeDeviceHandle is required.",
			"",
			&"handle"
		)

		return report

	if not handle.is_valid():

		_add_structural_error(
			report,
			&"test_host_handle_invalid",
			"RuntimeDeviceHandle is invalid.",
			handle.get_device_id(),
			&"handle"
		)

		return report

	var handle_instance_id: int = (
		handle.get_instance_id()
	)

	if _attached_handle_ids.has(
		handle_instance_id
	):

		return report

	var attached_this_call: Array[Object] = []

	for host_object: Object in handle.get_host_objects():

		_mark_attached(
			host_object
		)

		attached_this_call.append(
			host_object
		)

		if (
			_fail_after_host_count >= 0
			and attached_this_call.size()
			>= _fail_after_host_count
		):

			_rollback_partial_attach(
				attached_this_call
			)

			_fail_after_host_count = -1

			_add_structural_error(
				report,
				&"test_host_attach_failed",
				"Controlled RuntimeHost attach failure.",
				handle.get_device_id(),
				&"host_objects"
			)

			return report

	_attached_handle_ids[
		handle_instance_id
	] = true

	_attach_order.append(
		handle.get_device_id()
	)

	return report


func detach(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null:

		_add_structural_error(
			report,
			&"test_host_handle_missing",
			"RuntimeDeviceHandle is required.",
			"",
			&"handle"
		)

		return report

	if not handle.is_valid():

		_add_structural_error(
			report,
			&"test_host_handle_invalid",
			"RuntimeDeviceHandle is invalid.",
			handle.get_device_id(),
			&"handle"
		)

		return report

	var handle_instance_id: int = (
		handle.get_instance_id()
	)

	if not _attached_handle_ids.has(
		handle_instance_id
	):

		return report

	var host_objects := handle.get_host_objects()

	for host_index: int in range(
		host_objects.size() - 1,
		-1,
		-1
	):

		_mark_detached(
			host_objects[host_index]
		)

	_attached_handle_ids.erase(
		handle_instance_id
	)

	_detach_order.append(
		handle.get_device_id()
	)

	return report


func is_handle_attached(
	handle: RuntimeDeviceHandle
) -> bool:

	if handle == null:
		return false

	return _attached_handle_ids.has(
		handle.get_instance_id()
	)


func get_attached_handle_count(
) -> int:

	return _attached_handle_ids.size()


func get_attach_order(
) -> Array[String]:

	return _attach_order.duplicate()


func get_detach_order(
) -> Array[String]:

	return _detach_order.duplicate()


func _rollback_partial_attach(
	attached_objects: Array[Object]
) -> void:

	for object_index: int in range(
		attached_objects.size() - 1,
		-1,
		-1
	):

		_mark_detached(
			attached_objects[object_index]
		)


func _mark_attached(
	host_object: Object
) -> void:

	if host_object == null:
		return

	if not is_instance_valid(host_object):
		return

	if host_object.has_method(
		&"mark_attached"
	):

		host_object.call(
			&"mark_attached"
		)


func _mark_detached(
	host_object: Object
) -> void:

	if host_object == null:
		return

	if not is_instance_valid(host_object):
		return

	if host_object.has_method(
		&"mark_detached"
	):

		host_object.call(
			&"mark_detached"
		)


func _add_structural_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			message,
			related_object_id,
			related_field
		)
	)
