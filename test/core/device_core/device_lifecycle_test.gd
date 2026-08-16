extends Node


##
## DeviceLifecycleTest
##
## Verifica tipo, estados y transiciones
## de DeviceLifecycle.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceLifecycleTest")
	print("========================================")

	_test_runtime_type()
	_test_initial_state()
	_test_valid_sequence()
	_test_invalid_transitions()
	_test_shutdown_from_created()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_runtime_type() -> void:

	var lifecycle := DeviceLifecycle.new()

	var lifecycle_as_variant: Variant = (
		lifecycle
	)

	_expect(
		lifecycle_as_variant is RefCounted,
		"DL-U01: DeviceLifecycle is RefCounted"
	)

	_expect(
		not (lifecycle_as_variant is Node),
		"DL-U01: DeviceLifecycle is not Node"
	)


func _test_initial_state() -> void:

	var lifecycle := DeviceLifecycle.new()

	_expect(
		lifecycle.get_state()
		== DeviceLifecycle.State.CREATED,
		"DL-U02: initial state is CREATED"
	)


func _test_valid_sequence() -> void:

	var lifecycle := DeviceLifecycle.new()

	_expect(
		lifecycle.initialize(),
		"DL-U03: initialize succeeds"
	)

	_expect(
		lifecycle.get_state()
		== DeviceLifecycle.State.INITIALIZED,
		"DL-U03: state is INITIALIZED"
	)

	_expect(
		lifecycle.set_ready(),
		"DL-U03: set_ready succeeds"
	)

	_expect(
		lifecycle.get_state()
		== DeviceLifecycle.State.READY,
		"DL-U03: state is READY"
	)

	_expect(
		lifecycle.start(),
		"DL-U03: start succeeds"
	)

	_expect(
		lifecycle.get_state()
		== DeviceLifecycle.State.RUNNING,
		"DL-U03: state is RUNNING"
	)

	_expect(
		lifecycle.shutdown(),
		"DL-U03: shutdown succeeds"
	)

	_expect(
		lifecycle.get_state()
		== DeviceLifecycle.State.SHUTDOWN,
		"DL-U03: state is SHUTDOWN"
	)


func _test_invalid_transitions() -> void:

	# ---------------------------------------------------------
	# SET READY FROM CREATED
	# ---------------------------------------------------------

	var ready_from_created := (
		DeviceLifecycle.new()
	)

	_expect(
		not ready_from_created.set_ready(),
		"DL-U04: set_ready from CREATED fails"
	)

	_expect(
		ready_from_created.get_state()
		== DeviceLifecycle.State.CREATED,
		"DL-U04: failed set_ready preserves CREATED"
	)

	# ---------------------------------------------------------
	# START FROM CREATED
	# ---------------------------------------------------------

	var start_from_created := (
		DeviceLifecycle.new()
	)

	_expect(
		not start_from_created.start(),
		"DL-U04: start from CREATED fails"
	)

	_expect(
		start_from_created.get_state()
		== DeviceLifecycle.State.CREATED,
		"DL-U04: failed start preserves CREATED"
	)

	# ---------------------------------------------------------
	# START FROM INITIALIZED
	# ---------------------------------------------------------

	var start_from_initialized := (
		DeviceLifecycle.new()
	)

	start_from_initialized.initialize()

	_expect(
		not start_from_initialized.start(),
		"DL-U04: start from INITIALIZED fails"
	)

	_expect(
		start_from_initialized.get_state()
		== DeviceLifecycle.State.INITIALIZED,
		"DL-U04: failed start preserves INITIALIZED"
	)

	# ---------------------------------------------------------
	# SECOND INITIALIZE
	# ---------------------------------------------------------

	var second_initialize := (
		DeviceLifecycle.new()
	)

	second_initialize.initialize()

	_expect(
		not second_initialize.initialize(),
		"DL-U04: second initialize fails"
	)

	_expect(
		second_initialize.get_state()
		== DeviceLifecycle.State.INITIALIZED,
		"DL-U04: second initialize preserves state"
	)

	# ---------------------------------------------------------
	# SECOND SET READY
	# ---------------------------------------------------------

	var second_ready := DeviceLifecycle.new()

	second_ready.initialize()
	second_ready.set_ready()

	_expect(
		not second_ready.set_ready(),
		"DL-U04: second set_ready fails"
	)

	_expect(
		second_ready.get_state()
		== DeviceLifecycle.State.READY,
		"DL-U04: second set_ready preserves READY"
	)

	# ---------------------------------------------------------
	# SECOND START
	# ---------------------------------------------------------

	var second_start := DeviceLifecycle.new()

	second_start.initialize()
	second_start.set_ready()
	second_start.start()

	_expect(
		not second_start.start(),
		"DL-U04: second start fails"
	)

	_expect(
		second_start.get_state()
		== DeviceLifecycle.State.RUNNING,
		"DL-U04: second start preserves RUNNING"
	)


func _test_shutdown_from_created() -> void:

	var lifecycle := DeviceLifecycle.new()

	_expect(
		lifecycle.shutdown(),
		"DL-U05: shutdown from CREATED succeeds"
	)

	_expect(
		lifecycle.get_state()
		== DeviceLifecycle.State.SHUTDOWN,
		"DL-U05: state becomes SHUTDOWN"
	)

	_expect(
		not lifecycle.shutdown(),
		"DL-U05: second shutdown fails"
	)

	_expect(
		lifecycle.get_state()
		== DeviceLifecycle.State.SHUTDOWN,
		"DL-U05: second shutdown preserves state"
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
