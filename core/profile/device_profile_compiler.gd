extends RefCounted
class_name DeviceProfileCompiler


##
## DeviceProfileCompiler
##
## Valida DeviceProfileDraft y produce
## DeviceProfile derivado e inmutable.
##
## No crea Profiles canónicos.
##


const RESERVED_NAMESPACE_PREFIX: String = (
	"velocity."
)


func compile(
	draft: DeviceProfileDraft
) -> DeviceProfileCompileResult:

	var report := ValidationReport.new()

	if draft == null:

		_add_structural_error(
			report,
			&"profile_draft_missing",
			"DeviceProfileDraft is required.",
			"",
			&"draft"
		)

		return DeviceProfileCompileResult.new(
			null,
			report
		)

	_validate_identity(
		draft,
		report
	)

	_validate_namespace(
		draft,
		report
	)

	_validate_duplicates(
		draft,
		report
	)

	if not report.is_valid_for_simulation():

		return DeviceProfileCompileResult.new(
			null,
			report
		)

	var profile := DeviceProfile.new(
		draft.profile_id,
		draft.profile_version,
		draft.display_name,
		draft.description,
		draft.primary_role,
		draft.capabilities,
		draft.supported_publishes,
		draft.supported_subscribes,
		draft.requirements,
		false,
		draft.based_on_profile_id,
		draft.based_on_profile_version
	)

	if not profile.is_valid():

		_add_structural_error(
			report,
			&"profile_snapshot_invalid",
			"Compiled DeviceProfile is invalid.",
			String(draft.profile_id),
			&"profile"
		)

		return DeviceProfileCompileResult.new(
			null,
			report
		)

	return DeviceProfileCompileResult.new(
		profile,
		report
	)


# =============================================================================
# IDENTITY VALIDATION
# =============================================================================

func _validate_identity(
	draft: DeviceProfileDraft,
	report: ValidationReport
) -> void:

	var object_id: String = (
		String(draft.profile_id)
	)

	if draft.profile_id == &"":

		_add_structural_error(
			report,
			&"profile_id_missing",
			"Profile ID is required.",
			object_id,
			&"profile_id"
		)

	if draft.profile_version <= 0:

		_add_structural_error(
			report,
			&"profile_version_invalid",
			"Profile version must be greater than zero.",
			object_id,
			&"profile_version"
		)

	if draft.display_name.is_empty():

		_add_structural_error(
			report,
			&"profile_display_name_missing",
			"Display name is required.",
			object_id,
			&"display_name"
		)

	if not DeviceRoles.is_valid(
		draft.primary_role
	):

		_add_structural_error(
			report,
			&"profile_role_invalid",
			"Primary role is not registered.",
			object_id,
			&"primary_role"
		)

	if (
		draft.based_on_profile_id == &""
		and draft.based_on_profile_version != 0
	):

		_add_structural_error(
			report,
			&"profile_parent_invalid",
			"Root Profile requires parent version zero.",
			object_id,
			&"based_on_profile_version"
		)

	if (
		draft.based_on_profile_id != &""
		and draft.based_on_profile_version <= 0
	):

		_add_structural_error(
			report,
			&"profile_parent_invalid",
			"Derived Profile requires a parent version.",
			object_id,
			&"based_on_profile_version"
		)


# =============================================================================
# NAMESPACE VALIDATION
# =============================================================================

func _validate_namespace(
	draft: DeviceProfileDraft,
	report: ValidationReport
) -> void:

	var profile_id_text: String = (
		String(draft.profile_id)
	)

	if profile_id_text.begins_with(
		RESERVED_NAMESPACE_PREFIX
	):

		_add_structural_error(
			report,
			&"reserved_profile_namespace",
			"The velocity namespace is reserved.",
			profile_id_text,
			&"profile_id"
		)


# =============================================================================
# DUPLICATE VALIDATION
# =============================================================================

func _validate_duplicates(
	draft: DeviceProfileDraft,
	report: ValidationReport
) -> void:

	var object_id: String = (
		String(draft.profile_id)
	)

	if _has_duplicates(
		draft.capabilities
	):

		_add_structural_error(
			report,
			&"duplicate_capability",
			"Capabilities contain duplicates.",
			object_id,
			&"capabilities"
		)

	if _has_duplicates(
		draft.supported_publishes
	):

		_add_structural_error(
			report,
			&"duplicate_publish_topic",
			"Published topics contain duplicates.",
			object_id,
			&"supported_publishes"
		)

	if _has_duplicates(
		draft.supported_subscribes
	):

		_add_structural_error(
			report,
			&"duplicate_subscribe_topic",
			"Subscribed topics contain duplicates.",
			object_id,
			&"supported_subscribes"
		)

	if _has_duplicates(
		draft.requirements
	):

		_add_structural_error(
			report,
			&"duplicate_requirement",
			"Requirements contain duplicates.",
			object_id,
			&"requirements"
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
