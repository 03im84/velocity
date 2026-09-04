extends Node


##
## RuntimeFactoryKeyTest
##
## Verifica identidad exacta,
## contexto e igualdad lógica.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeFactoryKeyTest")
	print("========================================")

	_test_valid_simulation_key()
	_test_valid_hardware_key()
	_test_invalid_identity()
	_test_logical_equality()
	_test_contract()

	_finish_test()


# =============================================================================
# VALID SIMULATION KEY
# =============================================================================

func _test_valid_simulation_key() -> void:

	var key := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var key_value: Variant = key

	_expect(
		key.is_valid(),
		"RFK-U01: complete Simulation Key is valid"
	)

	_expect(
		key.get_profile_id()
		== &"test.runtime.sensor",
		"RFK-U01: Profile ID is preserved"
	)

	_expect(
		key.get_profile_version() == 1,
		"RFK-U01: Profile Version is preserved"
	)

	_expect(
		key.get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION,
		"RFK-U01: Simulation context is preserved"
	)

	_expect(
		key_value is RefCounted,
		"RFK-U01: Key is RefCounted"
	)

	_expect(
		not (key_value is Node),
		"RFK-U01: Key is not Node"
	)


# =============================================================================
# VALID HARDWARE KEY
# =============================================================================

func _test_valid_hardware_key() -> void:

	var key := RuntimeFactoryKey.new(
		&"test.runtime.hardware",
		4,
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	_expect(
		key.is_valid(),
		"RFK-U02: complete Hardware Key is valid"
	)

	_expect(
		key.get_activation_context()
		== DeviceConfiguration.ActivationContext.HARDWARE,
		"RFK-U02: Hardware context is preserved"
	)


# =============================================================================
# INVALID IDENTITY
# =============================================================================

func _test_invalid_identity() -> void:

	var missing_profile_id := RuntimeFactoryKey.new(
		&"",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var zero_version := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		0,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var negative_version := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		-1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var invalid_context := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		1,
		-1
	)

	_expect(
		not missing_profile_id.is_valid(),
		"RFK-U03: missing Profile ID is invalid"
	)

	_expect(
		not zero_version.is_valid(),
		"RFK-U03: version zero is invalid"
	)

	_expect(
		not negative_version.is_valid(),
		"RFK-U03: negative version is invalid"
	)

	_expect(
		not invalid_context.is_valid(),
		"RFK-U03: unknown Activation Context is invalid"
	)


# =============================================================================
# LOGICAL EQUALITY
# =============================================================================

func _test_logical_equality() -> void:

	var first := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var equivalent := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var different_profile := RuntimeFactoryKey.new(
		&"test.runtime.controller",
		2,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var different_version := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		3,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	var different_context := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		2,
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	_expect(
		first.equals(equivalent),
		"RFK-U04: equal fields produce logical equality"
	)

	_expect(
		equivalent.equals(first),
		"RFK-U04: equality is symmetric"
	)

	_expect(
		first.equals(first),
		"RFK-U04: equality is reflexive"
	)

	_expect(
		not first.equals(different_profile),
		"RFK-U04: different Profile ID is not equal"
	)

	_expect(
		not first.equals(different_version),
		"RFK-U04: different Profile Version is not equal"
	)

	_expect(
		not first.equals(different_context),
		"RFK-U04: different Activation Context is not equal"
	)

	_expect(
		not first.equals(null),
		"RFK-U04: null is not equal"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var key := RuntimeFactoryKey.new(
		&"test.runtime.sensor",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	_expect(
		not key.has_method(
			&"set_profile_id"
		)
		and not key.has_method(
			&"set_profile_version"
		)
		and not key.has_method(
			&"set_activation_context"
		),
		"RFK-U05: Key exposes no setters"
	)

	_expect(
		not key.has_method(
			&"get_factory"
		)
		and not key.has_method(
			&"get_callable"
		),
		"RFK-U05: Key contains no executable factory"
	)

	_expect(
		not key.has_method(
			&"get_host_target"
		),
		"RFK-U05: Key contains no host target"
	)

	_expect(
		not key.has_method(
			&"get_latest"
		)
		and not key.has_method(
			&"get_compatible"
		),
		"RFK-U05: Key exposes no fallback resolution"
	)

	_expect(
		not key.has_method(
			&"execute"
		)
		and not key.has_method(
			&"create_device"
		),
		"RFK-U05: Key is not executable"
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
