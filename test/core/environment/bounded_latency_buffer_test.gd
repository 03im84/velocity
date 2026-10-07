extends Node


## BoundedLatencyBufferTest
##
## Verifica delay, FIFO, capacity, monotonicidad, overflow policy,
## clear y ausencia de scheduling o memoria no acotada.


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("BoundedLatencyBufferTest")
	print("========================================")

	_test_validation()
	_test_zero_delay()
	_test_delayed_release()
	_test_fifo_order()
	_test_capacity_and_monotonicity()
	_test_clear_and_contract()

	_finish()


func _test_validation() -> void:

	var buffer := BoundedLatencyBuffer.new(0.05, 8)

	_expect(
		buffer.is_valid(),
		"BLB-U01: finite delay and positive capacity are valid"
	)
	_expect(
		buffer.get_delay_seconds() == 0.05
		and buffer.get_max_entries() == 8,
		"BLB-U01: configured policy is preserved"
	)
	_expect(
		BoundedLatencyBuffer.new(0.0, 1).is_valid(),
		"BLB-U01: zero-delay single-entry buffer is valid"
	)
	_expect(
		not BoundedLatencyBuffer.new(-0.001, 1).is_valid()
		and not BoundedLatencyBuffer.new(NAN, 1).is_valid()
		and not BoundedLatencyBuffer.new(INF, 1).is_valid(),
		"BLB-U02: invalid delay is rejected"
	)
	_expect(
		not BoundedLatencyBuffer.new(0.0, 0).is_valid()
		and not BoundedLatencyBuffer.new(0.0, -1).is_valid(),
		"BLB-U02: non-positive capacity is rejected"
	)
	_expect(
		not buffer.enqueue(null, 0.0),
		"BLB-U02: null signal value is rejected"
	)
	_expect(
		not buffer.enqueue("signal", -0.1)
		and not buffer.enqueue("signal", NAN)
		and not buffer.enqueue("signal", INF),
		"BLB-U02: invalid capture timestamp is rejected"
	)


func _test_zero_delay() -> void:

	var buffer := BoundedLatencyBuffer.new(0.0, 2)

	_expect(
		buffer.enqueue("immediate", 1.0),
		"BLB-U03: zero-delay signal is accepted"
	)
	_expect(
		buffer.has_ready(1.0),
		"BLB-U03: zero-delay signal is ready at capture time"
	)
	_expect(
		buffer.dequeue_ready(1.0) == "immediate"
		and buffer.is_empty(),
		"BLB-U03: zero-delay signal dequeues exactly once"
	)


func _test_delayed_release() -> void:

	var buffer := BoundedLatencyBuffer.new(0.1, 2)

	buffer.enqueue("delayed", 1.0)

	_expect(
		not buffer.has_ready(1.099),
		"BLB-U04: signal is unavailable before release time"
	)
	_expect(
		buffer.dequeue_ready(1.099) == null
		and buffer.get_pending_count() == 1,
		"BLB-U04: early dequeue preserves pending signal"
	)
	_expect(
		buffer.has_ready(1.1)
		and buffer.dequeue_ready(1.1) == "delayed",
		"BLB-U04: signal matures at conceptual release boundary"
	)


func _test_fifo_order() -> void:

	var buffer := BoundedLatencyBuffer.new(0.1, 4)

	buffer.enqueue("first", 1.0)
	buffer.enqueue("second", 1.05)
	buffer.enqueue("third", 1.1)

	_expect(
		buffer.get_pending_count() == 3,
		"BLB-U05: all accepted entries remain pending"
	)
	_expect(
		buffer.dequeue_ready(2.0) == "first"
		and buffer.dequeue_ready(2.0) == "second"
		and buffer.dequeue_ready(2.0) == "third",
		"BLB-U05: matured entries dequeue in FIFO order"
	)
	_expect(
		buffer.dequeue_ready(2.0) == null
		and buffer.is_empty(),
		"BLB-U05: empty FIFO returns null"
	)


func _test_capacity_and_monotonicity() -> void:

	var buffer := BoundedLatencyBuffer.new(1.0, 2)

	_expect(
		buffer.enqueue("first", 1.0)
		and buffer.enqueue("second", 1.0),
		"BLB-U06: equal monotonic timestamps are accepted"
	)
	_expect(
		not buffer.enqueue("overflow", 1.1)
		and buffer.get_pending_count() == 2,
		"BLB-U06: full buffer rejects newest without growth"
	)
	_expect(
		buffer.dequeue_ready(2.0) == "first"
		and buffer.dequeue_ready(2.0) == "second",
		"BLB-U06: overflow rejection preserves accepted entries"
	)

	var monotonic_buffer := BoundedLatencyBuffer.new(0.0, 3)
	monotonic_buffer.enqueue("newer", 2.0)

	_expect(
		not monotonic_buffer.enqueue("older", 1.9)
		and monotonic_buffer.get_pending_count() == 1,
		"BLB-U06: regressive capture timestamp is rejected"
	)


func _test_clear_and_contract() -> void:

	var buffer := BoundedLatencyBuffer.new(1.0, 2)
	buffer.enqueue("old", 10.0)
	buffer.clear()

	_expect(
		buffer.is_empty()
		and buffer.get_pending_count() == 0,
		"BLB-U07: clear removes all pending entries"
	)
	_expect(
		buffer.enqueue("new_epoch", 1.0),
		"BLB-U07: clear resets monotonic timestamp baseline"
	)
	_expect(
		not buffer.has_method(&"start_timer")
		and not buffer.has_method(&"process")
		and not buffer.has_method(&"create_thread")
		and not buffer.has_method(&"get_tree"),
		"BLB-U07: buffer has no timer, thread or SceneTree responsibility"
	)
	_expect(
		buffer.get_pending_count() <= buffer.get_max_entries(),
		"BLB-U07: observable queue size never exceeds capacity"
	)


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
