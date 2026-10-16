extends RefCounted
class_name VehicleControlRouterRuntimeFactory


## VehicleControlRouterRuntimeFactory
##
## Construct-only RuntimeFactory para Vehicle Control Router Simulation.
## Produce una Unit sin Host Objects y conserva PropulsionIntentPolicy
## como dependencia BORROWED.
## ADR-017 / Playable Vehicle Composition Design 1.1.


const PROFILE_ID: StringName = &"velocity.vehicle_control.router"
const PROFILE_VERSION: int = 1
const POLICY_DEPENDENCY_ID: StringName = &"propulsion_intent_policy"


var _released_handle_ids: Dictionary[int, bool] = {}


func build(
	request: RuntimeConstructionRequest
) -> RuntimeFactoryBuildResult:

	var report := ValidationReport.new()

	if request == null:
		_add_error(
			report,
			&"vehicle_control_router_factory_request_missing",
			"RuntimeConstructionRequest is required.",
			"",
			&"request"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not request.is_valid():
		_add_error(
			report,
			&"vehicle_control_router_factory_request_invalid",
			"RuntimeConstructionRequest is invalid.",
			request.get_device_id(),
			&"request"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not _key_is_supported(request.get_factory_key()):
		_add_error(
			report,
			&"vehicle_control_router_factory_key_mismatch",
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
			&"vehicle_control_router_factory_configuration_unsupported",
			"DeviceConfiguration enables unsupported behavior.",
			request.get_device_id(),
			&"configuration"
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var policy_binding := request.get_dependency_binding(
		POLICY_DEPENDENCY_ID
	)

	if policy_binding == null:
		_add_error(
			report,
			&"vehicle_control_router_factory_policy_missing",
			"propulsion_intent_policy Binding is required.",
			request.get_device_id(),
			POLICY_DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	if not policy_binding.is_borrowed():
		_add_error(
			report,
			&"vehicle_control_router_factory_policy_ownership_invalid",
			"propulsion_intent_policy must be BORROWED.",
			request.get_device_id(),
			POLICY_DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var policy_value := policy_binding.get_value()

	if not (policy_value is PropulsionIntentPolicy):
		_add_error(
			report,
			&"vehicle_control_router_factory_policy_invalid",
			"propulsion_intent_policy type is invalid.",
			request.get_device_id(),
			POLICY_DEPENDENCY_ID
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var policy: PropulsionIntentPolicy = policy_value
	var unit := VehicleControlRouterRuntimeUnit.new(
		request.get_device_id(),
		request.get_configuration(),
		policy
	)

	if not unit.is_valid():
		_add_error(
			report,
			&"vehicle_control_router_factory_handle_invalid",
			"VehicleControlRouterRuntimeUnit is invalid.",
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
			&"vehicle_control_router_factory_handle_invalid",
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
			&"vehicle_control_router_factory_handle_invalid",
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
			&"vehicle_control_router_factory_handle_invalid",
			"RuntimeDeviceHandle is invalid.",
			handle.get_device_id(),
			&"handle"
		)
		return report

	if not _key_is_supported(handle.get_factory_key()):
		_add_error(
			report,
			&"vehicle_control_router_factory_key_mismatch",
			"Handle Factory Key is not supported.",
			handle.get_device_id(),
			&"factory_key"
		)
		return report

	var primary := handle.get_primary_runtime_object()

	if not (primary is VehicleControlRouterRuntimeUnit):
		_add_error(
			report,
			&"vehicle_control_router_factory_primary_mismatch",
			"Primary Runtime Object is not VehicleControlRouterRuntimeUnit.",
			handle.get_device_id(),
			&"primary_runtime_object"
		)
		return report

	if not handle.get_host_objects().is_empty():
		_add_error(
			report,
			&"vehicle_control_router_factory_host_mismatch",
			"Vehicle Control Router Handle must not contain Host Objects.",
			handle.get_device_id(),
			&"host_objects"
		)
		return report

	var unit: VehicleControlRouterRuntimeUnit = primary

	if (
		unit.get_state() != VehicleControlRouterRuntimeUnit.State.CREATED
		and unit.get_state()
		!= VehicleControlRouterRuntimeUnit.State.SHUTDOWN
	):
		_add_error(
			report,
			&"vehicle_control_router_factory_release_active",
			"Active Vehicle Control Router Unit cannot be released.",
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
		"vehicle_control_routing",
	]
	var expected_publishes: Array[StringName] = [
		BusTopics.PROPULSION_COMMAND,
		BusTopics.STEERING_COMMAND,
		BusTopics.BRAKE_COMMAND,
	]
	var expected_subscribes: Array[StringName] = [
		BusTopics.VEHICLE_CONTROL_COMMAND,
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
