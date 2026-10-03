extends Node


const Helpers = preload(
	"res://test/core/runtime/distance_sensor_runtime_test_helpers.gd"
)


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DistanceSensorRuntimeFactoryTest")
	print("========================================")

	_test_request_validation()
	_test_configuration_and_ownership()
	_test_provider_behavior()
	_test_successful_build()
	_test_release_contract()

	_finish()


func _test_request_validation() -> void:

	var factory := DistanceSensorRuntimeFactory.new()

	_expect_code(
		factory.build(null).get_report(),
		&"distance_sensor_factory_request_missing",
		"DSRF-U01: null Request"
	)

	var bindings: Array[RuntimeDependencyBinding] = []
	var missing_binding_request := RuntimeConstructionRequest.new(
		"sensor",
		Helpers.create_configuration("sensor"),
		RuntimeFactoryKey.new(
			DistanceSensorRuntimeFactory.PROFILE_ID,
			DistanceSensorRuntimeFactory.PROFILE_VERSION,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		bindings
	)

	_expect_code(
		factory.build(missing_binding_request).get_report(),
		&"distance_sensor_factory_provider_missing",
		"DSRF-U01: missing Provider Binding"
	)


func _test_configuration_and_ownership() -> void:

	var factory := DistanceSensorRuntimeFactory.new()
	var provider := ManualDistanceProvider.new()
	var health_request := Helpers.create_request(
		"health_sensor",
		provider,
		true
	)

	_expect_code(
		factory.build(health_request).get_report(),
		&"distance_sensor_factory_configuration_unsupported",
		"DSRF-U02: unsupported health Configuration"
	)

	var transferred_request := Helpers.create_request(
		"transferred_sensor",
		provider,
		false,
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	_expect_code(
		factory.build(transferred_request).get_report(),
		&"distance_sensor_factory_provider_ownership_invalid",
		"DSRF-U02: TRANSFERRED Provider"
	)


func _test_provider_behavior() -> void:

	var factory := DistanceSensorRuntimeFactory.new()
	var invalid_provider := RefCounted.new()
	var request := Helpers.create_request(
		"invalid_provider_sensor",
		invalid_provider
	)

	_expect_code(
		factory.build(request).get_report(),
		&"distance_sensor_factory_provider_invalid",
		"DSRF-U03: invalid Provider behavior"
	)


func _test_successful_build() -> void:

	var factory := DistanceSensorRuntimeFactory.new()
	var provider := ManualDistanceProvider.new()
	var request := Helpers.create_request(
		"built_sensor",
		provider
	)
	var result := factory.build(request)
	var handle := result.get_handle()

	_expect(
		result.is_success()
		and result.get_report().is_empty(),
		"DSRF-U04: supported Request builds successfully"
	)
	_expect(
		handle != null
		and handle.is_valid()
		and handle.get_device_id() == "built_sensor",
		"DSRF-U04: Factory returns valid exact Handle"
	)
	_expect(
		handle.get_primary_runtime_object()
		is DistanceSensorRuntimeUnit,
		"DSRF-U04: Primary is DistanceSensorRuntimeUnit"
	)
	_expect(
		handle.get_host_objects().size() == 1
		and handle.get_host_objects()[0]
		is DistanceSensorDevice,
		"DSRF-U04: Handle contains one DistanceSensorDevice Host Object"
	)
	_expect(
		handle.get_dependency_binding(
			DistanceSensorRuntimeFactory.DEPENDENCY_ID
		).is_borrowed(),
		"DSRF-U04: Handle preserves BORROWED Provider Binding"
	)

	var unit: DistanceSensorRuntimeUnit = (
		handle.get_primary_runtime_object()
	)

	_expect(
		unit.get_state() == DistanceSensorRuntimeUnit.State.CREATED
		and unit.get_sensor().device == null
		and unit.get_sensor().get_parent() == null,
		"DSRF-U04: build does not attach or execute lifecycle"
	)

	factory.release(handle)


func _test_release_contract() -> void:

	var factory := DistanceSensorRuntimeFactory.new()
	var provider := ManualDistanceProvider.new()
	var result := factory.build(
		Helpers.create_request("release_sensor", provider)
	)
	var handle := result.get_handle()
	var unit: DistanceSensorRuntimeUnit = (
		handle.get_primary_runtime_object()
	)
	var sensor := unit.get_sensor()

	add_child(sensor)

	_expect_code(
		factory.release(handle),
		&"distance_sensor_factory_release_still_attached",
		"DSRF-U05: release while attached"
	)
	_expect(
		is_instance_valid(sensor),
		"DSRF-U05: rejected release preserves Sensor"
	)

	remove_child(sensor)

	_expect(
		factory.release(handle).is_valid_for_simulation()
		and not is_instance_valid(sensor),
		"DSRF-U05: detached release frees Sensor"
	)
	_expect(
		is_instance_valid(provider),
		"DSRF-U05: release preserves BORROWED Provider"
	)
	_expect(
		factory.release(handle).is_valid_for_simulation(),
		"DSRF-U05: repeated release is idempotent"
	)


func _expect_code(
	report: ValidationReport,
	code: StringName,
	description: String
) -> void:

	_expect(
		Helpers.report_has_code(report, code),
		description + " reports " + String(code)
	)


func _expect(condition: bool, description: String) -> void:

	_checks += 1
	if condition:
		print("[PASS] ", description)
		return
	_failures += 1
	push_error("[FAIL] " + description)


func _finish() -> void:

	print("----------------------------------------")
	print("Checks: ", _checks)
	print("Failures: ", _failures)
	if _failures == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")
	print("========================================")
	print("")
	get_tree().quit(_failures)
