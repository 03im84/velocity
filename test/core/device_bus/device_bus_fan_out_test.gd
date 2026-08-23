extends Node


##
## DeviceBusFanOutTest
##
## Verifica que una sola publicación sea
## entregada a múltiples consumidores sin
## duplicar Queue Entries ni mensajes.
##


class MessageProbe:

	extends RefCounted

	var value: int

	func _init(
		p_value: int
	) -> void:

		value = p_value


var _check_count: int = 0
var _failure_count: int = 0

var _received_messages: Array = []

var _event_log: Array[String] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusFanOutTest")
	print("========================================")

	_test_single_publication_fan_out()

	_finish_test()


# =============================================================================
# TEST
# =============================================================================

func _test_single_publication_fan_out() -> void:

	var bus := DeviceBus.new()

	_received_messages.clear()

	_event_log.clear()

	bus.subscribe(
		&"fan_out_test",
		_subscriber_a
	)

	bus.subscribe(
		&"fan_out_test",
		_subscriber_b
	)

	bus.subscribe(
		&"fan_out_test",
		_subscriber_c
	)

	var message := MessageProbe.new(42)

	var publish_result: bool = bus.publish(
		&"fan_out_test",
		message
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		publish_result,
		"DBFO-U01: root publication completes"
	)

	_expect(
		_received_messages.size() == 3,
		"DBFO-U03: all subscribers receive message"
	)

	_expect(
		_received_messages[0] == message,
		"DBFO-U02: subscriber A receives same reference"
	)

	_expect(
		_received_messages[1] == message,
		"DBFO-U02: subscriber B receives same reference"
	)

	_expect(
		_received_messages[2] == message,
		"DBFO-U02: subscriber C receives same reference"
	)

	_expect(
		_event_log == [
			"A",
			"B",
			"C",
		],
		"DBFO-U03: fan-out preserves subscriber order"
	)

	_expect(
		report.is_completed(),
		"DBFO-U01: Report is completed"
	)

	_expect(
		report.get_publications_accepted() == 1,
		"DBFO-U01: only one publication is accepted"
	)

	_expect(
		report.get_publications_dispatched() == 1,
		"DBFO-U01: only one Queue Entry is dispatched"
	)

	_expect(
		report.get_callbacks_invoked() == 3,
		"DBFO-U01: one callback per subscriber"
	)

	_expect(
		report.get_publications_dropped() == 0,
		"DBFO-U03: no publication is dropped"
	)

	_expect(
		report.get_pending_peak() == 1,
		"DBFO-U01: pending peak is one"
	)

	_expect(
		report.get_limit_reached() == &"",
		"DBFO-U03: no safety limit is reached"
	)


# =============================================================================
# SUBSCRIBERS
# =============================================================================

func _subscriber_a(
	message: Variant
) -> void:

	_received_messages.append(message)

	_event_log.append("A")


func _subscriber_b(
	message: Variant
) -> void:

	_received_messages.append(message)

	_event_log.append("B")


func _subscriber_c(
	message: Variant
) -> void:

	_received_messages.append(message)

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
