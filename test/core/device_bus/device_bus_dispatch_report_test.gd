extends Node


##
## DeviceBusDispatchReportTest
##
## Verifica estados, contadores,
## abortos e inmutabilidad del Report.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusDispatchReportTest")
	print("========================================")

	_test_no_dispatch_report()
	_test_completed_report()
	_test_abort_statuses()
	_test_immutable_api()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_no_dispatch_report() -> void:

	var report := DeviceBusDispatchReport.new(
		DeviceBusDispatchReport.Status.NO_DISPATCH,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		&"",
		&""
	)

	_expect(
		report.get_status()
		== DeviceBusDispatchReport.Status.NO_DISPATCH,
		"DBR-U01: status is NO_DISPATCH"
	)

	_expect(
		report.get_publications_accepted() == 0,
		"DBR-U01: accepted starts at zero"
	)

	_expect(
		report.get_publications_dispatched() == 0,
		"DBR-U01: dispatched starts at zero"
	)

	_expect(
		report.get_callbacks_invoked() == 0,
		"DBR-U01: invoked starts at zero"
	)

	_expect(
		report.get_callbacks_skipped() == 0,
		"DBR-U01: skipped starts at zero"
	)

	_expect(
		report.get_publications_dropped() == 0,
		"DBR-U01: dropped starts at zero"
	)

	_expect(
		report.get_pending_peak() == 0,
		"DBR-U01: pending peak starts at zero"
	)

	_expect(
		report.get_elapsed_usec() == 0,
		"DBR-U01: elapsed starts at zero"
	)

	_expect(
		report.get_limit_reached() == &"",
		"DBR-U01: limit starts empty"
	)

	_expect(
		report.get_trigger_topic() == &"",
		"DBR-U01: trigger topic starts empty"
	)

	_expect(
		not report.is_completed(),
		"DBR-U01: NO_DISPATCH is not completed"
	)

	_expect(
		not report.is_aborted(),
		"DBR-U01: NO_DISPATCH is not aborted"
	)


func _test_completed_report() -> void:

	var report := DeviceBusDispatchReport.new(
		DeviceBusDispatchReport.Status.COMPLETED,
		5,
		4,
		12,
		1,
		1,
		3,
		2500,
		&"",
		&"distance_measurement"
	)

	_expect(
		report.get_status()
		== DeviceBusDispatchReport.Status.COMPLETED,
		"DBR-U02: status is COMPLETED"
	)

	_expect(
		report.get_publications_accepted() == 5,
		"DBR-U02: accepted value is preserved"
	)

	_expect(
		report.get_publications_dispatched() == 4,
		"DBR-U02: dispatched value is preserved"
	)

	_expect(
		report.get_callbacks_invoked() == 12,
		"DBR-U02: invoked value is preserved"
	)

	_expect(
		report.get_callbacks_skipped() == 1,
		"DBR-U02: skipped value is preserved"
	)

	_expect(
		report.get_publications_dropped() == 1,
		"DBR-U02: dropped value is preserved"
	)

	_expect(
		report.get_pending_peak() == 3,
		"DBR-U02: pending peak is preserved"
	)

	_expect(
		report.get_elapsed_usec() == 2500,
		"DBR-U02: elapsed value is preserved"
	)

	_expect(
		report.get_limit_reached() == &"",
		"DBR-U02: completed limit is empty"
	)

	_expect(
		report.get_trigger_topic()
		== &"distance_measurement",
		"DBR-U02: trigger topic is preserved"
	)

	_expect(
		report.is_completed(),
		"DBR-U02: COMPLETED is completed"
	)

	_expect(
		not report.is_aborted(),
		"DBR-U02: COMPLETED is not aborted"
	)


func _test_abort_statuses() -> void:

	_expect_abort_status(
		DeviceBusDispatchReport
			.Status.ABORTED_PUBLICATION_BUDGET,
		"publication budget"
	)

	_expect_abort_status(
		DeviceBusDispatchReport
			.Status.ABORTED_CALLBACK_BUDGET,
		"callback budget"
	)

	_expect_abort_status(
		DeviceBusDispatchReport
			.Status.ABORTED_QUEUE_LIMIT,
		"queue limit"
	)

	_expect_abort_status(
		DeviceBusDispatchReport
			.Status.ABORTED_TIME_BUDGET,
		"time budget"
	)


func _test_immutable_api() -> void:

	var report := DeviceBusDispatchReport.new(
		DeviceBusDispatchReport.Status.NO_DISPATCH,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		&"",
		&""
	)

	var setter_names: Array[StringName] = [
		&"set_status",
		&"set_publications_accepted",
		&"set_publications_dispatched",
		&"set_callbacks_invoked",
		&"set_callbacks_skipped",
		&"set_publications_dropped",
		&"set_pending_peak",
		&"set_elapsed_usec",
		&"set_limit_reached",
		&"set_trigger_topic",
	]

	for setter_name: StringName in setter_names:

		_expect(
			not report.has_method(
				setter_name
			),
			"DBR-U04: "
			+ String(setter_name)
			+ " does not exist"
		)


# =============================================================================
# TEST HELPERS
# =============================================================================

func _expect_abort_status(
	status: DeviceBusDispatchReport.Status,
	status_name: String
) -> void:

	var report := DeviceBusDispatchReport.new(
		status,
		2,
		1,
		3,
		1,
		1,
		1,
		1000,
		&"test_limit",
		&"test_topic"
	)

	_expect(
		not report.is_completed(),
		"DBR-U03: "
		+ status_name
		+ " is not completed"
	)

	_expect(
		report.is_aborted(),
		"DBR-U03: "
		+ status_name
		+ " is aborted"
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
