extends Node


const ManagedRuntimeTestUnitScript = preload(
	"res://test/core/runtime/managed_runtime_test_unit.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("RuntimeSourceFilteredSubscriptionTest")
	print("========================================")

	_test_validation_and_queries()
	_test_exact_filtering()
	_test_invalid_endpoint()

	_finish_test()


func _test_validation_and_queries() -> void:

	var receiver := ManagedRuntimeTestUnitScript.new("target")
	var endpoint: Callable = receiver.receive_message
	var subscription := RuntimeSourceFilteredSubscription.new(
		"source",
		BusTopics.TEST_MESSAGE,
		endpoint
	)

	_expect(
		subscription.is_valid(),
		"RSFS-U01: complete Subscription is valid"
	)
	_expect(
		subscription.get_source_device_id() == "source"
		and subscription.get_topic() == BusTopics.TEST_MESSAGE
		and subscription.get_target_endpoint() == endpoint,
		"RSFS-U01: Subscription preserves exact fields"
	)
	_expect(
		not RuntimeSourceFilteredSubscription.new(
			"",
			BusTopics.TEST_MESSAGE,
			endpoint
		).is_valid()
		and not RuntimeSourceFilteredSubscription.new(
			"source",
			&"",
			endpoint
		).is_valid(),
		"RSFS-U01: empty source or topic is invalid"
	)


func _test_exact_filtering() -> void:

	var receiver := ManagedRuntimeTestUnitScript.new("target")
	var subscription := RuntimeSourceFilteredSubscription.new(
		"source",
		BusTopics.TEST_MESSAGE,
		receiver.receive_message
	)

	subscription.receive("not a BusMessage")
	subscription.receive(
		BusMessage.new(
			"",
			BusTopics.TEST_MESSAGE,
			0.0,
			null
		)
	)
	subscription.receive(
		BusMessage.new(
			"other_source",
			BusTopics.TEST_MESSAGE,
			0.0,
			null
		)
	)
	subscription.receive(
		BusMessage.new(
			"source",
			BusTopics.HEALTH_REPORT,
			0.0,
			null
		)
	)

	_expect(
		receiver.get_received_messages().is_empty(),
		"RSFS-U02: non-message, invalid, wrong source and topic are ignored"
	)

	var matching_message := BusMessage.new(
		"source",
		BusTopics.TEST_MESSAGE,
		1.0,
		RefCounted.new()
	)

	subscription.receive(matching_message)

	_expect(
		receiver.get_received_messages().size() == 1,
		"RSFS-U02: exact Source and Topic are forwarded once"
	)
	_expect(
		receiver.get_received_messages()[0] == matching_message,
		"RSFS-U02: endpoint receives same BusMessage reference"
	)


func _test_invalid_endpoint() -> void:

	var subscription := RuntimeSourceFilteredSubscription.new(
		"source",
		BusTopics.TEST_MESSAGE,
		Callable()
	)

	_expect(
		not subscription.is_valid(),
		"RSFS-U03: invalid endpoint makes Subscription invalid"
	)

	subscription.receive(
		BusMessage.new(
			"source",
			BusTopics.TEST_MESSAGE,
			0.0,
			null
		)
	)

	_expect(
		true,
		"RSFS-U03: invalid endpoint receive is a safe no-op"
	)


func _expect(
	condition: bool,
	description: String
) -> void:

	_check_count += 1

	if condition:
		print("[PASS] ", description)
		return

	_failure_count += 1
	push_error("[FAIL] " + description)


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
	get_tree().quit(_failure_count)
