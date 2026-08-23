extends RefCounted
class_name SystemProfileCompileResult


##
## SystemProfileCompileResult
##
## Resultado inmutable de compilar
## SystemProfileDraft.
##


var _profile: SystemProfile

var _report: ValidationReport


func _init(
	profile: SystemProfile,
	report: ValidationReport
) -> void:

	_profile = profile

	_report = report


func get_profile(
) -> SystemProfile:

	return _profile


func get_report(
) -> ValidationReport:

	return _report


func is_success(
) -> bool:

	if _profile == null:
		return false

	if _report == null:
		return false

	if not _profile.is_valid_identity():
		return false

	var activation_context: int = (
		_profile.get_activation_context()
	)

	if (
		activation_context
		== DeviceConfiguration.ActivationContext.SIMULATION
	):

		return _report.is_valid_for_simulation()

	if (
		activation_context
		== DeviceConfiguration.ActivationContext.HARDWARE
	):

		return _report.is_valid_for_hardware()

	return false
