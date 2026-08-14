extends RefCounted


##
## DeviceBusTestProducer
##
## Productor mínimo utilizado únicamente
## por la prueba de integración.
##
## No conoce consumidores.
##


var _bus: DeviceBus
var _topic: StringName


func _init(
	p_bus: DeviceBus,
	p_topic: StringName
) -> void:

	_bus = p_bus
	_topic = p_topic


## Publica un mensaje mediante DeviceBus.
func emit(
	message: Variant
) -> void:

	_bus.publish(
		_topic,
		message
	)
