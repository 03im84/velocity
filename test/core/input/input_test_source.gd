extends RefCounted

var strengths: Dictionary[StringName, Variant] = {}

func get_action_strength(action: StringName) -> Variant:
	return strengths.get(action, 0.0)
