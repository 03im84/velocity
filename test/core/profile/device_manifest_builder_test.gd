extends Node


##
## DeviceManifestBuilderTest
##
## Verifica validación, referencia,
## construcción, requirements y copias.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceManifestBuilderTest")
	print("========================================")

	_test_null_profile()
	_test_null_configuration()
	_test_invalid_snapshots()
	_test_profile_reference_mismatch()
	_test_hardware_context_rejected()
	_test_valid_build()
	_test_independent_collections()

	_finish_test()


# =============================================================================
# NULL INPUTS
# =============================================================================

func _test_null_profile() -> void:

	var configuration := _configuration(
		_profile()
	)

	var result := DeviceManifestBuilder.new().build(
		null,
		configuration
	)

	_expect(
		not result.is_success(),
		"DMB-U01: null Profile fails"
	)

	_expect(
		result.get_manifest() == null,
		"DMB-U01: null Profile produces no Manifest"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"profile_missing"
		),
		"DMB-U01: missing Profile code is reported"
	)


func _test_null_configuration() -> void:

	var result := DeviceManifestBuilder.new().build(
		_profile(),
		null
	)

	_expect(
		not result.is_success(),
		"DMB-U02: null Configuration fails"
	)

	_expect(
		result.get_manifest() == null,
		"DMB-U02: null Configuration produces no Manifest"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"configuration_missing"
		),
		"DMB-U02: missing Configuration code is reported"
	)


# =============================================================================
# INVALID SNAPSHOTS
# =============================================================================

func _test_invalid_snapshots() -> void:

	var invalid_profile := DeviceProfile.new()

	var valid_configuration := _configuration(
		_profile()
	)

	var invalid_profile_result := (
		DeviceManifestBuilder.new().build(
			invalid_profile,
			valid_configuration
		)
	)

	_expect(
		not invalid_profile_result.is_success(),
		"DMB-U03: invalid Profile fails"
	)

	_expect(
		_report_has_code(
			invalid_profile_result.get_report(),
			&"profile_invalid"
		),
		"DMB-U03: invalid Profile code is reported"
	)

	var invalid_configuration := (
		DeviceConfiguration.new()
	)

	var invalid_configuration_result := (
		DeviceManifestBuilder.new().build(
			_profile(),
			invalid_configuration
		)
	)

	_expect(
		not invalid_configuration_result.is_success(),
		"DMB-U03: invalid Configuration fails"
	)

	_expect(
		_report_has_code(
			invalid_configuration_result.get_report(),
			&"configuration_invalid"
		),
		"DMB-U03: invalid Configuration code is reported"
	)


# =============================================================================
# REFERENCE MISMATCH
# =============================================================================

func _test_profile_reference_mismatch() -> void:

	var profile := _profile()

	var configuration := DeviceConfiguration.new(
		&"ship_a.sensor_config",
		1,
		"front_left_distance_sensor",
		&"velocity.other_profile",
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		[
			"distance_measurement",
		],
		[
			BusTopics.DISTANCE_MEASUREMENT,
		],
		[],
		[]
	)

	var result := DeviceManifestBuilder.new().build(
		profile,
		configuration
	)

	_expect(
		not result.is_success(),
		"DMB-U04: Profile reference mismatch fails"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"profile_reference_mismatch"
		),
		"DMB-U04: mismatch code is reported"
	)


# =============================================================================
# HARDWARE CONTEXT
# =============================================================================

func _test_hardware_context_rejected() -> void:

	var profile := _profile()

	var configuration := DeviceConfiguration.new(
		&"ship_a.sensor_hardware_config",
		1,
		"front_left_distance_sensor",
		profile.get_profile_id(),
		profile.get_profile_version(),
		DeviceConfiguration.ActivationContext.HARDWARE,
		&"",
		0,
		[
			"distance_measurement",
		],
		[
			BusTopics.DISTANCE_MEASUREMENT,
		],
		[],
		[]
	)

	var result := DeviceManifestBuilder.new().build(
		profile,
		configuration
	)

	_expect(
		not result.is_success(),
		"DMB-U05: Hardware context is rejected"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"activation_context_not_supported"
		),
		"DMB-U05: Hardware context code is reported"
	)


# =============================================================================
# VALID BUILD
# =============================================================================

func _test_valid_build() -> void:

	var profile := _profile()

	var configuration := _configuration(
		profile
	)

	var result := DeviceManifestBuilder.new().build(
		profile,
		configuration
	)

	var manifest := result.get_manifest()

	_expect(
		result.is_success(),
		"DMB-U06: valid snapshots build Manifest"
	)

	_expect(
		manifest != null,
		"DMB-U06: Manifest is created"
	)

	_expect(
		result.get_report().is_valid_for_simulation(),
		"DMB-U06: Report is valid for simulation"
	)

	_expect(
		manifest.capabilities == [
			"distance_measurement",
		],
		"DMB-U06: capabilities are copied"
	)

	_expect(
		manifest.publishes == [
			BusTopics.DISTANCE_MEASUREMENT,
		],
		"DMB-U06: publishes are copied"
	)

	_expect(
		manifest.subscribes.is_empty(),
		"DMB-U06: subscribes are copied"
	)

	_expect(
		manifest.requirements == [
			"device_bus",
			"power",
			"mounting",
		],
		"DMB-U06: requirements are merged"
	)


# =============================================================================
# COLLECTION INDEPENDENCE
# =============================================================================

func _test_independent_collections() -> void:

	var profile := _profile()

	var configuration := _configuration(
		profile
	)

	var result := DeviceManifestBuilder.new().build(
		profile,
		configuration
	)

	var manifest := result.get_manifest()

	manifest.capabilities.clear()
	manifest.publishes.clear()
	manifest.requirements.clear()

	_expect(
		configuration.get_enabled_capabilities()
		== [
			"distance_measurement",
		],
		"DMB-U07: Manifest does not modify Configuration capabilities"
	)

	_expect(
		configuration.get_enabled_publishes()
		== [
			BusTopics.DISTANCE_MEASUREMENT,
		],
		"DMB-U07: Manifest does not modify Configuration publishes"
	)

	_expect(
		profile.get_requirements() == [
			"device_bus",
			"power",
		],
		"DMB-U07: Manifest does not modify Profile requirements"
	)


# =============================================================================
# HELPERS
# =============================================================================

func _profile() -> DeviceProfile:

	return DeviceProfile.new(
		&"velocity.distance_sensor.test_manifest",
		1,
		"Test Distance Sensor",
		"Manifest builder test Profile.",
		DeviceRoles.SENSOR,
		[
			"distance_measurement",
			"health_reporting",
		],
		[
			BusTopics.DISTANCE_MEASUREMENT,
			BusTopics.HEALTH_REPORT,
		],
		[],
		[
			"device_bus",
			"power",
		],
		true,
		&"",
		0
	)


func _configuration(
	profile: DeviceProfile
) -> DeviceConfiguration:

	var draft := DeviceConfigurationDraft.new()

	draft.configuration_id = (
		&"ship_a.front_left_distance"
	)

	draft.configuration_version = 1

	draft.device_id = (
		"front_left_distance_sensor"
	)

	draft.profile_id = profile.get_profile_id()

	draft.profile_version = (
		profile.get_profile_version()
	)

	draft.enabled_capabilities = [
		"distance_measurement",
	]

	draft.enabled_publishes = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	draft.enabled_subscribes = []

	draft.additional_requirements = [
		"power",
		"mounting",
	]

	var compiler := DeviceConfigurationCompiler.new()

	var result := compiler.compile_for_simulation(
		draft,
		profile
	)

	return result.get_configuration()


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
