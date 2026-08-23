extends Node


##
## DeviceConfigurationCompilerTest
##
## Verifica referencias, selecciones,
## duplicados y snapshots de Configuration.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceConfigurationCompilerTest")
	print("========================================")

	_test_null_draft()
	_test_null_profile()
	_test_profile_id_mismatch()
	_test_profile_version_mismatch()
	_test_unsupported_selections()
	_test_duplicate_lists()
	_test_valid_compilation()
	_test_snapshot_immutability()

	_finish_test()


# =============================================================================
# NULL INPUTS
# =============================================================================

func _test_null_draft() -> void:

	var profile := _profile()

	var result := (
		DeviceConfigurationCompiler.new()
			.compile_for_simulation(
				null,
				profile
			)
	)

	_expect(
		not result.is_success(),
		"DCC-U01: null Draft fails"
	)

	_expect(
		result.get_configuration() == null,
		"DCC-U01: null Draft produces no snapshot"
	)

	_expect(
		result.get_report().has_severity(
			ValidationIssue.Severity
				.STRUCTURAL_ERROR
		),
		"DCC-U01: null Draft produces structural error"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"configuration_draft_missing"
		),
		"DCC-U01: missing Draft code is reported"
	)


func _test_null_profile() -> void:

	var draft := _valid_draft()

	var result := (
		DeviceConfigurationCompiler.new()
			.compile_for_simulation(
				draft,
				null
			)
	)

	_expect(
		not result.is_success(),
		"DCC-U02: null Profile fails"
	)

	_expect(
		result.get_configuration() == null,
		"DCC-U02: null Profile produces no snapshot"
	)

	_expect(
		result.get_report().has_severity(
			ValidationIssue.Severity
				.STRUCTURAL_ERROR
		),
		"DCC-U02: null Profile produces structural error"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"configuration_profile_missing"
		),
		"DCC-U02: missing Profile code is reported"
	)


# =============================================================================
# PROFILE REFERENCE
# =============================================================================

func _test_profile_id_mismatch() -> void:

	var draft := _valid_draft()

	draft.profile_id = (
		&"velocity.other_profile"
	)

	var result := (
		DeviceConfigurationCompiler.new()
			.compile_for_simulation(
				draft,
				_profile()
			)
	)

	_expect(
		not result.is_success(),
		"DCC-U03: Profile ID mismatch fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"configuration_profile_id_mismatch"
		),
		"DCC-U03: ID mismatch code is reported"
	)


func _test_profile_version_mismatch() -> void:

	var draft := _valid_draft()

	draft.profile_version = 2

	var result := (
		DeviceConfigurationCompiler.new()
			.compile_for_simulation(
				draft,
				_profile()
			)
	)

	_expect(
		not result.is_success(),
		"DCC-U04: Profile version mismatch fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"configuration_profile_version_mismatch"
		),
		"DCC-U04: version mismatch code is reported"
	)


# =============================================================================
# UNSUPPORTED SELECTIONS
# =============================================================================

func _test_unsupported_selections() -> void:

	_test_unsupported_capability()

	_test_unsupported_publish()

	_test_unsupported_subscribe()


func _test_unsupported_capability() -> void:

	var draft := _valid_draft()

	draft.enabled_capabilities.append(
		"unsupported_capability"
	)

	var result := _compile(draft)

	_expect(
		not result.is_success(),
		"DCC-U05: unsupported capability fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"unsupported_capability"
		),
		"DCC-U05: capability error code is reported"
	)


func _test_unsupported_publish() -> void:

	var draft := _valid_draft()

	draft.enabled_publishes.append(
		&"unsupported_publish"
	)

	var result := _compile(draft)

	_expect(
		not result.is_success(),
		"DCC-U05: unsupported publish fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"unsupported_publish"
		),
		"DCC-U05: publish error code is reported"
	)


func _test_unsupported_subscribe() -> void:

	var draft := _valid_draft()

	draft.enabled_subscribes.append(
		&"unsupported_subscribe"
	)

	var result := _compile(draft)

	_expect(
		not result.is_success(),
		"DCC-U05: unsupported subscribe fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"unsupported_subscribe"
		),
		"DCC-U05: subscribe error code is reported"
	)


# =============================================================================
# DUPLICATES
# =============================================================================

func _test_duplicate_lists() -> void:

	_test_duplicate_capabilities()

	_test_duplicate_publishes()

	_test_duplicate_subscribes()

	_test_duplicate_requirements()


func _test_duplicate_capabilities() -> void:

	var draft := _valid_draft()

	draft.enabled_capabilities.append(
		"distance_measurement"
	)

	var result := _compile(draft)

	_expect(
		not result.is_success(),
		"DCC-U06: duplicate capability fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"duplicate_enabled_capability"
		),
		"DCC-U06: duplicate capability code is reported"
	)


func _test_duplicate_publishes() -> void:

	var draft := _valid_draft()

	draft.enabled_publishes.append(
		BusTopics.DISTANCE_MEASUREMENT
	)

	var result := _compile(draft)

	_expect(
		not result.is_success(),
		"DCC-U06: duplicate publish fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"duplicate_enabled_publish"
		),
		"DCC-U06: duplicate publish code is reported"
	)


func _test_duplicate_subscribes() -> void:

	var draft := _valid_draft()

	draft.enabled_subscribes = [
		BusTopics.HEALTH_REPORT,
		BusTopics.HEALTH_REPORT,
	]

	var result := _compile(draft)

	_expect(
		not result.is_success(),
		"DCC-U06: duplicate subscribe fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"duplicate_enabled_subscribe"
		),
		"DCC-U06: duplicate subscribe code is reported"
	)


func _test_duplicate_requirements() -> void:

	var draft := _valid_draft()

	draft.additional_requirements = [
		"power",
		"power",
	]

	var result := _compile(draft)

	_expect(
		not result.is_success(),
		"DCC-U06: duplicate requirement fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"duplicate_additional_requirement"
		),
		"DCC-U06: duplicate requirement code is reported"
	)


# =============================================================================
# VALID COMPILATION
# =============================================================================

func _test_valid_compilation() -> void:

	var draft := _valid_draft()

	var result := _compile(draft)

	var configuration := (
		result.get_configuration()
	)

	_expect(
		result.is_success(),
		"DCC-U07: valid Draft compiles"
	)

	_expect(
		configuration != null,
		"DCC-U07: compilation produces snapshot"
	)

	_expect(
		result.get_report()
			.is_valid_for_simulation(),
		"DCC-U07: Report is valid for simulation"
	)

	_expect(
		configuration.is_valid(),
		"DCC-U07: snapshot is valid"
	)

	_expect(
		configuration.get_configuration_id()
		== draft.configuration_id,
		"DCC-U07: configuration ID is preserved"
	)

	_expect(
		configuration.get_configuration_version()
		== draft.configuration_version,
		"DCC-U07: configuration version is preserved"
	)

	_expect(
		configuration.get_device_id()
		== draft.device_id,
		"DCC-U07: Device ID is preserved"
	)

	_expect(
		configuration.get_profile_id()
		== draft.profile_id,
		"DCC-U07: Profile ID is preserved"
	)

	_expect(
		configuration.get_profile_version()
		== draft.profile_version,
		"DCC-U07: Profile version is preserved"
	)

	_expect(
		configuration.get_activation_context()
		== DeviceConfiguration
			.ActivationContext.SIMULATION,
		"DCC-U07: context is SIMULATION"
	)

	_expect(
		configuration.get_based_on_configuration_id()
		== draft.based_on_configuration_id,
		"DCC-U07: parent ID is preserved"
	)

	_expect(
		configuration.get_based_on_configuration_version()
		== draft.based_on_configuration_version,
		"DCC-U07: parent version is preserved"
	)

	_expect(
		configuration.get_enabled_capabilities()
		== draft.enabled_capabilities,
		"DCC-U07: capabilities are preserved"
	)

	_expect(
		configuration.get_enabled_publishes()
		== draft.enabled_publishes,
		"DCC-U07: publishes are preserved"
	)

	_expect(
		configuration.get_enabled_subscribes()
		== draft.enabled_subscribes,
		"DCC-U07: subscribes are preserved"
	)

	_expect(
		configuration.get_additional_requirements()
		== draft.additional_requirements,
		"DCC-U07: requirements are preserved"
	)


# =============================================================================
# SNAPSHOT IMMUTABILITY
# =============================================================================

func _test_snapshot_immutability() -> void:

	var draft := _valid_draft()

	var result := _compile(draft)

	var configuration := (
		result.get_configuration()
	)

	var setter_names: Array[StringName] = [
		&"set_configuration_id",
		&"set_configuration_version",
		&"set_device_id",
		&"set_profile_id",
		&"set_profile_version",
		&"set_activation_context",
		&"set_enabled_capabilities",
		&"set_enabled_publishes",
		&"set_enabled_subscribes",
		&"set_additional_requirements",
	]

	for setter_name: StringName in setter_names:

		_expect(
			not configuration.has_method(
				setter_name
			),
			"DCC-U08: "
			+ String(setter_name)
			+ " does not exist"
		)

	var capabilities_copy: Array[String] = (
		configuration.get_enabled_capabilities()
	)

	capabilities_copy.clear()

	_expect(
		configuration
			.get_enabled_capabilities()
			.size() == 1,
		"DCC-U08: capabilities copy is independent"
	)

	var publishes_copy: Array[StringName] = (
		configuration.get_enabled_publishes()
	)

	publishes_copy.clear()

	_expect(
		configuration
			.get_enabled_publishes()
			.size() == 1,
		"DCC-U08: publishes copy is independent"
	)

	draft.device_id = "modified_device"

	draft.enabled_capabilities.clear()

	_expect(
		configuration.get_device_id()
		== "front_left_distance_sensor",
		"DCC-U08: Draft mutation does not change Device ID"
	)

	_expect(
		configuration
			.get_enabled_capabilities()
			.size() == 1,
		"DCC-U08: Draft mutation does not change arrays"
	)


# =============================================================================
# HELPERS
# =============================================================================

func _profile() -> DeviceProfile:

	return BuiltinDeviceProfiles.create_ideal_distance_sensor()


func _valid_draft() -> DeviceConfigurationDraft:

	var profile := _profile()

	var draft := DeviceConfigurationDraft.new()

	draft.configuration_id = (
		&"ship_a.front_left_distance"
	)

	draft.configuration_version = 1

	draft.device_id = (
		"front_left_distance_sensor"
	)

	draft.profile_id = (
		profile.get_profile_id()
	)

	draft.profile_version = (
		profile.get_profile_version()
	)

	draft.based_on_configuration_id = &""

	draft.based_on_configuration_version = 0

	draft.enabled_capabilities = [
		"distance_measurement",
	]

	draft.enabled_publishes = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	draft.enabled_subscribes = []

	draft.additional_requirements = [
		"power",
	]

	return draft


func _compile(
	draft: DeviceConfigurationDraft
) -> DeviceConfigurationCompileResult:

	return DeviceConfigurationCompiler.new().compile_for_simulation(
			draft,
			_profile()
		)


func _report_has_code(
	report: ValidationReport,
	code: StringName
) -> bool:

	for issue: ValidationIssue in (
		report.get_issues()
	):

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
