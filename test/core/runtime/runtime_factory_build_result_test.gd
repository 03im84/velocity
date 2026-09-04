extends Node


##
## RuntimeFactoryBuildResultTest
##
## Verifica resultado defensivo
## y validez según Activation Context.
##


class TestRuntimeObject:

	extends RefCounted


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeFactoryBuildResultTest")
	print("========================================")

	_test_valid_simulation_result()
	_test_required_components()
	_test_simulation_severities()
	_test_hardware_severities()
	_test_contract()

	_finish_test()


# =============================================================================
# VALID SIMULATION RESULT
# =============================================================================

func _test_valid_simulation_result() -> void:

	var handle := _valid_handle(
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var report := ValidationReport.new()

	var result := RuntimeFactoryBuildResult.new(
		handle,
		report
	)

	var result_value: Variant = result

	_expect(
		result.is_success(),
		"RFBR-U01: valid Simulation Handle and Report succeed"
	)

	_expect(
		result.get_handle() == handle,
		"RFBR-U01: Handle reference is preserved"
	)

	_expect(
		result.get_report() == report,
		"RFBR-U01: Report reference is preserved"
	)

	_expect(
		result_value is RefCounted
		and not (result_value is Node),
		"RFBR-U01: Result is RefCounted and not Node"
	)


# =============================================================================
# REQUIRED COMPONENTS
# =============================================================================

func _test_required_components() -> void:

	var valid_handle := _valid_handle(
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var valid_report := ValidationReport.new()

	var null_handle_result := RuntimeFactoryBuildResult.new(
		null,
		valid_report
	)

	var null_report_result := RuntimeFactoryBuildResult.new(
		valid_handle,
		null
	)

	var invalid_handle_result := RuntimeFactoryBuildResult.new(
		_invalid_handle(),
		valid_report
	)

	_expect(
		not null_handle_result.is_success(),
		"RFBR-U02: null Handle produces failure"
	)

	_expect(
		not null_report_result.is_success(),
		"RFBR-U02: null Report produces failure"
	)

	_expect(
		not invalid_handle_result.is_success(),
		"RFBR-U02: invalid Handle produces failure"
	)


# =============================================================================
# SIMULATION SEVERITIES
# =============================================================================

func _test_simulation_severities() -> void:

	var handle := _valid_handle(
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var info_result := RuntimeFactoryBuildResult.new(
		handle,
		_report_with_severity(
			ValidationIssue.Severity.INFO
		)
	)

	var warning_result := RuntimeFactoryBuildResult.new(
		handle,
		_report_with_severity(
			ValidationIssue.Severity.WARNING
		)
	)

	var simulation_hazard_result := RuntimeFactoryBuildResult.new(
		handle,
		_report_with_severity(
			ValidationIssue.Severity.SIMULATION_HAZARD
		)
	)

	var hardware_error_result := RuntimeFactoryBuildResult.new(
		handle,
		_report_with_severity(
			ValidationIssue.Severity.HARDWARE_SAFETY_ERROR
		)
	)

	var structural_error_result := RuntimeFactoryBuildResult.new(
		handle,
		_report_with_severity(
			ValidationIssue.Severity.STRUCTURAL_ERROR
		)
	)

	var platform_error_result := RuntimeFactoryBuildResult.new(
		handle,
		_report_with_severity(
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR
		)
	)

	_expect(
		info_result.is_success(),
		"RFBR-U03: INFO allows Simulation success"
	)

	_expect(
		warning_result.is_success(),
		"RFBR-U03: WARNING allows Simulation success"
	)

	_expect(
		simulation_hazard_result.is_success(),
		"RFBR-U03: Simulation Hazard allows Simulation success"
	)

	_expect(
		hardware_error_result.is_success(),
		"RFBR-U03: Hardware Safety Error allows Simulation result"
	)

	_expect(
		not structural_error_result.is_success(),
		"RFBR-U03: Structural Error blocks Simulation result"
	)

	_expect(
		not platform_error_result.is_success(),
		"RFBR-U03: Platform Safety Error blocks Simulation result"
	)


# =============================================================================
# HARDWARE SEVERITIES
# =============================================================================

func _test_hardware_severities() -> void:

	var handle := _valid_handle(
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	var empty_result := RuntimeFactoryBuildResult.new(
		handle,
		ValidationReport.new()
	)

	var warning_result := RuntimeFactoryBuildResult.new(
		handle,
		_report_with_severity(
			ValidationIssue.Severity.WARNING
		)
	)

	var simulation_hazard_result := RuntimeFactoryBuildResult.new(
		handle,
		_report_with_severity(
			ValidationIssue.Severity.SIMULATION_HAZARD
		)
	)

	var hardware_error_result := RuntimeFactoryBuildResult.new(
		handle,
		_report_with_severity(
			ValidationIssue.Severity.HARDWARE_SAFETY_ERROR
		)
	)

	var structural_error_result := RuntimeFactoryBuildResult.new(
		handle,
		_report_with_severity(
			ValidationIssue.Severity.STRUCTURAL_ERROR
		)
	)

	_expect(
		empty_result.is_success(),
		"RFBR-U04: empty Report allows Hardware result"
	)

	_expect(
		warning_result.is_success(),
		"RFBR-U04: WARNING allows Hardware result"
	)

	_expect(
		not simulation_hazard_result.is_success(),
		"RFBR-U04: Simulation Hazard blocks Hardware result"
	)

	_expect(
		not hardware_error_result.is_success(),
		"RFBR-U04: Hardware Safety Error blocks Hardware result"
	)

	_expect(
		not structural_error_result.is_success(),
		"RFBR-U04: Structural Error blocks Hardware result"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var result := RuntimeFactoryBuildResult.new(
		_valid_handle(
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		ValidationReport.new()
	)

	_expect(
		not result.has_method(
			&"set_handle"
		)
		and not result.has_method(
			&"set_report"
		),
		"RFBR-U05: Result exposes no setters"
	)

	_expect(
		not result.has_method(
			&"build"
		)
		and not result.has_method(
			&"release"
		),
		"RFBR-U05: Result has no factory behavior"
	)

	_expect(
		not result.has_method(
			&"execute"
		)
		and not result.has_method(
			&"attach"
		)
		and not result.has_method(
			&"activate"
		),
		"RFBR-U05: Result has no runtime or host behavior"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _valid_handle(
	activation_context: int
) -> RuntimeDeviceHandle:

	var configuration := _configuration(
		"runtime_sensor",
		&"test.runtime.sensor",
		2,
		activation_context
	)

	var factory_key := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		2,
		activation_context
	)

	return RuntimeDeviceHandle.new(
		"runtime_sensor",
		configuration,
		factory_key,
		TestRuntimeObject.new()
	)


func _invalid_handle() -> RuntimeDeviceHandle:

	return RuntimeDeviceHandle.new(
		"runtime_sensor",
		_configuration(
			"runtime_sensor",
			&"test.runtime.sensor",
			2,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		RuntimeFactoryKey.new(
			&"test.runtime.sensor",
			2,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		null
	)


func _configuration(
	device_id: String,
	profile_id: StringName,
	profile_version: int,
	activation_context: int
) -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"runtime_construction",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		&"test.runtime.build_result.configuration",
		1,
		device_id,
		profile_id,
		profile_version,
		activation_context,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _report_with_severity(
	severity: int
) -> ValidationReport:

	var report := ValidationReport.new()

	report.add_issue(
		ValidationIssue.new(
			&"test_runtime_factory_issue",
			severity,
			"RuntimeFactoryBuildResult test issue.",
			"runtime_sensor",
			&"factory"
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
