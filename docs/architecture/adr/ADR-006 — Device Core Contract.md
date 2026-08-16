# ADR-006 — Device Core Contract

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.1 |
| Fecha | 2026-08-15 |
| Componentes | Device, Identity, Manifest, State, Health, Lifecycle |
| Alcance | Modelo interno común de los Devices |

## 1. Contexto

Velocity modela sensores, actuadores, controladores y otros elementos funcionales como Devices.

El Device actual está compuesto por:

- DeviceIdentity;
- DeviceManifest;
- DeviceState;
- DeviceHealth;
- DeviceLifeCycle.

La implementación actual hereda de Node y añade DeviceLifeCycle como hijo.

Sin embargo, Device Core no utiliza:

- posición;
- SceneTree;
- procesamiento por frame;
- input;
- renderizado;
- física;
- notificaciones de Node.

Los Devices especializados ligados a Godot, como DistanceSensorDevice, ya pueden actuar como Nodes y conservar un Device interno.

Velocity necesita estabilizar el contrato de Device antes de diseñar DeviceGraph.

## 2. Problema

La implementación actual presenta los siguientes problemas:

- Device depende innecesariamente de Node;
- DeviceLifeCycle depende innecesariamente de Node;
- el estado interno se expone como variables públicas y getters;
- Device.initialize() no valida DeviceIdentity;
- DeviceHealth.add_fault() elimina en lugar de añadir;
- DeviceHealth.add_waring() contiene un error de nombre;
- DeviceManifest.has_requirements() utiliza plural para una consulta singular;
- DeviceLifeCycle utiliza un nombre no canónico;
- los estándares mezclan lifecycle y health;
- la prueba DeviceCoreTest solo imprime resultados;
- varias pruebas dependen de contratos que serán reemplazados.

Modificar estos elementos por separado produciría parches y contratos inconsistentes.

## 3. Decisión general

Device Core será un modelo lógico independiente del árbol de escenas.

Device heredará de:

```gdscript
RefCounted
```

Device compondrá:

```text
DeviceIdentity

DeviceManifest

DeviceState

DeviceHealth

DeviceLifecycle
```

Los Devices especializados podrán continuar siendo Nodes cuando necesiten integración con Godot.

La relación será composición, no herencia.

## 4. Device

Forma prevista:

```gdscript
extends RefCounted
class_name Device
```

Device tendrá una única responsabilidad:

> Reunir y coordinar los componentes comunes que definen a un Device.

Device no:

- participa en SceneTree;
- procesa frames;
- recibe input;
- accede a física;
- publica mensajes;
- conoce DeviceBus;
- conoce Providers;
- controla presentación;
- registra telemetría.

## 5. Composición interna

Device creará durante `_init()`:

```text
DeviceIdentity

DeviceManifest

DeviceState

DeviceHealth

DeviceLifecycle
```

Estado interno previsto:

```gdscript
var _identity: DeviceIdentity
var _manifest: DeviceManifest
var _state: DeviceState
var _health: DeviceHealth
var _lifecycle: DeviceLifecycle
```

Device no permitirá sustituir estos componentes después de construirse.

La API de acceso será:

```gdscript
get_identity() -> DeviceIdentity

get_manifest() -> DeviceManifest

get_state() -> DeviceState

get_health() -> DeviceHealth

get_lifecycle() -> DeviceLifecycle
```

No se conservarán variables públicas duplicando los getters.

## 6. Configuración y estado de ejecución

Los componentes se dividen en dos grupos.

### 6.1 Configuración

```text
DeviceIdentity

DeviceManifest
```

Se configuran antes de `initialize()`.

Después de una inicialización correcta deben tratarse como configuración estable.

### 6.2 Estado de ejecución

```text
DeviceState

DeviceHealth

DeviceLifecycle
```

Pueden cambiar durante la ejecución mediante sus APIs públicas.

## 7. DeviceIdentity

DeviceIdentity continuará heredando de:

```gdscript
Resource
```

Conservará:

```text
device_id: String

device_type: String

device_version: int
```

La identidad será válida cuando:

```text
device_id no esté vacío;

device_type no esté vacío;

device_version sea mayor que cero.
```

Device.initialize() deberá validar DeviceIdentity antes de cambiar lifecycle.

Si la identidad es inválida:

```text
initialize() devuelve false;

Lifecycle permanece CREATED.
```

ADR-006 no cambia todavía los tipos de los campos de identidad.

## 8. DeviceManifest

DeviceManifest continuará heredando de:

```gdscript
Resource
```

Conservará:

```text
capabilities: Array[String]

publishes: Array[StringName]

subscribes: Array[StringName]

requirements: Array[String]
```

La consulta singular será:

```gdscript
func has_requirement(
	requirement: String
) -> bool
```

La API anterior:

```gdscript
has_requirements()
```

será retirada después de crear una prueba sucesora.

No se mantendrá como alias permanente.

## 9. DeviceState

DeviceState continuará heredando de:

```gdscript
Resource
```

Tendrá estado interno:

```gdscript
var _data_valid: bool = false

var _last_update_time: float = 0.0
```

API:

```gdscript
validate() -> void

invalidate() -> void

update_timestamp(time: float) -> void

is_valid() -> bool

get_last_update_time() -> float
```

Responsabilidad:

> Representar la validez y el tiempo de actualización de los datos del Device.

DeviceState no representa:

- lifecycle;
- health;
- identidad;
- estado de una escena.

## 10. DeviceHealth

DeviceHealth continuará heredando de:

```gdscript
Resource
```

Estados:

```gdscript
enum Status {
	HEALTHY,
	DEGRADED,
	CRITICAL,
	FAILED
}
```

Estado interno:

```gdscript
var _status: Status = Status.HEALTHY

var _faults: Array[String] = []

var _warnings: Array[String] = []
```

API:

```gdscript
set_status()

get_status()

add_fault()

remove_fault()

add_warning()

remove_warning()

get_faults()

get_warnings()

has_faults()

has_warnings()

is_operational()
```

Los faults y warnings no aceptarán duplicados.

`get_faults()` y `get_warnings()` devolverán Arrays nuevos.

No expondrán las listas internas.

## 11. Política de Health

Status, faults y warnings serán conceptos relacionados, pero independientes.

Añadir un warning no modificará automáticamente status.

Añadir un fault no modificará automáticamente status.

Eliminar diagnósticos tampoco cambiará status.

El componente o política responsable utilizará:

```gdscript
set_status()
```

para cambiar la condición operacional.

Esta decisión evita asumir severidad o impacto sin un contrato explícito.

`is_operational()` devolverá `false` únicamente cuando:

```text
status == FAILED
```

## 12. DeviceLifecycle

La clase utilizará el nombre canónico:

```gdscript
DeviceLifecycle
```

Forma:

```gdscript
extends RefCounted
class_name DeviceLifecycle
```

El nombre anterior:

```gdscript
DeviceLifeCycle
```

será retirado después de crear pruebas sucesoras.

DeviceLifecycle no utilizará Node ni SceneTree.

## 13. Estados de Lifecycle

Se utilizarán:

```gdscript
enum State {
	CREATED,
	INITIALIZED,
	READY,
	RUNNING,
	SHUTDOWN
}
```

Transiciones válidas:

```text
CREATED
	↓ initialize()
INITIALIZED
	↓ set_ready()
READY
	↓ start()
RUNNING
	↓ shutdown()
SHUTDOWN
```

Reglas:

```text
initialize():
solo desde CREATED.

set_ready():
solo desde INITIALIZED.

start():
solo desde READY.

shutdown():
desde cualquier estado distinto de SHUTDOWN.

segunda llamada a shutdown():
devuelve false.
```

No se implementará restart en esta versión.

## 14. Separación entre Lifecycle y Health

Lifecycle responde:

> ¿En qué etapa operacional se encuentra el Device?

Health responde:

> ¿En qué condición se encuentra el Device?

Ejemplo:

```text
Lifecycle:
RUNNING

Health:
DEGRADED
```

Los estados:

```text
WARNING

DEGRADED

FAULT
```

no formarán parte de DeviceLifecycle.

Pertenecen al dominio de Health y diagnóstico.

El documento `engineering_standars.md` deberá actualizarse para reflejar esta separación.

## 15. Device.initialize()

Device.initialize() tendrá el siguiente comportamiento:

```gdscript
func initialize() -> bool:

	if not _identity.is_valid():
		return false

	return _lifecycle.initialize()
```

Device no validará automáticamente:

- capabilities;
- topics;
- requirements;
- status;
- faults;
- warnings.

Esas políticas no forman parte del contrato actual.

## 16. Relación con DeviceBus

Device Core no tendrá una referencia a DeviceBus.

Un Device especializado o adaptador administrará la comunicación.

Ejemplo:

```text
DistanceSensorDevice
	  │
	  ├──► Device
	  ├──► Provider
	  └──► DeviceBus
```

La capacidad de interactuar con DeviceBus no implica propiedad directa dentro de Device Core.

## 17. Devices especializados

Los Devices especializados utilizarán composición.

Ejemplo:

```text
DistanceSensorDevice
		│
		└──► Device
```

DistanceSensorDevice continuará siendo Node porque participa en una escena y puede coordinar integración con Godot.

Su Device interno será RefCounted.

Después de la migración, DistanceSensorDevice no ejecutará:

```gdscript
add_child(device)
```

Conservará una referencia:

```gdscript
var device: Device
```

### 17.1 Inicialización transaccional

Un Device especializado no debe conservar estado parcial cuando la inicialización falla.

DistanceSensorDevice deberá:

1. validar las dependencias;

2. validar que `sensor_id` no esté vacío;

3. crear un Device en una variable local;

4. configurar Identity y Manifest en la variable local;

5. ejecutar `initialize()` sobre el Device local;

6. guardar Device, DeviceBus y Provider únicamente si la inicialización termina correctamente.

Modelo:

```text
Validar entradas
	  │
	  ▼
Crear Device local
	  │
	  ▼
Configurar
	  │
	  ▼
Inicializar
	  │
	  ├── fallo ──► descartar Device local
	  │
	  └── éxito ──► conservar referencias
```

Si la inicialización falla:

```text
device permanece null;

device_bus permanece null;

distance_provider permanece null.
```

### 17.2 Liberación durante shutdown

Cuando DistanceSensorDevice realiza un shutdown correcto:

```text
Device permanece disponible para consultar
su estado SHUTDOWN.

DeviceBus se libera.

Provider se libera.
```

Forma conceptual:

```gdscript
var shutdown_result := device.shutdown()

if not shutdown_result:
	return false

device_bus = null
distance_provider = null

return true
```

Después de shutdown, `publish_measurement()` no produce publicaciones porque sus dependencias externas fueron liberadas.

## 18. Alternativas descartadas

### 18.1 Device como Node

Descartado porque Device Core no utiliza capacidades del SceneTree.

### 18.2 Device especializado hereda de Device

Descartado porque mezcla responsabilidades y limita especializaciones ligadas a Godot.

### 18.3 DeviceLifecycle como Node

Descartado porque lifecycle es una máquina de estados sin comportamiento de escena.

### 18.4 Lifecycle y Health combinados

Descartado porque etapa operacional y condición de salud son conceptos diferentes.

### 18.5 Status derivado automáticamente

Pospuesto porque no existe severidad ni política de diagnóstico.

### 18.6 Device contiene DeviceBus

Descartado porque comunicación no pertenece a todos los Devices de la misma forma.

### 18.7 Aliases permanentes

Descartados para:

```text
DeviceLifeCycle

has_requirements()

add_waring()
```

Las APIs anteriores se sustituirán mediante pruebas sucesoras.

## 19. Pruebas sucesoras

Se crearán pruebas nuevas para:

```text
DeviceIdentity

DeviceManifest

DeviceState

DeviceHealth

DeviceLifecycle

Device Core

DistanceSensorDevice con Device RefCounted
```

Las pruebas anteriores no serán editadas para utilizar los contratos nuevos.

## 20. Pruebas anteriores afectadas

### DeviceCoreTest

Ruta:

```text
core/tests/device_core/
```

Depende de Device como Node y solo imprime resultados.

Será sustituida y retirada.

### DeviceManifestTopicTest

Ruta:

```text
test/core/message_contract/
```

Utiliza `has_requirements()`.

Será sustituida antes de retirar la API.

### DistanceSensorLifecycleTest

Ruta:

```text
test/core/device/
```

Utiliza `DeviceLifeCycle`.

Será sustituida antes de renombrar la clase.

## 21. Consecuencias

### 21.1 Positivas

- Device Core independiente de SceneTree;
- pruebas puras;
- identidad validada;
- lifecycle independiente;
- health funcional;
- estado encapsulado;
- nomenclatura consistente;
- composición explícita;
- base estable para DeviceGraph.

### 21.2 Negativas

- se sustituyen pruebas recientes;
- cambia el nombre DeviceLifeCycle;
- se retiran APIs anteriores;
- DistanceSensorDevice debe migrarse;
- se requiere una migración coordinada.

Estas consecuencias son aceptadas.

## 22. Invariantes

1. Device hereda de RefCounted.

2. Device no participa en SceneTree.

3. Device compone sus componentes internos.

4. Los componentes internos se exponen mediante getters.

5. Identity y Manifest se configuran antes de initialize().

6. Device.initialize() valida Identity.

7. Una identidad inválida no cambia lifecycle.

8. DeviceState representa validez y timestamp.

9. DeviceHealth representa condición y diagnósticos.

10. DeviceLifecycle representa etapa operacional.

11. Lifecycle y Health permanecen separados.

12. Device Core no conoce DeviceBus.

13. Devices especializados utilizan composición.

14. Faults y warnings no aceptan duplicados.

15. Status cambia explícitamente.

16. Las pruebas anteriores se sustituyen antes de retirar APIs.

17. Los Devices especializados inicializan de forma transaccional.

18. Una inicialización fallida no conserva referencias parciales.

19. Un shutdown correcto libera dependencias externas.

## 23. Criterios de aceptación

La implementación satisface ADR-006 cuando:

1. Device hereda de RefCounted;

2. DeviceLifecycle hereda de RefCounted;

3. Device utiliza el nombre canónico DeviceLifecycle;

4. Device no ejecuta add_child();

5. DistanceSensorDevice no añade Device al SceneTree;

6. los componentes internos de Device son privados por convención;

7. Device.initialize() rechaza identidad inválida;

8. DeviceManifest utiliza has_requirement();

9. DeviceState encapsula sus campos;

10. DeviceHealth añade y elimina faults correctamente;

11. DeviceHealth utiliza add_warning();

12. Lifecycle y Health tienen pruebas independientes;

13. Device Core tiene una prueba sucesora;

14. DistanceSensorDevice tiene prueba sucesora;

15. las pruebas anteriores son retiradas después de sustitución;

16. la regresión completa termina correctamente.

17. DistanceSensorDevice rechaza sensor_id vacío.

18. DistanceSensorDevice no conserva estado parcial después de un fallo.

19. DistanceSensorDevice libera DeviceBus y Provider durante shutdown.

## 24. Fuera de alcance

ADR-006 no implementará:

- DeviceGraph;
- DeviceRuntime;
- ProfileSystem;
- telemetría;
- persistencia;
- serialización;
- restart;
- severidad de faults;
- recuperación automática;
- sincronización de tiempo;
- networking.

## 25. Regla de evolución

Una capacidad nueva no se añadirá directamente a Device si pertenece a:

- comunicación;
- telemetría;
- persistencia;
- presentación;
- física;
- hardware;
- scheduling.

Device debe permanecer como un modelo común pequeño.

Los Devices especializados y componentes externos añadirán comportamiento mediante composición.