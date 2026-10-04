extends RefCounted


## InputRuntimeFactoryTestHelpers
##
## Construye Requests, Configurations, Bindings y
## Factory Keys válidos o intencionalmente inválidos
## para InputRuntimeFactoryTest.


static func create_configuration(
	device_id: String,
	capabilities: Array[String] = ["vehicle_control_input"],
	publishes: Array[StringName] = [BusTopics.VEHICLE_CONTROL_COMMAND],
	subscribes: Array[StringName] = [],
	activation_context: int = (
		DeviceConfiguration.ActivationContext.SIMULATION
	),
	profile_id: StringName = InputRuntimeFactory.PROFILE_ID,
	profile_version: int = InputRuntimeFactory.PROFILE_VERSION
) -> DeviceConfiguration:

	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName("test.input." + device_id),
		1,
		device_id,
		profile_id,
		profile_version,
		activation_context,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


static func create_binding(
	provider: Object,
	ownership: int = (
		RuntimeDependencyBinding.Ownership.BORROWED
	)
) -> RuntimeDependencyBinding:

	return RuntimeDependencyBinding.new(
		InputRuntimeFactory.DEPENDENCY_ID,
		provider,
		ownership
	)


static func create_factory_key(
	profile_id: StringName = InputRuntimeFactory.PROFILE_ID,
	profile_version: int = InputRuntimeFactory.PROFILE_VERSION,
	activation_context: int = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)
) -> RuntimeFactoryKey:

	return RuntimeFactoryKey.new(
		profile_id,
		profile_version,
		activation_context
	)


static func create_request(
	device_id: String,
	provider: Object,
	ownership: int = (
		RuntimeDependencyBinding.Ownership.BORROWED
	),
	factory_key: RuntimeFactoryKey = null,
	configuration: DeviceConfiguration = null
) -> RuntimeConstructionRequest:

	if factory_key == null:
		factory_key = create_factory_key()

	if configuration == null:
		configuration = create_configuration(device_id)

	var bindings: Array[RuntimeDependencyBinding] = [
		create_binding(provider, ownership),
	]

	return RuntimeConstructionRequest.new(
		device_id,
		configuration,
		factory_key,
		bindings
	)


static func report_has_code(
	report: ValidationReport,
	code: StringName
) -> bool:

	if report == null:
		return false

	for issue: ValidationIssue in report.get_issues():
		if issue.get_code() == code:
			return true

	return false
