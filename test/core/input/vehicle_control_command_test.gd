extends Node

var _checks := 0
var _failures := 0

func _ready() -> void:
	var command := VehicleControlCommand.new(0.75, -0.5, 0.25, 12.0)
	_expect(command.is_valid(), "VCC-U01: bounded command is valid")
	_expect(command.get_throttle() == 0.75, "VCC-U01: throttle preserved")
	_expect(command.get_steering() == -0.5, "VCC-U01: steering preserved")
	_expect(command.get_brake() == 0.25, "VCC-U01: brake preserved")
	_expect(command.get_timestamp() == 12.0, "VCC-U01: timestamp preserved")
	_expect(VehicleControlCommand.new(-1.0, 1.0, 0.0, 0.0).is_valid(), "VCC-U02: exact boundaries valid")
	_expect(not VehicleControlCommand.new(1.01, 0.0, 0.0, 0.0).is_valid(), "VCC-U03: throttle overflow rejected")
	_expect(not VehicleControlCommand.new(0.0, -1.01, 0.0, 0.0).is_valid(), "VCC-U03: steering overflow rejected")
	_expect(not VehicleControlCommand.new(0.0, 0.0, -0.01, 0.0).is_valid(), "VCC-U03: negative brake rejected")
	_expect(not VehicleControlCommand.new(0.0, 0.0, 0.0, -0.01).is_valid(), "VCC-U03: negative timestamp rejected")
	_expect(BusTopics.VEHICLE_CONTROL_COMMAND == &"vehicle_control_command", "VCC-U04: canonical Topic exists")
	_expect(not command.has_method(&"set_throttle") and not command.has_method(&"set_steering"), "VCC-U05: command exposes no setters")
	print("Checks: ", _checks)
	print("Failures: ", _failures)
	print("RESULT: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(_failures)

func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] ", description)
	else:
		_failures += 1
		push_error("[FAIL] " + description)
