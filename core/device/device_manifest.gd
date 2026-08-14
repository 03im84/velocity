extends Resource
class_name DeviceManifest

@export var capabilities: Array[String] = []
@export var publishes: Array[String] = []
@export var subscribes: Array[String] = []
@export var requirements: Array[String] = []

func has_capability(capability: String) -> bool:
	return capabilities.has(capability)
	
func publishes_topic(topic: String) -> bool:
	return publishes.has(topic)
	
func subscribes_to(topic: String) -> bool:
	return subscribes.has(topic)
	
func has_requirements(requiement: String) -> bool:
	return requirements.has(requiement)
