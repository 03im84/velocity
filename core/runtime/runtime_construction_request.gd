extends RefCounted
class_name RuntimeConstructionRequest


##
## RuntimeConstructionRequest
##
## Transporta toda la información
## pre-resuelta necesaria para una
## construcción runtime.
##
## No es un service locator.
##


var _device_id: String

var _configuration: DeviceConfiguration

var _factory_key: RuntimeFactoryKey

var _dependency_bindings: Array[RuntimeDependencyBinding] = []


func _init(
	device_id: String,
	configuration: DeviceConfiguration,
	factory_key: RuntimeFactoryKey,
	dependency_bindings: Array[RuntimeDependencyBinding] = []
) -> void:

	_device_id = device_id

	_configuration = configuration

	_factory_key = factory_key

	_dependency_bindings = (
		dependency_bindings.duplicate()
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

func get_dependency_bindings(
) -> Array[RuntimeDependencyBinding]:

	return _dependency_bindings.duplicate()


func has_dependency(
	dependency_id: StringName
) -> bool:

	return get_dependency_binding(
		dependency_id
	) != null


func get_dependency_binding(
	dependency_id: StringName
) -> RuntimeDependencyBinding:

	if dependency_id == &"":
		return null

	for binding: RuntimeDependencyBinding in _dependency_bindings:

		if binding == null:
			continue

		if (
			binding.get_dependency_id()
			== dependency_id
		):

			return binding

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

	if not _dependency_bindings_are_valid():
		return false

	return true


func _dependency_bindings_are_valid(
) -> bool:

	var seen_ids: Dictionary[StringName, bool] = {}

	for binding: RuntimeDependencyBinding in _dependency_bindings:

		if binding == null:
			return false

		if not binding.is_valid():
			return false

		var dependency_id: StringName = (
			binding.get_dependency_id()
		)

		if seen_ids.has(dependency_id):
			return false

		seen_ids[dependency_id] = true

	return true
