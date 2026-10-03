extends RefCounted


## Controlled factory for managed adapter integration tests.


const ManagedRuntimeTestUnitScript = preload(
	"res://test/core/runtime/managed_runtime_test_unit.gd"
)


var _units_by_device: Dictionary[String, Object] = {}
var _nodes_by_device: Dictionary[String, Node] = {}
var _released_handle_ids: Dictionary[int, bool] = {}
var _build_order: Array[String] = []
var _release_order: Array[String] = []


func build(
	request: RuntimeConstructionRequest
) -> RuntimeFactoryBuildResult:

	var report := ValidationReport.new()

	if request == null or not request.is_valid():
		_add_error(
			report,
			&"managed_runtime_test_request_invalid",
			""
		)
		return RuntimeFactoryBuildResult.new(
			null,
			report
		)

	var device_id: String = request.get_device_id()
	var unit := ManagedRuntimeTestUnitScript.new(device_id)
	var host_node := Node.new()

	host_node.name = device_id + "_host"
	unit.register_endpoint(
		&"in.test_message",
		unit.receive_message
	)

	var host_objects: Array[Object] = [
		host_node,
	]

	var handle := RuntimeDeviceHandle.new(
		device_id,
		request.get_configuration(),
		request.get_factory_key(),
		unit,
		host_objects,
		request.get_dependency_bindings()
	)

	if not handle.is_valid():
		host_node.free()
		_add_error(
			report,
			&"managed_runtime_test_handle_invalid",
			device_id
		)
		return RuntimeFactoryBuildResult.new(
			null,
			report
		)

	_units_by_device[device_id] = unit
	_nodes_by_device[device_id] = host_node
	_build_order.append(device_id)

	return RuntimeFactoryBuildResult.new(
		handle,
		report
	)


func release(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null:
		_add_error(
			report,
			&"managed_runtime_test_handle_missing",
			""
		)
		return report

	var handle_id: int = handle.get_instance_id()

	if _released_handle_ids.has(handle_id):
		return report

	_released_handle_ids[handle_id] = true

	var device_id: String = handle.get_device_id()
	var host_node: Node = _nodes_by_device.get(
		device_id,
		null
	)

	if host_node != null and is_instance_valid(host_node):
		if host_node.get_parent() != null:
			_add_error(
				report,
				&"managed_runtime_test_node_still_attached",
				device_id
			)
			return report

		host_node.free()

	_nodes_by_device.erase(device_id)
	_units_by_device.erase(device_id)
	_release_order.append(device_id)

	return report


func get_unit(
	device_id: String
) -> Object:

	return _units_by_device.get(
		device_id,
		null
	)


func get_host_node(
	device_id: String
) -> Node:

	return _nodes_by_device.get(
		device_id,
		null
	)


func get_build_order(
) -> Array[String]:

	return _build_order.duplicate()


func get_release_order(
) -> Array[String]:

	return _release_order.duplicate()


func _add_error(
	report: ValidationReport,
	code: StringName,
	device_id: String
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Controlled managed runtime factory failure.",
			device_id,
			&"factory"
		)
	)
