extends Node


##
## RuntimeDependencySpecTest
##
## Verifica declaración de dependencias,
## ownership e inmutabilidad.
##
## RuntimeDependencySpec no contiene
## un Value runtime activo.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeDependencySpecTest")
	print("========================================")

	_test_borrowed_spec()
	_test_transferred_spec()
	_test_invalid_spec()
	_test_ownership_semantics()
	_test_contract()

	_finish_test()


# =============================================================================
# BORROWED
# =============================================================================

func _test_borrowed_spec() -> void:

	var spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var spec_value: Variant = spec

	_expect(
		spec.is_valid(),
		"RDS-U01: complete BORROWED Spec is valid"
	)

	_expect(
		spec.get_dependency_id()
		== &"runtime_clock",
		"RDS-U01: Dependency ID is preserved"
	)

	_expect(
		spec.get_ownership()
		== RuntimeDependencyBinding.Ownership.BORROWED,
		"RDS-U01: BORROWED ownership is preserved"
	)

	_expect(
		spec.is_borrowed(),
		"RDS-U01: is_borrowed returns true"
	)

	_expect(
		not spec.is_transferred(),
		"RDS-U01: BORROWED is not TRANSFERRED"
	)

	_expect(
		spec_value is RefCounted,
		"RDS-U01: Spec is RefCounted"
	)

	_expect(
		not (spec_value is Node),
		"RDS-U01: Spec is not Node"
	)


# =============================================================================
# TRANSFERRED
# =============================================================================

func _test_transferred_spec() -> void:

	var spec := RuntimeDependencySpec.new(
		&"distance_provider",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	_expect(
		spec.is_valid(),
		"RDS-U02: complete TRANSFERRED Spec is valid"
	)

	_expect(
		spec.get_dependency_id()
		== &"distance_provider",
		"RDS-U02: Dependency ID is preserved"
	)

	_expect(
		spec.get_ownership()
		== RuntimeDependencyBinding.Ownership.TRANSFERRED,
		"RDS-U02: TRANSFERRED ownership is preserved"
	)

	_expect(
		spec.is_transferred(),
		"RDS-U02: is_transferred returns true"
	)

	_expect(
		not spec.is_borrowed(),
		"RDS-U02: TRANSFERRED is not BORROWED"
	)


# =============================================================================
# INVALID SPEC
# =============================================================================

func _test_invalid_spec() -> void:

	var missing_id := RuntimeDependencySpec.new(
		&"",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var negative_ownership := RuntimeDependencySpec.new(
		&"runtime_clock",
		-1
	)

	var unknown_ownership := RuntimeDependencySpec.new(
		&"runtime_clock",
		99
	)

	_expect(
		not missing_id.is_valid(),
		"RDS-U03: missing Dependency ID is invalid"
	)

	_expect(
		not negative_ownership.is_valid(),
		"RDS-U03: negative Ownership is invalid"
	)

	_expect(
		not unknown_ownership.is_valid(),
		"RDS-U03: unknown Ownership is invalid"
	)

	_expect(
		not negative_ownership.is_borrowed()
		and not negative_ownership.is_transferred(),
		"RDS-U03: negative Ownership matches no canonical role"
	)

	_expect(
		not unknown_ownership.is_borrowed()
		and not unknown_ownership.is_transferred(),
		"RDS-U03: unknown Ownership matches no canonical role"
	)


# =============================================================================
# OWNERSHIP SEMANTICS
# =============================================================================

func _test_ownership_semantics() -> void:

	var borrowed := RuntimeDependencySpec.new(
		&"shared_dependency",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var transferred := RuntimeDependencySpec.new(
		&"shared_dependency",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	_expect(
		borrowed.is_valid()
		and transferred.is_valid(),
		"RDS-U04: both canonical Ownership roles are valid"
	)

	_expect(
		borrowed.get_dependency_id()
		== transferred.get_dependency_id(),
		"RDS-U04: same Dependency ID can declare different Ownership"
	)

	_expect(
		borrowed.get_ownership()
		!= transferred.get_ownership(),
		"RDS-U04: Ownership is part of each declaration"
	)

	_expect(
		borrowed.is_borrowed()
		and transferred.is_transferred(),
		"RDS-U04: ownership predicates preserve declaration roles"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	_expect(
		not spec.has_method(
			&"set_dependency_id"
		)
		and not spec.has_method(
			&"set_ownership"
		)
		and not spec.has_method(
			&"set_value"
		),
		"RDS-U05: Spec exposes no setters"
	)

	_expect(
		not spec.has_method(
			&"get_value"
		)
		and not spec.has_method(
			&"get_dependency_value"
		),
		"RDS-U05: Spec contains no active Dependency Value"
	)

	_expect(
		not spec.has_method(
			&"is_optional"
		)
		and not spec.has_method(
			&"get_default_value"
		)
		and not spec.has_method(
			&"get_fallback_value"
		),
		"RDS-U05: Spec 1.0 exposes no optional dependency behavior"
	)

	_expect(
		not spec.has_method(
			&"resolve"
		)
		and not spec.has_method(
			&"get_service"
		)
		and not spec.has_method(
			&"find_dependency"
		),
		"RDS-U05: Spec does not resolve dependencies"
	)

	_expect(
		not spec.has_method(
			&"build"
		)
		and not spec.has_method(
			&"create_device"
		)
		and not spec.has_method(
			&"attach"
		),
		"RDS-U05: Spec has no factory or host behavior"
	)

	_expect(
		not spec.has_method(
			&"release_dependency"
		)
		and not spec.has_method(
			&"dispose"
		)
		and not spec.has_method(
			&"cleanup"
		),
		"RDS-U05: Spec does not execute cleanup"
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
