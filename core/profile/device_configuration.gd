extends Resource
class_name DeviceConfiguration


##
## DeviceConfiguration
##
## Snapshot validado e inmutable por contrato
## de configuración de una instancia.
##
## No representa un Draft.
##


enum ActivationContext {
	SIMULATION,
	HARDWARE
}


# =============================================================================
# STORED STATE
# =============================================================================

@export_storage var _configuration_id: StringName = &""

@export_storage var _configuration_version: int = 1

@export_storage var _device_id: String = ""

@export_storage var _profile_id: StringName = &""

@export_storage var _profile_version: int = 1

@export_storage var _activation_context: ActivationContext = (
	ActivationContext.SIMULATION
)

@export_storage var _based_on_configuration_id: StringName = &""

@export_storage var _based_on_configuration_version: int = 0

@export_storage var _enabled_capabilities: Array[String] = []

@export_storage var _enabled_publishes: Array[StringName] = []

@export_storage var _enabled_subscribes: Array[StringName] = []

@export_storage var _additional_requirements: Array[String] = []


# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(
	configuration_id: StringName = &"",
	configuration_version: int = 1,
	device_id: String = "",
	profile_id: StringName = &"",
	profile_version: int = 1,
	activation_context: ActivationContext = (
		ActivationContext.SIMULATION
	),
	based_on_configuration_id: StringName = &"",
	based_on_configuration_version: int = 0,
	enabled_capabilities: Array[String] = [],
	enabled_publishes: Array[StringName] = [],
	enabled_subscribes: Array[StringName] = [],
	additional_requirements: Array[String] = []
) -> void:

	_configuration_id = configuration_id

	_configuration_version = configuration_version

	_device_id = device_id

	_profile_id = profile_id

	_profile_version = profile_version

	_activation_context = activation_context

	_based_on_configuration_id = (
		based_on_configuration_id
	)

	_based_on_configuration_version = (
		based_on_configuration_version
	)

	_enabled_capabilities = (
		enabled_capabilities.duplicate()
	)

	_enabled_publishes = (
		enabled_publishes.duplicate()
	)

	_enabled_subscribes = (
		enabled_subscribes.duplicate()
	)

	_additional_requirements = (
		additional_requirements.duplicate()
	)


# =============================================================================
# VALIDATION
# =============================================================================

func is_valid() -> bool:

	if _configuration_id == &"":
		return false

	if _configuration_version <= 0:
		return false

	if _device_id.is_empty():
		return false

	if _profile_id == &"":
		return false

	if _profile_version <= 0:
		return false

	if _has_duplicates(
		_enabled_capabilities
	):
		return false

	if _has_duplicates(
		_enabled_publishes
	):
		return false

	if _has_duplicates(
		_enabled_subscribes
	):
		return false

	if _has_duplicates(
		_additional_requirements
	):
		return false

	if _based_on_configuration_id == &"":

		return (
			_based_on_configuration_version == 0
		)

	return _based_on_configuration_version > 0


# =============================================================================
# PUBLIC API
# =============================================================================

func get_configuration_id() -> StringName:

	return _configuration_id


func get_configuration_version() -> int:

	return _configuration_version


func get_device_id() -> String:

	return _device_id


func get_profile_id() -> StringName:

	return _profile_id


func get_profile_version() -> int:

	return _profile_version


func get_activation_context(
) -> ActivationContext:

	return _activation_context


func get_based_on_configuration_id(
) -> StringName:

	return _based_on_configuration_id


func get_based_on_configuration_version(
) -> int:

	return _based_on_configuration_version


func get_enabled_capabilities(
) -> Array[String]:

	return _enabled_capabilities.duplicate()


func get_enabled_publishes(
) -> Array[StringName]:

	return _enabled_publishes.duplicate()


func get_enabled_subscribes(
) -> Array[StringName]:

	return _enabled_subscribes.duplicate()


func get_additional_requirements(
) -> Array[String]:

	return _additional_requirements.duplicate()


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

func _has_duplicates(
	values: Array
) -> bool:

	var seen: Dictionary = {}

	for value: Variant in values:

		if seen.has(value):
			return true

		seen[value] = true

	return false
