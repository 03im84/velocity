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
