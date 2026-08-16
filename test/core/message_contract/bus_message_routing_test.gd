extends Node


##
## BusMessageRoutingTest
##
## Verifica la colaboración entre:
##
## BusTopics
## BusMessage
## DeviceBus
##
## DeviceBus permanece agnóstico respecto
## al tipo concreto del mensaje.
##


class PayloadProbe:

	extends RefCounted

	var value: int

	func _init(
		p_value: int
	) -> void:

		value = p_value


var _check_count: int = 0
var _failure_count: int = 0

var _received_messages: Array[BusMessage] = []


func _ready() -> void:

	print("")
	print("========================================")
	print("BusMessageRoutingTest")
	print("========================================")

	var bus := DeviceBus.new()

	var payload := PayloadProbe.new(42)

	var message := BusMessage.new(
		"test_publisher",
		BusTopics.TEST_MESSAGE,
		15.25,
		payload
	)

	_expect(
		bus.subscribe(
			BusTopics.TEST_MESSAGE,
			_on_message
		),
		"BM-I01: consumer is subscribed"
	)

	_expect(
		message.is_valid(),
		"BM-I01: message is valid before publication"
	)

	_expect(
		message.get_topic()
		== BusTopics.TEST_MESSAGE,
		"BM-I01: routing topic matches envelope topic"
	)

	bus.publish(
		message.get_topic(),
		message
	)

	_expect(
		_received_messages.size() == 1,
		"BM-I01: consumer receives one message"
	)

	var received_message: BusMessage = (
		_received_messages[0]
	)

	_expect(
		received_message == message,
		"BM-I01: consumer receives same message reference"
	)

	_expect(
		received_message.get_source_id()
		== "test_publisher",
		"BM-I01: source ID remains intact"
	)

	_expect(
		received_message.get_timestamp() == 15.25,
		"BM-I01: timestamp remains intact"
	)

	_expect(
		received_message.get_payload() == payload,
		"BM-I01: payload remains intact"
	)

	_finish_test()


# =============================================================================
# CONSUMER
# =============================================================================

func _on_message(
	message: BusMessage
) -> void:

	_received_messages.append(message)


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
