extends Node


##
## InvalidDistanceProviderTest
##
## Verifica que DistanceSensorDevice rechace
## dependencias nulas y Providers que no
## satisfacen el contrato completo.
##


class ProviderWithoutContract:

	extends RefCounted


class ProviderWithDistanceOnly:

	extends RefCounted

	func get_distance() -> float:

		return 10.0


class ProviderWithValidityOnly:

	extends RefCounted

	func is_valid() -> bool:

		return true


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("InvalidDistanceProviderTest")
	print("========================================")

	_test_null_provider()
	_test_null_bus()
	_test_provider_without_contract()
	_test_provider_with_distance_only()
	_test_provider_with_validity_only()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_null_provider() -> void:

	var sensor := _create_sensor()

	var initialized: bool = (
		sensor.initialize_sensor(
			"null_provider_test",
			DeviceBus.new(),
			null
		)
	)

	_verify_rejected_initialization(
		sensor,
		initialized,
		"IDP-U01: null Provider"
	)


func _test_null_bus() -> void:

	var sensor := _create_sensor()

	var provider := ManualDistanceProvider.new()

	var initialized: bool = (
		sensor.initialize_sensor(
			"null_bus_test",
			null,
			provider
		)
	)

	_verify_rejected_initialization(
		sensor,
		initialized,
		"IDP-U02: null DeviceBus"
	)


func _test_provider_without_contract() -> void:

	var sensor := _create_sensor()

	var provider := ProviderWithoutContract.new()

	var initialized: bool = (
		sensor.initialize_sensor(
			"no_contract_test",
			DeviceBus.new(),
			provider
		)
	)

	_verify_rejected_initialization(
		sensor,
		initialized,
		"IDP-U03: Provider without contract"
	)


func _test_provider_with_distance_only() -> void:

	var sensor := _create_sensor()

	var provider := ProviderWithDistanceOnly.new()

	var initialized: bool = (
		sensor.initialize_sensor(
			"distance_only_test",
			DeviceBus.new(),
			provider
		)
	)

	_verify_rejected_initialization(
		sensor,
		initialized,
		"IDP-U04: Provider with distance only"
	)


func _test_provider_with_validity_only() -> void:

	var sensor := _create_sensor()

	var provider := ProviderWithValidityOnly.new()

	var initialized: bool = (
		sensor.initialize_sensor(
			"validity_only_test",
			DeviceBus.new(),
			provider
		)
	)

	_verify_rejected_initialization(
		sensor,
		initialized,
		"IDP-U05: Provider with validity only"
	)


# =============================================================================
# TEST HELPERS
# =============================================================================

func _create_sensor() -> DistanceSensorDevice:

	var sensor := DistanceSensorDevice.new()

	add_child(sensor)

	return sensor


func _verify_rejected_initialization(
	sensor: DistanceSensorDevice,
	initialized: bool,
	test_name: String
) -> void:

	_expect(
		not initialized,
		test_name + " returns false"
	)

	_expect(
		sensor.device == null,
		test_name + " creates no Device"
	)

	_expect(
		sensor.device_bus == null,
		test_name + " stores no DeviceBus"
	)

	_expect(
		sensor.distance_provider == null,
		test_name + " stores no Provider"
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
