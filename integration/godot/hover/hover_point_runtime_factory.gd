extends RefCounted
class_name HoverPointRuntimeFactory


## HoverPointRuntimeFactory
##
## Construct-only RuntimeFactory para Hover Point Simulation.
## Produce un HoverPointRuntimeUnit sin Host Objects y conserva
## model y force sink como dependencias BORROWED.
## ADR-016 / Hover Physics Slice Design 1.0.


const PROFILE_ID: StringName = &"velocity.hover.spring_damper_point"
const PROFILE_VERSION: int = 1
const MODEL_DEPENDENCY_ID: StringName = &"hover_model"
const SINK_DEPENDENCY_ID: StringName = &"hover_force_sink"


var _released_handle_ids: Dictionary[int, bool] = {}


func build(
	request: RuntimeConstructionRequest
) -> RuntimeFactoryBuildResult:

	var report := ValidationReport.new()

	if request == null:
		_add_error(
			report,
			&"hover_factory_request_missing",
			"RuntimeConstructionRequest is required.",
			"",
			&"request"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not request.is_valid():
		_add_error(
			report,
			&"hover_factory_request_invalid",
			"RuntimeConstructionRequest is invalid.",
			request.get_device_id(),
			&"request"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not _key_is_supported(request.get_factory_key()):
		_add_error(
			report,
			&"hover_factory_key_mismatch",
			"RuntimeFactoryKey is not supported.",
			request.get_device_id(),
			&"factory_key"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not _configuration_is_supported(
		request.get_configuration()
	):
		_add_error(
			report,
			&"hover_factory_configuration_unsupported",
			"DeviceConfiguration enables unsupported behavior.",
			request.get_device_id(),
			&"configuration"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var model_binding := request.get_dependency_binding(
		MODEL_DEPENDENCY_ID
	)

	if model_binding == null:
		_add_error(
			report,
			&"hover_factory_model_missing",
			"hover_model Binding is required.",
			request.get_device_id(),
			MODEL_DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not model_binding.is_borrowed():
		_add_error(
			report,
			&"hover_factory_model_ownership_invalid",
			"hover_model must be BORROWED.",
			request.get_device_id(),
			MODEL_DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var model_value := model_binding.get_value()

	if not (model_value is HoverSpringDamperModel):
		_add_error(
			report,
			&"hover_factory_model_invalid",
			"hover_model type is invalid.",
			request.get_device_id(),
			MODEL_DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var model: HoverSpringDamperModel = model_value

	if not model.is_valid():
		_add_error(
			report,
			&"hover_factory_model_invalid",
			"hover_model is invalid.",
			request.get_device_id(),
			MODEL_DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var sink_binding := request.get_dependency_binding(
		SINK_DEPENDENCY_ID
	)

	if sink_binding == null:
		_add_error(
			report,
			&"hover_factory_sink_missing",
			"hover_force_sink Binding is required.",
			request.get_device_id(),
			SINK_DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not sink_binding.is_borrowed():
		_add_error(
			report,
			&"hover_factory_sink_ownership_invalid",
			"hover_force_sink must be BORROWED.",
			request.get_device_id(),
			SINK_DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var force_sink := sink_binding.get_value()

	if (
		force_sink == null
		or not is_instance_valid(force_sink)
		or not force_sink.has_method(&"apply_hover_force")
	):
		_add_error(
			report,
			&"hover_factory_sink_invalid",
			"hover_force_sink behavior is invalid.",
			request.get_device_id(),
			SINK_DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var unit := HoverPointRuntimeUnit.new(
		request.get_device_id(),
		request.get_configuration(),
		model,
		force_sink
	)

	if not unit.is_valid():
		_add_error(
			report,
			&"hover_factory_handle_invalid",
			"HoverPointRuntimeUnit is invalid.",
			request.get_device_id(),
			&"runtime_unit"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var host_objects: Array[Object] = []
	var handle := RuntimeDeviceHandle.new(
		request.get_device_id(),
		request.get_configuration(),
		request.get_factory_key(),
		unit,
		host_objects,
		request.get_dependency_bindings()
	)

	if not handle.is_valid():
		_add_error(
			report,
			&"hover_factory_handle_invalid",
			"RuntimeDeviceHandle is invalid.",
			request.get_device_id(),
			&"handle"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	return RuntimeFactoryBuildResult.new(handle, report)


func release(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null:
		_add_error(
			report,
			&"hover_factory_handle_invalid",
			"RuntimeDeviceHandle is required.",
			"",
			&"handle"
		)
		return report

	var handle_id: int = handle.get_instance_id()

	if _released_handle_ids.has(handle_id):
		return report

	if not handle.is_valid():
		_add_error(
			report,
			&"hover_factory_handle_invalid",
			"RuntimeDeviceHandle is invalid.",
			handle.get_device_id(),
			&"handle"
		)
		return report

	if not _key_is_supported(handle.get_factory_key()):
		_add_error(
			report,
			&"hover_factory_key_mismatch",
			"Handle Factory Key is not supported.",
			handle.get_device_id(),
			&"factory_key"
		)
		return report

	var primary := handle.get_primary_runtime_object()

	if not (primary is HoverPointRuntimeUnit):
		_add_error(
			report,
			&"hover_factory_primary_mismatch",
			"Primary Runtime Object is not HoverPointRuntimeUnit.",
			handle.get_device_id(),
			&"primary_runtime_object"
		)
		return report

	if not handle.get_host_objects().is_empty():
		_add_error(
			report,
			&"hover_factory_host_mismatch",
			"Hover Point Handle must not contain Host Objects.",
			handle.get_device_id(),
			&"host_objects"
		)
		return report

	var unit: HoverPointRuntimeUnit = primary

	if (
		unit.get_state() != HoverPointRuntimeUnit.State.CREATED
		and unit.get_state() != HoverPointRuntimeUnit.State.SHUTDOWN
	):
		_add_error(
			report,
			&"hover_factory_release_active",
			"Active Hover Point Runtime Unit cannot be released.",
			handle.get_device_id(),
			&"state"
		)
		return report

	_released_handle_ids[handle_id] = true
	return report


func _key_is_supported(
	key: RuntimeFactoryKey
) -> bool:

	return (
		key != null
		and key.is_valid()
		and key.get_profile_id() == PROFILE_ID
		and key.get_profile_version() == PROFILE_VERSION
		and key.get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION
	)


func _configuration_is_supported(
	configuration: DeviceConfiguration
) -> bool:

	if configuration == null or not configuration.is_valid():
		return false

	var expected_capabilities: Array[String] = [
		"hover_lift_force",
	]
	var expected_publishes: Array[StringName] = []
	var expected_subscribes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	return (
		configuration.get_profile_id() == PROFILE_ID
		and configuration.get_profile_version() == PROFILE_VERSION
		and configuration.get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION
		and configuration.get_enabled_capabilities()
		== expected_capabilities
		and configuration.get_enabled_publishes()
		== expected_publishes
		and configuration.get_enabled_subscribes()
		== expected_subscribes
	)


func _add_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	object_id: String,
	field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			message,
			object_id,
			field
		)
	)
