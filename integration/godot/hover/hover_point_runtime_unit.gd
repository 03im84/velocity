extends RefCounted
class_name HoverPointRuntimeUnit


## HoverPointRuntimeUnit
##
## Managed actuator por punto que convierte DistanceMeasurement en
## lift acotado mediante HoverSpringDamperModel y HoverForceSink.
##
## Conserva como máximo un sample temporal previo. No conoce
## RigidBody3D, otros hover points o balancing global.
## ADR-016 / Hover Physics Slice Design 1.0.


enum State {
	CREATED,
	INITIALIZED,
	READY,
	RUNNING,
	SHUTDOWN,
}


const PROFILE_ID: StringName = &"velocity.hover.spring_damper_point"
const PROFILE_VERSION: int = 1
const INPUT_PORT_ID: StringName = &"in.distance_measurement"


var _device_id: String
var _configuration: DeviceConfiguration
var _model: HoverSpringDamperModel
var _force_sink: Object
var _device_bus: DeviceBus
var _state: State = State.CREATED

var _has_previous_sample: bool = false
var _previous_distance_meters: float = 0.0
var _previous_timestamp: float = 0.0

var _has_actuation_result: bool = false
var _last_force_newtons: float = 0.0
var _last_distance_rate_meters_per_second: float = 0.0
var _last_actuation_report: ValidationReport = ValidationReport.new()


func _init(
	device_id: String,
	configuration: DeviceConfiguration,
	model: HoverSpringDamperModel,
	force_sink: Object
) -> void:

	_device_id = device_id
	_configuration = configuration
	_model = model
	_force_sink = force_sink


func is_valid() -> bool:

	return (
		not _device_id.is_empty()
		and _configuration != null
		and _configuration.is_valid()
		and _configuration.get_device_id() == _device_id
		and _configuration_is_supported()
		and _model != null
		and is_instance_valid(_model)
		and _model.is_valid()
		and _force_sink != null
		and is_instance_valid(_force_sink)
		and _force_sink.has_method(&"apply_hover_force")
	)


func get_state() -> State:

	return _state


func get_model() -> HoverSpringDamperModel:

	return _model


func get_force_sink() -> Object:

	return _force_sink


func has_previous_sample() -> bool:

	return _has_previous_sample


func has_actuation_result() -> bool:

	return _has_actuation_result


func get_last_force_newtons() -> float:

	return _last_force_newtons


func get_last_distance_rate_meters_per_second() -> float:

	return _last_distance_rate_meters_per_second


func get_last_actuation_report() -> ValidationReport:

	return _last_actuation_report


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
			&"hover_runtime_unit_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Hover Point Runtime Unit is invalid.",
			&"runtime_unit"
		)
		return report

	if device_bus == null:
		_add_error(
			report,
			&"hover_runtime_bus_missing",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"DeviceBus is required.",
			&"device_bus"
		)
		return report

	_device_bus = device_bus
	_state = State.INITIALIZED
	return report


func runtime_set_ready() -> ValidationReport:

	return _transition(
		State.INITIALIZED,
		State.READY,
		&"set_ready"
	)


func runtime_start() -> ValidationReport:

	return _transition(
		State.READY,
		State.RUNNING,
		&"start"
	)


func runtime_shutdown() -> ValidationReport:

	var report := ValidationReport.new()

	if _state == State.SHUTDOWN:
		return report

	_device_bus = null
	_clear_previous_sample()
	_state = State.SHUTDOWN
	return report


func get_runtime_input_endpoint(
	port_id: StringName
) -> Callable:

	if port_id != INPUT_PORT_ID:
		return Callable()

	return _receive_distance_measurement


func _receive_distance_measurement(
	message_value: Variant
) -> void:

	_begin_actuation_result()

	if _state != State.RUNNING:
		_add_last_error(
			&"hover_runtime_state_invalid",
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			"Hover Runtime state rejects actuation.",
			&"state"
		)
		return

	if not is_valid():
		_clear_previous_sample()
		_add_last_error(
			&"hover_runtime_unit_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Hover Runtime Unit became invalid.",
			&"runtime_unit"
		)
		return

	if not (message_value is BusMessage):
		_reject_measurement(
			&"hover_runtime_message_invalid",
			"BusMessage is required.",
			&"message"
		)
		return

	var message: BusMessage = message_value

	if not message.is_valid():
		_reject_measurement(
			&"hover_runtime_message_invalid",
			"BusMessage is invalid.",
			&"message"
		)
		return

	if message.get_topic() != BusTopics.DISTANCE_MEASUREMENT:
		_reject_measurement(
			&"hover_runtime_topic_mismatch",
			"BusMessage Topic is not distance_measurement.",
			&"topic"
		)
		return

	var message_timestamp := message.get_timestamp()

	if (
		not is_finite(message_timestamp)
		or message_timestamp < 0.0
	):
		_reject_measurement(
			&"hover_runtime_timestamp_invalid",
			"BusMessage timestamp is invalid.",
			&"timestamp"
		)
		return

	var payload_value: Variant = message.get_payload()

	if not (payload_value is DistanceMeasurement):
		_reject_measurement(
			&"hover_runtime_payload_invalid",
			"DistanceMeasurement payload is required.",
			&"payload"
		)
		return

	var measurement: DistanceMeasurement = payload_value

	if (
		not measurement.valid
		or not is_finite(measurement.distance)
		or measurement.distance < 0.0
		or not is_finite(measurement.timestamp)
		or measurement.timestamp < 0.0
	):
		_reject_measurement(
			&"hover_runtime_measurement_invalid",
			"DistanceMeasurement is invalid.",
			&"payload"
		)
		return

	if measurement.timestamp != message_timestamp:
		_reject_measurement(
			&"hover_runtime_timestamp_mismatch",
			"Measurement and BusMessage timestamps differ.",
			&"timestamp"
		)
		return

	var distance_rate := 0.0

	if _has_previous_sample:
		var delta_seconds := (
			measurement.timestamp - _previous_timestamp
		)

		if delta_seconds <= 0.0:
			_set_previous_sample(
				measurement.distance,
				measurement.timestamp
			)
			_add_last_error(
				&"hover_runtime_timestamp_non_monotonic",
				ValidationIssue.Severity.STRUCTURAL_ERROR,
				"Measurement timestamp did not advance.",
				&"timestamp"
			)
			return

		if not _model.is_sample_interval_valid(
			delta_seconds
		):
			_set_previous_sample(
				measurement.distance,
				measurement.timestamp
			)
			_add_last_error(
				&"hover_runtime_sample_gap_exceeded",
				ValidationIssue.Severity.STRUCTURAL_ERROR,
				"Measurement sample gap exceeds model limit.",
				&"timestamp"
			)
			return

		distance_rate = (
			(measurement.distance
			- _previous_distance_meters)
			/ delta_seconds
		)

		if not is_finite(distance_rate):
			_set_previous_sample(
				measurement.distance,
				measurement.timestamp
			)
			_add_last_error(
				&"hover_runtime_distance_rate_invalid",
				ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
				"Calculated distance rate is not finite.",
				&"distance_rate"
			)
			return

	_last_distance_rate_meters_per_second = distance_rate

	var force_newtons := _model.calculate_lift_force_newtons(
		measurement.distance,
		distance_rate
	)

	if not is_finite(force_newtons):
		_add_last_error(
			&"hover_runtime_force_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Calculated hover force is not finite.",
			&"force_newtons"
		)
		return

	if not _model.is_force_within_limits(force_newtons):
		_add_last_error(
			&"hover_runtime_force_out_of_bounds",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Calculated hover force exceeds model limits.",
			&"force_newtons"
		)
		return

	_set_previous_sample(
		measurement.distance,
		measurement.timestamp
	)

	var accepted_value: Variant = _force_sink.call(
		&"apply_hover_force",
		force_newtons,
		measurement.timestamp
	)

	if typeof(accepted_value) != TYPE_BOOL:
		_add_last_error(
			&"hover_runtime_sink_result_invalid",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Hover Force Sink returned a non-boolean result.",
			&"hover_force_sink"
		)
		return

	if not bool(accepted_value):
		_add_last_error(
			&"hover_runtime_sink_rejected",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Hover Force Sink rejected lift output.",
			&"hover_force_sink"
		)
		return

	_last_force_newtons = force_newtons


func _configuration_is_supported() -> bool:

	var expected_capabilities: Array[String] = [
		"hover_lift_force",
	]
	var expected_publishes: Array[StringName] = []
	var expected_subscribes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	return (
		_configuration.get_profile_id() == PROFILE_ID
		and _configuration.get_profile_version() == PROFILE_VERSION
		and _configuration.get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION
		and _configuration.get_enabled_capabilities()
		== expected_capabilities
		and _configuration.get_enabled_publishes()
		== expected_publishes
		and _configuration.get_enabled_subscribes()
		== expected_subscribes
	)


func _begin_actuation_result() -> void:

	_has_actuation_result = true
	_last_force_newtons = 0.0
	_last_distance_rate_meters_per_second = 0.0
	_last_actuation_report = ValidationReport.new()


func _reject_measurement(
	code: StringName,
	message: String,
	field: StringName
) -> void:

	_clear_previous_sample()
	_add_last_error(
		code,
		ValidationIssue.Severity.STRUCTURAL_ERROR,
		message,
		field
	)


func _set_previous_sample(
	distance_meters: float,
	timestamp: float
) -> void:

	_has_previous_sample = true
	_previous_distance_meters = distance_meters
	_previous_timestamp = timestamp


func _clear_previous_sample() -> void:

	_has_previous_sample = false
	_previous_distance_meters = 0.0
	_previous_timestamp = 0.0


func _transition(
	expected: State,
	target: State,
	field: StringName
) -> ValidationReport:

	var report := ValidationReport.new()

	if _state != expected:
		_add_state_error(report, field)
		return report

	_state = target
	return report


func _add_state_error(
	report: ValidationReport,
	field: StringName
) -> void:

	_add_error(
		report,
		&"hover_runtime_state_invalid",
		ValidationIssue.Severity.STRUCTURAL_ERROR,
		"Hover Runtime state rejects operation.",
		field
	)


func _add_last_error(
	code: StringName,
	severity: ValidationIssue.Severity,
	message: String,
	field: StringName
) -> void:

	_add_error(
		_last_actuation_report,
		code,
		severity,
		message,
		field
	)


func _add_error(
	report: ValidationReport,
	code: StringName,
	severity: ValidationIssue.Severity,
	message: String,
	field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			severity,
			message,
			_device_id,
			field
		)
	)
