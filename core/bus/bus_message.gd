extends RefCounted
class_name BusMessage


##
## BusMessage
##
## Envelope de ejecución para mensajes
## intercambiados mediante DeviceBus.
##
## Se construye completamente y se trata
## como un objeto de solo lectura.
##


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _source_id: String
var _topic: StringName
var _timestamp: float
var _payload: Variant


# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(
	p_source_id: String,
	p_topic: StringName,
	p_timestamp: float,
	p_payload: Variant = null
) -> void:

	_source_id = p_source_id
	_topic = p_topic
	_timestamp = p_timestamp
	_payload = p_payload


# =============================================================================
# PUBLIC API
# =============================================================================

## Indica si el envelope contiene
## la identidad mínima requerida.
func is_valid() -> bool:

	return (
		not _source_id.is_empty()
		and _topic != &""
	)


## Devuelve la identidad del productor.
func get_source_id() -> String:

	return _source_id


## Devuelve el topic contenido
## en el envelope.
func get_topic() -> StringName:

	return _topic


## Devuelve el timestamp del mensaje.
func get_timestamp() -> float:

	return _timestamp


## Devuelve el payload sin copiarlo
## ni interpretarlo.
func get_payload() -> Variant:

	return _payload
