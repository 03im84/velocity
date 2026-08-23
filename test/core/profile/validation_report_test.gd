extends Node


##
## ValidationReportTest
##
## Verifica ValidationIssue, severidades,
## contextos y copias independientes.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("ValidationReportTest")
	print("========================================")

	_test_validation_issue()
	_test_empty_report()
	_test_info_and_warning()
	_test_simulation_hazard()
	_test_structural_error()
	_test_platform_safety_error()
	_test_hardware_safety_error()
	_test_independent_copy()
	_test_duplicate_issue()

	_finish_test()


# =============================================================================
# VALIDATION ISSUE
# =============================================================================

func _test_validation_issue() -> void:

	var issue := ValidationIssue.new(
		&"test_issue",
		ValidationIssue.Severity.WARNING,
		"Test warning",
		"device_a",
		&"test_field",
		"Review configuration"
	)

	_expect(
		issue.get_code() == &"test_issue",
		"VR-U01: Issue code is preserved"
	)

	_expect(
		issue.get_severity()
		== ValidationIssue.Severity.WARNING,
		"VR-U01: Issue severity is preserved"
	)

	_expect(
		issue.get_message()
		== "Test warning",
		"VR-U01: Issue message is preserved"
	)

	_expect(
		issue.get_related_object_id()
		== "device_a",
		"VR-U01: related object is preserved"
	)

	_expect(
		issue.get_related_field()
		== &"test_field",
		"VR-U01: related field is preserved"
	)

	_expect(
		issue.get_suggested_action()
		== "Review configuration",
		"VR-U01: suggested action is preserved"
	)

	var setter_names: Array[StringName] = [
		&"set_code",
		&"set_severity",
		&"set_message",
		&"set_related_object_id",
		&"set_related_field",
		&"set_suggested_action",
	]

	for setter_name: StringName in setter_names:

		_expect(
			not issue.has_method(
				setter_name
			),
			"VR-U01: "
			+ String(setter_name)
			+ " does not exist"
		)


# =============================================================================
# EMPTY REPORT
# =============================================================================

func _test_empty_report() -> void:

	var report := ValidationReport.new()

	_expect(
		report.is_empty(),
		"VR-U02: new Report is empty"
	)

	_expect(
		report.get_issue_count() == 0,
		"VR-U02: initial issue count is zero"
	)

	_expect(
		report.is_valid_for_simulation(),
		"VR-U02: empty Report is valid for simulation"
	)

	_expect(
		report.is_valid_for_hardware(),
		"VR-U02: empty Report is valid for hardware"
	)


# =============================================================================
# INFO AND WARNING
# =============================================================================

func _test_info_and_warning() -> void:

	var report := ValidationReport.new()

	_expect(
		report.add_issue(
			_issue(
				ValidationIssue.Severity.INFO,
				&"info"
			)
		),
		"VR-U03: INFO is added"
	)

	_expect(
		report.add_issue(
			_issue(
				ValidationIssue.Severity.WARNING,
				&"warning"
			)
		),
		"VR-U03: WARNING is added"
	)

	_expect(
		report.get_issue_count() == 2,
		"VR-U03: Report contains two issues"
	)

	_expect(
		report.is_valid_for_simulation(),
		"VR-U03: INFO and WARNING allow simulation"
	)

	_expect(
		report.is_valid_for_hardware(),
		"VR-U03: INFO and WARNING allow hardware"
	)


# =============================================================================
# SIMULATION HAZARD
# =============================================================================

func _test_simulation_hazard() -> void:

	var report := ValidationReport.new()

	report.add_issue(
		_issue(
			ValidationIssue.Severity
				.SIMULATION_HAZARD,
			&"simulation_hazard"
		)
	)

	_expect(
		report.has_severity(
			ValidationIssue.Severity
				.SIMULATION_HAZARD
		),
		"VR-U04: Simulation Hazard is detected"
	)

	_expect(
		report.is_valid_for_simulation(),
		"VR-U04: Simulation Hazard allows simulation"
	)

	_expect(
		not report.is_valid_for_hardware(),
		"VR-U04: Simulation Hazard blocks hardware"
	)


# =============================================================================
# STRUCTURAL ERROR
# =============================================================================

func _test_structural_error() -> void:

	var report := ValidationReport.new()

	report.add_issue(
		_issue(
			ValidationIssue.Severity
				.STRUCTURAL_ERROR,
			&"structural_error"
		)
	)

	_expect(
		report.has_severity(
			ValidationIssue.Severity
				.STRUCTURAL_ERROR
		),
		"VR-U05: Structural Error is detected"
	)

	_expect(
		not report.is_valid_for_simulation(),
		"VR-U05: Structural Error blocks simulation"
	)

	_expect(
		not report.is_valid_for_hardware(),
		"VR-U05: Structural Error blocks hardware"
	)


# =============================================================================
# PLATFORM SAFETY ERROR
# =============================================================================

func _test_platform_safety_error() -> void:

	var report := ValidationReport.new()

	report.add_issue(
		_issue(
			ValidationIssue.Severity
				.PLATFORM_SAFETY_ERROR,
			&"platform_error"
		)
	)

	_expect(
		report.has_severity(
			ValidationIssue.Severity
				.PLATFORM_SAFETY_ERROR
		),
		"VR-U06: Platform Safety Error is detected"
	)

	_expect(
		not report.is_valid_for_simulation(),
		"VR-U06: Platform Safety Error blocks simulation"
	)

	_expect(
		not report.is_valid_for_hardware(),
		"VR-U06: Platform Safety Error blocks hardware"
	)


# =============================================================================
# HARDWARE SAFETY ERROR
# =============================================================================

func _test_hardware_safety_error() -> void:

	var report := ValidationReport.new()

	report.add_issue(
		_issue(
			ValidationIssue.Severity
				.HARDWARE_SAFETY_ERROR,
			&"hardware_error"
		)
	)

	_expect(
		report.has_severity(
			ValidationIssue.Severity
				.HARDWARE_SAFETY_ERROR
		),
		"VR-U07: Hardware Safety Error is detected"
	)

	_expect(
		report.is_valid_for_simulation(),
		"VR-U07: Hardware Safety Error allows simulation"
	)

	_expect(
		not report.is_valid_for_hardware(),
		"VR-U07: Hardware Safety Error blocks hardware"
	)


# =============================================================================
# COPY AND DUPLICATE
# =============================================================================

func _test_independent_copy() -> void:

	var report := ValidationReport.new()

	report.add_issue(
		_issue(
			ValidationIssue.Severity.WARNING,
			&"warning"
		)
	)

	var issues_copy: Array[ValidationIssue] = (
		report.get_issues()
	)

	issues_copy.clear()

	_expect(
		report.get_issue_count() == 1,
		"VR-U08: issues copy is independent"
	)

	_expect(
		report.has_severity(
			ValidationIssue.Severity.WARNING
		),
		"VR-U08: original issue remains"
	)


func _test_duplicate_issue() -> void:

	var report := ValidationReport.new()

	var issue := _issue(
		ValidationIssue.Severity.WARNING,
		&"duplicate"
	)

	_expect(
		report.add_issue(issue),
		"VR-U09: first Issue is accepted"
	)

	_expect(
		not report.add_issue(issue),
		"VR-U09: duplicate instance is rejected"
	)

	_expect(
		report.get_issue_count() == 1,
		"VR-U09: duplicate does not change count"
	)


# =============================================================================
# HELPERS
# =============================================================================

func _issue(
	severity: ValidationIssue.Severity,
	code: StringName
) -> ValidationIssue:

	return ValidationIssue.new(
		code,
		severity,
		String(code)
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
