extends RefCounted
class_name DeviceConfigurationCompiler


##
## DeviceConfigurationCompiler
##
## Valida DeviceConfigurationDraft contra
## DeviceProfile y produce un snapshot
## para Simulation Mode.
##


func compile_for_simulation(
	draft: DeviceConfigurationDraft,
	profile: DeviceProfile
) -> DeviceConfigurationCompileResult:

	var report := ValidationReport.new()

	if draft == null:

		_add_structural_error(
			report,
			&"configuration_draft_missing",
			"DeviceConfigurationDraft is required.",
			"",
			&"draft"
		)

		return DeviceConfigurationCompileResult.new(
			null,
			report
		)

	if profile == null:

		_add_structural_error(
			report,
			&"configuration_profile_missing",
			"DeviceProfile is required.",
			String(draft.configuration_id),
			&"profile"
		)

		return DeviceConfigurationCompileResult.new(
			null,
			report
		)

	_validate_identity(
		draft,
		report
	)

	_validate_profile_reference(
		draft,
		profile,
		report
	)

	_validate_duplicates(
		draft,
		report
	)

	_validate_supported_selections(
		draft,
		profile,
		report
	)

	if not report.is_valid_for_simulation():

		return DeviceConfigurationCompileResult.new(
			null,
			report
		)

	var configuration := DeviceConfiguration.new(
		draft.configuration_id,
		draft.configuration_version,
		draft.device_id,
		draft.profile_id,
		draft.profile_version,
		DeviceConfiguration
			.ActivationContext.SIMULATION,
		draft.based_on_configuration_id,
		draft.based_on_configuration_version,
		draft.enabled_capabilities,
		draft.enabled_publishes,
		draft.enabled_subscribes,
		draft.additional_requirements
	)

	if not configuration.is_valid():

		_add_structural_error(
			report,
			&"configuration_snapshot_invalid",
			"Compiled DeviceConfiguration is invalid.",
			String(draft.configuration_id),
			&"configuration"
		)

		return DeviceConfigurationCompileResult.new(
			null,
			report
		)

	return DeviceConfigurationCompileResult.new(
		configuration,
		report
	)


# =============================================================================
# IDENTITY VALIDATION
# =============================================================================

func _validate_identity(
	draft: DeviceConfigurationDraft,
	report: ValidationReport
) -> void:

	var object_id: String = (
		String(draft.configuration_id)
	)

	if draft.configuration_id == &"":

		_add_structural_error(
			report,
			&"configuration_id_missing",
			"Configuration ID is required.",
			object_id,
			&"configuration_id"
		)

	if draft.configuration_version <= 0:

		_add_structural_error(
			report,
			&"configuration_version_invalid",
			"Configuration version must be greater than zero.",
			object_id,
			&"configuration_version"
		)

	if draft.device_id.is_empty():

		_add_structural_error(
			report,
			&"configuration_device_id_missing",
			"Device ID is required.",
			object_id,
			&"device_id"
		)

	if draft.profile_id == &"":

		_add_structural_error(
			report,
			&"configuration_profile_id_missing",
			"Profile ID is required.",
			object_id,
			&"profile_id"
		)

	if draft.profile_version <= 0:

		_add_structural_error(
			report,
			&"configuration_profile_version_invalid",
			"Profile version must be greater than zero.",
			object_id,
			&"profile_version"
		)

	if (
		draft.based_on_configuration_id == &""
		and draft.based_on_configuration_version != 0
	):

		_add_structural_error(
			report,
			&"configuration_parent_invalid",
			"Root Configuration requires parent version zero.",
			object_id,
			&"based_on_configuration_version"
		)

	if (
		draft.based_on_configuration_id != &""
		and draft.based_on_configuration_version <= 0
	):

		_add_structural_error(
			report,
			&"configuration_parent_invalid",
			"Derived Configuration requires a parent version.",
			object_id,
			&"based_on_configuration_version"
		)


# =============================================================================
# PROFILE REFERENCE
# =============================================================================

func _validate_profile_reference(
	draft: DeviceConfigurationDraft,
	profile: DeviceProfile,
	report: ValidationReport
) -> void:

	var object_id: String = (
		String(draft.configuration_id)
	)

	if (
		draft.profile_id
		!= profile.get_profile_id()
	):

		_add_structural_error(
			report,
			&"configuration_profile_id_mismatch",
			"Configuration Profile ID does not match.",
			object_id,
			&"profile_id"
		)

	if (
		draft.profile_version
		!= profile.get_profile_version()
	):

		_add_structural_error(
			report,
			&"configuration_profile_version_mismatch",
			"Configuration Profile version does not match.",
			object_id,
			&"profile_version"
		)


# =============================================================================
# DUPLICATE VALIDATION
# =============================================================================

func _validate_duplicates(
	draft: DeviceConfigurationDraft,
	report: ValidationReport
) -> void:

	var object_id: String = (
		String(draft.configuration_id)
	)

	if _has_duplicates(
		draft.enabled_capabilities
	):

		_add_structural_error(
			report,
			&"duplicate_enabled_capability",
			"Enabled capabilities contain duplicates.",
			object_id,
			&"enabled_capabilities"
		)

	if _has_duplicates(
		draft.enabled_publishes
	):

		_add_structural_error(
			report,
			&"duplicate_enabled_publish",
			"Enabled publishes contain duplicates.",
			object_id,
			&"enabled_publishes"
		)

	if _has_duplicates(
		draft.enabled_subscribes
	):

		_add_structural_error(
			report,
			&"duplicate_enabled_subscribe",
			"Enabled subscribes contain duplicates.",
			object_id,
			&"enabled_subscribes"
		)

	if _has_duplicates(
		draft.additional_requirements
	):

		_add_structural_error(
			report,
			&"duplicate_additional_requirement",
			"Additional requirements contain duplicates.",
			object_id,
			&"additional_requirements"
		)


# =============================================================================
# SUPPORTED SELECTIONS
# =============================================================================

func _validate_supported_selections(
	draft: DeviceConfigurationDraft,
	profile: DeviceProfile,
	report: ValidationReport
) -> void:

	var object_id: String = (
		String(draft.configuration_id)
	)

	_validate_subset(
		draft.enabled_capabilities,
		profile.get_capabilities(),
		report,
		&"unsupported_capability",
		object_id,
		&"enabled_capabilities"
	)

	_validate_subset(
		draft.enabled_publishes,
		profile.get_supported_publishes(),
		report,
		&"unsupported_publish",
		object_id,
		&"enabled_publishes"
	)

	_validate_subset(
		draft.enabled_subscribes,
		profile.get_supported_subscribes(),
		report,
		&"unsupported_subscribe",
		object_id,
		&"enabled_subscribes"
	)


func _validate_subset(
	values: Array,
	allowed_values: Array,
	report: ValidationReport,
	error_code: StringName,
	related_object_id: String,
	related_field: StringName
) -> void:

	for value: Variant in values:

		if allowed_values.has(value):
			continue

		_add_structural_error(
			report,
			error_code,
			"Configuration contains unsupported selection.",
			related_object_id,
			related_field
		)


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
			ValidationIssue.Severity
				.STRUCTURAL_ERROR,
			message,
			related_object_id,
			related_field
		)
	)
