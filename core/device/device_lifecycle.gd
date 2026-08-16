extends RefCounted
class_name DeviceLifecycle


##
## DeviceLifecycle
##
## Representa la etapa operacional
## y las transiciones de un Device.
##
## No representa Health.
## No depende de SceneTree.
##


enum State {
	CREATED,
	INITIALIZED,
	READY,
	RUNNING,
	SHUTDOWN
}


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _current_state: State = State.CREATED


# =============================================================================
# PUBLIC API
# =============================================================================

## Transición:
## CREATED → INITIALIZED
func initialize() -> bool:

	if _current_state != State.CREATED:
		return false

	_current_state = State.INITIALIZED

	return true


## Transición:
## INITIALIZED → READY
func set_ready() -> bool:

	if _current_state != State.INITIALIZED:
		return false

	_current_state = State.READY

	return true


## Transición:
## READY → RUNNING
func start() -> bool:

	if _current_state != State.READY:
		return false

	_current_state = State.RUNNING

	return true


## Transición desde cualquier estado
## distinto de SHUTDOWN.
func shutdown() -> bool:

	if _current_state == State.SHUTDOWN:
		return false

	_current_state = State.SHUTDOWN

	return true


## Devuelve el estado actual.
func get_state() -> State:

	return _current_state
