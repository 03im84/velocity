extends RefCounted
class_name InputRuntimeFactory


## InputRuntimeFactory
##
## Construct-only RuntimeFactory para Input Simulation.
##
## Produce un RuntimeDeviceHandle concreto que envuelve
## un InputRuntimeUnit (Primary Runtime Object) y un
## InputSamplingNode (único Host Object owned), conservando
## el Provider BORROWED.
##
## No adjunta, inicializa, prepara, inicia ni publica.
## No almacena DeviceBus.
##
## ADR-014 / Input Runtime Slice Design 1.0.


const PROFILE_ID: StringName = &"velocity.input.player"
const PROFILE_VERSION: int = 1
const DEPENDENCY_ID: StringName = &"input_intent_provider"


var _released_handle_ids: Dictionary[int, bool] = {}


func build(
	request: RuntimeConstructionRequest
) -> RuntimeFactoryBuildResult:

	var report := ValidationReport.new()

	if request == null:
		_add_error(
			report,
			&"input_runtime_factory_request_missing",
			"RuntimeConstructionRequest is required.",
			"",
			&"request"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not request.is_valid():
		_add_error(
			report,
			&"input_runtime_factory_request_invalid",
			"RuntimeConstructionRequest is invalid.",
			request.get_device_id(),
			&"request"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not _key_is_supported(request.get_factory_key()):
		_add_error(
			report,
			&"input_runtime_factory_key_mismatch",
			"RuntimeFactoryKey is not supported.",
			request.get_device_id(),
			&"factory_key"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var configuration := request.get_configuration()

	if not _configuration_is_supported(configuration):
		_add_error(
			report,
			&"input_runtime_factory_configuration_unsupported",
			"DeviceConfiguration enables unsupported behavior.",
			request.get_device_id(),
			&"configuration"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var binding := request.get_dependency_binding(DEPENDENCY_ID)

	if binding == null:
		_add_error(
			report,
			&"input_runtime_factory_provider_missing",
			"input_intent_provider Binding is required.",
			request.get_device_id(),
			DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not binding.is_borrowed():
		_add_error(
			report,
			&"input_runtime_factory_provider_ownership_invalid",
			"input_intent_provider must be BORROWED.",
			request.get_device_id(),
			DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var provider := binding.get_value()

	if (
		provider == null
		or not is_instance_valid(provider)
		or not provider.has_method(&"sample_intent")
	):
		_add_error(
			report,
			&"input_runtime_factory_provider_invalid",
			"input_intent_provider behavior is invalid.",
			request.get_device_id(),
			DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var sampler := InputSamplingNode.new()
	var unit := InputRuntimeUnit.new(
		request.get_device_id(),
		configuration,
		provider,
		sampler
	)

	if not unit.is_valid():
		sampler.free()
		_add_error(
			report,
			&"input_runtime_factory_handle_invalid",
			"InputRuntimeUnit is invalid.",
			request.get_device_id(),
			&"runtime_unit"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var host_objects: Array[Object] = [sampler]
	var handle := RuntimeDeviceHandle.new(
		request.get_device_id(),
		configuration,
		request.get_factory_key(),
		unit,
		host_objects,
		request.get_dependency_bindings()
	)

	if not handle.is_valid():
		sampler.free()
		_add_error(
			report,
			&"input_runtime_factory_handle_invalid",
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
			&"input_runtime_factory_handle_invalid",
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
			&"input_runtime_factory_handle_invalid",
			"RuntimeDeviceHandle is invalid.",
			handle.get_device_id(),
			&"handle"
		)
		return report

	if not _key_is_supported(handle.get_factory_key()):
		_add_error(
			report,
			&"input_runtime_factory_key_mismatch",
			"Handle Factory Key is not supported.",
			handle.get_device_id(),
			&"factory_key"
		)
		return report

	var primary := handle.get_primary_runtime_object()

	if not (primary is InputRuntimeUnit):
		_add_error(
			report,
			&"input_runtime_factory_primary_mismatch",
			"Primary Runtime Object is not InputRuntimeUnit.",
			handle.get_device_id(),
			&"primary_runtime_object"
		)
		return report

	var unit: InputRuntimeUnit = primary
	var sampler := unit.get_sampler()
	var host_objects := handle.get_host_objects()

	if (
		host_objects.size() != 1
		or host_objects[0] != sampler
	):
		_add_error(
			report,
			&"input_runtime_factory_host_mismatch",
			"Handle Host Objects do not match Runtime Unit.",
			handle.get_device_id(),
			&"host_objects"
		)
		return report

	if sampler != null and is_instance_valid(sampler):
		if sampler.get_parent() != null:
			_add_error(
				report,
				&"input_runtime_factory_release_still_attached",
				"InputSamplingNode must be detached before release.",
				handle.get_device_id(),
				&"host_objects"
			)
			return report

		if sampler.is_sampling_enabled():
			sampler.set_sampling_enabled(false)

		sampler.free()

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
		"vehicle_control_input",
	]
	var expected_publishes: Array[StringName] = [
		BusTopics.VEHICLE_CONTROL_COMMAND,
	]
	var expected_subscribes: Array[StringName] = []

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
