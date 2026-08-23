extends RefCounted
class_name DeviceGraphNodeBuilder


##
## DeviceGraphNodeBuilder
##
## Construye DeviceGraphNode desde:
##
## - DeviceProfile snapshot;
## - DeviceConfiguration snapshot;
## - DeviceManifest efectivo.
##
## Genera Ports iniciales con Semantic Kind
## UNSPECIFIED.
##


const RESERVED_SEPARATOR: String = "|"


func build(
	device_id: String,
	profile: DeviceProfile,
	configuration: DeviceConfiguration,
	manifest: DeviceManifest
) -> DeviceGraphNodeBuildResult:

	var report := ValidationReport.new()

	if device_id.is_empty():

		_add_structural_error(
			report,
			&"graph_device_id_missing",
			"Device ID is required.",
			device_id,
			&"device_id"
		)

	if device_id.contains(
		RESERVED_SEPARATOR
	):

		_add_structural_error(
			report,
			&"graph_id_contains_reserved_separator",
			"Device ID contains reserved separator.",
			device_id,
			&"device_id"
		)

	if profile == null:

		_add_structural_error(
			report,
			&"graph_profile_missing",
			"DeviceProfile is required.",
			device_id,
			&"profile"
		)

	if configuration == null:

		_add_structural_error(
			report,
			&"graph_configuration_missing",
			"DeviceConfiguration is required.",
			device_id,
			&"configuration"
		)

	if manifest == null:

		_add_structural_error(
			report,
			&"graph_manifest_missing",
			"DeviceManifest is required.",
			device_id,
			&"manifest"
		)

	if profile != null:
		_validate_profile(
			device_id,
			profile,
			report
		)

	if configuration != null:
		_validate_configuration(
			device_id,
			configuration,
			report
		)

	if (
		profile != null
		and configuration != null
	):
		_validate_references(
			device_id,
			profile,
			configuration,
			report
		)

	if manifest != null:
		_validate_manifest(
			device_id,
			manifest,
			report
		)

	if (
		configuration != null
		and manifest != null
	):
		_validate_manifest_matches_configuration(
			device_id,
			configuration,
			manifest,
			report
		)

	if not report.is_valid_for_simulation():

		return DeviceGraphNodeBuildResult.new(
			null,
			report
		)

	var input_ports: Array[DeviceGraphInputPort] = (
		_build_input_ports(
			device_id,
			manifest
		)
	)

	var output_ports: Array[DeviceGraphOutputPort] = (
		_build_output_ports(
			device_id,
			manifest
		)
	)

	var node := DeviceGraphNode.new(
		device_id,
		profile.get_primary_role(),
		profile,
		configuration,
		manifest,
		input_ports,
		output_ports
	)

	if not node.is_valid():

		_add_structural_error(
			report,
			&"graph_node_invalid",
			"Built DeviceGraphNode is invalid.",
			device_id,
			&"node"
		)

		return DeviceGraphNodeBuildResult.new(
			null,
			report
		)

	return DeviceGraphNodeBuildResult.new(
		node,
		report
	)


# =============================================================================
# PROFILE VALIDATION
# =============================================================================

func _validate_profile(
	device_id: String,
	profile: DeviceProfile,
	report: ValidationReport
) -> void:

	if profile.is_valid():
		return

	_add_structural_error(
		report,
		&"graph_profile_invalid",
		"DeviceProfile is invalid.",
		device_id,
		&"profile"
	)


# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================

func _validate_configuration(
	device_id: String,
	configuration: DeviceConfiguration,
	report: ValidationReport
) -> void:

	if not configuration.is_valid():

		_add_structural_error(
			report,
			&"graph_configuration_invalid",
			"DeviceConfiguration is invalid.",
			device_id,
			&"configuration"
		)

		return

	if (
		configuration.get_device_id()
		!= device_id
	):

		_add_structural_error(
			report,
			&"graph_configuration_device_id_mismatch",
			"Configuration Device ID does not match.",
			device_id,
			&"device_id"
		)


# =============================================================================
# REFERENCE VALIDATION
# =============================================================================

func _validate_references(
	device_id: String,
	profile: DeviceProfile,
	configuration: DeviceConfiguration,
	report: ValidationReport
) -> void:

	if (
		configuration.get_profile_id()
		!= profile.get_profile_id()
	):

		_add_structural_error(
			report,
			&"graph_profile_reference_mismatch",
			"Configuration Profile ID does not match.",
			device_id,
			&"profile_id"
		)

	if (
		configuration.get_profile_version()
		!= profile.get_profile_version()
	):

		_add_structural_error(
			report,
			&"graph_profile_reference_mismatch",
			"Configuration Profile version does not match.",
			device_id,
			&"profile_version"
		)


# =============================================================================
# MANIFEST VALIDATION
# =============================================================================

func _validate_manifest(
	device_id: String,
	manifest: DeviceManifest,
	report: ValidationReport
) -> void:

	if _has_duplicates(
		manifest.capabilities
	):

		_add_structural_error(
			report,
			&"graph_manifest_duplicate_capability",
			"Manifest capabilities contain duplicates.",
			device_id,
			&"capabilities"
		)

	if _has_duplicates(
		manifest.publishes
	):

		_add_structural_error(
			report,
			&"graph_manifest_duplicate_publish",
			"Manifest publishes contain duplicates.",
			device_id,
			&"publishes"
		)

	if _has_duplicates(
		manifest.subscribes
	):

		_add_structural_error(
			report,
			&"graph_manifest_duplicate_subscribe",
			"Manifest subscribes contain duplicates.",
			device_id,
			&"subscribes"
		)

	if _has_duplicates(
		manifest.requirements
	):

		_add_structural_error(
			report,
			&"graph_manifest_duplicate_requirement",
			"Manifest requirements contain duplicates.",
			device_id,
			&"requirements"
		)


func _validate_manifest_matches_configuration(
	device_id: String,
	configuration: DeviceConfiguration,
	manifest: DeviceManifest,
	report: ValidationReport
) -> void:

	if (
		manifest.capabilities
		!= configuration.get_enabled_capabilities()
	):

		_add_structural_error(
			report,
			&"graph_manifest_configuration_mismatch",
			"Manifest capabilities do not match Configuration.",
			device_id,
			&"capabilities"
		)

	if (
		manifest.publishes
		!= configuration.get_enabled_publishes()
	):

		_add_structural_error(
			report,
			&"graph_manifest_configuration_mismatch",
			"Manifest publishes do not match Configuration.",
			device_id,
			&"publishes"
		)

	if (
		manifest.subscribes
		!= configuration.get_enabled_subscribes()
	):

		_add_structural_error(
			report,
			&"graph_manifest_configuration_mismatch",
			"Manifest subscribes do not match Configuration.",
			device_id,
			&"subscribes"
		)


# =============================================================================
# PORT GENERATION
# =============================================================================

func _build_input_ports(
	device_id: String,
	manifest: DeviceManifest
) -> Array[DeviceGraphInputPort]:

	var ports: Array[DeviceGraphInputPort] = []

	for topic: StringName in manifest.subscribes:

		var port_id := StringName(
			"in." + String(topic)
		)

		ports.append(
			DeviceGraphInputPort.new(
				port_id,
				device_id,
				topic,
				PortSemanticKinds.UNSPECIFIED
			)
		)

	return ports


func _build_output_ports(
	device_id: String,
	manifest: DeviceManifest
) -> Array[DeviceGraphOutputPort]:

	var ports: Array[DeviceGraphOutputPort] = []

	for topic: StringName in manifest.publishes:

		var port_id := StringName(
			"out." + String(topic)
		)

		ports.append(
			DeviceGraphOutputPort.new(
				port_id,
				device_id,
				topic,
				PortSemanticKinds.UNSPECIFIED
			)
		)

	return ports


# =============================================================================
# HELPERS
# =============================================================================

func _has_duplicates(
	values: Array
) -> bool:

	var seen: Dictionary = {}

	for value: Variant in values:

		if seen.has(value):
			return true

		seen[value] = true

	return false


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
