extends Node


##
## DeviceBusFailureIsolationTest
##
## Verificación DB-E01.
##
## Produce intencionalmente un error dentro
## del suscriptor B.
##
## El objetivo es comprobar que DeviceBus
## continúa e invoca al suscriptor C.
##


var _check_count: int = 0
var _failure_count: int = 0

var _event_log: Array[String] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusFailureIsolationTest")
	print("========================================")
	print("An intentional GDScript error is expected.")
	print("")

	var bus := DeviceBus.new()

	bus.subscribe(
		&"topic",
		_subscriber_a
	)

	bus.subscribe(
		&"topic",
		_failing_subscriber_b
	)

	bus.subscribe(
		&"topic",
		_subscriber_c
	)

	bus.publish(
		&"topic",
		"message"
	)

	_expect(
		_event_log == [
			"A",
			"B:entered",
			"C",
		],
		"DB-E01: publication continues after subscriber error"
	)

	_expect(
		not _event_log.has("B:after_error"),
		"DB-E01: failing callback stops at its error"
	)

	_finish_test()


# =============================================================================
# SUBSCRIBERS
# =============================================================================

func _subscriber_a(
	_message: Variant
) -> void:

	_event_log.append("A")


func _failing_subscriber_b(
	_message: Variant
) -> void:

	_event_log.append("B:entered")

	var empty_values: Array = []

	var _unreachable_value: Variant = (
		empty_values[10]
	)

	_event_log.append("B:after_error")


func _subscriber_c(
	_message: Variant
) -> void:

	_event_log.append("C")


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

	print("")
	print("Event log: ", _event_log)
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
