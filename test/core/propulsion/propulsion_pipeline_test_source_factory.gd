extends RefCounted


class TestSourceUnit:
	extends RefCounted

	enum State {
		CREATED,
		INITIALIZED,
		READY,
		RUNNING,
		SHUTDOWN,
	}

	var device_id: String
	var configuration: DeviceConfiguration
	var state: State = State.CREATED
	var device_bus: DeviceBus

	func _init(
		p_device_id: String,
		p_configuration: DeviceConfiguration
	) -> void:
		device_id = p_device_id
		configuration = p_configuration

	func runtime_initialize(
		p_device_bus: DeviceBus
	) -> ValidationReport:
		var report := ValidationReport.new()
		if state != State.CREATED or p_device_bus == null:
			_add_error(report, &"test_source_initialize_failed")
			return report
		device_bus = p_device_bus
		state = State.INITIALIZED
		return report

	func runtime_set_ready() -> ValidationReport:
		var report := ValidationReport.new()
		if state != State.INITIALIZED:
			_add_error(report, &"test_source_ready_failed")
			return report
		state = State.READY
		return report

	func runtime_start() -> ValidationReport:
		var report := ValidationReport.new()
		if state != State.READY:
			_add_error(report, &"test_source_start_failed")
			return report
		state = State.RUNNING
		return report

	func runtime_shutdown() -> ValidationReport:
		var report := ValidationReport.new()
		if state == State.SHUTDOWN:
			return report
		device_bus = null
		state = State.SHUTDOWN
		return report

	func get_runtime_input_endpoint(
		_port_id: StringName
	) -> Callable:
		return Callable()

	func is_running() -> bool:
		return state == State.RUNNING

	func publish_command(
		command: PropulsionCommand
	) -> bool:
		if state != State.RUNNING:
			return false
		if device_bus == null or command == null:
			return false
		if not command.is_valid():
			return false
		var message := BusMessage.new(
			device_id,
			BusTopics.PROPULSION_COMMAND,
			command.get_timestamp(),
			command
		)
		return device_bus.publish(
			BusTopics.PROPULSION_COMMAND,
			message
		)

	func _add_error(
		report: ValidationReport,
		code: StringName
	) -> void:
		report.add_issue(
			ValidationIssue.new(
				code,
				ValidationIssue.Severity.STRUCTURAL_ERROR,
				"Propulsion pipeline test source failed.",
				device_id,
				&"state"
			)
		)


var release_count: int = 0
var _released_ids: Dictionary[int, bool] = {}


func build(
	request: RuntimeConstructionRequest
) -> RuntimeFactoryBuildResult:

	var report := ValidationReport.new()

	if request == null or not request.is_valid():
		report.add_issue(
			ValidationIssue.new(
				&"test_source_request_invalid",
				ValidationIssue.Severity.STRUCTURAL_ERROR,
				"Valid Request is required."
			)
		)
		return RuntimeFactoryBuildResult.new(null, report)

	var unit := TestSourceUnit.new(
		request.get_device_id(),
		request.get_configuration()
	)
	var hosts: Array[Object] = []
	var handle := RuntimeDeviceHandle.new(
		request.get_device_id(),
		request.get_configuration(),
		request.get_factory_key(),
		unit,
		hosts,
		request.get_dependency_bindings()
	)
	return RuntimeFactoryBuildResult.new(handle, report)


func release(
	handle: RuntimeDeviceHandle
) -> ValidationReport:

	var report := ValidationReport.new()

	if handle == null:
		return report

	var handle_id := handle.get_instance_id()

	if _released_ids.has(handle_id):
		return report

	_released_ids[handle_id] = true
	release_count += 1
	return report
