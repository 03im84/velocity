extends Node


##
## ManualDistanceProviderTest
##
## Verifica estado, lectura e invalidación
## de ManualDistanceProvider.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("ManualDistanceProviderTest")
	print("========================================")

	var provider := ManualDistanceProvider.new()

	# ---------------------------------------------------------
	# INITIAL STATE
	# ---------------------------------------------------------

	_expect(
		provider.get_distance() == 0.0,
		"MDP-U01: initial distance is zero"
	)

	_expect(
		not provider.is_valid(),
		"MDP-U01: initial reading is invalid"
	)

	# ---------------------------------------------------------
	# SET DISTANCE
	# ---------------------------------------------------------

	provider.set_distance(
		12.5
	)

	_expect(
		provider.get_distance() == 12.5,
		"MDP-U02: distance is stored"
	)

	_expect(
		provider.is_valid(),
		"MDP-U02: set_distance marks reading valid"
	)

	# ---------------------------------------------------------
	# INVALIDATE
	# ---------------------------------------------------------

	provider.invalidate()

	_expect(
		not provider.is_valid(),
		"MDP-U03: invalidate marks reading invalid"
	)

	_expect(
		provider.get_distance() == 12.5,
		"MDP-U03: invalidate preserves last distance"
	)

	_finish_test()


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
