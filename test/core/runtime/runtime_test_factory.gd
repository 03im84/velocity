extends RefCounted


##
## RuntimeTestFactory
##
## RuntimeFactory controlada para probar:
##
## - build atómico;
## - Handle válido;
## - cleanup de TRANSFERRED;
## - preservación de BORROWED;
## - release idempotente;
## - orden de rollback.
##
## No representa producción.
##


const RuntimeTestObjectScript = preload(
	"res://test/core/runtime/runtime_test_object.gd"
)


var _fail_next_build: bool = false

var _build_count: int = 0

var _release_count: int = 0

var _released_handle_ids: Dictionary[int, bool] = {}

var _release_order: Array[String] = []

var _last_primary_object: Object

var _last_host_objects: Array[Object] = []


func set_fail_next_build(
	should_fail: bool
) -> void:

	_fail_next_build = should_fail


func build(
	request: RuntimeConstructionRequest
) -> RuntimeFactoryBuildResult:

	var report := ValidationReport.new()

	_build_count += 1

	_last_primary_object = null
	_last_host_objects.clear()

	if request == null:

		_add_structural_error(
			report,
			&"test_factory_request_missing",
			"RuntimeConstructionRequest is required.",
			"",
			&"request"
		)

		return RuntimeFactoryBuildResult.new(
			null,
			report
		)

	if not request.is_valid():

		_cleanup_transferred_bindings(
			request.get_dependency_bindings()
		)

		_add_structural_error(
			report,
			&"test_factory_request_invalid",
			"RuntimeConstructionRequest is invalid.",
			request.get_device_id(),
			&"request"
		)

		return RuntimeFactoryBuildResult.new(
			null,
			report
		)

	if _fail_next_build:

		_fail_next_build = false

		_cleanup_transferred_bindings(
			request.get_dependency_bindings()
		)

		_add_structural_error(
			report,
			&"test_factory_build_failed",
			"Controlled RuntimeFactory build failure.",
			request.get_device_id(),
			&"factory"
		)

		return RuntimeFactoryBuildResult.new(
			null,
			report
		)

	var primary_object := RuntimeTestObjectScript.new()
	var host_object := RuntimeTestObjectScript.new()

	var host_objects: Array[Object] = [
		host_object,
	]

	var handle := RuntimeDeviceHandle.new(
		request.get_device_id(),
		request.get_configuration(),
		request.get_factory_key(),
		primary_object,
		host_objects,
		request.get_dependency_bindings()
	)

	if not handle.is_valid():

		_cleanup_runtime_objects(
			primary_object,
			host_objects,
			request.get_dependency_bindings()
		)

		_add_structural_error(
			report,
			&"test_factory_handle_invalid",
			"RuntimeFactory created invalid Handle.",
			request.get_device_id(),
			&"handle"
		)

		return RuntimeFactoryBuildResult.new(
			null,
			report
		)

	_last_primary_object = primary_object
	_last_host_objects = host_objects.duplicate()

	return RuntimeFactoryBuildResult.new(
		handle,
		report
	)


func release(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null:

		_add_structural_error(
			report,
			&"test_factory_handle_missing",
			"RuntimeDeviceHandle is required.",
			"",
			&"handle"
		)

		return report

	if not handle.is_valid():

		_add_structural_error(
			report,
			&"test_factory_handle_invalid",
			"RuntimeDeviceHandle is invalid.",
			handle.get_device_id(),
			&"handle"
		)

		return report

	var handle_instance_id: int = (
		handle.get_instance_id()
	)

	if _released_handle_ids.has(
		handle_instance_id
	):

		return report

	_released_handle_ids[
		handle_instance_id
	] = true

	var seen_instance_ids: Dictionary[int, bool] = {}

	_mark_released_once(
		handle.get_primary_runtime_object(),
		seen_instance_ids
	)

	for host_object: Object in handle.get_host_objects():

		_mark_released_once(
			host_object,
			seen_instance_ids
		)

	for binding: RuntimeDependencyBinding in handle.get_dependency_bindings():

		if binding == null:
			continue

		if not binding.is_transferred():
			continue

		_mark_released_once(
			binding.get_value(),
			seen_instance_ids
		)

	_release_count += 1

	_release_order.append(
		handle.get_device_id()
	)

	return report


func get_build_count(
) -> int:

	return _build_count


func get_release_count(
) -> int:

	return _release_count


func get_release_order(
) -> Array[String]:

	return _release_order.duplicate()


func get_last_primary_object(
) -> Object:

	return _last_primary_object


func get_last_host_objects(
) -> Array[Object]:

	return _last_host_objects.duplicate()


func _cleanup_runtime_objects(
	primary_object: Object,
	host_objects: Array[Object],
	dependency_bindings: Array[RuntimeDependencyBinding]
) -> void:

	var seen_instance_ids: Dictionary[int, bool] = {}

	_mark_released_once(
		primary_object,
		seen_instance_ids
	)

	for host_object: Object in host_objects:

		_mark_released_once(
			host_object,
			seen_instance_ids
		)

	for binding: RuntimeDependencyBinding in dependency_bindings:

		if binding == null:
			continue

		if not binding.is_transferred():
			continue

		_mark_released_once(
			binding.get_value(),
			seen_instance_ids
		)


func _cleanup_transferred_bindings(
	bindings: Array[RuntimeDependencyBinding]
) -> void:

	var seen_instance_ids: Dictionary[int, bool] = {}

	for binding: RuntimeDependencyBinding in bindings:

		if binding == null:
			continue

		if not binding.is_transferred():
			continue

		_mark_released_once(
			binding.get_value(),
			seen_instance_ids
		)


func _mark_released_once(
	value: Object,
	seen_instance_ids: Dictionary[int, bool]
) -> void:

	if value == null:
		return

	if not is_instance_valid(value):
		return

	var instance_id: int = value.get_instance_id()

	if seen_instance_ids.has(instance_id):
		return

	seen_instance_ids[instance_id] = true

	if value.has_method(
		&"mark_released"
	):

		value.call(
			&"mark_released"
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
