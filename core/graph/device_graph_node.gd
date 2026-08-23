extends RefCounted
class_name DeviceGraphNode


##
## DeviceGraphNode
##
## Snapshot lógico e inmutable de una
## instancia dentro de DeviceGraph.
##
## No es un Node de Godot.
##


const RESERVED_SEPARATOR: String = "|"


var _device_id: String

var _primary_role: StringName

var _profile: DeviceProfile

var _configuration: DeviceConfiguration

var _manifest: DeviceManifest

var _input_ports: Array[DeviceGraphInputPort] = []

var _output_ports: Array[DeviceGraphOutputPort] = []


func _init(
	device_id: String,
	primary_role: StringName,
	profile: DeviceProfile,
	configuration: DeviceConfiguration,
	manifest: DeviceManifest,
	input_ports: Array[DeviceGraphInputPort] = [],
	output_ports: Array[DeviceGraphOutputPort] = []
) -> void:

	_device_id = device_id

	_primary_role = primary_role

	_profile = profile

	_configuration = configuration

	_manifest = _copy_manifest(manifest)

	_input_ports = input_ports.duplicate()

	_output_ports = output_ports.duplicate()


# =============================================================================
# PUBLIC API
# =============================================================================

func get_device_id() -> String:

	return _device_id


func get_primary_role() -> StringName:

	return _primary_role


func get_profile() -> DeviceProfile:

	return _profile


func get_configuration() -> DeviceConfiguration:

	return _configuration


func get_manifest() -> DeviceManifest:

	return _copy_manifest(_manifest)


func get_input_ports(
) -> Array[DeviceGraphInputPort]:

	return _input_ports.duplicate()


func get_output_ports(
) -> Array[DeviceGraphOutputPort]:

	return _output_ports.duplicate()


func get_input_port(
	port_id: StringName
) -> DeviceGraphInputPort:

	for port: DeviceGraphInputPort in _input_ports:

		if port.get_port_id() == port_id:
			return port

	return null


func get_output_port(
	port_id: StringName
) -> DeviceGraphOutputPort:

	for port: DeviceGraphOutputPort in _output_ports:

		if port.get_port_id() == port_id:
			return port

	return null


# =============================================================================
# VALIDATION
# =============================================================================

func is_valid() -> bool:

	if _device_id.is_empty():
		return false

	if _device_id.contains(
		RESERVED_SEPARATOR
	):
		return false

	if not DeviceRoles.is_valid(
		_primary_role
	):
		return false

	if _profile == null:
		return false

	if not _profile.is_valid():
		return false

	if _configuration == null:
		return false

	if not _configuration.is_valid():
		return false

	if _manifest == null:
		return false

	if (
		_primary_role
		!= _profile.get_primary_role()
	):
		return false

	if (
		_configuration.get_device_id()
		!= _device_id
	):
		return false

	if (
		_configuration.get_profile_id()
		!= _profile.get_profile_id()
	):
		return false

	if (
		_configuration.get_profile_version()
		!= _profile.get_profile_version()
	):
		return false

	if not _manifest_matches_configuration():
		return false

	if not _ports_are_valid():
		return false

	return true


func _manifest_matches_configuration() -> bool:

	if (
		_manifest.capabilities
		!= _configuration.get_enabled_capabilities()
	):
		return false

	if (
		_manifest.publishes
		!= _configuration.get_enabled_publishes()
	):
		return false

	if (
		_manifest.subscribes
		!= _configuration.get_enabled_subscribes()
	):
		return false

	return true


func _ports_are_valid() -> bool:

	var seen_port_ids: Dictionary[StringName, bool] = {}

	for port: DeviceGraphInputPort in _input_ports:

		if port == null:
			return false

		if not port.is_valid():
			return false

		if port.get_device_id() != _device_id:
			return false

		if seen_port_ids.has(
			port.get_port_id()
		):
			return false

		if not _manifest.subscribes.has(
			port.get_topic()
		):
			return false

		seen_port_ids[
			port.get_port_id()
		] = true

	for port: DeviceGraphOutputPort in _output_ports:

		if port == null:
			return false

		if not port.is_valid():
			return false

		if port.get_device_id() != _device_id:
			return false

		if seen_port_ids.has(
			port.get_port_id()
		):
			return false

		if not _manifest.publishes.has(
			port.get_topic()
		):
			return false

		seen_port_ids[
			port.get_port_id()
		] = true

	return true


# =============================================================================
# MANIFEST COPY
# =============================================================================

func _copy_manifest(
	source: DeviceManifest
) -> DeviceManifest:

	if source == null:
		return null

	var manifest_copy := DeviceManifest.new()

	manifest_copy.capabilities = (
		source.capabilities.duplicate()
	)

	manifest_copy.publishes = (
		source.publishes.duplicate()
	)

	manifest_copy.subscribes = (
		source.subscribes.duplicate()
	)

	manifest_copy.requirements = (
		source.requirements.duplicate()
	)

	return manifest_copy
