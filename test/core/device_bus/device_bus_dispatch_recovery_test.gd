extends Node


##
## DeviceBusDispatchRecoveryTest
##
## Verifica que DeviceBus pueda ejecutar un
## ciclo válido después de un aborto.
##


var _check_count: int = 0
var _failure_count: int = 0

var _active_bus: DeviceBus = null

var _storm_enabled: bool = false

var _event_log: Array[String] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusDispatchRecoveryTest")
	print("========================================")

	_test_recovery_after_abort()

	_finish_test()


# =============================================================================
# TEST
# =============================================================================

func _test_recovery_after_abort() -> void:

	var bus := DeviceBus.new()

	var policy := DeviceBusDispatchPolicy.new(
		3,
		10,
		10,
		500000
	)

	_expect(
		bus.configure_dispatch_policy(
			policy
		),
		"DBRC-U01: recovery Policy is configured"
	)

	_active_bus = bus

	_storm_enabled = true

	_event_log.clear()

	bus.subscribe(
		&"recovery_test",
		_recovery_subscriber
	)

	# ---------------------------------------------------------
	# FIRST CYCLE — INTENTIONAL ABORT
	# ---------------------------------------------------------

	var first_result: bool = bus.publish(
		&"recovery_test",
		0
	)

	var first_report := (
		bus.get_last_dispatch_report()
	)

	_expect(
		not first_result,
		"DBRC-U01: first cycle aborts"
	)

	_expect(
		first_report.get_status()
		== DeviceBusDispatchReport
			.Status.ABORTED_PUBLICATION_BUDGET,
		"DBRC-U01: first Report contains abort"
	)

	_expect(
		first_report.get_publications_dropped() == 1,
		"DBRC-U01: first Report contains dropped publication"
	)

	_expect(
		bus.get_subscriber_count(
			&"recovery_test"
		) == 1,
		"DBRC-U02: subscription survives abort"
	)

	# ---------------------------------------------------------
	# SECOND CYCLE — RECOVERY
	# ---------------------------------------------------------

	_storm_enabled = false

	_event_log.clear()

	var second_result: bool = bus.publish(
		&"recovery_test",
		"recovered"
	)

	var second_report := (
		bus.get_last_dispatch_report()
	)

	_expect(
		second_result,
		"DBRC-U01: second cycle completes"
	)

	_expect(
		_event_log == [
			"recovered",
		],
		"DBRC-U03: aborted queue does not leak entries"
	)

	_expect(
		second_report.is_completed(),
		"DBRC-U01: second Report is completed"
	)

	_expect(
		second_report.get_publications_accepted() == 1,
		"DBRC-U03: second cycle accepts one publication"
	)

	_expect(
		second_report.get_publications_dispatched() == 1,
		"DBRC-U03: second cycle dispatches one publication"
	)

	_expect(
		second_report.get_callbacks_invoked() == 1,
		"DBRC-U03: second cycle invokes one callback"
	)

	_expect(
		second_report.get_publications_dropped() == 0,
		"DBRC-U03: second cycle drops nothing"
	)

	_expect(
		second_report != first_report,
		"DBRC-U04: second Report is a new instance"
	)

	_expect(
		bus.get_last_dispatch_report()
		== second_report,
		"DBRC-U04: Last Report points to second cycle"
	)

	_expect(
		first_report.is_aborted(),
		"DBRC-U04: first Report remains immutable"
	)

	_active_bus = null


# =============================================================================
# SUBSCRIBER
# =============================================================================

func _recovery_subscriber(
	message: Variant
) -> void:

	_event_log.append(
		str(message)
	)

	if not _storm_enabled:
		return

	var value: int = message

	_active_bus.publish(
		&"recovery_test",
		value + 1
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
