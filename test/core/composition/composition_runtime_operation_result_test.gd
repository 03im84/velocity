extends Node


##
## CompositionRuntimeOperationResultTest
##
## Verifica operation, success,
## ValidationReport e inmutabilidad.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("CompositionRuntimeOperationResultTest")
	print("========================================")

	_test_valid_activate_result()
	_test_valid_shutdown_result()
	_test_explicit_failure()
	_test_invalid_operation()
	_test_required_report()
	_test_report_policy()
	_test_contract()

	_finish_test()


# =============================================================================
# VALID ACTIVATE RESULT
# =============================================================================

func _test_valid_activate_result() -> void:

	var report := ValidationReport.new()

	var result := CompositionRuntimeOperationResult.new(
		true,
		CompositionRuntimeOperationResult.OPERATION_ACTIVATE,
		report
	)

	var result_value: Variant = result

	_expect(
		result.is_success(),
		"CROR-U01: valid activate Result succeeds"
	)

	_expect(
		result.get_operation()
		== CompositionRuntimeOperationResult.OPERATION_ACTIVATE
		and result.get_report() == report,
		"CROR-U01: activate operation and Report are preserved"
	)

	_expect(
		result_value is RefCounted
		and not (result_value is Node),
		"CROR-U01: Result is RefCounted and not Node"
	)


# =============================================================================
# VALID SHUTDOWN RESULT
# =============================================================================

func _test_valid_shutdown_result() -> void:

	var result := CompositionRuntimeOperationResult.new(
		true,
		CompositionRuntimeOperationResult.OPERATION_SHUTDOWN,
		ValidationReport.new()
	)

	_expect(
		result.is_success(),
		"CROR-U02: valid shutdown Result succeeds"
	)

	_expect(
		result.get_operation()
		== CompositionRuntimeOperationResult.OPERATION_SHUTDOWN,
		"CROR-U02: shutdown operation is preserved"
	)


# =============================================================================
# EXPLICIT FAILURE
# =============================================================================

func _test_explicit_failure() -> void:

	var result := CompositionRuntimeOperationResult.new(
		false,
		CompositionRuntimeOperationResult.OPERATION_ACTIVATE,
		ValidationReport.new()
	)

	_expect(
		not result.is_success(),
		"CROR-U03: explicit failure remains failed"
	)


# =============================================================================
# INVALID OPERATION
# =============================================================================

func _test_invalid_operation() -> void:

	var empty_operation := CompositionRuntimeOperationResult.new(
		true,
		&"",
		ValidationReport.new()
	)

	var unknown_operation := CompositionRuntimeOperationResult.new(
		true,
		&"restart",
		ValidationReport.new()
	)

	_expect(
		not empty_operation.is_success(),
		"CROR-U04: empty operation is invalid"
	)

	_expect(
		not unknown_operation.is_success(),
		"CROR-U04: unknown operation is invalid"
	)


# =============================================================================
# REQUIRED REPORT
# =============================================================================

func _test_required_report() -> void:

	var result := CompositionRuntimeOperationResult.new(
		true,
		CompositionRuntimeOperationResult.OPERATION_ACTIVATE,
		null
	)

	_expect(
		not result.is_success(),
		"CROR-U05: null Report produces failed Result"
	)


# =============================================================================
# REPORT POLICY
# =============================================================================

func _test_report_policy() -> void:

	var structural_result := _result_with_issue(
		ValidationIssue.Severity.STRUCTURAL_ERROR
	)

	var platform_result := _result_with_issue(
		ValidationIssue.Severity.PLATFORM_SAFETY_ERROR
	)

	var simulation_hazard_result := _result_with_issue(
		ValidationIssue.Severity.SIMULATION_HAZARD
	)

	var hardware_error_result := _result_with_issue(
		ValidationIssue.Severity.HARDWARE_SAFETY_ERROR
	)

	var warning_result := _result_with_issue(
		ValidationIssue.Severity.WARNING
	)

	_expect(
		not structural_result.is_success(),
		"CROR-U06: Structural Error blocks operation success"
	)

	_expect(
		not platform_result.is_success(),
		"CROR-U06: Platform Safety Error blocks operation success"
	)

	_expect(
		simulation_hazard_result.is_success(),
		"CROR-U06: Simulation Hazard is valid for Simulation runtime"
	)

	_expect(
		hardware_error_result.is_success(),
		"CROR-U06: Hardware Safety Error remains modelable in Simulation"
	)

	_expect(
		warning_result.is_success(),
		"CROR-U06: Warning does not block operation success"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var result := CompositionRuntimeOperationResult.new(
		true,
		CompositionRuntimeOperationResult.OPERATION_ACTIVATE,
		ValidationReport.new()
	)

	_expect(
		not result.has_method(
			&"set_success"
		)
		and not result.has_method(
			&"set_operation"
		)
		and not result.has_method(
			&"set_report"
		),
		"CROR-U07: Result exposes no setters"
	)

	_expect(
		not result.has_method(
			&"activate"
		)
		and not result.has_method(
			&"shutdown"
		)
		and not result.has_method(
			&"rollback"
		),
		"CROR-U07: Result does not execute runtime operations"
	)

	_expect(
		not result.has_method(
			&"get_runtime"
		)
		and not result.has_method(
			&"get_plan"
		)
		and not result.has_method(
			&"get_handles"
		),
		"CROR-U07: Result contains no active runtime state"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _result_with_issue(
	severity: int
) -> CompositionRuntimeOperationResult:

	var report := ValidationReport.new()

	report.add_issue(
		ValidationIssue.new(
			&"test_runtime_operation_issue",
			severity,
			"Controlled CompositionRuntimeOperationResult test Issue.",
			"test.runtime_operation",
			&"operation"
		)
	)

	return CompositionRuntimeOperationResult.new(
		true,
		CompositionRuntimeOperationResult.OPERATION_ACTIVATE,
		report
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
