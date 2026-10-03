extends RefCounted
class_name GodotNodeRuntimeHost


##
## GodotNodeRuntimeHost
##
## Adjunta Host Objects Node bajo un
## parent explícito sin descubrir SceneTree.
##
## No libera Nodes.
##


var _parent: Node
var _attached_nodes_by_handle: Dictionary[int, Array] = {}


func _init(
	parent: Node
) -> void:

	_parent = parent


func attach(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := _validate_parent()

	if not report.is_valid_for_simulation():
		return report

	var handle_report := _validate_handle(handle)
	_merge_report(report, handle_report)

	if not report.is_valid_for_simulation():
		return report

	var handle_id: int = handle.get_instance_id()

	if _attached_nodes_by_handle.has(handle_id):
		_add_error(
			report,
			&"godot_runtime_host_duplicate_attach",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"RuntimeDeviceHandle is already attached.",
			handle.get_device_id(),
			&"handle"
		)
		return report

	var nodes := _validate_host_objects(
		handle,
		report
	)

	if not report.is_valid_for_simulation():
		return report

	var attached_this_call: Array[Node] = []

	for node: Node in nodes:
		_parent.add_child(node)

		if node.get_parent() != _parent:
			_rollback_partial_attach(attached_this_call)
			_add_error(
				report,
				&"godot_runtime_host_attach_failed",
				ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
				"Godot parent rejected Host Object attachment.",
				handle.get_device_id(),
				&"host_objects"
			)
			return report

		attached_this_call.append(node)

	_attached_nodes_by_handle[handle_id] = (
		attached_this_call.duplicate()
	)

	return report


func detach(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := _validate_parent()

	if not report.is_valid_for_simulation():
		return report

	var handle_report := _validate_handle(handle)
	_merge_report(report, handle_report)

	if not report.is_valid_for_simulation():
		return report

	var handle_id: int = handle.get_instance_id()

	if not _attached_nodes_by_handle.has(handle_id):
		return report

	var stored_nodes: Array = (
		_attached_nodes_by_handle[handle_id]
	)
	var unresolved_nodes: Array[Node] = []

	for node_index: int in range(
		stored_nodes.size() - 1,
		-1,
		-1
	):
		var node: Node = stored_nodes[node_index]

		if node == null or not is_instance_valid(node):
			continue

		var current_parent := node.get_parent()

		if current_parent == null:
			continue

		if current_parent != _parent:
			unresolved_nodes.append(node)
			_add_error(
				report,
				&"godot_runtime_host_detach_parent_mismatch",
				ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
				"Host Object belongs to an unexpected parent.",
				handle.get_device_id(),
				&"host_objects"
			)
			continue

		_parent.remove_child(node)

		if node.get_parent() != null:
			unresolved_nodes.append(node)
			_add_error(
				report,
				&"godot_runtime_host_detach_parent_mismatch",
				ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
				"Host Object detach could not be confirmed.",
				handle.get_device_id(),
				&"host_objects"
			)

	if unresolved_nodes.is_empty():
		_attached_nodes_by_handle.erase(handle_id)
	else:
		unresolved_nodes.reverse()
		_attached_nodes_by_handle[handle_id] = unresolved_nodes

	return report


func is_handle_attached(
	handle: RuntimeDeviceHandle
) -> bool:

	if handle == null:
		return false

	if not is_instance_valid(handle):
		return false

	return _attached_nodes_by_handle.has(
		handle.get_instance_id()
	)


func get_attached_handle_count(
) -> int:

	return _attached_nodes_by_handle.size()


func _validate_parent(
) -> ValidationReport:

	var report := ValidationReport.new()

	if _parent == null:
		_add_error(
			report,
			&"godot_runtime_host_parent_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Explicit Godot parent is required.",
			"",
			&"parent"
		)
		return report

	if not is_instance_valid(_parent):
		_add_error(
			report,
			&"godot_runtime_host_parent_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Explicit Godot parent instance is invalid.",
			"",
			&"parent"
		)

	return report


func _validate_handle(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null:
		_add_error(
			report,
			&"godot_runtime_host_handle_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"RuntimeDeviceHandle is required.",
			"",
			&"handle"
		)
		return report

	if not handle.is_valid():
		_add_error(
			report,
			&"godot_runtime_host_handle_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"RuntimeDeviceHandle is invalid.",
			handle.get_device_id(),
			&"handle"
		)

	return report


func _validate_host_objects(
	handle: RuntimeDeviceHandle,
	report: ValidationReport
) -> Array[Node]:

	var nodes: Array[Node] = []

	for host_object: Object in handle.get_host_objects():

		if not (host_object is Node):
			_add_error(
				report,
				&"godot_runtime_host_object_not_node",
				ValidationIssue.Severity.STRUCTURAL_ERROR,
				"Host Object must be a Node.",
				handle.get_device_id(),
				&"host_objects"
			)
			continue

		var node: Node = host_object

		if not is_instance_valid(node):
			_add_error(
				report,
				&"godot_runtime_host_object_invalid",
				ValidationIssue.Severity.STRUCTURAL_ERROR,
				"Host Object Node instance is invalid.",
				handle.get_device_id(),
				&"host_objects"
			)
			continue

		if node == _parent:
			_add_error(
				report,
				&"godot_runtime_host_object_is_parent",
				ValidationIssue.Severity.STRUCTURAL_ERROR,
				"Host Object cannot be the explicit parent.",
				handle.get_device_id(),
				&"host_objects"
			)
			continue

		if node.get_parent() != null:
			_add_error(
				report,
				&"godot_runtime_host_object_already_parented",
				ValidationIssue.Severity.STRUCTURAL_ERROR,
				"Host Object already has a parent.",
				handle.get_device_id(),
				&"host_objects"
			)
			continue

		if node.is_ancestor_of(_parent):
			_add_error(
				report,
				&"godot_runtime_host_cycle_detected",
				ValidationIssue.Severity.STRUCTURAL_ERROR,
				"Host Object would create a SceneTree cycle.",
				handle.get_device_id(),
				&"host_objects"
			)
			continue

		nodes.append(node)

	return nodes


func _rollback_partial_attach(
	attached_nodes: Array[Node]
) -> void:

	for node_index: int in range(
		attached_nodes.size() - 1,
		-1,
		-1
	):
		var node := attached_nodes[node_index]

		if (
			node != null
			and is_instance_valid(node)
			and node.get_parent() == _parent
		):
			_parent.remove_child(node)


func _merge_report(
	target: ValidationReport,
	source: ValidationReport
) -> void:

	if source == null:
		return

	for issue: ValidationIssue in source.get_issues():
		target.add_issue(issue)


func _add_error(
	report: ValidationReport,
	code: StringName,
	severity: ValidationIssue.Severity,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			severity,
			message,
			related_object_id,
			related_field
		)
	)
