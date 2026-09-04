extends Node


##
## RuntimeDependencyBindingTest
##
## Verifica dependency value,
## ownership e inmutabilidad.
##


class TestDependency:

	extends RefCounted


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeDependencyBindingTest")
	print("========================================")

	_test_borrowed_binding()
	_test_transferred_binding()
	_test_invalid_binding()
	_test_ownership_semantics()
	_test_contract()

	_finish_test()


# =============================================================================
# BORROWED
# =============================================================================

func _test_borrowed_binding() -> void:

	var dependency := TestDependency.new()

	var binding := RuntimeDependencyBinding.new(
		&"runtime_clock",
		dependency,
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var binding_value: Variant = binding

	_expect(
		binding.is_valid(),
		"RDB-U01: complete BORROWED Binding is valid"
	)

	_expect(
		binding.get_dependency_id()
		== &"runtime_clock",
		"RDB-U01: Dependency ID is preserved"
	)

	_expect(
		binding.get_value() == dependency,
		"RDB-U01: Dependency Object is preserved"
	)

	_expect(
		binding.get_ownership()
		== RuntimeDependencyBinding.Ownership.BORROWED,
		"RDB-U01: BORROWED ownership is preserved"
	)

	_expect(
		binding.is_borrowed(),
		"RDB-U01: is_borrowed returns true"
	)

	_expect(
		not binding.is_transferred(),
		"RDB-U01: BORROWED is not TRANSFERRED"
	)

	_expect(
		binding_value is RefCounted,
		"RDB-U01: Binding is RefCounted"
	)

	_expect(
		not (binding_value is Node),
		"RDB-U01: Binding is not Node"
	)


# =============================================================================
# TRANSFERRED
# =============================================================================

func _test_transferred_binding() -> void:

	var dependency := TestDependency.new()

	var binding := RuntimeDependencyBinding.new(
		&"distance_provider",
		dependency,
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	_expect(
		binding.is_valid(),
		"RDB-U02: complete TRANSFERRED Binding is valid"
	)

	_expect(
		binding.get_ownership()
		== RuntimeDependencyBinding.Ownership.TRANSFERRED,
		"RDB-U02: TRANSFERRED ownership is preserved"
	)

	_expect(
		binding.is_transferred(),
		"RDB-U02: is_transferred returns true"
	)

	_expect(
		not binding.is_borrowed(),
		"RDB-U02: TRANSFERRED is not BORROWED"
	)


# =============================================================================
# INVALID BINDING
# =============================================================================

func _test_invalid_binding() -> void:

	var dependency := TestDependency.new()

	var missing_id := RuntimeDependencyBinding.new(
		&"",
		dependency,
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var missing_value := RuntimeDependencyBinding.new(
		&"runtime_clock",
		null,
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var negative_ownership := RuntimeDependencyBinding.new(
		&"runtime_clock",
		dependency,
		-1
	)

	var unknown_ownership := RuntimeDependencyBinding.new(
		&"runtime_clock",
		dependency,
		99
	)

	_expect(
		not missing_id.is_valid(),
		"RDB-U03: missing Dependency ID is invalid"
	)

	_expect(
		not missing_value.is_valid(),
		"RDB-U03: null Dependency Value is invalid"
	)

	_expect(
		not negative_ownership.is_valid(),
		"RDB-U03: negative Ownership is invalid"
	)

	_expect(
		not unknown_ownership.is_valid(),
		"RDB-U03: unknown Ownership is invalid"
	)

	_expect(
		not unknown_ownership.is_borrowed()
		and not unknown_ownership.is_transferred(),
		"RDB-U03: unknown Ownership matches no canonical role"
	)


# =============================================================================
# OWNERSHIP SEMANTICS
# =============================================================================

func _test_ownership_semantics() -> void:

	var shared_dependency := TestDependency.new()

	var borrowed := RuntimeDependencyBinding.new(
		&"shared_dependency",
		shared_dependency,
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var transferred := RuntimeDependencyBinding.new(
		&"private_dependency",
		shared_dependency,
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	_expect(
		borrowed.is_valid()
		and transferred.is_valid(),
		"RDB-U04: same Object can participate in explicit Binding roles"
	)

	_expect(
		borrowed.get_value() == transferred.get_value()
		and borrowed.get_dependency_id()
		!= transferred.get_dependency_id(),
		"RDB-U04: ownership belongs to Binding, not Object identity"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var binding := RuntimeDependencyBinding.new(
		&"runtime_clock",
		TestDependency.new(),
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	_expect(
		not binding.has_method(
			&"set_dependency_id"
		)
		and not binding.has_method(
			&"set_value"
		)
		and not binding.has_method(
			&"set_ownership"
		),
		"RDB-U05: Binding exposes no setters"
	)

	_expect(
		not binding.has_method(
			&"release_dependency"
		)
		and not binding.has_method(
			&"dispose"
		),
		"RDB-U05: Binding does not execute cleanup"
	)

	_expect(
		not binding.has_method(
			&"resolve"
		)
		and not binding.has_method(
			&"get_service"
		),
		"RDB-U05: Binding is not a service locator"
	)

	_expect(
		not binding.has_method(
			&"build"
		)
		and not binding.has_method(
			&"create_device"
		)
		and not binding.has_method(
			&"attach"
		),
		"RDB-U05: Binding has no factory or host behavior"
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
