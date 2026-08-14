extends RefCounted
class_name DeviceBus


##
## DeviceBus
##
## Gestiona el intercambio desacoplado de mensajes
## entre productores y consumidores.
##
## No conoce Devices concretos.
## No interpreta mensajes.
## No almacena estado funcional.
##


# =============================================================================
# REGISTRO INTERNO
# =============================================================================

var _subscribers_by_topic: Dictionary[StringName, Array] = {}

# =============================================================================
# PUBLIC API
# =============================================================================

## Registra un Callable para un topic.
##
## Devuelve true si la suscripción fue creada.
##
## Devuelve false cuando:
## - el topic está vacío;
## - el Callable no es válido;
## - la misma suscripción ya existe.
func subscribe(
	topic: StringName,
	subscriber: Callable
) -> bool:

	if topic == &"":
		return false

	if not subscriber.is_valid():
		return false

	var subscribers: Array = _subscribers_by_topic.get(
		topic,
		[]
	)

	if subscribers.has(subscriber):
		return false

	subscribers.append(subscriber)

	_subscribers_by_topic[topic] = subscribers

	return true
	
## Elimina una suscripción concreta.
##
## Devuelve true si la suscripción existía
## y fue eliminada.
##
## Devuelve false si:
## - el topic está vacío;
## - el topic no existe;
## - el Callable no está registrado.
func unsubscribe(
	topic: StringName,
	subscriber: Callable
) -> bool:

	if topic == &"":
		return false

	if not _subscribers_by_topic.has(topic):
		return false

	var subscribers: Array = _subscribers_by_topic[topic]

	var subscriber_index: int = subscribers.find(
		subscriber
	)

	if subscriber_index == -1:
		return false

	subscribers.remove_at(
		subscriber_index
	)

	if subscribers.is_empty():
		_erase_topic_if_empty(topic)

	return true


## Elimina todos los registros del Bus.
##
## No destruye suscriptores ni modifica Devices.
func clear() -> void:

	_subscribers_by_topic.clear()

## Indica si un topic tiene al menos
## un suscriptor válido.
func has_subscribers(
	topic: StringName
) -> bool:

	return get_subscriber_count(topic) > 0


## Devuelve la cantidad de suscriptores válidos
## registrados para un topic.
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

	var subscribers: Array = _subscribers_by_topic[topic]

	return subscribers.size()


## Devuelve los topics activos en orden
## de creación.
##
## El Array devuelto es independiente de la
## estructura interna del Bus.
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
	
	
## Publica un mensaje para los suscriptores
## registrados en un topic.
##
## La entrega es síncrona y utiliza una
## instantánea superficial del registro.
##
## DeviceBus no modifica ni copia el mensaje.
func publish(
	topic: StringName,
	message: Variant
) -> void:

	if topic == &"":
		return

	if not _subscribers_by_topic.has(topic):
		return

	var subscribers: Array = (
		_subscribers_by_topic[topic]
	)

	var publication_snapshot: Array = (
		subscribers.duplicate()
	)

	for subscriber: Callable in publication_snapshot:

		if not subscriber.is_valid():
			continue

		subscriber.call(message)

	_prune_invalid_subscribers(topic)
	
	
# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Elimina un topic cuando su lista
## no contiene suscriptores.
func _erase_topic_if_empty(
	topic: StringName
) -> void:

	if not _subscribers_by_topic.has(topic):
		return

	var subscribers: Array = _subscribers_by_topic[topic]

	if subscribers.is_empty():
		_subscribers_by_topic.erase(topic)
		
		
## Elimina los Callables que dejaron
## de ser válidos.
##
## Conserva el orden relativo de los
## suscriptores restantes.
func _prune_invalid_subscribers(
	topic: StringName
) -> void:

	if not _subscribers_by_topic.has(topic):
		return

	var subscribers: Array = _subscribers_by_topic[topic]

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
