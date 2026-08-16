extends Node


##
## DeviceIdentityTest
##
## Verifica la identidad mínima requerida
## para inicializar un Device.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceIdentityTest")
	print("========================================")

	_test_initial_identity()
	_test_id_without_type()
	_test_type_without_id()
	_test_invalid_version()
	_test_complete_identity()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_initial_identity() -> void:

	var identity := DeviceIdentity.new()

	_expect(
		identity.device_id.is_empty(),
		"DI-U01: initial device_id is empty"
	)

	_expect(
		identity.device_type.is_empty(),
		"DI-U01: initial device_type is empty"
	)

	_expect(
		identity.device_version == 1,
		"DI-U01: initial version is one"
	)

	_expect(
		not identity.is_valid(),
		"DI-U01: initial identity is invalid"
	)


func _test_id_without_type() -> void:

	var identity := DeviceIdentity.new()

	identity.device_id = "device_a"

	_expect(
		not identity.is_valid(),
		"DI-U02: ID without type is invalid"
	)


func _test_type_without_id() -> void:

	var identity := DeviceIdentity.new()

	identity.device_type = "distance_sensor"

	_expect(
		not identity.is_valid(),
		"DI-U03: type without ID is invalid"
	)


func _test_invalid_version() -> void:

	var identity := DeviceIdentity.new()

	identity.device_id = "device_a"
	identity.device_type = "distance_sensor"
	identity.device_version = 0

	_expect(
		not identity.is_valid(),
		"DI-U04: version zero is invalid"
	)


func _test_complete_identity() -> void:

	var identity := DeviceIdentity.new()

	identity.device_id = "device_a"
	identity.device_type = "distance_sensor"
	identity.device_version = 2

	_expect(
		identity.is_valid(),
		"DI-U05: complete identity is valid"
	)

	_expect(
		identity.get_device_id() == "device_a",
		"DI-U05: get_device_id preserves ID"
	)

	_expect(
		identity.get_device_type()
		== "distance_sensor",
		"DI-U05: get_device_type preserves type"
	)

	_expect(
		identity.get_device_version() == 2,
		"DI-U05: get_device_version preserves version"
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
