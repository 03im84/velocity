extends Node


##
## CompositionCompileResultTest
##
## Verifica Plan, Report,
## Context y contrato inmutable.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("CompositionCompileResultTest")
	print("========================================")

	_test_valid_simulation_result()
	_test_valid_hardware_result()
	_test_required_components()
	_test_invalid_plan()
	_test_simulation_report_policy()
	_test_hardware_report_policy()
	_test_contract()

	_finish_test()


# =============================================================================
# VALID SIMULATION RESULT
# =============================================================================

func _test_valid_simulation_result() -> void:

	var plan := _empty_plan(
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var report := ValidationReport.new()

	var result := CompositionCompileResult.new(
		plan,
		report
	)

	var result_value: Variant = result

	_expect(
		result.is_success(),
		"CCR-U01: valid Simulation Plan and Report produce success"
	)

	_expect(
		result.get_plan() == plan
		and result.get_report() == report,
		"CCR-U01: Result preserves Plan and Report references"
	)

	_expect(
		result_value is RefCounted
		and not (result_value is Node),
		"CCR-U01: Result is RefCounted and not Node"
	)


# =============================================================================
# VALID HARDWARE RESULT
# =============================================================================

func _test_valid_hardware_result() -> void:

	var result := CompositionCompileResult.new(
		_empty_plan(
			DeviceConfiguration.ActivationContext.HARDWARE
		),
		ValidationReport.new()
	)

	_expect(
		result.is_success(),
		"CCR-U02: Result defensively supports valid Hardware context"
	)


# =============================================================================
# REQUIRED COMPONENTS
# =============================================================================

func _test_required_components() -> void:

	var valid_plan := _empty_plan(
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var valid_report := ValidationReport.new()

	var missing_plan := CompositionCompileResult.new(
		null,
		valid_report
	)

	var missing_report := CompositionCompileResult.new(
		valid_plan,
		null
	)

	_expect(
		not missing_plan.is_success(),
		"CCR-U03: null Plan produces failed Result"
	)

	_expect(
		not missing_report.is_success(),
		"CCR-U03: null Report produces failed Result"
	)


# =============================================================================
# INVALID PLAN
# =============================================================================

func _test_invalid_plan() -> void:

	var entries: Array[CompositionDeviceEntry] = []
	var directives: Array[CompositionConnectionDirective] = []

	var invalid_context_plan := CompositionPlan.new(
		-1,
		entries,
		directives,
		DeviceBusDispatchPolicy.new()
	)

	var missing_policy_plan := CompositionPlan.new(
		DeviceConfiguration.ActivationContext.SIMULATION,
		entries,
		directives,
		null
	)

	var invalid_context_result := CompositionCompileResult.new(
		invalid_context_plan,
		ValidationReport.new()
	)

	var missing_policy_result := CompositionCompileResult.new(
		missing_policy_plan,
		ValidationReport.new()
	)

	_expect(
		not invalid_context_plan.is_valid()
		and not invalid_context_result.is_success(),
		"CCR-U04: invalid Context Plan is rejected"
	)

	_expect(
		not missing_policy_plan.is_valid()
		and not missing_policy_result.is_success(),
		"CCR-U04: invalid Policy Plan is rejected"
	)


# =============================================================================
# SIMULATION REPORT POLICY
# =============================================================================

func _test_simulation_report_policy() -> void:

	var simulation_plan := _empty_plan(
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var structural_result := CompositionCompileResult.new(
		simulation_plan,
		_report_with_issue(
			&"test_structural_error",
			ValidationIssue.Severity.STRUCTURAL_ERROR
		)
	)

	var platform_result := CompositionCompileResult.new(
		simulation_plan,
		_report_with_issue(
			&"test_platform_error",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR
		)
	)

	var simulation_hazard_result := CompositionCompileResult.new(
		simulation_plan,
		_report_with_issue(
			&"test_simulation_hazard",
			ValidationIssue.Severity.SIMULATION_HAZARD
		)
	)

	var hardware_error_result := CompositionCompileResult.new(
		simulation_plan,
		_report_with_issue(
			&"test_hardware_error",
			ValidationIssue.Severity.HARDWARE_SAFETY_ERROR
		)
	)

	_expect(
		not structural_result.is_success(),
		"CCR-U05: Structural Error blocks Simulation Result"
	)

	_expect(
		not platform_result.is_success(),
		"CCR-U05: Platform Safety Error blocks Simulation Result"
	)

	_expect(
		simulation_hazard_result.is_success(),
		"CCR-U05: Simulation Hazard remains valid for Simulation"
	)

	_expect(
		hardware_error_result.is_success(),
		"CCR-U05: Hardware Safety Error may be modeled in Simulation"
	)


# =============================================================================
# HARDWARE REPORT POLICY
# =============================================================================

func _test_hardware_report_policy() -> void:

	var hardware_plan := _empty_plan(
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	var simulation_hazard_result := CompositionCompileResult.new(
		hardware_plan,
		_report_with_issue(
			&"test_simulation_hazard",
			ValidationIssue.Severity.SIMULATION_HAZARD
		)
	)

	var hardware_error_result := CompositionCompileResult.new(
		hardware_plan,
		_report_with_issue(
			&"test_hardware_error",
			ValidationIssue.Severity.HARDWARE_SAFETY_ERROR
		)
	)

	var warning_result := CompositionCompileResult.new(
		hardware_plan,
		_report_with_issue(
			&"test_warning",
			ValidationIssue.Severity.WARNING
		)
	)

	_expect(
		not simulation_hazard_result.is_success(),
		"CCR-U06: Simulation Hazard blocks Hardware Result"
	)

	_expect(
		not hardware_error_result.is_success(),
		"CCR-U06: Hardware Safety Error blocks Hardware Result"
	)

	_expect(
		warning_result.is_success(),
		"CCR-U06: Warning does not block Hardware Result"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var result := CompositionCompileResult.new(
		_empty_plan(
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		ValidationReport.new()
	)

	_expect(
		not result.has_method(
			&"set_plan"
		)
		and not result.has_method(
			&"set_report"
		),
		"CCR-U07: Result exposes no setters"
	)

	_expect(
		not result.has_method(
			&"compile"
		)
		and not result.has_method(
			&"create_plan"
		),
		"CCR-U07: Result does not compile"
	)

	_expect(
		not result.has_method(
			&"execute"
		)
		and not result.has_method(
			&"activate"
		)
		and not result.has_method(
			&"rollback"
		),
		"CCR-U07: Result has no runtime behavior"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _empty_plan(
	activation_context: int
) -> CompositionPlan:

	var entries: Array[CompositionDeviceEntry] = []
	var directives: Array[CompositionConnectionDirective] = []

	return CompositionPlan.new(
		activation_context,
		entries,
		directives,
		DeviceBusDispatchPolicy.new()
	)


func _report_with_issue(
	code: StringName,
	severity: int
) -> ValidationReport:

	var report := ValidationReport.new()

	report.add_issue(
		ValidationIssue.new(
			code,
			severity,
			"Controlled CompositionCompileResult test Issue.",
			"test.composition_result",
			&"result"
		)
	)

	return report


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
