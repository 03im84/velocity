extends RefCounted
class_name DeviceGraphDraft


##
## DeviceGraphDraft
##
## Topología lógica editable mediante
## operaciones transaccionales.
##
## Implementa:
##
## - add/remove Device;
## - connect/disconnect;
## - queries;
## - TopicChannels derivados.
##


const CONNECTION_ID_SEPARATOR: String = "|"


var _devices_by_id: Dictionary[String, DeviceGraphNode] = {}

var _connections_by_id: Dictionary[StringName, DeviceGraphConnection] = {}

var _topic_channels_by_topic: Dictionary[StringName, DeviceGraphTopicChannel] = {}


# =============================================================================
# DEVICE API
# =============================================================================

func add_device(
	node: DeviceGraphNode
) -> DeviceGraphOperationResult:

	var report := ValidationReport.new()

	if node == null:

		_add_structural_error(
			report,
			&"graph_node_missing",
			"DeviceGraphNode is required.",
			"",
			&"node"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	if not node.is_valid():

		_add_structural_error(
			report,
			&"graph_node_invalid",
			"DeviceGraphNode is invalid.",
			node.get_device_id(),
			&"node"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	var device_id: String = node.get_device_id()

	if _devices_by_id.has(device_id):

		_add_structural_error(
			report,
			&"duplicate_device_id",
			"Device ID already exists in Graph.",
			device_id,
			&"device_id"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	_devices_by_id[device_id] = node

	_rebuild_topic_channels()

	return DeviceGraphOperationResult.new(
		true,
		StringName(device_id),
		report
	)


func remove_device(
	device_id: String
) -> DeviceGraphOperationResult:

	var report := ValidationReport.new()

	if not _devices_by_id.has(device_id):

		_add_structural_error(
			report,
			&"device_not_found",
			"Device does not exist in Graph.",
			device_id,
			&"device_id"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	if _device_has_connections(device_id):

		_add_structural_error(
			report,
			&"device_has_connections",
			"Connected Device cannot be removed.",
			device_id,
			&"device_id"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	_devices_by_id.erase(device_id)

	_rebuild_topic_channels()

	return DeviceGraphOperationResult.new(
		true,
		StringName(device_id),
		report
	)


func get_device(
	device_id: String
) -> DeviceGraphNode:

	return _devices_by_id.get(
		device_id,
		null
	)


func has_device(
	device_id: String
) -> bool:

	return _devices_by_id.has(device_id)


func get_devices(
) -> Array[DeviceGraphNode]:

	var devices: Array[DeviceGraphNode] = []

	for node: DeviceGraphNode in _devices_by_id.values():

		devices.append(node)

	return devices


# =============================================================================
# CONNECTION API
# =============================================================================

func connect_ports(
	source_device_id: String,
	source_port_id: StringName,
	target_device_id: String,
	target_port_id: StringName
) -> DeviceGraphOperationResult:

	var report := ValidationReport.new()

	if _identifier_contains_reserved_separator(
		source_device_id
	):

		_add_structural_error(
			report,
			&"graph_id_contains_reserved_separator",
			"Source Device ID contains reserved separator.",
			source_device_id,
			&"source_device_id"
		)

	if _identifier_contains_reserved_separator(
		String(source_port_id)
	):

		_add_structural_error(
			report,
			&"graph_id_contains_reserved_separator",
			"Source Port ID contains reserved separator.",
			source_device_id,
			&"source_port_id"
		)

	if _identifier_contains_reserved_separator(
		target_device_id
	):

		_add_structural_error(
			report,
			&"graph_id_contains_reserved_separator",
			"Target Device ID contains reserved separator.",
			target_device_id,
			&"target_device_id"
		)

	if _identifier_contains_reserved_separator(
		String(target_port_id)
	):

		_add_structural_error(
			report,
			&"graph_id_contains_reserved_separator",
			"Target Port ID contains reserved separator.",
			target_device_id,
			&"target_port_id"
		)

	if not report.is_valid_for_simulation():

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	if not _devices_by_id.has(
		source_device_id
	):

		_add_structural_error(
			report,
			&"source_device_not_found",
			"Source Device does not exist.",
			source_device_id,
			&"source_device_id"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	if not _devices_by_id.has(
		target_device_id
	):

		_add_structural_error(
			report,
			&"target_device_not_found",
			"Target Device does not exist.",
			target_device_id,
			&"target_device_id"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	if source_device_id == target_device_id:

		_add_structural_error(
			report,
			&"self_connection_not_supported",
			"Self-connections are not supported.",
			source_device_id,
			&"connection"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	var source_node: DeviceGraphNode = (
		_devices_by_id[source_device_id]
	)

	var target_node: DeviceGraphNode = (
		_devices_by_id[target_device_id]
	)

	var source_port: DeviceGraphOutputPort = (
		source_node.get_output_port(
			source_port_id
		)
	)

	if source_port == null:

		_add_structural_error(
			report,
			&"source_port_not_found",
			"Source OutputPort does not exist.",
			source_device_id,
			&"source_port_id"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	var target_port: DeviceGraphInputPort = (
		target_node.get_input_port(
			target_port_id
		)
	)

	if target_port == null:

		_add_structural_error(
			report,
			&"target_port_not_found",
			"Target InputPort does not exist.",
			target_device_id,
			&"target_port_id"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	if source_port.get_topic() != target_port.get_topic():

		_add_structural_error(
			report,
			&"connection_topic_mismatch",
			"Source and Target topics do not match.",
			source_device_id,
			&"topic"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	if not _semantic_kinds_are_compatible(
		source_port.get_semantic_kind(),
		target_port.get_semantic_kind()
	):

		_add_structural_error(
			report,
			&"connection_semantic_mismatch",
			"Source and Target semantic kinds do not match.",
			source_device_id,
			&"semantic_kind"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	var connection_id: StringName = (
		_build_connection_id(
			source_device_id,
			source_port_id,
			target_device_id,
			target_port_id
		)
	)

	if _connections_by_id.has(
		connection_id
	):

		_add_structural_error(
			report,
			&"duplicate_connection",
			"Connection already exists.",
			String(connection_id),
			&"connection_id"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)
		
	if _input_port_has_connection(
		target_device_id,
		target_port_id
		):

		_add_structural_error(
			report,
			&"input_port_multiple_sources",
			"InputPort already has a source Connection.",
			target_device_id,
			&"target_port_id"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	var connection := DeviceGraphConnection.new(
		connection_id,
		source_device_id,
		source_port_id,
		source_port.get_topic(),
		target_device_id,
		target_port_id
	)

	if not connection.is_valid_identity():

		_add_structural_error(
			report,
			&"connection_identity_invalid",
			"Generated Connection identity is invalid.",
			String(connection_id),
			&"connection"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	_connections_by_id[connection_id] = connection

	_rebuild_topic_channels()

	return DeviceGraphOperationResult.new(
		true,
		connection_id,
		report
	)


func disconnect_ports(
	connection_id: StringName
) -> DeviceGraphOperationResult:

	var report := ValidationReport.new()

	if not _connections_by_id.has(
		connection_id
	):

		_add_structural_error(
			report,
			&"connection_not_found",
			"Connection does not exist.",
			String(connection_id),
			&"connection_id"
		)

		return DeviceGraphOperationResult.new(
			false,
			&"",
			report
		)

	_connections_by_id.erase(
		connection_id
	)

	_rebuild_topic_channels()

	return DeviceGraphOperationResult.new(
		true,
		connection_id,
		report
	)


func get_connection(
	connection_id: StringName
) -> DeviceGraphConnection:

	return _connections_by_id.get(
		connection_id,
		null
	)


func has_connection(
	connection_id: StringName
) -> bool:

	return _connections_by_id.has(
		connection_id
	)


func get_connections(
) -> Array[DeviceGraphConnection]:

	var connections: Array[DeviceGraphConnection] = []

	for connection: DeviceGraphConnection in _connections_by_id.values():

		connections.append(connection)

	return connections


# =============================================================================
# TOPIC CHANNEL API
# =============================================================================

func get_topic_channel(
	topic: StringName
) -> DeviceGraphTopicChannel:

	return _topic_channels_by_topic.get(
		topic,
		null
	)


func get_topic_channels(
) -> Array[DeviceGraphTopicChannel]:

	var channels: Array[DeviceGraphTopicChannel] = []

	for channel: DeviceGraphTopicChannel in _topic_channels_by_topic.values():

		channels.append(channel)

	return channels


# =============================================================================
# VALIDATION API
# =============================================================================

func validate(
) -> ValidationReport:

	var validator := DeviceGraphValidator.new()

	return validator.validate(
		get_devices(),
		get_connections(),
		get_topic_channels()
	)


# =============================================================================
# CONNECTION HELPERS
# =============================================================================

func _input_port_has_connection(
	target_device_id: String,
	target_port_id: StringName
) -> bool:

	for connection: DeviceGraphConnection in _connections_by_id.values():

		if (
			connection.get_target_device_id()
			== target_device_id
			and connection.get_target_port_id()
			== target_port_id
		):

			return true

	return false

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


func _semantic_kinds_are_compatible(
	source_kind: StringName,
	target_kind: StringName
) -> bool:

	if (
		source_kind
		== PortSemanticKinds.UNSPECIFIED
	):

		return true

	if (
		target_kind
		== PortSemanticKinds.UNSPECIFIED
	):

		return true

	return source_kind == target_kind


func _identifier_contains_reserved_separator(
	identifier: String
) -> bool:

	return identifier.contains(
		CONNECTION_ID_SEPARATOR
	)


func _device_has_connections(
	device_id: String
) -> bool:

	for connection: DeviceGraphConnection in _connections_by_id.values():

		if (
			connection.get_source_device_id()
			== device_id
		):

			return true

		if (
			connection.get_target_device_id()
			== device_id
		):

			return true

	return false


# =============================================================================
# TOPIC CHANNEL REBUILD
# =============================================================================

func _rebuild_topic_channels() -> void:

	var rebuilt_channels: Dictionary[StringName, DeviceGraphTopicChannel] = {}

	for node: DeviceGraphNode in _devices_by_id.values():

		for input_port: DeviceGraphInputPort in node.get_input_ports():

			_ensure_topic_channel(
				rebuilt_channels,
				input_port.get_topic()
			)

		for output_port: DeviceGraphOutputPort in node.get_output_ports():

			_ensure_topic_channel(
				rebuilt_channels,
				output_port.get_topic()
			)

	for connection: DeviceGraphConnection in _connections_by_id.values():

		_ensure_topic_channel(
			rebuilt_channels,
			connection.get_topic()
		)

	_topic_channels_by_topic = rebuilt_channels


func _ensure_topic_channel(
	channels: Dictionary,
	topic: StringName
) -> void:

	if channels.has(topic):
		return

	channels[topic] = (
		DeviceGraphTopicChannel.new(topic)
	)


# =============================================================================
# VALIDATION HELPERS
# =============================================================================

func _add_structural_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			message,
			related_object_id,
			related_field
		)
	)
