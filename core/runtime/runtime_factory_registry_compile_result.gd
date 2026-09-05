extends RefCounted
class_name RuntimeFactoryRegistryCompileResult


##
## RuntimeFactoryRegistryCompileResult
##
## Resultado inmutable de compilar
## RuntimeFactoryRegistryDraft.
##
## No ejecuta factories ni activa runtime.
##


var _registry: RuntimeFactoryRegistry

var _report: ValidationReport


func _init(
	registry: RuntimeFactoryRegistry,
	report: ValidationReport
) -> void:

	_registry = registry

	_report = report


func get_registry(
) -> RuntimeFactoryRegistry:

	return _registry


func get_report(
) -> ValidationReport:

	return _report


func is_success(
) -> bool:

	if _registry == null:
		return false

	if _report == null:
		return false

	if not _report.is_valid_for_simulation():
		return false

	return _registry.is_valid()
