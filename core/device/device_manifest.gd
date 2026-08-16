extends Resource
class_name DeviceManifest


@export var capabilities: Array[String] = []
@export var publishes: Array[StringName] = []
@export var subscribes: Array[StringName] = []
@export var requirements: Array[String] = []


func has_capability(
	capability: String
) -> bool:

	return capabilities.has(capability)


func publishes_topic(
	topic: StringName
) -> bool:

	return publishes.has(topic)


func subscribes_to(
	topic: StringName
) -> bool:

	return subscribes.has(topic)


func has_requirements(
	requiement: String
) -> bool:

	return requirements.has(requiement)
