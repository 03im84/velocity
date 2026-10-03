extends Node

class ControlledUnit:
	extends RefCounted
	var calls := 0
	var last_timestamp := -1.0
	func sample_and_publish(timestamp: float) -> void:
		calls += 1
		last_timestamp = timestamp

var checks := 0
var failures := 0

func _ready() -> void:
	var sampler := InputSamplingNode.new()
	add_child(sampler)
	var unit := ControlledUnit.new()
	_expect(not sampler.set_sampling_enabled(true), "ISN-U01: cannot enable before configure")
	_expect(not sampler.configure(null), "ISN-U01: null Unit rejected")
	_expect(not sampler.configure(RefCounted.new()), "ISN-U01: behavior required")
	_expect(sampler.configure(unit), "ISN-U02: valid Unit configured")
	_expect(not sampler.configure(unit), "ISN-U02: second configure rejected")
	sampler._physics_process(0.016)
	_expect(unit.calls == 0, "ISN-U03: disabled sampler does not call Unit")
	_expect(sampler.set_sampling_enabled(true), "ISN-U03: sampling enabled")
	sampler._physics_process(0.016)
	_expect(unit.calls == 1 and unit.last_timestamp >= 0.0, "ISN-U03: physics tick delegates with timestamp")
	_expect(sampler.set_sampling_enabled(false), "ISN-U04: sampling disabled")
	sampler._physics_process(0.016)
	_expect(unit.calls == 1, "ISN-U04: disabled sampler stops delegation")
	print("Checks: ", checks)
	print("Failures: ", failures)
	print("RESULT: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)

func _expect(value: bool, text: String) -> void:
	checks += 1
	if value: print("[PASS] ", text)
	else:
		failures += 1
		push_error("[FAIL] " + text)
