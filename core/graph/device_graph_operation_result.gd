extends RefCounted
class_name DeviceGraphOperationResult


##
## DeviceGraphOperationResult
##
## Resultado inmutable de una operación
## solicitada sobre DeviceGraphDraft.
##


var _success: bool

var _affected_id: StringName

var _report: ValidationReport


func _init(
	success: bool,
	affected_id: StringName,
	report: ValidationReport
) -> void:

	_success = success

	_affected_id = affected_id

	_report = report


func is_success() -> bool:

	return _success


func get_affected_id() -> StringName:

	return _affected_id


func get_report() -> ValidationReport:

	return _report
