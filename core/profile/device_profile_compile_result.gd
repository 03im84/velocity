extends RefCounted
class_name DeviceProfileCompileResult


##
## DeviceProfileCompileResult
##
## Reúne el Profile compilado y su
## ValidationReport.
##


var _profile: DeviceProfile

var _report: ValidationReport


func _init(
	profile: DeviceProfile,
	report: ValidationReport
) -> void:

	_profile = profile

	_report = report


func get_profile() -> DeviceProfile:

	return _profile


func get_report() -> ValidationReport:

	return _report


func is_success() -> bool:

	return (
		_profile != null
		and _report != null
		and _report.is_valid_for_simulation()
	)
