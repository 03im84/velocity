extends RefCounted


## Shared fixtures for managed runtime adapter tests.


static func create_configuration(
	device_id: String,
	profile_id: StringName = &"test.managed.runtime"
) -> DeviceConfiguration:

	var capabilities: Array[String] = [
		"managed_runtime",
	]
	var topics: Array[StringName] = []
	var requirements: Array[String] = []

	return DeviceConfiguration.new(
		StringName(
			"test.managed." + device_id
		),
		1,
		device_id,
		profile_id,
		1,
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		capabilities,
		topics,
		topics,
		requirements
	)


static func create_handle(
	device_id: String,
	primary: Object,
	host_objects: Array[Object] = [],
	profile_id: StringName = &"test.managed.runtime"
) -> RuntimeDeviceHandle:

	var bindings: Array[RuntimeDependencyBinding] = []

	return RuntimeDeviceHandle.new(
		device_id,
		create_configuration(
			device_id,
			profile_id
		),
		RuntimeFactoryKey.new(
			profile_id,
			1,
			DeviceConfiguration.ActivationContext.SIMULATION
		),
		primary,
		host_objects,
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
