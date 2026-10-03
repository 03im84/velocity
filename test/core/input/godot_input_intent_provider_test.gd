extends Node

const Source = preload("res://test/core/input/input_test_source.gd")

var _checks := 0
var _failures := 0

func _ready() -> void:
	_test_validation()
	_test_neutral_and_axes()
	_test_deadzone_and_clamp()
	_test_contract()
	print("Checks: ", _checks)
	print("Failures: ", _failures)
	print("RESULT: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(_failures)

func _provider(source: Object, deadzone: float = 0.15) -> GodotInputIntentProvider:
	return GodotInputIntentProvider.new(source, &"throttle_positive", &"throttle_negative", &"steer_left", &"steer_right", &"brake", deadzone)

func _test_validation() -> void:
	_expect(_provider(Source.new()).is_valid(), "GIIP-U01: complete Provider is valid")
	_expect(not _provider(null).is_valid(), "GIIP-U01: null Source is invalid")
	_expect(not _provider(RefCounted.new()).is_valid(), "GIIP-U01: Source behavior is required")
	_expect(not _provider(Source.new(), -0.1).is_valid(), "GIIP-U01: negative deadzone is invalid")
	_expect(not _provider(Source.new(), 1.0).is_valid(), "GIIP-U01: deadzone one is invalid")

func _test_neutral_and_axes() -> void:
	var source := Source.new()
	var provider := _provider(source, 0.0)
	var neutral := provider.sample_intent()
	_expect(neutral != null and neutral.is_valid(), "GIIP-U02: neutral sample is valid")
	_expect(neutral.get_throttle() == 0.0 and neutral.get_steering() == 0.0 and neutral.get_brake() == 0.0, "GIIP-U02: neutral sample contains zero intent")
	source.strengths[&"throttle_positive"] = 0.8
	source.strengths[&"throttle_negative"] = 0.2
	source.strengths[&"steer_right"] = 0.1
	source.strengths[&"steer_left"] = 0.6
	source.strengths[&"brake"] = 0.4
	var command := provider.sample_intent()
	_expect(is_equal_approx(command.get_throttle(), 0.6), "GIIP-U02: throttle combines positive and negative")
	_expect(is_equal_approx(command.get_steering(), -0.5), "GIIP-U02: steering combines right and left")
	_expect(is_equal_approx(command.get_brake(), 0.4), "GIIP-U02: brake is sampled")
	_expect(command.get_timestamp() >= 0.0, "GIIP-U02: timestamp is generated")

func _test_deadzone_and_clamp() -> void:
	var source := Source.new()
	var provider := _provider(source, 0.2)
	source.strengths[&"throttle_positive"] = 0.1
	_expect(provider.sample_intent().get_throttle() == 0.0, "GIIP-U03: value inside deadzone becomes neutral")
	source.strengths[&"throttle_positive"] = 0.6
	_expect(is_equal_approx(provider.sample_intent().get_throttle(), 0.5), "GIIP-U03: value outside deadzone is rescaled")
	source.strengths[&"throttle_positive"] = 5.0
	source.strengths[&"brake"] = 5.0
	var clamped := provider.sample_intent()
	_expect(clamped.get_throttle() == 1.0 and clamped.get_brake() == 1.0, "GIIP-U03: strengths are clamped")
	source.strengths[&"steer_right"] = NAN
	_expect(provider.sample_intent().get_steering() == 0.0, "GIIP-U03: non-finite strength fails neutral")

func _test_contract() -> void:
	var provider := _provider(Source.new())
	_expect(provider.get_deadzone() == 0.15, "GIIP-U04: configured deadzone is observable")
	_expect(not provider.has_method(&"publish") and not provider.has_method(&"get_device_bus"), "GIIP-U04: Provider has no publication or Bus API")

func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] ", description)
	else:
		_failures += 1
		push_error("[FAIL] " + description)
