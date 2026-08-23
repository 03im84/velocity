extends RefCounted
class_name DeviceBusDispatchReport


##
## DeviceBusDispatchReport
##
## Describe el resultado final de un
## Dispatch Cycle de DeviceBus.
##
## No conserva mensajes ni payloads.
## Se trata como un objeto de solo lectura.
##


enum Status {
	NO_DISPATCH,
	COMPLETED,
	ABORTED_PUBLICATION_BUDGET,
	ABORTED_CALLBACK_BUDGET,
	ABORTED_QUEUE_LIMIT,
	ABORTED_TIME_BUDGET
}


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _status: Status

var _publications_accepted: int

var _publications_dispatched: int

var _callbacks_invoked: int

var _callbacks_skipped: int

var _publications_dropped: int

var _pending_peak: int

var _elapsed_usec: int

var _limit_reached: StringName

var _trigger_topic: StringName


# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(
	status: Status,
	publications_accepted: int,
	publications_dispatched: int,
	callbacks_invoked: int,
	callbacks_skipped: int,
	publications_dropped: int,
	pending_peak: int,
	elapsed_usec: int,
	limit_reached: StringName,
	trigger_topic: StringName
) -> void:

	_status = status

	_publications_accepted = (
		publications_accepted
	)

	_publications_dispatched = (
		publications_dispatched
	)

	_callbacks_invoked = (
		callbacks_invoked
	)

	_callbacks_skipped = (
		callbacks_skipped
	)

	_publications_dropped = (
		publications_dropped
	)

	_pending_peak = pending_peak

	_elapsed_usec = elapsed_usec

	_limit_reached = limit_reached

	_trigger_topic = trigger_topic


# =============================================================================
# PUBLIC API
# =============================================================================

func get_status() -> Status:

	return _status


func get_publications_accepted() -> int:

	return _publications_accepted


func get_publications_dispatched() -> int:

	return _publications_dispatched


func get_callbacks_invoked() -> int:

	return _callbacks_invoked


func get_callbacks_skipped() -> int:

	return _callbacks_skipped


func get_publications_dropped() -> int:

	return _publications_dropped


func get_pending_peak() -> int:

	return _pending_peak


func get_elapsed_usec() -> int:

	return _elapsed_usec


func get_limit_reached() -> StringName:

	return _limit_reached


func get_trigger_topic() -> StringName:

	return _trigger_topic


func is_completed() -> bool:

	return _status == Status.COMPLETED


func is_aborted() -> bool:

	return (
		_status
			== Status.ABORTED_PUBLICATION_BUDGET
		or _status
			== Status.ABORTED_CALLBACK_BUDGET
		or _status
			== Status.ABORTED_QUEUE_LIMIT
		or _status
			== Status.ABORTED_TIME_BUDGET
	)
