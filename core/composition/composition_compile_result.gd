extends RefCounted
class_name CompositionCompileResult


##
## CompositionCompileResult
##
## Resultado inmutable de compilar
## DeviceGraphSnapshot a CompositionPlan.
##
## No compila, ejecuta o activa runtime.
##


var _plan: CompositionPlan

var _report: ValidationReport


func _init(
	plan: CompositionPlan,
	report: ValidationReport
) -> void:

	_plan = plan

	_report = report


func get_plan(
) -> CompositionPlan:

	return _plan


func get_report(
) -> ValidationReport:

	return _report


func is_success(
) -> bool:

	if _plan == null:
		return false

	if _report == null:
		return false

	if not _plan.is_valid():
		return false

	var activation_context: int = (
		_plan.get_activation_context()
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
