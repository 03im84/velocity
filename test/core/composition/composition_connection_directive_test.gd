extends Node


##
## CompositionConnectionDirectiveTest
##
## Verifica identidad determinista,
## Topic, endpoints, inmutabilidad
## y ausencia de comunicación activa.
##


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("CompositionConnectionDirectiveTest")
	print("========================================")

	_test_valid_directive()
	_test_deterministic_identity()
	_test_required_fields()
	_test_self_reference()
	_test_reserved_separator()
	_test_contract()

	_finish_test()


# =============================================================================
# VALID DIRECTIVE
# =============================================================================

func _test_valid_directive() -> void:

	var directive := CompositionConnectionDirective.new(
		"distance_sensor",
		&"out.distance_measurement",
		&"velocity.distance.measurement",
		"hover_mcu",
		&"in.distance_measurement"
	)

	var directive_value: Variant = directive

	_expect(
		directive.is_valid_identity(),
		"CCD-U01: complete Directive has valid identity"
	)

	_expect(
		directive.get_connection_id()
		== &"distance_sensor|out.distance_measurement|hover_mcu|in.distance_measurement",
		"CCD-U01: Connection ID uses canonical format"
	)

	_expect(
		directive.get_source_device_id()
		== "distance_sensor",
		"CCD-U01: Source Device ID is preserved"
	)

	_expect(
		directive.get_source_port_id()
		== &"out.distance_measurement",
		"CCD-U01: Source Port ID is preserved"
	)

	_expect(
		directive.get_topic()
		== &"velocity.distance.measurement",
		"CCD-U01: Topic is preserved"
	)

	_expect(
		directive.get_target_device_id()
		== "hover_mcu",
		"CCD-U01: Target Device ID is preserved"
	)

	_expect(
		directive.get_target_port_id()
		== &"in.distance_measurement",
		"CCD-U01: Target Port ID is preserved"
	)

	_expect(
		directive_value is RefCounted,
		"CCD-U01: Directive is RefCounted"
	)

	_expect(
		not (directive_value is Node),
		"CCD-U01: Directive is not Node"
	)


# =============================================================================
# DETERMINISTIC IDENTITY
# =============================================================================

func _test_deterministic_identity() -> void:

	var first := _directive(
		"sensor_a",
		&"out.distance",
		&"velocity.distance",
		"controller",
		&"in.distance"
	)

	var equivalent := _directive(
		"sensor_a",
		&"out.distance",
		&"velocity.distance",
		"controller",
		&"in.distance"
	)

	var different_source_device := _directive(
		"sensor_b",
		&"out.distance",
		&"velocity.distance",
		"controller",
		&"in.distance"
	)

	var different_source_port := _directive(
		"sensor_a",
		&"out.backup",
		&"velocity.distance",
		"controller",
		&"in.distance"
	)

	var different_target_device := _directive(
		"sensor_a",
		&"out.distance",
		&"velocity.distance",
		"backup_controller",
		&"in.distance"
	)

	var different_target_port := _directive(
		"sensor_a",
		&"out.distance",
		&"velocity.distance",
		"controller",
		&"in.distance_backup"
	)

	var different_topic := _directive(
		"sensor_a",
		&"out.distance",
		&"velocity.distance.filtered",
		"controller",
		&"in.distance"
	)

	_expect(
		first.get_connection_id()
		== equivalent.get_connection_id(),
		"CCD-U02: equal endpoints produce equal ID"
	)

	_expect(
		first.get_connection_id()
		!= different_source_device.get_connection_id(),
		"CCD-U02: different Source Device changes ID"
	)

	_expect(
		first.get_connection_id()
		!= different_source_port.get_connection_id(),
		"CCD-U02: different Source Port changes ID"
	)

	_expect(
		first.get_connection_id()
		!= different_target_device.get_connection_id(),
		"CCD-U02: different Target Device changes ID"
	)

	_expect(
		first.get_connection_id()
		!= different_target_port.get_connection_id(),
		"CCD-U02: different Target Port changes ID"
	)

	_expect(
		first.get_connection_id()
		== different_topic.get_connection_id()
		and first.get_topic()
		!= different_topic.get_topic(),
		"CCD-U02: Topic does not redefine endpoint identity"
	)


# =============================================================================
# REQUIRED FIELDS
# =============================================================================

func _test_required_fields() -> void:

	var missing_source_device := _directive(
		"",
		&"out.topic",
		&"velocity.topic",
		"target",
		&"in.topic"
	)

	var missing_source_port := _directive(
		"source",
		&"",
		&"velocity.topic",
		"target",
		&"in.topic"
	)

	var missing_topic := _directive(
		"source",
		&"out.topic",
		&"",
		"target",
		&"in.topic"
	)

	var missing_target_device := _directive(
		"source",
		&"out.topic",
		&"velocity.topic",
		"",
		&"in.topic"
	)

	var missing_target_port := _directive(
		"source",
		&"out.topic",
		&"velocity.topic",
		"target",
		&""
	)

	_expect(
		not missing_source_device.is_valid_identity(),
		"CCD-U03: missing Source Device is invalid"
	)

	_expect(
		not missing_source_port.is_valid_identity(),
		"CCD-U03: missing Source Port is invalid"
	)

	_expect(
		not missing_topic.is_valid_identity(),
		"CCD-U03: missing Topic is invalid"
	)

	_expect(
		not missing_target_device.is_valid_identity(),
		"CCD-U03: missing Target Device is invalid"
	)

	_expect(
		not missing_target_port.is_valid_identity(),
		"CCD-U03: missing Target Port is invalid"
	)


# =============================================================================
# SELF REFERENCE
# =============================================================================

func _test_self_reference() -> void:

	var directive := _directive(
		"same_device",
		&"out.topic",
		&"velocity.topic",
		"same_device",
		&"in.topic"
	)

	_expect(
		not directive.is_valid_identity(),
		"CCD-U04: self-reference is invalid"
	)


# =============================================================================
# RESERVED SEPARATOR
# =============================================================================

func _test_reserved_separator() -> void:

	var source_device_separator := _directive(
		"source|invalid",
		&"out.topic",
		&"velocity.topic",
		"target",
		&"in.topic"
	)

	var source_port_separator := _directive(
		"source",
		&"out|invalid",
		&"velocity.topic",
		"target",
		&"in.topic"
	)

	var target_device_separator := _directive(
		"source",
		&"out.topic",
		&"velocity.topic",
		"target|invalid",
		&"in.topic"
	)

	var target_port_separator := _directive(
		"source",
		&"out.topic",
		&"velocity.topic",
		"target",
		&"in|invalid"
	)

	_expect(
		not source_device_separator.is_valid_identity(),
		"CCD-U05: Source Device separator is rejected"
	)

	_expect(
		not source_port_separator.is_valid_identity(),
		"CCD-U05: Source Port separator is rejected"
	)

	_expect(
		not target_device_separator.is_valid_identity(),
		"CCD-U05: Target Device separator is rejected"
	)

	_expect(
		not target_port_separator.is_valid_identity(),
		"CCD-U05: Target Port separator is rejected"
	)


# =============================================================================
# CONTRACT
# =============================================================================

func _test_contract() -> void:

	var directive := _directive(
		"source",
		&"out.topic",
		&"velocity.topic",
		"target",
		&"in.topic"
	)

	_expect(
		not directive.has_method(
			&"set_connection_id"
		)
		and not directive.has_method(
			&"set_source_device_id"
		)
		and not directive.has_method(
			&"set_source_port_id"
		)
		and not directive.has_method(
			&"set_topic"
		)
		and not directive.has_method(
			&"set_target_device_id"
		)
		and not directive.has_method(
			&"set_target_port_id"
		),
		"CCD-U06: Directive exposes no setters"
	)

	_expect(
		not directive.has_method(
			&"get_callback"
		)
		and not directive.has_method(
			&"get_callable"
		)
		and not directive.has_method(
			&"get_subscriber"
		),
		"CCD-U06: Directive contains no callback or Subscriber"
	)

	_expect(
		not directive.has_method(
			&"get_device_bus"
		)
		and not directive.has_method(
			&"publish"
		)
		and not directive.has_method(
			&"subscribe"
		),
		"CCD-U06: Directive contains no active DeviceBus"
	)

	_expect(
		not directive.has_method(
			&"get_runtime_handle"
		)
		and not directive.has_method(
			&"get_factory"
		)
		and not directive.has_method(
			&"get_device"
		),
		"CCD-U06: Directive contains no active runtime resource"
	)

	_expect(
		not directive.has_method(
			&"get_graph_connection"
		)
		and not directive.has_method(
			&"set_graph_connection"
		),
		"CCD-U06: Directive does not retain DeviceGraphConnection"
	)

	_expect(
		not directive.has_method(
			&"connect_ports"
		)
		and not directive.has_method(
			&"disconnect_ports"
		)
		and not directive.has_method(
			&"execute"
		),
		"CCD-U06: Directive exposes no mutation or execution API"
	)


# =============================================================================
# FIXTURES
# =============================================================================

func _directive(
	source_device_id: String,
	source_port_id: StringName,
	topic: StringName,
	target_device_id: String,
	target_port_id: StringName
) -> CompositionConnectionDirective:

	return CompositionConnectionDirective.new(
		source_device_id,
		source_port_id,
		topic,
		target_device_id,
		target_port_id
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
