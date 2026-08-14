extends Node
class_name  DeviceLifeCycle

enum State {
	CREATED,
	INITIALIZED,
	READY,
	RUNNING,
	SHUTDOWN
}

var current_state: State = State.CREATED

func initialize() -> bool:
	if current_state != State.CREATED:
		return false
	
	current_state = State.INITIALIZED
	return true
	
func set_ready() -> bool:
	if current_state != State.INITIALIZED:
		return false
	
	current_state = State.READY
	return true
	
func start() -> bool:
	if current_state != State.READY:
		return false
	
	current_state = State.RUNNING
	return true
	
func shutdown() -> bool:
	if current_state == State.SHUTDOWN:
		return false
		
	current_state = State.SHUTDOWN
	return true
	
func get_state() -> State:
	return current_state
