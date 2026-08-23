extends Node


##
## DeviceBusDispatchPolicyTest
##
## Verifica defaults, hard maximums,
## validación e inmutabilidad de Policy.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusDispatchPolicyTest")
	print("========================================")

	_test_defaults()
	_test_small_valid_policy()
	_test_zero_values()
	_test_negative_values()
	_test_hard_maximums()
	_test_values_over_hard_maximums()
	_test_public_api()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_defaults() -> void:

	var policy := DeviceBusDispatchPolicy.new()

	_expect(
		policy.get_max_publications_per_cycle()
		== 1024,
		"DBP-U01: default publications is 1024"
	)

	_expect(
		policy.get_max_callbacks_per_cycle()
		== 8192,
		"DBP-U01: default callbacks is 8192"
	)

	_expect(
		policy.get_max_pending_publications()
		== 512,
		"DBP-U01: default pending is 512"
	)

	_expect(
		policy.get_max_dispatch_time_usec()
		== 50000,
		"DBP-U01: default time is 50000 usec"
	)

	_expect(
		policy.is_valid(),
		"DBP-U01: default Policy is valid"
	)


func _test_small_valid_policy() -> void:

	var policy := DeviceBusDispatchPolicy.new(
		3,
		4,
		2,
		100000
	)

	_expect(
		policy.get_max_publications_per_cycle()
		== 3,
		"DBP-U02: custom publications is preserved"
	)

	_expect(
		policy.get_max_callbacks_per_cycle()
		== 4,
		"DBP-U02: custom callbacks is preserved"
	)

	_expect(
		policy.get_max_pending_publications()
		== 2,
		"DBP-U02: custom pending is preserved"
	)

	_expect(
		policy.get_max_dispatch_time_usec()
		== 100000,
		"DBP-U02: custom time is preserved"
	)

	_expect(
		policy.is_valid(),
		"DBP-U02: small Policy is valid"
	)


func _test_zero_values() -> void:

	_expect(
		not DeviceBusDispatchPolicy.new(
			0,
			4,
			2,
			100000
		).is_valid(),
		"DBP-U03: zero publications is invalid"
	)

	_expect(
		not DeviceBusDispatchPolicy.new(
			3,
			0,
			2,
			100000
		).is_valid(),
		"DBP-U03: zero callbacks is invalid"
	)

	_expect(
		not DeviceBusDispatchPolicy.new(
			3,
			4,
			0,
			100000
		).is_valid(),
		"DBP-U03: zero pending is invalid"
	)

	_expect(
		not DeviceBusDispatchPolicy.new(
			3,
			4,
			2,
			0
		).is_valid(),
		"DBP-U03: zero time is invalid"
	)


func _test_negative_values() -> void:

	_expect(
		not DeviceBusDispatchPolicy.new(
			-1,
			4,
			2,
			100000
		).is_valid(),
		"DBP-U04: negative publications is invalid"
	)

	_expect(
		not DeviceBusDispatchPolicy.new(
			3,
			-1,
			2,
			100000
		).is_valid(),
		"DBP-U04: negative callbacks is invalid"
	)

	_expect(
		not DeviceBusDispatchPolicy.new(
			3,
			4,
			-1,
			100000
		).is_valid(),
		"DBP-U04: negative pending is invalid"
	)

	_expect(
		not DeviceBusDispatchPolicy.new(
			3,
			4,
			2,
			-1
		).is_valid(),
		"DBP-U04: negative time is invalid"
	)


func _test_hard_maximums() -> void:

	var policy := DeviceBusDispatchPolicy.new(
		DeviceBusDispatchPolicy
			.HARD_MAX_PUBLICATIONS_PER_CYCLE,
		DeviceBusDispatchPolicy
			.HARD_MAX_CALLBACKS_PER_CYCLE,
		DeviceBusDispatchPolicy
			.HARD_MAX_PENDING_PUBLICATIONS,
		DeviceBusDispatchPolicy
			.HARD_MAX_DISPATCH_TIME_USEC
	)

	_expect(
		policy.is_valid(),
		"DBP-U05: exact hard maximums are valid"
	)


func _test_values_over_hard_maximums() -> void:

	_expect(
		not DeviceBusDispatchPolicy.new(
			DeviceBusDispatchPolicy
				.HARD_MAX_PUBLICATIONS_PER_CYCLE + 1,
			4,
			2,
			100000
		).is_valid(),
		"DBP-U05: publications over hard max is invalid"
	)

	_expect(
		not DeviceBusDispatchPolicy.new(
			3,
			DeviceBusDispatchPolicy
				.HARD_MAX_CALLBACKS_PER_CYCLE + 1,
			2,
			100000
		).is_valid(),
		"DBP-U05: callbacks over hard max is invalid"
	)

	_expect(
		not DeviceBusDispatchPolicy.new(
			3,
			4,
			DeviceBusDispatchPolicy
				.HARD_MAX_PENDING_PUBLICATIONS + 1,
			100000
		).is_valid(),
		"DBP-U05: pending over hard max is invalid"
	)

	_expect(
		not DeviceBusDispatchPolicy.new(
			3,
			4,
			2,
			DeviceBusDispatchPolicy
				.HARD_MAX_DISPATCH_TIME_USEC + 1
		).is_valid(),
		"DBP-U05: time over hard max is invalid"
	)


func _test_public_api() -> void:

	var policy := DeviceBusDispatchPolicy.new()

	_expect(
		policy.has_method(
			&"is_valid"
		),
		"DBP-U06: is_valid exists"
	)

	_expect(
		policy.has_method(
			&"get_max_publications_per_cycle"
		),
		"DBP-U06: publications getter exists"
	)

	_expect(
		policy.has_method(
			&"get_max_callbacks_per_cycle"
		),
		"DBP-U06: callbacks getter exists"
	)

	_expect(
		policy.has_method(
			&"get_max_pending_publications"
		),
		"DBP-U06: pending getter exists"
	)

	_expect(
		policy.has_method(
			&"get_max_dispatch_time_usec"
		),
		"DBP-U06: time getter exists"
	)

	_expect(
		not policy.has_method(
			&"set_max_publications_per_cycle"
		),
		"DBP-U06: publications setter does not exist"
	)

	_expect(
		not policy.has_method(
			&"set_max_callbacks_per_cycle"
		),
		"DBP-U06: callbacks setter does not exist"
	)

	_expect(
		not policy.has_method(
			&"set_max_pending_publications"
		),
		"DBP-U06: pending setter does not exist"
	)

	_expect(
		not policy.has_method(
			&"set_max_dispatch_time_usec"
		),
		"DBP-U06: time setter does not exist"
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
