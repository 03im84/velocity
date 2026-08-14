extends Node


##
## DeviceBusRegistryTest
##
## Verifica exclusivamente el registro,
## las consultas, unsubscribe() y clear().
##
## No prueba publish().
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceBusRegistryTest")
	print("========================================")

	_test_empty_bus()
	_test_valid_subscription()
	_test_invalid_registration()
	_test_duplicate_subscription()
	_test_same_callable_in_multiple_topics()
	_test_unsubscribe()
	_test_topic_order()
	_test_clear()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_empty_bus() -> void:

	var bus := DeviceBus.new()

	_expect(
		bus.get_topics().is_empty(),
		"DB-U01: new Bus has no topics"
	)

	_expect(
		not bus.has_subscribers(&"distance"),
		"DB-U01: new Bus has no subscribers"
	)

	_expect(
		bus.get_subscriber_count(&"distance") == 0,
		"DB-U01: subscriber count starts at zero"
	)


func _test_valid_subscription() -> void:

	var bus := DeviceBus.new()

	_expect(
		bus.subscribe(
			&"distance",
			_subscriber_a
		),
		"DB-U02: valid subscription is accepted"
	)

	_expect(
		bus.has_subscribers(&"distance"),
		"DB-U02: topic reports subscribers"
	)

	_expect(
		bus.get_subscriber_count(&"distance") == 1,
		"DB-U02: subscriber count is one"
	)

	_expect(
		bus.get_topics() == [&"distance"],
		"DB-U02: topic appears in get_topics"
	)


func _test_invalid_registration() -> void:

	var bus := DeviceBus.new()

	_expect(
		not bus.subscribe(
			&"",
			_subscriber_a
		),
		"DB-U03: empty topic is rejected"
	)

	_expect(
		not bus.subscribe(
			&"distance",
			Callable()
		),
		"DB-U04: invalid Callable is rejected"
	)

	_expect(
		bus.get_topics().is_empty(),
		"DB-U03/U04: invalid data does not change registry"
	)


func _test_duplicate_subscription() -> void:

	var bus := DeviceBus.new()

	_expect(
		bus.subscribe(
			&"distance",
			_subscriber_a
		),
		"DB-U05: first subscription is accepted"
	)

	_expect(
		not bus.subscribe(
			&"distance",
			_subscriber_a
		),
		"DB-U05: duplicate subscription is rejected"
	)

	_expect(
		bus.get_subscriber_count(&"distance") == 1,
		"DB-U05: duplicate does not change count"
	)


func _test_same_callable_in_multiple_topics() -> void:

	var bus := DeviceBus.new()

	_expect(
		bus.subscribe(
			&"distance",
			_subscriber_a
		),
		"DB-U06: Callable is accepted in first topic"
	)

	_expect(
		bus.subscribe(
			&"imu",
			_subscriber_a
		),
		"DB-U06: same Callable is accepted in another topic"
	)

	_expect(
		bus.get_subscriber_count(&"distance") == 1,
		"DB-U06: first topic has independent count"
	)

	_expect(
		bus.get_subscriber_count(&"imu") == 1,
		"DB-U06: second topic has independent count"
	)


func _test_unsubscribe() -> void:

	var bus := DeviceBus.new()

	_expect(
		bus.subscribe(
			&"distance",
			_subscriber_a
		),
		"DB-U08: setup subscriber A"
	)

	_expect(
		bus.subscribe(
			&"distance",
			_subscriber_b
		),
		"DB-U08: setup subscriber B"
	)

	_expect(
		bus.unsubscribe(
			&"distance",
			_subscriber_a
		),
		"DB-U08: existing subscription is removed"
	)

	_expect(
		bus.get_subscriber_count(&"distance") == 1,
		"DB-U08: one subscriber remains"
	)

	_expect(
		not bus.unsubscribe(
			&"distance",
			_subscriber_a
		),
		"DB-U08: removing it again returns false"
	)

	_expect(
		bus.unsubscribe(
			&"distance",
			_subscriber_b
		),
		"DB-U09: last subscriber is removed"
	)

	_expect(
		not bus.has_subscribers(&"distance"),
		"DB-U09: empty topic has no subscribers"
	)

	_expect(
		bus.get_topics().is_empty(),
		"DB-U09: empty topic is erased"
	)


func _test_topic_order() -> void:

	var bus := DeviceBus.new()

	_expect(
		bus.subscribe(
			&"distance",
			_subscriber_a
		),
		"DB-U10: create distance topic"
	)

	_expect(
		bus.subscribe(
			&"imu",
			_subscriber_a
		),
		"DB-U10: create imu topic"
	)

	_expect(
		bus.subscribe(
			&"motor_command",
			_subscriber_a
		),
		"DB-U10: create motor_command topic"
	)

	_expect(
		bus.get_topics() == [
			&"distance",
			&"imu",
			&"motor_command",
		],
		"DB-U10: topics preserve creation order"
	)

	_expect(
		bus.unsubscribe(
			&"imu",
			_subscriber_a
		),
		"DB-U10: remove imu topic"
	)

	_expect(
		bus.get_topics() == [
			&"distance",
			&"motor_command",
		],
		"DB-U10: removed topic disappears"
	)

	_expect(
		bus.subscribe(
			&"imu",
			_subscriber_a
		),
		"DB-U10: recreate imu topic"
	)

	_expect(
		bus.get_topics() == [
			&"distance",
			&"motor_command",
			&"imu",
		],
		"DB-U10: recreated topic appears last"
	)


func _test_clear() -> void:

	var bus := DeviceBus.new()

	bus.subscribe(
		&"distance",
		_subscriber_a
	)

	bus.subscribe(
		&"imu",
		_subscriber_b
	)

	bus.clear()

	_expect(
		bus.get_topics().is_empty(),
		"DB-U11: clear removes all topics"
	)

	_expect(
		bus.get_subscriber_count(&"distance") == 0,
		"DB-U11: distance count returns to zero"
	)

	_expect(
		bus.get_subscriber_count(&"imu") == 0,
		"DB-U11: imu count returns to zero"
	)

	_expect(
		not bus.has_subscribers(&"distance"),
		"DB-U11: clear removes active subscriptions"
	)


# =============================================================================
# TEST SUBSCRIBERS
# =============================================================================

func _subscriber_a(
	_message: Variant
) -> void:

	pass


func _subscriber_b(
	_message: Variant
) -> void:

	pass


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
