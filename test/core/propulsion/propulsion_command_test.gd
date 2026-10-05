extends Node


## PropulsionCommandTest
##
## Verifica construcción, boundaries, rechazo de valores no
## finitos, timestamp, Topic canónico y límites de responsabilidad.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("PropulsionCommandTest")
	print("========================================")

	_test_valid_command()
	_test_boundaries()
	_test_invalid_thrust()
	_test_invalid_timestamp()
	_test_contract()

	_finish()


func _test_valid_command() -> void:

	var command := PropulsionCommand.new(0.75, 12.5)

	_expect(
		command.is_valid(),
		"PC-U01: finite in-range command is valid"
	)
	_expect(
		command.get_normalized_thrust() == 0.75,
		"PC-U01: normalized thrust is preserved"
	)
	_expect(
		command.get_timestamp() == 12.5,
		"PC-U01: timestamp is preserved"
	)


func _test_boundaries() -> void:

	_expect(
		PropulsionCommand.new(-1.0, 0.0).is_valid(),
		"PC-U02: reverse boundary is valid"
	)
	_expect(
		PropulsionCommand.new(1.0, 0.0).is_valid(),
		"PC-U02: forward boundary is valid"
	)
	_expect(
		PropulsionCommand.new(0.0, 0.0).is_valid(),
		"PC-U02: neutral command and zero timestamp are valid"
	)


func _test_invalid_thrust() -> void:

	_expect(
		not PropulsionCommand.new(1.0001, 0.0).is_valid(),
		"PC-U03: forward overflow is rejected"
	)
	_expect(
		not PropulsionCommand.new(-1.0001, 0.0).is_valid(),
		"PC-U03: reverse overflow is rejected"
	)
	_expect(
		not PropulsionCommand.new(NAN, 0.0).is_valid(),
		"PC-U03: NAN thrust is rejected"
	)
	_expect(
		not PropulsionCommand.new(INF, 0.0).is_valid(),
		"PC-U03: positive infinity thrust is rejected"
	)
	_expect(
		not PropulsionCommand.new(-INF, 0.0).is_valid(),
		"PC-U03: negative infinity thrust is rejected"
	)


func _test_invalid_timestamp() -> void:

	_expect(
		not PropulsionCommand.new(0.0, -0.0001).is_valid(),
		"PC-U04: negative timestamp is rejected"
	)
	_expect(
		not PropulsionCommand.new(0.0, NAN).is_valid(),
		"PC-U04: NAN timestamp is rejected"
	)
	_expect(
		not PropulsionCommand.new(0.0, INF).is_valid(),
		"PC-U04: positive infinity timestamp is rejected"
	)
	_expect(
		not PropulsionCommand.new(0.0, -INF).is_valid(),
		"PC-U04: negative infinity timestamp is rejected"
	)


func _test_contract() -> void:

	var command := PropulsionCommand.new(0.0, 0.0)

	_expect(
		typeof(BusTopics.PROPULSION_COMMAND) == TYPE_STRING_NAME
		and BusTopics.PROPULSION_COMMAND == &"propulsion_command",
		"PC-U05: canonical Propulsion Topic is preserved"
	)
	_expect(
		command.has_method(&"get_normalized_thrust")
		and command.has_method(&"get_timestamp")
		and not command.has_method(&"set_normalized_thrust")
		and not command.has_method(&"set_timestamp"),
		"PC-U05: command exposes read-only value API"
	)
	_expect(
		not command.has_method(&"publish")
		and not command.has_method(&"apply_force")
		and not command.has_method(&"get_device_bus"),
		"PC-U05: command has no Bus or physics responsibility"
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
