extends Node


##
## RuntimeDeviceHandleTest
##
## Verifica identidad, runtime object,
## host objects, dependencies e inmutabilidad.
##


class TestRuntimeObject:

	extends RefCounted


class TestHostObject:

	extends RefCounted


class TestDependency:

	extends RefCounted


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeDeviceHandleTest")
	print("========================================")

	_test_valid_handle()
	_test_required_components()
	_test_identity_mismatches()
	_test_invalid_host_objects()
	_test_invalid_dependencies()
	_test_collection_independence()
	_test_contract()

	_finish_test()


# =============================================================================
# VALID HANDLE
# =============================================================================

func _test_valid_handle() -> void:

	var configuration := _valid_configuration()
	var factory_key := _valid_factory_key()
	var primary_object := TestRuntimeObject.new()
	var secondary_host := TestHostObject.new()

	var borrowed_binding := RuntimeDependencyBinding.new(
		&"runtime_clock",
		TestDependency.new(),
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var transferred_binding := RuntimeDependencyBinding.new(
		&"distance_provider",
		TestDependency.new(),
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	var host_objects: Array[Object] = [
		primary_object,
		secondary_host,
	]

	var bindings: Array[RuntimeDependencyBinding] = [
		borrowed_binding,
		transferred_binding,
	]

	var handle := RuntimeDeviceHandle.new(
		"runtime_sensor",
		configuration,
		factory_key,
		primary_object,
		host_objects,
		bindings
	)

	var handle_value: Variant = handle

	_expect(
		handle.is_valid(),
		"RDH-U01: complete Handle is valid"
	)

	_expect(
		handle.get_device_id() == "runtime_sensor",
		"RDH-U01: Device ID is preserved"
	)

	_expect(
		handle.get_configuration() == configuration,
		"RDH-U01: Configuration reference is preserved"
	)

	_expect(
		handle.get_factory_key() == factory_key,
		"RDH-U01: Factory Key reference is preserved"
	)

	_expect(
		handle.get_primary_runtime_object()
		== primary_object,
		"RDH-U01: Primary Runtime Object is preserved"
	)

	var returned_hosts := handle.get_host_objects()

	_expect(
		returned_hosts.size() == 2
		and returned_hosts[0] == primary_object
		and returned_hosts[1] == secondary_host,
		"RDH-U01: Host Object order is preserved"
	)

	var returned_bindings := handle.get_dependency_bindings()

	_expect(
		returned_bindings.size() == 2
		and returned_bindings[0] == borrowed_binding
		and returned_bindings[1] == transferred_binding,
		"RDH-U01: Dependency Binding order is preserved"
	)

	_expect(
		handle.has_dependency(
			&"runtime_clock"
		)
		and handle.has_dependency(
			&"distance_provider"
		),
		"RDH-U01: declared Dependencies are discoverable"
	)

	_expect(
		handle.get_dependency_binding(
			&"runtime_clock"
		) == borrowed_binding
		and handle.get_dependency_binding(
			&"distance_provider"
		) == transferred_binding
		and handle.get_dependency_binding(
			&"missing"
		) == null,
		"RDH-U01: exact Dependency lookup works"
	)

	_expect(
		handle_value is RefCounted
		and not (handle_value is Node),
		"RDH-U01: Handle is RefCounted and not Node"
	)


# =============================================================================
# REQUIRED COMPONENTS
# =============================================================================

func _test_required_components() -> void:

	var valid_configuration := _valid_configuration()
	var valid_key := _valid_factory_key()
	var primary := TestRuntimeObject.new()

	var missing_device_id := RuntimeDeviceHandle.new(
		"",
		valid_configuration,
		valid_key,
		primary
	)

	var missing_configuration := RuntimeDeviceHandle.new(
		"runtime_sensor",
		null,
		valid_key,
		primary
	)

	var invalid_configuration := RuntimeDeviceHandle.new(
		"runtime_sensor",
		_invalid_configuration(),
		valid_key,
		primary
	)

	var missing_factory_key := RuntimeDeviceHandle.new(
		"runtime_sensor",
		valid_configuration,
		null,
		primary
	)

	var invalid_factory_key := RuntimeDeviceHandle.new(
		"runtime_sensor",
		valid_configuration,
		RuntimeFactoryKey.new(
			&"",
			2,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		primary
	)

	var missing_primary_object := RuntimeDeviceHandle.new(
		"runtime_sensor",
		valid_configuration,
		valid_key,
		null
	)

	_expect(
		not missing_device_id.is_valid(),
		"RDH-U02: missing Device ID is invalid"
	)

	_expect(
		not missing_configuration.is_valid(),
		"RDH-U02: null Configuration is invalid"
	)

	_expect(
		not invalid_configuration.is_valid(),
		"RDH-U02: invalid Configuration is rejected"
	)

	_expect(
		not missing_factory_key.is_valid(),
		"RDH-U02: null Factory Key is invalid"
	)

	_expect(
		not invalid_factory_key.is_valid(),
		"RDH-U02: invalid Factory Key is rejected"
	)

	_expect(
		not missing_primary_object.is_valid(),
		"RDH-U02: null Primary Runtime Object is invalid"
	)


# =============================================================================
# IDENTITY MISMATCHES
# =============================================================================

func _test_identity_mismatches() -> void:

	var configuration := _valid_configuration()
	var primary := TestRuntimeObject.new()

	var device_id_mismatch := RuntimeDeviceHandle.new(
		"different_device",
		configuration,
		_valid_factory_key(),
		primary
	)

	var profile_id_mismatch := RuntimeDeviceHandle.new(
		"runtime_sensor",
		configuration,
		RuntimeFactoryKey.new(
			&"test.runtime.other",
			2,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		primary
	)

	var profile_version_mismatch := RuntimeDeviceHandle.new(
		"runtime_sensor",
		configuration,
		RuntimeFactoryKey.new(
			&"test.runtime.sensor",
			3,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		primary
	)

	var context_mismatch := RuntimeDeviceHandle.new(
		"runtime_sensor",
		configuration,
		RuntimeFactoryKey.new(
			&"test.runtime.sensor",
			2,
			DeviceConfiguration.ActivationContext.HARDWARE
		),
		primary
	)

	_expect(
		not device_id_mismatch.is_valid(),
		"RDH-U03: Device ID mismatch is rejected"
	)

	_expect(
		not profile_id_mismatch.is_valid(),
		"RDH-U03: Profile ID mismatch is rejected"
	)

	_expect(
		not profile_version_mismatch.is_valid(),
		"RDH-U03: Profile Version mismatch is rejected"
	)

	_expect(
		not context_mismatch.is_valid(),
		"RDH-U03: Activation Context mismatch is rejected"
	)


# =============================================================================
# HOST OBJECTS
# =============================================================================

func _test_invalid_host_objects() -> void:

	var null_hosts: Array[Object] = [
		null,
	]

	var null_host_handle := RuntimeDeviceHandle.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		TestRuntimeObject.new(),
		null_hosts
	)

	var duplicated_host := TestHostObject.new()

	var duplicate_hosts: Array[Object] = [
		duplicated_host,
		duplicated_host,
	]

	var duplicate_host_handle := RuntimeDeviceHandle.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		TestRuntimeObject.new(),
		duplicate_hosts
	)

	_expect(
		not null_host_handle.is_valid(),
		"RDH-U04: null Host Object is rejected"
	)

	_expect(
		not duplicate_host_handle.is_valid(),
		"RDH-U04: duplicate Host Object reference is rejected"
	)


# =============================================================================
# DEPENDENCY BINDINGS
# =============================================================================

func _test_invalid_dependencies() -> void:

	var null_bindings: Array[RuntimeDependencyBinding] = [
		null,
	]

	var null_binding_handle := RuntimeDeviceHandle.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		TestRuntimeObject.new(),
		[],
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

	var invalid_binding_handle := RuntimeDeviceHandle.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		TestRuntimeObject.new(),
		[],
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

	var duplicate_binding_handle := RuntimeDeviceHandle.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		TestRuntimeObject.new(),
		[],
		duplicate_bindings
	)

	_expect(
		not null_binding_handle.is_valid(),
		"RDH-U05: null Dependency Binding is rejected"
	)

	_expect(
		not invalid_binding_handle.is_valid(),
		"RDH-U05: invalid Dependency Binding is rejected"
	)

	_expect(
		not duplicate_binding_handle.is_valid(),
		"RDH-U05: duplicate Dependency ID is rejected"
	)


# =============================================================================
# COLLECTION INDEPENDENCE
# =============================================================================

func _test_collection_independence() -> void:

	var primary := TestRuntimeObject.new()
	var secondary_host := TestHostObject.new()

	var binding := RuntimeDependencyBinding.new(
		&"runtime_clock",
		TestDependency.new(),
		RuntimeDependencyBinding.Ownership.BORROWED
	)

	var constructor_hosts: Array[Object] = [
		primary,
		secondary_host,
	]

	var constructor_bindings: Array[RuntimeDependencyBinding] = [
		binding,
	]

	var handle := RuntimeDeviceHandle.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		primary,
		constructor_hosts,
		constructor_bindings
	)

	constructor_hosts.clear()
	constructor_bindings.clear()

	_expect(
		handle.get_host_objects().size() == 2,
		"RDH-U06: constructor copies Host Object Array"
	)

	_expect(
		handle.get_dependency_bindings().size() == 1,
		"RDH-U06: constructor copies Dependency Array"
	)

	var returned_hosts := handle.get_host_objects()
	var returned_bindings := handle.get_dependency_bindings()

	returned_hosts.clear()
	returned_bindings.clear()

	_expect(
		handle.get_host_objects().size() == 2,
		"RDH-U06: Host Object getter returns independent Array"
	)

	_expect(
		handle.get_dependency_bindings().size() == 1,
		"RDH-U06: Dependency getter returns independent Array"
	)

	_expect(
		handle.get_host_objects()[0] == primary
		and handle.get_host_objects()[1] == secondary_host
		and handle.get_dependency_bindings()[0] == binding,
		"RDH-U06: immutable references remain stable"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var handle := RuntimeDeviceHandle.new(
		"runtime_sensor",
		_valid_configuration(),
		_valid_factory_key(),
		TestRuntimeObject.new()
	)

	_expect(
		not handle.has_method(
			&"set_device_id"
		)
		and not handle.has_method(
			&"set_configuration"
		)
		and not handle.has_method(
			&"set_factory_key"
		)
		and not handle.has_method(
			&"set_primary_runtime_object"
		),
		"RDH-U07: Handle exposes no identity setters"
	)

	_expect(
		not handle.has_method(
			&"set_host_objects"
		)
		and not handle.has_method(
			&"set_dependency_bindings"
		),
		"RDH-U07: Handle exposes no collection setters"
	)

	_expect(
		not handle.has_method(
			&"execute"
		)
		and not handle.has_method(
			&"activate"
		)
		and not handle.has_method(
			&"start_all"
		)
		and not handle.has_method(
			&"shutdown_all"
		),
		"RDH-U07: Handle does not coordinate runtime"
	)

	_expect(
		not handle.has_method(
			&"attach"
		)
		and not handle.has_method(
			&"detach"
		),
		"RDH-U07: Handle has no RuntimeHost behavior"
	)

	_expect(
		not handle.has_method(
			&"release"
		)
		and not handle.has_method(
			&"dispose"
		),
		"RDH-U07: cleanup belongs to RuntimeFactory"
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
		&"test.runtime.handle.configuration",
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
