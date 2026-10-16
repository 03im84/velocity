extends Node


## VehicleControlRouterRuntimeFactoryTest
##
## Cubre Request/Key/Configuration, policy BORROWED, Handle shape,
## construct-only build y release seguro.


const Helpers = preload(
	"res://test/core/vehicle_control/vehicle_control_router_runtime_factory_test_helpers.gd"
)


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("VehicleControlRouterRuntimeFactoryTest")
	print("========================================")

	_test_request_validation()
	_test_factory_key_and_configuration()
	_test_policy_binding()
	_test_successful_build()
	_test_release_contract()
	_test_release_shape_validation()

	_finish()


func _test_request_validation() -> void:

	var factory := VehicleControlRouterRuntimeFactory.new()

	_expect_code(
		factory.build(null).get_report(),
		&"vehicle_control_router_factory_request_missing",
		"VCF-U01: null Request"
	)

	var policy := PropulsionIntentPolicy.new()
	var invalid_request := RuntimeConstructionRequest.new(
		"other_device",
		Helpers.create_configuration("request_device"),
		Helpers.create_factory_key(),
		[Helpers.create_binding(policy)]
	)

	_expect_code(
		factory.build(invalid_request).get_report(),
		&"vehicle_control_router_factory_request_invalid",
		"VCF-U01: invalid Request"
	)


func _test_factory_key_and_configuration() -> void:

	var factory := VehicleControlRouterRuntimeFactory.new()
	var policy := PropulsionIntentPolicy.new()
	var wrong_key := Helpers.create_factory_key(
		&"velocity.vehicle_control.other"
	)
	var wrong_configuration := Helpers.create_configuration(
		"wrong_key_device",
		["vehicle_control_routing"],
		[
			BusTopics.PROPULSION_COMMAND,
			BusTopics.STEERING_COMMAND,
			BusTopics.BRAKE_COMMAND,
		],
		[BusTopics.VEHICLE_CONTROL_COMMAND],
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"velocity.vehicle_control.other"
	)

	_expect_code(
		factory.build(
			Helpers.create_request(
				"wrong_key_device",
				policy,
				RuntimeDependencyBinding.Ownership.BORROWED,
				wrong_key,
				wrong_configuration
			)
		).get_report(),
		&"vehicle_control_router_factory_key_mismatch",
		"VCF-U02: incorrect Factory Key"
	)

	var unsupported_configuration := Helpers.create_configuration(
		"unsupported_device",
		["vehicle_physics"]
	)

	_expect_code(
		factory.build(
			Helpers.create_request(
				"unsupported_device",
				policy,
				RuntimeDependencyBinding.Ownership.BORROWED,
				null,
				unsupported_configuration
			)
		).get_report(),
		&"vehicle_control_router_factory_configuration_unsupported",
		"VCF-U02: unsupported Configuration"
	)


func _test_policy_binding() -> void:

	var factory := VehicleControlRouterRuntimeFactory.new()
	var empty_bindings: Array[RuntimeDependencyBinding] = []
	var missing_request := RuntimeConstructionRequest.new(
		"missing_policy",
		Helpers.create_configuration("missing_policy"),
		Helpers.create_factory_key(),
		empty_bindings
	)

	_expect_code(
		factory.build(missing_request).get_report(),
		&"vehicle_control_router_factory_policy_missing",
		"VCF-U03: missing policy Binding"
	)
	_expect_code(
		factory.build(
			Helpers.create_request(
				"transferred_policy",
				PropulsionIntentPolicy.new(),
				RuntimeDependencyBinding.Ownership.TRANSFERRED
			)
		).get_report(),
		&"vehicle_control_router_factory_policy_ownership_invalid",
		"VCF-U03: TRANSFERRED policy rejected"
	)
	_expect_code(
		factory.build(
			Helpers.create_request(
				"wrong_policy_type",
				RefCounted.new()
			)
		).get_report(),
		&"vehicle_control_router_factory_policy_invalid",
		"VCF-U03: incorrect policy type"
	)


func _test_successful_build() -> void:

	var factory := VehicleControlRouterRuntimeFactory.new()
	var policy := PropulsionIntentPolicy.new()
	var result := factory.build(
		Helpers.create_request("built_router", policy)
	)
	var handle := result.get_handle()

	_expect(
		result.is_success() and result.get_report().is_empty(),
		"VCF-U04: exact Request builds successfully"
	)
	_expect(
		handle != null
		and handle.is_valid()
		and handle.get_device_id() == "built_router",
		"VCF-U04: Factory returns valid exact Handle"
	)
	_expect(
		handle.get_primary_runtime_object()
		is VehicleControlRouterRuntimeUnit,
		"VCF-U04: Primary is VehicleControlRouterRuntimeUnit"
	)
	_expect(
		handle.get_host_objects().is_empty(),
		"VCF-U04: Handle contains no Host Objects"
	)
	_expect(
		handle.get_dependency_binding(
			VehicleControlRouterRuntimeFactory.POLICY_DEPENDENCY_ID
		).get_value() == policy
		and handle.get_dependency_binding(
			VehicleControlRouterRuntimeFactory.POLICY_DEPENDENCY_ID
		).is_borrowed(),
		"VCF-U04: Handle preserves exact BORROWED policy"
	)

	var unit: VehicleControlRouterRuntimeUnit = (
		handle.get_primary_runtime_object()
	)

	_expect(
		unit.get_state() == VehicleControlRouterRuntimeUnit.State.CREATED
		and not unit.has_routing_result(),
		"VCF-U04: build executes no lifecycle or routing"
	)


func _test_release_contract() -> void:

	var factory := VehicleControlRouterRuntimeFactory.new()
	var policy := PropulsionIntentPolicy.new()
	var result := factory.build(
		Helpers.create_request("release_router", policy)
	)
	var handle := result.get_handle()

	_expect_code(
		factory.release(null),
		&"vehicle_control_router_factory_handle_invalid",
		"VCF-U05: null Handle"
	)
	_expect(
		factory.release(handle).is_empty(),
		"VCF-U05: CREATED Handle release succeeds"
	)
	_expect(
		is_instance_valid(policy),
		"VCF-U05: release preserves BORROWED policy"
	)
	_expect(
		factory.release(handle).is_empty(),
		"VCF-U05: repeated release is idempotent"
	)

	var active_factory := VehicleControlRouterRuntimeFactory.new()
	var active_result := active_factory.build(
		Helpers.create_request(
			"active_router",
			PropulsionIntentPolicy.new()
		)
	)
	var active_handle := active_result.get_handle()
	var active_unit: VehicleControlRouterRuntimeUnit = (
		active_handle.get_primary_runtime_object()
	)
	active_unit.runtime_initialize(DeviceBus.new())

	_expect_code(
		active_factory.release(active_handle),
		&"vehicle_control_router_factory_release_active",
		"VCF-U05: active Unit release rejected"
	)
	_expect(
		active_unit.runtime_shutdown().is_empty()
		and active_factory.release(active_handle).is_empty(),
		"VCF-U05: SHUTDOWN Unit release succeeds"
	)


func _test_release_shape_validation() -> void:

	var factory := VehicleControlRouterRuntimeFactory.new()
	var policy := PropulsionIntentPolicy.new()
	var bindings: Array[RuntimeDependencyBinding] = [
		Helpers.create_binding(policy),
	]
	var configuration := Helpers.create_configuration("shape_router")
	var empty_hosts: Array[Object] = []
	var primary_mismatch := RuntimeDeviceHandle.new(
		"shape_router",
		configuration,
		Helpers.create_factory_key(),
		RefCounted.new(),
		empty_hosts,
		bindings
	)

	_expect_code(
		factory.release(primary_mismatch),
		&"vehicle_control_router_factory_primary_mismatch",
		"VCF-U06: incorrect Primary rejected"
	)

	var unit := VehicleControlRouterRuntimeUnit.new(
		"shape_router",
		configuration,
		policy
	)
	var unexpected_host := Node.new()
	var hosts: Array[Object] = [unexpected_host]
	var host_mismatch := RuntimeDeviceHandle.new(
		"shape_router",
		configuration,
		Helpers.create_factory_key(),
		unit,
		hosts,
		bindings
	)

	_expect_code(
		factory.release(host_mismatch),
		&"vehicle_control_router_factory_host_mismatch",
		"VCF-U06: unexpected Host Object rejected"
	)

	unexpected_host.free()


func _expect_code(
	report: ValidationReport,
	code: StringName,
	description: String
) -> void:

	_expect(
		Helpers.report_has_code(report, code),
		description + " reports " + String(code)
	)


func _expect(
	condition: bool,
	description: String
) -> void:

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
