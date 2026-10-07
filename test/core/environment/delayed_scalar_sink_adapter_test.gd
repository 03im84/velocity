extends Node


## DelayedScalarSinkAdapterTest
##
## Verifica zero/delayed delivery, FIFO, conceptual timestamps,
## bounded overflow, target rejection, clear y responsibility boundary.


class RecordingScalarTarget:
	extends RefCounted

	var results: Array[Variant] = []
	var call_count: int = 0
	var values: Array[float] = []
	var timestamps: Array[float] = []

	func apply_scalar(
		value: float,
		timestamp: float
	) -> Variant:
		call_count += 1
		values.append(value)
		timestamps.append(timestamp)

		if results.is_empty():
			return true

		return results.pop_front()


class WrongArityTarget:
	extends RefCounted

	func apply_scalar(
		_value: float
	) -> bool:
		return true


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DelayedScalarSinkAdapterTest")
	print("========================================")

	_test_configuration_validation()
	_test_submit_validation()
	_test_zero_delay_delivery()
	_test_delayed_delivery_and_fifo()
	_test_capacity_and_overflow()
	_test_timestamp_monotonicity()
	_test_target_rejection()
	_test_clear()
	_test_responsibility_boundary()

	_finish()


func _test_configuration_validation() -> void:

	var target := RecordingScalarTarget.new()
	var adapter := _adapter(target, 0.25, 4)
	var wrong_arity := WrongArityTarget.new()

	_expect(
		adapter.is_configuration_valid(),
		"DSS-U01: valid callable and bounded buffer are accepted"
	)
	_expect(
		adapter.get_delay_seconds() == 0.25
		and adapter.get_pending_count() == 0
		and adapter.get_max_pending_entries() == 4,
		"DSS-U01: configured delay and capacity are observable"
	)
	_expect(
		adapter.get_last_flush_count() == 0
		and adapter.get_total_applied_count() == 0,
		"DSS-U01: counters begin at zero"
	)
	_expect(
		not DelayedScalarSinkAdapter.new(
			Callable(),
			BoundedLatencyBuffer.new(0.0, 1)
		).is_configuration_valid(),
		"DSS-U02: invalid callable is rejected"
	)
	_expect(
		not DelayedScalarSinkAdapter.new(
			Callable(wrong_arity, &"apply_scalar"),
			BoundedLatencyBuffer.new(0.0, 1)
		).is_configuration_valid(),
		"DSS-U02: target callable must accept two arguments"
	)
	_expect(
		not DelayedScalarSinkAdapter.new(
			Callable(target, &"apply_scalar"),
			null
		).is_configuration_valid(),
		"DSS-U02: latency buffer is required"
	)
	_expect(
		not DelayedScalarSinkAdapter.new(
			Callable(target, &"apply_scalar"),
			BoundedLatencyBuffer.new(-1.0, 1)
		).is_configuration_valid(),
		"DSS-U02: invalid latency configuration is rejected"
	)


func _test_submit_validation() -> void:

	var target := RecordingScalarTarget.new()
	var adapter := _adapter(target, 1.0, 4)

	_expect(
		adapter.submit_scalar(10.0, 1.0)
		and adapter.submit_scalar(-5.0, 2.0)
		and adapter.submit_scalar(0.0, 3.0),
		"DSS-U03: positive, negative and zero scalars are accepted"
	)
	_expect(
		not adapter.submit_scalar(NAN, 4.0)
		and not adapter.submit_scalar(INF, 4.0),
		"DSS-U03: non-finite scalar is rejected"
	)
	_expect(
		not adapter.submit_scalar(1.0, -0.001)
		and not adapter.submit_scalar(1.0, NAN)
		and not adapter.submit_scalar(1.0, INF),
		"DSS-U03: invalid capture timestamp is rejected"
	)

	var overflow_timestamp_adapter := _adapter(
		target,
		1.0e308,
		1
	)

	_expect(
		not overflow_timestamp_adapter.submit_scalar(
			1.0,
			1.0e308
		),
		"DSS-U03: non-finite application timestamp is rejected"
	)
	_expect(
		adapter.get_pending_count() == 3,
		"DSS-U03: rejected inputs do not consume capacity"
	)


func _test_zero_delay_delivery() -> void:

	var target := RecordingScalarTarget.new()
	var adapter := _adapter(target, 0.0, 2)

	_expect(
		adapter.submit_scalar(12.5, 3.0)
		and target.call_count == 0,
		"DSS-U04: submit never bypasses explicit flush"
	)
	_expect(
		adapter.flush(3.0),
		"DSS-U04: zero-delay command flushes at capture time"
	)
	_expect(
		target.call_count == 1
		and target.values == [12.5]
		and target.timestamps == [3.0],
		"DSS-U04: target receives value and conceptual timestamp"
	)
	_expect(
		adapter.get_pending_count() == 0
		and adapter.get_last_flush_count() == 1
		and adapter.get_total_applied_count() == 1,
		"DSS-U04: successful flush updates bounded observability"
	)


func _test_delayed_delivery_and_fifo() -> void:

	var target := RecordingScalarTarget.new()
	var adapter := _adapter(target, 0.5, 4)
	adapter.submit_scalar(1.0, 1.0)
	adapter.submit_scalar(2.0, 1.25)
	adapter.submit_scalar(3.0, 1.5)

	_expect(
		adapter.flush(1.49)
		and target.call_count == 0
		and adapter.get_pending_count() == 3,
		"DSS-U05: commands remain pending before release"
	)
	_expect(
		adapter.flush(1.5)
		and target.values == [1.0]
		and target.timestamps == [1.5],
		"DSS-U05: first command matures at conceptual boundary"
	)
	_expect(
		adapter.flush(2.0)
		and target.values == [1.0, 2.0, 3.0],
		"DSS-U05: multiple matured commands preserve FIFO order"
	)
	_expect(
		target.timestamps == [1.5, 1.75, 2.0]
		and adapter.get_last_flush_count() == 2
		and adapter.get_total_applied_count() == 3,
		"DSS-U05: target timestamps remain cadence-independent"
	)


func _test_capacity_and_overflow() -> void:

	var target := RecordingScalarTarget.new()
	var adapter := _adapter(target, 10.0, 2)

	_expect(
		adapter.submit_scalar(1.0, 1.0)
		and adapter.submit_scalar(2.0, 2.0),
		"DSS-U06: queue accepts commands up to capacity"
	)
	_expect(
		not adapter.submit_scalar(3.0, 3.0)
		and adapter.get_pending_count() == 2,
		"DSS-U06: full queue rejects newest without growth"
	)
	_expect(
		adapter.flush(10.99)
		and adapter.get_pending_count() == 2,
		"DSS-U06: early flush cannot free future entries"
	)
	_expect(
		adapter.flush(12.0)
		and adapter.get_pending_count() == 0
		and target.values == [1.0, 2.0],
		"DSS-U06: matured entries free full capacity"
	)
	_expect(
		adapter.submit_scalar(4.0, 12.0)
		and adapter.get_pending_count() == 1,
		"DSS-U06: capacity is reusable after flush"
	)


func _test_timestamp_monotonicity() -> void:

	var target := RecordingScalarTarget.new()
	var adapter := _adapter(target, 0.0, 3)

	_expect(
		adapter.submit_scalar(1.0, 2.0)
		and not adapter.submit_scalar(2.0, 1.9),
		"DSS-U07: regressive capture timestamp is rejected"
	)
	_expect(
		adapter.submit_scalar(3.0, 2.0),
		"DSS-U07: equal capture timestamps are accepted"
	)
	_expect(
		adapter.flush(2.0)
		and adapter.get_last_flush_count() == 2,
		"DSS-U07: first monotonic flush applies ready commands"
	)
	_expect(
		not adapter.flush(1.9)
		and adapter.get_last_flush_count() == 0,
		"DSS-U07: regressive flush timestamp is rejected"
	)
	_expect(
		adapter.flush(2.0),
		"DSS-U07: equal flush timestamps are accepted"
	)


func _test_target_rejection() -> void:

	var rejecting_target := RecordingScalarTarget.new()
	rejecting_target.results.append(false)
	rejecting_target.results.append(true)
	var rejecting_adapter := _adapter(
		rejecting_target,
		0.0,
		2
	)
	rejecting_adapter.submit_scalar(1.0, 0.0)
	rejecting_adapter.submit_scalar(2.0, 0.0)

	_expect(
		not rejecting_adapter.flush(0.0),
		"DSS-U08: target rejection fails current flush"
	)
	_expect(
		rejecting_target.values == [1.0]
		and rejecting_adapter.get_pending_count() == 1
		and rejecting_adapter.get_total_applied_count() == 0,
		"DSS-U08: rejected command drops while later command remains"
	)
	_expect(
		rejecting_adapter.flush(0.0)
		and rejecting_target.values == [1.0, 2.0]
		and rejecting_adapter.get_total_applied_count() == 1,
		"DSS-U08: later command can flush after rejection"
	)

	var invalid_target := RecordingScalarTarget.new()
	invalid_target.results.append("not_boolean")
	var invalid_adapter := _adapter(invalid_target, 0.0, 1)
	invalid_adapter.submit_scalar(3.0, 0.0)

	_expect(
		not invalid_adapter.flush(0.0)
		and invalid_adapter.get_total_applied_count() == 0,
		"DSS-U08: non-boolean target result is rejected"
	)


func _test_clear() -> void:

	var target := RecordingScalarTarget.new()
	var adapter := _adapter(target, 1.0, 2)
	adapter.submit_scalar(1.0, 10.0)
	adapter.clear()

	_expect(
		adapter.get_pending_count() == 0
		and adapter.get_last_flush_count() == 0
		and adapter.get_total_applied_count() == 0,
		"DSS-U09: clear resets queue and counters"
	)
	_expect(
		adapter.submit_scalar(2.0, 1.0),
		"DSS-U09: clear resets capture timestamp epoch"
	)
	_expect(
		adapter.flush(2.0)
		and target.values == [2.0],
		"DSS-U09: clear resets flush timestamp epoch"
	)


func _test_responsibility_boundary() -> void:

	var target := RecordingScalarTarget.new()
	var adapter := _adapter(target, 0.0, 1)

	_expect(
		not adapter.has_method(&"apply_propulsion_force")
		and not adapter.has_method(&"apply_hover_force")
		and not adapter.has_method(&"apply_steering_torque")
		and not adapter.has_method(&"apply_brake_force"),
		"DSS-U10: generic adapter owns no actuator-specific API"
	)
	_expect(
		not adapter.has_method(&"apply_force")
		and not adapter.has_method(&"get_rigid_body")
		and not adapter.has_method(&"physics_process")
		and not adapter.has_method(&"get_tree"),
		"DSS-U10: adapter owns no physics or SceneTree API"
	)
	_expect(
		adapter.get_pending_count()
		<= adapter.get_max_pending_entries(),
		"DSS-U10: observable queue never exceeds capacity"
	)


func _adapter(
	target: RecordingScalarTarget,
	delay_seconds: float,
	max_entries: int
) -> DelayedScalarSinkAdapter:

	return DelayedScalarSinkAdapter.new(
		Callable(target, &"apply_scalar"),
		BoundedLatencyBuffer.new(delay_seconds, max_entries)
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
