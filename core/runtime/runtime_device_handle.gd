extends RefCounted
class_name RuntimeDeviceHandle


##
## RuntimeDeviceHandle
##
## Representa una unidad runtime construida
## y el ownership asociado a ella.
##
## No coordina el sistema completo.
##


var _device_id: String

var _configuration: DeviceConfiguration

var _factory_key: RuntimeFactoryKey

var _primary_runtime_object: Object

var _host_objects: Array[Object] = []

var _dependency_bindings: Array[RuntimeDependencyBinding] = []


func _init(
	device_id: String,
	configuration: DeviceConfiguration,
	factory_key: RuntimeFactoryKey,
	primary_runtime_object: Object,
	host_objects: Array[Object] = [],
	dependency_bindings: Array[RuntimeDependencyBinding] = []
) -> void:

	_device_id = device_id

	_configuration = configuration

	_factory_key = factory_key

	_primary_runtime_object = primary_runtime_object

	_host_objects = host_objects.duplicate()

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


func get_primary_runtime_object(
) -> Object:

	return _primary_runtime_object


# =============================================================================
# HOST OBJECT API
# =============================================================================

func get_host_objects(
) -> Array[Object]:

	return _host_objects.duplicate()


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

	if _primary_runtime_object == null:
		return false

	if not is_instance_valid(
		_primary_runtime_object
	):
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

	if not _host_objects_are_valid():
		return false

	if not _dependency_bindings_are_valid():
		return false

	return true


func _host_objects_are_valid(
) -> bool:

	var seen_instance_ids: Dictionary[int, bool] = {}

	for host_object: Object in _host_objects:

		if host_object == null:
			return false

		if not is_instance_valid(host_object):
			return false

		var instance_id: int = (
			host_object.get_instance_id()
		)

		if seen_instance_ids.has(instance_id):
			return false

		seen_instance_ids[instance_id] = true

	return true


func _dependency_bindings_are_valid(
) -> bool:

	var seen_dependency_ids: Dictionary[StringName, bool] = {}

	for binding: RuntimeDependencyBinding in _dependency_bindings:

		if binding == null:
			return false

		if not binding.is_valid():
			return false

		var dependency_id: StringName = (
			binding.get_dependency_id()
		)

		if seen_dependency_ids.has(
			dependency_id
		):
			return false

		seen_dependency_ids[
			dependency_id
		] = true

	return true
