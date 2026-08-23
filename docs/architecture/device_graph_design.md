# DeviceGraph — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 18/08/2026 |
| ADR relacionado | ADR-002 — DeviceGraph |
| Alcance | Topología lógica para Devices ideales |

## 1. Propósito

Este documento traduce ADR-002 a un diseño concreto e implementable.

La primera versión define:

- PortSemanticKinds;
- DeviceGraphInputPort;
- DeviceGraphOutputPort;
- DeviceGraphTopicChannel;
- DeviceGraphConnection;
- DeviceGraphNode;
- generación inicial de Ports;
- DeviceGraphDraft;
- DeviceGraphSnapshot;
- validación;
- mutaciones transaccionales;
- pruebas.

DeviceGraph 1.0 trabaja con:

- DeviceProfile snapshots;
- DeviceConfiguration snapshots;
- DeviceManifest efectivo;
- Devices ideales;
- datos y comandos;
- DeviceBus como transporte runtime futuro.

## 2. Estructura propuesta

### 2.1 Código

```text
core/graph/
├── port_semantic_kinds.gd
├── device_graph_input_port.gd
├── device_graph_output_port.gd
├── device_graph_topic_channel.gd
├── device_graph_connection.gd
├── device_graph_node.gd
├── device_graph_node_build_result.gd
├── device_graph_node_builder.gd
├── device_graph_draft.gd
├── device_graph_snapshot.gd
└── device_graph_snapshot_result.gd
```

### 2.2 Pruebas

```text
test/core/device_graph/
```

### 2.3 Dependencias permitidas

```text
DeviceRoles

DeviceProfile

DeviceConfiguration

DeviceManifest

ValidationIssue

ValidationReport

BusTopics
```

### 2.4 Dependencias no permitidas

```text
SceneTree

DeviceBus runtime

GraphEditor

SystemProfile persistence

hardware

telemetría

Godot visual Nodes
```

## 3. Terminología

### DeviceGraphNode

Representación lógica de una instancia.

No es un Node de Godot.

### InputPort

Entrada lógica declarada por un Device.

### OutputPort

Salida lógica declarada por un Device.

### TopicChannel

Representación lógica de un Topic de DeviceBus.

### Connection

Relación lógica:

```text
OutputPort

→ TopicChannel →

InputPort
```

### DeviceGraphDraft

Topología editable mediante API controlada.

### DeviceGraphSnapshot

Topología validada e inmutable.

## 4. PortSemanticKinds

### 4.1 Archivo previsto

```text
core/graph/port_semantic_kinds.gd
```

### 4.2 Forma

```gdscript
extends RefCounted
class_name PortSemanticKinds
```

### 4.3 Identidades

```gdscript
const UNSPECIFIED: StringName = (
	&"unspecified"
)

const MEASUREMENT: StringName = (
	&"measurement"
)

const COMMAND: StringName = (
	&"command"
)

const SETPOINT: StringName = (
	&"setpoint"
)

const RESULT: StringName = (
	&"result"
)

const STATE: StringName = (
	&"state"
)

const HEALTH: StringName = (
	&"health"
)

const EVENT: StringName = (
	&"event"
)
```

### 4.4 API

```gdscript
static func is_valid(
	kind: StringName
) -> bool
```

```gdscript
static func get_all(
) -> Array[StringName]
```

### 4.5 UNSPECIFIED

La primera implementación no tiene todavía un TopicContractRegistry.

Los Ports generados únicamente desde DeviceManifest podrán utilizar:

```text
UNSPECIFIED
```

hasta que exista un contrato canónico de semántica por Topic.

UNSPECIFIED no significa inválido.

Significa:

```text
Semantic Kind todavía no especificado.
```

### 4.6 Compatibilidad inicial

Regla inicial:

```text
Si ambos Kinds son específicos:
deben ser iguales.

Si uno o ambos son UNSPECIFIED:
la compatibilidad se decide por Topic.
```

Esto evita inferir semántica mediante nombres como `_measurement` o `_command`.

## 5. DeviceGraphInputPort

### 5.1 Archivo previsto

```text
core/graph/device_graph_input_port.gd
```

### 5.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphInputPort
```

### 5.3 Estado

```gdscript
var _port_id: StringName

var _device_id: String

var _topic: StringName

var _semantic_kind: StringName
```

### 5.4 Construcción

Todos los valores se reciben durante `_init()`.

DeviceGraphInputPort será inmutable por contrato.

### 5.5 API

```gdscript
get_port_id() -> StringName

get_device_id() -> String

get_topic() -> StringName

get_semantic_kind() -> StringName

is_valid() -> bool
```

### 5.6 Validación

Debe cumplirse:

```text
port_id no vacío;

device_id no vacío;

topic no vacío;

semantic_kind válido.
```

### 5.7 Responsabilidad

InputPort representa:

> Este Device puede consumir este Topic.

No contiene:

- Callable;
- referencia a Device;
- mensajes;
- queue;
- configuración visual;
- posición.

## 6. DeviceGraphOutputPort

### 6.1 Archivo previsto

```text
core/graph/device_graph_output_port.gd
```

### 6.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphOutputPort
```

### 6.3 Estado

```gdscript
var _port_id: StringName

var _device_id: String

var _topic: StringName

var _semantic_kind: StringName
```

### 6.4 Construcción

Todos los valores se reciben durante `_init()`.

DeviceGraphOutputPort será inmutable por contrato.

### 6.5 API

```gdscript
get_port_id() -> StringName

get_device_id() -> String

get_topic() -> StringName

get_semantic_kind() -> StringName

is_valid() -> bool
```

### 6.6 Validación

Debe cumplirse:

```text
port_id no vacío;

device_id no vacío;

topic no vacío;

semantic_kind válido.
```

### 6.7 Responsabilidad

OutputPort representa:

> Este Device puede publicar este Topic.

No publica por sí mismo.

No contiene referencia a DeviceBus.

## 7. Port IDs

La primera generación automática utilizará IDs deterministas.

### Input

```text
in.<topic>
```

Ejemplo:

```text
in.distance_measurement
```

### Output

```text
out.<topic>
```

Ejemplo:

```text
out.distance_measurement
```

El formato se utiliza únicamente como identidad del Port dentro del Device.

No es un Topic.

No es una ruta de escena.

### Limitación inicial

Un DeviceManifest contiene cada Topic una sola vez.

Por tanto, la primera versión genera un Port por:

```text
direction + topic
```

Named slots como:

```text
front_left_distance

front_right_distance
```

se añadirán cuando Configuration y Profile expongan metadata de Ports especializados.

### Separador reservado

DeviceGraph utilizará:

```text
|```

## 8. DeviceGraphTopicChannel

### 8.1 Archivo previsto

```text
core/graph/device_graph_topic_channel.gd
```

### 8.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphTopicChannel
```

### 8.3 Estado

```gdscript
var _topic: StringName
```

### 8.4 API

```gdscript
get_topic() -> StringName

is_valid() -> bool
```

### 8.5 Identidad

TopicChannel se identifica por el mismo StringName del Topic.

Dentro de un Graph existe como máximo un TopicChannel por Topic.

### 8.6 Responsabilidad

TopicChannel representa el canal lógico.

No:

- publica;
- almacena mensajes;
- conserva Subscribers;
- conoce DeviceBus;
- interpreta payloads.

## 9. DeviceGraphConnection

### 9.1 Archivo previsto

```text
core/graph/device_graph_connection.gd
```

### 9.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphConnection
```

### 9.3 Estado

```gdscript
var _connection_id: StringName

var _source_device_id: String

var _source_port_id: StringName

var _topic: StringName

var _target_device_id: String

var _target_port_id: StringName
```

### 9.4 API

```gdscript
get_connection_id() -> StringName

get_source_device_id() -> String

get_source_port_id() -> StringName

get_topic() -> StringName

get_target_device_id() -> String

get_target_port_id() -> StringName

is_valid_identity() -> bool
```

### 9.5 Validación de identidad

Debe cumplirse:

```text
connection_id no vacío;

source_device_id no vacío;

source_port_id no vacío;

topic no vacío;

target_device_id no vacío;

target_port_id no vacío.
```

La compatibilidad con Graph pertenece a DeviceGraphValidator o DeviceGraphDraft.

### 9.6 Inmutabilidad

Connection será inmutable por contrato.

No expondrá setters.

## 10. DeviceGraphNode

### 10.1 Archivo previsto

```text
core/graph/device_graph_node.gd
```

### 10.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphNode
```

### 10.3 Estado

```gdscript
var _device_id: String

var _primary_role: StringName

var _profile: DeviceProfile

var _configuration: DeviceConfiguration

var _manifest: DeviceManifest

var _input_ports: Array[DeviceGraphInputPort]

var _output_ports: Array[DeviceGraphOutputPort]
```

### 10.4 Inmutabilidad

DeviceGraphNode será un snapshot lógico.

No expondrá setters.

Los Arrays se copiarán durante construcción.

Los getters de Ports devolverán Arrays nuevos.

### 10.5 Manifest interno

DeviceManifest actual es mutable.

DeviceGraphNode no conservará directamente el mismo objeto editable recibido.

Durante construcción creará una copia interna de:

- capabilities;
- publishes;
- subscribes;
- requirements.

`get_manifest()` devolverá otra copia.

Esto evita que una modificación externa cambie Ports o interfaz después de crear el Node.

### 10.6 API

```gdscript
get_device_id() -> String

get_primary_role() -> StringName

get_profile() -> DeviceProfile

get_configuration() -> DeviceConfiguration

get_manifest() -> DeviceManifest

get_input_ports() -> Array[DeviceGraphInputPort]

get_output_ports() -> Array[DeviceGraphOutputPort]

get_input_port(
	port_id: StringName
) -> DeviceGraphInputPort

get_output_port(
	port_id: StringName
) -> DeviceGraphOutputPort

is_valid() -> bool
```

### 10.7 Validación

Debe comprobar:

```text
device_id no vacío;

primary_role válido;

Profile válido;

Configuration válida;

Configuration.device_id coincide;

Profile reference coincide;

Manifest no null;

Ports válidos;

Port IDs únicos;

Ports pertenecen al Device;

InputPort topics están en Manifest.subscribes;

OutputPort topics están en Manifest.publishes.
```

## 11. Generación inicial de Ports

Los Ports se generarán desde DeviceManifest.

### InputPorts

Por cada Topic en:

```gdscript
manifest.subscribes
```

se crea:

```text
DeviceGraphInputPort

port_id:
in.<topic>

device_id:
Device ID

topic:
Topic

semantic_kind:
UNSPECIFIED
```

### OutputPorts

Por cada Topic en:

```gdscript
manifest.publishes
```

se crea:

```text
DeviceGraphOutputPort

port_id:
out.<topic>

device_id:
Device ID

topic:
Topic

semantic_kind:
UNSPECIFIED
```

### Orden

Los Ports conservan el orden del Manifest.

No se ordenan alfabéticamente.

### Duplicados

DeviceManifest ya debe estar validado.

Si contiene Topics duplicados, DeviceGraphNodeBuilder producirá error estructural.

## 12. DeviceGraphNodeBuilder

### 12.1 Archivo previsto

```text
core/graph/device_graph_node_builder.gd
```

### 12.2 Responsabilidad

> Construir DeviceGraphNode desde snapshots y Manifest efectivo.

### 12.3 API conceptual

```gdscript
build(
	device_id: String,
	profile: DeviceProfile,
	configuration: DeviceConfiguration,
	manifest: DeviceManifest
) -> DeviceGraphNodeBuildResult
```

### 12.4 Validaciones

Debe comprobar:

- argumentos no null;
- Device ID no vacío;
- Profile válido;
- Configuration válida;
- Device ID coincide;
- Profile ID coincide;
- Profile version coincide;
- Device ID no contiene el separador reservado `|`;
- Port IDs generados no contienen el separador reservado.
- Primary Role válido;
- Manifest no contiene duplicados;
- Ports generados son válidos.

Si Device ID contiene el separador:

```text
STRUCTURAL_ERROR

code:
graph_id_contains_reserved_separator```

### 12.5 Resultado

Produce:

```text
DeviceGraphNode

ValidationReport
```

No modifica los argumentos.

## 13. DeviceGraphNodeBuildResult

### 13.1 Archivo previsto

```text
core/graph/device_graph_node_build_result.gd
```

### 13.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphNodeBuildResult
```

### 13.3 Estado

```gdscript
var _node: DeviceGraphNode

var _report: ValidationReport
```

### 13.4 API

```gdscript
get_node() -> DeviceGraphNode

get_report() -> ValidationReport

is_success() -> bool
```

## 14. Invariantes del bloque

1. Graph components son RefCounted.

2. Ningún componente es Godot Node.

3. Ports son inmutables.

4. TopicChannel es inmutable.

5. Connection es inmutable.

6. DeviceGraphNode es inmutable.

7. DeviceGraphNode utiliza snapshots.

8. Manifest interno se copia.

9. Ports derivan del Manifest efectivo.

10. Port ID combina direction y topic.

11. Un Topic genera un Port por dirección.

12. Semantic Kind puede ser UNSPECIFIED.

13. DeviceGraph no infiere Kind por nombre.

14. Connection no contiene referencias directas a Devices.

15. TopicChannel no transporta mensajes.

16. DeviceGraphNodeBuilder produce ValidationReport.

## 15. DeviceGraphOperationResult

### 15.1 Archivo previsto

```text
core/graph/device_graph_operation_result.gd
```

### 15.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphOperationResult
```

### 15.3 Responsabilidad

> Describir el resultado de una mutación solicitada sobre DeviceGraphDraft.

### 15.4 Estado

```gdscript
var _success: bool

var _affected_id: StringName

var _report: ValidationReport
```

`_affected_id` puede representar:

- Device ID convertido a StringName;
- Connection ID;
- TopicChannel;
- ID vacío en fallo.

### 15.5 API

```gdscript
is_success() -> bool

get_affected_id() -> StringName

get_report() -> ValidationReport
```

### 15.6 Inmutabilidad

DeviceGraphOperationResult será inmutable por contrato.

No expondrá setters.

## 16. DeviceGraphDraft

### 16.1 Archivo previsto

```text
core/graph/device_graph_draft.gd
```

### 16.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphDraft
```

### 16.3 Responsabilidad

> Mantener una topología lógica editable mediante operaciones transaccionales.

### 16.4 Estado interno

```gdscript
var _devices_by_id: Dictionary[String, DeviceGraphNode] = {}

var _connections_by_id: Dictionary[StringName, DeviceGraphConnection] = {}

var _topic_channels_by_topic: Dictionary[StringName, DeviceGraphTopicChannel] = {}
```

Los Dictionaries son privados por convención.

### 16.5 API de Devices

```gdscript
add_device(
	node: DeviceGraphNode
) -> DeviceGraphOperationResult
```

```gdscript
remove_device(
	device_id: String
) -> DeviceGraphOperationResult
```

```gdscript
get_device(
	device_id: String
) -> DeviceGraphNode
```

```gdscript
has_device(
	device_id: String
) -> bool
```

```gdscript
get_devices(
) -> Array[DeviceGraphNode]
```

### 16.6 API de Connections

```gdscript
connect(
	source_device_id: String,
	source_port_id: StringName,
	target_device_id: String,
	target_port_id: StringName
) -> DeviceGraphOperationResult
```

```gdscript
disconnect_ports(
	connection_id: StringName
) -> DeviceGraphOperationResult
```

```gdscript
get_connection(
	connection_id: StringName
) -> DeviceGraphConnection
```

```gdscript
has_connection(
	connection_id: StringName
) -> bool
```

```gdscript
get_connections(
) -> Array[DeviceGraphConnection]
```

### 16.7 API de TopicChannels

```gdscript
get_topic_channel(
	topic: StringName
) -> DeviceGraphTopicChannel
```

```gdscript
get_topic_channels(
) -> Array[DeviceGraphTopicChannel]
```

### 16.8 API de validación

```gdscript
validate() -> ValidationReport
```

```gdscript
create_snapshot() -> DeviceGraphSnapshotResult
```

### 16.9 Collections

Todos los getters de colecciones devolverán Arrays nuevos.

Los Dictionaries internos no se exponen.

## 17. Add Device

### 17.1 Validaciones

`add_device()` debe comprobar:

- Node no null;
- Node válido;
- Device ID no vacío;
- Device ID no registrado;
- Profile válido;
- Configuration válida;
- Manifest válido;
- Ports válidos.

### 17.2 Éxito

En éxito:

```text
DeviceNode se registra.

TopicChannels requeridos por sus Ports
se crean si no existen.

OperationResult success true.

affected_id contiene Device ID.
```

### 17.3 Fallo

En fallo:

```text
Graph no cambia.

OperationResult success false.

ValidationReport contiene error.
```

### 17.4 Device ID duplicado

Produce:

```text
STRUCTURAL_ERROR

code:
duplicate_device_id
```

## 18. Remove Device

### 18.1 Política inicial

DeviceGraph 1.0 rechazará eliminar un Device que tenga Connections.

Resultado:

```text
STRUCTURAL_ERROR

code:
device_has_connections
```

La herramienta deberá desconectar primero.

### 18.2 Device inexistente

Produce:

```text
STRUCTURAL_ERROR

code:
device_not_found
```

### 18.3 Éxito

Al eliminar un Device sin Connections:

- se retira DeviceNode;
- se reconstruyen TopicChannels;
- no quedan referencias huérfanas.

### 18.4 Evolución

Una operación futura podrá permitir:

```text
remove_device_with_connections()```

de forma transaccional.

No se implementará en 1.0.

## 19. Connection ID

DeviceGraph generará Connection IDs deterministas.

Separador reservado:

```text
|
```

Formato:

```text
source_device_id
|
source_port_id
|
target_device_id
|
target_port_id
```

Ejemplo:

```text
front_left_sensor
|
out.distance_measurement
|
hover_mcu
|
in.distance_measurement
```

ID final:

```text
front_left_sensor|out.distance_measurement|hover_mcu|in.distance_measurement
```

El ID será convertido a StringName.

### Validación

Ningún componente individual del ID puede contener:

```text
|
```

Si contiene el separador:

```text
STRUCTURAL_ERROR

code:
graph_id_contains_reserved_separator
```

### Propiedades

El ID:

- es reproducible;
- no depende del orden de inserción;
- identifica una Connection source–target concreta;
- permite detectar duplicados;
- no utiliza contador global;
- no utiliza UUID aleatorio.

El caller no proporciona Connection ID.

## 20. Connect

### 20.1 Validaciones

`connect_ports()` debe comprobar:

- Source Device existe;
- Target Device existe;
- Source y Target son diferentes;
- OutputPort existe;
- InputPort existe;
- Ports pertenecen a sus Devices;
- topics coinciden;
- Semantic Kinds son compatibles;
- Connection no existe.

### 20.2 Self Connection

DeviceGraph 1.0 rechazará conexiones donde:

```text
source_device_id == target_device_id
```

Produce:

```text
STRUCTURAL_ERROR

code:
self_connection_not_supported
```

La lógica interna de un Device no se modela como Connection hacia sí mismo.

### 20.3 Topic mismatch

Produce:

```text
STRUCTURAL_ERROR

code:
connection_topic_mismatch
```

### 20.4 Semantic mismatch

Si ambos Kinds son específicos y diferentes:

```text
STRUCTURAL_ERROR

code:
connection_semantic_mismatch
```

Si uno o ambos son UNSPECIFIED:

```text
Topic igual permite conexión.
```

### 20.5 Duplicate Connection

Produce:

```text
STRUCTURAL_ERROR

code:
duplicate_connection
```

### 20.6 Éxito

En éxito:

- se construye DeviceGraphConnection;
- se registra;
- se garantiza TopicChannel;
- se devuelve OperationResult.

No se modifica DeviceBus.

## 21. Disconnect

### 21.1 Connection inexistente

Produce:

```text
STRUCTURAL_ERROR

code:
connection_not_found
```

### 21.2 Éxito

Al desconectar:

- se elimina Connection;
- se reconstruyen TopicChannels;
- Devices y Ports permanecen intactos.

### 21.3 TopicChannels no utilizados

Un TopicChannel que ya no sea utilizado por:

- Ports registrados;
- Connections;

puede retirarse durante reconstrucción.

Como los Ports provienen de DeviceNodes, normalmente el canal permanece mientras exista un Port con ese Topic.

## 22. TopicChannel Registry

DeviceGraphDraft mantendrá un TopicChannel por Topic.

Se reconstruirá a partir de:

- todos los InputPorts;
- todos los OutputPorts;
- todas las Connections.

No se modifica manualmente mediante API pública.

Esto evita canales sin relación con la topología.

## 23. Full Graph Validation

`validate()` comprobará el Graph completo.

### 23.1 Devices

- Node válido;
- Device ID único;
- Profile válido;
- Configuration válida;
- Manifest válido.

### 23.2 Ports

- Port válido;
- Port ID único dentro de Device;
- ownership correcto;
- topic declarado en Manifest.

### 23.3 Connections

- identidad válida;
- Source existente;
- Target existente;
- Ports existentes;
- topic compatible;
- Semantic Kind compatible;
- no duplicados;
- no self-connection.

### 23.4 Ownership

La primera versión comprobará que un DeviceNode no declare dos OutputPorts para el mismo Topic.

DeviceManifest ya debe impedir duplicados.

La validación global de:

```text
Topic + Source ID
```

queda satisfecha inicialmente por:

- Device ID único;
- un OutputPort por Topic dentro del Device.

### 23.5 Inputs sin Connection

Un InputPort sin Connection producirá:

```text
WARNING

code:
input_port_unconnected
```

No será Structural Error porque todavía no existe metadata Required/Optional.

### 23.6 Outputs sin consumidores

Un OutputPort sin Connections producirá:

```text
INFO

code:
output_port_unconnected
```

No bloquea snapshot.

## 24. Cycle Detection

DeviceGraphDraft detectará ciclos dirigidos entre Devices.

### 24.1 Resultado inicial

Como todavía no existe metadata de temporal boundary:

```text
WARNING

code:
cycle_requires_runtime_validation
```

El ciclo se incluye en el ValidationReport.

No bloquea la creación del Graph Snapshot por sí solo.

### 24.2 Responsabilidad futura

CompositionCompiler deberá decidir si el ciclo contiene:

- Physics Frame;
- Scheduler Tick;
- Timer;
- Hardware Sample;
- otra frontera temporal.

Un zero-delay cycle será Platform Safety Error en la fase de compilación runtime.

### 24.3 Razón

DeviceGraph debe representar feedback loops legítimos.

No debe rechazarlos todos sin información temporal suficiente.

## 25. DeviceGraphSnapshot

### 25.1 Archivo previsto

```text
core/graph/device_graph_snapshot.gd
```

### 25.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphSnapshot
```

### 25.3 Estado

```gdscript
var _devices: Array[DeviceGraphNode]

var _connections: Array[DeviceGraphConnection]

var _topic_channels: Array[DeviceGraphTopicChannel]
```

### 25.4 Construcción

Los Arrays se copian durante `_init()`.

Los elementos ya son inmutables por contrato.

### 25.5 API

```gdscript
get_devices() -> Array[DeviceGraphNode]

get_connections() -> Array[DeviceGraphConnection]

get_topic_channels() -> Array[DeviceGraphTopicChannel]

get_device(
	device_id: String
) -> DeviceGraphNode

get_connection(
	connection_id: StringName
) -> DeviceGraphConnection

is_valid() -> bool
```

Los getters devuelven Arrays nuevos.

### 25.6 Inmutabilidad

Snapshot no expone:

- add;
- remove;
- connect;
- disconnect;
- setters.

### 25.7 Snapshot estructural

DeviceGraphSnapshot representa una topología estructuralmente validada.

No es todavía un plan ejecutable.

Antes de utilizarse por runtime deberá pasar por:

```text
CompositionCompiler

## 26. DeviceGraphSnapshotResult

### 26.1 Archivo previsto

```text
core/graph/device_graph_snapshot_result.gd
```

### 26.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphSnapshotResult
```

### 26.3 Estado

```gdscript
var _snapshot: DeviceGraphSnapshot

var _report: ValidationReport
```

### 26.4 API

```gdscript
get_snapshot() -> DeviceGraphSnapshot

get_report() -> ValidationReport

is_success() -> bool
```

### 26.5 Success

`is_success()` devuelve true cuando:

```text
snapshot no es null;

report es válido para Simulation Mode.
```

Warnings e INFO no impiden snapshot.

## 27. Create Snapshot

Flujo:

```text
DeviceGraphDraft

↓

validate()

↓

ValidationReport

↓

si válido para Simulation:

	copiar Devices

	copiar Connections

	copiar TopicChannels

	crear DeviceGraphSnapshot
```

Si existen Structural o Platform Safety Errors:

```text
snapshot:
null
```

Graph Draft permanece intacto.

## 28. Mutaciones transaccionales

Cada mutación:

1. valida argumentos;

2. calcula los cambios;

3. aplica únicamente si todo es válido;

4. reconstruye TopicChannels;

5. devuelve OperationResult.

Una operación fallida no debe:

- añadir parcialmente un Device;
- añadir Connection parcial;
- borrar Channels válidos;
- alterar Collections anteriores.

## 29. Orden determinista

DeviceGraphDraft conservará orden de inserción para:

- Devices;
- Connections;
- TopicChannels.

Los Arrays devueltos respetarán ese orden.

DeviceGraphSnapshot conservará el mismo orden.

Esto facilita:

- pruebas;
- UI;
- serialización futura;
- comparación;
- documentación.

## 30. Invariantes del bloque

1. Graph Draft es mutable solo mediante API.

2. Graph Snapshot es inmutable.

3. Device ID es único.

4. Connection ID es determinista.

5. Self-connections se rechazan en 1.0.

6. Topic mismatch se rechaza.

7. Semantic mismatch específico se rechaza.

8. UNSPECIFIED permite validación por Topic.

9. Duplicate Connection se rechaza.

10. Device con Connections no se elimina.

11. TopicChannels se derivan de topología.

12. Inputs desconectados producen WARNING.

13. Outputs desconectados producen INFO.

14. Cycles producen WARNING inicial.

15. Snapshot permite warnings.

16. Snapshot bloquea Structural y Platform errors.

17. Collections devueltas son copias.

18. Operaciones fallidas son transaccionales.

19. Orden de inserción es determinista.

20. DeviceGraph no toca DeviceBus.

21. Connection ID utiliza separador reservado.

22. Device IDs y Port IDs no contienen `|`.

23. GraphSnapshot representa topología,
	no ejecución.

24. Runtime requiere CompositionCompiler.

25. Tests no modifican collections privadas.

## 31. Estrategia de pruebas

DeviceGraph utilizará pruebas nuevas e independientes.

Suites previstas:

```text
PortSemanticKindsTest

DeviceGraphPrimitivesTest

DeviceGraphNodeBuilderTest

DeviceGraphDraftDeviceTest

DeviceGraphConnectionTest

DeviceGraphValidationTest

DeviceGraphSnapshotTest
```

Cada prueba utilizará:

- DeviceProfiles válidos;
- DeviceConfigurations válidas;
- DeviceManifests efectivos;
- objetos nuevos;
- ValidationReports independientes.

DeviceGraph no utilizará DeviceBus durante estas pruebas.

## 32. Fixtures de prueba

Las pruebas necesitarán Profiles ideales adicionales.

No se añadirán inmediatamente a BuiltinDeviceProfiles de producción.

Los tests podrán construir snapshots directamente para:

```text
Ideal Sensor

Ideal Local Controller

Ideal Actuator

Ideal Supervisory Controller
```

Los Profiles de prueba utilizarán namespace:

```text
test.
```

Ejemplos:

```text
test.distance_sensor

test.hover_mcu

test.hover_thruster

test.fcc
```

Las Configurations utilizarán IDs de instancia únicos.

Los Manifests se construirán mediante DeviceManifestBuilder cuando sea posible.

No se utilizarán Dictionaries genéricos para representar Devices.

## 33. PortSemanticKindsTest

### Archivos previstos

```text
test/core/device_graph/
PortSemanticKindsTest.tscn

test/core/device_graph/
port_semantic_kinds_test.gd
```

Debe verificar:

```text
UNSPECIFIED es StringName.

MEASUREMENT es StringName.

COMMAND es StringName.

SETPOINT es StringName.

RESULT es StringName.

STATE es StringName.

HEALTH es StringName.

EVENT es StringName.

Los valores utilizan lower_snake_case.

is_valid() acepta Kinds canónicos.

is_valid() rechaza vacío.

is_valid() rechaza desconocido.

get_all() contiene todos.

get_all() devuelve Array independiente.
```

## 34. DeviceGraphPrimitivesTest

### Archivos previstos

```text
test/core/device_graph/
DeviceGraphPrimitivesTest.tscn

test/core/device_graph/
device_graph_primitives_test.gd
```

### InputPort

Debe verificar:

- construcción válida;
- getters;
- semantic kind;
- identity inválida;
- no setters.

### OutputPort

Debe verificar:

- construcción válida;
- getters;
- semantic kind;
- identity inválida;
- no setters.

### TopicChannel

Debe verificar:

- topic válido;
- topic vacío inválido;
- getter;
- no setters.

### Connection

Debe verificar:

- identity válida;
- getters;
- campos obligatorios;
- no setters.

No verifica compatibilidad con Graph.

## 35. DeviceGraphNodeBuilderTest

### Archivos previstos

```text
test/core/device_graph/
DeviceGraphNodeBuilderTest.tscn

test/core/device_graph/
device_graph_node_builder_test.gd
```

Debe verificar:

### Argumentos nulos

```text
Profile null.

Configuration null.

Manifest null.
```

Produce:

```text
Node null.

STRUCTURAL_ERROR.
```

### Device ID vacío

Produce:

```text
Node null.

code:
graph_device_id_missing.
```

### Profile mismatch

Configuration referencia otro Profile.

Produce error.

### Configuration Device ID mismatch

El Device ID solicitado no coincide con Configuration.

Produce error.

### Manifest duplicado

Topics duplicados en publishes o subscribes producen error.

### Build válido

Debe verificar:

- DeviceGraphNode no null;
- Profile conservado;
- Configuration conservada;
- Manifest copiado;
- Primary Role correcto;
- InputPorts generados;
- OutputPorts generados;
- IDs `in.<topic>` y `out.<topic>`;
- Semantic Kind inicial UNSPECIFIED;
- orden conservado;
- Arrays independientes;
- Manifest externo no modifica Node.

## 36. DeviceGraphDraftDeviceTest

### Archivos previstos

```text
test/core/device_graph/
DeviceGraphDraftDeviceTest.tscn

test/core/device_graph/
device_graph_draft_device_test.gd
```

Debe verificar:

### Add Device

```text
Node válido se añade.

OperationResult success true.

affected_id contiene Device ID.

has_device() es true.

get_device() devuelve el Node.
```

### Duplicate Device ID

```text
segunda adición es rechazada;

code:
duplicate_device_id;

Graph no cambia.
```

### Invalid Node

```text
null es rechazado;

Graph no cambia.
```

### Collections

```text
get_devices() devuelve copia;

orden de inserción se conserva.
```

### Remove Device sin Connections

```text
Device se elimina;

OperationResult success true;

TopicChannels se reconstruyen.
```

### Device inexistente

```text
remove devuelve false;

code:
device_not_found.
```

## 37. DeviceGraphConnectionTest

### Archivos previstos

```text
test/core/device_graph/
DeviceGraphConnectionTest.tscn

test/core/device_graph/
device_graph_connection_test.gd
```

Debe verificar:

### Connection válida

```text
Source OutputPort existe.

Target InputPort existe.

Topic coincide.

Connection se crea.

ID es determinista.

TopicChannel existe.
```

### ID determinista

Debe verificar el formato:

```text
source|source_port|target|target_port

### Source inexistente

```text
rechazado;

code:
source_device_not_found.
```

### Target inexistente

```text
rechazado;

code:
target_device_not_found.
```

### OutputPort inexistente

```text
rechazado;

code:
source_port_not_found.
```

### InputPort inexistente

```text
rechazado;

code:
target_port_not_found.
```

### Topic mismatch

```text
rechazado;

code:
connection_topic_mismatch.
```

### Semantic mismatch

Con Kinds específicos diferentes:

```text
rechazado;

code:
connection_semantic_mismatch.
```

### UNSPECIFIED

Si uno o ambos Ports son UNSPECIFIED y Topic coincide:

```text
permitido.
```

### Self Connection

```text
rechazado;

code:
self_connection_not_supported.
```

### Duplicate

```text
segunda Connection rechazada;

code:
duplicate_connection.
```

### Disconnect

```text
Connection existente se elimina.

Connection inexistente se rechaza.
```

### Remove connected Device

```text
rechazado;

code:
device_has_connections.
```

## 38. DeviceGraphValidationTest

### Archivos previstos

```text
test/core/device_graph/
DeviceGraphValidationTest.tscn

test/core/device_graph/
device_graph_validation_test.gd
```

Debe verificar:

### Graph vacío

La primera versión podrá considerar un Graph vacío estructuralmente válido.

No contiene errores.

### Input sin Connection

Produce:

```text
WARNING

code:
input_port_unconnected.
```

El Graph continúa válido para Simulation.

### Output sin Connection

Produce:

```text
INFO

code:
output_port_unconnected.
```

### Graph conectado

No produce errores de Connection.

### Cycle

Construir:

```text
Controller A → Controller B

Controller B → Controller A
```

Debe producir:

```text
WARNING

code:
cycle_requires_runtime_validation.
```

No bloquea Snapshot por sí solo.

### Referencia corrupta

Una Connection huérfana no debe poder entrar mediante API pública.

La prueba puede validar que una operación fallida conserva Graph anterior.

## 39. DeviceGraphSnapshotTest

### Archivos previstos

```text
test/core/device_graph/
DeviceGraphSnapshotTest.tscn

test/core/device_graph/
device_graph_snapshot_test.gd
```

Debe verificar:

### Snapshot válido

```text
Snapshot no null.

Report válido para Simulation.

Devices conservados.

Connections conservadas.

TopicChannels conservados.

Orden conservado.
```

### Collections independientes

Modificar Arrays devueltos no cambia Snapshot.

### Sin setters

Snapshot no expone operaciones de mutación.

### Draft posterior

Modificar Draft después de crear Snapshot no cambia Snapshot.

```markdown
### Operación fallida antes del Snapshot

La prueba debe:

1. construir un Graph válido;

2. intentar una mutación inválida mediante API pública;

3. comprobar que la operación falla;

4. crear Snapshot;

5. comprobar que Snapshot conserva únicamente el estado válido anterior.

Esto verifica transaccionalidad sin corromper estado privado.

### Snapshot no ejecutable

Debe verificar mediante contrato y API que DeviceGraphSnapshot:

- no contiene DeviceBus;
- no contiene Callables;
- no expone método `execute()`;
- no expone método `activate()`;
- no expone método `publish()`.

CompositionCompiler permanece como etapa futura.
```

La prueba utilizará una operación o fixture controlado que no requiera alterar collections privadas directamente.

## 40. Orden de implementación

```text
1. Crear core/graph/.

2. Implementar PortSemanticKinds.

3. Ejecutar PortSemanticKindsTest.

4. Implementar InputPort.

5. Implementar OutputPort.

6. Implementar TopicChannel.

7. Implementar Connection.

8. Ejecutar DeviceGraphPrimitivesTest.

9. Implementar DeviceGraphNode.

10. Implementar DeviceGraphNodeBuildResult.

11. Implementar DeviceGraphNodeBuilder.

12. Ejecutar DeviceGraphNodeBuilderTest.

13. Implementar DeviceGraphOperationResult.

14. Implementar DeviceGraphDraft
	con add/remove.

15. Ejecutar DeviceGraphDraftDeviceTest.

16. Implementar connect/disconnect.

17. Ejecutar DeviceGraphConnectionTest.

18. Implementar validate y cycle detection.

19. Ejecutar DeviceGraphValidationTest.

20. Implementar DeviceGraphSnapshot.

21. Implementar DeviceGraphSnapshotResult.

22. Implementar create_snapshot().

23. Ejecutar DeviceGraphSnapshotTest.

24. Ejecutar runner Run All.

25. Registrar resultados.

26. Actualizar Core Architecture.```

## 41. Criterios de aceptación

DeviceGraph 1.0 satisface el diseño cuando:

1. PortSemanticKinds está implementado.

2. Ports son inmutables.

3. TopicChannel es inmutable.

4. Connection es inmutable.

5. DeviceGraphNode es inmutable.

6. NodeBuilder utiliza snapshots.

7. Manifest se copia.

8. Ports se generan desde Manifest.

9. DeviceGraphDraft utiliza API controlada.

10. Device ID duplicado se rechaza.

11. Connection válida se crea.

12. Connection inválida no cambia Graph.

13. Self Connection se rechaza.

14. Topic mismatch se rechaza.

15. Semantic mismatch se rechaza.

16. Duplicate Connection se rechaza.

17. Device conectado no se elimina.

18. TopicChannels se derivan.

19. Inputs desconectados generan WARNING.

20. Outputs desconectados generan INFO.

21. Cycles generan WARNING.

22. Snapshot es inmutable.

23. Operaciones fallidas son transaccionales.

24. Collections devueltas son copias.

25. DeviceGraph no depende de DeviceBus runtime.

26. pruebas sucesoras terminan correctamente.

27. runner Run All termina PASS.

28. Connection ID utiliza formato determinista.

29. El separador `|` está reservado.

30. IDs ambiguos son rechazados.

31. GraphSnapshot no es ejecutable.

32. CompositionCompiler permanece obligatorio
	antes de runtime.

33. Snapshot transaccional se prueba mediante
	APIs públicas, no corrupción privada.

## 42. Fuera de alcance

La implementación no añadirá:

- GraphEditor;
- GraphLayout;
- SystemProfile concreto;
- GraphSerializer;
- CompositionCompiler;
- DeviceRuntime;
- TemporalBoundary metadata;
- Named Input Slots;
- Cardinality;
- Hardware Mode;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation;
- conexiones eléctricas;
- power;
- mecánica.

## 43. Resumen de implementación

```text
Semantic Kinds:
PortSemanticKinds

Ports:
DeviceGraphInputPort
DeviceGraphOutputPort

Channel:
DeviceGraphTopicChannel

Connection:
DeviceGraphConnection

Logical Device:
DeviceGraphNode

Node Builder:
DeviceGraphNodeBuilder

Editable Graph:
DeviceGraphDraft

Immutable Graph:
DeviceGraphSnapshot

Mutation Result:
DeviceGraphOperationResult

Snapshot Result:
DeviceGraphSnapshotResult

Validation:
ValidationReport

Runtime Transport:
DeviceBus separado

Visual Editor:
futuro
```
