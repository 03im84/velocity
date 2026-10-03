extends RefCounted
class_name CompositionCompiler


##
## CompositionCompiler
##
## Compila DeviceGraphSnapshot y
## RuntimeFactoryRegistry en CompositionPlan.
##
## Version 1.0 soporta Simulation solamente.
## No ejecuta factories o runtime.
##


func compile(
	graph_snapshot: DeviceGraphSnapshot,
	factory_registry: RuntimeFactoryRegistry,
	activation_context: int,
	dispatch_policy: DeviceBusDispatchPolicy
) -> CompositionCompileResult:

	var report := ValidationReport.new()

	_validate_initial_inputs(
		graph_snapshot,
		factory_registry,
		activation_context,
		dispatch_policy,
		report
	)

	if not report.is_valid_for_simulation():

		return CompositionCompileResult.new(
			null,
			report
		)

	if (
		activation_context
		== DeviceConfiguration.ActivationContext.HARDWARE
	):

		_add_issue(
			report,
			&"composition_compile_hardware_not_supported",
			ValidationIssue.Severity.HARDWARE_SAFETY_ERROR,
			"Hardware Composition compilation is not supported.",
			"",
			&"activation_context"
		)

		return CompositionCompileResult.new(
			null,
			report
		)

	_validate_deep_inputs(
		graph_snapshot,
		factory_registry,
		dispatch_policy,
		report
	)

	if not report.is_valid_for_simulation():

		return CompositionCompileResult.new(
			null,
			report
		)

	var device_entries := _compile_device_entries(
		graph_snapshot.get_devices(),
		factory_registry,
		activation_context,
		report
	)

	if not report.is_valid_for_simulation():

		return CompositionCompileResult.new(
			null,
			report
		)

	var connection_directives := (
		_compile_connection_directives(
			graph_snapshot.get_connections(),
			device_entries,
			report
		)
	)

	if not report.is_valid_for_simulation():

		return CompositionCompileResult.new(
			null,
			report
		)

	var plan := CompositionPlan.new(
		activation_context,
		device_entries,
		connection_directives,
		dispatch_policy
	)

	if not plan.is_valid():

		_add_structural_error(
			report,
			&"composition_compile_plan_invalid",
			"Compiled CompositionPlan is invalid.",
			"",
			&"plan"
		)

		return CompositionCompileResult.new(
			null,
			report
		)

	return CompositionCompileResult.new(
		plan,
		report
	)


# =============================================================================
# INITIAL VALIDATION
# =============================================================================

func _validate_initial_inputs(
	graph_snapshot: DeviceGraphSnapshot,
	factory_registry: RuntimeFactoryRegistry,
	activation_context: int,
	dispatch_policy: DeviceBusDispatchPolicy,
	report: ValidationReport
) -> void:

	if not _activation_context_is_valid(
		activation_context
	):

		_add_structural_error(
			report,
			&"composition_compile_activation_context_invalid",
			"Activation Context is invalid.",
			"",
			&"activation_context"
		)

	if graph_snapshot == null:

		_add_structural_error(
			report,
			&"composition_compile_snapshot_missing",
			"DeviceGraphSnapshot is required.",
			"",
			&"graph_snapshot"
		)

	if factory_registry == null:

		_add_structural_error(
			report,
			&"composition_compile_registry_missing",
			"RuntimeFactoryRegistry is required.",
			"",
			&"factory_registry"
		)

	if dispatch_policy == null:

		_add_structural_error(
			report,
			&"composition_compile_dispatch_policy_missing",
			"DeviceBusDispatchPolicy is required.",
			"",
			&"dispatch_policy"
		)


func _validate_deep_inputs(
	graph_snapshot: DeviceGraphSnapshot,
	factory_registry: RuntimeFactoryRegistry,
	dispatch_policy: DeviceBusDispatchPolicy,
	report: ValidationReport
) -> void:

	if not graph_snapshot.is_valid():

		_add_structural_error(
			report,
			&"composition_compile_snapshot_invalid",
			"DeviceGraphSnapshot is invalid.",
			"",
			&"graph_snapshot"
		)

	if not factory_registry.is_valid():

		_add_structural_error(
			report,
			&"composition_compile_registry_invalid",
			"RuntimeFactoryRegistry is invalid.",
			"",
			&"factory_registry"
		)

	if not dispatch_policy.is_valid():

		_add_structural_error(
			report,
			&"composition_compile_dispatch_policy_invalid",
			"DeviceBusDispatchPolicy is invalid.",
			"",
			&"dispatch_policy"
		)


# =============================================================================
# DEVICE STAGE
# =============================================================================

func _compile_device_entries(
	nodes: Array[DeviceGraphNode],
	factory_registry: RuntimeFactoryRegistry,
	activation_context: int,
	report: ValidationReport
) -> Array[CompositionDeviceEntry]:

	var entries: Array[CompositionDeviceEntry] = []

	for node_index: int in range(
		nodes.size()
	):

		var node: DeviceGraphNode = nodes[
			node_index
		]

		if node == null:

			_add_structural_error(
				report,
				&"composition_compile_node_missing",
				"DeviceGraphNode is required.",
				str(node_index),
				&"nodes"
			)

			continue

		var device_id: String = node.get_device_id()

		if not node.is_valid():

			_add_structural_error(
				report,
				&"composition_compile_node_invalid",
				"DeviceGraphNode is invalid.",
				device_id,
				&"node"
			)

			continue

		var configuration := node.get_configuration()

		if configuration == null:

			_add_structural_error(
				report,
				&"composition_compile_configuration_missing",
				"DeviceConfiguration is required.",
				device_id,
				&"configuration"
			)

			continue

		if (
			configuration.get_activation_context()
			!= activation_context
		):

			_add_structural_error(
				report,
				&"composition_compile_configuration_context_mismatch",
				"DeviceConfiguration context does not match Compiler context.",
				device_id,
				&"activation_context"
			)

			continue

		var factory_key := RuntimeFactoryKey.new(
			configuration.get_profile_id(),
			configuration.get_profile_version(),
			activation_context
		)

		if not factory_key.is_valid():

			_add_structural_error(
				report,
				&"composition_compile_factory_key_invalid",
				"Derived RuntimeFactoryKey is invalid.",
				device_id,
				&"factory_key"
			)

			continue

		if not factory_registry.has_factory(
			factory_key
		):

			_add_structural_error(
				report,
				&"composition_compile_factory_missing",
				"Exact RuntimeFactoryDescriptor is not available.",
				device_id,
				&"factory_key"
			)

			continue

		var descriptor := factory_registry.get_descriptor(
			factory_key
		)

		if (
			descriptor == null
			or not descriptor.is_valid()
		):

			_add_structural_error(
				report,
				&"composition_compile_descriptor_invalid",
				"Resolved RuntimeFactoryDescriptor is invalid.",
				device_id,
				&"factory_descriptor"
			)

			continue

		var entry := CompositionDeviceEntry.new(
			device_id,
			configuration,
			factory_key,
			descriptor.get_dependency_specs()
		)

		if not entry.is_valid():

			_add_structural_error(
				report,
				&"composition_compile_device_entry_invalid",
				"Compiled CompositionDeviceEntry is invalid.",
				device_id,
				&"device_entry"
			)

			continue

		entries.append(
			entry
		)

	return entries


# =============================================================================
# CONNECTION STAGE
# =============================================================================

func _compile_connection_directives(
	connections: Array[DeviceGraphConnection],
	entries: Array[CompositionDeviceEntry],
	report: ValidationReport
) -> Array[CompositionConnectionDirective]:

	var directives: Array[CompositionConnectionDirective] = []
	var known_device_ids: Dictionary[String, bool] = {}

	for entry: CompositionDeviceEntry in entries:

		if entry == null:
			continue

		known_device_ids[
			entry.get_device_id()
		] = true

	for connection_index: int in range(
		connections.size()
	):

		var connection: DeviceGraphConnection = connections[
			connection_index
		]

		if connection == null:

			_add_structural_error(
				report,
				&"composition_compile_connection_missing",
				"DeviceGraphConnection is required.",
				str(connection_index),
				&"connections"
			)

			continue

		var connection_id: StringName = (
			connection.get_connection_id()
		)

		if not connection.is_valid_identity():

			_add_structural_error(
				report,
				&"composition_compile_connection_invalid",
				"DeviceGraphConnection is invalid.",
				String(connection_id),
				&"connection"
			)

			continue

		if (
			not known_device_ids.has(
				connection.get_source_device_id()
			)
			or not known_device_ids.has(
				connection.get_target_device_id()
			)
		):

			_add_structural_error(
				report,
				&"composition_compile_directive_invalid",
				"Connection endpoint has no compiled Device Entry.",
				String(connection_id),
				&"connection"
			)

			continue

		var directive := CompositionConnectionDirective.new(
			connection.get_source_device_id(),
			connection.get_source_port_id(),
			connection.get_topic(),
			connection.get_target_device_id(),
			connection.get_target_port_id()
		)

		if not directive.is_valid_identity():

			_add_structural_error(
				report,
				&"composition_compile_directive_invalid",
				"Compiled CompositionConnectionDirective is invalid.",
				String(connection_id),
				&"connection_directive"
			)

			continue

		if (
			directive.get_connection_id()
			!= connection_id
		):

			_add_structural_error(
				report,
				&"composition_compile_connection_id_mismatch",
				"Compiled Directive ID does not match Graph Connection ID.",
				String(connection_id),
				&"connection_id"
			)

			continue

		directives.append(
			directive
		)

	return directives


# =============================================================================
# HELPERS
# =============================================================================

func _activation_context_is_valid(
	context: int
) -> bool:

	return (
		context
		== DeviceConfiguration.ActivationContext.SIMULATION
		or context
		== DeviceConfiguration.ActivationContext.HARDWARE
	)


func _add_structural_error(
	report: ValidationReport,
	code: StringName,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> void:

	_add_issue(
		report,
		code,
		ValidationIssue.Severity.STRUCTURAL_ERROR,
		message,
		related_object_id,
		related_field
	)


func _add_issue(
	report: ValidationReport,
	code: StringName,
	severity: int,
	message: String,
	related_object_id: String,
	related_field: StringName
) -> void:

	report.add_issue(
		ValidationIssue.new(
			code,
			severity,
			message,
			related_object_id,
			related_field
		)
	)
