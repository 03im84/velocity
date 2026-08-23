extends Node


##
## DeviceGraphNodeBuilderTest
##
## Verifica validación, generación de Ports,
## snapshots y copias de DeviceGraphNode.
##


const DEVICE_ID: String = "hover_mcu"


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceGraphNodeBuilderTest")
	print("========================================")

	_test_null_arguments()
	_test_invalid_device_ids()
	_test_reference_mismatches()
	_test_manifest_duplicates()
	_test_manifest_configuration_mismatch()
	_test_valid_build()
	_test_collection_independence()
	_test_immutable_api()

	_finish_test()


# =============================================================================
# NULL ARGUMENTS
# =============================================================================

func _test_null_arguments() -> void:

	var profile := _profile()

	var configuration := _configuration(
		profile
	)

	var manifest := _manifest(
		profile,
		configuration
	)

	var builder := DeviceGraphNodeBuilder.new()

	var no_profile := builder.build(
		DEVICE_ID,
		null,
		configuration,
		manifest
	)

	_expect(
		not no_profile.is_success(),
		"DGN-U01: null Profile fails"
	)

	_expect(
		_report_has_code(
			no_profile.get_report(),
			&"graph_profile_missing"
		),
		"DGN-U01: missing Profile code is reported"
	)

	var no_configuration := builder.build(
		DEVICE_ID,
		profile,
		null,
		manifest
	)

	_expect(
		not no_configuration.is_success(),
		"DGN-U01: null Configuration fails"
	)

	_expect(
		_report_has_code(
			no_configuration.get_report(),
			&"graph_configuration_missing"
		),
		"DGN-U01: missing Configuration code is reported"
	)

	var no_manifest := builder.build(
		DEVICE_ID,
		profile,
		configuration,
		null
	)

	_expect(
		not no_manifest.is_success(),
		"DGN-U01: null Manifest fails"
	)

	_expect(
		_report_has_code(
			no_manifest.get_report(),
			&"graph_manifest_missing"
		),
		"DGN-U01: missing Manifest code is reported"
	)


# =============================================================================
# DEVICE ID
# =============================================================================

func _test_invalid_device_ids() -> void:

	var profile := _profile()

	var configuration := _configuration(
		profile
	)

	var manifest := _manifest(
		profile,
		configuration
	)

	var builder := DeviceGraphNodeBuilder.new()

	var empty_id_result := builder.build(
		"",
		profile,
		configuration,
		manifest
	)

	_expect(
		not empty_id_result.is_success(),
		"DGN-U02: empty Device ID fails"
	)

	_expect(
		_report_has_code(
			empty_id_result.get_report(),
			&"graph_device_id_missing"
		),
		"DGN-U02: missing Device ID code is reported"
	)

	var separator_result := builder.build(
		"hover|mcu",
		profile,
		configuration,
		manifest
	)

	_expect(
		not separator_result.is_success(),
		"DGN-U02: reserved separator fails"
	)

	_expect(
		_report_has_code(
			separator_result.get_report(),
			&"graph_id_contains_reserved_separator"
		),
		"DGN-U02: separator code is reported"
	)


# =============================================================================
# REFERENCES
# =============================================================================

func _test_reference_mismatches() -> void:

	var profile := _profile()

	var configuration := _configuration(
		profile
	)

	var manifest := _manifest(
		profile,
		configuration
	)

	var builder := DeviceGraphNodeBuilder.new()

	var other_profile := (
		BuiltinDeviceProfiles.create_ideal_distance_sensor()
	)

	var profile_mismatch := builder.build(
		DEVICE_ID,
		other_profile,
		configuration,
		manifest
	)

	_expect(
		not profile_mismatch.is_success(),
		"DGN-U03: Profile reference mismatch fails"
	)

	_expect(
		_report_has_code(
			profile_mismatch.get_report(),
			&"graph_profile_reference_mismatch"
		),
		"DGN-U03: Profile mismatch code is reported"
	)

	var device_id_mismatch := builder.build(
		"other_hover_mcu",
		profile,
		configuration,
		manifest
	)

	_expect(
		not device_id_mismatch.is_success(),
		"DGN-U03: Configuration Device ID mismatch fails"
	)

	_expect(
		_report_has_code(
			device_id_mismatch.get_report(),
			&"graph_configuration_device_id_mismatch"
		),
		"DGN-U03: Device ID mismatch code is reported"
	)


# =============================================================================
# MANIFEST DUPLICATES
# =============================================================================

func _test_manifest_duplicates() -> void:

	var profile := _profile()

	var configuration := _configuration(
		profile
	)

	var builder := DeviceGraphNodeBuilder.new()

	var duplicate_publish_manifest := _manifest(
		profile,
		configuration
	)

	duplicate_publish_manifest.publishes.append(
		BusTopics.PROPULSION_COMMAND
	)

	var duplicate_publish := builder.build(
		DEVICE_ID,
		profile,
		configuration,
		duplicate_publish_manifest
	)

	_expect(
		not duplicate_publish.is_success(),
		"DGN-U04: duplicate publish fails"
	)

	_expect(
		_report_has_code(
			duplicate_publish.get_report(),
			&"graph_manifest_duplicate_publish"
		),
		"DGN-U04: duplicate publish code is reported"
	)

	var duplicate_subscribe_manifest := _manifest(
		profile,
		configuration
	)

	duplicate_subscribe_manifest.subscribes.append(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var duplicate_subscribe := builder.build(
		DEVICE_ID,
		profile,
		configuration,
		duplicate_subscribe_manifest
	)

	_expect(
		not duplicate_subscribe.is_success(),
		"DGN-U04: duplicate subscribe fails"
	)

	_expect(
		_report_has_code(
			duplicate_subscribe.get_report(),
			&"graph_manifest_duplicate_subscribe"
		),
		"DGN-U04: duplicate subscribe code is reported"
	)


# =============================================================================
# MANIFEST / CONFIGURATION
# =============================================================================

func _test_manifest_configuration_mismatch() -> void:

	var profile := _profile()

	var configuration := _configuration(
		profile
	)

	var manifest := _manifest(
		profile,
		configuration
	)

	manifest.publishes.clear()

	var result := DeviceGraphNodeBuilder.new().build(
		DEVICE_ID,
		profile,
		configuration,
		manifest
	)

	_expect(
		not result.is_success(),
		"DGN-U05: Manifest mismatch fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"graph_manifest_configuration_mismatch"
		),
		"DGN-U05: Manifest mismatch code is reported"
	)


# =============================================================================
# VALID BUILD
# =============================================================================

func _test_valid_build() -> void:

	var profile := _profile()

	var configuration := _configuration(
		profile
	)

	var manifest := _manifest(
		profile,
		configuration
	)

	var result := DeviceGraphNodeBuilder.new().build(
		DEVICE_ID,
		profile,
		configuration,
		manifest
	)

	var node := result.get_node()

	_expect(
		result.is_success(),
		"DGN-U06: valid inputs build Node"
	)

	_expect(
		node != null,
		"DGN-U06: Node is created"
	)

	_expect(
		result.get_report().is_valid_for_simulation(),
		"DGN-U06: Report is valid"
	)

	_expect(
		node.is_valid(),
		"DGN-U06: Node is valid"
	)

	_expect(
		node.get_device_id() == DEVICE_ID,
		"DGN-U06: Device ID is preserved"
	)

	_expect(
		node.get_primary_role()
		== DeviceRoles.LOCAL_CONTROLLER,
		"DGN-U06: Primary Role is preserved"
	)

	_expect(
		node.get_profile() == profile,
		"DGN-U06: Profile snapshot is preserved"
	)

	_expect(
		node.get_configuration()
		== configuration,
		"DGN-U06: Configuration snapshot is preserved"
	)

	var node_manifest := node.get_manifest()

	_expect(
		node_manifest.capabilities
		== manifest.capabilities,
		"DGN-U06: Manifest capabilities are copied"
	)

	var input_ports := node.get_input_ports()

	var output_ports := node.get_output_ports()

	_expect(
		input_ports.size() == 2,
		"DGN-U06: two InputPorts are generated"
	)

	_expect(
		output_ports.size() == 1,
		"DGN-U06: one OutputPort is generated"
	)

	_expect(
		input_ports[0].get_port_id()
		== &"in.distance_measurement",
		"DGN-U06: first InputPort ID is deterministic"
	)

	_expect(
		input_ports[1].get_port_id()
		== &"in.health_report",
		"DGN-U06: second InputPort ID is deterministic"
	)

	_expect(
		output_ports[0].get_port_id()
		== &"out.propulsion_command",
		"DGN-U06: OutputPort ID is deterministic"
	)

	_expect(
		input_ports[0].get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"DGN-U06: InputPort Topic is correct"
	)

	_expect(
		output_ports[0].get_topic()
		== BusTopics.PROPULSION_COMMAND,
		"DGN-U06: OutputPort Topic is correct"
	)

	_expect(
		input_ports[0].get_semantic_kind()
		== PortSemanticKinds.UNSPECIFIED,
		"DGN-U06: InputPort Kind is UNSPECIFIED"
	)

	_expect(
		input_ports[1].get_semantic_kind()
		== PortSemanticKinds.UNSPECIFIED,
		"DGN-U06: second InputPort Kind is UNSPECIFIED"
	)

	_expect(
		output_ports[0].get_semantic_kind()
		== PortSemanticKinds.UNSPECIFIED,
		"DGN-U06: OutputPort Kind is UNSPECIFIED"
	)

	_expect(
		node.get_input_port(
			&"in.distance_measurement"
		) != null,
		"DGN-U06: InputPort lookup works"
	)


# =============================================================================
# COLLECTION INDEPENDENCE
# =============================================================================

func _test_collection_independence() -> void:

	var profile := _profile()

	var configuration := _configuration(
		profile
	)

	var manifest := _manifest(
		profile,
		configuration
	)

	var result := DeviceGraphNodeBuilder.new().build(
		DEVICE_ID,
		profile,
		configuration,
		manifest
	)

	var node := result.get_node()

	var input_ports := node.get_input_ports()

	var output_ports := node.get_output_ports()

	input_ports.clear()
	output_ports.clear()

	_expect(
		node.get_input_ports().size() == 2,
		"DGN-U07: InputPorts copy is independent"
	)

	_expect(
		node.get_output_ports().size() == 1,
		"DGN-U07: OutputPorts copy is independent"
	)

	manifest.capabilities.clear()
	manifest.publishes.clear()
	manifest.subscribes.clear()

	var internal_manifest := node.get_manifest()

	_expect(
		internal_manifest.capabilities.size() == 1,
		"DGN-U07: external Manifest capabilities do not affect Node"
	)

	_expect(
		internal_manifest.publishes.size() == 1,
		"DGN-U07: external Manifest publishes do not affect Node"
	)

	_expect(
		internal_manifest.subscribes.size() == 2,
		"DGN-U07: external Manifest subscribes do not affect Node"
	)

	internal_manifest.capabilities.clear()

	_expect(
		node.get_manifest().capabilities.size() == 1,
		"DGN-U07: returned Manifest is an independent copy"
	)


# =============================================================================
# IMMUTABLE API
# =============================================================================

func _test_immutable_api() -> void:

	var profile := _profile()

	var configuration := _configuration(
		profile
	)

	var manifest := _manifest(
		profile,
		configuration
	)

	var result := DeviceGraphNodeBuilder.new().build(
		DEVICE_ID,
		profile,
		configuration,
		manifest
	)

	var node := result.get_node()

	var setter_names: Array[StringName] = [
		&"set_device_id",
		&"set_primary_role",
		&"set_profile",
		&"set_configuration",
	]

	for setter_name: StringName in setter_names:

		_expect(
			not node.has_method(setter_name),
			"DGN-U08: "
			+ String(setter_name)
			+ " does not exist"
		)


# =============================================================================
# FIXTURES
# =============================================================================

func _profile() -> DeviceProfile:

	return DeviceProfile.new(
		&"test.hover_mcu",
		1,
		"Test Hover MCU",
		"DeviceGraphNodeBuilder fixture.",
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
		[
			"device_bus",
		],
		false,
		&"",
		0
	)


func _configuration(
	profile: DeviceProfile
) -> DeviceConfiguration:

	return DeviceConfiguration.new(
		&"test.hover_mcu.configuration",
		1,
		DEVICE_ID,
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


func _manifest(
	profile: DeviceProfile,
	configuration: DeviceConfiguration
) -> DeviceManifest:

	var result := DeviceManifestBuilder.new().build(
		profile,
		configuration
	)

	return result.get_manifest()


func _report_has_code(
	report: ValidationReport,
	code: StringName
) -> bool:

	for issue: ValidationIssue in report.get_issues():

		if issue.get_code() == code:
			return true

	return false


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
