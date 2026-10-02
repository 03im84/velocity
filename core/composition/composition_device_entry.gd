extends RefCounted
class_name CompositionDeviceEntry


##
## CompositionDeviceEntry
##
## Descripción inmutable de la construcción
## declarativa de un Device runtime.
##
## Conserva requisitos, no Values activos.
##


var _device_id: String

var _configuration: DeviceConfiguration

var _factory_key: RuntimeFactoryKey

var _dependency_specs: Array[RuntimeDependencySpec] = []


func _init(
	device_id: String,
	configuration: DeviceConfiguration,
	factory_key: RuntimeFactoryKey,
	dependency_specs: Array[RuntimeDependencySpec]
) -> void:

	_device_id = device_id

	_configuration = configuration

	_factory_key = factory_key

	_dependency_specs = (
		dependency_specs.duplicate()
	)


# =============================================================================
# IDENTITY API
# =============================================================================

func get_device_id(
) -> String:

	return _device_id


func get_configuration(
) -> DeviceConfiguration:

	return _configuration


func get_factory_key(
) -> RuntimeFactoryKey:

	return _factory_key


# =============================================================================
# DEPENDENCY API
# =============================================================================

func get_dependency_specs(
) -> Array[RuntimeDependencySpec]:

	return _dependency_specs.duplicate()


func has_dependency(
	dependency_id: StringName
) -> bool:

	return get_dependency_spec(
		dependency_id
	) != null


func get_dependency_spec(
	dependency_id: StringName
) -> RuntimeDependencySpec:

	if dependency_id == &"":
		return null

	for spec: RuntimeDependencySpec in _dependency_specs:

		if spec == null:
			continue

		if (
			spec.get_dependency_id()
			== dependency_id
		):

			return spec

	return null


# =============================================================================
# VALIDATION
# =============================================================================

func is_valid(
) -> bool:

	if _device_id.is_empty():
		return false

	if _configuration == null:
		return false

	if not _configuration.is_valid():
		return false

	if _factory_key == null:
		return false

	if not _factory_key.is_valid():
		return false

	if (
		_configuration.get_device_id()
		!= _device_id
	):
		return false

	if (
		_configuration.get_profile_id()
		!= _factory_key.get_profile_id()
	):
		return false

	if (
		_configuration.get_profile_version()
		!= _factory_key.get_profile_version()
	):
		return false

	if (
		_configuration.get_activation_context()
		!= _factory_key.get_activation_context()
	):
		return false

	if not _dependency_specs_are_valid():
		return false

	return true


func _dependency_specs_are_valid(
) -> bool:

	var seen_dependency_ids: Dictionary[StringName, bool] = {}

	for spec: RuntimeDependencySpec in _dependency_specs:

		if spec == null:
			return false

		if not spec.is_valid():
			return false

		var dependency_id: StringName = (
			spec.get_dependency_id()
		)

		if seen_dependency_ids.has(
			dependency_id
		):
			return false

		seen_dependency_ids[
			dependency_id
		] = true

	return true
