extends Node


##
## DeviceManifestTopicTest
##
## Verifica la representación canónica de
## topics dentro de DeviceManifest.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceManifestTopicTest")
	print("========================================")

	_test_typed_topic_arrays()
	_test_published_topics()
	_test_subscribed_topics()
	_test_non_topic_fields()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_typed_topic_arrays() -> void:

	var manifest := DeviceManifest.new()

	_expect(
		manifest.publishes.is_typed(),
		"DM-U05: publishes is typed"
	)

	_expect(
		manifest.publishes.get_typed_builtin()
		== TYPE_STRING_NAME,
		"DM-U05: publishes contains StringName"
	)

	_expect(
		manifest.subscribes.is_typed(),
		"DM-U05: subscribes is typed"
	)

	_expect(
		manifest.subscribes.get_typed_builtin()
		== TYPE_STRING_NAME,
		"DM-U05: subscribes contains StringName"
	)


func _test_published_topics() -> void:

	var manifest := DeviceManifest.new()

	manifest.publishes.append(
		BusTopics.DISTANCE_MEASUREMENT
	)

	_expect(
		manifest.publishes_topic(
			BusTopics.DISTANCE_MEASUREMENT
		),
		"DM-U01: registered published topic is found"
	)

	_expect(
		not manifest.publishes_topic(
			BusTopics.HEALTH_REPORT
		),
		"DM-U03: unknown published topic returns false"
	)


func _test_subscribed_topics() -> void:

	var manifest := DeviceManifest.new()

	manifest.subscribes.append(
		BusTopics.HEALTH_REPORT
	)

	_expect(
		manifest.subscribes_to(
			BusTopics.HEALTH_REPORT
		),
		"DM-U02: registered subscribed topic is found"
	)

	_expect(
		not manifest.subscribes_to(
			BusTopics.PROPULSION_COMMAND
		),
		"DM-U03: unknown subscribed topic returns false"
	)


func _test_non_topic_fields() -> void:

	var manifest := DeviceManifest.new()

	manifest.capabilities.append(
		"distance_measurement"
	)

	manifest.requirements.append(
		"power"
	)

	_expect(
		manifest.has_capability(
			"distance_measurement"
		),
		"DM-U04: capabilities remain String"
	)

	_expect(
		manifest.has_requirements(
			"power"
		),
		"DM-U04: requirements remain String"
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
