extends RefCounted
class_name RuntimeFactoryRegistryCompiler


##
## RuntimeFactoryRegistryCompiler
##
## Valida RuntimeFactoryRegistryDraft
## y produce un RuntimeFactoryRegistry
## inmutable.
##
## No modifica el Draft o sus Descriptors.
## No ejecuta factories.
##


func compile(
	draft: RuntimeFactoryRegistryDraft
) -> RuntimeFactoryRegistryCompileResult:

	var report := ValidationReport.new()

	if draft == null:

		_add_structural_error(
			report,
			&"runtime_factory_registry_draft_missing",
			"RuntimeFactoryRegistryDraft is required.",
			"",
			&"draft"
		)

		return RuntimeFactoryRegistryCompileResult.new(
			null,
			report
		)

	_validate_descriptors(
		draft.descriptors,
		report
	)

	if not report.is_valid_for_simulation():

		return RuntimeFactoryRegistryCompileResult.new(
			null,
			report
		)

	var registry := RuntimeFactoryRegistry.new(
		draft.descriptors
	)

	if not registry.is_valid():

		_add_structural_error(
			report,
			&"runtime_factory_registry_snapshot_invalid",
			"Compiled RuntimeFactoryRegistry is invalid.",
			"",
			&"registry"
		)

		return RuntimeFactoryRegistryCompileResult.new(
			null,
			report
		)

	return RuntimeFactoryRegistryCompileResult.new(
		registry,
		report
	)


# =============================================================================
# DESCRIPTOR VALIDATION
# =============================================================================

func _validate_descriptors(
	descriptors: Array[RuntimeFactoryDescriptor],
	report: ValidationReport
) -> void:

	var seen_by_profile: Dictionary = {}

	for descriptor_index: int in range(
		descriptors.size()
	):

		var descriptor: RuntimeFactoryDescriptor = descriptors[
			descriptor_index
		]

		if descriptor == null:

			_add_structural_error(
				report,
				&"runtime_factory_descriptor_missing",
				"RuntimeFactoryDescriptor is required.",
				str(descriptor_index),
				&"descriptors"
			)

			continue

		if not descriptor.is_valid():

			_add_structural_error(
				report,
				&"runtime_factory_descriptor_invalid",
				"RuntimeFactoryDescriptor is invalid.",
				str(descriptor_index),
				&"descriptors"
			)

			continue

		var factory_key := descriptor.get_factory_key()

		var profile_id: StringName = (
			factory_key.get_profile_id()
		)

		var profile_version: int = (
			factory_key.get_profile_version()
		)

		var activation_context: int = (
			factory_key.get_activation_context()
		)

		var seen_versions: Dictionary = {}

		if seen_by_profile.has(
			profile_id
		):

			seen_versions = seen_by_profile[
				profile_id
			]

		var seen_contexts: Dictionary = {}

		if seen_versions.has(
			profile_version
		):

			seen_contexts = seen_versions[
				profile_version
			]

		if seen_contexts.has(
			activation_context
		):

			_add_structural_error(
				report,
				&"duplicate_runtime_factory_key",
				"RuntimeFactoryKey is duplicated.",
				String(profile_id),
				&"factory_key"
			)

			continue

		seen_contexts[
			activation_context
		] = true

		seen_versions[
			profile_version
		] = seen_contexts

		seen_by_profile[
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
