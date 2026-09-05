extends RefCounted
class_name RuntimeFactoryRegistry


##
## RuntimeFactoryRegistry
##
## Snapshot inmutable de
## RuntimeFactoryDescriptors.
##
## Resuelve factories mediante
## RuntimeFactoryKey exacta.
##
## No ejecuta build() o release().
##


var _descriptors: Array[RuntimeFactoryDescriptor] = []

var _descriptors_by_profile: Dictionary = {}


func _init(
	descriptors: Array[RuntimeFactoryDescriptor] = []
) -> void:

	_descriptors = descriptors.duplicate()

	_rebuild_index()


# =============================================================================
# COLLECTION API
# =============================================================================

func get_descriptors(
) -> Array[RuntimeFactoryDescriptor]:

	return _descriptors.duplicate()


# =============================================================================
# RESOLVER API
# =============================================================================

func has_factory(
	factory_key: RuntimeFactoryKey
) -> bool:

	if factory_key == null:
		return false

	if not factory_key.is_valid():
		return false

	var profile_id: StringName = (
		factory_key.get_profile_id()
	)

	var profile_version: int = (
		factory_key.get_profile_version()
	)

	var activation_context: int = (
		factory_key.get_activation_context()
	)

	if not _descriptors_by_profile.has(
		profile_id
	):
		return false

	var versions: Dictionary = (
		_descriptors_by_profile[profile_id]
	)

	if not versions.has(
		profile_version
	):
		return false

	var contexts: Dictionary = (
		versions[profile_version]
	)

	return contexts.has(
		activation_context
	)


func get_factory(
	factory_key: RuntimeFactoryKey
) -> Object:

	var descriptor := get_descriptor(
		factory_key
	)

	if descriptor == null:
		return null

	return descriptor.get_factory()


func get_descriptor(
	factory_key: RuntimeFactoryKey
) -> RuntimeFactoryDescriptor:

	if not has_factory(
		factory_key
	):
		return null

	var profile_id: StringName = (
		factory_key.get_profile_id()
	)

	var profile_version: int = (
		factory_key.get_profile_version()
	)

	var activation_context: int = (
		factory_key.get_activation_context()
	)

	var versions: Dictionary = (
		_descriptors_by_profile[profile_id]
	)

	var contexts: Dictionary = (
		versions[profile_version]
	)

	return contexts.get(
		activation_context,
		null
	)


# =============================================================================
# VALIDATION
# =============================================================================

func is_valid(
) -> bool:

	var seen_by_profile: Dictionary = {}

	for descriptor: RuntimeFactoryDescriptor in _descriptors:

		if descriptor == null:
			return false

		if not descriptor.is_valid():
			return false

		var factory_key := descriptor.get_factory_key()

		if factory_key == null:
			return false

		var profile_id: StringName = (
			factory_key.get_profile_id()
		)

		var profile_version: int = (
			factory_key.get_profile_version()
		)

		var activation_context: int = (
			factory_key.get_activation_context()
		)

		var seen_versions: Dictionary = {}

		if seen_by_profile.has(
			profile_id
		):

			seen_versions = seen_by_profile[
				profile_id
			]

		var seen_contexts: Dictionary = {}

		if seen_versions.has(
			profile_version
		):

			seen_contexts = seen_versions[
				profile_version
			]

		if seen_contexts.has(
			activation_context
		):
			return false

		seen_contexts[
			activation_context
		] = true

		seen_versions[
			profile_version
		] = seen_contexts

		seen_by_profile[
			profile_id
		] = seen_versions

		if (
			get_descriptor(
				factory_key
			) != descriptor
		):
			return false

		if (
			get_factory(
				factory_key
			) != descriptor.get_factory()
		):
			return false

	return (
		_count_indexed_descriptors()
		== _descriptors.size()
	)


# =============================================================================
# INDEX
# =============================================================================

func _rebuild_index(
) -> void:

	_descriptors_by_profile.clear()

	for descriptor: RuntimeFactoryDescriptor in _descriptors:

		if descriptor == null:
			continue

		var factory_key := descriptor.get_factory_key()

		if factory_key == null:
			continue

		if not factory_key.is_valid():
			continue

		var profile_id: StringName = (
			factory_key.get_profile_id()
		)

		var profile_version: int = (
			factory_key.get_profile_version()
		)

		var activation_context: int = (
			factory_key.get_activation_context()
		)

		var versions: Dictionary = {}

		if _descriptors_by_profile.has(
			profile_id
		):

			versions = _descriptors_by_profile[
				profile_id
			]

		var contexts: Dictionary = {}

		if versions.has(
			profile_version
		):

			contexts = versions[
				profile_version
			]

		if contexts.has(
			activation_context
		):
			continue

		contexts[
			activation_context
		] = descriptor

		versions[
			profile_version
		] = contexts

		_descriptors_by_profile[
			profile_id
		] = versions


func _count_indexed_descriptors(
) -> int:

	var count: int = 0

	for versions_value: Variant in _descriptors_by_profile.values():

		var versions: Dictionary = (
			versions_value
		)

		for contexts_value: Variant in versions.values():

			var contexts: Dictionary = (
				contexts_value
			)

			count += contexts.size()

	return count
