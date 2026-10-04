extends Node


## InputRuntimeFactoryTest
##
## Cubre el contrato exacto de InputRuntimeFactory:
## validación de Request/Key/Configuration, Binding
## BORROWED, behavior sample_intent(), forma del Handle,
## estado CREATED, sampler detached/disabled, build sin
## lifecycle, y el contrato de release (attached rechazado,
## detached exitoso, Provider preservado, idempotente).


const Factory = preload(
	"res://integration/godot/input/input_runtime_factory.gd"
)
const Helpers = preload(
	"res://test/core/input/input_runtime_factory_test_helpers.gd"
)
const ValidProvider = preload(
	"res://test/core/input/input_runtime_test_provider.gd"
)


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("InputRuntimeFactoryTest")
	print("========================================")

	_test_request_validation()
	_test_factory_key()
	_test_configuration_support()
	_test_provider_binding()
	_test_successful_build()
	_test_release_contract()

	_finish()


func _test_request_validation() -> void:

	var factory := Factory.new()

	_expect_code(
		factory.build(null).get_report(),
		&"input_runtime_factory_request_missing",
		"IRF-U01: null Request"
	)

	var bad_config := Helpers.create_configuration("mismatch_device")
	var bad_request := RuntimeConstructionRequest.new(
		"other_device",
		bad_config,
		Helpers.create_factory_key(),
		[Helpers.create_binding(ValidProvider.new())]
	)

	_expect_code(
		factory.build(bad_request).get_report(),
		&"input_runtime_factory_request_invalid",
		"IRF-U01: invalid Request (identity mismatch)"
	)


func _test_factory_key() -> void:

	var factory := Factory.new()
	var provider := ValidProvider.new()
	var key := Helpers.create_factory_key(&"velocity.input.bot")
	var config := Helpers.create_configuration(
		"key_device",
		["vehicle_control_input"],
		[BusTopics.VEHICLE_CONTROL_COMMAND],
		[],
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"velocity.input.bot",
		1
	)
	var request := RuntimeConstructionRequest.new(
		"key_device",
		config,
		key,
		[Helpers.create_binding(provider)]
	)

	_expect_code(
		factory.build(request).get_report(),
		&"input_runtime_factory_key_mismatch",
		"IRF-U02: incorrect Factory Key"
	)


func _test_configuration_support() -> void:

	var factory := Factory.new()
	var provider := ValidProvider.new()
	var config := Helpers.create_configuration(
		"cfg_device",
		["distance_measurement"],
		[BusTopics.DISTANCE_MEASUREMENT],
		[]
	)
	var request := Helpers.create_request(
		"cfg_device",
		provider,
		RuntimeDependencyBinding.Ownership.BORROWED,
		Helpers.create_factory_key(),
		config
	)

	_expect_code(
		factory.build(request).get_report(),
		&"input_runtime_factory_configuration_unsupported",
		"IRF-U03: unsupported Configuration"
	)


func _test_provider_binding() -> void:

	var factory := Factory.new()

	var no_binding_request := RuntimeConstructionRequest.new(
		"nobind_device",
		Helpers.create_configuration("nobind_device"),
		Helpers.create_factory_key(),
		[]
	)

	_expect_code(
		factory.build(no_binding_request).get_report(),
		&"input_runtime_factory_provider_missing",
		"IRF-U04: missing Provider Binding"
	)

	var invalid_provider := RefCounted.new()

	_expect_code(
		factory.build(
			Helpers.create_request("badprov_device", invalid_provider)
		).get_report(),
		&"input_runtime_factory_provider_invalid",
		"IRF-U04: invalid Provider behavior"
	)

	var transferred_request := Helpers.create_request(
		"transferred_device",
		ValidProvider.new(),
		RuntimeDependencyBinding.Ownership.TRANSFERRED
	)

	_expect_code(
		factory.build(transferred_request).get_report(),
		&"input_runtime_factory_provider_ownership_invalid",
		"IRF-U04: TRANSFERRED Provider rejected"
	)


func _test_successful_build() -> void:

	var factory := Factory.new()
	var provider := ValidProvider.new()
	var result := factory.build(
		Helpers.create_request("built_device", provider)
	)
	var handle := result.get_handle()

	_expect(
		result.is_success() and result.get_report().is_empty(),
		"IRF-U05: supported Request builds successfully"
	)
	_expect(
		handle != null
		and handle.is_valid()
		and handle.get_device_id() == "built_device",
		"IRF-U05: Factory returns valid exact Handle"
	)
	_expect(
		handle.get_primary_runtime_object() is InputRuntimeUnit,
		"IRF-U05: Primary is InputRuntimeUnit"
	)
	_expect(
		handle.get_host_objects().size() == 1
		and handle.get_host_objects()[0] is InputSamplingNode,
		"IRF-U05: Handle contains one InputSamplingNode Host Object"
	)
	_expect(
		handle.get_dependency_binding(
			Factory.DEPENDENCY_ID
		).is_borrowed(),
		"IRF-U05: Handle preserves BORROWED Provider Binding"
	)

	var unit: InputRuntimeUnit = handle.get_primary_runtime_object()
	var sampler: InputSamplingNode = unit.get_sampler()

	_expect(
		unit.get_state() == InputRuntimeUnit.State.CREATED,
		"IRF-U05: Unit is CREATED"
	)
	_expect(
		sampler.get_parent() == null
		and not sampler.is_sampling_enabled(),
		"IRF-U05: Sampler detached and disabled"
	)
	_expect(
		unit.get_state() == InputRuntimeUnit.State.CREATED
		and sampler.get_parent() == null
		and not sampler.is_sampling_enabled(),
		"IRF-U05: build does not attach or execute lifecycle"
	)
	_expect(
		unit.get_provider() == provider,
		"IRF-U05: Provider preserved by Unit"
	)

	factory.release(handle)


func _test_release_contract() -> void:

	var factory := Factory.new()
	var provider := ValidProvider.new()
	var result := factory.build(
		Helpers.create_request("release_device", provider)
	)
	var handle := result.get_handle()
	var unit: InputRuntimeUnit = handle.get_primary_runtime_object()
	var sampler: InputSamplingNode = unit.get_sampler()

	add_child(sampler)

	_expect_code(
		factory.release(handle),
		&"input_runtime_factory_release_still_attached",
		"IRF-U06: release while attached"
	)
	_expect(
		is_instance_valid(sampler),
		"IRF-U06: rejected release preserves Sampler"
	)

	remove_child(sampler)

	_expect(
		factory.release(handle).is_valid_for_simulation()
		and not is_instance_valid(sampler),
		"IRF-U06: detached release frees Sampler"
	)
	_expect(
		is_instance_valid(provider),
		"IRF-U06: release preserves BORROWED Provider"
	)
	_expect(
		factory.release(handle).is_valid_for_simulation(),
		"IRF-U06: repeated release is idempotent"
	)


func _expect_code(
	report: ValidationReport,
	code: StringName,
	description: String
) -> void:

	_expect(
		Helpers.report_has_code(report, code),
		description + " reports " + String(code)
	)


func _expect(condition: bool, description: String) -> void:

	_checks += 1
	if condition:
		print("[PASS] ", description)
		return
	_failures += 1
	push_error("[FAIL] " + description)


func _finish() -> void:

	print("----------------------------------------")
	print("Checks: ", _checks)
	print("Failures: ", _failures)
	if _failures == 0:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL")
	print("========================================")
	print("")
	get_tree().quit(_failures)
