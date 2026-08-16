class_name BusDebugListener
extends RefCounted


##
## BusDebugListener
##
## Observa mensajes de distancia y muestra
## su contenido para diagnóstico.
##
## No crea DeviceBus.
## Recibe la instancia mediante attach().
##


var _bus: DeviceBus = null
var _enabled: bool = true


## Conecta el listener a una instancia de DeviceBus.
func attach(
	bus: DeviceBus
) -> void:

	if _bus != null:
		detach()

	_bus = bus

	_bus.subscribe(
		BusTopics.DISTANCE_MEASUREMENT,
		Callable(
			self,
			&"_on_distance_measurement"
		)
	)


## Elimina la suscripción y libera
## la referencia secundaria al Bus.
func detach() -> void:

	if _bus == null:
		return

	_bus.unsubscribe(
		BusTopics.DISTANCE_MEASUREMENT,
		Callable(
			self,
			&"_on_distance_measurement"
		)
	)

	_bus = null


## Activa o desactiva la salida de diagnóstico.
func set_enabled(
	value: bool
) -> void:

	_enabled = value


func _on_distance_measurement(
	message: BusMessage
) -> void:

	if not _enabled:
		return

	var measurement: DistanceMeasurement = (
		message.get_payload()
	)

	print("--------------------------------------")

	print(
		"Topic    :",
		message.get_topic()
	)

	print(
		"Source   :",
		message.get_source_id()
	)

	print(
		"Distance :",
		measurement.distance
	)

	print(
		"Valid    :",
		measurement.valid
	)

	print("--------------------------------------")
