extends RefCounted
class_name DeviceRoles


##
## DeviceRoles
##
## Catálogo canónico de roles principales
## para Devices.
##
## Un Device tiene un solo rol principal.
## Las capacidades adicionales pertenecen
## a DeviceManifest y DeviceProfile.
##


const SENSOR: StringName = (
	&"sensor"
)

const ACTUATOR: StringName = (
	&"actuator"
)

const LOCAL_CONTROLLER: StringName = (
	&"local_controller"
)

const SUPERVISORY_CONTROLLER: StringName = (
	&"supervisory_controller"
)


const _ALL_ROLES: Array[StringName] = [
	SENSOR,
	ACTUATOR,
	LOCAL_CONTROLLER,
	SUPERVISORY_CONTROLLER,
]


static func is_valid(
	role: StringName
) -> bool:

	return _ALL_ROLES.has(role)


static func get_all(
) -> Array[StringName]:

	return _ALL_ROLES.duplicate()
