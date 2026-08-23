extends Resource
class_name DeviceProfileDraft


##
## DeviceProfileDraft
##
## Definición editable de un modelo de Device.
##
## No puede utilizarse directamente por runtime.
## Debe compilarse para producir DeviceProfile.
##


@export var profile_id: StringName = &""

@export var profile_version: int = 1

@export var display_name: String = ""

@export_multiline var description: String = ""

@export var primary_role: StringName = &""

@export var capabilities: Array[String] = []

@export var supported_publishes: Array[StringName] = []

@export var supported_subscribes: Array[StringName] = []

@export var requirements: Array[String] = []

@export var based_on_profile_id: StringName = &""

@export var based_on_profile_version: int = 0


func is_valid_identity() -> bool:

	if profile_id == &"":
		return false

	if profile_version <= 0:
		return false

	if display_name.is_empty():
		return false

	if not DeviceRoles.is_valid(
		primary_role
	):
		return false

	if based_on_profile_id == &"":

		return (
			based_on_profile_version == 0
		)

	return based_on_profile_version > 0
