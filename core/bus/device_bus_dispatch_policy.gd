extends RefCounted
class_name DeviceBusDispatchPolicy


##
## DeviceBusDispatchPolicy
##
## Define los presupuestos permitidos para
## un Dispatch Cycle de DeviceBus.
##
## No ejecuta dispatch.
## No conoce Devices ni mensajes concretos.
##


# =============================================================================
# DEFAULT VALUES
# =============================================================================

const DEFAULT_MAX_PUBLICATIONS_PER_CYCLE: int = 1024

const DEFAULT_MAX_CALLBACKS_PER_CYCLE: int = 8192

const DEFAULT_MAX_PENDING_PUBLICATIONS: int = 512

const DEFAULT_MAX_DISPATCH_TIME_USEC: int = 50000


# =============================================================================
# HARD MAXIMUMS
# =============================================================================

const HARD_MAX_PUBLICATIONS_PER_CYCLE: int = 16384

const HARD_MAX_CALLBACKS_PER_CYCLE: int = 131072

const HARD_MAX_PENDING_PUBLICATIONS: int = 8192

const HARD_MAX_DISPATCH_TIME_USEC: int = 500000


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _max_publications_per_cycle: int

var _max_callbacks_per_cycle: int

var _max_pending_publications: int

var _max_dispatch_time_usec: int


# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(
	max_publications_per_cycle: int
		= DEFAULT_MAX_PUBLICATIONS_PER_CYCLE,
	max_callbacks_per_cycle: int
		= DEFAULT_MAX_CALLBACKS_PER_CYCLE,
	max_pending_publications: int
		= DEFAULT_MAX_PENDING_PUBLICATIONS,
	max_dispatch_time_usec: int
		= DEFAULT_MAX_DISPATCH_TIME_USEC
) -> void:

	_max_publications_per_cycle = (
		max_publications_per_cycle
	)

	_max_callbacks_per_cycle = (
		max_callbacks_per_cycle
	)

	_max_pending_publications = (
		max_pending_publications
	)

	_max_dispatch_time_usec = (
		max_dispatch_time_usec
	)


# =============================================================================
# VALIDATION
# =============================================================================

func is_valid() -> bool:

	return (
		_max_publications_per_cycle > 0
		and _max_publications_per_cycle
			<= HARD_MAX_PUBLICATIONS_PER_CYCLE
		and _max_callbacks_per_cycle > 0
		and _max_callbacks_per_cycle
			<= HARD_MAX_CALLBACKS_PER_CYCLE
		and _max_pending_publications > 0
		and _max_pending_publications
			<= HARD_MAX_PENDING_PUBLICATIONS
		and _max_dispatch_time_usec > 0
		and _max_dispatch_time_usec
			<= HARD_MAX_DISPATCH_TIME_USEC
	)


# =============================================================================
# PUBLIC API
# =============================================================================

func get_max_publications_per_cycle() -> int:

	return _max_publications_per_cycle


func get_max_callbacks_per_cycle() -> int:

	return _max_callbacks_per_cycle


func get_max_pending_publications() -> int:

	return _max_pending_publications


func get_max_dispatch_time_usec() -> int:

	return _max_dispatch_time_usec
