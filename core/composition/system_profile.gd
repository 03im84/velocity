extends RefCounted
class_name SystemProfile


##
## SystemProfile
##
## Snapshot validado e inmutable
## de una composición lógica.
##
## No representa DeviceGraph ni runtime.
##


var _system_profile_id: StringName

var _system_profile_version: int

var _display_name: String

var _description: String

var _activation_context: int

var _device_configurations: Array[DeviceConfiguration] = []

var _connection_specs: Array[SystemConnectionSpec] = []


func _init(
	system_profile_id: StringName,
	system_profile_version: int,
	display_name: String,
	description: String,
	activation_context: int,
	device_configurations: Array[DeviceConfiguration],
	connection_specs: Array[SystemConnectionSpec]
) -> void:

	_system_profile_id = system_profile_id

	_system_profile_version = system_profile_version

	_display_name = display_name

	_description = description

	_activation_context = activation_context

	_device_configurations = (
		device_configurations.duplicate()
	)

	_connection_specs = (
		connection_specs.duplicate()
	)


# =============================================================================
# IDENTITY API
# =============================================================================

func get_system_profile_id(
) -> StringName:

	return _system_profile_id


func get_system_profile_version(
) -> int:

	return _system_profile_version


func get_display_name(
) -> String:

	return _display_name


func get_description(
) -> String:

	return _description


func get_activation_context(
) -> int:

	return _activation_context


# =============================================================================
# COLLECTION API
# =============================================================================

func get_device_configurations(
) -> Array[DeviceConfiguration]:

	return _device_configurations.duplicate()


func get_connection_specs(
) -> Array[SystemConnectionSpec]:

	return _connection_specs.duplicate()


# =============================================================================
# LOOKUP API
# =============================================================================

func get_device_configuration(
	device_id: String
) -> DeviceConfiguration:

	for configuration: DeviceConfiguration in _device_configurations:

		if configuration == null:
			continue

		if configuration.get_device_id() == device_id:
			return configuration

	return null


func get_connection_spec(
	connection_id: StringName
) -> SystemConnectionSpec:

	for spec: SystemConnectionSpec in _connection_specs:

		if spec == null:
			continue

		if spec.get_connection_id() == connection_id:
			return spec

	return null


# =============================================================================
# IDENTITY VALIDATION
# =============================================================================

func is_valid_identity(
) -> bool:

	if _system_profile_id == &"":
		return false

	if _system_profile_version <= 0:
		return false

	if _display_name.strip_edges().is_empty():
		return false

	if not _activation_context_is_valid(
		_activation_context
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
