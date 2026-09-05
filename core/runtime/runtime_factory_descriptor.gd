extends RefCounted
class_name RuntimeFactoryDescriptor


##
## RuntimeFactoryDescriptor
##
## Asocia una RuntimeFactoryKey,
## un factory Object y sus
## RuntimeDependencySpecs.
##
## Valida behavior sin ejecutar
## build() o release().
##


var _factory_key: RuntimeFactoryKey

var _factory: Object

var _dependency_specs: Array[RuntimeDependencySpec] = []


func _init(
	factory_key: RuntimeFactoryKey,
	factory: Object,
	dependency_specs: Array[RuntimeDependencySpec]
) -> void:

	_factory_key = factory_key

	_factory = factory

	_dependency_specs = (
		dependency_specs.duplicate()
	)


# =============================================================================
# FACTORY API
# =============================================================================

func get_factory_key(
) -> RuntimeFactoryKey:

	return _factory_key


func get_factory(
) -> Object:

	return _factory


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

	if _factory_key == null:
		return false

	if not _factory_key.is_valid():
		return false

	if _factory == null:
		return false

	if not is_instance_valid(
		_factory
	):
		return false

	if not _factory.has_method(
		&"build"
	):
		return false

	if not _factory.has_method(
		&"release"
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
