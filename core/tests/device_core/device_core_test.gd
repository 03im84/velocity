extends Node


func _ready() -> void:
	var device: Device = $TestDevice
	
	print("Initial state: ", device.get_lifecycle().get_state())

	print("Initialize: ", device.initialize())
	print("State: ", device.get_lifecycle().get_state())

	print("Ready: ", device.set_ready())
	print("State: ", device.get_lifecycle().get_state())

	print("Start: ", device.start())
	print("State: ", device.get_lifecycle().get_state())

	print("Shutdown: ", device.shutdown())
	print("State: ", device.get_lifecycle().get_state())
