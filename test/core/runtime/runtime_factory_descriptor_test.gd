extends Node


##
## RuntimeFactoryDescriptorTest
##
## Verifica Factory Key, factory behavior,
## Dependency Specs, inmutabilidad
## y ausencia de ejecución.
##


class ValidFactory:

	extends RefCounted


	var _build_count: int = 0
	var _release_count: int = 0


	func build(
		_request: RuntimeConstructionRequest
	) -> RuntimeFactoryBuildResult:

		_build_count += 1

		return null


	func release(
		_handle: RuntimeDeviceHandle
	) -> ValidationReport:

		_release_count += 1

		return null


	func get_build_count(
	) -> int:

		return _build_count


	func get_release_count(
	) -> int:

		return _release_count


class FactoryWithoutBuild:

	extends RefCounted


	func release(
		_handle: RuntimeDeviceHandle
	) -> ValidationReport:

		return null


class FactoryWithoutRelease:

	extends RefCounted


	func build(
		_request: RuntimeConstructionRequest
	) -> RuntimeFactoryBuildResult:

		return null


class FactoryWithoutBehavior:

	extends RefCounted


class DisposableFactory:

	extends Node


	func build(
		_request: RuntimeConstructionRequest
	) -> RuntimeFactoryBuildResult:

		return null


	func release(
		_handle: RuntimeDeviceHandle
	) -> ValidationReport:

		return null


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeFactoryDescriptorTest")
	print("========================================")

	_test_valid_descriptor()
	_test_required_components()
	_test_dependency_validation()
	_test_dependency_lookup()
	_test_collection_independence()
	_test_no_factory_execution()
	_test_contract()

	_finish_test()


# =============================================================================
# VALID DESCRIPTOR
# =============================================================================

func _test_valid_descriptor() -> void:

	var factory_key := _valid_factory_key()
	var factory := ValidFactory.new()

	var borrowed_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var transferred_spec := RuntimeDependencySpec.new(
		&"distance_provider",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var dependency_specs: Array[RuntimeDependencySpec] = [
		borrowed_spec,
		transferred_spec,
	]

	var descriptor := RuntimeFactoryDescriptor.new(
		factory_key,
		factory,
		dependency_specs
	)

	var descriptor_value: Variant = descriptor

	_expect(
		descriptor.is_valid(),
		"RFD-U01: complete Descriptor is valid"
	)

	_expect(
		descriptor.get_factory_key() == factory_key,
		"RFD-U01: Factory Key reference is preserved"
	)

	_expect(
		descriptor.get_factory() == factory,
		"RFD-U01: factory Object reference is preserved"
	)

	var returned_specs := descriptor.get_dependency_specs()

	_expect(
		returned_specs.size() == 2
		and returned_specs[0] == borrowed_spec
		and returned_specs[1] == transferred_spec,
		"RFD-U01: Dependency Spec order is preserved"
	)

	_expect(
		descriptor_value is RefCounted
		and not (descriptor_value is Node),
		"RFD-U01: Descriptor is RefCounted and not Node"
	)

	_expect(
		factory.get_build_count() == 0
		and factory.get_release_count() == 0,
		"RFD-U01: Descriptor validation does not execute factory"
	)


# =============================================================================
# REQUIRED COMPONENTS
# =============================================================================

func _test_required_components() -> void:

	var valid_key := _valid_factory_key()
	var valid_factory := ValidFactory.new()

	var empty_specs: Array[RuntimeDependencySpec] = []

	var missing_key := RuntimeFactoryDescriptor.new(
		null,
		valid_factory,
		empty_specs
	)

	var invalid_key := RuntimeFactoryDescriptor.new(
		RuntimeFactoryKey.new(
			&"",
			1,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		valid_factory,
		empty_specs
	)

	var missing_factory := RuntimeFactoryDescriptor.new(
		valid_key,
		null,
		empty_specs
	)

	var missing_build := RuntimeFactoryDescriptor.new(
		valid_key,
		FactoryWithoutBuild.new(),
		empty_specs
	)

	var missing_release := RuntimeFactoryDescriptor.new(
		valid_key,
		FactoryWithoutRelease.new(),
		empty_specs
	)

	var missing_behavior := RuntimeFactoryDescriptor.new(
		valid_key,
		FactoryWithoutBehavior.new(),
		empty_specs
	)

	var disposable_factory := DisposableFactory.new()

	var disposed_factory_descriptor := RuntimeFactoryDescriptor.new(
		valid_key,
		disposable_factory,
		empty_specs
	)

	disposable_factory.free()

	var empty_dependencies := RuntimeFactoryDescriptor.new(
		valid_key,
		ValidFactory.new(),
		empty_specs
	)

	_expect(
		not missing_key.is_valid(),
		"RFD-U02: null Factory Key is invalid"
	)

	_expect(
		not invalid_key.is_valid(),
		"RFD-U02: invalid Factory Key is rejected"
	)

	_expect(
		not missing_factory.is_valid(),
		"RFD-U02: null factory Object is invalid"
	)

	_expect(
		not missing_build.is_valid(),
		"RFD-U02: factory without build is invalid"
	)

	_expect(
		not missing_release.is_valid(),
		"RFD-U02: factory without release is invalid"
	)

	_expect(
		not missing_behavior.is_valid(),
		"RFD-U02: factory without required behavior is invalid"
	)

	_expect(
		not disposed_factory_descriptor.is_valid(),
		"RFD-U02: disposed factory instance is invalid"
	)

	_expect(
		empty_dependencies.is_valid(),
		"RFD-U02: Descriptor may declare zero Dependencies"
	)


# =============================================================================
# DEPENDENCY VALIDATION
# =============================================================================

func _test_dependency_validation() -> void:

	var null_specs: Array[RuntimeDependencySpec] = [
		null,
	]

	var invalid_id_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			&"",
			RuntimeDependencyBinding.Ownership.BORROWED
		),
	]

	var invalid_ownership_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			&"runtime_clock",
			99
		),
	]

	var shared_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var duplicate_reference_specs: Array[RuntimeDependencySpec] = [
		shared_spec,
		shared_spec,
	]

	var duplicate_id_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			&"runtime_clock",
			RuntimeDependencyBinding.Ownership.BORROWED
		),
		RuntimeDependencySpec.new(
			&"runtime_clock",
			RuntimeDependencyBinding.Ownership.TRANSFERRED
		),
	]

	var distinct_specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			&"runtime_clock",
			RuntimeDependencyBinding.Ownership.BORROWED
		),
		RuntimeDependencySpec.new(
			&"distance_provider",
			RuntimeDependencyBinding.Ownership.TRANSFERRED
		),
	]

	_expect(
		not _descriptor_with_specs(
			null_specs
		).is_valid(),
		"RFD-U03: null Dependency Spec is rejected"
	)

	_expect(
		not _descriptor_with_specs(
			invalid_id_specs
		).is_valid(),
		"RFD-U03: invalid Dependency ID is rejected"
	)

	_expect(
		not _descriptor_with_specs(
			invalid_ownership_specs
		).is_valid(),
		"RFD-U03: invalid Dependency Ownership is rejected"
	)

	_expect(
		not _descriptor_with_specs(
			duplicate_reference_specs
		).is_valid(),
		"RFD-U03: duplicate Dependency Spec reference is rejected"
	)

	_expect(
		not _descriptor_with_specs(
			duplicate_id_specs
		).is_valid(),
		"RFD-U03: duplicate Dependency ID is rejected"
	)

	_expect(
		_descriptor_with_specs(
			distinct_specs
		).is_valid(),
		"RFD-U03: distinct valid Dependency Specs are accepted"
	)


# =============================================================================
# DEPENDENCY LOOKUP
# =============================================================================

func _test_dependency_lookup() -> void:

	var first_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var second_spec := RuntimeDependencySpec.new(
		&"distance_provider",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var specs: Array[RuntimeDependencySpec] = [
		first_spec,
		second_spec,
	]

	var descriptor := _descriptor_with_specs(
		specs
	)

	_expect(
		descriptor.has_dependency(
			&"runtime_clock"
		)
		and descriptor.has_dependency(
			&"distance_provider"
		)
		and not descriptor.has_dependency(
			&"missing"
		),
		"RFD-U04: exact Dependency presence lookup works"
	)

	_expect(
		descriptor.get_dependency_spec(
			&"runtime_clock"
		) == first_spec
		and descriptor.get_dependency_spec(
			&"distance_provider"
		) == second_spec,
		"RFD-U04: exact Dependency lookup preserves references"
	)

	_expect(
		descriptor.get_dependency_spec(
			&"missing"
		) == null,
		"RFD-U04: missing Dependency lookup returns null"
	)

	_expect(
		not descriptor.has_dependency(
			&""
		)
		and descriptor.get_dependency_spec(
			&""
		) == null,
		"RFD-U04: empty Dependency ID does not resolve"
	)


# =============================================================================
# COLLECTION INDEPENDENCE
# =============================================================================

func _test_collection_independence() -> void:

	var first_spec := RuntimeDependencySpec.new(
		&"runtime_clock",
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var second_spec := RuntimeDependencySpec.new(
		&"distance_provider",
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var source_specs: Array[RuntimeDependencySpec] = [
		first_spec,
	]

	var descriptor := RuntimeFactoryDescriptor.new(
		_valid_factory_key(),
		ValidFactory.new(),
		source_specs
	)

	source_specs.append(
		second_spec
	)

	var stored_after_source_change := (
		descriptor.get_dependency_specs()
	)

	_expect(
		stored_after_source_change.size() == 1
		and stored_after_source_change[0] == first_spec
		and not descriptor.has_dependency(
			&"distance_provider"
		),
		"RFD-U05: constructor copies Dependency Spec Array"
	)

	var returned_specs := descriptor.get_dependency_specs()

	returned_specs.clear()

	var stored_after_return_change := (
		descriptor.get_dependency_specs()
	)

	_expect(
		stored_after_return_change.size() == 1
		and stored_after_return_change[0] == first_spec,
		"RFD-U05: getter returns independent Dependency Spec Array"
	)


# =============================================================================
# NO FACTORY EXECUTION
# =============================================================================

func _test_no_factory_execution() -> void:

	var factory := ValidFactory.new()

	var specs: Array[RuntimeDependencySpec] = [
		RuntimeDependencySpec.new(
			&"runtime_clock",
			RuntimeDependencyBinding.Ownership.BORROWED
		),
	]

	var descriptor := RuntimeFactoryDescriptor.new(
		_valid_factory_key(),
		factory,
		specs
	)

	descriptor.is_valid()
	descriptor.get_factory()
	descriptor.get_factory_key()
	descriptor.get_dependency_specs()
	descriptor.has_dependency(
		&"runtime_clock"
	)
	descriptor.get_dependency_spec(
		&"runtime_clock"
	)

	_expect(
		factory.get_build_count() == 0
		and factory.get_release_count() == 0,
		"RFD-U06: validation and lookup never execute factory"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var empty_specs: Array[RuntimeDependencySpec] = []

	var descriptor := RuntimeFactoryDescriptor.new(
		_valid_factory_key(),
		ValidFactory.new(),
		empty_specs
	)

	_expect(
		not descriptor.has_method(
			&"set_factory_key"
		)
		and not descriptor.has_method(
			&"set_factory"
		)
		and not descriptor.has_method(
			&"set_dependency_specs"
		),
		"RFD-U07: Descriptor exposes no setters"
	)

	_expect(
		not descriptor.has_method(
			&"add_dependency"
		)
		and not descriptor.has_method(
			&"remove_dependency"
		)
		and not descriptor.has_method(
			&"clear_dependencies"
		),
		"RFD-U07: Descriptor exposes no collection mutation"
	)

	_expect(
		not descriptor.has_method(
			&"register"
		)
		and not descriptor.has_method(
			&"unregister"
		)
		and not descriptor.has_method(
			&"replace"
		),
		"RFD-U07: Descriptor is not a Registry"
	)

	_expect(
		not descriptor.has_method(
			&"build"
		)
		and not descriptor.has_method(
			&"release"
		),
		"RFD-U07: Descriptor does not expose factory execution"
	)

	_expect(
		not descriptor.has_method(
			&"resolve"
		)
		and not descriptor.has_method(
			&"get_service"
		),
		"RFD-U07: Descriptor is not a service locator"
	)

	_expect(
		not descriptor.has_method(
			&"execute"
		)
		and not descriptor.has_method(
			&"create_device"
		)
		and not descriptor.has_method(
			&"attach"
		),
		"RFD-U07: Descriptor does not activate runtime"
	)


# =============================================================================
# TEST HELPERS
# =============================================================================

func _valid_factory_key(
) -> RuntimeFactoryKey:

	return RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)


func _descriptor_with_specs(
	specs: Array[RuntimeDependencySpec]
) -> RuntimeFactoryDescriptor:

	return RuntimeFactoryDescriptor.new(
		_valid_factory_key(),
		ValidFactory.new(),
		specs
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
