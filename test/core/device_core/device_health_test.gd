extends Node


##
## DeviceHealthTest
##
## Verifica status, faults, warnings
## y política explícita de Health.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceHealthTest")
	print("========================================")

	_test_initial_state()
	_test_status()
	_test_faults()
	_test_warnings()
	_test_independent_copies()
	_test_explicit_policy()
	_test_public_api()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_initial_state() -> void:

	var health := DeviceHealth.new()

	_expect(
		health.get_status()
		== DeviceHealth.Status.HEALTHY,
		"DH-U01: initial status is HEALTHY"
	)

	_expect(
		not health.has_faults(),
		"DH-U01: initial faults are empty"
	)

	_expect(
		not health.has_warnings(),
		"DH-U01: initial warnings are empty"
	)

	_expect(
		health.is_operational(),
		"DH-U01: HEALTHY is operational"
	)


func _test_status() -> void:

	var health := DeviceHealth.new()

	health.set_status(
		DeviceHealth.Status.DEGRADED
	)

	_expect(
		health.get_status()
		== DeviceHealth.Status.DEGRADED,
		"DH-U02: status changes to DEGRADED"
	)

	_expect(
		health.is_operational(),
		"DH-U02: DEGRADED is operational"
	)

	health.set_status(
		DeviceHealth.Status.CRITICAL
	)

	_expect(
		health.get_status()
		== DeviceHealth.Status.CRITICAL,
		"DH-U02: status changes to CRITICAL"
	)

	_expect(
		health.is_operational(),
		"DH-U02: CRITICAL is operational"
	)

	health.set_status(
		DeviceHealth.Status.FAILED
	)

	_expect(
		health.get_status()
		== DeviceHealth.Status.FAILED,
		"DH-U02: status changes to FAILED"
	)

	_expect(
		not health.is_operational(),
		"DH-U02: FAILED is not operational"
	)


func _test_faults() -> void:

	var health := DeviceHealth.new()

	health.add_fault(
		"secondary_sensor_offline"
	)

	_expect(
		health.has_faults(),
		"DH-U03: add_fault registers fault"
	)

	_expect(
		health.get_faults() == [
			"secondary_sensor_offline",
		],
		"DH-U03: fault value is preserved"
	)

	health.add_fault(
		"secondary_sensor_offline"
	)

	_expect(
		health.get_faults().size() == 1,
		"DH-U03: duplicate fault is rejected"
	)

	health.remove_fault(
		"secondary_sensor_offline"
	)

	_expect(
		not health.has_faults(),
		"DH-U03: remove_fault removes fault"
	)

	health.remove_fault(
		"unknown_fault"
	)

	_expect(
		not health.has_faults(),
		"DH-U03: removing unknown fault is safe"
	)


func _test_warnings() -> void:

	var health := DeviceHealth.new()

	health.add_warning(
		"temperature_near_limit"
	)

	_expect(
		health.has_warnings(),
		"DH-U04: add_warning registers warning"
	)

	_expect(
		health.get_warnings() == [
			"temperature_near_limit",
		],
		"DH-U04: warning value is preserved"
	)

	health.add_warning(
		"temperature_near_limit"
	)

	_expect(
		health.get_warnings().size() == 1,
		"DH-U04: duplicate warning is rejected"
	)

	health.remove_warning(
		"temperature_near_limit"
	)

	_expect(
		not health.has_warnings(),
		"DH-U04: remove_warning removes warning"
	)

	health.remove_warning(
		"unknown_warning"
	)

	_expect(
		not health.has_warnings(),
		"DH-U04: removing unknown warning is safe"
	)


func _test_independent_copies() -> void:

	var health := DeviceHealth.new()

	health.add_fault(
		"fault_a"
	)

	health.add_warning(
		"warning_a"
	)

	var faults_copy: Array[String] = (
		health.get_faults()
	)

	var warnings_copy: Array[String] = (
		health.get_warnings()
	)

	faults_copy.clear()
	warnings_copy.clear()

	_expect(
		health.has_faults(),
		"DH-U05: faults copy is independent"
	)

	_expect(
		health.has_warnings(),
		"DH-U05: warnings copy is independent"
	)


func _test_explicit_policy() -> void:

	var health := DeviceHealth.new()

	health.add_fault(
		"fault_a"
	)

	health.add_warning(
		"warning_a"
	)

	_expect(
		health.get_status()
		== DeviceHealth.Status.HEALTHY,
		"DH-U06: diagnostics do not change status"
	)

	health.remove_fault(
		"fault_a"
	)

	health.remove_warning(
		"warning_a"
	)

	_expect(
		health.get_status()
		== DeviceHealth.Status.HEALTHY,
		"DH-U06: removing diagnostics does not change status"
	)


func _test_public_api() -> void:

	var health := DeviceHealth.new()

	_expect(
		health.has_method(
			&"add_warning"
		),
		"DH-U07: add_warning exists"
	)

	_expect(
		not health.has_method(
			&"add_waring"
		),
		"DH-U07: add_waring is retired"
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
