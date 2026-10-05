extends RefCounted
class_name BuiltinDeviceProfiles


##
## BuiltinDeviceProfiles
##
## Factory confiable de DeviceProfiles
## canónicos e ideales incluidos con Velocity.
##
## Cada llamada devuelve un snapshot nuevo.
##


static func create_ideal_distance_sensor(
) -> DeviceProfile:

	return DeviceProfile.new(
		&"velocity.distance_sensor.ideal",
		1,
		"Ideal Distance Sensor",
		(
			"Ideal prototype that produces "
			+ "distance measurements."
		),
		DeviceRoles.SENSOR,
		[
			"distance_measurement",
			"health_reporting",
		],
		[
			BusTopics.DISTANCE_MEASUREMENT,
			BusTopics.HEALTH_REPORT,
		],
		[],
		[],
		true,
		&"",
		0
	)


static func create_longitudinal_propulsion_actuator(
) -> DeviceProfile:

	return DeviceProfile.new(
		&"velocity.propulsion.longitudinal",
		1,
		"Longitudinal Propulsion Actuator",
		(
			"Simulation actuator that converts a bounded "
			+ "propulsion command into longitudinal force."
		),
		DeviceRoles.ACTUATOR,
		[
			"longitudinal_propulsion_force",
		],
		[],
		[
			BusTopics.PROPULSION_COMMAND,
		],
		[],
		true,
		&"",
		0
	)
