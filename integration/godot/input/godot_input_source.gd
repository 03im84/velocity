extends RefCounted
class_name GodotInputSource


func get_action_strength(
	action: StringName
) -> float:

	if action == &"":
		return 0.0

	return clampf(
		Input.get_action_strength(action),
		0.0,
		1.0
	)
