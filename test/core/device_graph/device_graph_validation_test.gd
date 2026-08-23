extends Node


##
## DeviceGraphValidationTest
##
## Verifica validación global, cardinalidad
## de InputPorts y detección iterativa de ciclos.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceGraphValidationTest")
	print("========================================")

	_test_empty_graph()
	_test_unconnected_ports()
	_test_connected_acyclic_graph()
	_test_fan_in_transaction()
	_test_defensive_fan_in_validation()
	_test_connection_id_mismatch()
	_test_topic_channel_registry_mismatch()
	_test_cycle_hazard()
	_test_two_cycle_components()
	_test_validator_does_not_mutate()

	_finish_test()


# =============================================================================
# EMPTY AND UNCONNECTED GRAPHS
# =============================================================================

func _test_empty_graph() -> void:

	var graph := DeviceGraphDraft.new()
	var report := graph.validate()

	_expect(
		report != null,
		"DGV-U01: empty Graph produces Report"
	)

	_expect(
		report.get_issues().is_empty(),
		"DGV-U01: empty Graph produces no Issues"
	)

	_expect(
		report.is_valid_for_simulation(),
		"DGV-U01: empty Graph is valid for Simulation"
	)

	_expect(
		report.is_valid_for_hardware(),
		"DGV-U01: empty Graph is valid for Hardware"
	)


func _test_unconnected_ports() -> void:

	var graph := DeviceGraphDraft.new()

	var source_result := graph.add_device(
		_source_node("source_unconnected")
	)

	var target_result := graph.add_device(
		_target_node("target_unconnected")
	)

	_expect(
		source_result.is_success()
		and target_result.is_success(),
		"DGV-U02: unconnected fixtures are added"
	)

	var report := graph.validate()

	_expect(
		_report_has_code(
			report,
			&"input_port_unconnected"
		),
		"DGV-U02: unconnected InputPort is reported"
	)

	_expect(
		_report_has_severity(
			report,
			&"input_port_unconnected",
			ValidationIssue.Severity.WARNING
		),
		"DGV-U02: unconnected InputPort is WARNING"
	)

	_expect(
		_report_has_code(
			report,
			&"output_port_unconnected"
		),
		"DGV-U02: unconnected OutputPort is reported"
	)

	_expect(
		_report_has_severity(
			report,
			&"output_port_unconnected",
			ValidationIssue.Severity.INFO
		),
		"DGV-U02: unconnected OutputPort is INFO"
	)

	_expect(
		report.is_valid_for_simulation(),
		"DGV-U02: WARNING and INFO allow Simulation"
	)

	_expect(
		report.is_valid_for_hardware(),
		"DGV-U02: WARNING and INFO allow Hardware"
	)


# =============================================================================
# CONNECTED ACYCLIC GRAPH
# =============================================================================

func _test_connected_acyclic_graph() -> void:

	var graph := _connected_pair_graph(
		"source_acyclic",
		"target_acyclic"
	)

	var report := graph.validate()

	_expect(
		graph.get_devices().size() == 2,
		"DGV-U03: acyclic Graph contains two Devices"
	)

	_expect(
		graph.get_connections().size() == 1,
		"DGV-U03: acyclic Graph contains one Connection"
	)

	_expect(
		report.get_issues().is_empty(),
		"DGV-U03: fully connected acyclic Graph has no Issues"
	)

	_expect(
		not _report_has_code(
			report,
			&"graph_cycle_requires_temporal_analysis"
		),
		"DGV-U03: acyclic Graph has no cycle Issue"
	)

	_expect(
		report.is_valid_for_simulation(),
		"DGV-U03: acyclic Graph is valid for Simulation"
	)

	_expect(
		report.is_valid_for_hardware(),
		"DGV-U03: acyclic Graph is valid for Hardware"
	)

	var second_report := graph.validate()

	_expect(
		second_report != report,
		"DGV-U03: each validation produces a new Report"
	)


# =============================================================================
# FAN-IN
# =============================================================================

func _test_fan_in_transaction() -> void:

	var graph := DeviceGraphDraft.new()

	var source_a := _source_node(
		"fanin_source_a"
	)

	var source_b := _source_node(
		"fanin_source_b"
	)

	var target := _target_node(
		"fanin_target"
	)

	var add_a_result := graph.add_device(
		source_a
	)

	var add_b_result := graph.add_device(
		source_b
	)

	var add_target_result := graph.add_device(
		target
	)

	_expect(
		add_a_result.is_success()
		and add_b_result.is_success()
		and add_target_result.is_success(),
		"DGV-U04: fan-in fixtures are added"
	)

	var first_result := graph.connect_ports(
		"fanin_source_a",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"fanin_target",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	_expect(
		first_result.is_success(),
		"DGV-U04: first source Connection succeeds"
	)

	var second_result := graph.connect_ports(
		"fanin_source_b",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"fanin_target",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	_expect(
		not second_result.is_success(),
		"DGV-U04: second source Connection is rejected"
	)

	_expect(
		_report_has_code(
			second_result.get_report(),
			&"input_port_multiple_sources"
		),
		"DGV-U04: fan-in code is reported"
	)

	_expect(
		second_result.get_affected_id() == &"",
		"DGV-U04: rejected fan-in has no affected ID"
	)

	_expect(
		graph.get_connections().size() == 1,
		"DGV-U04: rejected fan-in preserves one Connection"
	)

	_expect(
		graph.has_connection(
			first_result.get_affected_id()
		),
		"DGV-U04: rejected fan-in preserves first Connection"
	)

	var validation_report := graph.validate()

	_expect(
		not _report_has_code(
			validation_report,
			&"input_port_multiple_sources"
		),
		"DGV-U04: rejected fan-in does not corrupt Graph"
	)


func _test_defensive_fan_in_validation() -> void:

	var source_a := _source_node(
		"defensive_source_a"
	)

	var source_b := _source_node(
		"defensive_source_b"
	)

	var target := _target_node(
		"defensive_target"
	)

	var first_connection := _distance_connection(
		"defensive_source_a",
		"defensive_target"
	)

	var second_connection := _distance_connection(
		"defensive_source_b",
		"defensive_target"
	)

	var devices: Array[DeviceGraphNode] = [
		source_a,
		source_b,
		target,
	]

	var connections: Array[DeviceGraphConnection] = [
		first_connection,
		second_connection,
	]

	var channels: Array[DeviceGraphTopicChannel] = [
		DeviceGraphTopicChannel.new(
			BusTopics.DISTANCE_MEASUREMENT
		),
	]

	var report := DeviceGraphValidator.new().validate(
		devices,
		connections,
		channels
	)

	_expect(
		_report_has_code(
			report,
			&"input_port_multiple_sources"
		),
		"DGV-U05: Validator detects defensive fan-in"
	)

	_expect(
		_report_has_severity(
			report,
			&"input_port_multiple_sources",
			ValidationIssue.Severity.STRUCTURAL_ERROR
		),
		"DGV-U05: defensive fan-in is Structural Error"
	)

	_expect(
		not report.is_valid_for_simulation(),
		"DGV-U05: defensive fan-in blocks Simulation"
	)

	_expect(
		not report.is_valid_for_hardware(),
		"DGV-U05: defensive fan-in blocks Hardware"
	)

	_expect(
		devices.size() == 3
		and connections.size() == 2
		and channels.size() == 1,
		"DGV-U05: defensive validation preserves input Arrays"
	)


# =============================================================================
# DEFENSIVE ID AND CHANNEL VALIDATION
# =============================================================================

func _test_connection_id_mismatch() -> void:

	var source := _source_node(
		"id_source"
	)

	var target := _target_node(
		"id_target"
	)

	var invalid_connection := DeviceGraphConnection.new(
		&"incorrect_connection_id",
		"id_source",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		BusTopics.DISTANCE_MEASUREMENT,
		"id_target",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	var devices: Array[DeviceGraphNode] = [
		source,
		target,
	]

	var connections: Array[DeviceGraphConnection] = [
		invalid_connection,
	]

	var channels: Array[DeviceGraphTopicChannel] = [
		DeviceGraphTopicChannel.new(
			BusTopics.DISTANCE_MEASUREMENT
		),
	]

	var report := DeviceGraphValidator.new().validate(
		devices,
		connections,
		channels
	)

	_expect(
		_report_has_code(
			report,
			&"connection_id_mismatch"
		),
		"DGV-U06: incoherent Connection ID is detected"
	)

	_expect(
		_report_has_severity(
			report,
			&"connection_id_mismatch",
			ValidationIssue.Severity.STRUCTURAL_ERROR
		),
		"DGV-U06: incoherent Connection ID is Structural Error"
	)

	_expect(
		not report.is_valid_for_simulation(),
		"DGV-U06: incoherent Connection ID blocks Simulation"
	)

	_expect(
		not report.is_valid_for_hardware(),
		"DGV-U06: incoherent Connection ID blocks Hardware"
	)


func _test_topic_channel_registry_mismatch() -> void:

	var source := _source_node(
		"channel_source"
	)

	var source_devices: Array[DeviceGraphNode] = [
		source,
	]

	var no_connections: Array[DeviceGraphConnection] = []
	var no_channels: Array[DeviceGraphTopicChannel] = []

	var missing_report := DeviceGraphValidator.new().validate(
		source_devices,
		no_connections,
		no_channels
	)

	_expect(
		_report_has_code(
			missing_report,
			&"topic_channel_registry_mismatch"
		),
		"DGV-U07: missing TopicChannel is detected"
	)

	_expect(
		not missing_report.is_valid_for_simulation(),
		"DGV-U07: missing TopicChannel blocks Simulation"
	)

	var no_devices: Array[DeviceGraphNode] = []

	var extra_channels: Array[DeviceGraphTopicChannel] = [
		DeviceGraphTopicChannel.new(
			BusTopics.DISTANCE_MEASUREMENT
		),
	]

	var extra_report := DeviceGraphValidator.new().validate(
		no_devices,
		no_connections,
		extra_channels
	)

	_expect(
		_report_has_code(
			extra_report,
			&"topic_channel_registry_mismatch"
		),
		"DGV-U07: unused TopicChannel is detected"
	)

	_expect(
		not extra_report.is_valid_for_simulation(),
		"DGV-U07: unused TopicChannel blocks Simulation"
	)


# =============================================================================
# CYCLE DETECTION
# =============================================================================

func _test_cycle_hazard() -> void:

	var graph := DeviceGraphDraft.new()

	var node_a := _distance_to_health_node(
		"cycle_a"
	)

	var node_b := _health_to_distance_node(
		"cycle_b"
	)

	var add_a_result := graph.add_device(
		node_a
	)

	var add_b_result := graph.add_device(
		node_b
	)

	_expect(
		add_a_result.is_success()
		and add_b_result.is_success(),
		"DGV-U08: cycle fixtures are added"
	)

	var first_connection := graph.connect_ports(
		"cycle_a",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"cycle_b",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	var second_connection := graph.connect_ports(
		"cycle_b",
		_output_port_id(
			BusTopics.HEALTH_REPORT
		),
		"cycle_a",
		_input_port_id(
			BusTopics.HEALTH_REPORT
		)
	)

	_expect(
		first_connection.is_success()
		and second_connection.is_success(),
		"DGV-U08: cycle Connections are created"
	)

	var report := graph.validate()

	_expect(
		_report_code_count(
			report,
			&"graph_cycle_requires_temporal_analysis"
		) == 1,
		"DGV-U08: one cyclic component produces one Issue"
	)

	_expect(
		_report_has_severity(
			report,
			&"graph_cycle_requires_temporal_analysis",
			ValidationIssue.Severity.SIMULATION_HAZARD
		),
		"DGV-U08: cycle is Simulation Hazard"
	)

	_expect(
		report.is_valid_for_simulation(),
		"DGV-U08: unclassified cycle allows Simulation"
	)

	_expect(
		not report.is_valid_for_hardware(),
		"DGV-U08: unclassified cycle blocks Hardware"
	)


func _test_two_cycle_components() -> void:

	var graph := DeviceGraphDraft.new()

	var node_a := _distance_to_health_node(
		"multi_cycle_a"
	)

	var node_b := _health_to_distance_node(
		"multi_cycle_b"
	)

	var node_c := _distance_to_health_node(
		"multi_cycle_c"
	)

	var node_d := _health_to_distance_node(
		"multi_cycle_d"
	)

	var add_results: Array[DeviceGraphOperationResult] = [
		graph.add_device(node_a),
		graph.add_device(node_b),
		graph.add_device(node_c),
		graph.add_device(node_d),
	]

	_expect(
		_all_operations_succeeded(
			add_results
		),
		"DGV-U09: two-cycle fixtures are added"
	)

	var connection_results: Array[DeviceGraphOperationResult] = [
		_connect_topic(
			graph,
			"multi_cycle_a",
			"multi_cycle_b",
			BusTopics.DISTANCE_MEASUREMENT
		),
		_connect_topic(
			graph,
			"multi_cycle_b",
			"multi_cycle_a",
			BusTopics.HEALTH_REPORT
		),
		_connect_topic(
			graph,
			"multi_cycle_c",
			"multi_cycle_d",
			BusTopics.DISTANCE_MEASUREMENT
		),
		_connect_topic(
			graph,
			"multi_cycle_d",
			"multi_cycle_c",
			BusTopics.HEALTH_REPORT
		),
	]

	_expect(
		_all_operations_succeeded(
			connection_results
		),
		"DGV-U09: two independent cycles are connected"
	)

	var report := graph.validate()

	_expect(
		_report_code_count(
			report,
			&"graph_cycle_requires_temporal_analysis"
		) == 2,
		"DGV-U09: two cyclic components produce two Issues"
	)

	_expect(
		_all_issues_with_code_have_severity(
			report,
			&"graph_cycle_requires_temporal_analysis",
			ValidationIssue.Severity.SIMULATION_HAZARD
		),
		"DGV-U09: all cycle Issues are Simulation Hazards"
	)

	_expect(
		report.is_valid_for_simulation(),
		"DGV-U09: multiple cycles allow Simulation"
	)

	_expect(
		not report.is_valid_for_hardware(),
		"DGV-U09: multiple cycles block Hardware"
	)


# =============================================================================
# VALIDATOR NON-MUTATION
# =============================================================================

func _test_validator_does_not_mutate() -> void:

	var graph := _connected_pair_graph(
		"immutable_source",
		"immutable_target"
	)

	var devices := graph.get_devices()
	var connections := graph.get_connections()
	var channels := graph.get_topic_channels()

	var first_device := devices[0]
	var first_connection := connections[0]
	var first_channel := channels[0]

	var report := DeviceGraphValidator.new().validate(
		devices,
		connections,
		channels
	)

	_expect(
		devices.size() == 2
		and connections.size() == 1
		and channels.size() == 1,
		"DGV-U10: Validator preserves Array sizes"
	)

	_expect(
		devices[0] == first_device
		and connections[0] == first_connection
		and channels[0] == first_channel,
		"DGV-U10: Validator preserves element references"
	)

	_expect(
		report.get_issues().is_empty(),
		"DGV-U10: preserved connected Graph remains valid"
	)

	_expect(
		graph.get_devices().size() == 2
		and graph.get_connections().size() == 1,
		"DGV-U10: Validator does not modify Draft"
	)


# =============================================================================
# GRAPH FIXTURES
# =============================================================================

func _connected_pair_graph(
	source_device_id: String,
	target_device_id: String
) -> DeviceGraphDraft:

	var graph := DeviceGraphDraft.new()

	graph.add_device(
		_source_node(
			source_device_id
		)
	)

	graph.add_device(
		_target_node(
			target_device_id
		)
	)

	graph.connect_ports(
		source_device_id,
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		target_device_id,
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	return graph


func _source_node(
	device_id: String
) -> DeviceGraphNode:

	var publishes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var subscribes: Array[StringName] = []

	return _graph_node(
		device_id,
		publishes,
		subscribes
	)


func _target_node(
	device_id: String
) -> DeviceGraphNode:

	var publishes: Array[StringName] = []

	var subscribes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	return _graph_node(
		device_id,
		publishes,
		subscribes
	)


func _distance_to_health_node(
	device_id: String
) -> DeviceGraphNode:

	var publishes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var subscribes: Array[StringName] = [
		BusTopics.HEALTH_REPORT,
	]

	return _graph_node(
		device_id,
		publishes,
		subscribes
	)


func _health_to_distance_node(
	device_id: String
) -> DeviceGraphNode:

	var publishes: Array[StringName] = [
		BusTopics.HEALTH_REPORT,
	]

	var subscribes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	return _graph_node(
		device_id,
		publishes,
		subscribes
	)


func _graph_node(
	device_id: String,
	publishes: Array[StringName],
	subscribes: Array[StringName]
) -> DeviceGraphNode:

	var profile_id := StringName(
		"test." + device_id
	)

	var configuration_id := StringName(
		"test." + device_id + ".configuration"
	)

	var capabilities: Array[String] = [
		"graph_validation",
	]

	var requirements: Array[String] = []

	var profile := DeviceProfile.new(
		profile_id,
		1,
		"Validation " + device_id,
		"DeviceGraph validation fixture.",
		DeviceRoles.LOCAL_CONTROLLER,
		capabilities,
		publishes,
		subscribes,
		requirements,
		false,
		&"",
		0
	)

	var configuration := DeviceConfiguration.new(
		configuration_id,
		1,
		device_id,
		profile.get_profile_id(),
		profile.get_profile_version(),
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)

	var manifest_result := DeviceManifestBuilder.new().build(
		profile,
		configuration
	)

	var node_result := DeviceGraphNodeBuilder.new().build(
		device_id,
		profile,
		configuration,
		manifest_result.get_manifest()
	)

	return node_result.get_node()


func _distance_connection(
	source_device_id: String,
	target_device_id: String
) -> DeviceGraphConnection:

	var source_port_id := _output_port_id(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var target_port_id := _input_port_id(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var connection_id := _connection_id(
		source_device_id,
		source_port_id,
		target_device_id,
		target_port_id
	)

	return DeviceGraphConnection.new(
		connection_id,
		source_device_id,
		source_port_id,
		BusTopics.DISTANCE_MEASUREMENT,
		target_device_id,
		target_port_id
	)


func _connect_topic(
	graph: DeviceGraphDraft,
	source_device_id: String,
	target_device_id: String,
	topic: StringName
) -> DeviceGraphOperationResult:

	return graph.connect_ports(
		source_device_id,
		_output_port_id(topic),
		target_device_id,
		_input_port_id(topic)
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


func _connection_id(
	source_device_id: String,
	source_port_id: StringName,
	target_device_id: String,
	target_port_id: StringName
) -> StringName:

	var id_text: String = (
		source_device_id
		+ "|"
		+ String(source_port_id)
		+ "|"
		+ target_device_id
		+ "|"
		+ String(target_port_id)
	)

	return StringName(id_text)


# =============================================================================
# REPORT HELPERS
# =============================================================================

func _report_has_code(
	report: ValidationReport,
	code: StringName
) -> bool:

	return _report_code_count(
		report,
		code
	) > 0


func _report_code_count(
	report: ValidationReport,
	code: StringName
) -> int:

	var count: int = 0

	for issue: ValidationIssue in report.get_issues():

		if issue.get_code() == code:
			count += 1

	return count


func _report_has_severity(
	report: ValidationReport,
	code: StringName,
	severity: int
) -> bool:

	for issue: ValidationIssue in report.get_issues():

		if (
			issue.get_code() == code
			and issue.get_severity() == severity
		):

			return true

	return false


func _all_issues_with_code_have_severity(
	report: ValidationReport,
	code: StringName,
	severity: int
) -> bool:

	var found: bool = false

	for issue: ValidationIssue in report.get_issues():

		if issue.get_code() != code:
			continue

		found = true

		if issue.get_severity() != severity:
			return false

	return found


func _all_operations_succeeded(
	results: Array[DeviceGraphOperationResult]
) -> bool:

	for result: DeviceGraphOperationResult in results:

		if not result.is_success():
			return false

	return true


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
