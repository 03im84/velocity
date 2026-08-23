extends Node


##
## DeviceBusDispatchBudgetTest
##
## Verifica abortos controlados por:
##
## - Publication Budget;
## - Callback Budget;
## - Queue Size Limit;
## - Time Budget.
##


var _check_count: int = 0
var _failure_count: int = 0

var _active_bus: DeviceBus = null

var _publication_chain_value: int = -1

var _callback_log: Array[String] = []

var _queue_publish_results: Array[bool] = []

var _time_log: Array[String] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusDispatchBudgetTest")
	print("========================================")

	_test_publication_budget()
	_test_callback_budget()
	_test_queue_limit()
	_test_time_budget()

	_finish_test()


# =============================================================================
# PUBLICATION BUDGET
# =============================================================================

func _test_publication_budget() -> void:

	var bus := DeviceBus.new()

	var policy := DeviceBusDispatchPolicy.new(
		3,
		100,
		10,
		500000
	)

	bus.configure_dispatch_policy(policy)

	_active_bus = bus

	_publication_chain_value = -1

	bus.subscribe(
		&"publication_budget_test",
		_publication_chain_subscriber
	)

	var root_result: bool = bus.publish(
		&"publication_budget_test",
		0
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		not root_result,
		"DBB-U01: root publish reports abort"
	)

	_expect(
		report.get_status()
		== DeviceBusDispatchReport
			.Status.ABORTED_PUBLICATION_BUDGET,
		"DBB-U01: status is publication budget"
	)

	_expect(
		report.get_limit_reached()
		== &"publication_budget",
		"DBB-U01: publication limit is identified"
	)

	_expect(
		report.get_publications_accepted() == 3,
		"DBB-U01: three publications are accepted"
	)

	_expect(
		report.get_publications_dispatched() == 3,
		"DBB-U01: three publications are dispatched"
	)

	_expect(
		report.get_callbacks_invoked() == 3,
		"DBB-U01: three callbacks are invoked"
	)

	_expect(
		report.get_publications_dropped() == 1,
		"DBB-U01: rejected publication is dropped"
	)

	_expect(
		bus.get_subscriber_count(
			&"publication_budget_test"
		) == 1,
		"DBB-U01: subscription survives abort"
	)

	_active_bus = null


func _publication_chain_subscriber(
	message: Variant
) -> void:

	var value: int = message

	_publication_chain_value = value

	_active_bus.publish(
		&"publication_budget_test",
		value + 1
	)


# =============================================================================
# CALLBACK BUDGET
# =============================================================================

func _test_callback_budget() -> void:

	var bus := DeviceBus.new()

	var policy := DeviceBusDispatchPolicy.new(
		10,
		2,
		10,
		500000
	)

	bus.configure_dispatch_policy(policy)

	_callback_log.clear()

	bus.subscribe(
		&"callback_budget_test",
		_callback_subscriber_a
	)

	bus.subscribe(
		&"callback_budget_test",
		_callback_subscriber_b
	)

	bus.subscribe(
		&"callback_budget_test",
		_callback_subscriber_c
	)

	var root_result: bool = bus.publish(
		&"callback_budget_test",
		"message"
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		not root_result,
		"DBB-U02: callback overflow aborts root"
	)

	_expect(
		report.get_status()
		== DeviceBusDispatchReport
			.Status.ABORTED_CALLBACK_BUDGET,
		"DBB-U02: status is callback budget"
	)

	_expect(
		report.get_limit_reached()
		== &"callback_budget",
		"DBB-U02: callback limit is identified"
	)

	_expect(
		report.get_callbacks_invoked() == 2,
		"DBB-U02: only two callbacks are invoked"
	)

	_expect(
		report.get_callbacks_skipped() == 1,
		"DBB-U02: one callback is skipped"
	)

	_expect(
		_callback_log == [
			"A",
			"B",
		],
		"DBB-U02: third subscriber is not invoked"
	)

	_expect(
		bus.get_subscriber_count(
			&"callback_budget_test"
		) == 3,
		"DBB-U02: subscriptions survive abort"
	)


func _callback_subscriber_a(
	_message: Variant
) -> void:

	_callback_log.append("A")


func _callback_subscriber_b(
	_message: Variant
) -> void:

	_callback_log.append("B")


func _callback_subscriber_c(
	_message: Variant
) -> void:

	_callback_log.append("C")


# =============================================================================
# QUEUE LIMIT
# =============================================================================

func _test_queue_limit() -> void:

	var bus := DeviceBus.new()

	var policy := DeviceBusDispatchPolicy.new(
		10,
		20,
		2,
		500000
	)

	bus.configure_dispatch_policy(policy)

	_active_bus = bus

	_queue_publish_results.clear()

	bus.subscribe(
		&"queue_root",
		_queue_root_subscriber
	)

	var root_result: bool = bus.publish(
		&"queue_root",
		"start"
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		not root_result,
		"DBB-U03: queue overflow aborts root"
	)

	_expect(
		report.get_status()
		== DeviceBusDispatchReport
			.Status.ABORTED_QUEUE_LIMIT,
		"DBB-U03: status is queue limit"
	)

	_expect(
		report.get_limit_reached()
		== &"queue_limit",
		"DBB-U03: queue limit is identified"
	)

	_expect(
		report.get_publications_accepted() == 3,
		"DBB-U03: root and two pending are accepted"
	)

	_expect(
		report.get_publications_dispatched() == 1,
		"DBB-U03: only root is dispatched"
	)

	_expect(
		report.get_publications_dropped() == 3,
		"DBB-U03: two pending and one rejected are dropped"
	)

	_expect(
		report.get_callbacks_invoked() == 1,
		"DBB-U03: root callback is invoked"
	)

	_expect(
		report.get_pending_peak() == 2,
		"DBB-U03: pending peak reaches two"
	)

	_active_bus = null


func _queue_root_subscriber(
	_message: Variant
) -> void:

	_queue_publish_results.append(
		_active_bus.publish(
			&"queue_child",
			"child_1"
		)
	)

	_queue_publish_results.append(
		_active_bus.publish(
			&"queue_child",
			"child_2"
		)
	)

	_queue_publish_results.append(
		_active_bus.publish(
			&"queue_child",
			"child_3"
		)
	)


# =============================================================================
# TIME BUDGET
# =============================================================================

func _test_time_budget() -> void:

	var bus := DeviceBus.new()

	const TIME_BUDGET_USEC: int = 20000

	var policy := DeviceBusDispatchPolicy.new(
		10,
		10,
		10,
		TIME_BUDGET_USEC
	)

	bus.configure_dispatch_policy(policy)

	_time_log.clear()

	bus.subscribe(
		&"time_budget_test",
		_slow_subscriber
	)

	bus.subscribe(
		&"time_budget_test",
		_after_slow_subscriber
	)

	var root_result: bool = bus.publish(
		&"time_budget_test",
		"message"
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		not root_result,
		"DBB-U04: time overflow aborts root"
	)

	_expect(
		report.get_status()
		== DeviceBusDispatchReport
			.Status.ABORTED_TIME_BUDGET,
		"DBB-U04: status is time budget"
	)

	_expect(
		report.get_limit_reached()
		== &"time_budget",
		"DBB-U04: time limit is identified"
	)

	_expect(
		report.get_callbacks_invoked() == 1,
		"DBB-U04: slow callback is invoked"
	)

	_expect(
		report.get_callbacks_skipped() == 1,
		"DBB-U04: following callback is skipped"
	)

	_expect(
		_time_log == [
			"slow",
		],
		"DBB-U04: callback after timeout is not invoked"
	)

	_expect(
		report.get_elapsed_usec()
		>= TIME_BUDGET_USEC,
		"DBB-U04: elapsed reaches time budget"
	)


func _slow_subscriber(
	_message: Variant
) -> void:

	_time_log.append("slow")

	var start_usec: int = (
		Time.get_ticks_usec()
	)

	while (
		Time.get_ticks_usec() - start_usec
		< 40000
	):
		pass


func _after_slow_subscriber(
	_message: Variant
) -> void:

	_time_log.append("after")


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
