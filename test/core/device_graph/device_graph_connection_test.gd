extends Node


##
## DeviceGraphConnectionTest
##
## Verifica las operaciones transaccionales
## de conexión y desconexión de DeviceGraphDraft.
##


const SOURCE_DEVICE_ID: String = "distance_sensor"
const TARGET_DEVICE_ID: String = "hover_mcu"


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceGraphConnectionTest")
	print("========================================")

	_test_valid_connection()
	_test_missing_devices()
	_test_missing_ports()
	_test_topic_mismatch()
	_test_semantic_mismatch()
	_test_unspecified_semantic_compatibility()
	_test_self_connection()
	_test_duplicate_connection()
	_test_reserved_separator()
	_test_disconnect_connection()
	_test_remove_connected_devices()
	_test_connection_collection_copy()

	_finish_test()


# =============================================================================
# VALID CONNECTION
# =============================================================================

func _test_valid_connection() -> void:

	var graph := _default_graph()

	var source_port_id := _output_port_id(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var target_port_id := _input_port_id(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var expected_id_text: String = (
		SOURCE_DEVICE_ID
		+ "|"
		+ String(source_port_id)
		+ "|"
		+ TARGET_DEVICE_ID
		+ "|"
		+ String(target_port_id)
	)

	var result := graph.connect_ports(
		SOURCE_DEVICE_ID,
		source_port_id,
		TARGET_DEVICE_ID,
		target_port_id
	)

	_expect(
		result.is_success(),
		"DGC-U01: valid connection succeeds"
	)

	_expect(
		String(result.get_affected_id())
		== expected_id_text,
		"DGC-U01: connection ID uses the canonical four-part format"
	)

	_expect(
		result.get_report().is_valid_for_simulation(),
		"DGC-U01: successful result has a valid Report"
	)

	_expect(
		graph.has_connection(
			result.get_affected_id()
		),
		"DGC-U01: Graph contains the connection"
	)

	var connection := graph.get_connection(
		result.get_affected_id()
	)

	_expect(
		connection != null,
		"DGC-U01: get_connection returns the connection"
	)

	if connection == null:
		return

	_expect(
		connection.is_valid_identity(),
		"DGC-U01: stored connection has valid identity"
	)

	_expect(
		connection.get_source_device_id()
		== SOURCE_DEVICE_ID
		and connection.get_source_port_id()
		== source_port_id,
		"DGC-U01: source endpoint is preserved"
	)

	_expect(
		connection.get_target_device_id()
		== TARGET_DEVICE_ID
		and connection.get_target_port_id()
		== target_port_id,
		"DGC-U01: target endpoint is preserved"
	)

	_expect(
		connection.get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"DGC-U01: connection Topic is preserved"
	)

	_expect(
		graph.get_connections().size() == 1,
		"DGC-U01: Graph contains exactly one connection"
	)


# =============================================================================
# MISSING DEVICES
# =============================================================================

func _test_missing_devices() -> void:

	var graph := _default_graph()

	var source_port_id := _output_port_id(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var target_port_id := _input_port_id(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var missing_source_result := graph.connect_ports(
		"missing_sensor",
		source_port_id,
		TARGET_DEVICE_ID,
		target_port_id
	)

	_expect_failure(
		missing_source_result,
		&"source_device_not_found",
		"DGC-U02: missing source Device"
	)

	var missing_target_result := graph.connect_ports(
		SOURCE_DEVICE_ID,
		source_port_id,
		"missing_controller",
		target_port_id
	)

	_expect_failure(
		missing_target_result,
		&"target_device_not_found",
		"DGC-U02: missing target Device"
	)

	_expect(
		graph.get_connections().is_empty(),
		"DGC-U02: failed Device lookups preserve Graph"
	)


# =============================================================================
# MISSING PORTS
# =============================================================================

func _test_missing_ports() -> void:

	var graph := _default_graph()

	var source_port_id := _output_port_id(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var target_port_id := _input_port_id(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var missing_source_result := graph.connect_ports(
		SOURCE_DEVICE_ID,
		&"out.missing",
		TARGET_DEVICE_ID,
		target_port_id
	)

	_expect_failure(
		missing_source_result,
		&"source_port_not_found",
		"DGC-U03: missing source OutputPort"
	)

	var missing_target_result := graph.connect_ports(
		SOURCE_DEVICE_ID,
		source_port_id,
		TARGET_DEVICE_ID,
		&"in.missing"
	)

	_expect_failure(
		missing_target_result,
		&"target_port_not_found",
		"DGC-U03: missing target InputPort"
	)

	_expect(
		graph.get_connections().is_empty(),
		"DGC-U03: failed Port lookups preserve Graph"
	)


# =============================================================================
# TOPIC COMPATIBILITY
# =============================================================================

func _test_topic_mismatch() -> void:

	var graph := _default_graph()

	var result := graph.connect_ports(
		SOURCE_DEVICE_ID,
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		TARGET_DEVICE_ID,
		_input_port_id(
			BusTopics.HEALTH_REPORT
		)
	)

	_expect_failure(
		result,
		&"connection_topic_mismatch",
		"DGC-U04: Topic mismatch"
	)

	_expect(
		graph.get_connections().is_empty(),
		"DGC-U04: Topic mismatch preserves Graph"
	)


# =============================================================================
# SEMANTIC COMPATIBILITY
# =============================================================================

func _test_semantic_mismatch() -> void:

	var source := _copy_node_with_semantics(
		_sensor_node(),
		PortSemanticKinds.UNSPECIFIED,
		PortSemanticKinds.MEASUREMENT
	)

	var target := _copy_node_with_semantics(
		_controller_node(),
		PortSemanticKinds.COMMAND,
		PortSemanticKinds.UNSPECIFIED
	)

	var graph := DeviceGraphDraft.new()

	var source_add_result := graph.add_device(
		source
	)

	var target_add_result := graph.add_device(
		target
	)

	_expect(
		source.is_valid()
		and target.is_valid(),
		"DGC-U05: semantic fixtures are valid"
	)

	_expect(
		source_add_result.is_success()
		and target_add_result.is_success(),
		"DGC-U05: semantic fixtures are added"
	)

	var result := _connect_distance(
		graph
	)

	_expect_failure(
		result,
		&"connection_semantic_mismatch",
		"DGC-U05: semantic mismatch"
	)

	_expect(
		graph.get_connections().is_empty(),
		"DGC-U05: semantic mismatch preserves Graph"
	)


func _test_unspecified_semantic_compatibility() -> void:

	var source_unspecified := _sensor_node()

	var target_measurement := _copy_node_with_semantics(
		_controller_node(),
		PortSemanticKinds.MEASUREMENT,
		PortSemanticKinds.UNSPECIFIED
	)

	var first_graph := DeviceGraphDraft.new()

	first_graph.add_device(
		source_unspecified
	)

	first_graph.add_device(
		target_measurement
	)

	var source_wildcard_result := _connect_distance(
		first_graph
	)

	_expect(
		source_wildcard_result.is_success(),
		"DGC-U06: source UNSPECIFIED matches target semantic"
	)

	_expect(
		first_graph.get_connections().size() == 1,
		"DGC-U06: source wildcard creates one connection"
	)

	var source_measurement := _copy_node_with_semantics(
		_sensor_node(),
		PortSemanticKinds.UNSPECIFIED,
		PortSemanticKinds.MEASUREMENT
	)

	var target_unspecified := _controller_node()

	var second_graph := DeviceGraphDraft.new()

	second_graph.add_device(
		source_measurement
	)

	second_graph.add_device(
		target_unspecified
	)

	var target_wildcard_result := _connect_distance(
		second_graph
	)

	_expect(
		target_wildcard_result.is_success(),
		"DGC-U06: target UNSPECIFIED matches source semantic"
	)

	_expect(
		second_graph.get_connections().size() == 1,
		"DGC-U06: target wildcard creates one connection"
	)


# =============================================================================
# SELF AND DUPLICATE CONNECTIONS
# =============================================================================

func _test_self_connection() -> void:

	var graph := DeviceGraphDraft.new()

	graph.add_device(
		_controller_node()
	)

	var result := graph.connect_ports(
		TARGET_DEVICE_ID,
		_output_port_id(
			BusTopics.PROPULSION_COMMAND
		),
		TARGET_DEVICE_ID,
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	_expect_failure(
		result,
		&"self_connection_not_supported",
		"DGC-U07: self-connection"
	)

	_expect(
		graph.get_connections().is_empty(),
		"DGC-U07: self-connection preserves Graph"
	)


func _test_duplicate_connection() -> void:

	var graph := _default_graph()

	var first_result := _connect_distance(
		graph
	)

	var duplicate_result := _connect_distance(
		graph
	)

	_expect(
		first_result.is_success(),
		"DGC-U08: first connection succeeds"
	)

	_expect_failure(
		duplicate_result,
		&"duplicate_connection",
		"DGC-U08: duplicate connection"
	)

	_expect(
		duplicate_result.get_affected_id() == &"",
		"DGC-U08: failed duplicate has no affected ID"
	)

	_expect(
		graph.get_connections().size() == 1,
		"DGC-U08: duplicate attempt preserves original connection"
	)


# =============================================================================
# RESERVED SEPARATOR
# =============================================================================

func _test_reserved_separator() -> void:

	var graph := _default_graph()

	var source_port_id := _output_port_id(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var target_port_id := _input_port_id(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var source_device_result := graph.connect_ports(
		"distance|sensor",
		source_port_id,
		TARGET_DEVICE_ID,
		target_port_id
	)

	_expect_failure(
		source_device_result,
		&"graph_id_contains_reserved_separator",
		"DGC-U09: source Device reserved separator"
	)

	var source_port_result := graph.connect_ports(
		SOURCE_DEVICE_ID,
		&"out|invalid",
		TARGET_DEVICE_ID,
		target_port_id
	)

	_expect_failure(
		source_port_result,
		&"graph_id_contains_reserved_separator",
		"DGC-U09: source Port reserved separator"
	)

	var target_device_result := graph.connect_ports(
		SOURCE_DEVICE_ID,
		source_port_id,
		"hover|mcu",
		target_port_id
	)

	_expect_failure(
		target_device_result,
		&"graph_id_contains_reserved_separator",
		"DGC-U09: target Device reserved separator"
	)

	var target_port_result := graph.connect_ports(
		SOURCE_DEVICE_ID,
		source_port_id,
		TARGET_DEVICE_ID,
		&"in|invalid"
	)

	_expect_failure(
		target_port_result,
		&"graph_id_contains_reserved_separator",
		"DGC-U09: target Port reserved separator"
	)

	_expect(
		graph.get_connections().is_empty(),
		"DGC-U09: separator failures preserve Graph"
	)


# =============================================================================
# DISCONNECT
# =============================================================================

func _test_disconnect_connection() -> void:

	var graph := _default_graph()

	var connect_result := _connect_distance(
		graph
	)

	var connection_id := connect_result.get_affected_id()

	_expect(
		connect_result.is_success(),
		"DGC-U10: disconnect fixture connection succeeds"
	)

	var missing_result := graph.disconnect_ports(
		&"missing|connection"
	)

	_expect_failure(
		missing_result,
		&"connection_not_found",
		"DGC-U10: missing disconnect"
	)

	_expect(
		graph.has_connection(connection_id),
		"DGC-U10: failed disconnect preserves connection"
	)

	var disconnect_result := graph.disconnect_ports(
		connection_id
	)

	_expect(
		disconnect_result.is_success(),
		"DGC-U10: existing connection is disconnected"
	)

	_expect(
		disconnect_result.get_affected_id()
		== connection_id,
		"DGC-U10: disconnect returns affected connection ID"
	)

	_expect(
		not graph.has_connection(connection_id)
		and graph.get_connection(connection_id) == null
		and graph.get_connections().is_empty(),
		"DGC-U10: disconnected connection is fully removed"
	)

	var second_disconnect_result := graph.disconnect_ports(
		connection_id
	)

	_expect_failure(
		second_disconnect_result,
		&"connection_not_found",
		"DGC-U10: repeated disconnect"
	)


# =============================================================================
# CONNECTED DEVICE REMOVAL
# =============================================================================

func _test_remove_connected_devices() -> void:

	var graph := _default_graph()

	var connection_result := _connect_distance(
		graph
	)

	_expect(
		connection_result.is_success(),
		"DGC-U11: removal fixture connection succeeds"
	)

	var source_remove_result := graph.remove_device(
		SOURCE_DEVICE_ID
	)

	_expect_failure(
		source_remove_result,
		&"device_has_connections",
		"DGC-U11: connected source removal"
	)

	var target_remove_result := graph.remove_device(
		TARGET_DEVICE_ID
	)

	_expect_failure(
		target_remove_result,
		&"device_has_connections",
		"DGC-U11: connected target removal"
	)

	_expect(
		graph.get_devices().size() == 2
		and graph.get_connections().size() == 1,
		"DGC-U11: failed removals preserve Graph"
	)

	var disconnect_result := graph.disconnect_ports(
		connection_result.get_affected_id()
	)

	_expect(
		disconnect_result.is_success(),
		"DGC-U11: connection is removed before Devices"
	)

	var final_source_result := graph.remove_device(
		SOURCE_DEVICE_ID
	)

	var final_target_result := graph.remove_device(
		TARGET_DEVICE_ID
	)

	_expect(
		final_source_result.is_success()
		and final_target_result.is_success(),
		"DGC-U11: disconnected Devices can be removed"
	)

	_expect(
		graph.get_devices().is_empty(),
		"DGC-U11: all disconnected Devices are removed"
	)

	_expect(
		graph.get_topic_channels().is_empty(),
		"DGC-U11: Channels become empty after removals"
	)


# =============================================================================
# COLLECTION COPY
# =============================================================================

func _test_connection_collection_copy() -> void:

	var graph := _default_graph()

	var result := _connect_distance(
		graph
	)

	_expect(
		result.is_success(),
		"DGC-U12: collection fixture connection succeeds"
	)

	var connections_copy := graph.get_connections()

	connections_copy.clear()

	_expect(
		graph.get_connections().size() == 1,
		"DGC-U12: Connections Array is independent"
	)


# =============================================================================
# GRAPH HELPERS
# =============================================================================

func _default_graph() -> DeviceGraphDraft:

	var graph := DeviceGraphDraft.new()

	graph.add_device(
		_sensor_node()
	)

	graph.add_device(
		_controller_node()
	)

	return graph


func _connect_distance(
	graph: DeviceGraphDraft
) -> DeviceGraphOperationResult:

	return graph.connect_ports(
		SOURCE_DEVICE_ID,
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		TARGET_DEVICE_ID,
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)


# =============================================================================
# NODE FIXTURES
# =============================================================================

func _sensor_node() -> DeviceGraphNode:

	var profile := (
		BuiltinDeviceProfiles.create_ideal_distance_sensor()
	)

	var configuration := DeviceConfiguration.new(
		&"test.distance_sensor.configuration",
		1,
		SOURCE_DEVICE_ID,
		profile.get_profile_id(),
		profile.get_profile_version(),
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		[
			"distance_measurement",
			"health_reporting",
		],
		[
			BusTopics.DISTANCE_MEASUREMENT,
			BusTopics.HEALTH_REPORT,
		],
		[],
		[]
	)

	var manifest_result := DeviceManifestBuilder.new().build(
		profile,
		configuration
	)

	var node_result := DeviceGraphNodeBuilder.new().build(
		SOURCE_DEVICE_ID,
		profile,
		configuration,
		manifest_result.get_manifest()
	)

	return node_result.get_node()


func _controller_node() -> DeviceGraphNode:

	var profile := DeviceProfile.new(
		&"test.hover_mcu",
		1,
		"Test Hover MCU",
		"Graph Connection fixture.",
		DeviceRoles.LOCAL_CONTROLLER,
		[
			"hover_control",
		],
		[
			BusTopics.PROPULSION_COMMAND,
		],
		[
			BusTopics.DISTANCE_MEASUREMENT,
			BusTopics.HEALTH_REPORT,
		],
		[],
		false,
		&"",
		0
	)

	var configuration := DeviceConfiguration.new(
		&"test.hover_mcu.configuration",
		1,
		TARGET_DEVICE_ID,
		profile.get_profile_id(),
		profile.get_profile_version(),
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		[
			"hover_control",
		],
		[
			BusTopics.PROPULSION_COMMAND,
		],
		[
			BusTopics.DISTANCE_MEASUREMENT,
			BusTopics.HEALTH_REPORT,
		],
		[]
	)

	var manifest_result := DeviceManifestBuilder.new().build(
		profile,
		configuration
	)

	var node_result := DeviceGraphNodeBuilder.new().build(
		TARGET_DEVICE_ID,
		profile,
		configuration,
		manifest_result.get_manifest()
	)

	return node_result.get_node()


func _copy_node_with_semantics(
	node: DeviceGraphNode,
	input_semantic_kind: StringName,
	output_semantic_kind: StringName
) -> DeviceGraphNode:

	var input_ports: Array[DeviceGraphInputPort] = []

	for port: DeviceGraphInputPort in node.get_input_ports():

		input_ports.append(
			DeviceGraphInputPort.new(
				port.get_port_id(),
				port.get_device_id(),
				port.get_topic(),
				input_semantic_kind
			)
		)

	var output_ports: Array[DeviceGraphOutputPort] = []

	for port: DeviceGraphOutputPort in node.get_output_ports():

		output_ports.append(
			DeviceGraphOutputPort.new(
				port.get_port_id(),
				port.get_device_id(),
				port.get_topic(),
				output_semantic_kind
			)
		)

	return DeviceGraphNode.new(
		node.get_device_id(),
		node.get_primary_role(),
		node.get_profile(),
		node.get_configuration(),
		node.get_manifest(),
		input_ports,
		output_ports
	)


# =============================================================================
# ID HELPERS
# =============================================================================

func _input_port_id(
	topic: StringName
) -> StringName:

	return StringName(
		"in." + String(topic)
	)


func _output_port_id(
	topic: StringName
) -> StringName:

	return StringName(
		"out." + String(topic)
	)


# =============================================================================
# REPORT HELPERS
# =============================================================================

func _report_has_code(
	report: ValidationReport,
	code: StringName
) -> bool:

	for issue: ValidationIssue in report.get_issues():

		if issue.get_code() == code:
			return true

	return false


func _expect_failure(
	result: DeviceGraphOperationResult,
	code: StringName,
	description: String
) -> void:

	_expect(
		not result.is_success(),
		description + " is rejected"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			code
		),
		description + " reports " + String(code)
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
