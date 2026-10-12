extends Node


## SteeringCommandTest
##
## Verifica construcción, boundaries, rechazo de valores no
## finitos, timestamp, Topic canónico y límites de responsabilidad.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("SteeringCommandTest")
	print("========================================")

	_test_valid_command()
	_test_boundaries()
	_test_invalid_yaw()
	_test_invalid_timestamp()
	_test_contract()

	_finish()


func _test_valid_command() -> void:

	var command := SteeringCommand.new(0.75, 12.5)

	_expect(
		command.is_valid(),
		"SC-U01: finite in-range command is valid"
	)
	_expect(
		command.get_normalized_yaw() == 0.75,
		"SC-U01: normalized yaw is preserved"
	)
	_expect(
		command.get_timestamp() == 12.5,
		"SC-U01: timestamp is preserved"
	)


func _test_boundaries() -> void:

	_expect(
		SteeringCommand.new(-1.0, 0.0).is_valid(),
		"SC-U02: negative yaw boundary is valid"
	)
	_expect(
		SteeringCommand.new(1.0, 0.0).is_valid(),
		"SC-U02: positive yaw boundary is valid"
	)
	_expect(
		SteeringCommand.new(0.0, 0.0).is_valid(),
		"SC-U02: neutral command and zero timestamp are valid"
	)


func _test_invalid_yaw() -> void:

	_expect(
		not SteeringCommand.new(1.0001, 0.0).is_valid(),
		"SC-U03: positive yaw overflow is rejected"
	)
	_expect(
		not SteeringCommand.new(-1.0001, 0.0).is_valid(),
		"SC-U03: negative yaw overflow is rejected"
	)
	_expect(
		not SteeringCommand.new(NAN, 0.0).is_valid(),
		"SC-U03: NAN yaw is rejected"
	)
	_expect(
		not SteeringCommand.new(INF, 0.0).is_valid(),
		"SC-U03: positive infinity yaw is rejected"
	)
	_expect(
		not SteeringCommand.new(-INF, 0.0).is_valid(),
		"SC-U03: negative infinity yaw is rejected"
	)


func _test_invalid_timestamp() -> void:

	_expect(
		not SteeringCommand.new(0.0, -0.0001).is_valid(),
		"SC-U04: negative timestamp is rejected"
	)
	_expect(
		not SteeringCommand.new(0.0, NAN).is_valid(),
		"SC-U04: NAN timestamp is rejected"
	)
	_expect(
		not SteeringCommand.new(0.0, INF).is_valid(),
		"SC-U04: positive infinity timestamp is rejected"
	)
	_expect(
		not SteeringCommand.new(0.0, -INF).is_valid(),
		"SC-U04: negative infinity timestamp is rejected"
	)


func _test_contract() -> void:

	var command := SteeringCommand.new(0.0, 0.0)

	_expect(
		typeof(BusTopics.STEERING_COMMAND) == TYPE_STRING_NAME
		and BusTopics.STEERING_COMMAND == &"steering_command",
		"SC-U05: canonical Steering Topic is preserved"
	)
	_expect(
		command.has_method(&"get_normalized_yaw")
		and command.has_method(&"get_timestamp")
		and not command.has_method(&"set_normalized_yaw")
		and not command.has_method(&"set_timestamp"),
		"SC-U05: command exposes read-only value API"
	)
	_expect(
		not command.has_method(&"publish")
		and not command.has_method(&"apply_force")
		and not command.has_method(&"get_device_bus"),
		"SC-U05: command has no Bus or physics responsibility"
	)


func _expect(
	condition: bool,
	description: String
) -> void:

	_checks += 1

	if condition:
		print("[PASS] ", description)
		return

	_failures += 1
	push_error("[FAIL] " + description)


func _finish() -> void:

	print("----------------------------------------")
	print("Checks: ", _checks)
	print("Failures: ", _failures)

	if _failures == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")

	print("========================================")
	print("")
	get_tree().quit(_failures)
