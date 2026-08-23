extends RefCounted
class_name DeviceManifestBuildResult


##
## DeviceManifestBuildResult
##
## Reúne el DeviceManifest generado
## y su ValidationReport.
##


var _manifest: DeviceManifest

var _report: ValidationReport


func _init(
	manifest: DeviceManifest,
	report: ValidationReport
) -> void:

	_manifest = manifest

	_report = report


func get_manifest() -> DeviceManifest:

	return _manifest


func get_report() -> ValidationReport:

	return _report


func is_success() -> bool:

	return (
		_manifest != null
		and _report != null
		and _report.is_valid_for_simulation()
	)
