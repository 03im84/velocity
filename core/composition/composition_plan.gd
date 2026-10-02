extends RefCounted
class_name CompositionPlan


##
## CompositionPlan
##
## Plan runtime inmutable y no ejecutable.
##
## Describe construcción, comunicación,
## orden por fases y Dispatch Policy.
##


var _activation_context: int

var _device_entries: Array[CompositionDeviceEntry] = []

var _connection_directives: Array[CompositionConnectionDirective] = []

var _dispatch_policy: DeviceBusDispatchPolicy


func _init(
	activation_context: int,
	device_entries: Array[CompositionDeviceEntry],
	connection_directives: Array[CompositionConnectionDirective],
	dispatch_policy: DeviceBusDispatchPolicy
) -> void:

	_activation_context = activation_context

	_device_entries = device_entries.duplicate()

	_connection_directives = (
		connection_directives.duplicate()
	)

	_dispatch_policy = dispatch_policy


# =============================================================================
# PLAN API
# =============================================================================

func get_activation_context(
) -> int:

	return _activation_context


func get_device_entries(
) -> Array[CompositionDeviceEntry]:

	return _device_entries.duplicate()


func get_connection_directives(
) -> Array[CompositionConnectionDirective]:

	return _connection_directives.duplicate()


func get_dispatch_policy(
) -> DeviceBusDispatchPolicy:

	return _dispatch_policy


# =============================================================================
# LOOKUP API
# =============================================================================

func get_device_entry(
	device_id: String
) -> CompositionDeviceEntry:

	if device_id.is_empty():
		return null

	for entry: CompositionDeviceEntry in _device_entries:

		if entry == null:
			continue

		if entry.get_device_id() == device_id:
			return entry

	return null


func get_connection_directive(
	connection_id: StringName
) -> CompositionConnectionDirective:

	if connection_id == &"":
		return null

	for directive: CompositionConnectionDirective in _connection_directives:

		if directive == null:
			continue

		if (
			directive.get_connection_id()
			== connection_id
		):
			return directive

	return null


# =============================================================================
# LIFECYCLE ORDER API
# =============================================================================

func get_construction_order(
) -> Array[String]:

	return _get_forward_order()


func get_attach_order(
) -> Array[String]:

	return _get_forward_order()


func get_initialization_order(
) -> Array[String]:

	return _get_forward_order()


func get_ready_order(
) -> Array[String]:

	return _get_forward_order()


func get_start_order(
) -> Array[String]:

	return _get_forward_order()


func get_shutdown_order(
) -> Array[String]:

	return _get_reverse_order()


func get_rollback_order(
) -> Array[String]:

	return _get_reverse_order()


# =============================================================================
# VALIDATION
# =============================================================================

func is_valid(
) -> bool:

	if not _activation_context_is_valid(
		_activation_context
	):
		return false

	if _dispatch_policy == null:
		return false

	if not _dispatch_policy.is_valid():
		return false

	var known_device_ids: Dictionary[String, bool] = {}

	for entry: CompositionDeviceEntry in _device_entries:

		if entry == null:
			return false

		if not entry.is_valid():
			return false

		var device_id: String = entry.get_device_id()

		if known_device_ids.has(
			device_id
		):
			return false

		var factory_key := entry.get_factory_key()

		if factory_key == null:
			return false

		if (
			factory_key.get_activation_context()
			!= _activation_context
		):
			return false

		known_device_ids[
			device_id
		] = true

	var known_connection_ids: Dictionary[StringName, bool] = {}

	for directive: CompositionConnectionDirective in _connection_directives:

		if directive == null:
			return false

		if not directive.is_valid_identity():
			return false

		var connection_id: StringName = (
			directive.get_connection_id()
		)

		if known_connection_ids.has(
			connection_id
		):
			return false

		if not known_device_ids.has(
			directive.get_source_device_id()
		):
			return false

		if not known_device_ids.has(
			directive.get_target_device_id()
		):
			return false

		known_connection_ids[
			connection_id
		] = true

	return true


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

func _get_forward_order(
) -> Array[String]:

	var order: Array[String] = []

	for entry: CompositionDeviceEntry in _device_entries:

		if entry == null:
			continue

		order.append(
			entry.get_device_id()
		)

	return order


func _get_reverse_order(
) -> Array[String]:

	var order := _get_forward_order()

	order.reverse()

	return order


func _activation_context_is_valid(
	context: int
) -> bool:

	return (
		context
		== DeviceConfiguration.ActivationContext.SIMULATION
		or context
		== DeviceConfiguration.ActivationContext.HARDWARE
	)
