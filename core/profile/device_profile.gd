extends Resource
class_name DeviceProfile


##
## DeviceProfile
##
## Snapshot validado e inmutable por contrato
## de un modelo de Device.
##
## Los Arrays se copian durante construcción
## y al ser consultados.
##


# =============================================================================
# STORED STATE
# =============================================================================

@export_storage var _profile_id: StringName = &""

@export_storage var _profile_version: int = 1

@export_storage var _display_name: String = ""

@export_storage var _description: String = ""

@export_storage var _primary_role: StringName = &""

@export_storage var _capabilities: Array[String] = []

@export_storage var _supported_publishes: Array[StringName] = []

@export_storage var _supported_subscribes: Array[StringName] = []

@export_storage var _requirements: Array[String] = []

@export_storage var _canonical: bool = false

@export_storage var _based_on_profile_id: StringName = &""

@export_storage var _based_on_profile_version: int = 0


# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(
	profile_id: StringName = &"",
	profile_version: int = 1,
	display_name: String = "",
	description: String = "",
	primary_role: StringName = &"",
	capabilities: Array[String] = [],
	supported_publishes: Array[StringName] = [],
	supported_subscribes: Array[StringName] = [],
	requirements: Array[String] = [],
	canonical: bool = false,
	based_on_profile_id: StringName = &"",
	based_on_profile_version: int = 0
) -> void:

	_profile_id = profile_id

	_profile_version = profile_version

	_display_name = display_name

	_description = description

	_primary_role = primary_role

	_capabilities = capabilities.duplicate()

	_supported_publishes = (
		supported_publishes.duplicate()
	)

	_supported_subscribes = (
		supported_subscribes.duplicate()
	)

	_requirements = requirements.duplicate()

	_canonical = canonical

	_based_on_profile_id = based_on_profile_id

	_based_on_profile_version = (
		based_on_profile_version
	)


# =============================================================================
# VALIDATION
# =============================================================================

func is_valid() -> bool:

	if _profile_id == &"":
		return false

	if _profile_version <= 0:
		return false

	if _display_name.is_empty():
		return false

	if not DeviceRoles.is_valid(
		_primary_role
	):
		return false

	if _has_duplicates(_capabilities):
		return false

	if _has_duplicates(
		_supported_publishes
	):
		return false

	if _has_duplicates(
		_supported_subscribes
	):
		return false

	if _has_duplicates(_requirements):
		return false

	if _based_on_profile_id == &"":

		return (
			_based_on_profile_version == 0
		)

	return _based_on_profile_version > 0


# =============================================================================
# PUBLIC API
# =============================================================================

func get_profile_id() -> StringName:

	return _profile_id


func get_profile_version() -> int:

	return _profile_version


func get_display_name() -> String:

	return _display_name


func get_description() -> String:

	return _description


func get_primary_role() -> StringName:

	return _primary_role


func get_capabilities() -> Array[String]:

	return _capabilities.duplicate()


func get_supported_publishes(
) -> Array[StringName]:

	return _supported_publishes.duplicate()


func get_supported_subscribes(
) -> Array[StringName]:

	return _supported_subscribes.duplicate()


func get_requirements() -> Array[String]:

	return _requirements.duplicate()


func is_canonical() -> bool:

	return _canonical


func get_based_on_profile_id() -> StringName:

	return _based_on_profile_id


func get_based_on_profile_version() -> int:

	return _based_on_profile_version


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
