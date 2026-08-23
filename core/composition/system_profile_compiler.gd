extends RefCounted
class_name SystemProfileCompiler


##
## SystemProfileCompiler
##
## Valida SystemProfileDraft y produce
## un SystemProfile snapshot.
##
## No construye DeviceGraph.
## No abre ni guarda archivos.
##


func compile(
	draft: SystemProfileDraft,
	profile_resolver: Object
) -> SystemProfileCompileResult:

	var report := ValidationReport.new()

	if draft == null:

		_add_structural_error(
			report,
			&"system_profile_draft_missing",
			"SystemProfileDraft is required.",
			"",
			&"draft"
		)

		return SystemProfileCompileResult.new(
			null,
			report
		)

	if profile_resolver == null:

		_add_structural_error(
			report,
			&"device_profile_resolver_missing",
			"DeviceProfileResolver is required.",
			String(draft.system_profile_id),
			&"profile_resolver"
		)

		return SystemProfileCompileResult.new(
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
			String(draft.system_profile_id),
			&"profile_resolver"
		)

		return SystemProfileCompileResult.new(
			null,
			report
		)

	_validate_identity(
		draft,
		report
	)

	var configurations_by_device_id: Dictionary = {}

	_validate_configurations(
		draft,
		profile_resolver,
		configurations_by_device_id,
		report
	)

	_validate_connection_specs(
		draft,
		configurations_by_device_id,
		report
	)

	if not _report_allows_context(
		report,
		draft.activation_context
	):

		return SystemProfileCompileResult.new(
			null,
			report
		)

	var profile := SystemProfile.new(
		draft.system_profile_id,
		draft.system_profile_version,
		draft.display_name,
		draft.description,
		draft.activation_context,
		draft.device_configurations,
		draft.connection_specs
	)

	if not profile.is_valid_identity():

		_add_structural_error(
			report,
			&"system_profile_snapshot_invalid",
			"Compiled SystemProfile identity is invalid.",
			String(draft.system_profile_id),
			&"profile"
		)

		return SystemProfileCompileResult.new(
			null,
			report
		)

	return SystemProfileCompileResult.new(
		profile,
		report
	)


# =============================================================================
# IDENTITY VALIDATION
# =============================================================================

func _validate_identity(
	draft: SystemProfileDraft,
	report: ValidationReport
) -> void:

	if draft.system_profile_id == &"":

		_add_structural_error(
			report,
			&"system_profile_id_missing",
			"System Profile ID is required.",
			"",
			&"system_profile_id"
		)

	if draft.system_profile_version <= 0:

		_add_structural_error(
			report,
			&"system_profile_version_invalid",
			"System Profile version must be positive.",
			String(draft.system_profile_id),
			&"system_profile_version"
		)

	if draft.display_name.strip_edges().is_empty():

		_add_structural_error(
			report,
			&"system_profile_display_name_missing",
			"System Profile Display Name is required.",
			String(draft.system_profile_id),
			&"display_name"
		)

	if not _activation_context_is_valid(
		draft.activation_context
	):

		_add_structural_error(
			report,
			&"system_profile_activation_context_invalid",
			"System Profile Activation Context is invalid.",
			String(draft.system_profile_id),
			&"activation_context"
		)


# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================

func _validate_configurations(
	draft: SystemProfileDraft,
	profile_resolver: Object,
	configurations_by_device_id: Dictionary,
	report: ValidationReport
) -> void:

	for configuration_index: int in range(
		draft.device_configurations.size()
	):

		var configuration: DeviceConfiguration = (
			draft.device_configurations[
				configuration_index
			]
		)

		if configuration == null:

			_add_structural_error(
				report,
				&"system_profile_configuration_missing",
				"DeviceConfiguration is required.",
				str(configuration_index),
				&"device_configurations"
			)

			continue

		var device_id: String = (
			configuration.get_device_id()
		)

		if (
			not device_id.is_empty()
			and configurations_by_device_id.has(
				device_id
			)
		):

			_add_structural_error(
				report,
				&"duplicate_system_device_id",
				"Device ID is duplicated in SystemProfile.",
				device_id,
				&"device_id"
			)

		elif not device_id.is_empty():

			configurations_by_device_id[
				device_id
			] = configuration

		if not configuration.is_valid():

			_add_structural_error(
				report,
				&"system_profile_configuration_invalid",
				"DeviceConfiguration is invalid.",
				device_id,
				&"device_configurations"
			)

		if (
			configuration.get_activation_context()
			!= draft.activation_context
		):

			_add_structural_error(
				report,
				&"system_profile_activation_context_mismatch",
				"DeviceConfiguration Activation Context does not match SystemProfile.",
				device_id,
				&"activation_context"
			)

		if not configuration.is_valid():
			continue

		_validate_profile_dependency(
			configuration,
			profile_resolver,
			report
		)


func _validate_profile_dependency(
	configuration: DeviceConfiguration,
	profile_resolver: Object,
	report: ValidationReport
) -> void:

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
			&"system_profile_dependency_invalid",
			"DeviceProfileResolver returned invalid availability result.",
			device_id,
			&"profile_id"
		)

		return

	var has_profile: bool = bool(
		has_profile_value
	)

	if not has_profile:

		_add_structural_error(
			report,
			&"system_profile_dependency_missing",
			"Referenced DeviceProfile is not available.",
			device_id,
			&"profile_id"
		)

		return

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
			&"system_profile_dependency_invalid",
			"DeviceProfileResolver returned invalid Profile.",
			device_id,
			&"profile_id"
		)

		return

	if not profile.is_valid():

		_add_structural_error(
			report,
			&"system_profile_dependency_invalid",
			"Resolved DeviceProfile is invalid.",
			device_id,
			&"profile_id"
		)

		return

	if (
		profile.get_profile_id()
		!= profile_id
		or profile.get_profile_version()
		!= profile_version
	):

		_add_structural_error(
			report,
			&"system_profile_dependency_identity_mismatch",
			"Resolved DeviceProfile identity does not match reference.",
			device_id,
			&"profile_id"
		)


# =============================================================================
# CONNECTION SPEC VALIDATION
# =============================================================================

func _validate_connection_specs(
	draft: SystemProfileDraft,
	configurations_by_device_id: Dictionary,
	report: ValidationReport
) -> void:

	var specs_by_id: Dictionary = {}

	for spec_index: int in range(
		draft.connection_specs.size()
	):

		var spec: SystemConnectionSpec = (
			draft.connection_specs[
				spec_index
			]
		)

		if spec == null:

			_add_structural_error(
				report,
				&"system_connection_spec_missing",
				"SystemConnectionSpec is required.",
				str(spec_index),
				&"connection_specs"
			)

			continue

		var connection_id: StringName = (
			spec.get_connection_id()
		)

		if not spec.is_valid_identity():

			_add_structural_error(
				report,
				&"system_connection_spec_invalid",
				"SystemConnectionSpec identity is invalid.",
				String(connection_id),
				&"connection_specs"
			)

			continue

		if specs_by_id.has(connection_id):

			_add_structural_error(
				report,
				&"duplicate_system_connection",
				"System Connection is duplicated.",
				String(connection_id),
				&"connection_id"
			)

		else:

			specs_by_id[connection_id] = spec

		var source_device_id: String = (
			spec.get_source_device_id()
		)

		var target_device_id: String = (
			spec.get_target_device_id()
		)

		if not configurations_by_device_id.has(
			source_device_id
		):

			_add_structural_error(
				report,
				&"system_connection_source_device_not_found",
				"Source Device is not declared by SystemProfile.",
				source_device_id,
				&"source_device_id"
			)

		if not configurations_by_device_id.has(
			target_device_id
		):

			_add_structural_error(
				report,
				&"system_connection_target_device_not_found",
				"Target Device is not declared by SystemProfile.",
				target_device_id,
				&"target_device_id"
			)


# =============================================================================
# RESOLVER CONTRACT
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


# =============================================================================
# CONTEXT VALIDATION
# =============================================================================

func _activation_context_is_valid(
	context: int
) -> bool:

	return (
		context
		== DeviceConfiguration.ActivationContext.SIMULATION
		or context
		== DeviceConfiguration.ActivationContext.HARDWARE
	)


func _report_allows_context(
	report: ValidationReport,
	context: int
) -> bool:

	if (
		context
		== DeviceConfiguration.ActivationContext.SIMULATION
	):

		return report.is_valid_for_simulation()

	if (
		context
		== DeviceConfiguration.ActivationContext.HARDWARE
	):

		return report.is_valid_for_hardware()

	return false


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

	report.add_issue(
		ValidationIssue.new(
			code,
			ValidationIssue.Severity.STRUCTURAL_ERROR,
			message,
			related_object_id,
			related_field
		)
	)
