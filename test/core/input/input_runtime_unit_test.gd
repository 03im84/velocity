extends Node

const Provider = preload("res://test/core/input/input_runtime_test_provider.gd")

var _checks := 0
var _failures := 0
var _messages: Array[BusMessage] = []

func _ready() -> void:
	_test_validation()
	_test_lifecycle_and_publication()
	_test_state_and_shutdown()
	_finish()

func _configuration(device_id: String) -> DeviceConfiguration:
	var capabilities: Array[String] = ["vehicle_control_input"]
	var publishes: Array[StringName] = [BusTopics.VEHICLE_CONTROL_COMMAND]
	var subscribes: Array[StringName] = []
	var requirements: Array[String] = []
	return DeviceConfiguration.new(&"test.input.runtime", 1, device_id, &"velocity.input.player", 1, DeviceConfiguration.ActivationContext.SIMULATION, &"", 0, capabilities, publishes, subscribes, requirements)

func _sampler() -> InputSamplingNode:
	var sampler := InputSamplingNode.new()
	add_child(sampler)
	return sampler

func _unit(device_id: String = "player_input") -> InputRuntimeUnit:
	return InputRuntimeUnit.new(device_id, _configuration(device_id), Provider.new(), _sampler())

func _test_validation() -> void:
	var unit := _unit()
	_expect(unit.is_valid(), "IRU-U01: complete Unit is valid")
	_expect(unit.get_state() == InputRuntimeUnit.State.CREATED, "IRU-U01: initial State is CREATED")
	_expect(unit.get_sampler() != null and unit.get_provider() != null, "IRU-U01: Provider and Sampler preserved")
	var invalid := InputRuntimeUnit.new("", _configuration("player_input"), Provider.new(), _sampler())
	_expect(not invalid.is_valid(), "IRU-U01: mismatched identity is invalid")

func _test_lifecycle_and_publication() -> void:
	var provider := Provider.new()
	provider.command = VehicleControlCommand.new(0.8, -0.4, 0.2, 1.0)
	var sampler := _sampler()
	var unit := InputRuntimeUnit.new("player_input", _configuration("player_input"), provider, sampler)
	var bus := DeviceBus.new()
	bus.subscribe(BusTopics.VEHICLE_CONTROL_COMMAND, _on_message)
	_expect(unit.runtime_initialize(bus).is_valid_for_simulation(), "IRU-U02: initialize succeeds")
	_expect(unit.get_state() == InputRuntimeUnit.State.INITIALIZED and not sampler.is_sampling_enabled(), "IRU-U02: initialize stores Bus without sampling")
	_expect(unit.runtime_set_ready().is_valid_for_simulation(), "IRU-U02: ready succeeds")
	_expect(unit.runtime_start().is_valid_for_simulation() and sampler.is_sampling_enabled(), "IRU-U02: start enables sampling")
	unit.sample_and_publish(42.0)
	_expect(_messages.size() == 1, "IRU-U02: RUNNING Unit publishes once")
	if not _messages.is_empty():
		var message := _messages[0]
		var command: VehicleControlCommand
		if message.get_payload() is VehicleControlCommand:
			command = message.get_payload()
		_expect(message.get_source_id() == "player_input" and message.get_topic() == BusTopics.VEHICLE_CONTROL_COMMAND, "IRU-U02: message preserves Source and Topic")
		_expect(message.get_timestamp() == 42.0 and command != null and command.get_timestamp() == 42.0, "IRU-U02: sampling timestamp is authoritative")
		_expect(command != null and command.get_throttle() == 0.8 and command.get_steering() == -0.4 and command.get_brake() == 0.2, "IRU-U02: command values are preserved")
	unit.runtime_shutdown()

func _test_state_and_shutdown() -> void:
	var provider := Provider.new()
	var unit := InputRuntimeUnit.new("state_input", _configuration("state_input"), provider, _sampler())
	unit.sample_and_publish(1.0)
	_expect(_messages.size() == 1, "IRU-U03: pre-RUNNING publication is ignored")
	_expect(not unit.runtime_start().is_valid_for_simulation(), "IRU-U03: invalid transition reports failure")
	_expect(unit.runtime_shutdown().is_valid_for_simulation() and unit.get_state() == InputRuntimeUnit.State.SHUTDOWN, "IRU-U03: shutdown from CREATED is safe")
	_expect(unit.runtime_shutdown().is_valid_for_simulation(), "IRU-U03: repeated shutdown is idempotent")
	_expect(is_instance_valid(provider), "IRU-U03: BORROWED Provider remains alive")
	_expect(not unit.get_runtime_input_endpoint(&"any").is_valid(), "IRU-U03: source-only Unit exposes no endpoint")

func _on_message(message: BusMessage) -> void:
	_messages.append(message)

func _expect(value: bool, text: String) -> void:
	_checks += 1
	if value: print("[PASS] ", text)
	else:
		_failures += 1
		push_error("[FAIL] " + text)

func _finish() -> void:
	_messages.clear()
	print("Checks: ", _checks)
	print("Failures: ", _failures)
	print("RESULT: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(_failures)
