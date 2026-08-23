extends Node


##
## SystemConnectionSpecTest
##
## Verifica identidad determinista,
## endpoints e inmutabilidad.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("SystemConnectionSpecTest")
	print("========================================")

	_test_valid_spec()
	_test_deterministic_identity()
	_test_required_fields()
	_test_self_connection()
	_test_reserved_separator()
	_test_contract()

	_finish_test()


# =============================================================================
# VALID SPEC
# =============================================================================

func _test_valid_spec() -> void:

	var spec := SystemConnectionSpec.new(
		"distance_sensor",
		&"out.distance_measurement",
		"hover_mcu",
		&"in.distance_measurement"
	)

	_expect(
		spec.is_valid_identity(),
		"SCS-U01: complete Spec has valid identity"
	)

	_expect(
		spec.get_connection_id()
		== &"distance_sensor|out.distance_measurement|hover_mcu|in.distance_measurement",
		"SCS-U01: Connection ID uses canonical format"
	)

	_expect(
		spec.get_source_device_id()
		== "distance_sensor",
		"SCS-U01: Source Device ID is preserved"
	)

	_expect(
		spec.get_source_port_id()
		== &"out.distance_measurement",
		"SCS-U01: Source Port ID is preserved"
	)

	_expect(
		spec.get_target_device_id()
		== "hover_mcu",
		"SCS-U01: Target Device ID is preserved"
	)

	_expect(
		spec.get_target_port_id()
		== &"in.distance_measurement",
		"SCS-U01: Target Port ID is preserved"
	)
	
	var spec_value: Variant = spec

	_expect(
		spec is RefCounted,
		"SCS-U01: Spec is RefCounted"
	)

	_expect(
		not (spec_value is Node),
		"SCS-U01: Spec is not Node"
	)


# =============================================================================
# DETERMINISTIC IDENTITY
# =============================================================================

func _test_deterministic_identity() -> void:

	var first := SystemConnectionSpec.new(
		"sensor_a",
		&"out.distance",
		"controller",
		&"in.distance"
	)

	var second := SystemConnectionSpec.new(
		"sensor_a",
		&"out.distance",
		"controller",
		&"in.distance"
	)

	var different_target_port := SystemConnectionSpec.new(
		"sensor_a",
		&"out.distance",
		"controller",
		&"in.distance_backup"
	)

	var different_source := SystemConnectionSpec.new(
		"sensor_b",
		&"out.distance",
		"controller",
		&"in.distance"
	)

	_expect(
		first.get_connection_id()
		== second.get_connection_id(),
		"SCS-U02: equal endpoints produce equal ID"
	)

	_expect(
		first.get_connection_id()
		!= different_target_port.get_connection_id(),
		"SCS-U02: different Target Port changes ID"
	)

	_expect(
		first.get_connection_id()
		!= different_source.get_connection_id(),
		"SCS-U02: different Source changes ID"
	)


# =============================================================================
# REQUIRED FIELDS
# =============================================================================

func _test_required_fields() -> void:

	var missing_source_device := SystemConnectionSpec.new(
		"",
		&"out.topic",
		"target",
		&"in.topic"
	)

	var missing_source_port := SystemConnectionSpec.new(
		"source",
		&"",
		"target",
		&"in.topic"
	)

	var missing_target_device := SystemConnectionSpec.new(
		"source",
		&"out.topic",
		"",
		&"in.topic"
	)

	var missing_target_port := SystemConnectionSpec.new(
		"source",
		&"out.topic",
		"target",
		&""
	)

	_expect(
		not missing_source_device.is_valid_identity(),
		"SCS-U03: missing Source Device is invalid"
	)

	_expect(
		not missing_source_port.is_valid_identity(),
		"SCS-U03: missing Source Port is invalid"
	)

	_expect(
		not missing_target_device.is_valid_identity(),
		"SCS-U03: missing Target Device is invalid"
	)

	_expect(
		not missing_target_port.is_valid_identity(),
		"SCS-U03: missing Target Port is invalid"
	)


# =============================================================================
# SELF CONNECTION
# =============================================================================

func _test_self_connection() -> void:

	var spec := SystemConnectionSpec.new(
		"same_device",
		&"out.topic",
		"same_device",
		&"in.topic"
	)

	_expect(
		not spec.is_valid_identity(),
		"SCS-U04: self-connection is invalid"
	)


# =============================================================================
# RESERVED SEPARATOR
# =============================================================================

func _test_reserved_separator() -> void:

	var source_device_separator := SystemConnectionSpec.new(
		"source|invalid",
		&"out.topic",
		"target",
		&"in.topic"
	)

	var source_port_separator := SystemConnectionSpec.new(
		"source",
		&"out|invalid",
		"target",
		&"in.topic"
	)

	var target_device_separator := SystemConnectionSpec.new(
		"source",
		&"out.topic",
		"target|invalid",
		&"in.topic"
	)

	var target_port_separator := SystemConnectionSpec.new(
		"source",
		&"out.topic",
		"target",
		&"in|invalid"
	)

	_expect(
		not source_device_separator.is_valid_identity(),
		"SCS-U05: Source Device separator is rejected"
	)

	_expect(
		not source_port_separator.is_valid_identity(),
		"SCS-U05: Source Port separator is rejected"
	)

	_expect(
		not target_device_separator.is_valid_identity(),
		"SCS-U05: Target Device separator is rejected"
	)

	_expect(
		not target_port_separator.is_valid_identity(),
		"SCS-U05: Target Port separator is rejected"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var spec := SystemConnectionSpec.new(
		"source",
		&"out.topic",
		"target",
		&"in.topic"
	)

	_expect(
		not spec.has_method(
			&"set_connection_id"
		)
		and not spec.has_method(
			&"set_source_device_id"
		)
		and not spec.has_method(
			&"set_source_port_id"
		)
		and not spec.has_method(
			&"set_target_device_id"
		)
		and not spec.has_method(
			&"set_target_port_id"
		),
		"SCS-U06: Spec exposes no setters"
	)

	_expect(
		not spec.has_method(
			&"get_topic"
		)
		and not spec.has_method(
			&"get_semantic_kind"
		),
		"SCS-U06: Spec does not duplicate Topic semantics"
	)

	_expect(
		not spec.has_method(
			&"connect_ports"
		)
		and not spec.has_method(
			&"disconnect_ports"
		)
		and not spec.has_method(
			&"execute"
		),
		"SCS-U06: Spec exposes no mutation or execution API"
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
