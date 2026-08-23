extends RefCounted
class_name DeviceBus


##
## DeviceBus
##
## Gestiona el intercambio desacoplado de mensajes
## entre productores y consumidores.
##
## Runtime Safety:
##
## - dispatch FIFO iterativo;
## - reentrada sin crecimiento del call stack;
## - budgets obligatorios;
## - aborto controlado;
## - Dispatch Report observable.
##
## DeviceBus no interpreta mensajes.
## DeviceBus no conoce Devices concretos.
##


# =============================================================================
# INTERNAL TYPES
# =============================================================================

class DispatchEntry:

	extends RefCounted

	var topic: StringName
	var message: Variant

	func _init(
		p_topic: StringName,
		p_message: Variant
	) -> void:

		topic = p_topic
		message = p_message


class DispatchContext:

	extends RefCounted

	var start_usec: int = 0

	var publications_accepted: int = 0
	var publications_dispatched: int = 0

	var callbacks_invoked: int = 0
	var callbacks_skipped: int = 0

	var publications_dropped: int = 0

	var pending_peak: int = 0

	var aborted: bool = false

	var abort_status: DeviceBusDispatchReport.Status = (
		DeviceBusDispatchReport.Status.NO_DISPATCH
	)

	var limit_reached: StringName = &""
	var trigger_topic: StringName = &""


# =============================================================================
# SUBSCRIPTION REGISTRY
# =============================================================================

var _subscribers_by_topic: Dictionary[StringName, Array] = {}


# =============================================================================
# DISPATCH STATE
# =============================================================================

var _dispatch_policy: DeviceBusDispatchPolicy

var _pending_publications: Array = []

var _queue_read_index: int = 0

var _is_dispatching: bool = false

var _has_dispatched: bool = false

var _active_context: DispatchContext = null

var _last_dispatch_report: DeviceBusDispatchReport


# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:

	_dispatch_policy = (
		DeviceBusDispatchPolicy.new()
	)

	_last_dispatch_report = (
		_create_no_dispatch_report()
	)


# =============================================================================
# SUBSCRIPTION API
# =============================================================================

## Registra un Callable para un topic.
func subscribe(
	topic: StringName,
	subscriber: Callable
) -> bool:

	if topic == &"":
		return false

	if not subscriber.is_valid():
		return false

	var subscribers: Array = (
		_subscribers_by_topic.get(
			topic,
			[]
		)
	)

	if subscribers.has(subscriber):
		return false

	subscribers.append(subscriber)

	_subscribers_by_topic[topic] = subscribers

	return true


## Elimina una suscripción concreta.
func unsubscribe(
	topic: StringName,
	subscriber: Callable
) -> bool:

	if topic == &"":
		return false

	if not _subscribers_by_topic.has(topic):
		return false

	var subscribers: Array = (
		_subscribers_by_topic[topic]
	)

	var subscriber_index: int = (
		subscribers.find(subscriber)
	)

	if subscriber_index == -1:
		return false

	subscribers.remove_at(
		subscriber_index
	)

	_erase_topic_if_empty(topic)

	return true


## Elimina todos los registros permanentes.
##
## No cancela automáticamente el Dispatch Cycle.
func clear() -> void:

	_subscribers_by_topic.clear()


# =============================================================================
# QUERY API
# =============================================================================

func has_subscribers(
	topic: StringName
) -> bool:

	return get_subscriber_count(topic) > 0


func get_subscriber_count(
	topic: StringName
) -> int:

	if topic == &"":
		return 0

	if not _subscribers_by_topic.has(topic):
		return 0

	_prune_invalid_subscribers(topic)

	if not _subscribers_by_topic.has(topic):
		return 0

	var subscribers: Array = (
		_subscribers_by_topic[topic]
	)

	return subscribers.size()


func get_topics() -> Array[StringName]:

	var topics_snapshot: Array = (
		_subscribers_by_topic.keys()
	)

	var active_topics: Array[StringName] = []

	for topic_value: Variant in topics_snapshot:

		var topic: StringName = topic_value

		_prune_invalid_subscribers(topic)

		if _subscribers_by_topic.has(topic):
			active_topics.append(topic)

	return active_topics


# =============================================================================
# POLICY API
# =============================================================================

func configure_dispatch_policy(
	policy: DeviceBusDispatchPolicy
) -> bool:

	if policy == null:
		return false

	if not policy.is_valid():
		return false

	if _is_dispatching:
		return false

	if _has_dispatched:
		return false

	_dispatch_policy = policy

	return true


func get_dispatch_policy(
) -> DeviceBusDispatchPolicy:

	return _dispatch_policy


# =============================================================================
# REPORT API
# =============================================================================

func get_last_dispatch_report(
) -> DeviceBusDispatchReport:

	return _last_dispatch_report


# =============================================================================
# PUBLICATION API
# =============================================================================

## Publica un mensaje mediante bounded FIFO dispatch.
##
## Root publish:
## - devuelve true si el ciclo termina COMPLETED;
## - devuelve false si el ciclo es abortado.
##
## Reentrant publish:
## - devuelve true si la Entry es aceptada;
## - devuelve false si es rechazada.
func publish(
	topic: StringName,
	message: Variant
) -> bool:

	if topic == &"":
		return false

	if _is_dispatching:
		return _enqueue_publication(
			topic,
			message
		)

	_begin_dispatch_cycle()

	var root_accepted: bool = (
		_enqueue_publication(
			topic,
			message
		)
	)

	if root_accepted:
		_process_pending_publications()

	_finish_dispatch_cycle()

	return (
		root_accepted
		and _last_dispatch_report.is_completed()
	)


# =============================================================================
# DISPATCH CYCLE
# =============================================================================

func _begin_dispatch_cycle() -> void:

	_pending_publications.clear()

	_queue_read_index = 0

	_active_context = DispatchContext.new()

	_active_context.start_usec = (
		Time.get_ticks_usec()
	)

	_is_dispatching = true

	_has_dispatched = true


func _process_pending_publications() -> void:

	while (
		_active_context != null
		and not _active_context.aborted
		and _queue_read_index
			< _pending_publications.size()
	):

		var next_entry: DispatchEntry = (
			_pending_publications[
				_queue_read_index
			]
		)

		if _abort_if_time_exceeded(
			next_entry.topic
		):
			break

		_queue_read_index += 1

		_active_context.publications_dispatched += 1

		_dispatch_entry(next_entry)


func _finish_dispatch_cycle() -> void:

	if _active_context == null:
		return

	var elapsed_usec: int = (
		_get_elapsed_usec()
	)

	var final_status: DeviceBusDispatchReport.Status = (
		DeviceBusDispatchReport.Status.COMPLETED
	)

	if _active_context.aborted:
		final_status = (
			_active_context.abort_status
		)

	_last_dispatch_report = (
		DeviceBusDispatchReport.new(
			final_status,
			_active_context.publications_accepted,
			_active_context.publications_dispatched,
			_active_context.callbacks_invoked,
			_active_context.callbacks_skipped,
			_active_context.publications_dropped,
			_active_context.pending_peak,
			elapsed_usec,
			_active_context.limit_reached,
			_active_context.trigger_topic
		)
	)

	_pending_publications.clear()

	_queue_read_index = 0

	_active_context = null

	_is_dispatching = false


# =============================================================================
# ENQUEUE
# =============================================================================

func _enqueue_publication(
	topic: StringName,
	message: Variant
) -> bool:

	if _active_context == null:
		return false

	if _active_context.aborted:
		return false

	if _is_dispatch_time_exceeded():

		_abort_dispatch(
			DeviceBusDispatchReport
				.Status.ABORTED_TIME_BUDGET,
			&"time_budget",
			topic,
			1,
			0
		)

		return false

	if (
		_active_context.publications_accepted
		>= _dispatch_policy
			.get_max_publications_per_cycle()
	):

		_abort_dispatch(
			DeviceBusDispatchReport
				.Status.ABORTED_PUBLICATION_BUDGET,
			&"publication_budget",
			topic,
			1,
			0
		)

		return false

	var pending_count: int = (
		_get_pending_publication_count()
	)

	if (
		pending_count
		>= _dispatch_policy
			.get_max_pending_publications()
	):

		_abort_dispatch(
			DeviceBusDispatchReport
				.Status.ABORTED_QUEUE_LIMIT,
			&"queue_limit",
			topic,
			1,
			0
		)

		return false

	var entry := DispatchEntry.new(
		topic,
		message
	)

	_pending_publications.append(entry)

	_active_context.publications_accepted += 1

	var new_pending_count: int = (
		_get_pending_publication_count()
	)

	_active_context.pending_peak = max(
		_active_context.pending_peak,
		new_pending_count
	)

	return true


# =============================================================================
# ENTRY DISPATCH
# =============================================================================

func _dispatch_entry(
	entry: DispatchEntry
) -> void:

	var subscribers_snapshot: Array = []

	if _subscribers_by_topic.has(entry.topic):

		var registered_subscribers: Array = (
			_subscribers_by_topic[entry.topic]
		)

		subscribers_snapshot = (
			registered_subscribers.duplicate()
		)

	var subscriber_index: int = 0

	while (
		subscriber_index
		< subscribers_snapshot.size()
	):

		if (
			_active_context == null
			or _active_context.aborted
		):
			break

		var subscriber: Callable = (
			subscribers_snapshot[
				subscriber_index
			]
		)

		if not subscriber.is_valid():

			subscriber_index += 1

			continue

		if (
			_active_context.callbacks_invoked
			>= _dispatch_policy
				.get_max_callbacks_per_cycle()
		):

			var skipped_callbacks: int = (
				_count_valid_callbacks(
					subscribers_snapshot,
					subscriber_index
				)
			)

			_abort_dispatch(
				DeviceBusDispatchReport
					.Status.ABORTED_CALLBACK_BUDGET,
				&"callback_budget",
				entry.topic,
				0,
				skipped_callbacks
			)

			break

		if _is_dispatch_time_exceeded():

			var skipped_before_call: int = (
				_count_valid_callbacks(
					subscribers_snapshot,
					subscriber_index
				)
			)

			_abort_dispatch(
				DeviceBusDispatchReport
					.Status.ABORTED_TIME_BUDGET,
				&"time_budget",
				entry.topic,
				0,
				skipped_before_call
			)

			break

		subscriber.call(
			entry.message
		)

		_active_context.callbacks_invoked += 1

		subscriber_index += 1

		if _active_context.aborted:

			_active_context.callbacks_skipped += (
				_count_valid_callbacks(
					subscribers_snapshot,
					subscriber_index
				)
			)

			break

		if _is_dispatch_time_exceeded():

			var skipped_after_call: int = (
				_count_valid_callbacks(
					subscribers_snapshot,
					subscriber_index
				)
			)

			_abort_dispatch(
				DeviceBusDispatchReport
					.Status.ABORTED_TIME_BUDGET,
				&"time_budget",
				entry.topic,
				0,
				skipped_after_call
			)

			break

	_prune_invalid_subscribers(
		entry.topic
	)


# =============================================================================
# ABORT
# =============================================================================

func _abort_dispatch(
	status: DeviceBusDispatchReport.Status,
	limit_reached: StringName,
	trigger_topic: StringName,
	rejected_publications: int,
	skipped_callbacks: int
) -> void:

	if _active_context == null:
		return

	if _active_context.aborted:
		return

	_active_context.aborted = true

	_active_context.abort_status = status

	_active_context.limit_reached = (
		limit_reached
	)

	_active_context.trigger_topic = (
		trigger_topic
	)

	_active_context.publications_dropped += (
		rejected_publications
	)

	_active_context.callbacks_skipped += (
		skipped_callbacks
	)

	var pending_publications: int = (
		_get_pending_publication_count()
	)

	_active_context.publications_dropped += (
		pending_publications
	)

	_pending_publications.clear()

	_queue_read_index = 0


func _abort_if_time_exceeded(
	trigger_topic: StringName
) -> bool:

	if not _is_dispatch_time_exceeded():
		return false

	_abort_dispatch(
		DeviceBusDispatchReport
			.Status.ABORTED_TIME_BUDGET,
		&"time_budget",
		trigger_topic,
		0,
		0
	)

	return true


# =============================================================================
# DISPATCH QUERIES
# =============================================================================

func _get_pending_publication_count() -> int:

	return max(
		0,
		_pending_publications.size()
			- _queue_read_index
	)


func _get_elapsed_usec() -> int:

	if _active_context == null:
		return 0

	return max(
		0,
		Time.get_ticks_usec()
			- _active_context.start_usec
	)


func _is_dispatch_time_exceeded() -> bool:

	return (
		_get_elapsed_usec()
		>= _dispatch_policy
			.get_max_dispatch_time_usec()
	)


func _count_valid_callbacks(
	subscribers: Array,
	start_index: int
) -> int:

	var valid_count: int = 0

	var subscriber_index: int = start_index

	while subscriber_index < subscribers.size():

		var subscriber: Callable = (
			subscribers[subscriber_index]
		)

		if subscriber.is_valid():
			valid_count += 1

		subscriber_index += 1

	return valid_count


# =============================================================================
# SUBSCRIPTION MAINTENANCE
# =============================================================================

func _erase_topic_if_empty(
	topic: StringName
) -> void:

	if not _subscribers_by_topic.has(topic):
		return

	var subscribers: Array = (
		_subscribers_by_topic[topic]
	)

	if subscribers.is_empty():
		_subscribers_by_topic.erase(topic)


func _prune_invalid_subscribers(
	topic: StringName
) -> void:

	if not _subscribers_by_topic.has(topic):
		return

	var subscribers: Array = (
		_subscribers_by_topic[topic]
	)

	var subscriber_index: int = (
		subscribers.size() - 1
	)

	while subscriber_index >= 0:

		var subscriber: Callable = (
			subscribers[subscriber_index]
		)

		if not subscriber.is_valid():

			subscribers.remove_at(
				subscriber_index
			)

		subscriber_index -= 1

	_erase_topic_if_empty(topic)


# =============================================================================
# REPORT FACTORY
# =============================================================================

func _create_no_dispatch_report(
) -> DeviceBusDispatchReport:

	return DeviceBusDispatchReport.new(
		DeviceBusDispatchReport.Status.NO_DISPATCH,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		&"",
		&""
	)
