extends Node


##
## DeviceCatalogCompilerTest
##
## Verifica compilación inmutable,
## múltiples versiones y resolución exacta.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceCatalogCompilerTest")
	print("========================================")

	_test_null_draft()
	_test_empty_catalog()
	_test_profile_validation()
	_test_duplicate_identity()
	_test_exact_resolution_and_versions()
	_test_canonical_and_user_profiles()
	_test_snapshot_independence()
	_test_result_contract()
	_test_catalog_contract()

	_finish_test()


# =============================================================================
# NULL DRAFT
# =============================================================================

func _test_null_draft() -> void:

	var result := DeviceCatalogCompiler.new().compile(
		null
	)

	_expect_compile_failure(
		result,
		&"device_catalog_draft_missing",
		"DCCAT-U01: null Draft"
	)


# =============================================================================
# EMPTY CATALOG
# =============================================================================

func _test_empty_catalog() -> void:

	var draft := DeviceCatalogDraft.new()

	var result := DeviceCatalogCompiler.new().compile(
		draft
	)

	var catalog := result.get_catalog()

	_expect(
		result.is_success(),
		"DCCAT-U02: empty Draft compiles successfully"
	)

	_expect(
		catalog != null,
		"DCCAT-U02: empty Draft produces Catalog"
	)

	if catalog == null:
		return

	_expect(
		result.get_report().get_issues().is_empty(),
		"DCCAT-U02: empty compilation has no Issues"
	)

	_expect(
		catalog.is_valid(),
		"DCCAT-U02: empty Catalog is valid"
	)

	_expect(
		catalog.get_profiles().is_empty(),
		"DCCAT-U02: empty Catalog has no Profiles"
	)

	_expect(
		not catalog.has_profile(
			&"test.missing",
			1
		),
		"DCCAT-U02: empty Catalog reports missing identity"
	)

	_expect(
		catalog.get_profile(
			&"test.missing",
			1
		) == null,
		"DCCAT-U02: empty Catalog returns null"
	)

	_expect(
		not catalog.has_profile(
			&"",
			0
		)
		and catalog.get_profile(
			&"",
			0
		) == null,
		"DCCAT-U02: invalid query is rejected safely"
	)


# =============================================================================
# PROFILE VALIDATION
# =============================================================================

func _test_profile_validation() -> void:

	var null_profile_draft := DeviceCatalogDraft.new()

	null_profile_draft.profiles.append(
		null
	)

	_expect_compile_failure(
		DeviceCatalogCompiler.new().compile(
			null_profile_draft
		),
		&"device_catalog_profile_missing",
		"DCCAT-U03: null Profile"
	)

	var invalid_profile_draft := DeviceCatalogDraft.new()

	invalid_profile_draft.profiles.append(
		_invalid_profile()
	)

	_expect_compile_failure(
		DeviceCatalogCompiler.new().compile(
			invalid_profile_draft
		),
		&"device_catalog_profile_invalid",
		"DCCAT-U03: invalid Profile"
	)


# =============================================================================
# DUPLICATE IDENTITY
# =============================================================================

func _test_duplicate_identity() -> void:

	var first := _profile(
		&"test.duplicate",
		1
	)

	var second := _profile(
		&"test.duplicate",
		1
	)

	var duplicate_instances := DeviceCatalogDraft.new()

	duplicate_instances.profiles.append(
		first
	)

	duplicate_instances.profiles.append(
		second
	)

	_expect_compile_failure(
		DeviceCatalogCompiler.new().compile(
			duplicate_instances
		),
		&"duplicate_device_profile_identity",
		"DCCAT-U04: duplicate identity from different instances"
	)

	var repeated_instance := DeviceCatalogDraft.new()

	repeated_instance.profiles.append(
		first
	)

	repeated_instance.profiles.append(
		first
	)

	_expect_compile_failure(
		DeviceCatalogCompiler.new().compile(
			repeated_instance
		),
		&"duplicate_device_profile_identity",
		"DCCAT-U04: repeated Profile instance"
	)


# =============================================================================
# EXACT RESOLUTION AND VERSIONS
# =============================================================================

func _test_exact_resolution_and_versions() -> void:

	var sensor_v1 := _profile(
		&"test.sensor",
		1
	)

	var sensor_v2 := _profile(
		&"test.sensor",
		2
	)

	var controller_v1 := _profile(
		&"test.controller",
		1
	)

	var draft := DeviceCatalogDraft.new()

	draft.profiles.append(sensor_v1)
	draft.profiles.append(sensor_v2)
	draft.profiles.append(controller_v1)

	var result := DeviceCatalogCompiler.new().compile(
		draft
	)

	var catalog := result.get_catalog()

	_expect(
		result.is_success()
		and catalog != null,
		"DCCAT-U05: multiple versions compile successfully"
	)

	if catalog == null:
		return

	var profiles := catalog.get_profiles()

	_expect(
		profiles.size() == 3
		and profiles[0] == sensor_v1
		and profiles[1] == sensor_v2
		and profiles[2] == controller_v1,
		"DCCAT-U05: Profile order is preserved"
	)

	_expect(
		catalog.has_profile(
			&"test.sensor",
			1
		)
		and catalog.has_profile(
			&"test.sensor",
			2
		)
		and catalog.has_profile(
			&"test.controller",
			1
		),
		"DCCAT-U05: exact identities are available"
	)

	_expect(
		catalog.get_profile(
			&"test.sensor",
			1
		) == sensor_v1
		and catalog.get_profile(
			&"test.sensor",
			2
		) == sensor_v2
		and catalog.get_profile(
			&"test.controller",
			1
		) == controller_v1,
		"DCCAT-U05: exact resolution returns correct references"
	)

	_expect(
		not catalog.has_profile(
			&"test.sensor",
			3
		)
		and catalog.get_profile(
			&"test.sensor",
			3
		) == null,
		"DCCAT-U05: missing version has no fallback"
	)

	_expect(
		not catalog.has_profile(
			&"test.unknown",
			1
		)
		and catalog.get_profile(
			&"test.unknown",
			1
		) == null,
		"DCCAT-U05: missing Profile ID returns null"
	)

	_expect(
		not catalog.has_profile(
			&"test.sensor",
			0
		)
		and catalog.get_profile(
			&"test.sensor",
			-1
		) == null,
		"DCCAT-U05: invalid versions are rejected"
	)

	_expect(
		result.get_report().get_issues().is_empty(),
		"DCCAT-U05: valid catalog compilation has no Issues"
	)


# =============================================================================
# CANONICAL AND USER PROFILES
# =============================================================================

func _test_canonical_and_user_profiles() -> void:

	var canonical := (
		BuiltinDeviceProfiles.create_ideal_distance_sensor()
	)

	var user_profile := _profile(
		&"test.user_profile",
		1
	)

	var draft := DeviceCatalogDraft.new()

	draft.profiles.append(canonical)
	draft.profiles.append(user_profile)

	var result := DeviceCatalogCompiler.new().compile(
		draft
	)

	var catalog := result.get_catalog()

	_expect(
		result.is_success()
		and catalog != null,
		"DCCAT-U06: canonical and user Profiles compile together"
	)

	if catalog == null:
		return

	_expect(
		catalog.get_profiles()[0] == canonical
		and catalog.get_profiles()[1] == user_profile,
		"DCCAT-U06: canonical flag does not change order"
	)

	_expect(
		catalog.has_profile(
			canonical.get_profile_id(),
			canonical.get_profile_version()
		)
		and catalog.has_profile(
			user_profile.get_profile_id(),
			user_profile.get_profile_version()
		),
		"DCCAT-U06: both Profile categories resolve exactly"
	)


# =============================================================================
# SNAPSHOT INDEPENDENCE
# =============================================================================

func _test_snapshot_independence() -> void:

	var first := _profile(
		&"test.independent",
		1
	)

	var second := _profile(
		&"test.independent",
		2
	)

	var draft := DeviceCatalogDraft.new()

	draft.profiles.append(first)
	draft.profiles.append(second)

	var result := DeviceCatalogCompiler.new().compile(
		draft
	)

	var catalog := result.get_catalog()

	_expect(
		result.is_success()
		and catalog != null,
		"DCCAT-U07: independence fixture compiles"
	)

	if catalog == null:
		return

	draft.profiles.clear()

	_expect(
		catalog.get_profiles().size() == 2,
		"DCCAT-U07: Draft mutation does not affect Catalog"
	)

	var profiles_copy := catalog.get_profiles()

	profiles_copy.clear()

	_expect(
		catalog.get_profiles().size() == 2,
		"DCCAT-U07: get_profiles returns independent Array"
	)

	_expect(
		catalog.get_profiles()[0] == first
		and catalog.get_profiles()[1] == second,
		"DCCAT-U07: immutable Profile references are preserved"
	)

	_expect(
		catalog.get_profile(
			&"test.independent",
			1
		) == first
		and catalog.get_profile(
			&"test.independent",
			2
		) == second,
		"DCCAT-U07: resolver remains stable after Draft mutation"
	)


# =============================================================================
# RESULT CONTRACT
# =============================================================================

func _test_result_contract() -> void:

	var valid_report := ValidationReport.new()
	var valid_catalog := DeviceCatalog.new()

	var duplicate := _profile(
		&"test.invalid_catalog",
		1
	)

	var duplicate_profiles: Array[DeviceProfile] = [
		duplicate,
		duplicate,
	]

	var invalid_catalog := DeviceCatalog.new(
		duplicate_profiles
	)

	_expect(
		not invalid_catalog.is_valid(),
		"DCCAT-U08: directly constructed duplicate Catalog is invalid"
	)

	var null_profiles: Array[DeviceProfile] = [
		null,
	]

	var null_profile_catalog := DeviceCatalog.new(
		null_profiles
	)

	_expect(
		not null_profile_catalog.is_valid(),
		"DCCAT-U08: directly constructed null Profile Catalog is invalid"
	)

	var null_catalog_result := DeviceCatalogCompileResult.new(
		null,
		valid_report
	)

	_expect(
		not null_catalog_result.is_success(),
		"DCCAT-U08: null Catalog produces failed Result"
	)

	var null_report_result := DeviceCatalogCompileResult.new(
		valid_catalog,
		null
	)

	_expect(
		not null_report_result.is_success(),
		"DCCAT-U08: null Report produces failed Result"
	)

	var invalid_catalog_result := DeviceCatalogCompileResult.new(
		invalid_catalog,
		valid_report
	)

	_expect(
		not invalid_catalog_result.is_success(),
		"DCCAT-U08: valid Report cannot approve invalid Catalog"
	)

	var valid_result := DeviceCatalogCompileResult.new(
		valid_catalog,
		valid_report
	)

	_expect(
		valid_result.is_success(),
		"DCCAT-U08: valid Catalog and Report produce success"
	)

	_expect(
		valid_result.get_catalog() == valid_catalog
		and valid_result.get_report() == valid_report,
		"DCCAT-U08: Result preserves Catalog and Report"
	)

	_expect(
		not valid_result.has_method(
			&"set_catalog"
		)
		and not valid_result.has_method(
			&"set_report"
		),
		"DCCAT-U08: Result exposes no setters"
	)


# =============================================================================
# CATALOG CONTRACT
# =============================================================================

func _test_catalog_contract() -> void:

	var catalog := DeviceCatalog.new()
	var catalog_value: Variant = catalog

	_expect(
		catalog_value is RefCounted,
		"DCCAT-U09: Catalog is RefCounted"
	)

	_expect(
		not (catalog_value is Node),
		"DCCAT-U09: Catalog is not Node"
	)

	_expect(
		not catalog.has_method(
			&"register_profile"
		)
		and not catalog.has_method(
			&"remove_profile"
		)
		and not catalog.has_method(
			&"replace_profile"
		),
		"DCCAT-U09: Catalog exposes no mutation API"
	)

	_expect(
		not catalog.has_method(
			&"get_latest"
		)
		and not catalog.has_method(
			&"get_compatible"
		),
		"DCCAT-U09: Catalog exposes no fallback resolution"
	)

	_expect(
		not catalog.has_method(
			&"save"
		)
		and not catalog.has_method(
			&"load"
		),
		"DCCAT-U09: Catalog has no persistence API"
	)

	_expect(
		not catalog.has_method(
			&"create_device"
		)
		and not catalog.has_method(
			&"get_factory"
		)
		and not catalog.has_method(
			&"execute"
		),
		"DCCAT-U09: Catalog has no runtime responsibility"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _profile(
	profile_id: StringName,
	profile_version: int
) -> DeviceProfile:

	var capabilities: Array[String] = [
		"catalog_test",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceProfile.new(
		profile_id,
		profile_version,
		"Catalog Test Profile",
		"DeviceCatalogCompiler fixture.",
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

	var capabilities: Array[String] = [
		"catalog_test",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceProfile.new(
		&"",
		1,
		"Invalid Catalog Profile",
		"Invalid fixture.",
		DeviceRoles.LOCAL_CONTROLLER,
		capabilities,
		publishes,
		subscribes,
		requirements,
		false,
		&"",
		0
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


func _expect_compile_failure(
	result: DeviceCatalogCompileResult,
	code: StringName,
	description: String
) -> void:

	_expect(
		not result.is_success(),
		description + " is rejected"
	)

	_expect(
		result.get_catalog() == null,
		description + " produces null Catalog"
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
