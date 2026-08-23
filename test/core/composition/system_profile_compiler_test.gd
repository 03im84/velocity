extends Node


##
## SystemProfileCompilerTest
##
## Verifica compilación Draft–Snapshot,
## resolución exacta y validación estructural.
##


const TestResolverScript = preload(
	"res://test/core/composition/system_profile_test_resolver.gd"
)


class InvalidAvailabilityResolver:

	extends RefCounted

	func has_profile(
		_profile_id: StringName,
		_profile_version: int
	) -> Variant:

		return "invalid"

	func get_profile(
		_profile_id: StringName,
		_profile_version: int
	) -> DeviceProfile:

		return null


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("SystemProfileCompilerTest")
	print("========================================")

	_test_required_inputs()
	_test_identity_validation()
	_test_empty_profile_compilation()
	_test_configuration_validation()
	_test_dependency_validation()
	_test_connection_spec_validation()
	_test_valid_compilation()
	_test_snapshot_independence()
	_test_hardware_context()
	_test_compile_result_contract()
	_test_system_profile_contract()

	_finish_test()


# =============================================================================
# REQUIRED INPUTS
# =============================================================================

func _test_required_inputs() -> void:

	var compiler := SystemProfileCompiler.new()
	var resolver := TestResolverScript.new()

	var missing_draft_result := compiler.compile(
		null,
		resolver
	)

	_expect_compile_failure(
		missing_draft_result,
		&"system_profile_draft_missing",
		"SPC-U01: null Draft"
	)

	var missing_resolver_result := compiler.compile(
		_valid_draft(),
		null
	)

	_expect_compile_failure(
		missing_resolver_result,
		&"device_profile_resolver_missing",
		"SPC-U01: null Resolver"
	)

	var incomplete_resolver := RefCounted.new()

	var incomplete_result := compiler.compile(
		_valid_draft(),
		incomplete_resolver
	)

	_expect_compile_failure(
		incomplete_result,
		&"device_profile_resolver_contract_invalid",
		"SPC-U01: incomplete Resolver"
	)


# =============================================================================
# IDENTITY VALIDATION
# =============================================================================

func _test_identity_validation() -> void:

	var compiler := SystemProfileCompiler.new()
	var resolver := TestResolverScript.new()

	var missing_id := _valid_draft()

	missing_id.system_profile_id = &""

	_expect_compile_failure(
		compiler.compile(
			missing_id,
			resolver
		),
		&"system_profile_id_missing",
		"SPC-U02: missing System Profile ID"
	)

	var invalid_version := _valid_draft()

	invalid_version.system_profile_version = 0

	_expect_compile_failure(
		compiler.compile(
			invalid_version,
			resolver
		),
		&"system_profile_version_invalid",
		"SPC-U02: invalid System Profile version"
	)

	var missing_name := _valid_draft()

	missing_name.display_name = "   "

	_expect_compile_failure(
		compiler.compile(
			missing_name,
			resolver
		),
		&"system_profile_display_name_missing",
		"SPC-U02: missing Display Name"
	)

	var invalid_context := _valid_draft()

	invalid_context.activation_context = -1

	_expect_compile_failure(
		compiler.compile(
			invalid_context,
			resolver
		),
		&"system_profile_activation_context_invalid",
		"SPC-U02: invalid Activation Context"
	)


# =============================================================================
# EMPTY PROFILE
# =============================================================================

func _test_empty_profile_compilation() -> void:

	var draft := _valid_draft()
	var resolver := TestResolverScript.new()

	var result := SystemProfileCompiler.new().compile(
		draft,
		resolver
	)

	var profile := result.get_profile()

	_expect(
		result.is_success(),
		"SPC-U03: empty Draft compiles successfully"
	)

	_expect(
		profile != null,
		"SPC-U03: empty Draft produces SystemProfile"
	)

	if profile == null:
		return

	_expect(
		result.get_report().get_issues().is_empty(),
		"SPC-U03: empty compilation has no Issues"
	)

	_expect(
		profile.is_valid_identity(),
		"SPC-U03: empty SystemProfile identity is valid"
	)

	_expect(
		profile.get_system_profile_id()
		== draft.system_profile_id,
		"SPC-U03: System Profile ID is preserved"
	)

	_expect(
		profile.get_system_profile_version()
		== draft.system_profile_version,
		"SPC-U03: System Profile version is preserved"
	)

	_expect(
		profile.get_display_name()
		== draft.display_name,
		"SPC-U03: Display Name is preserved"
	)

	_expect(
		profile.get_activation_context()
		== draft.activation_context,
		"SPC-U03: Activation Context is preserved"
	)

	_expect(
		profile.get_device_configurations().is_empty()
		and profile.get_connection_specs().is_empty(),
		"SPC-U03: empty collections are preserved"
	)


# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================

func _test_configuration_validation() -> void:

	var compiler := SystemProfileCompiler.new()

	var profile := _device_profile(
		&"test.configuration_profile"
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		profile
	)

	var null_configuration := _valid_draft()

	null_configuration.device_configurations.append(
		null
	)

	_expect_compile_failure(
		compiler.compile(
			null_configuration,
			resolver
		),
		&"system_profile_configuration_missing",
		"SPC-U04: null Configuration"
	)

	var invalid_configuration := _valid_draft()

	invalid_configuration.device_configurations.append(
		_device_configuration(
			"",
			profile,
			DeviceConfiguration.ActivationContext.SIMULATION,
			"invalid"
		)
	)

	_expect_compile_failure(
		compiler.compile(
			invalid_configuration,
			resolver
		),
		&"system_profile_configuration_invalid",
		"SPC-U04: invalid Configuration"
	)

	var duplicate_devices := _valid_draft()

	duplicate_devices.device_configurations.append(
		_device_configuration(
			"duplicate_device",
			profile,
			DeviceConfiguration.ActivationContext.SIMULATION,
			"first"
		)
	)

	duplicate_devices.device_configurations.append(
		_device_configuration(
			"duplicate_device",
			profile,
			DeviceConfiguration.ActivationContext.SIMULATION,
			"second"
		)
	)

	_expect_compile_failure(
		compiler.compile(
			duplicate_devices,
			resolver
		),
		&"duplicate_system_device_id",
		"SPC-U04: duplicate Device ID"
	)

	var context_mismatch := _valid_draft()

	context_mismatch.device_configurations.append(
		_device_configuration(
			"hardware_device",
			profile,
			DeviceConfiguration.ActivationContext.HARDWARE,
			"hardware"
		)
	)

	_expect_compile_failure(
		compiler.compile(
			context_mismatch,
			resolver
		),
		&"system_profile_activation_context_mismatch",
		"SPC-U04: Configuration context mismatch"
	)


# =============================================================================
# DEPENDENCY VALIDATION
# =============================================================================

func _test_dependency_validation() -> void:

	var compiler := SystemProfileCompiler.new()

	var required_profile := _device_profile(
		&"test.required_profile"
	)

	var missing_dependency_draft := _valid_draft()

	missing_dependency_draft.device_configurations.append(
		_device_configuration(
			"missing_dependency_device",
			required_profile,
			DeviceConfiguration.ActivationContext.SIMULATION,
			"missing"
		)
	)

	var empty_resolver := TestResolverScript.new()

	_expect_compile_failure(
		compiler.compile(
			missing_dependency_draft,
			empty_resolver
		),
		&"system_profile_dependency_missing",
		"SPC-U05: missing dependency"
	)

	var null_dependency_resolver := TestResolverScript.new()

	null_dependency_resolver.register_profile_as(
		required_profile.get_profile_id(),
		required_profile.get_profile_version(),
		null
	)

	_expect_compile_failure(
		compiler.compile(
			missing_dependency_draft,
			null_dependency_resolver
		),
		&"system_profile_dependency_invalid",
		"SPC-U05: Resolver returns null Profile"
	)

	var invalid_resolved_profile := _invalid_device_profile()
	var invalid_profile_resolver := TestResolverScript.new()

	invalid_profile_resolver.register_profile_as(
		required_profile.get_profile_id(),
		required_profile.get_profile_version(),
		invalid_resolved_profile
	)

	_expect_compile_failure(
		compiler.compile(
			missing_dependency_draft,
			invalid_profile_resolver
		),
		&"system_profile_dependency_invalid",
		"SPC-U05: Resolver returns invalid Profile"
	)

	var wrong_profile := _device_profile(
		&"test.wrong_profile"
	)

	var mismatch_resolver := TestResolverScript.new()

	mismatch_resolver.register_profile_as(
		required_profile.get_profile_id(),
		required_profile.get_profile_version(),
		wrong_profile
	)

	_expect_compile_failure(
		compiler.compile(
			missing_dependency_draft,
			mismatch_resolver
		),
		&"system_profile_dependency_identity_mismatch",
		"SPC-U05: resolved Profile identity mismatch"
	)

	var invalid_availability := InvalidAvailabilityResolver.new()

	_expect_compile_failure(
		compiler.compile(
			missing_dependency_draft,
			invalid_availability
		),
		&"system_profile_dependency_invalid",
		"SPC-U05: Resolver returns non-bool availability"
	)


# =============================================================================
# CONNECTION SPEC VALIDATION
# =============================================================================

func _test_connection_spec_validation() -> void:

	var compiler := SystemProfileCompiler.new()

	var profile := _device_profile(
		&"test.connection_profile"
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		profile
	)

	var base_draft := _valid_draft()

	base_draft.device_configurations.append(
		_device_configuration(
			"source",
			profile,
			DeviceConfiguration.ActivationContext.SIMULATION,
			"source"
		)
	)

	base_draft.device_configurations.append(
		_device_configuration(
			"target",
			profile,
			DeviceConfiguration.ActivationContext.SIMULATION,
			"target"
		)
	)

	var null_spec := _copy_draft(
		base_draft
	)

	null_spec.connection_specs.append(
		null
	)

	_expect_compile_failure(
		compiler.compile(
			null_spec,
			resolver
		),
		&"system_connection_spec_missing",
		"SPC-U06: null Connection Spec"
	)

	var invalid_spec := _copy_draft(
		base_draft
	)

	invalid_spec.connection_specs.append(
		SystemConnectionSpec.new(
			"source",
			&"out.topic",
			"source",
			&"in.topic"
		)
	)

	_expect_compile_failure(
		compiler.compile(
			invalid_spec,
			resolver
		),
		&"system_connection_spec_invalid",
		"SPC-U06: invalid Connection Spec"
	)

	var duplicate_specs := _copy_draft(
		base_draft
	)

	duplicate_specs.connection_specs.append(
		_valid_connection_spec()
	)

	duplicate_specs.connection_specs.append(
		_valid_connection_spec()
	)

	_expect_compile_failure(
		compiler.compile(
			duplicate_specs,
			resolver
		),
		&"duplicate_system_connection",
		"SPC-U06: duplicate Connection Spec"
	)

	var missing_source := _copy_draft(
		base_draft
	)

	missing_source.connection_specs.append(
		SystemConnectionSpec.new(
			"unknown_source",
			&"out.topic",
			"target",
			&"in.topic"
		)
	)

	_expect_compile_failure(
		compiler.compile(
			missing_source,
			resolver
		),
		&"system_connection_source_device_not_found",
		"SPC-U06: unknown Source Device"
	)

	var missing_target := _copy_draft(
		base_draft
	)

	missing_target.connection_specs.append(
		SystemConnectionSpec.new(
			"source",
			&"out.topic",
			"unknown_target",
			&"in.topic"
		)
	)

	_expect_compile_failure(
		compiler.compile(
			missing_target,
			resolver
		),
		&"system_connection_target_device_not_found",
		"SPC-U06: unknown Target Device"
	)


# =============================================================================
# VALID COMPILATION
# =============================================================================

func _test_valid_compilation() -> void:

	var draft := _valid_draft()

	draft.system_profile_id = &"test.valid_composition"
	draft.system_profile_version = 3
	draft.display_name = "Valid Composition"
	draft.description = "Compiler fixture."

	var resolver := TestResolverScript.new()

	_populate_valid_composition(
		draft,
		resolver
	)

	var result := SystemProfileCompiler.new().compile(
		draft,
		resolver
	)

	var profile := result.get_profile()

	_expect(
		result.is_success(),
		"SPC-U07: valid Draft compiles successfully"
	)

	_expect(
		profile != null,
		"SPC-U07: valid Draft produces SystemProfile"
	)

	if profile == null:
		return

	_expect(
		result.get_report().get_issues().is_empty(),
		"SPC-U07: valid compilation has no Issues"
	)

	_expect(
		profile.is_valid_identity(),
		"SPC-U07: compiled Profile identity is valid"
	)

	_expect(
		profile.get_system_profile_id()
		== &"test.valid_composition",
		"SPC-U07: System Profile ID is preserved"
	)

	_expect(
		profile.get_system_profile_version() == 3,
		"SPC-U07: System Profile version is preserved"
	)

	_expect(
		profile.get_display_name()
		== "Valid Composition",
		"SPC-U07: Display Name is preserved"
	)

	_expect(
		profile.get_description()
		== "Compiler fixture.",
		"SPC-U07: description is preserved"
	)

	_expect(
		profile.get_activation_context()
		== DeviceConfiguration.ActivationContext.SIMULATION,
		"SPC-U07: Activation Context is preserved"
	)

	var configurations := profile.get_device_configurations()
	var specs := profile.get_connection_specs()

	_expect(
		configurations.size() == 2,
		"SPC-U07: two Configurations are preserved"
	)

	_expect(
		specs.size() == 1,
		"SPC-U07: one Connection Spec is preserved"
	)

	_expect(
		configurations[0].get_device_id()
		== "source"
		and configurations[1].get_device_id()
		== "target",
		"SPC-U07: Configuration order is preserved"
	)

	_expect(
		profile.get_device_configuration(
			"source"
		) == configurations[0],
		"SPC-U07: Configuration lookup works"
	)

	_expect(
		profile.get_device_configuration(
			"missing"
		) == null,
		"SPC-U07: missing Configuration returns null"
	)

	_expect(
		profile.get_connection_spec(
			specs[0].get_connection_id()
		) == specs[0],
		"SPC-U07: Connection Spec lookup works"
	)

	_expect(
		profile.get_connection_spec(
			&"missing_connection"
		) == null,
		"SPC-U07: missing Connection Spec returns null"
	)


# =============================================================================
# SNAPSHOT INDEPENDENCE
# =============================================================================

func _test_snapshot_independence() -> void:

	var draft := _valid_draft()
	var resolver := TestResolverScript.new()

	_populate_valid_composition(
		draft,
		resolver
	)

	var result := SystemProfileCompiler.new().compile(
		draft,
		resolver
	)

	var profile := result.get_profile()

	_expect(
		result.is_success()
		and profile != null,
		"SPC-U08: independence fixture compiles"
	)

	if profile == null:
		return

	var first_configuration := (
		profile.get_device_configurations()[0]
	)

	var first_spec := (
		profile.get_connection_specs()[0]
	)

	draft.system_profile_id = &"test.changed"
	draft.display_name = "Changed"
	draft.device_configurations.clear()
	draft.connection_specs.clear()

	_expect(
		profile.get_system_profile_id()
		== &"test.system_profile",
		"SPC-U08: Draft ID mutation does not affect Snapshot"
	)

	_expect(
		profile.get_display_name()
		== "Test System Profile",
		"SPC-U08: Draft name mutation does not affect Snapshot"
	)

	_expect(
		profile.get_device_configurations().size()
		== 2
		and profile.get_connection_specs().size()
		== 1,
		"SPC-U08: Draft collection mutation does not affect Snapshot"
	)

	var configurations_copy := (
		profile.get_device_configurations()
	)

	var specs_copy := (
		profile.get_connection_specs()
	)

	configurations_copy.clear()
	specs_copy.clear()

	_expect(
		profile.get_device_configurations().size()
		== 2
		and profile.get_connection_specs().size()
		== 1,
		"SPC-U08: Snapshot getters return independent Arrays"
	)

	_expect(
		profile.get_device_configurations()[0]
		== first_configuration
		and profile.get_connection_specs()[0]
		== first_spec,
		"SPC-U08: Snapshot preserves immutable references"
	)


# =============================================================================
# HARDWARE CONTEXT
# =============================================================================

func _test_hardware_context() -> void:

	var draft := _valid_draft()

	draft.activation_context = (
		DeviceConfiguration.ActivationContext.HARDWARE
	)

	var profile := _device_profile(
		&"test.hardware_profile"
	)

	var resolver := TestResolverScript.new()

	resolver.register_profile(
		profile
	)

	draft.device_configurations.append(
		_device_configuration(
			"hardware_device",
			profile,
			DeviceConfiguration.ActivationContext.HARDWARE,
			"hardware"
		)
	)

	var result := SystemProfileCompiler.new().compile(
		draft,
		resolver
	)

	_expect(
		result.is_success(),
		"SPC-U09: valid Hardware definition compiles"
	)

	_expect(
		result.get_profile() != null
		and result.get_profile().get_activation_context()
		== DeviceConfiguration.ActivationContext.HARDWARE,
		"SPC-U09: Hardware context is preserved"
	)

	_expect(
		result.get_report().is_valid_for_hardware(),
		"SPC-U09: Hardware compilation Report is valid"
	)


# =============================================================================
# RESULT CONTRACT
# =============================================================================

func _test_compile_result_contract() -> void:

	var valid_report := ValidationReport.new()
	var valid_profile := _empty_system_profile()

	var null_profile_result := SystemProfileCompileResult.new(
		null,
		valid_report
	)

	_expect(
		not null_profile_result.is_success(),
		"SPC-U10: null Profile produces failed Result"
	)

	var null_report_result := SystemProfileCompileResult.new(
		valid_profile,
		null
	)

	_expect(
		not null_report_result.is_success(),
		"SPC-U10: null Report produces failed Result"
	)

	var invalid_profile := _invalid_system_profile()

	var invalid_profile_result := SystemProfileCompileResult.new(
		invalid_profile,
		valid_report
	)

	_expect(
		not invalid_profile_result.is_success(),
		"SPC-U10: invalid Profile identity produces failure"
	)

	var valid_result := SystemProfileCompileResult.new(
		valid_profile,
		valid_report
	)

	_expect(
		valid_result.is_success(),
		"SPC-U10: valid Profile and Report produce success"
	)

	_expect(
		valid_result.get_profile() == valid_profile
		and valid_result.get_report() == valid_report,
		"SPC-U10: Result preserves Profile and Report"
	)

	_expect(
		not valid_result.has_method(
			&"set_profile"
		)
		and not valid_result.has_method(
			&"set_report"
		),
		"SPC-U10: Result exposes no setters"
	)


# =============================================================================
# SYSTEM PROFILE CONTRACT
# =============================================================================

func _test_system_profile_contract() -> void:

	var profile := _empty_system_profile()
	var profile_value: Variant = profile

	_expect(
		profile_value is RefCounted,
		"SPC-U11: SystemProfile is RefCounted"
	)

	_expect(
		not (profile_value is Node),
		"SPC-U11: SystemProfile is not Node"
	)

	_expect(
		not profile.has_method(
			&"set_system_profile_id"
		)
		and not profile.has_method(
			&"set_device_configurations"
		)
		and not profile.has_method(
			&"set_connection_specs"
		),
		"SPC-U11: SystemProfile exposes no setters"
	)

	_expect(
		not profile.has_method(
			&"execute"
		)
		and not profile.has_method(
			&"activate"
		)
		and not profile.has_method(
			&"publish"
		),
		"SPC-U11: SystemProfile is not executable"
	)

	_expect(
		not profile.has_method(
			&"save"
		)
		and not profile.has_method(
			&"load"
		)
		and not profile.has_method(
			&"create_snapshot"
		),
		"SPC-U11: SystemProfile has no persistence or Graph API"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _valid_draft() -> SystemProfileDraft:

	var draft := SystemProfileDraft.new()

	draft.system_profile_id = &"test.system_profile"
	draft.system_profile_version = 1
	draft.display_name = "Test System Profile"
	draft.description = "SystemProfileCompiler fixture."
	draft.activation_context = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)

	return draft


func _copy_draft(
	source: SystemProfileDraft
) -> SystemProfileDraft:

	var copy := SystemProfileDraft.new()

	copy.system_profile_id = source.system_profile_id
	copy.system_profile_version = source.system_profile_version
	copy.display_name = source.display_name
	copy.description = source.description
	copy.activation_context = source.activation_context

	copy.device_configurations = (
		source.device_configurations.duplicate()
	)

	copy.connection_specs = (
		source.connection_specs.duplicate()
	)

	return copy


func _populate_valid_composition(
	draft: SystemProfileDraft,
	resolver: Object
) -> void:

	var source_profile := _device_profile(
		&"test.source_profile"
	)

	var target_profile := _device_profile(
		&"test.target_profile"
	)

	resolver.call(
		&"register_profile",
		source_profile
	)

	resolver.call(
		&"register_profile",
		target_profile
	)

	draft.device_configurations.append(
		_device_configuration(
			"source",
			source_profile,
			draft.activation_context,
			"source"
		)
	)

	draft.device_configurations.append(
		_device_configuration(
			"target",
			target_profile,
			draft.activation_context,
			"target"
		)
	)

	draft.connection_specs.append(
		_valid_connection_spec()
	)


func _valid_connection_spec() -> SystemConnectionSpec:

	return SystemConnectionSpec.new(
		"source",
		&"out.topic",
		"target",
		&"in.topic"
	)


func _device_profile(
	profile_id: StringName,
	profile_version: int = 1
) -> DeviceProfile:

	var capabilities: Array[String] = [
		"system_composition",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceProfile.new(
		profile_id,
		profile_version,
		"Composition Profile",
		"SystemProfileCompiler fixture.",
		DeviceRoles.LOCAL_CONTROLLER,
		capabilities,
		publishes,
		subscribes,
		requirements,
		false,
		&"",
		0
	)


func _invalid_device_profile() -> DeviceProfile:

	var capabilities: Array[String] = [
		"system_composition",
	]

	var publishes: Array[StringName] = []
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceProfile.new(
		&"",
		1,
		"Invalid Profile",
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


func _device_configuration(
	device_id: String,
	profile: DeviceProfile,
	activation_context: int,
	suffix: String
) -> DeviceConfiguration:

	var configuration_id := StringName(
		"test."
		+ suffix
		+ ".configuration"
	)

	var capabilities: Array[String] = [
		"system_composition",
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
		activation_context,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


func _empty_system_profile() -> SystemProfile:

	var configurations: Array[DeviceConfiguration] = []
	var specs: Array[SystemConnectionSpec] = []

	return SystemProfile.new(
		&"test.empty_system",
		1,
		"Empty System",
		"",
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		specs
	)


func _invalid_system_profile() -> SystemProfile:

	var configurations: Array[DeviceConfiguration] = []
	var specs: Array[SystemConnectionSpec] = []

	return SystemProfile.new(
		&"",
		1,
		"Invalid System",
		"",
		DeviceConfiguration.ActivationContext.SIMULATION,
		configurations,
		specs
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
	result: SystemProfileCompileResult,
	code: StringName,
	description: String
) -> void:

	_expect(
		not result.is_success(),
		description + " is rejected"
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
