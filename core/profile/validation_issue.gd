extends RefCounted
class_name ValidationIssue


##
## ValidationIssue
##
## Resultado individual e inmutable
## de una operación de validación.
##


enum Severity {
	INFO,
	WARNING,
	SIMULATION_HAZARD,
	STRUCTURAL_ERROR,
	PLATFORM_SAFETY_ERROR,
	HARDWARE_SAFETY_ERROR
}


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _code: StringName

var _severity: Severity

var _message: String

var _related_object_id: String

var _related_field: StringName

var _suggested_action: String


# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(
	code: StringName,
	severity: Severity,
	message: String,
	related_object_id: String = "",
	related_field: StringName = &"",
	suggested_action: String = ""
) -> void:

	_code = code

	_severity = severity

	_message = message

	_related_object_id = related_object_id

	_related_field = related_field

	_suggested_action = suggested_action


# =============================================================================
# PUBLIC API
# =============================================================================

func get_code() -> StringName:

	return _code


func get_severity() -> Severity:

	return _severity


func get_message() -> String:

	return _message


func get_related_object_id() -> String:

	return _related_object_id


func get_related_field() -> StringName:

	return _related_field


func get_suggested_action() -> String:

	return _suggested_action
