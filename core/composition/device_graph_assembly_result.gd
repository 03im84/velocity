extends RefCounted
class_name DeviceGraphAssemblyResult


##
## DeviceGraphAssemblyResult
##
## Resultado inmutable de ensamblar
## DeviceGraphSnapshot desde SystemProfile.
##


var _snapshot: DeviceGraphSnapshot

var _report: ValidationReport


func _init(
	snapshot: DeviceGraphSnapshot,
	report: ValidationReport
) -> void:

	_snapshot = snapshot

	_report = report


func get_snapshot(
) -> DeviceGraphSnapshot:

	return _snapshot


func get_report(
) -> ValidationReport:

	return _report


func is_success(
) -> bool:

	if _snapshot == null:
		return false

	if _report == null:
		return false

	if not _report.is_valid_for_simulation():
		return false

	return _snapshot.is_valid()
