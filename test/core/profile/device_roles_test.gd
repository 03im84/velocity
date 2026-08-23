extends Node


##
## DeviceRolesTest
##
## Verifica tipos, valores, validación
## e independencia del catálogo de roles.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("DeviceRolesTest")
	print("========================================")

	_test_role_types()
	_test_role_values()
	_test_valid_roles()
	_test_invalid_roles()
	_test_get_all()

	_finish_test()


# =============================================================================
# TESTS
# =============================================================================

func _test_role_types() -> void:

	_expect(
		typeof(DeviceRoles.SENSOR)
		== TYPE_STRING_NAME,
		"DR-U01: SENSOR is StringName"
	)

	_expect(
		typeof(DeviceRoles.ACTUATOR)
		== TYPE_STRING_NAME,
		"DR-U01: ACTUATOR is StringName"
	)

	_expect(
		typeof(DeviceRoles.LOCAL_CONTROLLER)
		== TYPE_STRING_NAME,
		"DR-U01: LOCAL_CONTROLLER is StringName"
	)

	_expect(
		typeof(
			DeviceRoles.SUPERVISORY_CONTROLLER
		) == TYPE_STRING_NAME,
		"DR-U01: SUPERVISORY_CONTROLLER is StringName"
	)


func _test_role_values() -> void:

	_expect(
		DeviceRoles.SENSOR == &"sensor",
		"DR-U02: SENSOR has canonical value"
	)

	_expect(
		DeviceRoles.ACTUATOR == &"actuator",
		"DR-U02: ACTUATOR has canonical value"
	)

	_expect(
		DeviceRoles.LOCAL_CONTROLLER
		== &"local_controller",
		"DR-U02: LOCAL_CONTROLLER has canonical value"
	)

	_expect(
		DeviceRoles.SUPERVISORY_CONTROLLER
		== &"supervisory_controller",
		"DR-U02: SUPERVISORY_CONTROLLER has canonical value"
	)


func _test_valid_roles() -> void:

	_expect(
		DeviceRoles.is_valid(
			DeviceRoles.SENSOR
		),
		"DR-U03: SENSOR is valid"
	)

	_expect(
		DeviceRoles.is_valid(
			DeviceRoles.ACTUATOR
		),
		"DR-U03: ACTUATOR is valid"
	)

	_expect(
		DeviceRoles.is_valid(
			DeviceRoles.LOCAL_CONTROLLER
		),
		"DR-U03: LOCAL_CONTROLLER is valid"
	)

	_expect(
		DeviceRoles.is_valid(
			DeviceRoles.SUPERVISORY_CONTROLLER
		),
		"DR-U03: SUPERVISORY_CONTROLLER is valid"
	)


func _test_invalid_roles() -> void:

	_expect(
		not DeviceRoles.is_valid(
			&""
		),
		"DR-U04: empty role is invalid"
	)

	_expect(
		not DeviceRoles.is_valid(
			&"unknown_role"
		),
		"DR-U04: unknown role is invalid"
	)


func _test_get_all() -> void:

	var roles: Array[StringName] = (
		DeviceRoles.get_all()
	)

	_expect(
		roles == [
			DeviceRoles.SENSOR,
			DeviceRoles.ACTUATOR,
			DeviceRoles.LOCAL_CONTROLLER,
			DeviceRoles.SUPERVISORY_CONTROLLER,
		],
		"DR-U05: get_all returns all roles"
	)

	roles.clear()

	_expect(
		DeviceRoles.get_all().size() == 4,
		"DR-U05: returned Array is independent"
	)


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
