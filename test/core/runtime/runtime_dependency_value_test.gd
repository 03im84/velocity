extends Node


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeDependencyValueTest")
	print("========================================")

	_test_valid_value()
	_test_invalid_identity_and_value()
	_test_disposed_value()
	_test_contract()

	_finish_test()


func _test_valid_value() -> void:

	var value := RefCounted.new()
	var entry := RuntimeDependencyValue.new(
		"device_a",
		&"runtime_clock",
		value
	)

	_expect(
		entry.is_valid(),
		"RDV-U01: complete Value is valid"
	)
	_expect(
		entry.get_device_id() == "device_a",
		"RDV-U01: Device ID is preserved"
	)
	_expect(
		entry.get_dependency_id() == &"runtime_clock",
		"RDV-U01: Dependency ID is preserved"
	)
	_expect(
		entry.get_value() == value,
		"RDV-U01: Object reference is preserved"
	)


func _test_invalid_identity_and_value() -> void:

	var value := RefCounted.new()

	_expect(
		not RuntimeDependencyValue.new(
			"",
			&"runtime_clock",
			value
		).is_valid(),
		"RDV-U02: empty Device ID is invalid"
	)
	_expect(
		not RuntimeDependencyValue.new(
			"device_a",
			&"",
			value
		).is_valid(),
		"RDV-U02: empty Dependency ID is invalid"
	)
	_expect(
		not RuntimeDependencyValue.new(
			"device_a",
			&"runtime_clock",
			null
		).is_valid(),
		"RDV-U02: null Object is invalid"
	)


func _test_disposed_value() -> void:

	var node := Node.new()
	var entry := RuntimeDependencyValue.new(
		"device_a",
		&"runtime_clock",
		node
	)

	_expect(
		entry.is_valid(),
		"RDV-U03: live Object starts valid"
	)

	node.free()

	_expect(
		not entry.is_valid(),
		"RDV-U03: disposed Object invalidates Value"
	)


func _test_contract() -> void:

	var entry := RuntimeDependencyValue.new(
		"device_a",
		&"runtime_clock",
		RefCounted.new()
	)

	_expect(
		not entry.has_method(&"set_device_id")
		and not entry.has_method(&"set_dependency_id")
		and not entry.has_method(&"set_value"),
		"RDV-U04: Value exposes no setters"
	)
	_expect(
		not entry.has_method(&"get_ownership")
		and not entry.has_method(&"is_borrowed")
		and not entry.has_method(&"is_transferred"),
		"RDV-U04: Value contains no Ownership"
	)


func _expect(
	condition: bool,
	description: String
) -> void:

	_check_count += 1

	if condition:
		print("[PASS] ", description)
		return

	_failure_count += 1
	push_error("[FAIL] " + description)


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
	get_tree().quit(_failure_count)
