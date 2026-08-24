extends Node


##
## SystemProfileCatalogGraphAssemblyIntegrationTest
##
## Verifica el pipeline real:
## DeviceCatalog → SystemProfile → DeviceGraphSnapshot.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("SystemProfileCatalogGraphAssemblyIntegrationTest")
	print("========================================")

	_test_valid_pipeline()
	_test_empty_pipeline()
	_test_cycle_pipeline()
	_test_snapshot_stability()
	_test_pipeline_has_no_runtime()

	_finish_test()


# =============================================================================
# VALID PIPELINE
# =============================================================================

func _test_valid_pipeline() -> void:

	var distance_topic: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var source_profile := _profile(
		&"test.pipeline.source",
		distance_topic,
		_empty_topics()
	)

	var target_profile := _profile(
		&"test.pipeline.target",
		_empty_topics(),
		distance_topic
	)

	var catalog_draft := DeviceCatalogDraft.new()

	catalog_draft.profiles.append(
		source_profile
	)

	catalog_draft.profiles.append(
		target_profile
	)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)

	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog != null,
		"SPCGA-I01: DeviceCatalog compiles"
	)

	if catalog == null:
		return

	var source_configuration := _configuration(
		"pipeline_source",
		source_profile,
		distance_topic,
		_empty_topics(),
		"pipeline_source"
	)

	var target_configuration := _configuration(
		"pipeline_target",
		target_profile,
		_empty_topics(),
		distance_topic,
		"pipeline_target"
	)

	var system_draft := _system_draft(
		&"test.pipeline.system"
	)

	system_draft.device_configurations.append(
		source_configuration
	)

	system_draft.device_configurations.append(
		target_configuration
	)

	var spec := SystemConnectionSpec.new(
		"pipeline_source",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"pipeline_target",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	system_draft.connection_specs.append(
		spec
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	var system_profile := system_result.get_profile()

	_expect(
		system_result.is_success()
		and system_profile != null,
		"SPCGA-I01: SystemProfile compiles with Catalog"
	)

	if system_profile == null:
		return

	var assembly_result := DeviceGraphAssembler.new().assemble(
		system_profile,
		catalog
	)

	var snapshot := assembly_result.get_snapshot()

	_expect(
		assembly_result.is_success()
		and snapshot != null,
		"SPCGA-I01: DeviceGraphAssembler creates Snapshot"
	)

	if snapshot == null:
		return

	_expect(
		catalog_result.get_report().get_issues().is_empty()
		and system_result.get_report().get_issues().is_empty()
		and assembly_result.get_report().get_issues().is_empty(),
		"SPCGA-I01: valid pipeline has no Issues"
	)

	var nodes := snapshot.get_devices()
	var connections := snapshot.get_connections()
	var channels := snapshot.get_topic_channels()

	_expect(
		nodes.size() == 2,
		"SPCGA-I01: Snapshot contains two Nodes"
	)

	_expect(
		nodes[0].get_device_id()
		== "pipeline_source"
		and nodes[1].get_device_id()
		== "pipeline_target",
		"SPCGA-I01: Node order follows SystemProfile"
	)

	_expect(
		nodes[0].get_profile() == source_profile
		and nodes[1].get_profile() == target_profile,
		"SPCGA-I01: Nodes preserve Catalog Profile references"
	)

	_expect(
		nodes[0].get_configuration()
		== source_configuration
		and nodes[1].get_configuration()
		== target_configuration,
		"SPCGA-I01: Nodes preserve Configuration references"
	)

	_expect(
		nodes[0].get_output_port(
			_output_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			)
		) != null
		and nodes[1].get_input_port(
			_input_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			)
		) != null,
		"SPCGA-I01: Ports are generated from Manifests"
	)

	_expect(
		connections.size() == 1
		and connections[0].get_connection_id()
		== spec.get_connection_id(),
		"SPCGA-I01: SystemConnectionSpec becomes Graph Connection"
	)

	_expect(
		channels.size() == 1
		and channels[0].get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"SPCGA-I01: TopicChannel is derived"
	)

	_expect(
		snapshot.is_valid(),
		"SPCGA-I01: final Snapshot is valid"
	)


# =============================================================================
# EMPTY PIPELINE
# =============================================================================

func _test_empty_pipeline() -> void:

	var catalog_result := DeviceCatalogCompiler.new().compile(
		DeviceCatalogDraft.new()
	)

	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog != null,
		"SPCGA-I02: empty Catalog compiles"
	)

	if catalog == null:
		return

	var system_result := SystemProfileCompiler.new().compile(
		_system_draft(
			&"test.empty_pipeline"
		),
		catalog
	)

	var system_profile := system_result.get_profile()

	_expect(
		system_result.is_success()
		and system_profile != null,
		"SPCGA-I02: empty SystemProfile compiles"
	)

	if system_profile == null:
		return

	var assembly_result := DeviceGraphAssembler.new().assemble(
		system_profile,
		catalog
	)

	var snapshot := assembly_result.get_snapshot()

	_expect(
		assembly_result.is_success()
		and snapshot != null,
		"SPCGA-I02: empty Graph assembly succeeds"
	)

	_expect(
		snapshot != null
		and snapshot.get_devices().is_empty()
		and snapshot.get_connections().is_empty()
		and snapshot.get_topic_channels().is_empty(),
		"SPCGA-I02: empty pipeline preserves empty topology"
	)


# =============================================================================
# CYCLE PIPELINE
# =============================================================================

func _test_cycle_pipeline() -> void:

	var distance_topic: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var health_topic: Array[StringName] = [
		BusTopics.HEALTH_REPORT,
	]

	var profile_a := _profile(
		&"test.pipeline.cycle_a",
		distance_topic,
		health_topic
	)

	var profile_b := _profile(
		&"test.pipeline.cycle_b",
		health_topic,
		distance_topic
	)

	var catalog_draft := DeviceCatalogDraft.new()

	catalog_draft.profiles.append(
		profile_a
	)

	catalog_draft.profiles.append(
		profile_b
	)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)

	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog != null,
		"SPCGA-I03: cycle Catalog compiles"
	)

	if catalog == null:
		return

	var configuration_a := _configuration(
		"pipeline_cycle_a",
		profile_a,
		distance_topic,
		health_topic,
		"pipeline_cycle_a"
	)

	var configuration_b := _configuration(
		"pipeline_cycle_b",
		profile_b,
		health_topic,
		distance_topic,
		"pipeline_cycle_b"
	)

	var system_draft := _system_draft(
		&"test.pipeline.cycle_system"
	)

	system_draft.device_configurations.append(
		configuration_a
	)

	system_draft.device_configurations.append(
		configuration_b
	)

	system_draft.connection_specs.append(
		SystemConnectionSpec.new(
			"pipeline_cycle_a",
			_output_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			),
			"pipeline_cycle_b",
			_input_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			)
		)
	)

	system_draft.connection_specs.append(
		SystemConnectionSpec.new(
			"pipeline_cycle_b",
			_output_port_id(
				BusTopics.HEALTH_REPORT
			),
			"pipeline_cycle_a",
			_input_port_id(
				BusTopics.HEALTH_REPORT
			)
		)
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	var system_profile := system_result.get_profile()

	_expect(
		system_result.is_success()
		and system_profile != null,
		"SPCGA-I03: cycle SystemProfile compiles"
	)

	if system_profile == null:
		return

	var assembly_result := DeviceGraphAssembler.new().assemble(
		system_profile,
		catalog
	)

	var snapshot := assembly_result.get_snapshot()

	_expect(
		assembly_result.is_success()
		and snapshot != null,
		"SPCGA-I03: cycle assembles for Simulation"
	)

	_expect(
		_report_has_severity(
			assembly_result.get_report(),
			&"graph_cycle_requires_temporal_analysis",
			ValidationIssue.Severity.SIMULATION_HAZARD
		),
		"SPCGA-I03: cycle Hazard reaches final Result"
	)

	_expect(
		assembly_result.get_report().is_valid_for_simulation()
		and not assembly_result.get_report().is_valid_for_hardware(),
		"SPCGA-I03: cycle allows Simulation and blocks Hardware"
	)

	_expect(
		snapshot != null
		and snapshot.get_connections().size() == 2,
		"SPCGA-I03: cycle Snapshot contains both Connections"
	)


# =============================================================================
# SNAPSHOT STABILITY
# =============================================================================

func _test_snapshot_stability() -> void:

	var profile := _profile(
		&"test.pipeline.stable",
		_empty_topics(),
		_empty_topics()
	)

	var catalog_draft := DeviceCatalogDraft.new()

	catalog_draft.profiles.append(
		profile
	)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)

	var catalog := catalog_result.get_catalog()

	if catalog == null:

		_expect(
			false,
			"SPCGA-I04: stability Catalog is created"
		)

		return

	var configuration := _configuration(
		"stable_pipeline_device",
		profile,
		_empty_topics(),
		_empty_topics(),
		"stable_pipeline"
	)

	var system_draft := _system_draft(
		&"test.pipeline.stable_system"
	)

	system_draft.device_configurations.append(
		configuration
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	var system_profile := system_result.get_profile()

	if system_profile == null:

		_expect(
			false,
			"SPCGA-I04: stability SystemProfile is created"
		)

		return

	catalog_draft.profiles.clear()
	system_draft.device_configurations.clear()

	var assembly_result := DeviceGraphAssembler.new().assemble(
		system_profile,
		catalog
	)

	var snapshot := assembly_result.get_snapshot()

	_expect(
		assembly_result.is_success()
		and snapshot != null,
		"SPCGA-I04: compiled snapshots survive Draft mutations"
	)

	_expect(
		catalog.get_profiles().size() == 1
		and system_profile.get_device_configurations().size() == 1,
		"SPCGA-I04: Catalog and SystemProfile remain stable"
	)

	_expect(
		snapshot != null
		and snapshot.get_devices().size() == 1
		and snapshot.get_device(
			"stable_pipeline_device"
		) != null,
		"SPCGA-I04: stable inputs produce expected Graph Node"
	)


# =============================================================================
# NO RUNTIME
# =============================================================================

func _test_pipeline_has_no_runtime() -> void:

	var assembler := DeviceGraphAssembler.new()
	var empty_snapshot := DeviceGraphSnapshot.new()

	_expect(
		not assembler.has_method(
			&"execute"
		)
		and not assembler.has_method(
			&"activate"
		)
		and not assembler.has_method(
			&"create_device"
		),
		"SPCGA-I05: Assembler exposes no runtime API"
	)

	_expect(
		not empty_snapshot.has_method(
			&"execute"
		)
		and not empty_snapshot.has_method(
			&"activate"
		)
		and not empty_snapshot.has_method(
			&"publish"
		),
		"SPCGA-I05: final Snapshot remains non-executable"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _system_draft(
	system_profile_id: StringName
) -> SystemProfileDraft:

	var draft := SystemProfileDraft.new()

	draft.system_profile_id = system_profile_id
	draft.system_profile_version = 1
	draft.display_name = "Pipeline Integration"
	draft.description = "Full composition pipeline fixture."
	draft.activation_context = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	return draft


func _profile(
	profile_id: StringName,
	publishes: Array[StringName],
	subscribes: Array[StringName]
) -> DeviceProfile:

	var capabilities: Array[String] = [
		"pipeline_integration",
	]

	var requirements: Array[String] = []

	return DeviceProfile.new(
		profile_id,
		1,
		"Pipeline Profile",
		"Full pipeline fixture.",
		DeviceRoles.LOCAL_CONTROLLER,
		capabilities,
		publishes,
		subscribes,
		requirements,
		false,
		&"",
		0
	)


func _configuration(
	device_id: String,
	profile: DeviceProfile,
	publishes: Array[StringName],
	subscribes: Array[StringName],
	suffix: String
) -> DeviceConfiguration:

	var configuration_id := StringName(
		"test."
		+ suffix
		+ ".configuration"
	)

	var capabilities: Array[String] = [
		"pipeline_integration",
	]

	var requirements: Array[String] = []

	return DeviceConfiguration.new(
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


func _output_port_id(
	topic: StringName
) -> StringName:

	return StringName(
		"out." + String(topic)
	)


func _input_port_id(
	topic: StringName
) -> StringName:

	return StringName(
		"in." + String(topic)
	)


func _empty_topics() -> Array[StringName]:

	var topics: Array[StringName] = []

	return topics


# =============================================================================
# REPORT HELPERS
# =============================================================================

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
