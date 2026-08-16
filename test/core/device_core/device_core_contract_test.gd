extends Node


##
## DeviceCoreContractTest
##
## Verifica tipo, composición, identidad
## y lifecycle delegado de Device.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceCoreContractTest")
	print("========================================")

	_test_runtime_type()
	_test_composition()
	_test_invalid_identity()
	_test_valid_identity()
	_test_lifecycle_delegation()
	_test_bus_independence()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_runtime_type() -> void:

	var device := Device.new()

	var device_as_variant: Variant = device

	_expect(
		device_as_variant is RefCounted,
		"DC-U01: Device is RefCounted"
	)

	_expect(
		not (device_as_variant is Node),
		"DC-U01: Device is not Node"
	)


func _test_composition() -> void:

	var device := Device.new()

	var identity: DeviceIdentity = (
		device.get_identity()
	)

	var manifest: DeviceManifest = (
		device.get_manifest()
	)

	var state: DeviceState = (
		device.get_state()
	)

	var health: DeviceHealth = (
		device.get_health()
	)

	var lifecycle: DeviceLifecycle = (
		device.get_lifecycle()
	)

	_expect(
		identity != null,
		"DC-U02: Device creates Identity"
	)

	_expect(
		manifest != null,
		"DC-U02: Device creates Manifest"
	)

	_expect(
		state != null,
		"DC-U02: Device creates State"
	)

	_expect(
		health != null,
		"DC-U02: Device creates Health"
	)

	_expect(
		lifecycle != null,
		"DC-U02: Device creates Lifecycle"
	)

	_expect(
		device.get_identity() == identity,
		"DC-U02: Identity instance is stable"
	)

	_expect(
		device.get_manifest() == manifest,
		"DC-U02: Manifest instance is stable"
	)

	_expect(
		device.get_state() == state,
		"DC-U02: State instance is stable"
	)

	_expect(
		device.get_health() == health,
		"DC-U02: Health instance is stable"
	)

	_expect(
		device.get_lifecycle() == lifecycle,
		"DC-U02: Lifecycle instance is stable"
	)


func _test_invalid_identity() -> void:

	var device := Device.new()

	_expect(
		not device.initialize(),
		"DC-U03: invalid Identity blocks initialize"
	)

	_expect(
		device.get_lifecycle().get_state()
		== DeviceLifecycle.State.CREATED,
		"DC-U03: failed initialize preserves CREATED"
	)


func _test_valid_identity() -> void:

	var device := Device.new()

	device.get_identity().device_id = (
		"device_core_test"
	)

	device.get_identity().device_type = (
		"test_device"
	)

	device.get_identity().device_version = 1

	_expect(
		device.initialize(),
		"DC-U04: valid Identity initializes Device"
	)

	_expect(
		device.get_lifecycle().get_state()
		== DeviceLifecycle.State.INITIALIZED,
		"DC-U04: lifecycle becomes INITIALIZED"
	)


func _test_lifecycle_delegation() -> void:

	var device := Device.new()

	device.get_identity().device_id = (
		"lifecycle_test"
	)

	device.get_identity().device_type = (
		"test_device"
	)

	device.initialize()

	_expect(
		device.set_ready(),
		"DC-U05: set_ready delegates successfully"
	)

	_expect(
		device.get_lifecycle().get_state()
		== DeviceLifecycle.State.READY,
		"DC-U05: lifecycle becomes READY"
	)

	_expect(
		device.start(),
		"DC-U05: start delegates successfully"
	)

	_expect(
		device.get_lifecycle().get_state()
		== DeviceLifecycle.State.RUNNING,
		"DC-U05: lifecycle becomes RUNNING"
	)

	_expect(
		device.shutdown(),
		"DC-U05: shutdown delegates successfully"
	)

	_expect(
		device.get_lifecycle().get_state()
		== DeviceLifecycle.State.SHUTDOWN,
		"DC-U05: lifecycle becomes SHUTDOWN"
	)


func _test_bus_independence() -> void:

	var device := Device.new()

	_expect(
		not device.has_method(
			&"publish"
		),
		"DC-U06: Device does not publish"
	)

	_expect(
		not device.has_method(
			&"subscribe"
		),
		"DC-U06: Device does not subscribe"
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
