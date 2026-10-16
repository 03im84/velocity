extends Node


## SteeringRuntimeFactoryTest
##
## Cubre Request/Key/Configuration, tres dependencies BORROWED,
## Handle construct-only y release seguro.


const Helpers = preload(
	"res://test/core/steering/steering_runtime_factory_test_helpers.gd"
)
const MotionSource = preload(
	"res://test/core/steering/steering_test_motion_source.gd"
)
const TorqueSink = preload(
	"res://test/core/steering/steering_test_torque_sink.gd"
)


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("SteeringRuntimeFactoryTest")
	print("========================================")

	_test_request_validation()
	_test_factory_key_and_configuration()
	_test_model_binding()
	_test_motion_source_binding()
	_test_sink_binding()
	_test_successful_build()
	_test_release_contract()
	_test_release_shape_validation()

	_finish()


func _test_request_validation() -> void:

	var factory := SteeringRuntimeFactory.new()
	_expect_code(factory.build(null).get_report(), &"steering_factory_request_missing", "STF-U01: null Request")
	var invalid_request := RuntimeConstructionRequest.new(
		"other",
		Helpers.create_configuration("request_device"),
		Helpers.create_factory_key(),
		[
			Helpers.create_binding(SteeringRuntimeFactory.MODEL_DEPENDENCY_ID, _model()),
			Helpers.create_binding(SteeringRuntimeFactory.MOTION_SOURCE_DEPENDENCY_ID, MotionSource.new()),
			Helpers.create_binding(SteeringRuntimeFactory.SINK_DEPENDENCY_ID, TorqueSink.new()),
		]
	)
	_expect_code(factory.build(invalid_request).get_report(), &"steering_factory_request_invalid", "STF-U01: invalid Request")


func _test_factory_key_and_configuration() -> void:

	var factory := SteeringRuntimeFactory.new()
	var wrong_key := Helpers.create_factory_key(&"velocity.steering.other")
	var wrong_configuration := Helpers.create_configuration(
		"wrong_key",
		["bounded_yaw_torque"],
		[],
		[BusTopics.STEERING_COMMAND],
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"velocity.steering.other"
	)
	_expect_code(
		factory.build(Helpers.create_request("wrong_key", _model(), MotionSource.new(), TorqueSink.new(), RuntimeDependencyBinding.Ownership.BORROWED, RuntimeDependencyBinding.Ownership.BORROWED, RuntimeDependencyBinding.Ownership.BORROWED, wrong_key, wrong_configuration)).get_report(),
		&"steering_factory_key_mismatch",
		"STF-U02: incorrect Factory Key"
	)
	var unsupported := Helpers.create_configuration("unsupported", ["vehicle_control_routing"])
	_expect_code(
		factory.build(Helpers.create_request("unsupported", _model(), MotionSource.new(), TorqueSink.new(), RuntimeDependencyBinding.Ownership.BORROWED, RuntimeDependencyBinding.Ownership.BORROWED, RuntimeDependencyBinding.Ownership.BORROWED, null, unsupported)).get_report(),
		&"steering_factory_configuration_unsupported",
		"STF-U02: unsupported Configuration"
	)


func _test_model_binding() -> void:

	var factory := SteeringRuntimeFactory.new()
	var source := MotionSource.new()
	var sink := TorqueSink.new()
	var bindings: Array[RuntimeDependencyBinding] = [
		Helpers.create_binding(SteeringRuntimeFactory.MOTION_SOURCE_DEPENDENCY_ID, source),
		Helpers.create_binding(SteeringRuntimeFactory.SINK_DEPENDENCY_ID, sink),
	]
	var missing := RuntimeConstructionRequest.new("missing_model", Helpers.create_configuration("missing_model"), Helpers.create_factory_key(), bindings)
	_expect_code(factory.build(missing).get_report(), &"steering_factory_model_missing", "STF-U03: missing model")
	_expect_code(factory.build(Helpers.create_request("transferred_model", _model(), source, sink, RuntimeDependencyBinding.Ownership.TRANSFERRED)).get_report(), &"steering_factory_model_ownership_invalid", "STF-U03: transferred model")
	_expect_code(factory.build(Helpers.create_request("wrong_model", RefCounted.new(), source, sink)).get_report(), &"steering_factory_model_invalid", "STF-U03: wrong model type")
	_expect_code(factory.build(Helpers.create_request("invalid_model", YawSteeringModel.new(-1.0, 1.0, 1.0), source, sink)).get_report(), &"steering_factory_model_invalid", "STF-U03: invalid model")


func _test_motion_source_binding() -> void:

	var factory := SteeringRuntimeFactory.new()
	var model := _model()
	var sink := TorqueSink.new()
	var bindings: Array[RuntimeDependencyBinding] = [
		Helpers.create_binding(SteeringRuntimeFactory.MODEL_DEPENDENCY_ID, model),
		Helpers.create_binding(SteeringRuntimeFactory.SINK_DEPENDENCY_ID, sink),
	]
	var missing := RuntimeConstructionRequest.new("missing_motion", Helpers.create_configuration("missing_motion"), Helpers.create_factory_key(), bindings)
	_expect_code(factory.build(missing).get_report(), &"steering_factory_motion_source_missing", "STF-U04: missing motion source")
	_expect_code(factory.build(Helpers.create_request("transferred_motion", model, MotionSource.new(), sink, RuntimeDependencyBinding.Ownership.BORROWED, RuntimeDependencyBinding.Ownership.TRANSFERRED)).get_report(), &"steering_factory_motion_source_ownership_invalid", "STF-U04: transferred motion source")
	_expect_code(factory.build(Helpers.create_request("invalid_motion", model, RefCounted.new(), sink)).get_report(), &"steering_factory_motion_source_invalid", "STF-U04: invalid motion source")


func _test_sink_binding() -> void:

	var factory := SteeringRuntimeFactory.new()
	var model := _model()
	var source := MotionSource.new()
	var bindings: Array[RuntimeDependencyBinding] = [
		Helpers.create_binding(SteeringRuntimeFactory.MODEL_DEPENDENCY_ID, model),
		Helpers.create_binding(SteeringRuntimeFactory.MOTION_SOURCE_DEPENDENCY_ID, source),
	]
	var missing := RuntimeConstructionRequest.new("missing_sink", Helpers.create_configuration("missing_sink"), Helpers.create_factory_key(), bindings)
	_expect_code(factory.build(missing).get_report(), &"steering_factory_sink_missing", "STF-U05: missing sink")
	_expect_code(factory.build(Helpers.create_request("transferred_sink", model, source, TorqueSink.new(), RuntimeDependencyBinding.Ownership.BORROWED, RuntimeDependencyBinding.Ownership.BORROWED, RuntimeDependencyBinding.Ownership.TRANSFERRED)).get_report(), &"steering_factory_sink_ownership_invalid", "STF-U05: transferred sink")
	_expect_code(factory.build(Helpers.create_request("invalid_sink", model, source, RefCounted.new())).get_report(), &"steering_factory_sink_invalid", "STF-U05: invalid sink")


func _test_successful_build() -> void:

	var factory := SteeringRuntimeFactory.new()
	var model := _model()
	var source := MotionSource.new()
	var sink := TorqueSink.new()
	var result := factory.build(Helpers.create_request("built", model, source, sink))
	var handle := result.get_handle()
	_expect(result.is_success() and result.get_report().is_empty(), "STF-U06: exact Request builds")
	_expect(handle != null and handle.is_valid() and handle.get_device_id() == "built", "STF-U06: valid Handle")
	_expect(handle.get_primary_runtime_object() is SteeringRuntimeUnit, "STF-U06: exact Primary")
	_expect(handle.get_host_objects().is_empty(), "STF-U06: zero Host Objects")
	_expect(
		handle.get_dependency_binding(SteeringRuntimeFactory.MODEL_DEPENDENCY_ID).get_value() == model
		and handle.get_dependency_binding(SteeringRuntimeFactory.MOTION_SOURCE_DEPENDENCY_ID).get_value() == source
		and handle.get_dependency_binding(SteeringRuntimeFactory.SINK_DEPENDENCY_ID).get_value() == sink,
		"STF-U06: exact dependencies preserved"
	)
	var unit: SteeringRuntimeUnit = handle.get_primary_runtime_object()
	_expect(unit.get_state() == SteeringRuntimeUnit.State.CREATED and not unit.has_actuation_result() and sink.apply_count == 0, "STF-U06: build executes no lifecycle or actuation")


func _test_release_contract() -> void:

	var factory := SteeringRuntimeFactory.new()
	var model := _model()
	var source := MotionSource.new()
	var sink := TorqueSink.new()
	var handle := factory.build(Helpers.create_request("release", model, source, sink)).get_handle()
	_expect_code(factory.release(null), &"steering_factory_handle_invalid", "STF-U07: null Handle")
	_expect(factory.release(handle).is_empty(), "STF-U07: CREATED release")
	_expect(is_instance_valid(model) and is_instance_valid(source) and is_instance_valid(sink), "STF-U07: BORROWED dependencies survive")
	_expect(factory.release(handle).is_empty(), "STF-U07: repeated release idempotent")
	var active_factory := SteeringRuntimeFactory.new()
	var active_handle := active_factory.build(Helpers.create_request("active", _model(), MotionSource.new(), TorqueSink.new())).get_handle()
	var active: SteeringRuntimeUnit = active_handle.get_primary_runtime_object()
	active.runtime_initialize(DeviceBus.new())
	_expect_code(active_factory.release(active_handle), &"steering_factory_release_active", "STF-U07: active release rejected")
	_expect(active.runtime_shutdown().is_empty() and active_factory.release(active_handle).is_empty(), "STF-U07: SHUTDOWN release")


func _test_release_shape_validation() -> void:

	var factory := SteeringRuntimeFactory.new()
	var model := _model()
	var source := MotionSource.new()
	var sink := TorqueSink.new()
	var bindings: Array[RuntimeDependencyBinding] = [
		Helpers.create_binding(SteeringRuntimeFactory.MODEL_DEPENDENCY_ID, model),
		Helpers.create_binding(SteeringRuntimeFactory.MOTION_SOURCE_DEPENDENCY_ID, source),
		Helpers.create_binding(SteeringRuntimeFactory.SINK_DEPENDENCY_ID, sink),
	]
	var config := Helpers.create_configuration("shape")
	var empty_hosts: Array[Object] = []
	var primary_bad := RuntimeDeviceHandle.new("shape", config, Helpers.create_factory_key(), RefCounted.new(), empty_hosts, bindings)
	_expect_code(factory.release(primary_bad), &"steering_factory_primary_mismatch", "STF-U08: wrong Primary")
	var unit := SteeringRuntimeUnit.new("shape", config, model, source, sink)
	var host := Node.new()
	var hosts: Array[Object] = [host]
	var host_bad := RuntimeDeviceHandle.new("shape", config, Helpers.create_factory_key(), unit, hosts, bindings)
	_expect_code(factory.release(host_bad), &"steering_factory_host_mismatch", "STF-U08: unexpected Host")
	host.free()


func _model() -> YawSteeringModel:
	return YawSteeringModel.new(100.0, 10.0, 2.0)

func _expect_code(report: ValidationReport, code: StringName, description: String) -> void:
	_expect(Helpers.report_has_code(report, code), description + " reports " + String(code))

func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] ", description)
	else:
		_failures += 1
		push_error("[FAIL] " + description)

func _finish() -> void:
	print("Checks: ", _checks)
	print("Failures: ", _failures)
	print("RESULT: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(_failures)
