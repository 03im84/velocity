extends RefCounted
class_name PortSemanticKinds


##
## PortSemanticKinds
##
## Catálogo canónico del significado lógico
## de los flujos representados por Ports.
##
## No modifica el routing de DeviceBus.
##


const UNSPECIFIED: StringName = (
	&"unspecified"
)

const MEASUREMENT: StringName = (
	&"measurement"
)

const COMMAND: StringName = (
	&"command"
)

const SETPOINT: StringName = (
	&"setpoint"
)

const RESULT: StringName = (
	&"result"
)

const STATE: StringName = (
	&"state"
)

const HEALTH: StringName = (
	&"health"
)

const EVENT: StringName = (
	&"event"
)


const _ALL_KINDS: Array[StringName] = [
	UNSPECIFIED,
	MEASUREMENT,
	COMMAND,
	SETPOINT,
	RESULT,
	STATE,
	HEALTH,
	EVENT,
]


static func is_valid(
	kind: StringName
) -> bool:

	return _ALL_KINDS.has(kind)


static func get_all(
) -> Array[StringName]:

	return _ALL_KINDS.duplicate()
