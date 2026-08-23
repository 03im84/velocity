extends Resource
class_name DeviceConfigurationDraft


##
## DeviceConfigurationDraft
##
## Configuración editable de una instancia.
##
## No puede utilizarse directamente por runtime.
## Debe compilarse para producir
## DeviceConfiguration.
##


@export var configuration_id: StringName = &""

@export var configuration_version: int = 1

@export var device_id: String = ""

@export var profile_id: StringName = &""

@export var profile_version: int = 1

@export var based_on_configuration_id: StringName = &""

@export var based_on_configuration_version: int = 0

@export var enabled_capabilities: Array[String] = []

@export var enabled_publishes: Array[StringName] = []

@export var enabled_subscribes: Array[StringName] = []

@export var additional_requirements: Array[String] = []


func is_valid_identity() -> bool:

	if configuration_id == &"":
		return false

	if configuration_version <= 0:
		return false

	if device_id.is_empty():
		return false

	if profile_id == &"":
		return false

	if profile_version <= 0:
		return false

	if based_on_configuration_id == &"":

		return (
			based_on_configuration_version == 0
		)

	return based_on_configuration_version > 0
