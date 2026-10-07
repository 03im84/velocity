extends Node


## HoverSampleIntervalPrecisionTest
##
## Prueba sucesora para deltas conceptualmente iguales al máximo
## que exceden por error normal de resta floating-point.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("HoverSampleIntervalPrecisionTest")
	print("========================================")

	var model := HoverSpringDamperModel.new(
		2.0, 9810.0, 20000.0, 8000.0, 30000.0, 0.1
	)
	var subtraction_delta := 1.1 - 1.0
	var second_subtraction_delta := 1.2 - 1.1

	_expect(
		model.is_valid(),
		"HSI-R01: canonical model is valid"
	)
	_expect(
		subtraction_delta > 0.1,
		"HSI-R01: fixture reproduces floating-point overshoot"
	)
	_expect(
		model.is_sample_interval_valid(subtraction_delta),
		"HSI-R01: conceptual maximum from subtraction is accepted"
	)
	_expect(
		model.is_sample_interval_valid(
			second_subtraction_delta
		),
		"HSI-R01: repeated timestamp subtraction remains accepted"
	)
	_expect(
		not model.is_sample_interval_valid(0.1001),
		"HSI-R01: materially excessive interval remains rejected"
	)
	_expect(
		not model.is_sample_interval_valid(0.0)
		and not model.is_sample_interval_valid(-0.1),
		"HSI-R01: non-positive intervals remain rejected"
	)

	_finish()


func _expect(
	condition: bool,
	description: String
) -> void:

	_checks += 1

	if condition:
		print("[PASS] ", description)
		return

	_failures += 1
	push_error("[FAIL] " + description)


func _finish() -> void:

	print("----------------------------------------")
	print("Checks: ", _checks)
	print("Failures: ", _failures)

	if _failures == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")

	print("========================================")
	print("")
	get_tree().quit(_failures)
