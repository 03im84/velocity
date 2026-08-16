extends Node


##
## BusMessageContractTest
##
## Verifica construcción, validación,
## getters, payload y tipo de BusMessage.
##


class PayloadProbe:

	extends RefCounted

	var value: int = 42


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("BusMessageContractTest")
	print("========================================")

	_test_valid_message()
	_test_empty_source_id()
	_test_empty_topic()
	_test_null_payload()
	_test_payload_identity()
	_test_public_api()
	_test_runtime_type()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_valid_message() -> void:

	var payload := PayloadProbe.new()

	var message := BusMessage.new(
		"sensor_a",
		BusTopics.DISTANCE_MEASUREMENT,
		10.5,
		payload
	)

	_expect(
		message.is_valid(),
		"BM-U01: complete message is valid"
	)

	_expect(
		message.get_source_id() == "sensor_a",
		"BM-U01: source ID is preserved"
	)

	_expect(
		message.get_topic()
		== BusTopics.DISTANCE_MEASUREMENT,
		"BM-U01: topic is preserved"
	)

	_expect(
		message.get_timestamp() == 10.5,
		"BM-U01: timestamp is preserved"
	)

	_expect(
		message.get_payload() == payload,
		"BM-U01: payload is preserved"
	)


func _test_empty_source_id() -> void:

	var message := BusMessage.new(
		"",
		BusTopics.TEST_MESSAGE,
		0.0,
		null
	)

	_expect(
		not message.is_valid(),
		"BM-U02: empty source ID is invalid"
	)


func _test_empty_topic() -> void:

	var message := BusMessage.new(
		"sensor_a",
		&"",
		0.0,
		null
	)

	_expect(
		not message.is_valid(),
		"BM-U03: empty topic is invalid"
	)


func _test_null_payload() -> void:

	var message := BusMessage.new(
		"sensor_a",
		BusTopics.TEST_MESSAGE,
		0.0
	)

	_expect(
		message.is_valid(),
		"BM-U04: null payload is allowed"
	)

	_expect(
		message.get_payload() == null,
		"BM-U04: null payload is preserved"
	)


func _test_payload_identity() -> void:

	var payload := PayloadProbe.new()

	var message := BusMessage.new(
		"sensor_a",
		BusTopics.TEST_MESSAGE,
		1.0,
		payload
	)

	_expect(
		message.get_payload() == payload,
		"BM-U05: same payload reference is returned"
	)


func _test_public_api() -> void:

	var message := BusMessage.new(
		"sensor_a",
		BusTopics.TEST_MESSAGE,
		0.0
	)

	_expect(
		message.has_method(&"get_source_id"),
		"BM-U06: get_source_id exists"
	)

	_expect(
		message.has_method(&"get_topic"),
		"BM-U06: get_topic exists"
	)

	_expect(
		message.has_method(&"get_timestamp"),
		"BM-U06: get_timestamp exists"
	)

	_expect(
		message.has_method(&"get_payload"),
		"BM-U06: get_payload exists"
	)

	_expect(
		message.has_method(&"is_valid"),
		"BM-U06: is_valid exists"
	)

	_expect(
		not message.has_method(&"set_source_id"),
		"BM-U06: set_source_id does not exist"
	)

	_expect(
		not message.has_method(&"set_topic"),
		"BM-U06: set_topic does not exist"
	)

	_expect(
		not message.has_method(&"set_timestamp"),
		"BM-U06: set_timestamp does not exist"
	)

	_expect(
		not message.has_method(&"set_payload"),
		"BM-U06: set_payload does not exist"
	)

	_expect(
		not message.has_method(&"set_data"),
		"BM-U06: set_data does not exist"
	)

func _test_runtime_type() -> void:

	var message := BusMessage.new(
		"sensor_a",
		BusTopics.TEST_MESSAGE,
		0.0
	)

	var message_as_variant: Variant = message
	
	_expect(
		message_as_variant is RefCounted,
		"BM-U07: BusMessage is RefCounted"
	)

	_expect(
		not (message_as_variant is Resource),
		"BM-U07: BusMessage is not Resource"
	)

	_expect(
		not (message_as_variant is Node),
		"BM-U07: BusMessage is not Node"
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
