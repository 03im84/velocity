extends Node


##
## DeviceBusDispatchMutationTest
##
## Verifica cambios en el registro durante
## bounded FIFO dispatch.
##


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


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusDispatchMutationTest")
	print("========================================")

	_test_subscribe_during_dispatch()
	_test_unsubscribe_during_dispatch()
	_test_clear_during_dispatch()
	_test_invalid_callable()

	_finish_test()


# =============================================================================
# SUBSCRIBE DURING DISPATCH
# =============================================================================

func _test_subscribe_during_dispatch() -> void:

	var bus := DeviceBus.new()

	_active_bus = bus

	_event_log.clear()

	bus.subscribe(
		&"subscribe_test",
		_subscribe_mutator_a
	)

	bus.subscribe(
		&"subscribe_test",
		_subscriber_b
	)

	var root_result: bool = bus.publish(
		&"subscribe_test",
		"outer"
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		root_result,
		"DBM-U01: subscribe cycle completes"
	)

	_expect(
		_event_log == [
			"A:outer",
			"B:outer",
			"A:inner",
			"B:inner",
			"C:inner",
		],
		"DBM-U01: pending message sees new subscriber"
	)

	_expect(
		bus.get_subscriber_count(
			&"subscribe_test"
		) == 3,
		"DBM-U01: new subscriber remains registered"
	)

	_expect(
		report.get_publications_accepted() == 2,
		"DBM-U01: two publications are accepted"
	)

	_expect(
		report.get_callbacks_invoked() == 5,
		"DBM-U01: five callbacks are invoked"
	)

	_active_bus = null


func _subscribe_mutator_a(
	message: Variant
) -> void:

	_event_log.append(
		"A:" + str(message)
	)

	if message != "outer":
		return

	_active_bus.subscribe(
		&"subscribe_test",
		_subscriber_c
	)

	_active_bus.publish(
		&"subscribe_test",
		"inner"
	)


# =============================================================================
# UNSUBSCRIBE DURING DISPATCH
# =============================================================================

func _test_unsubscribe_during_dispatch() -> void:

	var bus := DeviceBus.new()

	_active_bus = bus

	_event_log.clear()

	bus.subscribe(
		&"unsubscribe_test",
		_unsubscribe_mutator_a
	)

	bus.subscribe(
		&"unsubscribe_test",
		_subscriber_b
	)

	bus.subscribe(
		&"unsubscribe_test",
		_subscriber_c
	)

	var root_result: bool = bus.publish(
		&"unsubscribe_test",
		"outer"
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		root_result,
		"DBM-U02: unsubscribe cycle completes"
	)

	_expect(
		_event_log == [
			"A:outer",
			"B:outer",
			"C:outer",
			"A:inner",
			"C:inner",
		],
		"DBM-U02: pending message excludes removed subscriber"
	)

	_expect(
		bus.get_subscriber_count(
			&"unsubscribe_test"
		) == 2,
		"DBM-U02: subscriber is removed permanently"
	)

	_expect(
		report.get_callbacks_invoked() == 5,
		"DBM-U02: five callbacks are invoked"
	)

	_active_bus = null


func _unsubscribe_mutator_a(
	message: Variant
) -> void:

	_event_log.append(
		"A:" + str(message)
	)

	if message != "outer":
		return

	_active_bus.unsubscribe(
		&"unsubscribe_test",
		_subscriber_b
	)

	_active_bus.publish(
		&"unsubscribe_test",
		"inner"
	)


# =============================================================================
# CLEAR DURING DISPATCH
# =============================================================================

func _test_clear_during_dispatch() -> void:

	var bus := DeviceBus.new()

	_active_bus = bus

	_event_log.clear()

	bus.subscribe(
		&"clear_test",
		_clear_mutator_a
	)

	bus.subscribe(
		&"clear_test",
		_subscriber_b
	)

	bus.subscribe(
		&"clear_test",
		_subscriber_c
	)

	var root_result: bool = bus.publish(
		&"clear_test",
		"outer"
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		root_result,
		"DBM-U03: clear cycle completes"
	)

	_expect(
		_event_log == [
			"A:outer",
			"B:outer",
			"C:outer",
		],
		"DBM-U03: current snapshot completes"
	)

	_expect(
		bus.get_topics().is_empty(),
		"DBM-U03: clear removes permanent registry"
	)

	_expect(
		report.get_publications_accepted() == 2,
		"DBM-U03: inner publication is accepted"
	)

	_expect(
		report.get_publications_dispatched() == 2,
		"DBM-U03: inner publication is dispatched"
	)

	_expect(
		report.get_callbacks_invoked() == 3,
		"DBM-U03: inner message has no subscribers"
	)

	_active_bus = null


func _clear_mutator_a(
	message: Variant
) -> void:

	_event_log.append(
		"A:" + str(message)
	)

	if message != "outer":
		return

	_active_bus.clear()

	_active_bus.publish(
		&"clear_test",
		"inner"
	)


# =============================================================================
# INVALID CALLABLE
# =============================================================================

func _test_invalid_callable() -> void:

	var bus := DeviceBus.new()

	_event_log.clear()

	var temporary_subscriber := (
		TemporarySubscriber.new()
	)

	var temporary_callable: Callable = (
		temporary_subscriber.receive
	)

	bus.subscribe(
		&"invalid_test",
		_subscriber_a
	)

	bus.subscribe(
		&"invalid_test",
		temporary_callable
	)

	bus.subscribe(
		&"invalid_test",
		_subscriber_c
	)

	temporary_subscriber.free()

	_expect(
		not temporary_callable.is_valid(),
		"DBM-U04: temporary Callable is invalid"
	)

	var root_result: bool = bus.publish(
		&"invalid_test",
		"message"
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		root_result,
		"DBM-U04: invalid Callable does not abort"
	)

	_expect(
		_event_log == [
			"A:message",
			"C:message",
		],
		"DBM-U04: valid subscribers receive message"
	)

	_expect(
		bus.get_subscriber_count(
			&"invalid_test"
		) == 2,
		"DBM-U04: invalid Callable is pruned"
	)

	_expect(
		report.get_callbacks_invoked() == 2,
		"DBM-U04: only valid callbacks are counted"
	)

	_expect(
		report.is_completed(),
		"DBM-U04: Report is completed"
	)


# =============================================================================
# STANDARD SUBSCRIBERS
# =============================================================================

func _subscriber_a(
	message: Variant
) -> void:

	_event_log.append(
		"A:" + str(message)
	)


func _subscriber_b(
	message: Variant
) -> void:

	_event_log.append(
		"B:" + str(message)
	)


func _subscriber_c(
	message: Variant
) -> void:

	_event_log.append(
		"C:" + str(message)
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
