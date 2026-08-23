extends Node


##
## PortSemanticKindsTest
##
## Verifica tipos, valores, validación
## e independencia del catálogo.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("PortSemanticKindsTest")
	print("========================================")

	_test_types()
	_test_values()
	_test_valid_kinds()
	_test_invalid_kinds()
	_test_get_all()

	_finish_test()


# =============================================================================
# TYPES
# =============================================================================

func _test_types() -> void:

	_expect(
		typeof(
			PortSemanticKinds.UNSPECIFIED
		) == TYPE_STRING_NAME,
		"PSK-U01: UNSPECIFIED is StringName"
	)

	_expect(
		typeof(
			PortSemanticKinds.MEASUREMENT
		) == TYPE_STRING_NAME,
		"PSK-U01: MEASUREMENT is StringName"
	)

	_expect(
		typeof(
			PortSemanticKinds.COMMAND
		) == TYPE_STRING_NAME,
		"PSK-U01: COMMAND is StringName"
	)

	_expect(
		typeof(
			PortSemanticKinds.SETPOINT
		) == TYPE_STRING_NAME,
		"PSK-U01: SETPOINT is StringName"
	)

	_expect(
		typeof(
			PortSemanticKinds.RESULT
		) == TYPE_STRING_NAME,
		"PSK-U01: RESULT is StringName"
	)

	_expect(
		typeof(
			PortSemanticKinds.STATE
		) == TYPE_STRING_NAME,
		"PSK-U01: STATE is StringName"
	)

	_expect(
		typeof(
			PortSemanticKinds.HEALTH
		) == TYPE_STRING_NAME,
		"PSK-U01: HEALTH is StringName"
	)

	_expect(
		typeof(
			PortSemanticKinds.EVENT
		) == TYPE_STRING_NAME,
		"PSK-U01: EVENT is StringName"
	)


# =============================================================================
# VALUES
# =============================================================================

func _test_values() -> void:

	_expect(
		PortSemanticKinds.UNSPECIFIED
		== &"unspecified",
		"PSK-U02: UNSPECIFIED value is correct"
	)

	_expect(
		PortSemanticKinds.MEASUREMENT
		== &"measurement",
		"PSK-U02: MEASUREMENT value is correct"
	)

	_expect(
		PortSemanticKinds.COMMAND
		== &"command",
		"PSK-U02: COMMAND value is correct"
	)

	_expect(
		PortSemanticKinds.SETPOINT
		== &"setpoint",
		"PSK-U02: SETPOINT value is correct"
	)

	_expect(
		PortSemanticKinds.RESULT
		== &"result",
		"PSK-U02: RESULT value is correct"
	)

	_expect(
		PortSemanticKinds.STATE
		== &"state",
		"PSK-U02: STATE value is correct"
	)

	_expect(
		PortSemanticKinds.HEALTH
		== &"health",
		"PSK-U02: HEALTH value is correct"
	)

	_expect(
		PortSemanticKinds.EVENT
		== &"event",
		"PSK-U02: EVENT value is correct"
	)


# =============================================================================
# VALIDATION
# =============================================================================

func _test_valid_kinds() -> void:

	var kinds: Array[StringName] = (
		PortSemanticKinds.get_all()
	)

	for kind: StringName in kinds:

		_expect(
			PortSemanticKinds.is_valid(
				kind
			),
			"PSK-U03: "
			+ String(kind)
			+ " is valid"
		)


func _test_invalid_kinds() -> void:

	_expect(
		not PortSemanticKinds.is_valid(
			&""
		),
		"PSK-U04: empty kind is invalid"
	)

	_expect(
		not PortSemanticKinds.is_valid(
			&"unknown_kind"
		),
		"PSK-U04: unknown kind is invalid"
	)


# =============================================================================
# COPY
# =============================================================================

func _test_get_all() -> void:

	var kinds: Array[StringName] = (
		PortSemanticKinds.get_all()
	)

	_expect(
		kinds == [
			PortSemanticKinds.UNSPECIFIED,
			PortSemanticKinds.MEASUREMENT,
			PortSemanticKinds.COMMAND,
			PortSemanticKinds.SETPOINT,
			PortSemanticKinds.RESULT,
			PortSemanticKinds.STATE,
			PortSemanticKinds.HEALTH,
			PortSemanticKinds.EVENT,
		],
		"PSK-U05: get_all returns all kinds"
	)

	kinds.clear()

	_expect(
		PortSemanticKinds.get_all().size() == 8,
		"PSK-U05: returned Array is independent"
	)


# =============================================================================
# TEST UTILITIES
# =============================================================================

func _expect(
	condition: bool,
	description: String
) -> void:

	_check_count += 1

	if condition:
		print("[PASS] ", description)
		return

	_failure_count += 1

	push_error(
		"[FAIL] " + description
	)


func _finish_test() -> void:

	print("----------------------------------------")
	print("Checks: ", _check_count)
	print("Failures: ", _failure_count)

	if _failure_count == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")

	print("========================================")
	print("")

	get_tree().quit(
		_failure_count
	)
