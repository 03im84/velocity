extends RefCounted
class_name SystemProfileDraft


##
## SystemProfileDraft
##
## Representa una composición editable
## todavía no autorizada para Graph assembly
## o runtime.
##


var system_profile_id: StringName = &""

var system_profile_version: int = 1

var display_name: String = ""

var description: String = ""

var activation_context: int = (
	DeviceConfiguration.ActivationContext.SIMULATION
)

var device_configurations: Array[DeviceConfiguration] = []

var connection_specs: Array[SystemConnectionSpec] = []


func has_valid_identity(
) -> bool:

	if system_profile_id == &"":
		return false

	if system_profile_version <= 0:
		return false

	if display_name.strip_edges().is_empty():
		return false

	if not _activation_context_is_valid(
		activation_context
	):
		return false

	return true


func _activation_context_is_valid(
	context: int
) -> bool:

	return (
		context
		== DeviceConfiguration.ActivationContext.SIMULATION
		or context
		== DeviceConfiguration.ActivationContext.HARDWARE
	)
