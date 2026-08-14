extends Node


##
## DeviceBusPublishTest
##
## Verifica la publicación, el orden,
## las instantáneas, la reentrada y
## la identidad de los mensajes.
##


class MessageProbe:

	extends RefCounted

	var value: int = 42


class TemporarySubscriber:

	extends Node

	func receive(
		_message: Variant
	) -> void:

		pass


var _check_count: int = 0
var _failure_count: int = 0

var _active_bus: DeviceBus = null

var _event_log: Array[String] = []

var _received_messages: Array = []


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusPublishTest")
	print("========================================")

	_test_publish_without_subscribers()
	_test_duplicate_is_delivered_once()
	_test_deterministic_order()
	_test_message_identity()
	_test_invalidated_callable()
	_test_subscribe_during_publish()
	_test_unsubscribe_during_publish()
	_test_clear_during_publish()
	_test_reentrant_publish()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_publish_without_subscribers() -> void:

	var bus := DeviceBus.new()

	_event_log.clear()

	bus.publish(
		&"",
		"ignored"
	)

	_expect(
		_event_log.is_empty(),
		"DB-U01: empty topic produces no delivery"
	)

	bus.publish(
		&"unknown",
		"ignored"
	)

	_expect(
		_event_log.is_empty(),
		"DB-U01: unknown topic produces no delivery"
	)


func _test_duplicate_is_delivered_once() -> void:

	var bus := DeviceBus.new()

	_event_log.clear()

	bus.subscribe(
		&"topic",
		_subscriber_a
	)

	bus.subscribe(
		&"topic",
		_subscriber_a
	)

	bus.publish(
		&"topic",
		"message"
	)

	_expect(
		_event_log == ["A"],
		"DB-U05: duplicate subscription delivers once"
	)


func _test_deterministic_order() -> void:

	var bus := DeviceBus.new()

	_event_log.clear()

	bus.subscribe(
		&"topic",
		_subscriber_a
	)

	bus.subscribe(
		&"topic",
		_subscriber_b
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
			"B",
			"C",
		],
		"DB-U07: delivery follows registration order"
	)


func _test_message_identity() -> void:

	var bus := DeviceBus.new()

	_received_messages.clear()

	var message := MessageProbe.new()

	bus.subscribe(
		&"topic",
		_receive_message_a
	)

	bus.subscribe(
		&"topic",
		_receive_message_b
	)

	bus.publish(
		&"topic",
		message
	)

	_expect(
		_received_messages.size() == 2,
		"DB-U12: both subscribers receive the message"
	)

	var first_received_same_message: bool = (
		_received_messages.size() > 0
		and _received_messages[0] == message
	)

	_expect(
		first_received_same_message,
		"DB-U12: first subscriber receives same reference"
	)

	var second_received_same_message: bool = (
		_received_messages.size() > 1
		and _received_messages[1] == message
	)

	_expect(
		second_received_same_message,
		"DB-U12: second subscriber receives same reference"
	)

	_expect(
		message.value == 42,
		"DB-U12: DeviceBus does not modify message"
	)


func _test_invalidated_callable() -> void:

	var bus := DeviceBus.new()

	_event_log.clear()

	var temporary_subscriber := (
		TemporarySubscriber.new()
	)

	var temporary_callable: Callable = (
		temporary_subscriber.receive
	)

	bus.subscribe(
		&"topic",
		_subscriber_a
	)

	bus.subscribe(
		&"topic",
		temporary_callable
	)

	bus.subscribe(
		&"topic",
		_subscriber_c
	)

	temporary_subscriber.free()

	_expect(
		not temporary_callable.is_valid(),
		"DB-U13: Callable becomes invalid"
	)

	bus.publish(
		&"topic",
		"message"
	)

	_expect(
		_event_log == [
			"A",
			"C",
		],
		"DB-U13: invalid Callable is skipped"
	)

	_expect(
		bus.get_subscriber_count(&"topic") == 2,
		"DB-U13: invalid Callable is pruned"
	)


func _test_subscribe_during_publish() -> void:

	var bus := DeviceBus.new()

	_active_bus = bus
	_event_log.clear()

	bus.subscribe(
		&"topic",
		_subscribe_during_publish_a
	)

	bus.subscribe(
		&"topic",
		_subscriber_b
	)

	bus.publish(
		&"topic",
		"first"
	)

	_expect(
		_event_log == [
			"A",
			"B",
		],
		"DB-U14: new subscriber does not receive current publication"
	)

	_expect(
		bus.get_subscriber_count(&"topic") == 3,
		"DB-U14: new subscriber is registered"
	)

	_event_log.clear()

	bus.publish(
		&"topic",
		"second"
	)

	_expect(
		_event_log == [
			"A",
			"B",
			"C",
		],
		"DB-U14: new subscriber receives next publication"
	)

	_active_bus = null


func _test_unsubscribe_during_publish() -> void:

	var bus := DeviceBus.new()

	_active_bus = bus
	_event_log.clear()

	bus.subscribe(
		&"topic",
		_unsubscribe_during_publish_a
	)

	bus.subscribe(
		&"topic",
		_subscriber_b
	)

	bus.subscribe(
		&"topic",
		_subscriber_c
	)

	bus.publish(
		&"topic",
		"first"
	)

	_expect(
		_event_log == [
			"A",
			"B",
			"C",
		],
		"DB-U15: removed subscriber receives current snapshot"
	)

	_expect(
		bus.get_subscriber_count(&"topic") == 2,
		"DB-U15: subscriber is removed from registry"
	)

	_event_log.clear()

	bus.publish(
		&"topic",
		"second"
	)

	_expect(
		_event_log == [
			"A",
			"C",
		],
		"DB-U15: removed subscriber misses next publication"
	)

	_active_bus = null


func _test_clear_during_publish() -> void:

	var bus := DeviceBus.new()

	_active_bus = bus
	_event_log.clear()

	bus.subscribe(
		&"topic",
		_clear_during_publish_a
	)

	bus.subscribe(
		&"topic",
		_subscriber_b
	)

	bus.subscribe(
		&"topic",
		_subscriber_c
	)

	bus.publish(
		&"topic",
		"first"
	)

	_expect(
		_event_log == [
			"A",
			"B",
			"C",
		],
		"DB-U16: clear does not cancel current snapshot"
	)

	_expect(
		bus.get_topics().is_empty(),
		"DB-U16: clear removes registry"
	)

	_event_log.clear()

	bus.publish(
		&"topic",
		"second"
	)

	_expect(
		_event_log.is_empty(),
		"DB-U16: next publication has no subscribers"
	)

	_active_bus = null


func _test_reentrant_publish() -> void:

	var bus := DeviceBus.new()

	_active_bus = bus
	_event_log.clear()

	bus.subscribe(
		&"topic",
		_reentrant_subscriber_a
	)

	bus.subscribe(
		&"topic",
		_reentrant_subscriber_b
	)

	bus.publish(
		&"topic",
		"outer"
	)

	_expect(
		_event_log == [
			"A:outer",
			"A:inner",
			"B:inner",
			"B:outer",
		],
		"DB-U17: reentrant publication is depth-first"
	)

	_active_bus = null


# =============================================================================
# STANDARD SUBSCRIBERS
# =============================================================================

func _subscriber_a(
	_message: Variant
) -> void:

	_event_log.append("A")


func _subscriber_b(
	_message: Variant
) -> void:

	_event_log.append("B")


func _subscriber_c(
	_message: Variant
) -> void:

	_event_log.append("C")


# =============================================================================
# MESSAGE SUBSCRIBERS
# =============================================================================

func _receive_message_a(
	message: Variant
) -> void:

	_received_messages.append(message)


func _receive_message_b(
	message: Variant
) -> void:

	_received_messages.append(message)


# =============================================================================
# MUTATING SUBSCRIBERS
# =============================================================================

func _subscribe_during_publish_a(
	_message: Variant
) -> void:

	_event_log.append("A")

	_active_bus.subscribe(
		&"topic",
		_subscriber_c
	)


func _unsubscribe_during_publish_a(
	_message: Variant
) -> void:

	_event_log.append("A")

	_active_bus.unsubscribe(
		&"topic",
		_subscriber_b
	)


func _clear_during_publish_a(
	_message: Variant
) -> void:

	_event_log.append("A")

	_active_bus.clear()


# =============================================================================
# REENTRANT SUBSCRIBERS
# =============================================================================

func _reentrant_subscriber_a(
	message: Variant
) -> void:

	_event_log.append(
		"A:" + str(message)
	)

	if message == "outer":

		_active_bus.publish(
			&"topic",
			"inner"
		)


func _reentrant_subscriber_b(
	message: Variant
) -> void:

	_event_log.append(
		"B:" + str(message)
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
