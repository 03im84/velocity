extends Node


##
## RuntimeConstructionRequestTest
##
## Verifica identidad, coherencia,
## dependencias pre-resueltas e inmutabilidad.
##


class TestDependency:

	extends RefCounted


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeConstructionRequestTest")
	print("========================================")

	_test_valid_request()
	_test_required_components()
	_test_identity_mismatches()
	_test_invalid_bindings()
	_test_collection_independence()
	_test_contract()

	_finish_test()


# =============================================================================
# VALID REQUEST
# =============================================================================

func _test_valid_request() -> void:

	var configuration := _configuration(
		"runtime_sensor",
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var factory_key := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var borrowed_dependency := TestDependency.new()
	var transferred_dependency := TestDependency.new()

	var borrowed_binding := RuntimeDependencyBinding.new(
		&"runtime_clock",
		borrowed_dependency,
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var transferred_binding := RuntimeDependencyBinding.new(
		&"distance_provider",
		transferred_dependency,
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var bindings: Array[RuntimeDependencyBinding] = [
		borrowed_binding,
		transferred_binding,
	]

	var request := RuntimeConstructionRequest.new(
		"runtime_sensor",
		configuration,
		factory_key,
		bindings
	)

	var request_value: Variant = request

	_expect(
		request.is_valid(),
		"RCR-U01: complete Request is valid"
	)

	_expect(
		request.get_device_id() == "runtime_sensor",
		"RCR-U01: Device ID is preserved"
	)

	_expect(
		request.get_configuration() == configuration,
		"RCR-U01: Configuration reference is preserved"
	)

	_expect(
		request.get_factory_key() == factory_key,
		"RCR-U01: Factory Key reference is preserved"
	)

	var returned_bindings := request.get_dependency_bindings()

	_expect(
		returned_bindings.size() == 2
		and returned_bindings[0] == borrowed_binding
		and returned_bindings[1] == transferred_binding,
		"RCR-U01: Binding order and references are preserved"
	)

	_expect(
		request.has_dependency(
			&"runtime_clock"
		)
		and request.has_dependency(
			&"distance_provider"
		),
		"RCR-U01: declared Dependencies are discoverable"
	)

	_expect(
		request.get_dependency_binding(
			&"runtime_clock"
		) == borrowed_binding
		and request.get_dependency_binding(
			&"distance_provider"
		) == transferred_binding,
		"RCR-U01: exact Dependency lookup works"
	)

	_expect(
		not request.has_dependency(
			&"missing_dependency"
		)
		and request.get_dependency_binding(
			&"missing_dependency"
		) == null
		and request.get_dependency_binding(
			&""
		) == null,
		"RCR-U01: missing Dependency returns null"
	)

	_expect(
		request_value is RefCounted,
		"RCR-U01: Request is RefCounted"
	)

	_expect(
		not (request_value is Node),
		"RCR-U01: Request is not Node"
	)


# =============================================================================
# REQUIRED COMPONENTS
# =============================================================================

func _test_required_components() -> void:

	var configuration := _valid_configuration()
	var factory_key := _valid_factory_key()
	var bindings: Array[RuntimeDependencyBinding] = []

	var missing_device_id := RuntimeConstructionRequest.new(
		"",
		configuration,
		factory_key,
		bindings
	)

	var missing_configuration := RuntimeConstructionRequest.new(
		"runtime_sensor",
		null,
		factory_key,
		bindings
	)

	var invalid_configuration := RuntimeConstructionRequest.new(
		"runtime_sensor",
		_invalid_configuration(),
		factory_key,
		bindings
	)

	var missing_factory_key := RuntimeConstructionRequest.new(
		"runtime_sensor",
		configuration,
		null,
		bindings
	)

	var invalid_factory_key := RuntimeConstructionRequest.new(
		"runtime_sensor",
		configuration,
		RuntimeFactoryKey.new(
			&"",
			1,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		bindings
	)

	_expect(
		not missing_device_id.is_valid(),
		"RCR-U02: missing Device ID is invalid"
	)

	_expect(
		not missing_configuration.is_valid(),
		"RCR-U02: null Configuration is invalid"
	)

	_expect(
		not invalid_configuration.is_valid(),
		"RCR-U02: invalid Configuration is rejected"
	)

	_expect(
		not missing_factory_key.is_valid(),
		"RCR-U02: null Factory Key is invalid"
	)

	_expect(
		not invalid_factory_key.is_valid(),
		"RCR-U02: invalid Factory Key is rejected"
	)


# =============================================================================
# IDENTITY MISMATCHES
# =============================================================================

func _test_identity_mismatches() -> void:

	var configuration := _valid_configuration()
	var empty_bindings: Array[RuntimeDependencyBinding] = []

	var device_id_mismatch := RuntimeConstructionRequest.new(
		"different_device",
		configuration,
		_valid_factory_key(),
		empty_bindings
	)

	var profile_id_mismatch := RuntimeConstructionRequest.new(
		"runtime_sensor",
		configuration,
		RuntimeFactoryKey.new(
			&"test.runtime.other",
			2,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		empty_bindings
	)

	var profile_version_mismatch := RuntimeConstructionRequest.new(
		"runtime_sensor",
		configuration,
		RuntimeFactoryKey.new(
			&"test.runtime.sensor",
			3,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		empty_bindings
	)

	var context_mismatch := RuntimeConstructionRequest.new(
		"runtime_sensor",
		configuration,
		RuntimeFactoryKey.new(
			&"test.runtime.sensor",
			2,
			DeviceConfiguration.ActivationContext.HARDWARE
		),
		empty_bindings
	)

	_expect(
		not device_id_mismatch.is_valid(),
		"RCR-U03: Device ID mismatch is rejected"
	)

	_expect(
		not profile_id_mismatch.is_valid(),
		"RCR-U03: Profile ID mismatch is rejected"
	)

	_expect(
		not profile_version_mismatch.is_valid(),
		"RCR-U03: Profile Version mismatch is rejected"
	)

	_expect(
		not context_mismatch.is_valid(),
		"RCR-U03: Activation Context mismatch is rejected"
	)


# =============================================================================
# INVALID BINDINGS
# =============================================================================

func _test_invalid_bindings() -> void:

	var null_bindings: Array[RuntimeDependencyBinding] = [
		null,
	]

	var null_binding_request := RuntimeConstructionRequest.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		null_bindings
	)

	var invalid_binding := RuntimeDependencyBinding.new(
		&"runtime_clock",
		null,
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var invalid_bindings: Array[RuntimeDependencyBinding] = [
		invalid_binding,
	]

	var invalid_binding_request := RuntimeConstructionRequest.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		invalid_bindings
	)

	var first_duplicate := RuntimeDependencyBinding.new(
		&"runtime_clock",
		TestDependency.new(),
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var second_duplicate := RuntimeDependencyBinding.new(
		&"runtime_clock",
		TestDependency.new(),
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var duplicate_bindings: Array[RuntimeDependencyBinding] = [
		first_duplicate,
		second_duplicate,
	]

	var duplicate_request := RuntimeConstructionRequest.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		duplicate_bindings
	)

	_expect(
		not null_binding_request.is_valid(),
		"RCR-U04: null Binding is rejected"
	)

	_expect(
		not invalid_binding_request.is_valid(),
		"RCR-U04: invalid Binding is rejected"
	)

	_expect(
		not duplicate_request.is_valid(),
		"RCR-U04: duplicate Dependency ID is rejected"
	)


# =============================================================================
# COLLECTION INDEPENDENCE
# =============================================================================

func _test_collection_independence() -> void:

	var first_binding := RuntimeDependencyBinding.new(
		&"runtime_clock",
		TestDependency.new(),
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var second_binding := RuntimeDependencyBinding.new(
		&"distance_provider",
		TestDependency.new(),
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var constructor_bindings: Array[RuntimeDependencyBinding] = [
		first_binding,
		second_binding,
	]

	var request := RuntimeConstructionRequest.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		constructor_bindings
	)

	constructor_bindings.clear()

	_expect(
		request.get_dependency_bindings().size() == 2,
		"RCR-U05: constructor copies Binding Array"
	)

	var returned_bindings := request.get_dependency_bindings()

	returned_bindings.clear()

	_expect(
		request.get_dependency_bindings().size() == 2,
		"RCR-U05: getter returns independent Binding Array"
	)

	_expect(
		request.get_dependency_bindings()[0]
		== first_binding
		and request.get_dependency_bindings()[1]
		== second_binding,
		"RCR-U05: immutable Binding references are preserved"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var request := RuntimeConstructionRequest.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		[]
	)

	_expect(
		not request.has_method(
			&"set_device_id"
		)
		and not request.has_method(
			&"set_configuration"
		)
		and not request.has_method(
			&"set_factory_key"
		)
		and not request.has_method(
			&"set_dependency_bindings"
		),
		"RCR-U06: Request exposes no setters"
	)

	_expect(
		not request.has_method(
			&"resolve_dependency"
		)
		and not request.has_method(
			&"get_service"
		)
		and not request.has_method(
			&"find_node"
		),
		"RCR-U06: Request is not a service locator"
	)

	_expect(
		not request.has_method(
			&"build"
		)
		and not request.has_method(
			&"create_device"
		),
		"RCR-U06: Request has no factory behavior"
	)

	_expect(
		not request.has_method(
			&"execute"
		)
		and not request.has_method(
			&"attach"
		),
		"RCR-U06: Request has no runtime or host behavior"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _valid_factory_key() -> RuntimeFactoryKey:

	return RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)


func _valid_configuration() -> DeviceConfiguration:

	return _configuration(
		"runtime_sensor",
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)


func _invalid_configuration() -> DeviceConfiguration:

	return _configuration(
		"",
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)


func _configuration(
	device_id: String,
	profile_id: StringName,
	profile_version: int,
	activation_context: int
) -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"runtime_construction",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		&"test.runtime.request.configuration",
		1,
		device_id,
		profile_id,
		profile_version,
		activation_context,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
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
