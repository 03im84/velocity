extends RefCounted


##
## DeviceBusTestConsumer
##
## Consumidor mínimo utilizado únicamente
## por la prueba de integración.
##
## No conoce al productor.
##


var _received_messages: Array = []


## Callback registrado en DeviceBus.
func receive(
	message: Variant
) -> void:

	_received_messages.append(message)


## Devuelve la cantidad de mensajes recibidos.
func get_received_count() -> int:

	return _received_messages.size()


## Devuelve el último mensaje recibido.
func get_last_message() -> Variant:

	if _received_messages.is_empty():
		return null

	return _received_messages.back()
