extends RefCounted


##
## SystemProfileTestResolver
##
## Resolver controlado para pruebas.
##
## No utiliza filesystem.
## No representa DeviceCatalog de producción.
##


const PROFILE_KEY_SEPARATOR: String = "|"


var _profiles_by_key: Dictionary = {}


func register_profile(
	profile: DeviceProfile
) -> bool:

	if profile == null:
		return false

	return register_profile_as(
		profile.get_profile_id(),
		profile.get_profile_version(),
		profile
	)


func register_profile_as(
	profile_id: StringName,
	profile_version: int,
	profile: DeviceProfile
) -> bool:

	if profile_id == &"":
		return false

	if profile_version <= 0:
		return false

	var key := _build_key(
		profile_id,
		profile_version
	)

	if _profiles_by_key.has(key):
		return false

	_profiles_by_key[key] = profile

	return true


func has_profile(
	profile_id: StringName,
	profile_version: int
) -> bool:

	var key := _build_key(
		profile_id,
		profile_version
	)

	return _profiles_by_key.has(key)


func get_profile(
	profile_id: StringName,
	profile_version: int
) -> DeviceProfile:

	var key := _build_key(
		profile_id,
		profile_version
	)

	return _profiles_by_key.get(
		key,
		null
	)


func clear(
) -> void:

	_profiles_by_key.clear()


func get_profile_count(
) -> int:

	return _profiles_by_key.size()


func _build_key(
	profile_id: StringName,
	profile_version: int
) -> String:

	return (
		String(profile_id)
		+ PROFILE_KEY_SEPARATOR
		+ str(profile_version)
	)
