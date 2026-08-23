extends Node


##
## DeviceGraphPrimitivesTest
##
## Verifica Ports, TopicChannel y Connection.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceGraphPrimitivesTest")
	print("========================================")

	_test_input_port()
	_test_output_port()
	_test_topic_channel()
	_test_connection()

	_finish_test()


# =============================================================================
# INPUT PORT
# =============================================================================

func _test_input_port() -> void:

	var port := DeviceGraphInputPort.new(
		&"in.distance_measurement",
		"hover_mcu",
		BusTopics.DISTANCE_MEASUREMENT,
		PortSemanticKinds.MEASUREMENT
	)

	_expect(
		port.is_valid(),
		"DGP-U01: InputPort is valid"
	)

	_expect(
		port.get_port_id()
		== &"in.distance_measurement",
		"DGP-U01: InputPort ID is preserved"
	)

	_expect(
		port.get_device_id() == "hover_mcu",
		"DGP-U01: InputPort Device ID is preserved"
	)

	_expect(
		port.get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"DGP-U01: InputPort Topic is preserved"
	)

	_expect(
		port.get_semantic_kind()
		== PortSemanticKinds.MEASUREMENT,
		"DGP-U01: InputPort Kind is preserved"
	)

	var invalid_ports: Array[DeviceGraphInputPort] = [
		DeviceGraphInputPort.new(
			&"",
			"hover_mcu",
			BusTopics.DISTANCE_MEASUREMENT
		),
		DeviceGraphInputPort.new(
			&"in.distance_measurement",
			"",
			BusTopics.DISTANCE_MEASUREMENT
		),
		DeviceGraphInputPort.new(
			&"in.distance_measurement",
			"hover_mcu",
			&""
		),
		DeviceGraphInputPort.new(
			&"in.distance_measurement",
			"hover_mcu",
			BusTopics.DISTANCE_MEASUREMENT,
			&"invalid_kind"
		),
		DeviceGraphInputPort.new(
			&"in.distance_measurement",
			"hover|mcu",
			BusTopics.DISTANCE_MEASUREMENT
		),
		DeviceGraphInputPort.new(
			&"in|distance",
			"hover_mcu",
			BusTopics.DISTANCE_MEASUREMENT
		),
	]

	for invalid_port: DeviceGraphInputPort in (
		invalid_ports
	):

		_expect(
			not invalid_port.is_valid(),
			"DGP-U01: invalid InputPort is rejected"
		)

	var setter_names: Array[StringName] = [
		&"set_port_id",
		&"set_device_id",
		&"set_topic",
		&"set_semantic_kind",
	]

	for setter_name: StringName in setter_names:

		_expect(
			not port.has_method(setter_name),
			"DGP-U01: InputPort "
			+ String(setter_name)
			+ " does not exist"
		)


# =============================================================================
# OUTPUT PORT
# =============================================================================

func _test_output_port() -> void:

	var port := DeviceGraphOutputPort.new(
		&"out.distance_measurement",
		"distance_sensor",
		BusTopics.DISTANCE_MEASUREMENT,
		PortSemanticKinds.MEASUREMENT
	)

	_expect(
		port.is_valid(),
		"DGP-U02: OutputPort is valid"
	)

	_expect(
		port.get_port_id()
		== &"out.distance_measurement",
		"DGP-U02: OutputPort ID is preserved"
	)

	_expect(
		port.get_device_id()
		== "distance_sensor",
		"DGP-U02: OutputPort Device ID is preserved"
	)

	_expect(
		port.get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"DGP-U02: OutputPort Topic is preserved"
	)

	_expect(
		port.get_semantic_kind()
		== PortSemanticKinds.MEASUREMENT,
		"DGP-U02: OutputPort Kind is preserved"
	)

	var invalid_ports: Array[DeviceGraphOutputPort] = [
		DeviceGraphOutputPort.new(
			&"",
			"distance_sensor",
			BusTopics.DISTANCE_MEASUREMENT
		),
		DeviceGraphOutputPort.new(
			&"out.distance_measurement",
			"",
			BusTopics.DISTANCE_MEASUREMENT
		),
		DeviceGraphOutputPort.new(
			&"out.distance_measurement",
			"distance_sensor",
			&""
		),
		DeviceGraphOutputPort.new(
			&"out.distance_measurement",
			"distance_sensor",
			BusTopics.DISTANCE_MEASUREMENT,
			&"invalid_kind"
		),
		DeviceGraphOutputPort.new(
			&"out.distance_measurement",
			"distance|sensor",
			BusTopics.DISTANCE_MEASUREMENT
		),
		DeviceGraphOutputPort.new(
			&"out|distance",
			"distance_sensor",
			BusTopics.DISTANCE_MEASUREMENT
		),
	]

	for invalid_port: DeviceGraphOutputPort in (
		invalid_ports
	):

		_expect(
			not invalid_port.is_valid(),
			"DGP-U02: invalid OutputPort is rejected"
		)

	var setter_names: Array[StringName] = [
		&"set_port_id",
		&"set_device_id",
		&"set_topic",
		&"set_semantic_kind",
	]

	for setter_name: StringName in setter_names:

		_expect(
			not port.has_method(setter_name),
			"DGP-U02: OutputPort "
			+ String(setter_name)
			+ " does not exist"
		)


# =============================================================================
# TOPIC CHANNEL
# =============================================================================

func _test_topic_channel() -> void:

	var channel := DeviceGraphTopicChannel.new(
		BusTopics.DISTANCE_MEASUREMENT
	)

	_expect(
		channel.is_valid(),
		"DGP-U03: TopicChannel is valid"
	)

	_expect(
		channel.get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"DGP-U03: TopicChannel Topic is preserved"
	)

	var invalid_channel := (
		DeviceGraphTopicChannel.new(
			&""
		)
	)

	_expect(
		not invalid_channel.is_valid(),
		"DGP-U03: empty TopicChannel is invalid"
	)

	_expect(
		not channel.has_method(
			&"set_topic"
		),
		"DGP-U03: TopicChannel has no setter"
	)


# =============================================================================
# CONNECTION
# =============================================================================

func _test_connection() -> void:

	var connection := DeviceGraphConnection.new(
		(
			&"distance_sensor"
			+ &"|out.distance_measurement"
			+ &"|hover_mcu"
			+ &"|in.distance_measurement"
		),
		"distance_sensor",
		&"out.distance_measurement",
		BusTopics.DISTANCE_MEASUREMENT,
		"hover_mcu",
		&"in.distance_measurement"
	)

	_expect(
		connection.is_valid_identity(),
		"DGP-U04: Connection identity is valid"
	)

	_expect(
		connection.get_connection_id()
		== (
			&"distance_sensor"
			+ &"|out.distance_measurement"
			+ &"|hover_mcu"
			+ &"|in.distance_measurement"
		),
		"DGP-U04: Connection ID is preserved"
	)

	_expect(
		connection.get_source_device_id()
		== "distance_sensor",
		"DGP-U04: Source Device ID is preserved"
	)

	_expect(
		connection.get_source_port_id()
		== &"out.distance_measurement",
		"DGP-U04: Source Port ID is preserved"
	)

	_expect(
		connection.get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"DGP-U04: Topic is preserved"
	)

	_expect(
		connection.get_target_device_id()
		== "hover_mcu",
		"DGP-U04: Target Device ID is preserved"
	)

	_expect(
		connection.get_target_port_id()
		== &"in.distance_measurement",
		"DGP-U04: Target Port ID is preserved"
	)

	var invalid_connections: Array[DeviceGraphConnection] = [
		DeviceGraphConnection.new(
			&"",
			"source",
			&"out.topic",
			&"topic",
			"target",
			&"in.topic"
		),
		DeviceGraphConnection.new(
			&"id",
			"",
			&"out.topic",
			&"topic",
			"target",
			&"in.topic"
		),
		DeviceGraphConnection.new(
			&"id",
			"source",
			&"",
			&"topic",
			"target",
			&"in.topic"
		),
		DeviceGraphConnection.new(
			&"id",
			"source",
			&"out.topic",
			&"",
			"target",
			&"in.topic"
		),
		DeviceGraphConnection.new(
			&"id",
			"source",
			&"out.topic",
			&"topic",
			"",
			&"in.topic"
		),
		DeviceGraphConnection.new(
			&"id",
			"source",
			&"out.topic",
			&"topic",
			"target",
			&""
		),
		DeviceGraphConnection.new(
			&"id",
			"source|bad",
			&"out.topic",
			&"topic",
			"target",
			&"in.topic"
		),
		DeviceGraphConnection.new(
			&"id",
			"source",
			&"out|topic",
			&"topic",
			"target",
			&"in.topic"
		),
		DeviceGraphConnection.new(
			&"id",
			"source",
			&"out.topic",
			&"topic",
			"target|bad",
			&"in.topic"
		),
		DeviceGraphConnection.new(
			&"id",
			"source",
			&"out.topic",
			&"topic",
			"target",
			&"in|topic"
		),
	]

	for invalid_connection: DeviceGraphConnection in (
		invalid_connections
	):

		_expect(
			not invalid_connection
				.is_valid_identity(),
			"DGP-U04: invalid Connection is rejected"
		)

	var setter_names: Array[StringName] = [
		&"set_connection_id",
		&"set_source_device_id",
		&"set_source_port_id",
		&"set_topic",
		&"set_target_device_id",
		&"set_target_port_id",
	]

	for setter_name: StringName in setter_names:

		_expect(
			not connection.has_method(
				setter_name
			),
			"DGP-U04: Connection "
			+ String(setter_name)
			+ " does not exist"
		)


# =============================================================================
# TEST UTILITIES
# =============================================================================

func _expect(
	condition: bool,
	description: String
) -> void:

	_check_count += 1

	if condition:
		print("[PASS] ", description)
		return

	_failure_count += 1

	push_error(
		"[FAIL] " + description
	)


func _finish_test() -> void:

	print("----------------------------------------")
	print("Checks: ", _check_count)
	print("Failures: ", _failure_count)

	if _failure_count == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")

	print("========================================")
	print("")

	get_tree().quit(
		_failure_count
	)
