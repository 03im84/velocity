extends Node


##
## SystemProfileDeviceCatalogIntegrationTest
##
## Verifica que SystemProfileCompiler
## utiliza DeviceCatalog mediante el contrato
## DeviceProfileResolver.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("SystemProfileDeviceCatalogIntegrationTest")
	print("========================================")

	_test_valid_catalog_resolution()
	_test_missing_exact_dependency()
	_test_multiple_version_resolution()
	_test_catalog_stability()

	_finish_test()


# =============================================================================
# VALID CATALOG RESOLUTION
# =============================================================================

func _test_valid_catalog_resolution() -> void:

	var source_profile := _profile(
		&"test.integration.source",
		1
	)

	var target_profile := _profile(
		&"test.integration.target",
		1
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
		catalog_result.is_success(),
		"SPDC-I01: valid Catalog compiles"
	)

	_expect(
		catalog != null,
		"SPDC-I01: Catalog snapshot is created"
	)

	if catalog == null:
		return

	_expect(
		catalog.has_profile(
			source_profile.get_profile_id(),
			source_profile.get_profile_version()
		)
		and catalog.has_profile(
			target_profile.get_profile_id(),
			target_profile.get_profile_version()
		),
		"SPDC-I01: Catalog exposes both exact dependencies"
	)

	var source_configuration := _configuration(
		"source",
		source_profile,
		"source"
	)

	var target_configuration := _configuration(
		"target",
		target_profile,
		"target"
	)

	var system_draft := _system_draft()

	system_draft.device_configurations.append(
		source_configuration
	)

	system_draft.device_configurations.append(
		target_configuration
	)

	system_draft.connection_specs.append(
		SystemConnectionSpec.new(
			"source",
			&"out.topic",
			"target",
			&"in.topic"
		)
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	var system_profile := system_result.get_profile()

	_expect(
		system_result.is_success(),
		"SPDC-I01: SystemProfileCompiler accepts DeviceCatalog"
	)

	_expect(
		system_profile != null,
		"SPDC-I01: SystemProfile snapshot is created"
	)

	if system_profile == null:
		return

	_expect(
		system_result.get_report().get_issues().is_empty(),
		"SPDC-I01: exact dependencies produce no Issues"
	)

	_expect(
		system_profile.get_device_configurations().size() == 2
		and system_profile.get_connection_specs().size() == 1,
		"SPDC-I01: composition contents are preserved"
	)

	_expect(
		system_profile.get_device_configuration(
			"source"
		) == source_configuration
		and system_profile.get_device_configuration(
			"target"
		) == target_configuration,
		"SPDC-I01: Configuration references are preserved"
	)

	_expect(
		catalog.get_profiles().size() == 2,
		"SPDC-I01: System compilation does not modify Catalog"
	)


# =============================================================================
# MISSING EXACT DEPENDENCY
# =============================================================================

func _test_missing_exact_dependency() -> void:

	var profile_v1 := _profile(
		&"test.integration.versioned",
		1
	)

	var profile_v2 := _profile(
		&"test.integration.versioned",
		2
	)

	var catalog_draft := DeviceCatalogDraft.new()

	catalog_draft.profiles.append(
		profile_v1
	)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)

	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog != null,
		"SPDC-I02: Catalog with version one compiles"
	)

	if catalog == null:
		return

	var system_draft := _system_draft()

	system_draft.device_configurations.append(
		_configuration(
			"version_two_device",
			profile_v2,
			"version_two"
		)
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	_expect(
		not system_result.is_success(),
		"SPDC-I02: missing exact version is rejected"
	)

	_expect(
		system_result.get_profile() == null,
		"SPDC-I02: missing exact version produces null SystemProfile"
	)

	_expect(
		_report_has_code(
			system_result.get_report(),
			&"system_profile_dependency_missing"
		),
		"SPDC-I02: missing dependency code is reported"
	)

	_expect(
		catalog.has_profile(
			profile_v1.get_profile_id(),
			1
		)
		and not catalog.has_profile(
			profile_v2.get_profile_id(),
			2
		),
		"SPDC-I02: Catalog does not substitute available version"
	)


# =============================================================================
# MULTIPLE VERSION RESOLUTION
# =============================================================================

func _test_multiple_version_resolution() -> void:

	var profile_v1 := _profile(
		&"test.integration.multi_version",
		1
	)

	var profile_v2 := _profile(
		&"test.integration.multi_version",
		2
	)

	var catalog_draft := DeviceCatalogDraft.new()

	catalog_draft.profiles.append(
		profile_v1
	)

	catalog_draft.profiles.append(
		profile_v2
	)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)

	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog != null,
		"SPDC-I03: multiple versions compile together"
	)

	if catalog == null:
		return

	var configuration_v2 := _configuration(
		"multi_version_device",
		profile_v2,
		"multi_version"
	)

	var system_draft := _system_draft()

	system_draft.device_configurations.append(
		configuration_v2
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	_expect(
		system_result.is_success(),
		"SPDC-I03: requested version two resolves exactly"
	)

	_expect(
		system_result.get_profile() != null
		and system_result.get_profile().get_device_configuration(
			"multi_version_device"
		).get_profile_version() == 2,
		"SPDC-I03: SystemProfile preserves requested version"
	)

	_expect(
		catalog.get_profile(
			profile_v1.get_profile_id(),
			1
		) == profile_v1
		and catalog.get_profile(
			profile_v2.get_profile_id(),
			2
		) == profile_v2,
		"SPDC-I03: both versions resolve independently"
	)

	_expect(
		not catalog.has_method(
			&"get_latest"
		),
		"SPDC-I03: integration exposes no latest fallback"
	)


# =============================================================================
# CATALOG STABILITY
# =============================================================================

func _test_catalog_stability() -> void:

	var profile := _profile(
		&"test.integration.stable",
		1
	)

	var catalog_draft := DeviceCatalogDraft.new()

	catalog_draft.profiles.append(
		profile
	)

	var catalog_result := DeviceCatalogCompiler.new().compile(
		catalog_draft
	)

	var catalog := catalog_result.get_catalog()

	_expect(
		catalog_result.is_success()
		and catalog != null,
		"SPDC-I04: stability Catalog compiles"
	)

	if catalog == null:
		return

	catalog_draft.profiles.clear()

	_expect(
		catalog.has_profile(
			profile.get_profile_id(),
			profile.get_profile_version()
		)
		and catalog.get_profiles().size() == 1,
		"SPDC-I04: Catalog remains stable after Draft mutation"
	)

	var system_draft := _system_draft()

	system_draft.device_configurations.append(
		_configuration(
			"stable_device",
			profile,
			"stable"
		)
	)

	var system_result := SystemProfileCompiler.new().compile(
		system_draft,
		catalog
	)

	_expect(
		system_result.is_success(),
		"SPDC-I04: stable Catalog remains usable as Resolver"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _system_draft() -> SystemProfileDraft:

	var draft := SystemProfileDraft.new()

	draft.system_profile_id = &"test.catalog_integration"
	draft.system_profile_version = 1
	draft.display_name = "Catalog Integration"
	draft.description = "DeviceCatalog integration fixture."
	draft.activation_context = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	return draft


func _profile(
	profile_id: StringName,
	profile_version: int
) -> DeviceProfile:

	var capabilities: Array[String] = [
		"catalog_integration",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceProfile.new(
		profile_id,
		profile_version,
		"Catalog Integration Profile",
		"DeviceCatalog integration fixture.",
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
	suffix: String
) -> DeviceConfiguration:

	var configuration_id := StringName(
		"test."
		+ suffix
		+ ".configuration"
	)

	var capabilities: Array[String] = [
		"catalog_integration",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
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
