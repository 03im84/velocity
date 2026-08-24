extends RefCounted
class_name DeviceCatalog


##
## DeviceCatalog
##
## Snapshot inmutable de DeviceProfiles.
##
## Resuelve Profile ID + Profile Version
## mediante coincidencia exacta.
##


var _profiles: Array[DeviceProfile] = []

var _profiles_by_id: Dictionary = {}


func _init(
	profiles: Array[DeviceProfile] = []
) -> void:

	_profiles = profiles.duplicate()

	_rebuild_index()


# =============================================================================
# COLLECTION API
# =============================================================================

func get_profiles(
) -> Array[DeviceProfile]:

	return _profiles.duplicate()


# =============================================================================
# RESOLVER API
# =============================================================================

func has_profile(
	profile_id: StringName,
	profile_version: int
) -> bool:

	if profile_id == &"":
		return false

	if profile_version <= 0:
		return false

	if not _profiles_by_id.has(
		profile_id
	):
		return false

	var versions: Dictionary = (
		_profiles_by_id[profile_id]
	)

	return versions.has(
		profile_version
	)


func get_profile(
	profile_id: StringName,
	profile_version: int
) -> DeviceProfile:

	if not has_profile(
		profile_id,
		profile_version
	):
		return null

	var versions: Dictionary = (
		_profiles_by_id[profile_id]
	)

	return versions.get(
		profile_version,
		null
	)


# =============================================================================
# VALIDATION
# =============================================================================

func is_valid(
) -> bool:

	var seen_by_id: Dictionary = {}

	for profile: DeviceProfile in _profiles:

		if profile == null:
			return false

		if not profile.is_valid():
			return false

		var profile_id: StringName = (
			profile.get_profile_id()
		)

		var profile_version: int = (
			profile.get_profile_version()
		)

		var seen_versions: Dictionary = {}

		if seen_by_id.has(profile_id):

			seen_versions = seen_by_id[
				profile_id
			]

		if seen_versions.has(
			profile_version
		):
			return false

		seen_versions[
			profile_version
		] = true

		seen_by_id[profile_id] = seen_versions

		if (
			get_profile(
				profile_id,
				profile_version
			) != profile
		):
			return false

	return (
		_count_indexed_profiles()
		== _profiles.size()
	)


# =============================================================================
# INDEX
# =============================================================================

func _rebuild_index(
) -> void:

	_profiles_by_id.clear()

	for profile: DeviceProfile in _profiles:

		if profile == null:
			continue

		var profile_id: StringName = (
			profile.get_profile_id()
		)

		var profile_version: int = (
			profile.get_profile_version()
		)

		if profile_id == &"":
			continue

		if profile_version <= 0:
			continue

		var versions: Dictionary = {}

		if _profiles_by_id.has(
			profile_id
		):

			versions = _profiles_by_id[
				profile_id
			]

		if versions.has(
			profile_version
		):

			continue

		versions[
			profile_version
		] = profile

		_profiles_by_id[
			profile_id
		] = versions


func _count_indexed_profiles(
) -> int:

	var count: int = 0

	for versions_value: Variant in _profiles_by_id.values():

		var versions: Dictionary = (
			versions_value
		)

		count += versions.size()

	return count
