extends RefCounted
class_name DeviceManifestBuilder


##
## DeviceManifestBuilder
##
## Construye DeviceManifest efectivo
## utilizando snapshots validados.
##
## No acepta Drafts.
## No modifica Profile ni Configuration.
##


func build(
	profile: DeviceProfile,
	configuration: DeviceConfiguration
) -> DeviceManifestBuildResult:

	var report := ValidationReport.new()

	if profile == null:

		_add_structural_error(
			report,
			&"profile_missing",
			"DeviceProfile is required.",
			"",
			&"profile"
		)

		return DeviceManifestBuildResult.new(
			null,
			report
		)

	if configuration == null:

		_add_structural_error(
			report,
			&"configuration_missing",
			"DeviceConfiguration is required.",
			"",
			&"configuration"
		)

		return DeviceManifestBuildResult.new(
			null,
			report
		)

	if not profile.is_valid():

		_add_structural_error(
			report,
			&"profile_invalid",
			"DeviceProfile is invalid.",
			String(profile.get_profile_id()),
			&"profile"
		)

	if not configuration.is_valid():

		_add_structural_error(
			report,
			&"configuration_invalid",
			"DeviceConfiguration is invalid.",
			String(
				configuration.get_configuration_id()
			),
			&"configuration"
		)

	if (
		profile.get_profile_id()
		!= configuration.get_profile_id()
		or profile.get_profile_version()
		!= configuration.get_profile_version()
	):

		_add_structural_error(
			report,
			&"profile_reference_mismatch",
			(
				"Configuration does not reference "
				+ "the supplied Profile."
			),
			String(
				configuration.get_configuration_id()
			),
			&"profile_id"
		)

	if (
		configuration.get_activation_context()
		!= DeviceConfiguration.ActivationContext.SIMULATION
	):

		_add_structural_error(
			report,
			&"activation_context_not_supported",
			(
				"DeviceManifestBuilder 1.0 "
				+ "supports Simulation Mode only."
			),
			String(
				configuration.get_configuration_id()
			),
			&"activation_context"
		)

	if not report.is_valid_for_simulation():

		return DeviceManifestBuildResult.new(
			null,
			report
		)

	var manifest := DeviceManifest.new()

	manifest.capabilities = (
		configuration.get_enabled_capabilities()
	)

	manifest.publishes = (
		configuration.get_enabled_publishes()
	)

	manifest.subscribes = (
		configuration.get_enabled_subscribes()
	)

	manifest.requirements = (
		_merge_requirements(
			profile.get_requirements(),
			configuration
				.get_additional_requirements()
		)
	)

	return DeviceManifestBuildResult.new(
		manifest,
		report
	)


# =============================================================================
# REQUIREMENTS
# =============================================================================

func _merge_requirements(
	profile_requirements: Array[String],
	additional_requirements: Array[String]
) -> Array[String]:

	var merged_requirements: Array[String] = (
		profile_requirements.duplicate()
	)

	for requirement: String in (
		additional_requirements
	):

		if merged_requirements.has(requirement):
			continue

		merged_requirements.append(requirement)

	return merged_requirements


# =============================================================================
# VALIDATION HELPERS
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
