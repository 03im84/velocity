extends Node


## ProximityLiftPointRuntimeFactoryTest
##
## Cubre Request/Key/Configuration, dependencias BORROWED,
## forma del Handle, build construct-only y release seguro.


const Helpers = preload(
	"res://test/core/proximity_lift/proximity_lift_point_runtime_factory_test_helpers.gd"
)
const ForceSink = preload(
	"res://test/core/proximity_lift/proximity_lift_test_force_sink.gd"
)


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("ProximityLiftPointRuntimeFactoryTest")
	print("========================================")

	_test_request_validation()
	_test_factory_key_and_configuration()
	_test_model_binding()
	_test_sink_binding()
	_test_successful_build()
	_test_release_contract()
	_test_release_shape_validation()

	_finish()


func _test_request_validation() -> void:

	var factory := ProximityLiftPointRuntimeFactory.new()

	_expect_code(
		factory.build(null).get_report(),
		&"proximity_lift_factory_request_missing",
		"PLF-U01: null Request"
	)

	var model := _model()
	var sink := ForceSink.new()
	var invalid_request := RuntimeConstructionRequest.new(
		"other_device",
		Helpers.create_configuration("request_device"),
		Helpers.create_factory_key(),
		[
			Helpers.create_binding(
				ProximityLiftPointRuntimeFactory.MODEL_DEPENDENCY_ID,
				model
			),
			Helpers.create_binding(
				ProximityLiftPointRuntimeFactory.SINK_DEPENDENCY_ID,
				sink
			),
		]
	)

	_expect_code(
		factory.build(invalid_request).get_report(),
		&"proximity_lift_factory_request_invalid",
		"PLF-U01: invalid Request"
	)


func _test_factory_key_and_configuration() -> void:

	var factory := ProximityLiftPointRuntimeFactory.new()
	var model := _model()
	var sink := ForceSink.new()
	var wrong_key := Helpers.create_factory_key(
		&"velocity.proximity_lift.central_controller"
	)
	var wrong_key_configuration := Helpers.create_configuration(
		"wrong_key_device",
		["proximity_lift_force"],
		[],
		[BusTopics.DISTANCE_MEASUREMENT],
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"velocity.proximity_lift.central_controller"
	)

	_expect_code(
		factory.build(
			Helpers.create_request(
				"wrong_key_device",
				model,
				sink,
				RuntimeDependencyBinding.Ownership.BORROWED,
				RuntimeDependencyBinding.Ownership.BORROWED,
				wrong_key,
				wrong_key_configuration
			)
		).get_report(),
		&"proximity_lift_factory_key_mismatch",
		"PLF-U02: incorrect Factory Key"
	)

	var unsupported_capabilities: Array[String] = [
		"central_proximity_lift_controller",
	]
	var unsupported_configuration := Helpers.create_configuration(
		"unsupported_device",
		unsupported_capabilities
	)

	_expect_code(
		factory.build(
			Helpers.create_request(
				"unsupported_device",
				model,
				sink,
				RuntimeDependencyBinding.Ownership.BORROWED,
				RuntimeDependencyBinding.Ownership.BORROWED,
				null,
				unsupported_configuration
			)
		).get_report(),
		&"proximity_lift_factory_configuration_unsupported",
		"PLF-U02: unsupported Configuration"
	)


func _test_model_binding() -> void:

	var factory := ProximityLiftPointRuntimeFactory.new()
	var sink := ForceSink.new()
	var sink_only_bindings: Array[RuntimeDependencyBinding] = [
		Helpers.create_binding(
			ProximityLiftPointRuntimeFactory.SINK_DEPENDENCY_ID,
			sink
		),
	]
	var missing_request := RuntimeConstructionRequest.new(
		"missing_model",
		Helpers.create_configuration("missing_model"),
		Helpers.create_factory_key(),
		sink_only_bindings
	)

	_expect_code(
		factory.build(missing_request).get_report(),
		&"proximity_lift_factory_model_missing",
		"PLF-U03: missing model Binding"
	)
	_expect_code(
		factory.build(
			Helpers.create_request(
				"transferred_model",
				_model(),
				sink,
				RuntimeDependencyBinding.Ownership.TRANSFERRED
			)
		).get_report(),
		&"proximity_lift_factory_model_ownership_invalid",
		"PLF-U03: TRANSFERRED model rejected"
	)
	_expect_code(
		factory.build(
			Helpers.create_request(
				"wrong_model_type",
				RefCounted.new(),
				sink
			)
		).get_report(),
		&"proximity_lift_factory_model_invalid",
		"PLF-U03: incorrect model type"
	)
	_expect_code(
		factory.build(
			Helpers.create_request(
				"invalid_model",
				ProximityLiftModel.new(0.0, 1.0, 1.0),
				sink
			)
		).get_report(),
		&"proximity_lift_factory_model_invalid",
		"PLF-U03: invalid model rejected"
	)


func _test_sink_binding() -> void:

	var factory := ProximityLiftPointRuntimeFactory.new()
	var model := _model()
	var model_only_bindings: Array[RuntimeDependencyBinding] = [
		Helpers.create_binding(
			ProximityLiftPointRuntimeFactory.MODEL_DEPENDENCY_ID,
			model
		),
	]
	var missing_request := RuntimeConstructionRequest.new(
		"missing_sink",
		Helpers.create_configuration("missing_sink"),
		Helpers.create_factory_key(),
		model_only_bindings
	)

	_expect_code(
		factory.build(missing_request).get_report(),
		&"proximity_lift_factory_sink_missing",
		"PLF-U04: missing sink Binding"
	)
	_expect_code(
		factory.build(
			Helpers.create_request(
				"transferred_sink",
				model,
				ForceSink.new(),
				RuntimeDependencyBinding.Ownership.BORROWED,
				RuntimeDependencyBinding.Ownership.TRANSFERRED
			)
		).get_report(),
		&"proximity_lift_factory_sink_ownership_invalid",
		"PLF-U04: TRANSFERRED sink rejected"
	)
	_expect_code(
		factory.build(
			Helpers.create_request(
				"invalid_sink",
				model,
				RefCounted.new()
			)
		).get_report(),
		&"proximity_lift_factory_sink_invalid",
		"PLF-U04: incomplete sink behavior"
	)


func _test_successful_build() -> void:

	var factory := ProximityLiftPointRuntimeFactory.new()
	var model := _model()
	var sink := ForceSink.new()
	var result := factory.build(
		Helpers.create_request("built_device", model, sink)
	)
	var handle := result.get_handle()

	_expect(
		result.is_success() and result.get_report().is_empty(),
		"PLF-U05: exact Request builds successfully"
	)
	_expect(
		handle != null
		and handle.is_valid()
		and handle.get_device_id() == "built_device",
		"PLF-U05: Factory returns valid exact Handle"
	)
	_expect(
		handle.get_primary_runtime_object()
		is ProximityLiftPointRuntimeUnit,
		"PLF-U05: Primary is ProximityLiftPointRuntimeUnit"
	)
	_expect(
		handle.get_host_objects().is_empty(),
		"PLF-U05: Handle contains no Host Objects"
	)
	_expect(
		handle.get_dependency_binding(
			ProximityLiftPointRuntimeFactory.MODEL_DEPENDENCY_ID
		).get_value() == model
		and handle.get_dependency_binding(
			ProximityLiftPointRuntimeFactory.MODEL_DEPENDENCY_ID
		).is_borrowed()
		and handle.get_dependency_binding(
			ProximityLiftPointRuntimeFactory.SINK_DEPENDENCY_ID
		).get_value() == sink
		and handle.get_dependency_binding(
			ProximityLiftPointRuntimeFactory.SINK_DEPENDENCY_ID
		).is_borrowed(),
		"PLF-U05: Handle preserves exact BORROWED dependencies"
	)

	var unit: ProximityLiftPointRuntimeUnit = (
		handle.get_primary_runtime_object()
	)

	_expect(
		unit.get_state() == ProximityLiftPointRuntimeUnit.State.CREATED
		and not unit.has_actuation_result()
		and sink.apply_count == 0,
		"PLF-U05: build executes no lifecycle or actuation"
	)


func _test_release_contract() -> void:

	var factory := ProximityLiftPointRuntimeFactory.new()
	var model := _model()
	var sink := ForceSink.new()
	var result := factory.build(
		Helpers.create_request("release_device", model, sink)
	)
	var handle := result.get_handle()

	_expect_code(
		factory.release(null),
		&"proximity_lift_factory_handle_invalid",
		"PLF-U06: null Handle"
	)
	_expect(
		factory.release(handle).is_empty(),
		"PLF-U06: CREATED Handle release succeeds"
	)
	_expect(
		is_instance_valid(model)
		and is_instance_valid(sink),
		"PLF-U06: release preserves BORROWED dependencies"
	)
	_expect(
		factory.release(handle).is_empty(),
		"PLF-U06: repeated release is idempotent"
	)

	var active_factory := ProximityLiftPointRuntimeFactory.new()
	var active_result := active_factory.build(
		Helpers.create_request(
			"active_device",
			_model(),
			ForceSink.new()
		)
	)
	var active_handle := active_result.get_handle()
	var active_unit: ProximityLiftPointRuntimeUnit = (
		active_handle.get_primary_runtime_object()
	)
	active_unit.runtime_initialize(DeviceBus.new())

	_expect_code(
		active_factory.release(active_handle),
		&"proximity_lift_factory_release_active",
		"PLF-U06: active Unit release rejected"
	)
	_expect(
		active_unit.runtime_shutdown().is_empty()
		and active_factory.release(active_handle).is_empty(),
		"PLF-U06: SHUTDOWN Unit release succeeds"
	)


func _test_release_shape_validation() -> void:

	var factory := ProximityLiftPointRuntimeFactory.new()
	var model := _model()
	var sink := ForceSink.new()
	var bindings: Array[RuntimeDependencyBinding] = [
		Helpers.create_binding(
			ProximityLiftPointRuntimeFactory.MODEL_DEPENDENCY_ID,
			model
		),
		Helpers.create_binding(
			ProximityLiftPointRuntimeFactory.SINK_DEPENDENCY_ID,
			sink
		),
	]
	var configuration := Helpers.create_configuration(
		"shape_device"
	)
	var empty_hosts: Array[Object] = []
	var primary_mismatch := RuntimeDeviceHandle.new(
		"shape_device",
		configuration,
		Helpers.create_factory_key(),
		RefCounted.new(),
		empty_hosts,
		bindings
	)

	_expect_code(
		factory.release(primary_mismatch),
		&"proximity_lift_factory_primary_mismatch",
		"PLF-U07: incorrect Primary rejected"
	)

	var unit := ProximityLiftPointRuntimeUnit.new(
		"shape_device",
		configuration,
		model,
		sink
	)
	var unexpected_host := Node.new()
	var hosts: Array[Object] = [unexpected_host]
	var host_mismatch := RuntimeDeviceHandle.new(
		"shape_device",
		configuration,
		Helpers.create_factory_key(),
		unit,
		hosts,
		bindings
	)

	_expect_code(
		factory.release(host_mismatch),
		&"proximity_lift_factory_host_mismatch",
		"PLF-U07: unexpected Host Object rejected"
	)

	unexpected_host.free()


func _model() -> ProximityLiftModel:

	return ProximityLiftModel.new(2.0, 4000.0, 2.0)


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
