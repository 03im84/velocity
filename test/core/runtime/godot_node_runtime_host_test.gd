extends Node


const RuntimeAdapterTestHelpersScript = preload(
	"res://test/core/runtime/runtime_adapter_test_helpers.gd"
)


var _check_count: int = 0
var _failure_count: int = 0


func _ready() -> void:

	print("")
	print("========================================")
	print("GodotNodeRuntimeHostTest")
	print("========================================")

	_test_empty_handle()
	_test_ordered_attach_and_detach()
	_test_input_validation()
	_test_non_node_and_parented_rejection()
	_test_cycle_rejection()
	_test_parent_mismatch()
	_test_contract()

	_finish_test()


func _test_empty_handle() -> void:

	var parent := _parent_node("empty_parent")
	var host := GodotNodeRuntimeHost.new(parent)
	var handle := RuntimeAdapterTestHelpersScript.create_handle(
		"empty_device",
		RefCounted.new()
	)

	_expect(
		host.attach(handle).is_valid_for_simulation()
		and host.is_handle_attached(handle)
		and host.get_attached_handle_count() == 1,
		"GNRH-U01: zero Host Objects attach as one Handle"
	)
	_expect(
		host.detach(handle).is_valid_for_simulation()
		and not host.is_handle_attached(handle)
		and host.get_attached_handle_count() == 0,
		"GNRH-U01: empty Handle detaches cleanly"
	)

	parent.queue_free()


func _test_ordered_attach_and_detach() -> void:

	var parent := _parent_node("ordered_parent")
	var node_a := Node.new()
	var node_b := Node.new()

	node_a.name = "node_a"
	node_b.name = "node_b"

	var host_objects: Array[Object] = [
		node_a,
		node_b,
	]
	var handle := RuntimeAdapterTestHelpersScript.create_handle(
		"ordered_device",
		RefCounted.new(),
		host_objects
	)
	var host := GodotNodeRuntimeHost.new(parent)
	var attach_report := host.attach(handle)

	_expect(
		attach_report.is_valid_for_simulation()
		and node_a.get_parent() == parent
		and node_b.get_parent() == parent,
		"GNRH-U02: all Nodes attach under explicit parent"
	)
	_expect(
		parent.get_child(0) == node_a
		and parent.get_child(1) == node_b,
		"GNRH-U02: attach preserves Host Object order"
	)
	_expect_code(
		host.attach(handle),
		&"godot_runtime_host_duplicate_attach",
		"GNRH-U02: duplicate attach"
	)

	var detach_report := host.detach(handle)

	_expect(
		detach_report.is_valid_for_simulation()
		and node_a.get_parent() == null
		and node_b.get_parent() == null,
		"GNRH-U02: detach removes all Nodes"
	)
	_expect(
		is_instance_valid(node_a)
		and is_instance_valid(node_b),
		"GNRH-U02: Host detach does not free Nodes"
	)
	_expect(
		host.detach(handle).is_valid_for_simulation(),
		"GNRH-U02: repeated detach is valid no-op"
	)

	node_a.free()
	node_b.free()
	parent.queue_free()


func _test_input_validation() -> void:

	var parent := _parent_node("validation_parent")
	var host := GodotNodeRuntimeHost.new(parent)

	_expect_code(
		host.attach(null),
		&"godot_runtime_host_handle_missing",
		"GNRH-U03: null Handle"
	)

	var null_parent_host := GodotNodeRuntimeHost.new(null)
	var handle := RuntimeAdapterTestHelpersScript.create_handle(
		"device_a",
		RefCounted.new()
	)

	_expect_code(
		null_parent_host.attach(handle),
		&"godot_runtime_host_parent_missing",
		"GNRH-U03: null parent"
	)

	parent.queue_free()


func _test_non_node_and_parented_rejection() -> void:

	var parent := _parent_node("rejection_parent")
	var non_node_objects: Array[Object] = [
		RefCounted.new(),
	]
	var non_node_handle := (
		RuntimeAdapterTestHelpersScript.create_handle(
			"non_node_device",
			RefCounted.new(),
			non_node_objects
		)
	)
	var host := GodotNodeRuntimeHost.new(parent)

	_expect_code(
		host.attach(non_node_handle),
		&"godot_runtime_host_object_not_node",
		"GNRH-U04: non-Node Host Object"
	)

	var other_parent := _parent_node("other_parent")
	var already_parented := Node.new()
	other_parent.add_child(already_parented)
	var parented_objects: Array[Object] = [
		already_parented,
	]
	var parented_handle := (
		RuntimeAdapterTestHelpersScript.create_handle(
			"parented_device",
			RefCounted.new(),
			parented_objects
		)
	)

	_expect_code(
		host.attach(parented_handle),
		&"godot_runtime_host_object_already_parented",
		"GNRH-U04: already parented Host Object"
	)

	other_parent.queue_free()
	parent.queue_free()


func _test_cycle_rejection() -> void:

	var ancestor := Node.new()
	var parent := Node.new()
	ancestor.add_child(parent)
	var host_objects: Array[Object] = [
		ancestor,
	]
	var handle := RuntimeAdapterTestHelpersScript.create_handle(
		"cycle_device",
		RefCounted.new(),
		host_objects
	)
	var host := GodotNodeRuntimeHost.new(parent)

	_expect_code(
		host.attach(handle),
		&"godot_runtime_host_cycle_detected",
		"GNRH-U05: SceneTree cycle"
	)

	ancestor.free()


func _test_parent_mismatch() -> void:

	var parent := _parent_node("mismatch_parent")
	var other_parent := _parent_node("mismatch_other")
	var host_node := Node.new()
	var host_objects: Array[Object] = [
		host_node,
	]
	var handle := RuntimeAdapterTestHelpersScript.create_handle(
		"mismatch_device",
		RefCounted.new(),
		host_objects
	)
	var host := GodotNodeRuntimeHost.new(parent)

	host.attach(handle)
	parent.remove_child(host_node)
	other_parent.add_child(host_node)

	_expect_code(
		host.detach(handle),
		&"godot_runtime_host_detach_parent_mismatch",
		"GNRH-U06: unexpected parent during detach"
	)
	_expect(
		host.is_handle_attached(handle),
		"GNRH-U06: unresolved detach remains observable"
	)

	other_parent.remove_child(host_node)
	host_node.free()
	parent.queue_free()
	other_parent.queue_free()


func _test_contract() -> void:

	var parent := _parent_node("contract_parent")
	var host := GodotNodeRuntimeHost.new(parent)

	_expect(
		not host.has_method(&"get_tree")
		and not host.has_method(&"get_root")
		and not host.has_method(&"free_handle"),
		"GNRH-U07: Host has no SceneTree discovery or release API"
	)

	parent.queue_free()


func _parent_node(
	node_name: String
) -> Node:

	var parent := Node.new()
	parent.name = node_name
	add_child(parent)
	return parent


func _expect_code(
	report: ValidationReport,
	code: StringName,
	description: String
) -> void:

	_expect(
		RuntimeAdapterTestHelpersScript.report_has_code(
			report,
			code
		),
		description + " reports " + String(code)
	)


func _expect(
	condition: bool,
	description: String
) -> void:

	_check_count += 1

	if condition:
		print("[PASS] ", description)
		return

	_failure_count += 1
	push_error("[FAIL] " + description)


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
	get_tree().quit(_failure_count)
