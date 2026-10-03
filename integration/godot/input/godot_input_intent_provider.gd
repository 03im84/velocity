extends RefCounted
class_name GodotInputIntentProvider


const DEFAULT_DEADZONE: float = 0.15

var _input_source: Object
var _throttle_positive: StringName
var _throttle_negative: StringName
var _steer_left: StringName
var _steer_right: StringName
var _brake: StringName
var _deadzone: float


func _init(
	input_source: Object,
	throttle_positive: StringName,
	throttle_negative: StringName,
	steer_left: StringName,
	steer_right: StringName,
	brake: StringName,
	deadzone: float = DEFAULT_DEADZONE
) -> void:

	_input_source = input_source
	_throttle_positive = throttle_positive
	_throttle_negative = throttle_negative
	_steer_left = steer_left
	_steer_right = steer_right
	_brake = brake
	_deadzone = deadzone


func is_valid() -> bool:

	return (
		_input_source != null
		and is_instance_valid(_input_source)
		and _input_source.has_method(&"get_action_strength")
		and _throttle_positive != &""
		and _throttle_negative != &""
		and _steer_left != &""
		and _steer_right != &""
		and _brake != &""
		and is_finite(_deadzone)
		and _deadzone >= 0.0
		and _deadzone < 1.0
	)


func sample_intent(
) -> VehicleControlCommand:

	if not is_valid():
		return null

	var throttle := _sample_axis(
		_throttle_positive,
		_throttle_negative
	)
	var steering := _sample_axis(
		_steer_right,
		_steer_left
	)
	var brake_value := _strength(_brake)
	var brake := _apply_deadzone(brake_value)
	var timestamp := Time.get_ticks_msec() / 1000.0

	return VehicleControlCommand.new(
		throttle,
		steering,
		clampf(brake, 0.0, 1.0),
		timestamp
	)


func get_deadzone(
) -> float:

	return _deadzone


func _sample_axis(
	positive_action: StringName,
	negative_action: StringName
) -> float:

	var raw_value := (
		_strength(positive_action)
		- _strength(negative_action)
	)

	return clampf(
		_apply_deadzone(raw_value),
		-1.0,
		1.0
	)


func _strength(
	action: StringName
) -> float:

	var value: Variant = _input_source.call(
		&"get_action_strength",
		action
	)

	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return 0.0

	var strength := float(value)

	if not is_finite(strength):
		return 0.0

	return clampf(strength, 0.0, 1.0)


func _apply_deadzone(
	value: float
) -> float:

	var magnitude := absf(value)

	if magnitude <= _deadzone:
		return 0.0

	var normalized := (
		(magnitude - _deadzone)
		/ (1.0 - _deadzone)
	)

	return signf(value) * normalized
