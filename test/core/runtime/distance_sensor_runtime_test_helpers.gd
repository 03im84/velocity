extends RefCounted


static func create_configuration(
	device_id: String,
	include_health: bool = false
) -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"distance_measurement",
	]
	var publishes: Array[StringName] = [
		BusTopics.DISTANCE_MEASUREMENT,
	]

	if include_health:
		capabilities.append("health_reporting")
		publishes.append(BusTopics.HEALTH_REPORT)

	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName("test.distance." + device_id),
		1,
		device_id,
		DistanceSensorRuntimeFactory.PROFILE_ID,
		DistanceSensorRuntimeFactory.PROFILE_VERSION,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		publishes,
		subscribes,
		requirements
	)


static func create_binding(
	provider: Object,
	ownership: int = RuntimeDependencyBinding.Ownership.BORROWED
) -> RuntimeDependencyBinding:

	return RuntimeDependencyBinding.new(
		DistanceSensorRuntimeFactory.DEPENDENCY_ID,
		provider,
		ownership
	)


static func create_request(
	device_id: String,
	provider: Object,
	include_health: bool = false,
	ownership: int = RuntimeDependencyBinding.Ownership.BORROWED
) -> RuntimeConstructionRequest:

	var bindings: Array[RuntimeDependencyBinding] = [
		create_binding(provider, ownership),
	]

	return RuntimeConstructionRequest.new(
		device_id,
		create_configuration(device_id, include_health),
		RuntimeFactoryKey.new(
			DistanceSensorRuntimeFactory.PROFILE_ID,
			DistanceSensorRuntimeFactory.PROFILE_VERSION,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
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
