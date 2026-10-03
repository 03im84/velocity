extends RefCounted
class_name DistanceSensorRuntimeUnit


enum State {
	CREATED,
	INITIALIZED,
	READY,
	RUNNING,
	SHUTDOWN,
}


var _device_id: String
var _configuration: DeviceConfiguration
var _sensor: DistanceSensorDevice
var _provider: Object
var _state: State = State.CREATED


func _init(
	device_id: String,
	configuration: DeviceConfiguration,
	sensor: DistanceSensorDevice,
	provider: Object
) -> void:

	_device_id = device_id
	_configuration = configuration
	_sensor = sensor
	_provider = provider


func is_valid(
) -> bool:

	return (
		not _device_id.is_empty()
		and _configuration != null
		and _configuration.is_valid()
		and _configuration.get_device_id() == _device_id
		and _sensor != null
		and is_instance_valid(_sensor)
		and _provider != null
		and is_instance_valid(_provider)
		and _provider.has_method(&"get_distance")
		and _provider.has_method(&"is_valid")
	)


func get_state(
) -> State:

	return _state


func get_sensor(
) -> DistanceSensorDevice:

	return _sensor


func get_provider(
) -> Object:

	return _provider


func runtime_initialize(
	device_bus: DeviceBus
) -> ValidationReport:

	var report := ValidationReport.new()

	if _state != State.CREATED:
		_add_state_error(report, &"initialize")
		return report

	if not is_valid():
		_add_error(
			report,
			&"distance_sensor_runtime_configuration_invalid",
			"Distance Sensor Runtime Unit is invalid.",
			&"runtime_unit"
		)
		return report

	if device_bus == null:
		_add_error(
			report,
			&"distance_sensor_runtime_bus_missing",
			"DeviceBus is required.",
			&"device_bus"
		)
		return report

	if not _sensor.initialize_sensor(
		_device_id,
		device_bus,
		_provider
	):
		_add_error(
			report,
			&"distance_sensor_runtime_initialize_failed",
			"DistanceSensorDevice initialization failed.",
			&"initialize"
		)
		return report

	if not _sensor_matches_configuration():
		_add_error(
			report,
			&"distance_sensor_runtime_manifest_mismatch",
			"DistanceSensorDevice does not match Configuration.",
			&"manifest"
		)
		return report

	_state = State.INITIALIZED
	return report


func runtime_set_ready(
) -> ValidationReport:

	var report := ValidationReport.new()

	if _state != State.INITIALIZED:
		_add_state_error(report, &"set_ready")
		return report

	if not _sensor.set_ready():
		_add_error(
			report,
			&"distance_sensor_runtime_ready_failed",
			"DistanceSensorDevice set_ready failed.",
			&"set_ready"
		)
		return report

	_state = State.READY
	return report


func runtime_start(
) -> ValidationReport:

	var report := ValidationReport.new()

	if _state != State.READY:
		_add_state_error(report, &"start")
		return report

	if not _sensor.start():
		_add_error(
			report,
			&"distance_sensor_runtime_start_failed",
			"DistanceSensorDevice start failed.",
			&"start"
		)
		return report

	_state = State.RUNNING
	return report


func runtime_shutdown(
) -> ValidationReport:

	var report := ValidationReport.new()

	if _state == State.SHUTDOWN:
		return report

	if _sensor == null or not is_instance_valid(_sensor):
		_add_error(
			report,
			&"distance_sensor_runtime_sensor_invalid",
			"DistanceSensorDevice instance is invalid.",
			&"sensor"
		)
		return report

	if _sensor.device != null:
		if not _sensor.shutdown():
			_add_error(
				report,
				&"distance_sensor_runtime_shutdown_failed",
				"DistanceSensorDevice shutdown failed.",
				&"shutdown"
			)
			return report

	_provider = null
	_state = State.SHUTDOWN
	return report


func get_runtime_input_endpoint(
	_port_id: StringName
) -> Callable:

	return Callable()


func publish_measurement(
) -> ValidationReport:

	var report := ValidationReport.new()

	if _state != State.RUNNING:
		_add_error(
			report,
			&"distance_sensor_runtime_publish_not_running",
			"Distance Sensor must be RUNNING to publish.",
			&"publish_measurement"
		)
		return report

	_sensor.publish_measurement()
	return report


func _sensor_matches_configuration(
) -> bool:

	if _sensor.device == null:
		return false

	var identity := _sensor.device.get_identity()
	var manifest := _sensor.device.get_manifest()

	return (
		identity.get_device_id() == _device_id
		and manifest.capabilities
		== _configuration.get_enabled_capabilities()
		and manifest.publishes
		== _configuration.get_enabled_publishes()
		and manifest.subscribes
		== _configuration.get_enabled_subscribes()
	)


func _add_state_error(
	report: ValidationReport,
	field: StringName
) -> void:

	_add_error(
		report,
		&"distance_sensor_runtime_state_invalid",
		"Distance Sensor Runtime state rejects operation.",
		field
	)


func _add_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			message,
			_device_id,
			field
		)
	)
