extends RefCounted
class_name DeviceConfigurationCompileResult


##
## DeviceConfigurationCompileResult
##
## Reúne el snapshot de DeviceConfiguration
## y su ValidationReport.
##
## No compila Profiles.
##


var _configuration: DeviceConfiguration

var _report: ValidationReport


func _init(
	configuration: DeviceConfiguration,
	report: ValidationReport
) -> void:

	_configuration = configuration

	_report = report


func get_configuration() -> DeviceConfiguration:

	return _configuration


func get_report() -> ValidationReport:

	return _report


func is_success() -> bool:

	return (
		_configuration != null
		and _report != null
		and _report.is_valid_for_simulation()
	)
