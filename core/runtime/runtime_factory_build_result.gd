extends RefCounted
class_name RuntimeFactoryBuildResult


##
## RuntimeFactoryBuildResult
##
## Resultado inmutable de ejecutar
## RuntimeFactory.build().
##


var _handle: RuntimeDeviceHandle

var _report: ValidationReport


func _init(
	handle: RuntimeDeviceHandle,
	report: ValidationReport
) -> void:

	_handle = handle

	_report = report


func get_handle(
) -> RuntimeDeviceHandle:

	return _handle


func get_report(
) -> ValidationReport:

	return _report


func is_success(
) -> bool:

	if _handle == null:
		return false

	if _report == null:
		return false

	if not _handle.is_valid():
		return false

	var factory_key := _handle.get_factory_key()

	if factory_key == null:
		return false

	var activation_context: int = (
		factory_key.get_activation_context()
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
