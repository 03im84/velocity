extends RefCounted
class_name DeviceCatalogCompileResult


##
## DeviceCatalogCompileResult
##
## Resultado inmutable de compilar
## DeviceCatalogDraft.
##


var _catalog: DeviceCatalog

var _report: ValidationReport


func _init(
	catalog: DeviceCatalog,
	report: ValidationReport
) -> void:

	_catalog = catalog

	_report = report


func get_catalog(
) -> DeviceCatalog:

	return _catalog


func get_report(
) -> ValidationReport:

	return _report


func is_success(
) -> bool:

	if _catalog == null:
		return false

	if _report == null:
		return false

	if not _report.is_valid_for_simulation():
		return false

	return _catalog.is_valid()
