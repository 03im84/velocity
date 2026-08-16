extends Node


##
## BusTopicsContractTest
##
## Verifica el tipo, valor y existencia de
## los topics canónicos de Velocity.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("BusTopicsContractTest")
	print("========================================")

	_test_topic_types()
	_test_topic_values()
	_test_topics_are_not_empty()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_topic_types() -> void:

	_expect(
		typeof(BusTopics.TEST_MESSAGE)
		== TYPE_STRING_NAME,
		"TC-U01: TEST_MESSAGE is StringName"
	)

	_expect(
		typeof(BusTopics.DISTANCE_MEASUREMENT)
		== TYPE_STRING_NAME,
		"TC-U01: DISTANCE_MEASUREMENT is StringName"
	)

	_expect(
		typeof(BusTopics.TEMPERATURE_MEASUREMENT)
		== TYPE_STRING_NAME,
		"TC-U01: TEMPERATURE_MEASUREMENT is StringName"
	)

	_expect(
		typeof(BusTopics.HEALTH_REPORT)
		== TYPE_STRING_NAME,
		"TC-U01: HEALTH_REPORT is StringName"
	)

	_expect(
		typeof(BusTopics.PROPULSION_COMMAND)
		== TYPE_STRING_NAME,
		"TC-U01: PROPULSION_COMMAND is StringName"
	)


func _test_topic_values() -> void:

	_expect(
		BusTopics.TEST_MESSAGE
		== &"test_message",
		"TC-U02: TEST_MESSAGE has canonical value"
	)

	_expect(
		BusTopics.DISTANCE_MEASUREMENT
		== &"distance_measurement",
		"TC-U02: DISTANCE_MEASUREMENT has canonical value"
	)

	_expect(
		BusTopics.TEMPERATURE_MEASUREMENT
		== &"temperature_measurement",
		"TC-U02: TEMPERATURE_MEASUREMENT has canonical value"
	)

	_expect(
		BusTopics.HEALTH_REPORT
		== &"health_report",
		"TC-U02: HEALTH_REPORT has canonical value"
	)

	_expect(
		BusTopics.PROPULSION_COMMAND
		== &"propulsion_command",
		"TC-U02: PROPULSION_COMMAND has canonical value"
	)


func _test_topics_are_not_empty() -> void:

	_expect(
		BusTopics.TEST_MESSAGE != &"",
		"TC-U03: TEST_MESSAGE is not empty"
	)

	_expect(
		BusTopics.DISTANCE_MEASUREMENT != &"",
		"TC-U03: DISTANCE_MEASUREMENT is not empty"
	)

	_expect(
		BusTopics.TEMPERATURE_MEASUREMENT != &"",
		"TC-U03: TEMPERATURE_MEASUREMENT is not empty"
	)

	_expect(
		BusTopics.HEALTH_REPORT != &"",
		"TC-U03: HEALTH_REPORT is not empty"
	)

	_expect(
		BusTopics.PROPULSION_COMMAND != &"",
		"TC-U03: PROPULSION_COMMAND is not empty"
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
