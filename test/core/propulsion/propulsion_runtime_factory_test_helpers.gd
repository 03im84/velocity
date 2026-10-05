extends RefCounted


static func create_configuration(
	device_id: String,
	capabilities: Array[String] = [
		"longitudinal_propulsion_force",
	],
	publishes: Array[StringName] = [],
	subscribes: Array[StringName] = [
		BusTopics.PROPULSION_COMMAND,
	],
	activation_context: int = (
		DeviceConfiguration.ActivationContext.SIMULATION
	),
	profile_id: StringName = PropulsionRuntimeFactory.PROFILE_ID,
	profile_version: int = PropulsionRuntimeFactory.PROFILE_VERSION
) -> DeviceConfiguration:

	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName("test.propulsion.factory." + device_id),
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


static func create_factory_key(
	profile_id: StringName = PropulsionRuntimeFactory.PROFILE_ID,
	profile_version: int = PropulsionRuntimeFactory.PROFILE_VERSION,
	activation_context: int = (
		DeviceConfiguration.ActivationContext.SIMULATION
	)
) -> RuntimeFactoryKey:

	return RuntimeFactoryKey.new(
		profile_id,
		profile_version,
		activation_context
	)


static func create_binding(
	dependency_id: StringName,
	value: Object,
	ownership: int = RuntimeDependencyBinding.Ownership.BORROWED
) -> RuntimeDependencyBinding:

	return RuntimeDependencyBinding.new(
		dependency_id,
		value,
		ownership
	)


static func create_request(
	device_id: String,
	model: Object,
	force_sink: Object,
	model_ownership: int = (
		RuntimeDependencyBinding.Ownership.BORROWED
	),
	sink_ownership: int = (
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
		create_binding(
			PropulsionRuntimeFactory.MODEL_DEPENDENCY_ID,
			model,
			model_ownership
		),
		create_binding(
			PropulsionRuntimeFactory.SINK_DEPENDENCY_ID,
			force_sink,
			sink_ownership
		),
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
