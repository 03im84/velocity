extends RefCounted
class_name Device


##
## Device
##
## Modelo lógico común de un dispositivo.
##
## Compone Identity, Manifest, State,
## Health y Lifecycle.
##
## No depende de SceneTree ni DeviceBus.
##


# =============================================================================
# INTERNAL COMPONENTS
# =============================================================================

var _identity: DeviceIdentity

var _manifest: DeviceManifest

var _state: DeviceState

var _health: DeviceHealth

var _lifecycle: DeviceLifecycle


# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:

	_identity = DeviceIdentity.new()

	_manifest = DeviceManifest.new()

	_state = DeviceState.new()

	_health = DeviceHealth.new()

	_lifecycle = DeviceLifecycle.new()


# =============================================================================
# LIFECYCLE API
# =============================================================================

## Valida Identity antes de inicializar.
func initialize() -> bool:

	if not _identity.is_valid():
		return false

	return _lifecycle.initialize()


func set_ready() -> bool:

	return _lifecycle.set_ready()


func start() -> bool:

	return _lifecycle.start()


func shutdown() -> bool:

	return _lifecycle.shutdown()


# =============================================================================
# COMPONENT ACCESS
# =============================================================================

func get_identity() -> DeviceIdentity:

	return _identity


func get_manifest() -> DeviceManifest:

	return _manifest


func get_state() -> DeviceState:

	return _state


func get_health() -> DeviceHealth:

	return _health


func get_lifecycle() -> DeviceLifecycle:

	return _lifecycle
