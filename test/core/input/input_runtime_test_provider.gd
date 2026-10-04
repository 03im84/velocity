extends RefCounted

var command: VehicleControlCommand = VehicleControlCommand.new(
	0.0,
	0.0,
	0.0,
	0.0
)

func sample_intent() -> VehicleControlCommand:
	return command
