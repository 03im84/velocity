extends Node


##
## DeviceProfileCompilerTest
##
## Verifica errores, namespace reservado,
## duplicados, snapshots y copias.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceProfileCompilerTest")
	print("========================================")

	_test_null_draft()
	_test_invalid_identity()
	_test_invalid_role()
	_test_reserved_namespace()
	_test_duplicate_lists()
	_test_valid_compilation()
	_test_snapshot_immutability()

	_finish_test()


# =============================================================================
# NULL DRAFT
# =============================================================================

func _test_null_draft() -> void:

	var compiler := DeviceProfileCompiler.new()

	var result := compiler.compile(null)

	_expect(
		not result.is_success(),
		"DPC-U01: null Draft fails"
	)

	_expect(
		result.get_profile() == null,
		"DPC-U01: null Draft produces no Profile"
	)

	_expect(
		result.get_report().has_severity(
			ValidationIssue.Severity
				.STRUCTURAL_ERROR
		),
		"DPC-U01: null Draft produces structural error"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"profile_draft_missing"
		),
		"DPC-U01: missing Draft code is reported"
	)


# =============================================================================
# INVALID IDENTITY
# =============================================================================

func _test_invalid_identity() -> void:

	var compiler := DeviceProfileCompiler.new()

	var draft := _valid_draft()

	draft.profile_id = &""

	var result := compiler.compile(draft)

	_expect(
		not result.is_success(),
		"DPC-U02: invalid identity fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"profile_id_missing"
		),
		"DPC-U02: missing ID code is reported"
	)


func _test_invalid_role() -> void:

	var compiler := DeviceProfileCompiler.new()

	var draft := _valid_draft()

	draft.primary_role = &"unknown_role"

	var result := compiler.compile(draft)

	_expect(
		not result.is_success(),
		"DPC-U03: invalid role fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"profile_role_invalid"
		),
		"DPC-U03: invalid role code is reported"
	)


# =============================================================================
# RESERVED NAMESPACE
# =============================================================================

func _test_reserved_namespace() -> void:

	var compiler := DeviceProfileCompiler.new()

	var draft := _valid_draft()

	draft.profile_id = (
		&"velocity.user_override"
	)

	var result := compiler.compile(draft)

	_expect(
		not result.is_success(),
		"DPC-U04: velocity namespace is rejected"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"reserved_profile_namespace"
		),
		"DPC-U04: reserved namespace code is reported"
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

	draft.capabilities = [
		"distance_measurement",
		"distance_measurement",
	]

	var result := (
		DeviceProfileCompiler.new().compile(
			draft
		)
	)

	_expect(
		not result.is_success(),
		"DPC-U05: duplicate capability fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"duplicate_capability"
		),
		"DPC-U05: duplicate capability code is reported"
	)


func _test_duplicate_publishes() -> void:

	var draft := _valid_draft()

	draft.supported_publishes = [
		BusTopics.DISTANCE_MEASUREMENT,
		BusTopics.DISTANCE_MEASUREMENT,
	]

	var result := (
		DeviceProfileCompiler.new().compile(
			draft
		)
	)

	_expect(
		not result.is_success(),
		"DPC-U05: duplicate publish fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"duplicate_publish_topic"
		),
		"DPC-U05: duplicate publish code is reported"
	)


func _test_duplicate_subscribes() -> void:

	var draft := _valid_draft()

	draft.supported_subscribes = [
		BusTopics.HEALTH_REPORT,
		BusTopics.HEALTH_REPORT,
	]

	var result := (
		DeviceProfileCompiler.new().compile(
			draft
		)
	)

	_expect(
		not result.is_success(),
		"DPC-U05: duplicate subscribe fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"duplicate_subscribe_topic"
		),
		"DPC-U05: duplicate subscribe code is reported"
	)


func _test_duplicate_requirements() -> void:

	var draft := _valid_draft()

	draft.requirements = [
		"device_bus",
		"device_bus",
	]

	var result := (
		DeviceProfileCompiler.new().compile(
			draft
		)
	)

	_expect(
		not result.is_success(),
		"DPC-U05: duplicate requirement fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"duplicate_requirement"
		),
		"DPC-U05: duplicate requirement code is reported"
	)


# =============================================================================
# VALID COMPILATION
# =============================================================================

func _test_valid_compilation() -> void:

	var draft := _valid_draft()

	var result := (
		DeviceProfileCompiler.new().compile(
			draft
		)
	)

	var profile := result.get_profile()

	_expect(
		result.is_success(),
		"DPC-U06: valid Draft compiles"
	)

	_expect(
		profile != null,
		"DPC-U06: compilation produces Profile"
	)

	_expect(
		result.get_report()
			.is_valid_for_simulation(),
		"DPC-U06: Report is valid for simulation"
	)

	_expect(
		profile.is_valid(),
		"DPC-U06: compiled Profile is valid"
	)

	_expect(
		profile.get_profile_id()
		== draft.profile_id,
		"DPC-U06: profile ID is preserved"
	)

	_expect(
		profile.get_profile_version()
		== draft.profile_version,
		"DPC-U06: profile version is preserved"
	)

	_expect(
		profile.get_display_name()
		== draft.display_name,
		"DPC-U06: display name is preserved"
	)

	_expect(
		profile.get_description()
		== draft.description,
		"DPC-U06: description is preserved"
	)

	_expect(
		profile.get_primary_role()
		== draft.primary_role,
		"DPC-U06: role is preserved"
	)

	_expect(
		not profile.is_canonical(),
		"DPC-U06: compiled user Profile is not canonical"
	)

	_expect(
		profile.get_based_on_profile_id()
		== draft.based_on_profile_id,
		"DPC-U06: parent ID is preserved"
	)

	_expect(
		profile.get_based_on_profile_version()
		== draft.based_on_profile_version,
		"DPC-U06: parent version is preserved"
	)

	_expect(
		profile.get_capabilities()
		== draft.capabilities,
		"DPC-U06: capabilities are preserved"
	)

	_expect(
		profile.get_supported_publishes()
		== draft.supported_publishes,
		"DPC-U06: publishes are preserved"
	)

	_expect(
		profile.get_supported_subscribes()
		== draft.supported_subscribes,
		"DPC-U06: subscribes are preserved"
	)

	_expect(
		profile.get_requirements()
		== draft.requirements,
		"DPC-U06: requirements are preserved"
	)


# =============================================================================
# SNAPSHOT IMMUTABILITY
# =============================================================================

func _test_snapshot_immutability() -> void:

	var draft := _valid_draft()

	var result := (
		DeviceProfileCompiler.new().compile(
			draft
		)
	)

	var profile := result.get_profile()

	var setter_names: Array[StringName] = [
		&"set_profile_id",
		&"set_profile_version",
		&"set_display_name",
		&"set_primary_role",
		&"set_capabilities",
		&"set_supported_publishes",
		&"set_supported_subscribes",
		&"set_requirements",
		&"set_canonical",
	]

	for setter_name: StringName in setter_names:

		_expect(
			not profile.has_method(
				setter_name
			),
			"DPC-U07: "
			+ String(setter_name)
			+ " does not exist"
		)

	var capabilities_copy: Array[String] = (
		profile.get_capabilities()
	)

	capabilities_copy.clear()

	_expect(
		profile.get_capabilities().size() == 2,
		"DPC-U07: capabilities copy is independent"
	)

	var publishes_copy: Array[StringName] = (
		profile.get_supported_publishes()
	)

	publishes_copy.clear()

	_expect(
		profile.get_supported_publishes().size()
		== 2,
		"DPC-U07: publishes copy is independent"
	)

	draft.display_name = "Modified Draft"

	draft.capabilities.clear()

	_expect(
		profile.get_display_name()
		== "Test Distance Sensor",
		"DPC-U07: Draft mutation does not change name"
	)

	_expect(
		profile.get_capabilities().size() == 2,
		"DPC-U07: Draft mutation does not change arrays"
	)


# =============================================================================
# HELPERS
# =============================================================================

func _valid_draft() -> DeviceProfileDraft:

	var draft := DeviceProfileDraft.new()

	draft.profile_id = (
		&"user.distance_sensor.test"
	)

	draft.profile_version = 1

	draft.display_name = (
		"Test Distance Sensor"
	)

	draft.description = (
		"Profile compiler test."
	)

	draft.primary_role = (
		DeviceRoles.SENSOR
	)

	draft.capabilities = [
		"distance_measurement",
		"health_reporting",
	]

	draft.supported_publishes = [
		BusTopics.DISTANCE_MEASUREMENT,
		BusTopics.HEALTH_REPORT,
	]

	draft.supported_subscribes = []

	draft.requirements = [
		"device_bus",
	]

	draft.based_on_profile_id = (
		&"user.base_distance_sensor"
	)

	draft.based_on_profile_version = 1

	return draft


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
