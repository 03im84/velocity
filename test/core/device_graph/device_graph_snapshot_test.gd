extends Node


##
## DeviceGraphSnapshotTest
##
## Verifica Snapshot inmutable, SnapshotResult
## y creación transaccional desde DeviceGraphDraft.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceGraphSnapshotTest")
	print("========================================")

	_test_empty_snapshot()
	_test_connected_snapshot()
	_test_collection_independence()
	_test_snapshot_contract()
	_test_draft_mutation_after_snapshot()
	_test_failed_mutation_preserves_last_known_good()
	_test_cycle_snapshot()
	_test_structural_error_blocks_snapshot()
	_test_snapshot_result_contract()

	_finish_test()


# =============================================================================
# EMPTY SNAPSHOT
# =============================================================================

func _test_empty_snapshot() -> void:

	var graph := DeviceGraphDraft.new()
	var result := graph.create_snapshot()
	var snapshot := result.get_snapshot()
	var report := result.get_report()

	_expect(
		result.is_success(),
		"DGS-U01: empty Graph creates successful Result"
	)

	_expect(
		snapshot != null,
		"DGS-U01: empty Graph creates Snapshot"
	)

	_expect(
		report != null,
		"DGS-U01: empty Graph creates Report"
	)

	_expect(
		report.get_issues().is_empty(),
		"DGS-U01: empty Snapshot Report has no Issues"
	)

	_expect(
		snapshot.is_valid(),
		"DGS-U01: empty Snapshot is valid"
	)

	_expect(
		snapshot.get_devices().is_empty(),
		"DGS-U01: empty Snapshot has no Devices"
	)

	_expect(
		snapshot.get_connections().is_empty(),
		"DGS-U01: empty Snapshot has no Connections"
	)

	_expect(
		snapshot.get_topic_channels().is_empty(),
		"DGS-U01: empty Snapshot has no TopicChannels"
	)


# =============================================================================
# CONNECTED SNAPSHOT
# =============================================================================

func _test_connected_snapshot() -> void:

	var graph := _connected_pair_graph(
		"snapshot_source",
		"snapshot_target"
	)

	var source := graph.get_device(
		"snapshot_source"
	)

	var target := graph.get_device(
		"snapshot_target"
	)

	var graph_connection := graph.get_connections()[0]
	var result := graph.create_snapshot()
	var snapshot := result.get_snapshot()

	_expect(
		result.is_success(),
		"DGS-U02: connected Graph creates successful Result"
	)

	_expect(
		snapshot != null,
		"DGS-U02: connected Graph creates Snapshot"
	)

	if snapshot == null:
		return

	_expect(
		snapshot.is_valid(),
		"DGS-U02: connected Snapshot is valid"
	)

	_expect(
		snapshot.get_devices().size() == 2,
		"DGS-U02: Snapshot contains two Devices"
	)

	_expect(
		snapshot.get_connections().size() == 1,
		"DGS-U02: Snapshot contains one Connection"
	)

	_expect(
		snapshot.get_topic_channels().size() == 1,
		"DGS-U02: Snapshot contains one TopicChannel"
	)

	var snapshot_devices := snapshot.get_devices()

	_expect(
		snapshot_devices[0] == source
		and snapshot_devices[1] == target,
		"DGS-U02: Snapshot preserves Device order"
	)

	_expect(
		snapshot.get_device(
			"snapshot_source"
		) == source,
		"DGS-U02: Device lookup returns Source"
	)

	_expect(
		snapshot.get_device(
			"snapshot_target"
		) == target,
		"DGS-U02: Device lookup returns Target"
	)

	_expect(
		snapshot.get_device(
			"missing_device"
		) == null,
		"DGS-U02: missing Device lookup returns null"
	)

	_expect(
		snapshot.get_connection(
			graph_connection.get_connection_id()
		) == graph_connection,
		"DGS-U02: Connection lookup returns stored Connection"
	)

	_expect(
		snapshot.get_connection(
			&"missing_connection"
		) == null,
		"DGS-U02: missing Connection lookup returns null"
	)

	_expect(
		result.get_report().get_issues().is_empty(),
		"DGS-U02: fully connected Snapshot has no Issues"
	)


# =============================================================================
# COLLECTION INDEPENDENCE
# =============================================================================

func _test_collection_independence() -> void:

	var graph := _connected_pair_graph(
		"copy_source",
		"copy_target"
	)

	var result := graph.create_snapshot()
	var snapshot := result.get_snapshot()

	_expect(
		result.is_success()
		and snapshot != null,
		"DGS-U03: collection fixture Snapshot is created"
	)

	if snapshot == null:
		return

	var devices_copy := snapshot.get_devices()
	var connections_copy := snapshot.get_connections()
	var channels_copy := snapshot.get_topic_channels()

	devices_copy.clear()
	connections_copy.clear()
	channels_copy.clear()

	_expect(
		snapshot.get_devices().size() == 2,
		"DGS-U03: Devices getter returns independent Array"
	)

	_expect(
		snapshot.get_connections().size() == 1,
		"DGS-U03: Connections getter returns independent Array"
	)

	_expect(
		snapshot.get_topic_channels().size() == 1,
		"DGS-U03: Channels getter returns independent Array"
	)

	var constructor_devices := graph.get_devices()
	var constructor_connections := graph.get_connections()
	var constructor_channels := graph.get_topic_channels()

	var direct_snapshot := DeviceGraphSnapshot.new(
		constructor_devices,
		constructor_connections,
		constructor_channels
	)

	constructor_devices.clear()
	constructor_connections.clear()
	constructor_channels.clear()

	_expect(
		direct_snapshot.get_devices().size() == 2
		and direct_snapshot.get_connections().size() == 1
		and direct_snapshot.get_topic_channels().size() == 1,
		"DGS-U03: constructor copies all input Arrays"
	)

	_expect(
		direct_snapshot.is_valid(),
		"DGS-U03: constructor copies preserve valid Snapshot"
	)


# =============================================================================
# SNAPSHOT CONTRACT
# =============================================================================

func _test_snapshot_contract() -> void:

	var snapshot := DeviceGraphSnapshot.new()

	_expect(
		not snapshot.has_method(
			&"add_device"
		)
		and not snapshot.has_method(
			&"remove_device"
		)
		and not snapshot.has_method(
			&"connect_ports"
		)
		and not snapshot.has_method(
			&"disconnect_ports"
		),
		"DGS-U04: Snapshot exposes no topology mutations"
	)

	_expect(
		not snapshot.has_method(
			&"set_devices"
		)
		and not snapshot.has_method(
			&"set_connections"
		)
		and not snapshot.has_method(
			&"set_topic_channels"
		),
		"DGS-U04: Snapshot exposes no collection setters"
	)

	_expect(
		not snapshot.has_method(
			&"execute"
		)
		and not snapshot.has_method(
			&"activate"
		)
		and not snapshot.has_method(
			&"publish"
		),
		"DGS-U04: Snapshot is not executable"
	)


# =============================================================================
# LAST KNOWN GOOD
# =============================================================================

func _test_draft_mutation_after_snapshot() -> void:

	var graph := _connected_pair_graph(
		"mutable_source",
		"mutable_target"
	)

	var result := graph.create_snapshot()
	var snapshot := result.get_snapshot()

	_expect(
		result.is_success()
		and snapshot != null,
		"DGS-U05: mutation fixture Snapshot is created"
	)

	if snapshot == null:
		return

	var snapshot_source := snapshot.get_device(
		"mutable_source"
	)

	var connection_id := snapshot.get_connections()[0].get_connection_id()

	var disconnect_result := graph.disconnect_ports(
		connection_id
	)

	var remove_source_result := graph.remove_device(
		"mutable_source"
	)

	var remove_target_result := graph.remove_device(
		"mutable_target"
	)

	_expect(
		disconnect_result.is_success()
		and remove_source_result.is_success()
		and remove_target_result.is_success(),
		"DGS-U05: Draft can change after Snapshot"
	)

	_expect(
		graph.get_devices().is_empty()
		and graph.get_connections().is_empty()
		and graph.get_topic_channels().is_empty(),
		"DGS-U05: Draft becomes empty"
	)

	_expect(
		snapshot.get_devices().size() == 2
		and snapshot.get_connections().size() == 1
		and snapshot.get_topic_channels().size() == 1,
		"DGS-U05: Draft changes do not affect Snapshot"
	)

	_expect(
		snapshot.get_device(
			"mutable_source"
		) == snapshot_source,
		"DGS-U05: Snapshot preserves Device reference"
	)

	_expect(
		snapshot.get_connection(
			connection_id
		) != null,
		"DGS-U05: Snapshot preserves Connection"
	)

	_expect(
		snapshot.is_valid(),
		"DGS-U05: Snapshot remains valid after Draft changes"
	)


func _test_failed_mutation_preserves_last_known_good() -> void:

	var graph := _connected_pair_graph(
		"last_good_source_a",
		"last_good_target"
	)

	var add_result := graph.add_device(
		_source_node(
			"last_good_source_b"
		)
	)

	_expect(
		add_result.is_success(),
		"DGS-U06: second Source is added"
	)

	var first_connection := graph.get_connections()[0]

	var failed_result := graph.connect_ports(
		"last_good_source_b",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"last_good_target",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	_expect(
		not failed_result.is_success(),
		"DGS-U06: invalid fan-in mutation fails"
	)

	_expect(
		_report_has_code(
			failed_result.get_report(),
			&"input_port_multiple_sources"
		),
		"DGS-U06: failed mutation reports fan-in"
	)

	var snapshot_result := graph.create_snapshot()
	var snapshot := snapshot_result.get_snapshot()

	_expect(
		snapshot_result.is_success()
		and snapshot != null,
		"DGS-U06: Last Known Good creates Snapshot"
	)

	if snapshot == null:
		return

	_expect(
		snapshot.get_devices().size() == 3
		and snapshot.get_connections().size() == 1,
		"DGS-U06: Snapshot contains only accepted topology"
	)

	_expect(
		snapshot.get_connection(
			first_connection.get_connection_id()
		) == first_connection,
		"DGS-U06: Snapshot preserves first Connection"
	)

	_expect(
		not _report_has_code(
			snapshot_result.get_report(),
			&"input_port_multiple_sources"
		),
		"DGS-U06: rejected mutation does not contaminate Snapshot Report"
	)

	_expect(
		snapshot_result.get_report().is_valid_for_simulation(),
		"DGS-U06: Last Known Good remains valid for Simulation"
	)


# =============================================================================
# CYCLE SNAPSHOT
# =============================================================================

func _test_cycle_snapshot() -> void:

	var graph := DeviceGraphDraft.new()

	var add_a_result := graph.add_device(
		_distance_to_health_node(
			"snapshot_cycle_a"
		)
	)

	var add_b_result := graph.add_device(
		_health_to_distance_node(
			"snapshot_cycle_b"
		)
	)

	_expect(
		add_a_result.is_success()
		and add_b_result.is_success(),
		"DGS-U07: cycle Snapshot fixtures are added"
	)

	var first_result := _connect_topic(
		graph,
		"snapshot_cycle_a",
		"snapshot_cycle_b",
		BusTopics.DISTANCE_MEASUREMENT
	)

	var second_result := _connect_topic(
		graph,
		"snapshot_cycle_b",
		"snapshot_cycle_a",
		BusTopics.HEALTH_REPORT
	)

	_expect(
		first_result.is_success()
		and second_result.is_success(),
		"DGS-U07: cycle Snapshot Connections succeed"
	)

	var snapshot_result := graph.create_snapshot()
	var snapshot := snapshot_result.get_snapshot()
	var report := snapshot_result.get_report()

	_expect(
		snapshot_result.is_success(),
		"DGS-U07: cycle creates successful Simulation Result"
	)

	_expect(
		snapshot != null,
		"DGS-U07: cycle creates Snapshot"
	)

	_expect(
		_report_code_count(
			report,
			&"graph_cycle_requires_temporal_analysis"
		) == 1,
		"DGS-U07: cycle Snapshot reports one Hazard"
	)

	_expect(
		_report_has_severity(
			report,
			&"graph_cycle_requires_temporal_analysis",
			ValidationIssue.Severity.SIMULATION_HAZARD
		),
		"DGS-U07: cycle Snapshot Issue is Simulation Hazard"
	)

	_expect(
		report.is_valid_for_simulation(),
		"DGS-U07: cycle Snapshot is valid for Simulation"
	)

	_expect(
		not report.is_valid_for_hardware(),
		"DGS-U07: cycle Snapshot is blocked for Hardware"
	)

	_expect(
		snapshot != null
		and snapshot.is_valid(),
		"DGS-U07: cycle Snapshot is structurally valid"
	)

	_expect(
		snapshot != null
		and snapshot.get_connections().size() == 2,
		"DGS-U07: cycle Snapshot preserves Connections"
	)


# =============================================================================
# STRUCTURAL FAILURE
# =============================================================================

func _test_structural_error_blocks_snapshot() -> void:

	var graph := DeviceGraphDraft.new()

	var duplicate_owner_node := _duplicate_owner_node(
		"duplicate_owner"
	)

	_expect(
		duplicate_owner_node.is_valid(),
		"DGS-U08: duplicate-owner fixture is locally valid"
	)

	var add_result := graph.add_device(
		duplicate_owner_node
	)

	_expect(
		add_result.is_success(),
		"DGS-U08: locally valid fixture enters Draft"
	)

	var result := graph.create_snapshot()
	var report := result.get_report()

	_expect(
		not result.is_success(),
		"DGS-U08: structural Graph cannot create successful Result"
	)

	_expect(
		result.get_snapshot() == null,
		"DGS-U08: structural Graph produces null Snapshot"
	)

	_expect(
		_report_has_code(
			report,
			&"duplicate_stream_owner"
		),
		"DGS-U08: duplicate stream owner is reported"
	)

	_expect(
		_report_has_severity(
			report,
			&"duplicate_stream_owner",
			ValidationIssue.Severity.STRUCTURAL_ERROR
		),
		"DGS-U08: duplicate stream owner is Structural Error"
	)

	_expect(
		not report.is_valid_for_simulation(),
		"DGS-U08: structural Graph blocks Simulation"
	)

	_expect(
		not report.is_valid_for_hardware(),
		"DGS-U08: structural Graph blocks Hardware"
	)

	_expect(
		graph.get_devices().size() == 1,
		"DGS-U08: failed Snapshot does not modify Draft"
	)


# =============================================================================
# SNAPSHOT RESULT CONTRACT
# =============================================================================

func _test_snapshot_result_contract() -> void:

	var valid_report := ValidationReport.new()
	var valid_snapshot := DeviceGraphSnapshot.new()

	var null_snapshot_result := DeviceGraphSnapshotResult.new(
		null,
		valid_report
	)

	_expect(
		not null_snapshot_result.is_success(),
		"DGS-U09: null Snapshot produces failed Result"
	)

	var null_report_result := DeviceGraphSnapshotResult.new(
		valid_snapshot,
		null
	)

	_expect(
		not null_report_result.is_success(),
		"DGS-U09: null Report produces failed Result"
	)

	var invalid_node := _duplicate_owner_node(
		"invalid_snapshot_owner"
	)

	var invalid_devices: Array[DeviceGraphNode] = [
		invalid_node,
	]

	var no_connections: Array[DeviceGraphConnection] = []

	var invalid_channels: Array[DeviceGraphTopicChannel] = [
		DeviceGraphTopicChannel.new(
			BusTopics.DISTANCE_MEASUREMENT
		),
	]

	var invalid_snapshot := DeviceGraphSnapshot.new(
		invalid_devices,
		no_connections,
		invalid_channels
	)

	_expect(
		not invalid_snapshot.is_valid(),
		"DGS-U09: directly constructed invalid Snapshot is detected"
	)

	var incoherent_result := DeviceGraphSnapshotResult.new(
		invalid_snapshot,
		valid_report
	)

	_expect(
		not incoherent_result.is_success(),
		"DGS-U09: valid Report cannot approve invalid Snapshot"
	)

	var valid_result := DeviceGraphSnapshotResult.new(
		valid_snapshot,
		valid_report
	)

	_expect(
		valid_result.is_success(),
		"DGS-U09: valid Snapshot and Report produce success"
	)

	_expect(
		valid_result.get_snapshot() == valid_snapshot
		and valid_result.get_report() == valid_report,
		"DGS-U09: Result preserves Snapshot and Report"
	)

	_expect(
		not valid_result.has_method(
			&"set_snapshot"
		)
		and not valid_result.has_method(
			&"set_report"
		),
		"DGS-U09: SnapshotResult exposes no setters"
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
		"graph_snapshot",
	]

	var requirements: Array[String] = []

	var profile := DeviceProfile.new(
		profile_id,
		1,
		"Snapshot " + device_id,
		"DeviceGraph Snapshot fixture.",
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


func _duplicate_owner_node(
	device_id: String
) -> DeviceGraphNode:

	var base_node := _source_node(
		device_id
	)

	var input_ports: Array[DeviceGraphInputPort] = []

	var output_ports: Array[DeviceGraphOutputPort] = [
		DeviceGraphOutputPort.new(
			&"out.distance.primary",
			device_id,
			BusTopics.DISTANCE_MEASUREMENT,
			PortSemanticKinds.UNSPECIFIED
		),
		DeviceGraphOutputPort.new(
			&"out.distance.secondary",
			device_id,
			BusTopics.DISTANCE_MEASUREMENT,
			PortSemanticKinds.UNSPECIFIED
		),
	]

	return DeviceGraphNode.new(
		base_node.get_device_id(),
		base_node.get_primary_role(),
		base_node.get_profile(),
		base_node.get_configuration(),
		base_node.get_manifest(),
		input_ports,
		output_ports
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
