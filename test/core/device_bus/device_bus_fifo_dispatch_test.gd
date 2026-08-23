extends Node


##
## DeviceBusFifoDispatchTest
##
## Verifica:
##
## - Report inicial;
## - Policy inválida;
## - orden FIFO reentrante;
## - cadena iterativa;
## - Policy lock.
##


const CHAIN_LAST_VALUE: int = 255


var _check_count: int = 0
var _failure_count: int = 0

var _active_bus: DeviceBus = null

var _event_log: Array[String] = []

var _nested_publication_accepted: bool = false

var _chain_count: int = 0
var _chain_last_value: int = -1
var _chain_enqueue_failed: bool = false


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusFifoDispatchTest")
	print("========================================")

	_test_initial_report()
	_test_invalid_policy()
	_test_fifo_reentrant_order()
	_test_long_iterative_chain()
	_test_policy_lock()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_initial_report() -> void:

	var bus := DeviceBus.new()

	var report := bus.get_last_dispatch_report()

	_expect(
		report.get_status()
		== DeviceBusDispatchReport.Status.NO_DISPATCH,
		"DBF-U00: initial Report is NO_DISPATCH"
	)

	_expect(
		not report.is_completed()
		and not report.is_aborted(),
		"DBF-U00: initial Report is neutral"
	)


func _test_invalid_policy() -> void:

	var bus := DeviceBus.new()

	var default_policy := (
		bus.get_dispatch_policy()
	)

	var invalid_policy := (
		DeviceBusDispatchPolicy.new(
			0,
			4,
			2,
			100000
		)
	)

	_expect(
		not bus.configure_dispatch_policy(
			invalid_policy
		),
		"DBF-U00: invalid Policy is rejected"
	)

	_expect(
		bus.get_dispatch_policy()
		== default_policy,
		"DBF-U00: default Policy is preserved"
	)


func _test_fifo_reentrant_order() -> void:

	var bus := DeviceBus.new()

	_active_bus = bus

	_event_log.clear()

	_nested_publication_accepted = false

	bus.subscribe(
		&"fifo_test",
		_fifo_subscriber_a
	)

	bus.subscribe(
		&"fifo_test",
		_fifo_subscriber_b
	)

	var root_result: bool = bus.publish(
		&"fifo_test",
		"outer"
	)

	_expect(
		root_result,
		"DBF-U01: root publication completes"
	)

	_expect(
		_nested_publication_accepted,
		"DBF-U01: reentrant publication is accepted"
	)

	_expect(
		_event_log == [
			"A:outer",
			"B:outer",
			"A:inner",
			"B:inner",
		],
		"DBF-U01: reentrant order is FIFO"
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		report.is_completed(),
		"DBF-U03: FIFO cycle is completed"
	)

	_expect(
		report.get_publications_accepted() == 2,
		"DBF-U03: two publications are accepted"
	)

	_expect(
		report.get_publications_dispatched() == 2,
		"DBF-U03: two publications are dispatched"
	)

	_expect(
		report.get_callbacks_invoked() == 4,
		"DBF-U03: four callbacks are invoked"
	)

	_active_bus = null


func _test_long_iterative_chain() -> void:

	var bus := DeviceBus.new()

	var chain_policy := (
		DeviceBusDispatchPolicy.new(
			300,
			300,
			4,
			DeviceBusDispatchPolicy
				.HARD_MAX_DISPATCH_TIME_USEC
		)
	)

	_expect(
		bus.configure_dispatch_policy(
			chain_policy
		),
		"DBF-U02: chain Policy is configured"
	)

	_active_bus = bus

	_chain_count = 0
	_chain_last_value = -1
	_chain_enqueue_failed = false

	bus.subscribe(
		&"chain_test",
		_chain_subscriber
	)

	var root_result: bool = bus.publish(
		&"chain_test",
		0
	)

	_expect(
		root_result,
		"DBF-U02: iterative chain completes"
	)

	_expect(
		not _chain_enqueue_failed,
		"DBF-U02: all chain entries are accepted"
	)

	_expect(
		_chain_count
		== CHAIN_LAST_VALUE + 1,
		"DBF-U02: all chain messages are delivered"
	)

	_expect(
		_chain_last_value
		== CHAIN_LAST_VALUE,
		"DBF-U02: chain reaches final value"
	)

	var report := bus.get_last_dispatch_report()

	_expect(
		report.is_completed(),
		"DBF-U02: chain Report is completed"
	)

	_expect(
		report.get_publications_accepted()
		== CHAIN_LAST_VALUE + 1,
		"DBF-U02: Report counts accepted entries"
	)

	_expect(
		report.get_publications_dispatched()
		== CHAIN_LAST_VALUE + 1,
		"DBF-U02: Report counts dispatched entries"
	)

	_expect(
		report.get_callbacks_invoked()
		== CHAIN_LAST_VALUE + 1,
		"DBF-U02: Report counts callbacks"
	)

	_expect(
		report.get_pending_peak() == 1,
		"DBF-U02: iterative chain pending peak is one"
	)

	_active_bus = null


func _test_policy_lock() -> void:

	var bus := DeviceBus.new()

	var first_policy := (
		DeviceBusDispatchPolicy.new(
			3,
			4,
			2,
			100000
		)
	)

	var replacement_policy := (
		DeviceBusDispatchPolicy.new(
			5,
			6,
			3,
			150000
		)
	)

	_expect(
		bus.configure_dispatch_policy(
			first_policy
		),
		"DBF-U04: Policy configures before dispatch"
	)

	_expect(
		bus.get_dispatch_policy()
		== first_policy,
		"DBF-U04: configured Policy is active"
	)

	_expect(
		bus.publish(
			&"no_subscribers",
			"message"
		),
		"DBF-U04: first cycle completes"
	)

	_expect(
		not bus.configure_dispatch_policy(
			replacement_policy
		),
		"DBF-U04: Policy change after dispatch is rejected"
	)

	_expect(
		bus.get_dispatch_policy()
		== first_policy,
		"DBF-U04: original Policy is preserved"
	)


# =============================================================================
# FIFO SUBSCRIBERS
# =============================================================================

func _fifo_subscriber_a(
	message: Variant
) -> void:

	_event_log.append(
		"A:" + str(message)
	)

	if message == "outer":

		_nested_publication_accepted = (
			_active_bus.publish(
				&"fifo_test",
				"inner"
			)
		)


func _fifo_subscriber_b(
	message: Variant
) -> void:

	_event_log.append(
		"B:" + str(message)
	)


# =============================================================================
# CHAIN SUBSCRIBER
# =============================================================================

func _chain_subscriber(
	message: Variant
) -> void:

	var value: int = message

	_chain_count += 1

	_chain_last_value = value

	if value >= CHAIN_LAST_VALUE:
		return

	var accepted: bool = (
		_active_bus.publish(
			&"chain_test",
			value + 1
		)
	)

	if not accepted:
		_chain_enqueue_failed = true


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
