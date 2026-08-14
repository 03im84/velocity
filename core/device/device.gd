extends Node
class_name Device

var identity: DeviceIdentity
var manifest: DeviceManifest
var state: DeviceState
var health: DeviceHealth
var lifecycle: DeviceLifeCycle

func _init() -> void:
	identity = DeviceIdentity.new()
	manifest = DeviceManifest.new()
	state = DeviceState.new()
	health = DeviceHealth.new()
	
	lifecycle = DeviceLifeCycle.new()
	add_child(lifecycle)

func initialize() -> bool:
	return lifecycle.initialize()
	
func set_ready() -> bool:
	return lifecycle.set_ready()
	
func start() -> bool:
	return lifecycle.start()
	
func shutdown() -> bool:
	return lifecycle.shutdown()

func get_identity() -> DeviceIdentity:
	return identity

func get_manifest() -> DeviceManifest:
	return manifest
	
func get_state() -> DeviceState:
	return state

func get_health() -> DeviceHealth:
	return health
	
func get_lifecycle() -> DeviceLifeCycle:
	return lifecycle
