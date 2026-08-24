extends Node


##
## DeviceGraphAssemblerTest
##
## Verifica assembly por etapas,
## resolución exacta y salida transaccional.
##


const TestResolverScript = preload(
	"res://test/core/composition/system_profile_test_resolver.gd"
)


class InvalidAvailabilityResolver:

	extends RefCounted

	func has_profile(
		_profile_id: StringName,
		_profile_version: int
	) -> Variant:

		return "invalid"

	func get_profile(
		_profile_id: StringName,
		_profile_version: int
	) -> DeviceProfile:

		return null


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceGraphAssemblerTest")
	print("========================================")

	_test_required_inputs()
	_test_hardware_context()
	_test_empty_system_profile()
	_test_device_stage_aggregation()
	_test_configuration_context_mismatch()
	_test_dependency_validation()
	_test_duplicate_device_stage_failure()
	_test_valid_assembly()
	_test_connection_stage_aggregation()
	_test_fan_in_failure()
	_test_cycle_snapshot()
	_test_input_non_mutation()
	_test_result_contract()
	_test_assembler_contract()

	_finish_test()


# =============================================================================
# REQUIRED INPUTS
# =============================================================================

func _test_required_inputs() -> void:

	var assembler := DeviceGraphAssembler.new()
	var resolver := TestResolverScript.new()

	_expect_assembly_failure(
		assembler.assemble(
			null,
			resolver
		),
		&"device_graph_assembly_system_profile_missing",
		"DGA-U01: null SystemProfile"
	)

	var invalid_context_profile := _system_profile(
		&"test.invalid_context",
		-1,
		_empty_configurations(),
		_empty_specs()
	)

	_expect_assembly_failure(
		assembler.assemble(
			invalid_context_profile,
			resolver
		),
		&"device_graph_assembly_activation_context_invalid",
		"DGA-U01: invalid Activation Context"
	)

	var invalid_identity_profile := _system_profile(
		&"",
		DeviceConfiguration.ActivationContext.SIMULATION,
		_empty_configurations(),
		_empty_specs()
	)

	_expect_assembly_failure(
		assembler.assemble(
			invalid_identity_profile,
			resolver
		),
		&"device_graph_assembly_system_profile_invalid",
		"DGA-U01: invalid SystemProfile identity"
	)

	var valid_empty_profile := _empty_system_profile()

	_expect_assembly_failure(
		assembler.assemble(
			valid_empty_profile,
			null
		),
		&"device_profile_resolver_missing",
		"DGA-U01: null Resolver"
	)

	var incomplete_resolver := RefCounted.new()

	_expect_assembly_failure(
		assembler.assemble(
			valid_empty_profile,
			incomplete_resolver
		),
		&"device_profile_resolver_contract_invalid",
		"DGA-U01: incomplete Resolver"
	)


# =============================================================================
# HARDWARE
# =============================================================================

func _test_hardware_context() -> void:

	var hardware_profile := _system_profile(
		&"test.hardware_system",
		DeviceConfiguration.ActivationContext.HARDWARE,
		_empty_configurations(),
		_empty_specs()
	)

	var result := DeviceGraphAssembler.new().assemble(
		hardware_profile,
		TestResolverScript.new()
	)

	_expect_assembly_failure(
		result,
		&"device_graph_assembly_hardware_not_supported",
		"DGA-U02: Hardware assembly"
	)

	_expect(
		_report_has_severity(
			result.get_report(),
			&"device_graph_assembly_hardware_not_supported",
			ValidationIssue.Severity.HARDWARE_SAFETY_ERROR
		),
		"DGA-U02: Hardware rejection uses Hardware Safety Error"
	)

	_expect(
		result.get_report().is_valid_for_simulation(),
		"DGA-U02: Hardware Safety Error remains visible to Simulation"
	)


# =============================================================================
# EMPTY SYSTEM PROFILE
# =============================================================================

func _test_empty_system_profile() -> void:

	var result := DeviceGraphAssembler.new().assemble(
		_empty_system_profile(),
		TestResolverScript.new()
	)

	var snapshot := result.get_snapshot()

	_expect(
		result.is_success(),
		"DGA-U03: empty SystemProfile assembles successfully"
	)

	_expect(
		snapshot != null,
		"DGA-U03: empty SystemProfile produces Snapshot"
	)

	if snapshot == null:
		return

	_expect(
		result.get_report().get_issues().is_empty(),
		"DGA-U03: empty assembly has no Issues"
	)

	_expect(
		snapshot.is_valid(),
		"DGA-U03: empty Snapshot is valid"
	)

	_expect(
		snapshot.get_devices().is_empty()
		and snapshot.get_connections().is_empty()
		and snapshot.get_topic_channels().is_empty(),
		"DGA-U03: empty Snapshot has empty topology"
	)


# =============================================================================
# DEVICE STAGE
# =============================================================================

func _test_device_stage_aggregation() -> void:

	var valid_profile := _profile(
		&"test.device_stage",
		_empty_topics(),
		_empty_topics()
	)

	var invalid_configuration := _configuration(
		"",
		valid_profile,
		DeviceConfiguration.ActivationContext.SIMULATION,
		_empty_topics(),
		_empty_topics(),
		"invalid"
	)

	var missing_profile := _profile(
		&"test.device_stage_missing",
		_empty_topics(),
		_empty_topics()
	)

	var missing_dependency_configuration := _configuration(
		"missing_dependency",
		missing_profile,
		DeviceConfiguration.ActivationContext.SIMULATION,
		_empty_topics(),
		_empty_topics(),
		"missing"
	)

	var configurations: Array[DeviceConfiguration] = [
		null,
		invalid_configuration,
		missing_dependency_configuration,
	]

	var specs: Array[SystemConnectionSpec] = [
		null,
	]

	var system_profile := _system_profile(
		&"test.device_stage_aggregation",
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		specs
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		valid_profile
	)

	var original_configurations := (
		system_profile.get_device_configurations()
	)

	var original_specs := (
		system_profile.get_connection_specs()
	)

	var result := DeviceGraphAssembler.new().assemble(
		system_profile,
		resolver
	)

	_expect(
		not result.is_success()
		and result.get_snapshot() == null,
		"DGA-U04: Device stage errors block Snapshot"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"device_graph_assembly_configuration_missing"
		),
		"DGA-U04: null Configuration is reported"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"device_graph_assembly_configuration_invalid"
		),
		"DGA-U04: invalid Configuration is reported"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"device_graph_assembly_dependency_missing"
		),
		"DGA-U04: missing dependency is reported"
	)

	_expect(
		not _report_has_code(
			result.get_report(),
			&"device_graph_assembly_connection_spec_missing"
		),
		"DGA-U04: Connection stage is gated after Device errors"
	)

	_expect(
		system_profile.get_device_configurations()
		== original_configurations
		and system_profile.get_connection_specs()
		== original_specs,
		"DGA-U04: Device stage does not modify SystemProfile Arrays"
	)


func _test_configuration_context_mismatch() -> void:

	var profile := _profile(
		&"test.context_mismatch",
		_empty_topics(),
		_empty_topics()
	)

	var configuration := _configuration(
		"hardware_configuration",
		profile,
		DeviceConfiguration.ActivationContext.HARDWARE,
		_empty_topics(),
		_empty_topics(),
		"context_mismatch"
	)

	var configurations: Array[DeviceConfiguration] = [
		configuration,
	]

	var system_profile := _system_profile(
		&"test.context_mismatch_system",
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		_empty_specs()
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		profile
	)

	_expect_assembly_failure(
		DeviceGraphAssembler.new().assemble(
			system_profile,
			resolver
		),
		&"device_graph_assembly_configuration_context_mismatch",
		"DGA-U05: Configuration context mismatch"
	)


# =============================================================================
# DEPENDENCY VALIDATION
# =============================================================================

func _test_dependency_validation() -> void:

	var requested_profile := _profile(
		&"test.requested_dependency",
		_empty_topics(),
		_empty_topics()
	)

	var system_profile := _single_device_system(
		"dependency_device",
		requested_profile,
		"dependency"
	)

	var null_profile_resolver := TestResolverScript.new()

	null_profile_resolver.register_profile_as(
		requested_profile.get_profile_id(),
		requested_profile.get_profile_version(),
		null
	)

	_expect_assembly_failure(
		DeviceGraphAssembler.new().assemble(
			system_profile,
			null_profile_resolver
		),
		&"device_graph_assembly_dependency_invalid",
		"DGA-U06: Resolver returns null Profile"
	)

	var invalid_profile := _invalid_profile()
	var invalid_profile_resolver := TestResolverScript.new()

	invalid_profile_resolver.register_profile_as(
		requested_profile.get_profile_id(),
		requested_profile.get_profile_version(),
		invalid_profile
	)

	_expect_assembly_failure(
		DeviceGraphAssembler.new().assemble(
			system_profile,
			invalid_profile_resolver
		),
		&"device_graph_assembly_dependency_invalid",
		"DGA-U06: Resolver returns invalid Profile"
	)

	var wrong_profile := _profile(
		&"test.wrong_dependency",
		_empty_topics(),
		_empty_topics()
	)

	var mismatch_resolver := TestResolverScript.new()

	mismatch_resolver.register_profile_as(
		requested_profile.get_profile_id(),
		requested_profile.get_profile_version(),
		wrong_profile
	)

	_expect_assembly_failure(
		DeviceGraphAssembler.new().assemble(
			system_profile,
			mismatch_resolver
		),
		&"device_graph_assembly_dependency_identity_mismatch",
		"DGA-U06: resolved Profile identity mismatch"
	)

	var invalid_availability := InvalidAvailabilityResolver.new()

	_expect_assembly_failure(
		DeviceGraphAssembler.new().assemble(
			system_profile,
			invalid_availability
		),
		&"device_graph_assembly_dependency_invalid",
		"DGA-U06: Resolver returns non-bool availability"
	)


func _test_duplicate_device_stage_failure() -> void:

	var profile := _profile(
		&"test.duplicate_device_profile",
		_empty_topics(),
		_empty_topics()
	)

	var first_configuration := _configuration(
		"duplicate_device",
		profile,
		DeviceConfiguration.ActivationContext.SIMULATION,
		_empty_topics(),
		_empty_topics(),
		"duplicate_first"
	)

	var second_configuration := _configuration(
		"duplicate_device",
		profile,
		DeviceConfiguration.ActivationContext.SIMULATION,
		_empty_topics(),
		_empty_topics(),
		"duplicate_second"
	)

	var configurations: Array[DeviceConfiguration] = [
		first_configuration,
		second_configuration,
	]

	var system_profile := _system_profile(
		&"test.duplicate_device_system",
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		_empty_specs()
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		profile
	)

	_expect_assembly_failure(
		DeviceGraphAssembler.new().assemble(
			system_profile,
			resolver
		),
		&"duplicate_device_id",
		"DGA-U07: duplicate Device ID during Graph add"
	)


# =============================================================================
# VALID ASSEMBLY
# =============================================================================

func _test_valid_assembly() -> void:

	var distance_topic: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var source_profile := _profile(
		&"test.valid_source_profile",
		distance_topic,
		_empty_topics()
	)

	var target_profile := _profile(
		&"test.valid_target_profile",
		_empty_topics(),
		distance_topic
	)

	var source_configuration := _configuration(
		"valid_source",
		source_profile,
		DeviceConfiguration.ActivationContext.SIMULATION,
		distance_topic,
		_empty_topics(),
		"valid_source"
	)

	var target_configuration := _configuration(
		"valid_target",
		target_profile,
		DeviceConfiguration.ActivationContext.SIMULATION,
		_empty_topics(),
		distance_topic,
		"valid_target"
	)

	var configurations: Array[DeviceConfiguration] = [
		source_configuration,
		target_configuration,
	]

	var spec := SystemConnectionSpec.new(
		"valid_source",
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"valid_target",
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
	)

	var specs: Array[SystemConnectionSpec] = [
		spec,
	]

	var system_profile := _system_profile(
		&"test.valid_assembly",
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		specs
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		source_profile
	)

	resolver.register_profile(
		target_profile
	)

	var result := DeviceGraphAssembler.new().assemble(
		system_profile,
		resolver
	)

	var snapshot := result.get_snapshot()

	_expect(
		result.is_success(),
		"DGA-U08: valid SystemProfile assembles successfully"
	)

	_expect(
		snapshot != null,
		"DGA-U08: valid assembly produces Snapshot"
	)

	if snapshot == null:
		return

	_expect(
		result.get_report().get_issues().is_empty(),
		"DGA-U08: valid assembly has no Issues"
	)

	_expect(
		snapshot.is_valid(),
		"DGA-U08: assembled Snapshot is valid"
	)

	var nodes := snapshot.get_devices()
	var connections := snapshot.get_connections()

	_expect(
		nodes.size() == 2
		and nodes[0].get_device_id()
		== "valid_source"
		and nodes[1].get_device_id()
		== "valid_target",
		"DGA-U08: Device order follows Configurations"
	)

	_expect(
		connections.size() == 1
		and connections[0].get_connection_id()
		== spec.get_connection_id(),
		"DGA-U08: Connection order and ID are preserved"
	)

	_expect(
		snapshot.get_topic_channels().size() == 1
		and snapshot.get_topic_channels()[0].get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"DGA-U08: TopicChannel is derived"
	)

	_expect(
		nodes[0].get_profile() == source_profile
		and nodes[1].get_profile() == target_profile,
		"DGA-U08: resolved Profile references are preserved"
	)

	_expect(
		nodes[0].get_configuration()
		== source_configuration
		and nodes[1].get_configuration()
		== target_configuration,
		"DGA-U08: Configuration references are preserved"
	)


# =============================================================================
# CONNECTION STAGE
# =============================================================================

func _test_connection_stage_aggregation() -> void:

	var publishes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var subscribes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
		BusTopics.HEALTH_REPORT,
	]

	var source_profile := _profile(
		&"test.connection_source_profile",
		publishes,
		_empty_topics()
	)

	var target_profile := _profile(
		&"test.connection_target_profile",
		_empty_topics(),
		subscribes
	)

	var source_configuration := _configuration(
		"connection_source",
		source_profile,
		DeviceConfiguration.ActivationContext.SIMULATION,
		publishes,
		_empty_topics(),
		"connection_source"
	)

	var target_configuration := _configuration(
		"connection_target",
		target_profile,
		DeviceConfiguration.ActivationContext.SIMULATION,
		_empty_topics(),
		subscribes,
		"connection_target"
	)

	var configurations: Array[DeviceConfiguration] = [
		source_configuration,
		target_configuration,
	]

	var specs: Array[SystemConnectionSpec] = [
		null,
		SystemConnectionSpec.new(
			"connection_source",
			&"out.missing",
			"connection_target",
			_input_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			)
		),
		SystemConnectionSpec.new(
			"connection_source",
			_output_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			),
			"connection_target",
			&"in.missing"
		),
		SystemConnectionSpec.new(
			"connection_source",
			_output_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			),
			"connection_target",
			_input_port_id(
				BusTopics.HEALTH_REPORT
			)
		),
		SystemConnectionSpec.new(
			"connection_source",
			&"out.topic",
			"connection_source",
			&"in.topic"
		),
	]

	var system_profile := _system_profile(
		&"test.connection_aggregation",
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		specs
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		source_profile
	)

	resolver.register_profile(
		target_profile
	)

	var result := DeviceGraphAssembler.new().assemble(
		system_profile,
		resolver
	)

	_expect(
		not result.is_success()
		and result.get_snapshot() == null,
		"DGA-U09: Connection stage errors block Snapshot"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"device_graph_assembly_connection_spec_missing"
		),
		"DGA-U09: null Spec is reported"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"source_port_not_found"
		),
		"DGA-U09: missing Source Port is reported"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"target_port_not_found"
		),
		"DGA-U09: missing Target Port is reported"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"connection_topic_mismatch"
		),
		"DGA-U09: Topic mismatch is reported"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"device_graph_assembly_connection_spec_invalid"
		),
		"DGA-U09: invalid Spec is reported"
	)

	_expect(
		not _report_has_code(
			result.get_report(),
			&"device_graph_assembly_configuration_invalid"
		),
		"DGA-U09: Connection errors do not fabricate Device errors"
	)


func _test_fan_in_failure() -> void:

	var distance_topic: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var source_profile := _profile(
		&"test.fanin_source_profile",
		distance_topic,
		_empty_topics()
	)

	var target_profile := _profile(
		&"test.fanin_target_profile",
		_empty_topics(),
		distance_topic
	)

	var configurations: Array[DeviceConfiguration] = [
		_configuration(
			"fanin_a",
			source_profile,
			DeviceConfiguration.ActivationContext.SIMULATION,
			distance_topic,
			_empty_topics(),
			"fanin_a"
		),
		_configuration(
			"fanin_b",
			source_profile,
			DeviceConfiguration.ActivationContext.SIMULATION,
			distance_topic,
			_empty_topics(),
			"fanin_b"
		),
		_configuration(
			"fanin_target",
			target_profile,
			DeviceConfiguration.ActivationContext.SIMULATION,
			_empty_topics(),
			distance_topic,
			"fanin_target"
		),
	]

	var specs: Array[SystemConnectionSpec] = [
		_distance_spec(
			"fanin_a",
			"fanin_target"
		),
		_distance_spec(
			"fanin_b",
			"fanin_target"
		),
	]

	var system_profile := _system_profile(
		&"test.fanin_assembly",
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		specs
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		source_profile
	)

	resolver.register_profile(
		target_profile
	)

	var result := DeviceGraphAssembler.new().assemble(
		system_profile,
		resolver
	)

	_expect(
		not result.is_success()
		and result.get_snapshot() == null,
		"DGA-U10: fan-in blocks Snapshot"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"input_port_multiple_sources"
		),
		"DGA-U10: fan-in code is preserved"
	)


# =============================================================================
# CYCLE
# =============================================================================

func _test_cycle_snapshot() -> void:

	var distance_topic: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var health_topic: Array[StringName] = [
		BusTopics.HEALTH_REPORT,
	]

	var profile_a := _profile(
		&"test.cycle_profile_a",
		distance_topic,
		health_topic
	)

	var profile_b := _profile(
		&"test.cycle_profile_b",
		health_topic,
		distance_topic
	)

	var configurations: Array[DeviceConfiguration] = [
		_configuration(
			"cycle_a",
			profile_a,
			DeviceConfiguration.ActivationContext.SIMULATION,
			distance_topic,
			health_topic,
			"cycle_a"
		),
		_configuration(
			"cycle_b",
			profile_b,
			DeviceConfiguration.ActivationContext.SIMULATION,
			health_topic,
			distance_topic,
			"cycle_b"
		),
	]

	var specs: Array[SystemConnectionSpec] = [
		SystemConnectionSpec.new(
			"cycle_a",
			_output_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			),
			"cycle_b",
			_input_port_id(
				BusTopics.DISTANCE_MEASUREMENT
			)
		),
		SystemConnectionSpec.new(
			"cycle_b",
			_output_port_id(
				BusTopics.HEALTH_REPORT
			),
			"cycle_a",
			_input_port_id(
				BusTopics.HEALTH_REPORT
			)
		),
	]

	var system_profile := _system_profile(
		&"test.cycle_assembly",
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		specs
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		profile_a
	)

	resolver.register_profile(
		profile_b
	)

	var result := DeviceGraphAssembler.new().assemble(
		system_profile,
		resolver
	)

	var snapshot := result.get_snapshot()

	_expect(
		result.is_success()
		and snapshot != null,
		"DGA-U11: cycle assembles for Simulation"
	)

	_expect(
		_report_has_severity(
			result.get_report(),
			&"graph_cycle_requires_temporal_analysis",
			ValidationIssue.Severity.SIMULATION_HAZARD
		),
		"DGA-U11: cycle Hazard is preserved"
	)

	_expect(
		result.get_report().is_valid_for_simulation(),
		"DGA-U11: cycle Report allows Simulation"
	)

	_expect(
		not result.get_report().is_valid_for_hardware(),
		"DGA-U11: cycle Report blocks Hardware"
	)

	_expect(
		snapshot != null
		and snapshot.get_connections().size() == 2,
		"DGA-U11: cycle Snapshot preserves Connections"
	)


# =============================================================================
# INPUT NON-MUTATION
# =============================================================================

func _test_input_non_mutation() -> void:

	var profile := _profile(
		&"test.non_mutation_profile",
		_empty_topics(),
		_empty_topics()
	)

	var configuration := _configuration(
		"non_mutation_device",
		profile,
		DeviceConfiguration.ActivationContext.SIMULATION,
		_empty_topics(),
		_empty_topics(),
		"non_mutation"
	)

	var configurations: Array[DeviceConfiguration] = [
		configuration,
	]

	var system_profile := _system_profile(
		&"test.non_mutation_system",
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		_empty_specs()
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		profile
	)

	var profile_count_before: int = (
		resolver.get_profile_count()
	)

	var result := DeviceGraphAssembler.new().assemble(
		system_profile,
		resolver
	)

	_expect(
		result.is_success(),
		"DGA-U12: non-mutation fixture assembles"
	)

	_expect(
		system_profile.get_device_configurations().size()
		== 1
		and system_profile.get_device_configurations()[0]
		== configuration,
		"DGA-U12: SystemProfile Configurations are unchanged"
	)

	_expect(
		system_profile.get_connection_specs().is_empty(),
		"DGA-U12: SystemProfile Specs are unchanged"
	)

	_expect(
		resolver.get_profile_count() == profile_count_before
		and resolver.get_profile(
			profile.get_profile_id(),
			profile.get_profile_version()
		) == profile,
		"DGA-U12: Resolver contents are unchanged"
	)


# =============================================================================
# RESULT CONTRACT
# =============================================================================

func _test_result_contract() -> void:

	var valid_report := ValidationReport.new()
	var valid_snapshot := DeviceGraphSnapshot.new()

	var null_snapshot_result := DeviceGraphAssemblyResult.new(
		null,
		valid_report
	)

	_expect(
		not null_snapshot_result.is_success(),
		"DGA-U13: null Snapshot produces failed Result"
	)

	var null_report_result := DeviceGraphAssemblyResult.new(
		valid_snapshot,
		null
	)

	_expect(
		not null_report_result.is_success(),
		"DGA-U13: null Report produces failed Result"
	)

	var invalid_nodes: Array[DeviceGraphNode] = [
		null,
	]

	var invalid_snapshot := DeviceGraphSnapshot.new(
		invalid_nodes,
		_empty_graph_connections(),
		_empty_graph_channels()
	)

	var invalid_snapshot_result := DeviceGraphAssemblyResult.new(
		invalid_snapshot,
		valid_report
	)

	_expect(
		not invalid_snapshot.is_valid()
		and not invalid_snapshot_result.is_success(),
		"DGA-U13: valid Report cannot approve invalid Snapshot"
	)

	var valid_result := DeviceGraphAssemblyResult.new(
		valid_snapshot,
		valid_report
	)

	_expect(
		valid_result.is_success(),
		"DGA-U13: valid Snapshot and Report produce success"
	)

	_expect(
		valid_result.get_snapshot() == valid_snapshot
		and valid_result.get_report() == valid_report,
		"DGA-U13: Result preserves Snapshot and Report"
	)

	_expect(
		not valid_result.has_method(
			&"set_snapshot"
		)
		and not valid_result.has_method(
			&"set_report"
		),
		"DGA-U13: Result exposes no setters"
	)


# =============================================================================
# ASSEMBLER CONTRACT
# =============================================================================

func _test_assembler_contract() -> void:

	var assembler := DeviceGraphAssembler.new()
	var assembler_value: Variant = assembler

	_expect(
		assembler_value is RefCounted,
		"DGA-U14: Assembler is RefCounted"
	)

	_expect(
		not (assembler_value is Node),
		"DGA-U14: Assembler is not Node"
	)

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
		"DGA-U14: Assembler has no runtime API"
	)

	_expect(
		not assembler.has_method(
			&"save"
		)
		and not assembler.has_method(
			&"load"
		),
		"DGA-U14: Assembler has no persistence API"
	)

	_expect(
		not assembler.has_method(
			&"get_last_snapshot"
		)
		and not assembler.has_method(
			&"get_last_profile"
		),
		"DGA-U14: Assembler stores no last operation state"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _empty_system_profile() -> SystemProfile:

	return _system_profile(
		&"test.empty_assembly",
		DeviceConfiguration.ActivationContext.SIMULATION,
		_empty_configurations(),
		_empty_specs()
	)


func _single_device_system(
	device_id: String,
	profile: DeviceProfile,
	suffix: String
) -> SystemProfile:

	var configuration := _configuration(
		device_id,
		profile,
		DeviceConfiguration.ActivationContext.SIMULATION,
		_empty_topics(),
		_empty_topics(),
		suffix
	)

	var configurations: Array[DeviceConfiguration] = [
		configuration,
	]

	return _system_profile(
		StringName(
			"test." + suffix + ".system"
		),
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		_empty_specs()
	)


func _system_profile(
	profile_id: StringName,
	activation_context: int,
	configurations: Array[DeviceConfiguration],
	specs: Array[SystemConnectionSpec]
) -> SystemProfile:

	return SystemProfile.new(
		profile_id,
		1,
		"Assembler Test System",
		"DeviceGraphAssembler fixture.",
		activation_context,
		configurations,
		specs
	)


func _profile(
	profile_id: StringName,
	publishes: Array[StringName],
	subscribes: Array[StringName]
) -> DeviceProfile:

	var capabilities: Array[String] = [
		"graph_assembly",
	]

	var requirements: Array[String] = []

	return DeviceProfile.new(
		profile_id,
		1,
		"Assembly Test Profile",
		"DeviceGraphAssembler fixture.",
		DeviceRoles.LOCAL_CONTROLLER,
		capabilities,
		publishes,
		subscribes,
		requirements,
		false,
		&"",
		0
	)


func _invalid_profile() -> DeviceProfile:

	return _profile(
		&"",
		_empty_topics(),
		_empty_topics()
	)


func _configuration(
	device_id: String,
	profile: DeviceProfile,
	activation_context: int,
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
		"graph_assembly",
	]

	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		configuration_id,
		1,
		device_id,
		profile.get_profile_id(),
		profile.get_profile_version(),
		activation_context,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _distance_spec(
	source_device_id: String,
	target_device_id: String
) -> SystemConnectionSpec:

	return SystemConnectionSpec.new(
		source_device_id,
		_output_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		),
		target_device_id,
		_input_port_id(
			BusTopics.DISTANCE_MEASUREMENT
		)
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


func _empty_configurations() -> Array[DeviceConfiguration]:

	var configurations: Array[DeviceConfiguration] = []

	return configurations


func _empty_specs() -> Array[SystemConnectionSpec]:

	var specs: Array[SystemConnectionSpec] = []

	return specs


func _empty_graph_connections() -> Array[DeviceGraphConnection]:

	var connections: Array[DeviceGraphConnection] = []

	return connections


func _empty_graph_channels() -> Array[DeviceGraphTopicChannel]:

	var channels: Array[DeviceGraphTopicChannel] = []

	return channels


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


func _expect_assembly_failure(
	result: DeviceGraphAssemblyResult,
	code: StringName,
	description: String
) -> void:

	_expect(
		not result.is_success(),
		description + " is rejected"
	)

	_expect(
		result.get_snapshot() == null,
		description + " produces null Snapshot"
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
