extends RefCounted
class_name DeviceGraphValidator


##
## DeviceGraphValidator
##
## Examina una topología lógica completa
## sin modificarla y produce ValidationReport.
##
## La detección de ciclos es iterativa.
##


const CONNECTION_ID_SEPARATOR: String = "|"


func validate(
	devices: Array[DeviceGraphNode],
	connections: Array[DeviceGraphConnection],
	topic_channels: Array[DeviceGraphTopicChannel]
) -> ValidationReport:

	var report := ValidationReport.new()

	var devices_by_id := _validate_devices(
		devices,
		report
	)

	var channels_by_topic := _validate_topic_channels(
		topic_channels,
		report
	)

	var connected_input_keys: Dictionary = {}
	var connected_output_keys: Dictionary = {}
	var valid_edges: Array[Dictionary] = []

	_validate_connections(
		connections,
		devices_by_id,
		connected_input_keys,
		connected_output_keys,
		valid_edges,
		report
	)

	_validate_topic_channel_registry(
		devices,
		connections,
		topic_channels,
		channels_by_topic,
		report
	)

	_validate_unconnected_ports(
		devices,
		connected_input_keys,
		connected_output_keys,
		report
	)

	_detect_cycles(
		devices,
		valid_edges,
		report
	)

	return report


# =============================================================================
# DEVICE VALIDATION
# =============================================================================

func _validate_devices(
	devices: Array[DeviceGraphNode],
	report: ValidationReport
) -> Dictionary:

	var devices_by_id: Dictionary = {}

	for device_index: int in range(
		devices.size()
	):

		var node: DeviceGraphNode = devices[
			device_index
		]

		if node == null:

			_add_structural_error(
				report,
				&"graph_node_missing",
				"DeviceGraphNode is required.",
				str(device_index),
				&"devices"
			)

			continue

		var device_id: String = node.get_device_id()

		if device_id.is_empty():

			_add_structural_error(
				report,
				&"graph_device_id_missing",
				"Device ID is required.",
				str(device_index),
				&"device_id"
			)

		elif devices_by_id.has(device_id):

			_add_structural_error(
				report,
				&"duplicate_device_id",
				"Device ID is duplicated in Graph.",
				device_id,
				&"device_id"
			)

		else:

			devices_by_id[device_id] = node

		if not node.is_valid():

			_add_structural_error(
				report,
				&"graph_node_invalid",
				"DeviceGraphNode is invalid.",
				device_id,
				&"node"
			)

		_validate_stream_ownership(
			node,
			report
		)

	return devices_by_id


func _validate_stream_ownership(
	node: DeviceGraphNode,
	report: ValidationReport
) -> void:

	var seen_output_topics: Dictionary = {}
	var device_id: String = node.get_device_id()

	for output_port: DeviceGraphOutputPort in node.get_output_ports():

		if output_port == null:
			continue

		var topic: StringName = output_port.get_topic()

		if seen_output_topics.has(topic):

			_add_structural_error(
				report,
				&"duplicate_stream_owner",
				"Device declares duplicate ownership for Topic.",
				device_id,
				&"publishes"
			)

			continue

		seen_output_topics[topic] = true


# =============================================================================
# TOPIC CHANNEL VALIDATION
# =============================================================================

func _validate_topic_channels(
	topic_channels: Array[DeviceGraphTopicChannel],
	report: ValidationReport
) -> Dictionary:

	var channels_by_topic: Dictionary = {}

	for channel_index: int in range(
		topic_channels.size()
	):

		var channel: DeviceGraphTopicChannel = topic_channels[
			channel_index
		]

		if channel == null:

			_add_structural_error(
				report,
				&"topic_channel_missing",
				"DeviceGraphTopicChannel is required.",
				str(channel_index),
				&"topic_channels"
			)

			continue

		var topic: StringName = channel.get_topic()

		if not channel.is_valid():

			_add_structural_error(
				report,
				&"topic_channel_invalid",
				"DeviceGraphTopicChannel is invalid.",
				String(topic),
				&"topic"
			)

		if channels_by_topic.has(topic):

			_add_structural_error(
				report,
				&"duplicate_topic_channel",
				"TopicChannel is duplicated.",
				String(topic),
				&"topic_channels"
			)

		else:

			channels_by_topic[topic] = channel

	return channels_by_topic


func _validate_topic_channel_registry(
	devices: Array[DeviceGraphNode],
	connections: Array[DeviceGraphConnection],
	topic_channels: Array[DeviceGraphTopicChannel],
	channels_by_topic: Dictionary,
	report: ValidationReport
) -> void:

	var expected_topics: Dictionary = {}

	for node: DeviceGraphNode in devices:

		if node == null:
			continue

		for input_port: DeviceGraphInputPort in node.get_input_ports():

			if input_port == null:
				continue

			var input_topic: StringName = input_port.get_topic()

			if input_topic != &"":
				expected_topics[input_topic] = true

		for output_port: DeviceGraphOutputPort in node.get_output_ports():

			if output_port == null:
				continue

			var output_topic: StringName = output_port.get_topic()

			if output_topic != &"":
				expected_topics[output_topic] = true

	for connection: DeviceGraphConnection in connections:

		if connection == null:
			continue

		var connection_topic: StringName = connection.get_topic()

		if connection_topic != &"":
			expected_topics[connection_topic] = true

	for expected_topic: StringName in expected_topics.keys():

		if channels_by_topic.has(expected_topic):
			continue

		_add_structural_error(
			report,
			&"topic_channel_registry_mismatch",
			"Required TopicChannel is missing.",
			String(expected_topic),
			&"topic_channels"
		)

	for channel: DeviceGraphTopicChannel in topic_channels:

		if channel == null:
			continue

		var actual_topic: StringName = channel.get_topic()

		if expected_topics.has(actual_topic):
			continue

		_add_structural_error(
			report,
			&"topic_channel_registry_mismatch",
			"TopicChannel is not used by Graph topology.",
			String(actual_topic),
			&"topic_channels"
		)


# =============================================================================
# CONNECTION VALIDATION
# =============================================================================

func _validate_connections(
	connections: Array[DeviceGraphConnection],
	devices_by_id: Dictionary,
	connected_input_keys: Dictionary,
	connected_output_keys: Dictionary,
	valid_edges: Array[Dictionary],
	report: ValidationReport
) -> void:

	var connections_by_id: Dictionary = {}
	var incoming_by_target_key: Dictionary = {}

	for connection_index: int in range(
		connections.size()
	):

		var connection: DeviceGraphConnection = connections[
			connection_index
		]

		if connection == null:

			_add_structural_error(
				report,
				&"connection_missing",
				"DeviceGraphConnection is required.",
				str(connection_index),
				&"connections"
			)

			continue

		var connection_is_valid: bool = true
		var connection_id: StringName = connection.get_connection_id()
		var source_device_id: String = connection.get_source_device_id()
		var source_port_id: StringName = connection.get_source_port_id()
		var target_device_id: String = connection.get_target_device_id()
		var target_port_id: StringName = connection.get_target_port_id()
		var topic: StringName = connection.get_topic()

		if not connection.is_valid_identity():

			_add_structural_error(
				report,
				&"connection_identity_invalid",
				"Connection identity is invalid.",
				String(connection_id),
				&"connection"
			)

			connection_is_valid = false

		if connections_by_id.has(connection_id):

			_add_structural_error(
				report,
				&"duplicate_connection_id",
				"Connection ID is duplicated.",
				String(connection_id),
				&"connection_id"
			)

			connection_is_valid = false

		else:

			connections_by_id[connection_id] = connection

		var expected_connection_id := _build_connection_id(
			source_device_id,
			source_port_id,
			target_device_id,
			target_port_id
		)

		if connection_id != expected_connection_id:

			_add_structural_error(
				report,
				&"connection_id_mismatch",
				"Connection ID does not match its endpoints.",
				String(connection_id),
				&"connection_id"
			)

			connection_is_valid = false

		var source_node: DeviceGraphNode = devices_by_id.get(
			source_device_id,
			null
		)

		var target_node: DeviceGraphNode = devices_by_id.get(
			target_device_id,
			null
		)

		if source_node == null:

			_add_structural_error(
				report,
				&"source_device_not_found",
				"Source Device does not exist.",
				source_device_id,
				&"source_device_id"
			)

			connection_is_valid = false

		if target_node == null:

			_add_structural_error(
				report,
				&"target_device_not_found",
				"Target Device does not exist.",
				target_device_id,
				&"target_device_id"
			)

			connection_is_valid = false

		if source_device_id == target_device_id:

			_add_structural_error(
				report,
				&"self_connection_not_supported",
				"Self-connections are not supported.",
				source_device_id,
				&"connection"
			)

			connection_is_valid = false

		var source_port: DeviceGraphOutputPort = null
		var target_port: DeviceGraphInputPort = null

		if source_node != null:

			source_port = source_node.get_output_port(
				source_port_id
			)

			if source_port == null:

				_add_structural_error(
					report,
					&"source_port_not_found",
					"Source OutputPort does not exist.",
					source_device_id,
					&"source_port_id"
				)

				connection_is_valid = false

		if target_node != null:

			target_port = target_node.get_input_port(
				target_port_id
			)

			if target_port == null:

				_add_structural_error(
					report,
					&"target_port_not_found",
					"Target InputPort does not exist.",
					target_device_id,
					&"target_port_id"
				)

				connection_is_valid = false

		if (
			source_port != null
			and target_port != null
		):

			if (
				source_port.get_topic() != target_port.get_topic()
				or topic != source_port.get_topic()
			):

				_add_structural_error(
					report,
					&"connection_topic_mismatch",
					"Connection topics do not match.",
					String(connection_id),
					&"topic"
				)

				connection_is_valid = false

			if not _semantic_kinds_are_compatible(
				source_port.get_semantic_kind(),
				target_port.get_semantic_kind()
			):

				_add_structural_error(
					report,
					&"connection_semantic_mismatch",
					"Connection semantic kinds do not match.",
					String(connection_id),
					&"semantic_kind"
				)

				connection_is_valid = false

		if not connection_is_valid:
			continue

		var target_key := _build_endpoint_key(
			target_device_id,
			target_port_id
		)

		if incoming_by_target_key.has(target_key):

			_add_structural_error(
				report,
				&"input_port_multiple_sources",
				"InputPort has multiple source Connections.",
				target_device_id,
				&"target_port_id"
			)

			continue

		incoming_by_target_key[target_key] = connection_id
		connected_input_keys[target_key] = true

		var source_key := _build_endpoint_key(
			source_device_id,
			source_port_id
		)

		connected_output_keys[source_key] = true

		valid_edges.append(
			{
				"source": source_device_id,
				"target": target_device_id,
			}
		)


# =============================================================================
# UNCONNECTED PORTS
# =============================================================================

func _validate_unconnected_ports(
	devices: Array[DeviceGraphNode],
	connected_input_keys: Dictionary,
	connected_output_keys: Dictionary,
	report: ValidationReport
) -> void:

	for node: DeviceGraphNode in devices:

		if node == null:
			continue

		var device_id: String = node.get_device_id()

		for input_port: DeviceGraphInputPort in node.get_input_ports():

			if input_port == null:
				continue

			var input_key := _build_endpoint_key(
				device_id,
				input_port.get_port_id()
			)

			if connected_input_keys.has(input_key):
				continue

			_add_issue(
				report,
				&"input_port_unconnected",
				ValidationIssue.Severity.WARNING,
				"InputPort has no Connection.",
				device_id,
				input_port.get_port_id()
			)

		for output_port: DeviceGraphOutputPort in node.get_output_ports():

			if output_port == null:
				continue

			var output_key := _build_endpoint_key(
				device_id,
				output_port.get_port_id()
			)

			if connected_output_keys.has(output_key):
				continue

			_add_issue(
				report,
				&"output_port_unconnected",
				ValidationIssue.Severity.INFO,
				"OutputPort has no Connection.",
				device_id,
				output_port.get_port_id()
			)


# =============================================================================
# ITERATIVE CYCLE DETECTION
# =============================================================================

func _detect_cycles(
	devices: Array[DeviceGraphNode],
	valid_edges: Array[Dictionary],
	report: ValidationReport
) -> void:

	var device_order: Array[String] = []
	var known_device_ids: Dictionary = {}
	var adjacency: Dictionary = {}
	var reverse_adjacency: Dictionary = {}

	for node: DeviceGraphNode in devices:

		if node == null:
			continue

		var device_id: String = node.get_device_id()

		if (
			device_id.is_empty()
			or known_device_ids.has(device_id)
		):

			continue

		known_device_ids[device_id] = true
		device_order.append(device_id)
		adjacency[device_id] = []
		reverse_adjacency[device_id] = []

	for edge: Dictionary in valid_edges:

		var source_device_id: String = edge.get(
			"source",
			""
		)

		var target_device_id: String = edge.get(
			"target",
			""
		)

		if (
			not adjacency.has(source_device_id)
			or not adjacency.has(target_device_id)
		):

			continue

		var targets: Array = adjacency[source_device_id]

		if not targets.has(target_device_id):
			targets.append(target_device_id)

		adjacency[source_device_id] = targets

		var sources: Array = reverse_adjacency[target_device_id]

		if not sources.has(source_device_id):
			sources.append(source_device_id)

		reverse_adjacency[target_device_id] = sources

	var finish_order := _build_finish_order(
		device_order,
		adjacency
	)

	var assigned: Dictionary = {}

	for order_index: int in range(
		finish_order.size() - 1,
		-1,
		-1
	):

		var start_device_id: String = finish_order[
			order_index
		]

		if assigned.has(start_device_id):
			continue

		var component := _collect_component(
			start_device_id,
			reverse_adjacency,
			assigned
		)

		if not _component_is_cyclic(
			component,
			adjacency
		):

			continue

		component.sort()

		var component_text := _join_device_ids(
			component
		)

		_add_issue(
			report,
			&"graph_cycle_requires_temporal_analysis",
			ValidationIssue.Severity.SIMULATION_HAZARD,
			"Graph cycle requires temporal analysis: "
			+ component_text
			+ ".",
			component[0],
			&"connections"
		)


func _build_finish_order(
	device_order: Array[String],
	adjacency: Dictionary
) -> Array[String]:

	var visited: Dictionary = {}
	var finish_order: Array[String] = []

	for start_device_id: String in device_order:

		if visited.has(start_device_id):
			continue

		visited[start_device_id] = true

		var device_stack: Array[String] = [
			start_device_id,
		]

		var neighbor_index_stack: Array[int] = [
			0,
		]

		while not device_stack.is_empty():

			var stack_index: int = (
				device_stack.size() - 1
			)

			var current_device_id: String = (
				device_stack[stack_index]
			)

			var neighbor_index: int = (
				neighbor_index_stack[stack_index]
			)

			var neighbors: Array = adjacency.get(
				current_device_id,
				[]
			)

			if neighbor_index < neighbors.size():

				var next_device_id: String = neighbors[
					neighbor_index
				]

				neighbor_index_stack[stack_index] = (
					neighbor_index + 1
				)

				if visited.has(next_device_id):
					continue

				visited[next_device_id] = true
				device_stack.append(next_device_id)
				neighbor_index_stack.append(0)

				continue

			finish_order.append(current_device_id)
			device_stack.pop_back()
			neighbor_index_stack.pop_back()

	return finish_order


func _collect_component(
	start_device_id: String,
	reverse_adjacency: Dictionary,
	assigned: Dictionary
) -> Array[String]:

	var component: Array[String] = []

	var device_stack: Array[String] = [
		start_device_id,
	]

	assigned[start_device_id] = true

	while not device_stack.is_empty():

		var current_device_id: String = (
			device_stack.pop_back()
		)

		component.append(current_device_id)

		var neighbors: Array = reverse_adjacency.get(
			current_device_id,
			[]
		)

		for neighbor_value: Variant in neighbors:

			var next_device_id: String = String(
				neighbor_value
			)

			if assigned.has(next_device_id):
				continue

			assigned[next_device_id] = true
			device_stack.append(next_device_id)

	return component


func _component_is_cyclic(
	component: Array[String],
	adjacency: Dictionary
) -> bool:

	if component.size() > 1:
		return true

	if component.is_empty():
		return false

	var device_id: String = component[0]

	var neighbors: Array = adjacency.get(
		device_id,
		[]
	)

	return neighbors.has(device_id)


func _join_device_ids(
	device_ids: Array[String]
) -> String:

	var result: String = ""

	for device_id: String in device_ids:

		if not result.is_empty():
			result += ", "

		result += device_id

	return result


# =============================================================================
# ID AND SEMANTIC HELPERS
# =============================================================================

func _build_connection_id(
	source_device_id: String,
	source_port_id: StringName,
	target_device_id: String,
	target_port_id: StringName
) -> StringName:

	var id_text: String = (
		source_device_id
		+ CONNECTION_ID_SEPARATOR
		+ String(source_port_id)
		+ CONNECTION_ID_SEPARATOR
		+ target_device_id
		+ CONNECTION_ID_SEPARATOR
		+ String(target_port_id)
	)

	return StringName(id_text)


func _build_endpoint_key(
	device_id: String,
	port_id: StringName
) -> String:

	return (
		device_id
		+ CONNECTION_ID_SEPARATOR
		+ String(port_id)
	)


func _semantic_kinds_are_compatible(
	source_kind: StringName,
	target_kind: StringName
) -> bool:

	if source_kind == PortSemanticKinds.UNSPECIFIED:
		return true

	if target_kind == PortSemanticKinds.UNSPECIFIED:
		return true

	return source_kind == target_kind


# =============================================================================
# ISSUE HELPERS
# =============================================================================

func _add_structural_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> void:

	_add_issue(
		report,
		code,
		ValidationIssue.Severity.STRUCTURAL_ERROR,
		message,
		related_object_id,
		related_field
	)


func _add_issue(
	report: ValidationReport,
	code: StringName,
	severity: int,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			severity,
			message,
			related_object_id,
			related_field
		)
	)
