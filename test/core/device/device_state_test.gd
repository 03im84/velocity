extends Node


##
## DeviceStateTest
##
## Verifica validez y timestamp de DeviceState.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceStateTest")
	print("========================================")

	_test_initial_state()
	_test_validate()
	_test_timestamp()
	_test_invalidate()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_initial_state() -> void:

	var state := DeviceState.new()

	_expect(
		not state.is_valid(),
		"DS-U01: initial data is invalid"
	)

	_expect(
		state.get_last_update_time() == 0.0,
		"DS-U01: initial timestamp is zero"
	)


func _test_validate() -> void:

	var state := DeviceState.new()

	state.validate()

	_expect(
		state.is_valid(),
		"DS-U02: validate marks data valid"
	)


func _test_timestamp() -> void:

	var state := DeviceState.new()

	state.update_timestamp(
		25.5
	)

	_expect(
		state.get_last_update_time() == 25.5,
		"DS-U03: timestamp is preserved"
	)


func _test_invalidate() -> void:

	var state := DeviceState.new()

	state.validate()

	state.update_timestamp(
		25.5
	)

	state.invalidate()

	_expect(
		not state.is_valid(),
		"DS-U04: invalidate marks data invalid"
	)

	_expect(
		state.get_last_update_time() == 25.5,
		"DS-U04: invalidate preserves timestamp"
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
