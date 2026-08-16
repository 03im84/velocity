extends RefCounted
class_name BusTopics


##
## BusTopics
##
## Catálogo canónico de topics internos
## conocidos por Velocity.
##
## Todos los topics utilizan StringName
## y lower_snake_case.
##


const TEST_MESSAGE: StringName = (
	&"test_message"
)

const DISTANCE_MEASUREMENT: StringName = (
	&"distance_measurement"
)

const TEMPERATURE_MEASUREMENT: StringName = (
	&"temperature_measurement"
)

const HEALTH_REPORT: StringName = (
	&"health_report"
)

const PROPULSION_COMMAND: StringName = (
	&"propulsion_command"
)
