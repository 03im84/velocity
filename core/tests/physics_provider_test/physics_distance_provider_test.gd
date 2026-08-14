extends Node

@onready var device_bus: DeviceBus = $DeviceBus
@onready var distance_provider: PhysicsDistanceProvider = $PhysicsDistanceProvider

@onready var provider: PhysicsDistanceProvider = (
	$PhysicsDistanceProvider
)


func _ready() -> void:
	
	await get_tree().physics_frame
	
	print("Provider valid: ", provider.is_valid())
	print("Distance: ", provider.get_distance())
