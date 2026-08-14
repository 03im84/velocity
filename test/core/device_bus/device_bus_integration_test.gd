extends Node


##
## DeviceBusIntegrationTest
##
## Verifica la colaboración entre un productor
## y consumidores independientes mediante
## la API pública de DeviceBus.
##


const TEST_PRODUCER_SCRIPT := preload(
	"res://test/core/device_bus/device_bus_test_producer.gd"
)

const TEST_CONSUMER_SCRIPT := preload(
	"res://test/core/device_bus/device_bus_test_consumer.gd"
)


class IntegrationMessage:

	extends RefCounted

	var sequence: int

	func _init(
		p_sequence: int
	) -> void:

		sequence = p_sequence


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusIntegrationTest")
	print("========================================")

	var bus := DeviceBus.new()

	var producer := TEST_PRODUCER_SCRIPT.new(
		bus,
		&"integration"
	)

	var consumer_a := TEST_CONSUMER_SCRIPT.new()
	var consumer_b := TEST_CONSUMER_SCRIPT.new()

	# ---------------------------------------------------------
	# PRIMER CONSUMIDOR
	# ---------------------------------------------------------

	_expect(
		bus.subscribe(
			&"integration",
			consumer_a.receive
		),
		"DB-I01: consumer A is connected"
	)

	var message_1 := IntegrationMessage.new(1)

	producer.emit(message_1)

	_expect(
		consumer_a.get_received_count() == 1,
		"DB-I01: consumer A receives first message"
	)

	_expect(
		consumer_a.get_last_message() == message_1,
		"DB-I01: consumer A receives same message reference"
	)

	# ---------------------------------------------------------
	# SEGUNDO CONSUMIDOR
	# ---------------------------------------------------------

	_expect(
		bus.subscribe(
			&"integration",
			consumer_b.receive
		),
		"DB-I01: consumer B is added without changing producer"
	)

	var message_2 := IntegrationMessage.new(2)

	producer.emit(message_2)

	_expect(
		consumer_a.get_received_count() == 2,
		"DB-I01: consumer A receives second message"
	)

	_expect(
		consumer_b.get_received_count() == 1,
		"DB-I01: consumer B receives second message"
	)

	_expect(
		consumer_a.get_last_message() == message_2,
		"DB-I01: consumer A receives message 2 reference"
	)

	_expect(
		consumer_b.get_last_message() == message_2,
		"DB-I01: consumer B receives message 2 reference"
	)

	# ---------------------------------------------------------
	# ELIMINAR PRIMER CONSUMIDOR
	# ---------------------------------------------------------

	_expect(
		bus.unsubscribe(
			&"integration",
			consumer_a.receive
		),
		"DB-I01: consumer A is disconnected"
	)

	var message_3 := IntegrationMessage.new(3)

	producer.emit(message_3)

	_expect(
		consumer_a.get_received_count() == 2,
		"DB-I01: disconnected consumer A receives nothing"
	)

	_expect(
		consumer_b.get_received_count() == 2,
		"DB-I01: consumer B receives third message"
	)

	_expect(
		consumer_b.get_last_message() == message_3,
		"DB-I01: consumer B receives message 3 reference"
	)

	_finish_test()


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
