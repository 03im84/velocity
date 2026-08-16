# Device Core — Diseño

| Campo | Valor |
|---|---|
| Estado | BORRADOR |
| Versión | 0.1 |
| Fecha | 2026-08-15 |
| ADR relacionado | ADR-006 — Device Core Contract |
| Componentes | Device, Identity, Manifest, State, Health, Lifecycle |

## 1. Propósito

Este documento traduce ADR-006 a un diseño concreto e implementable para Device Core.

Define:

- la forma de Device;
- la composición de sus componentes;
- la validación de identidad;
- la API de DeviceManifest;
- la máquina de estados DeviceLifecycle;
- el contrato de DeviceState;
- el contrato de DeviceHealth;
- la migración de Devices especializados;
- las pruebas sucesoras;
- el orden de implementación.

Este documento no implementa DeviceGraph.

## 2. Alcance

El diseño afectará:

```text
core/device/device.gd

core/device/device_identity.gd

core/device/device_manifest.gd

core/device/device_state.gd

core/device/device_health.gd

core/device/device_lifecycle.gd

core/device/sensors/
distance_sensor_device.gd
```

También afectará pruebas que dependan de:

```text
Device como Node

DeviceLifeCycle

has_requirements()
```

No afectará:

```text
DeviceBus

BusMessage

BusTopics

Provider System

DistanceMeasurement

PhysicsDistanceProvider
```

## 3. Diseño de Device

### 3.1 Forma

Device será:

```gdscript
extends RefCounted
class_name Device
```

Device no tendrá:

- `_ready()`;
- `_process()`;
- `_physics_process()`;
- posición;
- acceso a SceneTree;
- Nodes hijos;
- referencia a DeviceBus.

### 3.2 Estado interno

Device conservará:

```gdscript
var _identity: DeviceIdentity

var _manifest: DeviceManifest

var _state: DeviceState

var _health: DeviceHealth

var _lifecycle: DeviceLifecycle
```

Las variables serán privadas por convención.

No existirán simultáneamente variables públicas como:

```gdscript
identity
manifest
state
health
lifecycle
```

### 3.3 Construcción

Durante `_init()`:

```gdscript
_identity = DeviceIdentity.new()

_manifest = DeviceManifest.new()

_state = DeviceState.new()

_health = DeviceHealth.new()

_lifecycle = DeviceLifecycle.new()
```

Device no ejecutará:

```gdscript
add_child()
```

Ningún componente interno será Node.

### 3.4 API de lifecycle

Device expondrá:

```gdscript
func initialize() -> bool
```

```gdscript
func set_ready() -> bool
```

```gdscript
func start() -> bool
```

```gdscript
func shutdown() -> bool
```

Estas operaciones delegarán en DeviceLifecycle.

### 3.5 API de componentes

```gdscript
func get_identity() -> DeviceIdentity
```

```gdscript
func get_manifest() -> DeviceManifest
```

```gdscript
func get_state() -> DeviceState
```

```gdscript
func get_health() -> DeviceHealth
```

```gdscript
func get_lifecycle() -> DeviceLifecycle
```

Device no expondrá setters para sustituir estos componentes.

## 4. Inicialización de Device

`initialize()` comprobará DeviceIdentity antes de modificar lifecycle.

Forma prevista:

```gdscript
func initialize() -> bool:

	if not _identity.is_valid():
		return false

	return _lifecycle.initialize()
```

### 4.1 Identidad inválida

Si cualquiera de estas condiciones ocurre:

```text
device_id vacío;

device_type vacío;

device_version menor o igual que cero;
```

el resultado será:

```text
initialize() devuelve false;

lifecycle continúa en CREATED.
```

### 4.2 Identidad válida

Si DeviceIdentity es válida:

```text
initialize() delega en DeviceLifecycle;

CREATED cambia a INITIALIZED.
```

Una segunda llamada a `initialize()` devuelve `false` porque lifecycle ya no se encuentra en CREATED.

### 4.3 Manifest

Device no validará automáticamente DeviceManifest durante `initialize()`.

Todavía no existe una política universal que indique:

- capabilities obligatorias;
- topics obligatorios;
- requirements obligatorios.

Cada Device especializado configura su Manifest antes de inicializar.

## 5. Diseño de DeviceIdentity

### 5.1 Forma

DeviceIdentity continuará como:

```gdscript
extends Resource
class_name DeviceIdentity
```

### 5.2 Estado

```gdscript
@export var device_id: String = ""

@export var device_type: String = ""

@export var device_version: int = 1
```

### 5.3 Validación

```gdscript
func is_valid() -> bool
```

devolverá:

```gdscript
return (
	not device_id.is_empty()
	and not device_type.is_empty()
	and device_version > 0
)
```

### 5.4 API de lectura

```gdscript
func get_device_id() -> String
```

```gdscript
func get_device_type() -> String
```

```gdscript
func get_device_version() -> int
```

No se añadirá un constructor obligatorio.

Los Devices especializados configuran Identity antes de ejecutar `initialize()`.

## 6. Diseño de DeviceManifest

### 6.1 Forma

DeviceManifest continuará como:

```gdscript
extends Resource
class_name DeviceManifest
```

### 6.2 Estado

```gdscript
@export var capabilities: Array[String] = []

@export var publishes: Array[StringName] = []

@export var subscribes: Array[StringName] = []

@export var requirements: Array[String] = []
```

### 6.3 API

```gdscript
func has_capability(
	capability: String
) -> bool
```

```gdscript
func publishes_topic(
	topic: StringName
) -> bool
```

```gdscript
func subscribes_to(
	topic: StringName
) -> bool
```

```gdscript
func has_requirement(
	requirement: String
) -> bool
```

### 6.4 API retirada

Se retirará:

```gdscript
has_requirements()
```

No se conservará como alias.

La prueba sucesora deberá existir antes de retirar la API anterior.

### 6.5 Responsabilidad

DeviceManifest describe:

- capacidades;
- topics publicados;
- topics consumidos;
- requisitos.

No:

- valida lifecycle;
- publica mensajes;
- crea DeviceBus;
- controla Health;
- administra Devices.

## 7. Diseño de DeviceLifecycle

### 7.1 Archivo

```text
core/device/device_lifecycle.gd
```

### 7.2 Forma

```gdscript
extends RefCounted
class_name DeviceLifecycle
```

Se retirará:

```gdscript
class_name DeviceLifeCycle
```

### 7.3 Estados

```gdscript
enum State {
	CREATED,
	INITIALIZED,
	READY,
	RUNNING,
	SHUTDOWN
}
```

### 7.4 Estado interno

```gdscript
var _current_state: State = State.CREATED
```

No se expondrá una variable pública `current_state`.

### 7.5 API

```gdscript
func initialize() -> bool
```

```gdscript
func set_ready() -> bool
```

```gdscript
func start() -> bool
```

```gdscript
func shutdown() -> bool
```

```gdscript
func get_state() -> State
```

## 8. Transiciones de DeviceLifecycle

### 8.1 Initialize

```text
Estado requerido:
CREATED

Estado resultante:
INITIALIZED
```

Si el estado no es CREATED:

```text
devuelve false;
no cambia el estado.
```

### 8.2 Set Ready

```text
Estado requerido:
INITIALIZED

Estado resultante:
READY
```

Si el estado no es INITIALIZED:

```text
devuelve false;
no cambia el estado.
```

### 8.3 Start

```text
Estado requerido:
READY

Estado resultante:
RUNNING
```

Si el estado no es READY:

```text
devuelve false;
no cambia el estado.
```

### 8.4 Shutdown

`shutdown()` puede ejecutarse desde:

```text
CREATED

INITIALIZED

READY

RUNNING
```

Estado resultante:

```text
SHUTDOWN
```

Si ya se encuentra en SHUTDOWN:

```text
devuelve false;
no cambia el estado.
```

### 8.5 Restart

DeviceLifecycle 1.0 no permitirá salir de SHUTDOWN.

No implementará:

```text
restart()

reset()

boot()
```

Estas capacidades requieren una decisión futura.

## 9. Invariantes del bloque

1. Device hereda de RefCounted.

2. Device no contiene Nodes.

3. Device compone cinco componentes internos.

4. Los componentes se crean durante `_init()`.

5. Los componentes no pueden sustituirse mediante setters.

6. Identity se valida antes de cambiar lifecycle.

7. Manifest no se valida sin una política concreta.

8. DeviceLifecycle hereda de RefCounted.

9. El nombre canónico es DeviceLifecycle.

10. Lifecycle comienza en CREATED.

11. Las transiciones inválidas no modifican estado.

12. SHUTDOWN es final en la versión 1.0.

13. Device Core no conoce DeviceBus.

## 10. Diseño de DeviceState

### 10.1 Archivo

```text
core/device/device_state.gd
```

### 10.2 Forma

DeviceState continuará como:

```gdscript
extends Resource
class_name DeviceState
```

DeviceState no necesita:

- Node;
- SceneTree;
- procesamiento por frame;
- referencia a Device;
- referencia a DeviceBus.

### 10.3 Estado interno

```gdscript
var _data_valid: bool = false

var _last_update_time: float = 0.0
```

Las variables serán privadas por convención.

Se retirarán las variables públicas:

```gdscript
data_valid

last_update_time
```

### 10.4 Estado inicial

Al crear DeviceState:

```text
_data_valid = false

_last_update_time = 0.0
```

Un Device recién creado todavía no contiene datos válidos.

### 10.5 Validar datos

```gdscript
func validate() -> void
```

Comportamiento:

```gdscript
_data_valid = true
```

`validate()` no modifica automáticamente el timestamp.

La validez y el tiempo son decisiones independientes.

### 10.6 Invalidar datos

```gdscript
func invalidate() -> void
```

Comportamiento:

```gdscript
_data_valid = false
```

`invalidate()` no elimina el último timestamp.

El timestamp puede ser útil para conocer cuándo existió la última actualización, incluso si los datos actuales dejaron de ser válidos.

### 10.7 Actualizar timestamp

```gdscript
func update_timestamp(
	time: float
) -> void
```

Comportamiento:

```gdscript
_last_update_time = time
```

DeviceState no interpreta:

- origen del reloj;
- tiempo real;
- tiempo de simulación;
- epoch;
- sincronización.

Solo conserva el valor recibido.

### 10.8 Consultas

```gdscript
func is_valid() -> bool
```

Devuelve:

```gdscript
_data_valid
```

```gdscript
func get_last_update_time() -> float
```

Devuelve:

```gdscript
_last_update_time
```

### 10.9 Responsabilidad

DeviceState responde únicamente:

```text
¿Los datos actuales del Device son válidos?

¿Cuál fue su último timestamp registrado?
```

No responde:

- en qué lifecycle se encuentra el Device;
- cuál es su condición de Health;
- qué payload contiene;
- qué Measurement fue producida;
- qué mensaje se publicó.

## 11. Diseño de DeviceHealth

### 11.1 Archivo

```text
core/device/device_health.gd
```

### 11.2 Forma

DeviceHealth continuará como:

```gdscript
extends Resource
class_name DeviceHealth
```

### 11.3 Estados

```gdscript
enum Status {
	HEALTHY,
	DEGRADED,
	CRITICAL,
	FAILED
}
```

Los valores representan condición operacional.

No representan lifecycle.

### 11.4 Estado interno

```gdscript
var _status: Status = Status.HEALTHY

var _faults: Array[String] = []

var _warnings: Array[String] = []
```

Las variables serán privadas por convención.

Se retirarán las variables públicas:

```gdscript
status

faults

warnings
```

### 11.5 Estado inicial

Al crear DeviceHealth:

```text
_status = HEALTHY

_faults = []

_warnings = []
```

Un Device nuevo comienza sin diagnósticos registrados.

### 11.6 Modificar Status

```gdscript
func set_status(
	new_status: Status
) -> void
```

Comportamiento:

```gdscript
_status = new_status
```

Consulta:

```gdscript
func get_status() -> Status
```

Devuelve:

```gdscript
_status
```

### 11.7 Añadir Fault

```gdscript
func add_fault(
	fault: String
) -> void
```

Comportamiento:

```gdscript
if not _faults.has(fault):
	_faults.append(fault)
```

No se aceptarán duplicados.

Añadir un fault no modifica automáticamente `_status`.

### 11.8 Eliminar Fault

```gdscript
func remove_fault(
	fault: String
) -> void
```

Comportamiento:

```gdscript
_faults.erase(fault)
```

Eliminar un fault inexistente no produce error.

Eliminar un fault no modifica automáticamente `_status`.

### 11.9 Añadir Warning

```gdscript
func add_warning(
	warning: String
) -> void
```

Comportamiento:

```gdscript
if not _warnings.has(warning):
	_warnings.append(warning)
```

No se aceptarán duplicados.

Se retirará el nombre anterior:

```gdscript
add_waring()
```

No se conservará como alias.

### 11.10 Eliminar Warning

```gdscript
func remove_warning(
	warning: String
) -> void
```

Comportamiento:

```gdscript
_warnings.erase(warning)
```

Eliminar un warning inexistente no produce error.

### 11.11 Consultar diagnósticos

```gdscript
func get_faults() -> Array[String]
```

Devolverá un Array nuevo con los faults registrados.

```gdscript
func get_warnings() -> Array[String]
```

Devolverá un Array nuevo con los warnings registrados.

Modificar los Arrays devueltos no alterará el estado interno de DeviceHealth.

### 11.12 Consultar existencia

```gdscript
func has_faults() -> bool
```

Devuelve:

```gdscript
not _faults.is_empty()
```

```gdscript
func has_warnings() -> bool
```

Devuelve:

```gdscript
not _warnings.is_empty()
```

### 11.13 Condición operacional

```gdscript
func is_operational() -> bool
```

Devuelve:

```gdscript
_status != Status.FAILED
```

Por tanto:

```text
HEALTHY:
operacional

DEGRADED:
operacional

CRITICAL:
operacional

FAILED:
no operacional
```

ADR-006 no define restricciones automáticas de ejecución basadas en Health.

## 12. Política de diagnósticos

Status, faults y warnings serán independientes.

Ejemplo válido:

```text
Status:
HEALTHY

Warnings:
["temperature_near_limit"]
```

También:

```text
Status:
DEGRADED

Faults:
["secondary_sensor_offline"]
```

El componente o controlador responsable decide cuándo ejecutar:

```gdscript
set_status()
```

DeviceHealth no calcula automáticamente status porque todavía no existe:

- severidad de diagnósticos;
- clasificación de faults;
- reglas de degradación;
- política de recuperación;
- prioridad de warnings.

### 12.1 Duplicados

Registrar dos veces:

```text
secondary_sensor_offline
```

produce una sola entrada.

Esto se aplica tanto a:

```text
faults
warnings
```

### 12.2 Orden

Faults y warnings conservan el orden de registro.

Eliminar una entrada no reordena las restantes.

Una entrada eliminada y añadida nuevamente aparece al final.

### 12.3 Arrays devueltos

Ejemplo:

```gdscript
var faults_copy := health.get_faults()

faults_copy.clear()
```

Esta operación no debe modificar:

```text
_health._faults
```

Los consumidores no reciben acceso directo a las colecciones internas.

## 13. Separación de responsabilidades

### DeviceState

```text
Validez de datos.

Timestamp.
```

### DeviceHealth

```text
Condición operacional.

Faults.

Warnings.
```

### DeviceLifecycle

```text
Etapa operacional.

Transiciones.
```

Ejemplo:

```text
DeviceState:
invalid

DeviceHealth:
DEGRADED

DeviceLifecycle:
RUNNING
```

Esta combinación es válida.

Los tres componentes son independientes.

Una modificación en uno no cambia automáticamente los otros.

Las políticas que coordinen State, Health y Lifecycle pertenecerán a componentes de control futuros.

## 14. Invariantes del bloque

1. DeviceState continúa siendo Resource.

2. DeviceState no expone variables públicas.

3. DeviceState comienza inválido.

4. DeviceState conserva el último timestamp al invalidarse.

5. DeviceState no interpreta el reloj.

6. DeviceHealth continúa siendo Resource.

7. DeviceHealth comienza HEALTHY.

8. Faults y warnings comienzan vacíos.

9. Faults no aceptan duplicados.

10. Warnings no aceptan duplicados.

11. Los diagnósticos no cambian status automáticamente.

12. Status cambia únicamente mediante set_status().

13. get_faults() devuelve una copia.

14. get_warnings() devuelve una copia.

15. Solo FAILED se considera no operacional.

16. State, Health y Lifecycle permanecen separados.

17. No se conservan aliases para add_waring().

## 15. Estrategia de pruebas

Device Core utilizará pruebas nuevas e independientes.

No se modificarán pruebas anteriores para hacerlas compatibles con los contratos nuevos.

Se crearán:

```text
DeviceIdentityTest

DeviceManifestContractTest

DeviceStateTest

DeviceHealthTest

DeviceLifecycleTest

DeviceCoreContractTest

DistanceSensorInitializationTest

DistanceSensorLifecycleV2Test
```

Cada prueba protegerá una responsabilidad específica.

## 16. DeviceIdentityTest

### Archivos previstos

```text
test/core/device_core/
DeviceIdentityTest.tscn

test/core/device_core/
device_identity_test.gd
```

### DI-U01 — Estado inicial

Debe verificar:

```text
device_id está vacío.

device_type está vacío.

device_version es 1.

is_valid() devuelve false.
```

### DI-U02 — ID sin type

Configurar únicamente:

```text
device_id
```

Debe verificar:

```text
is_valid() devuelve false.
```

### DI-U03 — Type sin ID

Configurar únicamente:

```text
device_type
```

Debe verificar:

```text
is_valid() devuelve false.
```

### DI-U04 — Version inválida

Configurar:

```text
device_id válido;

device_type válido;

device_version igual a 0.
```

Debe verificar:

```text
is_valid() devuelve false.
```

### DI-U05 — Identidad completa

Configurar todos los campos correctamente.

Debe verificar:

```text
is_valid() devuelve true;

get_device_id() devuelve el ID;

get_device_type() devuelve el type;

get_device_version() devuelve la version.
```

## 17. DeviceManifestContractTest

### Archivos previstos

```text
test/core/device_core/
DeviceManifestContractTest.tscn

test/core/device_core/
device_manifest_contract_test.gd
```

Esta prueba sustituirá:

```text
test/core/message_contract/
DeviceManifestTopicTest.tscn

test/core/message_contract/
device_manifest_topic_test.gd
```

### DM-C01 — Capabilities

Debe verificar:

```text
has_capability() encuentra una capability registrada.

Una capability inexistente devuelve false.
```

### DM-C02 — Topics publicados

Debe verificar:

```text
publishes utiliza Array[StringName].

publishes_topic() encuentra un topic registrado.

Un topic inexistente devuelve false.
```

### DM-C03 — Topics consumidos

Debe verificar:

```text
subscribes utiliza Array[StringName].

subscribes_to() encuentra un topic registrado.

Un topic inexistente devuelve false.
```

### DM-C04 — Requirements

Debe verificar:

```text
has_requirement() encuentra un requirement.

Un requirement inexistente devuelve false.
```

### DM-C05 — API anterior retirada

Debe verificar que DeviceManifest no exponga:

```gdscript
has_requirements()
```

y que sí exponga:

```gdscript
has_requirement()
```

## 18. DeviceStateTest

### Archivos previstos

```text
test/core/device_core/
DeviceStateTest.tscn

test/core/device_core/
device_state_test.gd
```

### DS-U01 — Estado inicial

Debe verificar:

```text
is_valid() devuelve false.

get_last_update_time() devuelve 0.0.
```

### DS-U02 — Validar

Después de:

```gdscript
validate()
```

debe verificar:

```text
is_valid() devuelve true.
```

### DS-U03 — Timestamp

Después de:

```gdscript
update_timestamp(25.5)
```

debe verificar:

```text
get_last_update_time() devuelve 25.5.
```

### DS-U04 — Invalidar

Después de validar, actualizar timestamp e invalidar:

```text
is_valid() devuelve false.

get_last_update_time() continúa devolviendo 25.5.
```

La invalidación no elimina el tiempo anterior.

## 19. DeviceHealthTest

### Archivos previstos

```text
test/core/device_core/
DeviceHealthTest.tscn

test/core/device_core/
device_health_test.gd
```

### DH-U01 — Estado inicial

Debe verificar:

```text
get_status() devuelve HEALTHY.

has_faults() devuelve false.

has_warnings() devuelve false.

is_operational() devuelve true.
```

### DH-U02 — Status explícito

Debe verificar:

```text
DEGRADED es operacional.

CRITICAL es operacional.

FAILED no es operacional.
```

### DH-U03 — Faults

Debe verificar:

```text
add_fault() añade un fault.

El mismo fault no se duplica.

has_faults() devuelve true.

remove_fault() elimina el fault.

Eliminar un fault inexistente es seguro.
```

### DH-U04 — Warnings

Debe verificar:

```text
add_warning() añade un warning.

El mismo warning no se duplica.

has_warnings() devuelve true.

remove_warning() elimina el warning.

Eliminar un warning inexistente es seguro.
```

### DH-U05 — Copias independientes

Debe verificar:

```text
get_faults() devuelve un Array nuevo.

get_warnings() devuelve un Array nuevo.

Modificar las copias no cambia el estado interno.
```

### DH-U06 — Política explícita

Debe verificar:

```text
Añadir un fault no cambia status.

Añadir un warning no cambia status.

Eliminar diagnósticos no cambia status.
```

### DH-U07 — API anterior retirada

Debe verificar que DeviceHealth no exponga:

```gdscript
add_waring()
```

y que sí exponga:

```gdscript
add_warning()
```

## 20. DeviceLifecycleTest

### Archivos previstos

```text
test/core/device_core/
DeviceLifecycleTest.tscn

test/core/device_core/
device_lifecycle_test.gd
```

### DL-U01 — Tipo

Debe verificar:

```text
DeviceLifecycle es RefCounted.

DeviceLifecycle no es Node.
```

La comprobación de tipos incompatibles utilizará una variable Variant para evitar errores del analizador estático.

### DL-U02 — Estado inicial

Debe verificar:

```text
get_state() devuelve CREATED.
```

### DL-U03 — Transiciones válidas

Debe verificar:

```text
initialize() devuelve true.

Estado:
INITIALIZED.

set_ready() devuelve true.

Estado:
READY.

start() devuelve true.

Estado:
RUNNING.

shutdown() devuelve true.

Estado:
SHUTDOWN.
```

### DL-U04 — Transiciones inválidas

En instancias independientes debe verificar:

```text
set_ready() desde CREATED devuelve false.

start() desde CREATED devuelve false.

start() desde INITIALIZED devuelve false.

initialize() por segunda vez devuelve false.

set_ready() por segunda vez devuelve false.

start() por segunda vez devuelve false.
```

Ningún fallo modifica el estado.

### DL-U05 — Shutdown

Debe verificar:

```text
shutdown() desde CREATED devuelve true.

segunda llamada a shutdown() devuelve false.

Estado permanece SHUTDOWN.
```

## 21. DeviceCoreContractTest

### Archivos previstos

```text
test/core/device_core/
DeviceCoreContractTest.tscn

test/core/device_core/
device_core_contract_test.gd
```

Esta prueba sustituirá:

```text
core/tests/device_core/
DeviceCoreTest.tscn

core/tests/device_core/
device_core_test.gd
```

### DC-U01 — Tipo de Device

Debe verificar:

```text
Device es RefCounted.

Device no es Node.
```

### DC-U02 — Composición

Debe verificar que Device crea:

```text
DeviceIdentity

DeviceManifest

DeviceState

DeviceHealth

DeviceLifecycle
```

Los getters deben devolver siempre las mismas instancias.

### DC-U03 — Identidad inválida

Con Identity inicial:

```text
initialize() devuelve false.

Lifecycle permanece CREATED.
```

### DC-U04 — Identidad válida

Después de configurar:

```text
device_id

device_type

device_version
```

debe verificar:

```text
initialize() devuelve true.

Lifecycle cambia a INITIALIZED.
```

### DC-U05 — Lifecycle delegado

Debe verificar:

```text
set_ready() cambia a READY.

start() cambia a RUNNING.

shutdown() cambia a SHUTDOWN.
```

### DC-U06 — Independencia

Debe verificar:

```text
Device no necesita SceneTree.

Device no tiene Nodes hijos.

Device no contiene DeviceBus.
```

La ausencia de DeviceBus se confirmará mediante API y revisión de dependencias.

## 22. DistanceSensorLifecycleV2Test

### Archivos previstos

```text
test/core/device/
DistanceSensorLifecycleV2Test.tscn

test/core/device/
distance_sensor_lifecycle_v2_test.gd
```

Esta prueba sustituirá:

```text
test/core/device/
DistanceSensorLifecycleTest.tscn

test/core/device/
distance_sensor_lifecycle_test.gd
```

### DSL2-I01 — Device RefCounted

Debe verificar:

```text
DistanceSensorDevice crea un Device.

Device es RefCounted.

Device no es Node.

Device no se añade como hijo del Sensor.
```

### DSL2-I02 — Lifecycle canónico

Debe verificar mediante:

```gdscript
DeviceLifecycle.State
```

la secuencia:

```text
INITIALIZED

READY

RUNNING

SHUTDOWN
```

### DSL2-I03 — Integraciones existentes

Después de la migración deberán ejecutarse nuevamente:

```text
DistanceSensorMessageTest

DistanceSensorPhysicsIntegrationTest
```

No se modificarán esas pruebas.

### DSL2-I04 — Liberación de dependencias

Después de un shutdown correcto debe verificar:

```text
Device permanece disponible.

Lifecycle se encuentra en SHUTDOWN.

device_bus es null.

distance_provider es null.
```

Una llamada posterior a `publish_measurement()` no debe publicar mensajes.

## 23. Orden de migración

La implementación seguirá este orden:

```text
1. Crear DeviceIdentityTest.

2. Ejecutar DeviceIdentityTest.

3. Implementar has_requirement()
   en DeviceManifest.

4. Crear y ejecutar DeviceManifestContractTest.

5. Declarar DeviceManifestTopicTest como SUPERADA.

6. Implementar DeviceState.

7. Crear y ejecutar DeviceStateTest.

8. Implementar DeviceHealth.

9. Crear y ejecutar DeviceHealthTest.

10. Implementar DeviceLifecycle con nombre canónico.

11. Implementar Device como RefCounted.

12. Eliminar add_child(device)
	de DistanceSensorDevice.
	
13. Implementar inicialización transaccional
	en DistanceSensorDevice.

14. Implementar liberación de DeviceBus
	y Provider durante shutdown().

15. Crear y ejecutar
	DistanceSensorInitializationTest.

16. Crear y ejecutar DeviceLifecycleTest.

17. Crear y ejecutar DeviceCoreContractTest.

18. Crear y ejecutar DistanceSensorLifecycleV2Test.

19. Ejecutar DistanceSensorMessageTest.

20. Ejecutar DistanceSensorPhysicsIntegrationTest.

21. Declarar pruebas anteriores como SUPERADAS.

22. Retirar APIs, clases y pruebas anteriores.

23. Actualizar engineering_standars.md.

24. Ejecutar regresión completa.

25. Registrar resultados.
```

Los pasos 10, 11 y 12 forman una migración coordinada.

No debe renombrarse DeviceLifecycle sin actualizar Device y DistanceSensorDevice dentro del mismo checkpoint.

## 24. Pruebas anteriores

### DeviceManifestTopicTest

Archivo:

```text
test/core/message_contract/
DeviceManifestTopicTest.tscn

test/core/message_contract/
device_manifest_topic_test.gd
```

Será sustituida por:

```text
test/core/device_core/
DeviceManifestContractTest
```

### DeviceCoreTest

Carpeta:

```text
core/tests/device_core/
```

Será sustituida por:

```text
test/core/device_core/
DeviceCoreContractTest
```

### DistanceSensorLifecycleTest

Archivos:

```text
test/core/device/
DistanceSensorLifecycleTest.tscn

test/core/device/
distance_sensor_lifecycle_test.gd
```

Será sustituida por:

```text
test/core/device/
DistanceSensorLifecycleV2Test
```

Las pruebas anteriores no serán modificadas.

Después de aprobar las sucesoras:

- serán declaradas SUPERADAS;
- serán retiradas del árbol activo;
- permanecerán disponibles en Git.

## 25. Actualización de estándares

### Archivo que deberá modificarse después de las pruebas

```text
docs/engineering_standars.md
```

La lista que mezcla lifecycle y health será sustituida por dos grupos.

### Lifecycle

```text
CREATED

INITIALIZED

READY

RUNNING

SHUTDOWN
```

### Health

```text
HEALTHY

DEGRADED

CRITICAL

FAILED
```

Warnings y faults serán diagnósticos.

No serán estados de lifecycle.

Este documento no se modificará antes de verificar el código.

## 26. Criterios de aceptación

Device Core satisface el diseño cuando:

1. Device hereda de RefCounted.

2. DeviceLifecycle hereda de RefCounted.

3. Device utiliza DeviceLifecycle.

4. Device no contiene Nodes hijos.

5. Device compone cinco componentes internos.

6. Los componentes se exponen mediante getters.

7. Identity inválida bloquea initialize().

8. DeviceManifest utiliza has_requirement().

9. DeviceState encapsula su estado.

10. DeviceHealth registra faults correctamente.

11. DeviceHealth utiliza add_warning().

12. DeviceHealth devuelve copias de diagnósticos.

13. Lifecycle y Health permanecen separados.

14. DistanceSensorDevice no añade Device como hijo.

15. Las pruebas sucesoras terminan correctamente.

16. Las pruebas anteriores son retiradas.

17. engineering_standars.md refleja la separación.

18. La regresión completa termina correctamente.

19. DistanceSensorDevice rechaza sensor_id vacío.

20. DistanceSensorDevice inicializa de forma transaccional.

21. Una inicialización fallida no conserva referencias.

22. Un shutdown correcto libera DeviceBus y Provider.

## 27. Fuera de alcance

La implementación no añadirá:

- DeviceGraph;
- DeviceRuntime;
- DeviceBus dentro de Device;
- ProfileSystem;
- restart;
- recuperación automática;
- severidad de diagnósticos;
- políticas automáticas de Health;
- serialización;
- telemetría;
- persistencia.

## 29. Resumen de migración

```text
Device:
Node → RefCounted

DeviceLifecycle:
Node → RefCounted

DeviceLifeCycle:
→ DeviceLifecycle

Device internals:
Públicos → privados por convención

Device.initialize():
Delegación directa
→ validación de Identity

DeviceManifest:
has_requirements()
→ has_requirement()

DeviceState:
Campos públicos
→ estado encapsulado

DeviceHealth:
add_fault() defectuoso
→ registro único

add_waring()
→ add_warning()

Health y Lifecycle:
Separados

DistanceSensorDevice:
add_child(device)
→ referencia RefCounted

Pruebas:
Sucesoras antes de retirar contratos
```

## 28. Inicialización y cierre de DistanceSensorDevice

### 29.1 Validación inicial

Antes de crear Device se comprobará:

```gdscript
if device != null:
	return false

if sensor_id.is_empty():
	return false

if bus == null:
	return false

if provider == null:
	return false