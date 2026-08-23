extends RefCounted
class_name DeviceGraphNodeBuildResult


##
## DeviceGraphNodeBuildResult
##
## Reúne DeviceGraphNode y ValidationReport.
##


var _node: DeviceGraphNode

var _report: ValidationReport


func _init(
	node: DeviceGraphNode,
	report: ValidationReport
) -> void:

	_node = node

	_report = report


func get_node() -> DeviceGraphNode:

	return _node


func get_report() -> ValidationReport:

	return _report


func is_success() -> bool:

	return (
		_node != null
		and _report != null
		and _report.is_valid_for_simulation()
	)
