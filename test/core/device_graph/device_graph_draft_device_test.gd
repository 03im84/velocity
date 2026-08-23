extends Node


##
## DeviceGraphDraftDeviceTest
##
## Verifica add/remove Device,
## transaccionalidad, orden y Channels.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceGraphDraftDeviceTest")
	print("========================================")

	_test_add_devices()
	_test_duplicate_device()
	_test_null_device()
	_test_collection_copy()
	_test_remove_devices()
	_test_operation_result_api()

	_finish_test()


# =============================================================================
# ADD DEVICES
# =============================================================================

func _test_add_devices() -> void:

	var graph := DeviceGraphDraft.new()

	var sensor := _sensor_node()

	var sensor_result := graph.add_device(
		sensor
	)

	_expect(
		sensor_result.is_success(),
		"DGD-U01: Sensor is added"
	)

	_expect(
		sensor_result.get_affected_id()
		== &"distance_sensor",
		"DGD-U01: affected ID is Sensor ID"
	)

	_expect(
		graph.has_device(
			"distance_sensor"
		),
		"DGD-U01: Graph contains Sensor"
	)

	_expect(
		graph.get_device(
			"distance_sensor"
		) == sensor,
		"DGD-U01: get_device returns Sensor"
	)

	_expect(
		graph.get_topic_channels().size() == 2,
		"DGD-U01: Sensor creates two channels"
	)

	var controller := _controller_node()

	var controller_result := graph.add_device(
		controller
	)

	_expect(
		controller_result.is_success(),
		"DGD-U01: Controller is added"
	)

	var devices := graph.get_devices()

	_expect(
		devices.size() == 2,
		"DGD-U01: Graph contains two Devices"
	)

	_expect(
		devices[0] == sensor,
		"DGD-U01: insertion order keeps Sensor first"
	)

	_expect(
		devices[1] == controller,
		"DGD-U01: insertion order keeps Controller second"
	)

	_expect(
		graph.get_topic_channels().size() == 3,
		"DGD-U01: union contains three channels"
	)


# =============================================================================
# DUPLICATE AND NULL
# =============================================================================

func _test_duplicate_device() -> void:

	var graph := DeviceGraphDraft.new()

	graph.add_device(
		_sensor_node()
	)

	graph.add_device(
		_controller_node()
	)

	var duplicate_result := graph.add_device(
		_sensor_node()
	)

	_expect(
		not duplicate_result.is_success(),
		"DGD-U02: duplicate Device ID is rejected"
	)

	_expect(
		_report_has_code(
			duplicate_result.get_report(),
			&"duplicate_device_id"
		),
		"DGD-U02: duplicate code is reported"
	)

	_expect(
		graph.get_devices().size() == 2,
		"DGD-U02: failed add preserves Graph"
	)


func _test_null_device() -> void:

	var graph := DeviceGraphDraft.new()

	graph.add_device(
		_sensor_node()
	)

	var result := graph.add_device(null)

	_expect(
		not result.is_success(),
		"DGD-U03: null Node is rejected"
	)

	_expect(
		_report_has_code(
			result.get_report(),
			&"graph_node_missing"
		),
		"DGD-U03: missing Node code is reported"
	)

	_expect(
		graph.get_devices().size() == 1,
		"DGD-U03: null add preserves Graph"
	)


# =============================================================================
# COLLECTION COPY
# =============================================================================

func _test_collection_copy() -> void:

	var graph := DeviceGraphDraft.new()

	graph.add_device(
		_sensor_node()
	)

	graph.add_device(
		_controller_node()
	)

	var devices_copy := graph.get_devices()

	devices_copy.clear()

	_expect(
		graph.get_devices().size() == 2,
		"DGD-U04: Devices Array is independent"
	)


# =============================================================================
# REMOVE DEVICES
# =============================================================================

func _test_remove_devices() -> void:

	var graph := DeviceGraphDraft.new()

	graph.add_device(
		_sensor_node()
	)

	graph.add_device(
		_controller_node()
	)

	var missing_result := graph.remove_device(
		"unknown_device"
	)

	_expect(
		not missing_result.is_success(),
		"DGD-U05: missing Device removal fails"
	)

	_expect(
		_report_has_code(
			missing_result.get_report(),
			&"device_not_found"
		),
		"DGD-U05: missing Device code is reported"
	)

	var sensor_result := graph.remove_device(
		"distance_sensor"
	)

	_expect(
		sensor_result.is_success(),
		"DGD-U05: unconnected Sensor is removed"
	)

	_expect(
		not graph.has_device(
			"distance_sensor"
		),
		"DGD-U05: Sensor no longer exists"
	)

	_expect(
		graph.get_devices().size() == 1,
		"DGD-U05: one Device remains"
	)

	var controller_result := graph.remove_device(
		"hover_mcu"
	)

	_expect(
		controller_result.is_success(),
		"DGD-U05: Controller is removed"
	)

	_expect(
		graph.get_devices().is_empty(),
		"DGD-U05: Graph becomes empty"
	)

	_expect(
		graph.get_topic_channels().is_empty(),
		"DGD-U05: Channels are rebuilt empty"
	)


# =============================================================================
# OPERATION RESULT
# =============================================================================

func _test_operation_result_api() -> void:

	var report := ValidationReport.new()

	var result := DeviceGraphOperationResult.new(
		true,
		&"test_id",
		report
	)

	_expect(
		not result.has_method(
			&"set_success"
		),
		"DGD-U06: OperationResult has no success setter"
	)

	_expect(
		not result.has_method(
			&"set_affected_id"
		),
		"DGD-U06: OperationResult has no ID setter"
	)

	_expect(
		not result.has_method(
			&"set_report"
		),
		"DGD-U06: OperationResult has no Report setter"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _sensor_node() -> DeviceGraphNode:

	var profile := (
		BuiltinDeviceProfiles.create_ideal_distance_sensor()
	)

	var configuration := DeviceConfiguration.new(
		&"test.distance_sensor.configuration",
		1,
		"distance_sensor",
		profile.get_profile_id(),
		profile.get_profile_version(),
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		[
			"distance_measurement",
			"health_reporting",
		],
		[
			BusTopics.DISTANCE_MEASUREMENT,
			BusTopics.HEALTH_REPORT,
		],
		[],
		[]
	)

	var manifest_result := (
		DeviceManifestBuilder.new().build(
			profile,
			configuration
		)
	)

	var node_result := (
		DeviceGraphNodeBuilder.new().build(
			"distance_sensor",
			profile,
			configuration,
			manifest_result.get_manifest()
		)
	)

	return node_result.get_node()


func _controller_node() -> DeviceGraphNode:

	var profile := DeviceProfile.new(
		&"test.hover_mcu",
		1,
		"Test Hover MCU",
		"Graph Draft fixture.",
		DeviceRoles.LOCAL_CONTROLLER,
		[
			"hover_control",
		],
		[
			BusTopics.PROPULSION_COMMAND,
		],
		[
			BusTopics.DISTANCE_MEASUREMENT,
			BusTopics.HEALTH_REPORT,
		],
		[],
		false,
		&"",
		0
	)

	var configuration := DeviceConfiguration.new(
		&"test.hover_mcu.configuration",
		1,
		"hover_mcu",
		profile.get_profile_id(),
		profile.get_profile_version(),
		DeviceConfiguration.ActivationContext.SIMULATION,
		&"",
		0,
		[
			"hover_control",
		],
		[
			BusTopics.PROPULSION_COMMAND,
		],
		[
			BusTopics.DISTANCE_MEASUREMENT,
			BusTopics.HEALTH_REPORT,
		],
		[]
	)

	var manifest_result := (
		DeviceManifestBuilder.new().build(
			profile,
			configuration
		)
	)

	var node_result := (
		DeviceGraphNodeBuilder.new().build(
			"hover_mcu",
			profile,
			configuration,
			manifest_result.get_manifest()
		)
	)

	return node_result.get_node()


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
