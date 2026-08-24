extends RefCounted
class_name DeviceGraphAssembler


##
## DeviceGraphAssembler
##
## Construye DeviceGraphSnapshot desde
## SystemProfile y DeviceProfileResolver.
##
## No crea Devices runtime.
##


func assemble(
	system_profile: SystemProfile,
	profile_resolver: Object
) -> DeviceGraphAssemblyResult:

	var report := ValidationReport.new()

	if system_profile == null:

		_add_structural_error(
			report,
			&"device_graph_assembly_system_profile_missing",
			"SystemProfile is required.",
			"",
			&"system_profile"
		)

		return DeviceGraphAssemblyResult.new(
			null,
			report
		)

	var activation_context: int = (
		system_profile.get_activation_context()
	)

	if not _activation_context_is_valid(
		activation_context
	):

		_add_structural_error(
			report,
			&"device_graph_assembly_activation_context_invalid",
			"SystemProfile Activation Context is invalid.",
			String(
				system_profile.get_system_profile_id()
			),
			&"activation_context"
		)

		return DeviceGraphAssemblyResult.new(
			null,
			report
		)

	if not system_profile.is_valid_identity():

		_add_structural_error(
			report,
			&"device_graph_assembly_system_profile_invalid",
			"SystemProfile identity is invalid.",
			String(
				system_profile.get_system_profile_id()
			),
			&"system_profile"
		)

		return DeviceGraphAssemblyResult.new(
			null,
			report
		)

	if profile_resolver == null:

		_add_structural_error(
			report,
			&"device_profile_resolver_missing",
			"DeviceProfileResolver is required.",
			String(
				system_profile.get_system_profile_id()
			),
			&"profile_resolver"
		)

		return DeviceGraphAssemblyResult.new(
			null,
			report
		)

	if not _resolver_contract_is_valid(
		profile_resolver
	):

		_add_structural_error(
			report,
			&"device_profile_resolver_contract_invalid",
			"DeviceProfileResolver contract is incomplete.",
			String(
				system_profile.get_system_profile_id()
			),
			&"profile_resolver"
		)

		return DeviceGraphAssemblyResult.new(
			null,
			report
		)

	if (
		activation_context
		== DeviceConfiguration.ActivationContext.HARDWARE
	):

		_add_issue(
			report,
			&"device_graph_assembly_hardware_not_supported",
			ValidationIssue.Severity.HARDWARE_SAFETY_ERROR,
			"Hardware DeviceGraph assembly is not supported.",
			String(
				system_profile.get_system_profile_id()
			),
			&"activation_context"
		)

		return DeviceGraphAssemblyResult.new(
			null,
			report
		)

	var graph := DeviceGraphDraft.new()

	_assemble_devices(
		system_profile,
		profile_resolver,
		graph,
		report
	)

	if not report.is_valid_for_simulation():

		return DeviceGraphAssemblyResult.new(
			null,
			report
		)

	_assemble_connections(
		system_profile,
		graph,
		report
	)

	if not report.is_valid_for_simulation():

		return DeviceGraphAssemblyResult.new(
			null,
			report
		)

	var snapshot_result := graph.create_snapshot()

	_merge_report(
		report,
		snapshot_result.get_report()
	)

	var snapshot := snapshot_result.get_snapshot()

	if (
		not snapshot_result.is_success()
		or snapshot == null
	):

		if report.is_valid_for_simulation():

			_add_structural_error(
				report,
				&"device_graph_assembly_snapshot_missing",
				"DeviceGraphSnapshot was not created.",
				String(
					system_profile.get_system_profile_id()
				),
				&"snapshot"
			)

		return DeviceGraphAssemblyResult.new(
			null,
			report
		)

	return DeviceGraphAssemblyResult.new(
		snapshot,
		report
	)


# =============================================================================
# DEVICE STAGE
# =============================================================================

func _assemble_devices(
	system_profile: SystemProfile,
	profile_resolver: Object,
	graph: DeviceGraphDraft,
	report: ValidationReport
) -> void:

	var configurations := (
		system_profile.get_device_configurations()
	)

	for configuration_index: int in range(
		configurations.size()
	):

		var configuration: DeviceConfiguration = (
			configurations[configuration_index]
		)

		if configuration == null:

			_add_structural_error(
				report,
				&"device_graph_assembly_configuration_missing",
				"DeviceConfiguration is required.",
				str(configuration_index),
				&"device_configurations"
			)

			continue

		var device_id: String = (
			configuration.get_device_id()
		)

		if not configuration.is_valid():

			_add_structural_error(
				report,
				&"device_graph_assembly_configuration_invalid",
				"DeviceConfiguration is invalid.",
				device_id,
				&"device_configurations"
			)

			continue

		if (
			configuration.get_activation_context()
			!= system_profile.get_activation_context()
		):

			_add_structural_error(
				report,
				&"device_graph_assembly_configuration_context_mismatch",
				"DeviceConfiguration context does not match SystemProfile.",
				device_id,
				&"activation_context"
			)

			continue

		var profile := _resolve_profile(
			configuration,
			profile_resolver,
			report
		)

		if profile == null:
			continue

		var manifest_result := (
			DeviceManifestBuilder.new().build(
				profile,
				configuration
			)
		)

		var manifest_report := manifest_result.get_report()

		_merge_report(
			report,
			manifest_report
		)

		if manifest_report == null:
			continue

		var manifest := manifest_result.get_manifest()

		if manifest == null:

			if manifest_report.is_valid_for_simulation():

				_add_structural_error(
					report,
					&"device_graph_assembly_manifest_missing",
					"DeviceManifest was not created.",
					device_id,
					&"manifest"
				)

			continue

		if not manifest_report.is_valid_for_simulation():
			continue

		var node_result := (
			DeviceGraphNodeBuilder.new().build(
				device_id,
				profile,
				configuration,
				manifest
			)
		)

		var node_report := node_result.get_report()

		_merge_report(
			report,
			node_report
		)

		if node_report == null:
			continue

		var node := node_result.get_node()

		if node == null:

			if node_report.is_valid_for_simulation():

				_add_structural_error(
					report,
					&"device_graph_assembly_node_missing",
					"DeviceGraphNode was not created.",
					device_id,
					&"node"
				)

			continue

		if not node_report.is_valid_for_simulation():
			continue

		var add_result := graph.add_device(
			node
		)

		var add_report := add_result.get_report()

		_merge_report(
			report,
			add_report
		)

		if (
			not add_result.is_success()
			and add_report != null
			and add_report.is_valid_for_simulation()
		):

			_add_structural_error(
				report,
				&"device_graph_assembly_add_device_failed",
				"DeviceGraphDraft rejected Device without reporting an error.",
				device_id,
				&"device"
			)


func _resolve_profile(
	configuration: DeviceConfiguration,
	profile_resolver: Object,
	report: ValidationReport
) -> DeviceProfile:

	var device_id: String = (
		configuration.get_device_id()
	)

	var profile_id: StringName = (
		configuration.get_profile_id()
	)

	var profile_version: int = (
		configuration.get_profile_version()
	)

	var has_profile_value: Variant = (
		profile_resolver.call(
			&"has_profile",
			profile_id,
			profile_version
		)
	)

	if typeof(has_profile_value) != TYPE_BOOL:

		_add_structural_error(
			report,
			&"device_graph_assembly_dependency_invalid",
			"DeviceProfileResolver returned invalid availability result.",
			device_id,
			&"profile_id"
		)

		return null

	if not bool(has_profile_value):

		_add_structural_error(
			report,
			&"device_graph_assembly_dependency_missing",
			"Referenced DeviceProfile is not available.",
			device_id,
			&"profile_id"
		)

		return null

	var profile_value: Variant = (
		profile_resolver.call(
			&"get_profile",
			profile_id,
			profile_version
		)
	)

	var profile: DeviceProfile = (
		profile_value as DeviceProfile
	)

	if profile == null:

		_add_structural_error(
			report,
			&"device_graph_assembly_dependency_invalid",
			"DeviceProfileResolver returned invalid Profile.",
			device_id,
			&"profile_id"
		)

		return null

	if not profile.is_valid():

		_add_structural_error(
			report,
			&"device_graph_assembly_dependency_invalid",
			"Resolved DeviceProfile is invalid.",
			device_id,
			&"profile_id"
		)

		return null

	if (
		profile.get_profile_id() != profile_id
		or profile.get_profile_version() != profile_version
	):

		_add_structural_error(
			report,
			&"device_graph_assembly_dependency_identity_mismatch",
			"Resolved DeviceProfile identity does not match reference.",
			device_id,
			&"profile_id"
		)

		return null

	return profile


# =============================================================================
# CONNECTION STAGE
# =============================================================================

func _assemble_connections(
	system_profile: SystemProfile,
	graph: DeviceGraphDraft,
	report: ValidationReport
) -> void:

	var specs := system_profile.get_connection_specs()

	for spec_index: int in range(
		specs.size()
	):

		var spec: SystemConnectionSpec = specs[
			spec_index
		]

		if spec == null:

			_add_structural_error(
				report,
				&"device_graph_assembly_connection_spec_missing",
				"SystemConnectionSpec is required.",
				str(spec_index),
				&"connection_specs"
			)

			continue

		if not spec.is_valid_identity():

			_add_structural_error(
				report,
				&"device_graph_assembly_connection_spec_invalid",
				"SystemConnectionSpec identity is invalid.",
				String(
					spec.get_connection_id()
				),
				&"connection_specs"
			)

			continue

		var connection_result := graph.connect_ports(
			spec.get_source_device_id(),
			spec.get_source_port_id(),
			spec.get_target_device_id(),
			spec.get_target_port_id()
		)

		var connection_report := connection_result.get_report()

		_merge_report(
			report,
			connection_report
		)

		if not connection_result.is_success():

			if (
				connection_report != null
				and connection_report.is_valid_for_simulation()
			):

				_add_structural_error(
					report,
					&"device_graph_assembly_connect_failed",
					"DeviceGraphDraft rejected Connection without reporting an error.",
					String(
						spec.get_connection_id()
					),
					&"connection"
				)

			continue

		if (
			connection_result.get_affected_id()
			!= spec.get_connection_id()
		):

			_add_structural_error(
				report,
				&"device_graph_assembly_connection_id_mismatch",
				"Graph Connection ID does not match SystemConnectionSpec.",
				String(
					spec.get_connection_id()
				),
				&"connection_id"
			)


# =============================================================================
# CONTRACT HELPERS
# =============================================================================

func _resolver_contract_is_valid(
	profile_resolver: Object
) -> bool:

	return (
		profile_resolver.has_method(
			&"has_profile"
		)
		and profile_resolver.has_method(
			&"get_profile"
		)
	)


func _activation_context_is_valid(
	context: int
) -> bool:

	return (
		context
		== DeviceConfiguration.ActivationContext.SIMULATION
		or context
		== DeviceConfiguration.ActivationContext.HARDWARE
	)


# =============================================================================
# REPORT MERGE
# =============================================================================

func _merge_report(
	target: ValidationReport,
	source: ValidationReport
) -> void:

	if source == null:

		_add_issue(
			target,
			&"device_graph_assembly_report_missing",
			ValidationIssue.Severity.PLATFORM_SAFETY_ERROR,
			"Assembly dependency returned null ValidationReport.",
			"",
			&"report"
		)

		return

	for issue: ValidationIssue in source.get_issues():

		target.add_issue(
			issue
		)


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
