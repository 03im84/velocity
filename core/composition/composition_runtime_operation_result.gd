extends RefCounted
class_name CompositionRuntimeOperationResult


##
## CompositionRuntimeOperationResult
##
## Resultado inmutable de una operación
## solicitada a CompositionRuntime.
##
## No ejecuta activate, shutdown o rollback.
##


const OPERATION_ACTIVATE: StringName = &"activate"
const OPERATION_SHUTDOWN: StringName = &"shutdown"


var _success: bool

var _operation: StringName

var _report: ValidationReport


func _init(
	success: bool,
	operation: StringName,
	report: ValidationReport
) -> void:

	_success = success

	_operation = operation

	_report = report


func is_success(
) -> bool:

	if not _success:
		return false

	if not _operation_is_valid(
		_operation
	):
		return false

	if _report == null:
		return false

	return _report.is_valid_for_simulation()


func get_operation(
) -> StringName:

	return _operation


func get_report(
) -> ValidationReport:

	return _report


func _operation_is_valid(
	operation: StringName
) -> bool:

	return (
		operation == OPERATION_ACTIVATE
		or operation == OPERATION_SHUTDOWN
	)
