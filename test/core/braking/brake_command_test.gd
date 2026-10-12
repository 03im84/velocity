extends Node


## BrakeCommandTest
##
## Verifica construcción, boundaries, rechazo de valores no
## finitos, timestamp, Topic canónico y límites de responsabilidad.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("BrakeCommandTest")
	print("========================================")

	_test_valid_command()
	_test_boundaries()
	_test_invalid_brake()
	_test_invalid_timestamp()
	_test_contract()

	_finish()


func _test_valid_command() -> void:

	var command := BrakeCommand.new(0.75, 12.5)

	_expect(
		command.is_valid(),
		"BC-U01: finite in-range command is valid"
	)
	_expect(
		command.get_normalized_brake() == 0.75,
		"BC-U01: normalized brake is preserved"
	)
	_expect(
		command.get_timestamp() == 12.5,
		"BC-U01: timestamp is preserved"
	)


func _test_boundaries() -> void:

	_expect(
		BrakeCommand.new(0.0, 0.0).is_valid(),
		"BC-U02: zero brake boundary is valid"
	)
	_expect(
		BrakeCommand.new(1.0, 0.0).is_valid(),
		"BC-U02: full brake boundary is valid"
	)
	_expect(
		BrakeCommand.new(0.5, 0.0).is_valid(),
		"BC-U02: partial brake and zero timestamp are valid"
	)


func _test_invalid_brake() -> void:

	_expect(
		not BrakeCommand.new(1.0001, 0.0).is_valid(),
		"BC-U03: positive brake overflow is rejected"
	)
	_expect(
		not BrakeCommand.new(-0.0001, 0.0).is_valid(),
		"BC-U03: negative brake input is rejected"
	)
	_expect(
		not BrakeCommand.new(NAN, 0.0).is_valid(),
		"BC-U03: NAN brake is rejected"
	)
	_expect(
		not BrakeCommand.new(INF, 0.0).is_valid(),
		"BC-U03: positive infinity brake is rejected"
	)
	_expect(
		not BrakeCommand.new(-INF, 0.0).is_valid(),
		"BC-U03: negative infinity brake is rejected"
	)


func _test_invalid_timestamp() -> void:

	_expect(
		not BrakeCommand.new(0.0, -0.0001).is_valid(),
		"BC-U04: negative timestamp is rejected"
	)
	_expect(
		not BrakeCommand.new(0.0, NAN).is_valid(),
		"BC-U04: NAN timestamp is rejected"
	)
	_expect(
		not BrakeCommand.new(0.0, INF).is_valid(),
		"BC-U04: positive infinity timestamp is rejected"
	)
	_expect(
		not BrakeCommand.new(0.0, -INF).is_valid(),
		"BC-U04: negative infinity timestamp is rejected"
	)


func _test_contract() -> void:

	var command := BrakeCommand.new(0.0, 0.0)

	_expect(
		typeof(BusTopics.BRAKE_COMMAND) == TYPE_STRING_NAME
		and BusTopics.BRAKE_COMMAND == &"brake_command",
		"BC-U05: canonical Brake Topic is preserved"
	)
	_expect(
		command.has_method(&"get_normalized_brake")
		and command.has_method(&"get_timestamp")
		and not command.has_method(&"set_normalized_brake")
		and not command.has_method(&"set_timestamp"),
		"BC-U05: command exposes read-only value API"
	)
	_expect(
		not command.has_method(&"publish")
		and not command.has_method(&"apply_force")
		and not command.has_method(&"get_device_bus"),
		"BC-U05: command has no Bus or physics responsibility"
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
