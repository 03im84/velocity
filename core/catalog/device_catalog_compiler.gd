extends RefCounted
class_name DeviceCatalogCompiler


##
## DeviceCatalogCompiler
##
## Valida DeviceCatalogDraft y produce
## un DeviceCatalog snapshot.
##
## No modifica Draft ni DeviceProfiles.
##


func compile(
	draft: DeviceCatalogDraft
) -> DeviceCatalogCompileResult:

	var report := ValidationReport.new()

	if draft == null:

		_add_structural_error(
			report,
			&"device_catalog_draft_missing",
			"DeviceCatalogDraft is required.",
			"",
			&"draft"
		)

		return DeviceCatalogCompileResult.new(
			null,
			report
		)

	_validate_profiles(
		draft.profiles,
		report
	)

	if not report.is_valid_for_simulation():

		return DeviceCatalogCompileResult.new(
			null,
			report
		)

	var catalog := DeviceCatalog.new(
		draft.profiles
	)

	if not catalog.is_valid():

		_add_structural_error(
			report,
			&"device_catalog_snapshot_invalid",
			"Compiled DeviceCatalog is invalid.",
			"",
			&"catalog"
		)

		return DeviceCatalogCompileResult.new(
			null,
			report
		)

	return DeviceCatalogCompileResult.new(
		catalog,
		report
	)


# =============================================================================
# PROFILE VALIDATION
# =============================================================================

func _validate_profiles(
	profiles: Array[DeviceProfile],
	report: ValidationReport
) -> void:

	var seen_by_id: Dictionary = {}

	for profile_index: int in range(
		profiles.size()
	):

		var profile: DeviceProfile = profiles[
			profile_index
		]

		if profile == null:

			_add_structural_error(
				report,
				&"device_catalog_profile_missing",
				"DeviceProfile is required.",
				str(profile_index),
				&"profiles"
			)

			continue

		if not profile.is_valid():

			_add_structural_error(
				report,
				&"device_catalog_profile_invalid",
				"DeviceProfile is invalid.",
				String(
					profile.get_profile_id()
				),
				&"profiles"
			)

			continue

		var profile_id: StringName = (
			profile.get_profile_id()
		)

		var profile_version: int = (
			profile.get_profile_version()
		)

		var seen_versions: Dictionary = {}

		if seen_by_id.has(profile_id):

			seen_versions = seen_by_id[
				profile_id
			]

		if seen_versions.has(
			profile_version
		):

			_add_structural_error(
				report,
				&"duplicate_device_profile_identity",
				"DeviceProfile identity is duplicated.",
				String(profile_id),
				&"profile_version"
			)

			continue

		seen_versions[
			profile_version
		] = true

		seen_by_id[
			profile_id
		] = seen_versions


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
