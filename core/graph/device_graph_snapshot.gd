extends RefCounted
class_name DeviceGraphSnapshot


##
## DeviceGraphSnapshot
##
## Topología lógica validada e inmutable.
##
## Representa estructura.
## No representa ejecución.
##


var _devices: Array[DeviceGraphNode] = []

var _connections: Array[DeviceGraphConnection] = []

var _topic_channels: Array[DeviceGraphTopicChannel] = []


func _init(
	devices: Array[DeviceGraphNode] = [],
	connections: Array[DeviceGraphConnection] = [],
	topic_channels: Array[DeviceGraphTopicChannel] = []
) -> void:

	_devices = devices.duplicate()

	_connections = connections.duplicate()

	_topic_channels = topic_channels.duplicate()


# =============================================================================
# COLLECTION API
# =============================================================================

func get_devices(
) -> Array[DeviceGraphNode]:

	return _devices.duplicate()


func get_connections(
) -> Array[DeviceGraphConnection]:

	return _connections.duplicate()


func get_topic_channels(
) -> Array[DeviceGraphTopicChannel]:

	return _topic_channels.duplicate()


# =============================================================================
# LOOKUP API
# =============================================================================

func get_device(
	device_id: String
) -> DeviceGraphNode:

	for node: DeviceGraphNode in _devices:

		if node == null:
			continue

		if node.get_device_id() == device_id:
			return node

	return null


func get_connection(
	connection_id: StringName
) -> DeviceGraphConnection:

	for connection: DeviceGraphConnection in _connections:

		if connection == null:
			continue

		if (
			connection.get_connection_id()
			== connection_id
		):

			return connection

	return null


# =============================================================================
# VALIDATION
# =============================================================================

func is_valid(
) -> bool:

	var validator := DeviceGraphValidator.new()

	var report := validator.validate(
		get_devices(),
		get_connections(),
		get_topic_channels()
	)

	return report.is_valid_for_simulation()
