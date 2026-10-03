extends RefCounted


## Transaction-observable RuntimeFactory for CompositionRuntime integration tests.


const RuntimeTestObjectScript = preload(
	"res://test/core/runtime/runtime_test_object.gd"
)


var _trace: Object
var _build_failures: Dictionary[String, bool] = {}
var _release_failures: Dictionary[String, bool] = {}
var _released_handle_ids: Dictionary[int, bool] = {}
var _build_count: int = 0
var _release_count: int = 0


func _init(
	trace: Object
) -> void:

	_trace = trace


func add_failure(
	phase: StringName,
	device_id: String
) -> void:

	if phase == &"build":
		_build_failures[device_id] = true
	elif phase == &"release":
		_release_failures[device_id] = true


func build(
	request: RuntimeConstructionRequest
) -> RuntimeFactoryBuildResult:

	var report := ValidationReport.new()

	if request == null or not request.is_valid():
		_add_error(
			report,
			&"runtime_integration_factory_request_invalid",
			"RuntimeConstructionRequest is invalid.",
			"",
			&"request"
		)
		return RuntimeFactoryBuildResult.new(
			null,
			report
		)

	var device_id: String = request.get_device_id()

	_build_count += 1
	_record(
		"build:" + device_id
	)

	if _build_failures.has(device_id):
		_add_error(
			report,
			&"runtime_integration_factory_build_failed",
			"Controlled RuntimeFactory build failure.",
			device_id,
			&"build"
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
		device_id,
		request.get_configuration(),
		request.get_factory_key(),
		primary_object,
		host_objects,
		request.get_dependency_bindings()
	)

	if not handle.is_valid():
		_mark_released(primary_object)
		_mark_released(host_object)
		_add_error(
			report,
			&"runtime_integration_factory_handle_invalid",
			"RuntimeFactory produced an invalid Handle.",
			device_id,
			&"handle"
		)
		return RuntimeFactoryBuildResult.new(
			null,
			report
		)

	return RuntimeFactoryBuildResult.new(
		handle,
		report
	)


func release(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null or not handle.is_valid():
		_add_error(
			report,
			&"runtime_integration_factory_handle_invalid",
			"RuntimeDeviceHandle is invalid.",
			"",
			&"handle"
		)
		return report

	var handle_id: int = handle.get_instance_id()

	if _released_handle_ids.has(handle_id):
		return report

	_released_handle_ids[handle_id] = true
	_release_count += 1

	var device_id: String = handle.get_device_id()

	_record(
		"release:" + device_id
	)

	var seen_ids: Dictionary[int, bool] = {}

	_release_once(
		handle.get_primary_runtime_object(),
		seen_ids
	)

	for host_object: Object in handle.get_host_objects():
		_release_once(
			host_object,
			seen_ids
		)

	for binding: RuntimeDependencyBinding in handle.get_dependency_bindings():
		if binding == null or not binding.is_transferred():
			continue
		_release_once(
			binding.get_value(),
			seen_ids
		)

	if _release_failures.has(device_id):
		_add_error(
			report,
			&"runtime_integration_factory_release_failed",
			"Controlled RuntimeFactory release failure.",
			device_id,
			&"release"
		)

	return report


func get_build_count(
) -> int:

	return _build_count


func get_release_count(
) -> int:

	return _release_count


func _release_once(
	value: Object,
	seen_ids: Dictionary[int, bool]
) -> void:

	if value == null or not is_instance_valid(value):
		return

	var instance_id: int = value.get_instance_id()

	if seen_ids.has(instance_id):
		return

	seen_ids[instance_id] = true
	_mark_released(value)


func _mark_released(
	value: Object
) -> void:

	if value == null or not is_instance_valid(value):
		return

	if value.has_method(
		&"mark_released"
	):
		value.call(
			&"mark_released"
		)


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
