extends Node


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("ScopedRuntimeDependencyResolverTest")
	print("========================================")

	_test_empty_resolver()
	_test_exact_resolution()
	_test_invalid_entries()
	_test_duplicate_key()
	_test_disposed_value()
	_test_source_array_protection()
	_test_contract()

	_finish_test()


func _test_empty_resolver() -> void:

	var values: Array[RuntimeDependencyValue] = []
	var resolver := ScopedRuntimeDependencyResolver.new(values)

	_expect(
		resolver.is_valid(),
		"SRDR-U01: empty Resolver is valid"
	)
	_expect(
		resolver.get_value_count() == 0,
		"SRDR-U01: empty Resolver has zero Values"
	)
	_expect(
		not resolver.has_value("device_a", &"clock")
		and resolver.get_value("device_a", &"clock") == null,
		"SRDR-U01: missing exact Value returns false and null"
	)


func _test_exact_resolution() -> void:

	var clock_a := RefCounted.new()
	var provider_a := RefCounted.new()
	var clock_b := RefCounted.new()
	var values: Array[RuntimeDependencyValue] = [
		RuntimeDependencyValue.new(
			"device_a",
			&"clock",
			clock_a
		),
		RuntimeDependencyValue.new(
			"device_a",
			&"provider",
			provider_a
		),
		RuntimeDependencyValue.new(
			"device_b",
			&"clock",
			clock_b
		),
	]
	var resolver := ScopedRuntimeDependencyResolver.new(values)

	_expect(
		resolver.is_valid()
		and resolver.get_value_count() == 3,
		"SRDR-U02: multiple exact Values are valid"
	)
	_expect(
		resolver.has_value("device_a", &"clock")
		and resolver.get_value("device_a", &"clock") == clock_a,
		"SRDR-U02: Device A Clock resolves exactly"
	)
	_expect(
		resolver.has_value("device_a", &"provider")
		and resolver.get_value("device_a", &"provider")
		== provider_a,
		"SRDR-U02: Device A Provider resolves exactly"
	)
	_expect(
		resolver.has_value("device_b", &"clock")
		and resolver.get_value("device_b", &"clock") == clock_b,
		"SRDR-U02: Device B Clock resolves independently"
	)
	_expect(
		not resolver.has_value("device_b", &"provider")
		and resolver.get_value("device_b", &"provider") == null,
		"SRDR-U02: Resolver provides no cross-Device fallback"
	)
	_expect(
		not resolver.has_value("", &"clock")
		and not resolver.has_value("device_a", &""),
		"SRDR-U02: empty lookup identity is rejected"
	)


func _test_invalid_entries() -> void:

	var null_values: Array[RuntimeDependencyValue] = []
	null_values.append(null)
	var null_resolver := ScopedRuntimeDependencyResolver.new(
		null_values
	)

	_expect(
		not null_resolver.is_valid()
		and null_resolver.get_value_count() == 0,
		"SRDR-U03: null Entry invalidates Resolver"
	)

	var invalid_values: Array[RuntimeDependencyValue] = [
		RuntimeDependencyValue.new(
			"",
			&"clock",
			RefCounted.new()
		),
	]
	var invalid_resolver := ScopedRuntimeDependencyResolver.new(
		invalid_values
	)

	_expect(
		not invalid_resolver.is_valid()
		and not invalid_resolver.has_value("device_a", &"clock")
		and invalid_resolver.get_value("device_a", &"clock") == null,
		"SRDR-U03: invalid Entry fails closed"
	)


func _test_duplicate_key() -> void:

	var values: Array[RuntimeDependencyValue] = [
		RuntimeDependencyValue.new(
			"device_a",
			&"clock",
			RefCounted.new()
		),
		RuntimeDependencyValue.new(
			"device_a",
			&"clock",
			RefCounted.new()
		),
	]
	var resolver := ScopedRuntimeDependencyResolver.new(values)

	_expect(
		not resolver.is_valid()
		and resolver.get_value_count() == 0
		and not resolver.has_value("device_a", &"clock"),
		"SRDR-U04: duplicate exact Key invalidates without overwrite"
	)


func _test_disposed_value() -> void:

	var node := Node.new()
	var values: Array[RuntimeDependencyValue] = [
		RuntimeDependencyValue.new(
			"device_a",
			&"provider",
			node
		),
	]
	var resolver := ScopedRuntimeDependencyResolver.new(values)

	_expect(
		resolver.has_value("device_a", &"provider"),
		"SRDR-U05: live Value is available"
	)

	node.free()

	_expect(
		not resolver.has_value("device_a", &"provider")
		and resolver.get_value("device_a", &"provider") == null,
		"SRDR-U05: disposed Value becomes unavailable"
	)


func _test_source_array_protection() -> void:

	var value := RefCounted.new()
	var values: Array[RuntimeDependencyValue] = [
		RuntimeDependencyValue.new(
			"device_a",
			&"clock",
			value
		),
	]
	var resolver := ScopedRuntimeDependencyResolver.new(values)

	values.clear()

	_expect(
		resolver.get_value_count() == 1
		and resolver.get_value("device_a", &"clock") == value,
		"SRDR-U06: Resolver copies source Array"
	)


func _test_contract() -> void:

	var values: Array[RuntimeDependencyValue] = []
	var resolver := ScopedRuntimeDependencyResolver.new(values)

	_expect(
		not resolver.has_method(&"register_value")
		and not resolver.has_method(&"remove_value")
		and not resolver.has_method(&"clear"),
		"SRDR-U07: Resolver exposes no mutation API"
	)
	_expect(
		not resolver.has_method(&"get_service")
		and not resolver.has_method(&"get_by_type")
		and not resolver.has_method(&"get_latest"),
		"SRDR-U07: Resolver exposes no service locator or fallback API"
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
