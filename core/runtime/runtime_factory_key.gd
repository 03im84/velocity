extends RefCounted
class_name RuntimeFactoryKey


##
## RuntimeFactoryKey
##
## Identidad lógica exacta de una
## RuntimeFactory.
##
## No resuelve ni ejecuta factories.
##


var _profile_id: StringName

var _profile_version: int

var _activation_context: int


func _init(
	profile_id: StringName,
	profile_version: int,
	activation_context: int
) -> void:

	_profile_id = profile_id

	_profile_version = profile_version

	_activation_context = activation_context


func get_profile_id(
) -> StringName:

	return _profile_id


func get_profile_version(
) -> int:

	return _profile_version


func get_activation_context(
) -> int:

	return _activation_context


func is_valid(
) -> bool:

	if _profile_id == &"":
		return false

	if _profile_version <= 0:
		return false

	if not _activation_context_is_valid(
		_activation_context
	):
		return false

	return true


func equals(
	other: RuntimeFactoryKey
) -> bool:

	if other == null:
		return false

	return (
		_profile_id == other.get_profile_id()
		and _profile_version
		== other.get_profile_version()
		and _activation_context
		== other.get_activation_context()
	)


func _activation_context_is_valid(
	context: int
) -> bool:

	return (
		context
		== DeviceConfiguration.ActivationContext.SIMULATION
		or context
		== DeviceConfiguration.ActivationContext.HARDWARE
	)
