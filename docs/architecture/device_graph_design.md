# DeviceGraph — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.3 |
| Fecha | 22/08/2026 |
| ADR relacionado | ADR-002 — DeviceGraph |
| Alcance | Topología lógica y validación para Devices ideales |

## 1. Propósito

Este documento traduce ADR-002 a un diseño concreto e implementable.

DeviceGraph 1.1 define:

- PortSemanticKinds;
- DeviceGraphInputPort;
- DeviceGraphOutputPort;
- DeviceGraphTopicChannel;
- DeviceGraphConnection;
- DeviceGraphNode;
- DeviceGraphNodeBuilder;
- DeviceGraphOperationResult;
- DeviceGraphDraft;
- DeviceGraphValidator;
- DeviceGraphSnapshot;
- DeviceGraphSnapshotResult;
- validación global;
- detección conservadora de ciclos;
- mutaciones transaccionales;
- pruebas.

DeviceGraph trabaja con:

- DeviceProfile snapshots;
- DeviceConfiguration snapshots;
- DeviceManifest efectivo;
- Devices ideales;
- datos y comandos;
- DeviceBus como transporte runtime futuro.

## 2. Estructura

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
├── device_graph_operation_result.gd
├── device_graph_draft.gd
├── device_graph_validator.gd
├── device_graph_snapshot.gd
└── device_graph_snapshot_result.gd
```

Estado actual:

```text
DeviceGraph Primitives:
COMPLETADO.

DeviceGraphNodeBuilder:
COMPLETADO.

DeviceGraphDraft:
COMPLETADO.

Connections:
COMPLETADO.

DeviceGraphValidator:
COMPLETADO.

Fan-in Protection:
COMPLETADO.

Iterative Cycle Detection:
COMPLETADO.

DeviceGraphSnapshot:
COMPLETADO.

DeviceGraphSnapshotResult:
COMPLETADO.

create_snapshot():
COMPLETADO.

DeviceGraph 1.0:
IMPLEMENTADO Y VERIFICADO.

Siguiente arquitectura:
SystemProfile y CompositionCompiler.
```

### 2.2 Pruebas

```text
test/core/device_graph/
├── PortSemanticKindsTest.tscn
├── port_semantic_kinds_test.gd
├── DeviceGraphPrimitivesTest.tscn
├── device_graph_primitives_test.gd
├── DeviceGraphNodeBuilderTest.tscn
├── device_graph_node_builder_test.gd
├── DeviceGraphDraftDeviceTest.tscn
├── device_graph_draft_device_test.gd
├── DeviceGraphConnectionTest.tscn
├── device_graph_connection_test.gd
├── DeviceGraphValidationTest.tscn
├── device_graph_validation_test.gd
├── DeviceGraphSnapshotTest.tscn
└── device_graph_snapshot_test.gd
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

### DeviceGraphValidator

Componente sin estado que examina una topología completa y produce ValidationReport.

### DeviceGraphSnapshot

Topología validada e inmutable.

## 4. PortSemanticKinds

### 4.1 Archivo

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
const UNSPECIFIED: StringName = &"unspecified"

const MEASUREMENT: StringName = &"measurement"

const COMMAND: StringName = &"command"

const SETPOINT: StringName = &"setpoint"

const RESULT: StringName = &"result"

const STATE: StringName = &"state"

const HEALTH: StringName = &"health"

const EVENT: StringName = &"event"
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

La primera implementación todavía no tiene TopicContractRegistry.

Los Ports generados desde DeviceManifest utilizan inicialmente:

```text
UNSPECIFIED
```

UNSPECIFIED no significa inválido.

Significa:

```text
Semantic Kind todavía no especificado.
```

### 4.6 Compatibilidad inicial

```text
Si ambos Kinds son específicos:
deben ser iguales.

Si uno o ambos son UNSPECIFIED:
la compatibilidad se decide por Topic.
```

No se infiere semántica mediante nombres como `_measurement` o `_command`.

## 5. DeviceGraphInputPort

### 5.1 Archivo

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

DeviceGraphInputPort es inmutable por contrato.

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

semantic_kind válido;

IDs sin separador reservado.
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

### 5.8 Cardinalidad inicial

Un InputPort admite como máximo:

```text
una Connection entrante.
```

Cardinalidad configurable pertenece a una evolución futura.

## 6. DeviceGraphOutputPort

### 6.1 Archivo

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

DeviceGraphOutputPort es inmutable por contrato.

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

semantic_kind válido;

IDs sin separador reservado.
```

### 6.7 Responsabilidad

OutputPort representa:

> Este Device puede publicar este Topic.

No publica por sí mismo.

No contiene referencia a DeviceBus.

### 6.8 Fan-out

Un OutputPort puede participar en múltiples Connections.

No existe un límite semántico inicial de consumidores.

## 7. Port IDs

La generación automática utiliza IDs deterministas.

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

El formato es identidad del Port dentro del Device.

No es un Topic ni una ruta de escena.

### Limitación inicial

Un DeviceManifest contiene cada Topic una sola vez.

La primera versión genera un Port por:

```text
direction + Topic
```

Named slots como:

```text
front_left_distance

front_right_distance
```

se añadirán cuando Profile y Configuration expongan metadata de Ports especializados.

### Separador reservado

DeviceGraph utiliza:

```text
|
```

Ningún Device ID o Port ID puede contenerlo.

## 8. DeviceGraphTopicChannel

### 8.1 Archivo

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

### 9.1 Archivo

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

target_port_id no vacío;

componentes sin separador reservado.
```

La compatibilidad con Graph pertenece a DeviceGraphDraft y DeviceGraphValidator.

### 9.6 Inmutabilidad

Connection es inmutable por contrato.

No expone setters.

## 10. DeviceGraphNode

### 10.1 Archivo

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

DeviceGraphNode es un snapshot lógico.

No expone setters.

Los Arrays se copian durante construcción.

Los getters de Ports devuelven Arrays nuevos.

### 10.5 Manifest interno

DeviceManifest actual es mutable.

DeviceGraphNode no conserva directamente el objeto editable recibido.

Durante construcción crea una copia interna de:

- capabilities;
- publishes;
- subscribes;
- requirements.

`get_manifest()` devuelve otra copia.

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

Los Ports se generan desde DeviceManifest.

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

DeviceManifest debe estar validado.

Si contiene Topics duplicados, DeviceGraphNodeBuilder produce error estructural.

## 12. DeviceGraphNodeBuilder

### 12.1 Archivo

```text
core/graph/device_graph_node_builder.gd
```

### 12.2 Responsabilidad

> Construir DeviceGraphNode desde snapshots y Manifest efectivo.

### 12.3 API

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
- Device ID no contiene `|`;
- Primary Role válido;
- Manifest no contiene duplicados;
- Ports generados son válidos.

Si Device ID contiene el separador:

```text
STRUCTURAL_ERROR

code:
graph_id_contains_reserved_separator
```

### 12.5 Resultado

Produce:

```text
DeviceGraphNode

ValidationReport
```

No modifica los argumentos.

## 13. DeviceGraphNodeBuildResult

### 13.1 Archivo

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

## 14. Invariantes de primitivas

1. Graph components son RefCounted.

2. Ningún componente es Godot Node.

3. Ports son inmutables.

4. TopicChannel es inmutable.

5. Connection es inmutable.

6. DeviceGraphNode es inmutable.

7. DeviceGraphNode utiliza snapshots.

8. Manifest interno se copia.

9. Ports derivan del Manifest efectivo.

10. Port ID combina direction y Topic.

11. Un Topic genera un Port por dirección.

12. Semantic Kind puede ser UNSPECIFIED.

13. DeviceGraph no infiere Kind por nombre.

14. Connection no contiene referencias directas a Devices.

15. TopicChannel no transporta mensajes.

16. DeviceGraphNodeBuilder produce ValidationReport.

## 15. DeviceGraphOperationResult

### 15.1 Archivo

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
- ID vacío en fallo.

### 15.5 API

```gdscript
is_success() -> bool

get_affected_id() -> StringName

get_report() -> ValidationReport
```

### 15.6 Inmutabilidad

DeviceGraphOperationResult es inmutable por contrato.

No expone setters.

## 16. DeviceGraphDraft

### 16.1 Archivo

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

La validación global no se implementa como un método gigante dentro del Draft.

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
get_devices() -> Array[DeviceGraphNode]
```

### 16.6 API de Connections

```gdscript
connect_ports(
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
get_connections() -> Array[DeviceGraphConnection]
```

### 16.7 API de TopicChannels

```gdscript
get_topic_channel(
	topic: StringName
) -> DeviceGraphTopicChannel
```

```gdscript
get_topic_channels() -> Array[DeviceGraphTopicChannel]
```

### 16.8 API de validación

```gdscript
validate() -> ValidationReport
```

```gdscript
create_snapshot() -> DeviceGraphSnapshotResult
```

`validate()` delega en DeviceGraphValidator.

### 16.9 Colecciones

Todos los getters de colecciones devuelven Arrays nuevos.

Los Dictionaries internos no se exponen.

## 17. Add Device

### 17.1 Validaciones

`add_device()` comprueba:

- Node no null;
- Node válido;
- Device ID no vacío;
- Device ID no registrado;
- Profile válido;
- Configuration válida;
- Manifest válido;
- Ports válidos.

### 17.2 Éxito

```text
DeviceGraphNode se registra.

TopicChannels requeridos por sus Ports
se crean si no existen.

OperationResult success true.

affected_id contiene Device ID.
```

### 17.3 Fallo

```text
Graph no cambia.

OperationResult success false.

ValidationReport contiene error.
```

### 17.4 Device ID duplicado

```text
STRUCTURAL_ERROR

code:
duplicate_device_id
```

## 18. Remove Device

### 18.1 Política inicial

DeviceGraph rechaza eliminar un Device que tenga Connections.

```text
STRUCTURAL_ERROR

code:
device_has_connections
```

La herramienta debe desconectar primero.

### 18.2 Device inexistente

```text
STRUCTURAL_ERROR

code:
device_not_found
```

### 18.3 Éxito

Al eliminar un Device sin Connections:

- se retira DeviceGraphNode;
- se reconstruyen TopicChannels;
- no quedan referencias huérfanas.

### 18.4 Evolución

Una operación futura podrá permitir:

```text
remove_device_with_connections()
```

como una transacción explícita.

## 19. Connection ID

DeviceGraph genera Connection IDs deterministas.

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
front_left_sensor|out.distance_measurement|hover_mcu|in.distance_measurement
```

El ID se convierte a StringName.

### Validación

Ningún componente individual puede contener:

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
- identifica endpoints concretos;
- permite detectar duplicados;
- no utiliza contador global;
- no utiliza UUID aleatorio.

El caller no proporciona Connection ID.

## 20. Connect Ports

### 20.1 Validaciones

`connect_ports()` comprueba:

- Source Device existe;
- Target Device existe;
- Source y Target son diferentes;
- OutputPort existe;
- InputPort existe;
- Ports pertenecen a sus Devices;
- Topics coinciden;
- Semantic Kinds son compatibles;
- Connection no existe;
- Target InputPort no tiene otra Connection entrante.

### 20.2 Self Connection

Si:

```text
source_device_id == target_device_id
```

produce:

```text
STRUCTURAL_ERROR

code:
self_connection_not_supported
```

### 20.3 Topic mismatch

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

Si uno o ambos son UNSPECIFIED y Topic coincide:

```text
Connection permitida.
```

### 20.5 Duplicate Connection

```text
STRUCTURAL_ERROR

code:
duplicate_connection
```

### 20.6 Multiple Sources

Si otra Connection ya utiliza el mismo:

```text
Target Device ID
+
Target InputPort ID
```

produce:

```text
STRUCTURAL_ERROR

code:
input_port_multiple_sources
```

La operación fallida no modifica el Graph.

### 20.7 Éxito

En éxito:

- se construye DeviceGraphConnection;
- se registra;
- se garantiza TopicChannel;
- se devuelve OperationResult;
- no se modifica DeviceBus.

## 21. Disconnect Ports

### 21.1 Connection inexistente

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

Un TopicChannel no utilizado por Ports o Connections puede retirarse durante reconstrucción.

## 22. TopicChannel Registry

DeviceGraphDraft mantiene un TopicChannel por Topic.

Se reconstruye a partir de:

- todos los InputPorts;
- todos los OutputPorts;
- todas las Connections.

No se modifica manualmente mediante API pública.

Esto evita canales sin relación con la topología.

## 23. DeviceGraphValidator

### 23.1 Archivo

```text
core/graph/device_graph_validator.gd
```

### 23.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphValidator
```

### 23.3 Responsabilidad

> Examinar una topología completa sin modificarla y producir un ValidationReport determinista.

No:

- añade Devices;
- elimina Devices;
- crea Connections;
- corrige el Graph;
- crea Snapshot;
- consulta DeviceBus;
- ejecuta runtime.

### 23.4 API

```gdscript
validate(
	devices: Array[DeviceGraphNode],
	connections: Array[DeviceGraphConnection],
	topic_channels: Array[DeviceGraphTopicChannel]
) -> ValidationReport
```

Los Arrays son copias obtenidas desde DeviceGraphDraft.

DeviceGraphValidator los trata como read-only.

### 23.5 Delegación desde Draft

```gdscript
func validate() -> ValidationReport:

	return DeviceGraphValidator.new().validate(
		get_devices(),
		get_connections(),
		get_topic_channels()
	)
```

La implementación deberá respetar las convenciones de formato GDScript del proyecto.

### 23.6 Graph vacío

Un Graph vacío es estructuralmente válido.

Razón:

- Draft puede estar incompleto;
- el conjunto vacío no contiene referencias corruptas;
- DeviceGraph valida topología, no utilidad;
- CompositionCompiler podrá exigir Devices para un plan ejecutable.

No produce Issues.

## 24. Full Graph Validation

### 24.1 Devices

Debe comprobar:

- Node no null;
- Node válido;
- Device ID no vacío;
- Device IDs únicos;
- Profile válido;
- Configuration válida;
- Manifest válido.

### 24.2 Ports

Debe comprobar:

- Port no null;
- Port válido;
- Port ID único dentro del Device;
- Port pertenece al Device;
- Input Topic está declarado en Manifest.subscribes;
- Output Topic está declarado en Manifest.publishes;
- un Device no declara dos OutputPorts para el mismo Topic.

### 24.3 Connections

Debe comprobar:

- Connection no null;
- identidad válida;
- Connection IDs únicos;
- Source existe;
- Target existe;
- Source y Target son diferentes;
- Source OutputPort existe;
- Target InputPort existe;
- Ports pertenecen a sus Devices;
- Topics coinciden;
- Topic almacenado por Connection coincide;
- Semantic Kinds son compatibles;
- Connection ID coincide con sus endpoints.

Connection ID incoherente produce:

```text
STRUCTURAL_ERROR

code:
connection_id_mismatch
```

### 24.4 InputPort Cardinality

Cada combinación:

```text
Target Device ID
+
Target InputPort ID
```

admite como máximo una Connection.

Si existen varias:

```text
STRUCTURAL_ERROR

code:
input_port_multiple_sources
```

La comprobación existe:

- durante `connect_ports()`;
- defensivamente dentro de DeviceGraphValidator.

### 24.5 Ownership

La primera versión define stream identity como:

```text
Topic + Source ID
```

Se permite:

```text
múltiples Source IDs
+
mismo Topic.
```

Se rechaza que un mismo Device declare dos OutputPorts para el mismo Topic.

### 24.6 TopicChannels

Debe comprobar:

- Channel no null;
- Channel válido;
- Topic único;
- todo Topic utilizado por Ports tiene Channel;
- todo Topic utilizado por Connections tiene Channel;
- no existen Channels ajenos a la topología.

Una inconsistencia produce:

```text
STRUCTURAL_ERROR

code:
topic_channel_registry_mismatch
```

### 24.7 Inputs sin Connection

Un InputPort sin Connection produce:

```text
WARNING

code:
input_port_unconnected
```

No es Structural Error porque todavía no existe metadata Required/Optional.

### 24.8 Outputs sin consumidores

Un OutputPort sin Connections produce:

```text
INFO

code:
output_port_unconnected
```

No bloquea Snapshot.

### 24.9 Orden

Los Issues se generan en orden determinista:

1. Devices;

2. Ports;

3. Connections;

4. TopicChannels;

5. cardinalidad;

6. Ports desconectados;

7. ciclos.

Dentro de cada categoría se conserva el orden de entrada cuando sea posible.

### 24.10 No mutación

La validación no:

- modifica Arrays recibidos;
- modifica Nodes;
- modifica Connections;
- modifica Channels;
- modifica Draft.

## 25. Cycle Detection

### 25.1 Modelo dirigido

Cada Connection produce una arista:

```text
Source Device
→
Target Device
```

### 25.2 Algoritmo

La detección utiliza componentes fuertemente conectados mediante algoritmo iterativo.

Requisitos:

- sin recursión;
- complejidad `O(V + E)`;
- memoria lineal;
- sin enumerar todos los ciclos posibles;
- resultado determinista.

Puede utilizar una variante iterativa de Kosaraju o un algoritmo equivalente que cumpla estas propiedades.

### 25.3 Componente cíclico

Un componente es cíclico cuando:

- contiene más de un Device; o
- contiene un self-loop defensivo.

Self-connections no entran mediante API pública, pero Validator conserva la comprobación defensiva.

### 25.4 Resultado

Cada componente cíclico produce un único Issue:

```text
SIMULATION_HAZARD

code:
graph_cycle_requires_temporal_analysis
```

No se produce un Issue por cada camino posible.

### 25.5 Efecto por contexto

```text
report.is_valid_for_simulation():
true, si no existen otros errores bloqueantes.

report.is_valid_for_hardware():
false.
```

### 25.6 Razón

DeviceGraph permite feedback loops legítimos.

Sin metadata temporal no puede demostrar:

- que el ciclo es seguro;
- que contiene una frontera temporal;
- que es zero-delay.

La ausencia de evidencia no debe bloquear Simulation Mode ni permitir Hardware Mode.

### 25.7 Responsabilidad futura

CompositionCompiler podrá comprobar:

- Physics Frame;
- Scheduler Tick;
- Timer;
- Hardware Sample;
- External Input;
- otra frontera temporal.

Un zero-delay cycle confirmado podrá producir Platform Safety Error.

## 26. DeviceGraphSnapshot

### 26.1 Archivo

```text
core/graph/device_graph_snapshot.gd
```

### 26.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphSnapshot
```

### 26.3 Estado

```gdscript
var _devices: Array[DeviceGraphNode]

var _connections: Array[DeviceGraphConnection]

var _topic_channels: Array[DeviceGraphTopicChannel]
```

### 26.4 Construcción

Los Arrays se copian durante `_init()`.

Los elementos ya son inmutables por contrato.

### 26.5 API

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

### 26.6 Inmutabilidad

Snapshot no expone:

- add;
- remove;
- connect;
- disconnect;
- setters.

### 26.7 Snapshot estructural

DeviceGraphSnapshot representa una topología validada.

No es un plan ejecutable.

Antes de runtime deberá pasar por:

```text
CompositionCompiler
```

## 27. DeviceGraphSnapshotResult

### 27.1 Archivo

```text
core/graph/device_graph_snapshot_result.gd
```

### 27.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphSnapshotResult
```

### 27.3 Estado

```gdscript
var _snapshot: DeviceGraphSnapshot

var _report: ValidationReport
```

### 27.4 API

```gdscript
get_snapshot() -> DeviceGraphSnapshot

get_report() -> ValidationReport

is_success() -> bool
```

### 27.5 Success

`is_success()` devuelve true cuando:

```text
snapshot no es null;

report es válido para Simulation Mode.
```

INFO, WARNING y SIMULATION_HAZARD no impiden un Snapshot de simulación.

## 28. Create Snapshot

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

Un Snapshot con Simulation Hazard no es autorización para Hardware Mode.

## 29. Mutaciones transaccionales

Cada mutación:

1. valida argumentos;

2. calcula el cambio;

3. aplica únicamente si todo es válido;

4. reconstruye TopicChannels;

5. devuelve OperationResult.

Una operación fallida no debe:

- añadir parcialmente un Device;
- añadir una Connection parcial;
- borrar Channels válidos;
- alterar colecciones anteriores;
- sustituir Last Known Good.

## 30. Orden determinista

DeviceGraphDraft conserva orden de inserción para:

- Devices;
- Connections;
- TopicChannels.

Los Arrays devueltos respetan ese orden.

DeviceGraphSnapshot conserva el mismo orden.

DeviceGraphValidator produce Issues en orden determinista.

Esto facilita:

- pruebas;
- UI;
- serialización futura;
- comparación;
- documentación.

## 31. Invariantes del bloque

1. Graph Draft es mutable solo mediante API.

2. Graph Snapshot es inmutable.

3. Device ID es único.

4. Connection ID es determinista.

5. Self-connections se rechazan.

6. Topic mismatch se rechaza.

7. Semantic mismatch específico se rechaza.

8. UNSPECIFIED permite validación por Topic.

9. Duplicate Connection se rechaza.

10. Device conectado no se elimina.

11. Un InputPort tiene como máximo una Connection.

12. Fan-out está permitido.

13. Fan-in requiere Device explícito.

14. TopicChannels se derivan de topología.

15. Inputs desconectados producen WARNING.

16. Outputs desconectados producen INFO.

17. Ciclos producen SIMULATION_HAZARD.

18. Ciclos no clasificados permiten Simulation.

19. Ciclos no clasificados bloquean Hardware.

20. Detección de ciclos no utiliza recursión.

21. Snapshot permite Simulation Hazards.

22. Snapshot bloquea Structural y Platform errors.

23. Colecciones devueltas son copias.

24. Operaciones fallidas son transaccionales.

25. Orden es determinista.

26. DeviceGraph no toca DeviceBus.

27. Connection ID utiliza separador reservado.

28. IDs no contienen `|`.

29. GraphSnapshot representa topología, no ejecución.

30. Runtime requiere CompositionCompiler.

31. Validator no modifica sus entradas.

## 32. Estrategia de pruebas

DeviceGraph utiliza pruebas nuevas e independientes.

Suites:

```text
PortSemanticKindsTest

DeviceGraphPrimitivesTest

DeviceGraphNodeBuilderTest

DeviceGraphDraftDeviceTest

DeviceGraphConnectionTest

DeviceGraphValidationTest

DeviceGraphSnapshotTest
```

Cada prueba utiliza:

- DeviceProfiles válidos;
- DeviceConfigurations válidas;
- DeviceManifests efectivos;
- objetos nuevos;
- ValidationReports independientes.

DeviceGraph no utiliza DeviceBus durante estas pruebas.

Las cinco baselines existentes no se modifican para validar la arquitectura nueva.

## 33. Fixtures de prueba

Los tests pueden construir snapshots con namespace:

```text
test.
```

Fixtures iniciales:

```text
test.distance_sensor

test.hover_mcu

test.hover_thruster

test.fcc
```

Las Configurations utilizan IDs de instancia únicos.

Los Manifests se construyen mediante DeviceManifestBuilder cuando sea posible.

No se utilizan Dictionaries genéricos para representar Devices.

## 34. PortSemanticKindsTest

Verifica:

- Kinds son StringName;
- valores canónicos;
- `is_valid()`;
- rechazo de vacío;
- rechazo de desconocido;
- `get_all()`;
- Array independiente.

Baseline aceptada:

```text
Checks: 28
Failures: 0
RESULT: PASS
```

## 35. DeviceGraphPrimitivesTest

Verifica:

- InputPort;
- OutputPort;
- TopicChannel;
- Connection;
- identidad;
- getters;
- inmutabilidad;
- ausencia de setters.

Baseline aceptada:

```text
Checks: 57
Failures: 0
RESULT: PASS
```

## 36. DeviceGraphNodeBuilderTest

Verifica:

- argumentos nulos;
- Device ID vacío;
- separador reservado;
- Profile mismatch;
- Configuration mismatch;
- Manifest duplicado;
- build válido;
- Ports deterministas;
- Semantic Kind UNSPECIFIED;
- Arrays independientes;
- Manifest copiado.

Baseline aceptada:

```text
Checks: 50
Failures: 0
RESULT: PASS
```

## 37. DeviceGraphDraftDeviceTest

Verifica:

- add Device;
- duplicate Device;
- null Device;
- collections independientes;
- remove Device;
- Device inexistente;
- TopicChannels;
- OperationResult inmutable.

Baseline aceptada:

```text
Checks: 28
Failures: 0
RESULT: PASS
```

## 38. DeviceGraphConnectionTest

Verifica:

- Connection válida;
- ID determinista;
- Source inexistente;
- Target inexistente;
- OutputPort inexistente;
- InputPort inexistente;
- Topic mismatch;
- Semantic mismatch;
- UNSPECIFIED;
- self-connection;
- duplicate;
- separador reservado;
- disconnect;
- Device conectado;
- colección independiente.

Baseline aceptada:

```text
Checks: 70
Failures: 0
RESULT: PASS
```

## 39. DeviceGraphValidationTest

### 39.1 Archivos

```text
test/core/device_graph/
DeviceGraphValidationTest.tscn

test/core/device_graph/
device_graph_validation_test.gd
```

### 39.2 Graph vacío

Debe verificar:

```text
Graph vacío no produce Issues.

Report es válido para Simulation.

Report es válido para Hardware.
```

### 39.3 Input sin Connection

Debe producir:

```text
WARNING

code:
input_port_unconnected
```

El Graph continúa válido para Simulation y Hardware.

### 39.4 Output sin Connection

Debe producir:

```text
INFO

code:
output_port_unconnected
```

No bloquea.

### 39.5 Graph conectado

Debe verificar:

- no errores de Connection;
- endpoints válidos;
- TopicChannels coherentes;
- IDs deterministas.

INFO por Outputs opcionales no conectados puede permanecer.

### 39.6 Fan-in mediante API

Debe:

1. conectar Source A a Target InputPort;

2. intentar conectar Source B al mismo Target InputPort;

3. recibir:

   ```text
   STRUCTURAL_ERROR

   code:
   input_port_multiple_sources
   ```

4. comprobar que solo permanece la primera Connection.

### 39.7 Fan-in defensivo del Validator

La prueba puede invocar DeviceGraphValidator con Arrays controlados que contengan dos Connections hacia el mismo InputPort.

Debe producir:

```text
STRUCTURAL_ERROR

code:
input_port_multiple_sources
```

Esto valida defensa en profundidad sin corromper campos privados del Draft.

### 39.8 Connection ID incoherente

Una fixture controlada con ID diferente de sus endpoints debe producir:

```text
STRUCTURAL_ERROR

code:
connection_id_mismatch
```

### 39.9 TopicChannel inconsistente

Una fixture controlada con Channels faltantes o adicionales debe producir:

```text
STRUCTURAL_ERROR

code:
topic_channel_registry_mismatch
```

### 39.10 Graph acíclico

Debe verificar que una cadena dirigida no produce:

```text
graph_cycle_requires_temporal_analysis
```

### 39.11 Ciclo

Construir:

```text
Controller A → Controller B

Controller B → Controller A
```

Debe producir exactamente un Issue:

```text
SIMULATION_HAZARD

code:
graph_cycle_requires_temporal_analysis
```

Debe verificar:

```text
Report válido para Simulation.

Report inválido para Hardware.
```

### 39.12 Varios componentes cíclicos

Dos componentes cíclicos independientes producen:

```text
un Issue por componente.
```

El orden debe ser determinista.

### 39.13 No mutación

Modificar Arrays externos después de validar no debe demostrar una modificación realizada por Validator.

Validator no cambia:

- Devices;
- Connections;
- TopicChannels;
- orden de Arrays.

### 39.14 Operación fallida

Una operación inválida mediante API pública conserva el Graph válido anterior.

No se modifican Dictionaries privados desde el test.

````markdown
### 39.15 Baseline aceptada

```text
Checks: 55
Failures: 0
RESULT: PASS
```

DeviceGraph acumulado:

```text
Tests: 6
Checks: 288
Failures: 0
```

Regresión completa:

```text
Tests: 39
Checks: 980
Failures: 0
Timeout: 0
Engine Error: 0
Plan ExitCode: 0
RESULT: PASS
```

## 40. DeviceGraphSnapshotTest

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

### Colecciones independientes

Modificar Arrays devueltos no cambia Snapshot.

### Sin setters

Snapshot no expone operaciones de mutación.

### Draft posterior

Modificar Draft después de crear Snapshot no cambia Snapshot.

### Operación fallida previa

La prueba:

1. construye Graph válido;

2. intenta mutación inválida;

3. comprueba fallo;

4. crea Snapshot;

5. comprueba que Snapshot contiene solo Last Known Good.

### Snapshot con ciclo no clasificado

Debe verificar:

```text
Snapshot de Simulation puede crearse.

Report contiene SIMULATION_HAZARD.

Report no es válido para Hardware.
```

### Snapshot no ejecutable

DeviceGraphSnapshot:

- no contiene DeviceBus;
- no contiene Callables;
- no expone `execute()`;
- no expone `activate()`;
- no expone `publish()`.

CompositionCompiler permanece como etapa futura.

## 41. Orden de implementación

```text
1. PortSemanticKinds.
   COMPLETADO.

2. InputPort.
   COMPLETADO.

3. OutputPort.
   COMPLETADO.

4. TopicChannel.
   COMPLETADO.

5. Connection.
   COMPLETADO.

6. DeviceGraphPrimitivesTest.
   PASS.

7. DeviceGraphNode.
   COMPLETADO.

8. DeviceGraphNodeBuildResult.
   COMPLETADO.

9. DeviceGraphNodeBuilder.
   COMPLETADO.

10. DeviceGraphNodeBuilderTest.
	PASS.

11. DeviceGraphOperationResult.
	COMPLETADO.

12. DeviceGraphDraft add/remove.
	COMPLETADO.

13. DeviceGraphDraftDeviceTest.
	PASS.

14. connect_ports()/disconnect_ports().
	COMPLETADO.

15. DeviceGraphConnectionTest.
	PASS.

116. DeviceGraphValidator.
	COMPLETADO.

17. Fan-in validation.
	COMPLETADO.

18. Iterative cycle detection.
	COMPLETADO.

19. DeviceGraphValidationTest.
	PASS — 55 checks.

20. DeviceGraphSnapshot.
	COMPLETADO.

21. DeviceGraphSnapshotResult.
	COMPLETADO.

22. create_snapshot().
	COMPLETADO.

23. DeviceGraphSnapshotTest.
	PASS — 71 checks.

24. Runner Run All.
	PASS — 40 tests, 1051 checks.

25. Registrar resultados.
	COMPLETADO.

26. Actualizar Core Architecture.
	COMPLETADO — versión 2.6.```

### Baseline aceptada

```text
Checks: 71
Failures: 0
RESULT: PASS
```

DeviceGraph acumulado:

```text
Tests: 7
Checks: 359
Failures: 0
```

Regresión completa:

```text
Tests: 40
Checks: 1051
Failures: 0
Timeout: 0
Engine Error: 0
Plan ExitCode: 0
RESULT: PASS
```

## 42. Criterios de aceptación

DeviceGraph 1.1 satisface el diseño cuando:

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

19. InputPort admite máximo una Connection.

20. Fan-in implícito se rechaza.

21. Inputs desconectados generan WARNING.

22. Outputs desconectados generan INFO.

23. DeviceGraphValidator no modifica entradas.

24. Detección de ciclos es iterativa.

25. Ciclos generan SIMULATION_HAZARD.

26. Ciclos no clasificados permiten Simulation.

27. Ciclos no clasificados bloquean Hardware.

28. Snapshot es inmutable.

29. Operaciones fallidas son transaccionales.

30. Colecciones devueltas son copias.

31. DeviceGraph no depende de DeviceBus runtime.

32. Pruebas sucesoras terminan correctamente.

33. Runner Run All termina PASS.

34. Connection ID utiliza formato determinista.

35. Separador `|` está reservado.

36. IDs ambiguos son rechazados.

37. GraphSnapshot no es ejecutable.

38. CompositionCompiler permanece obligatorio.

39. Snapshot se prueba mediante APIs públicas.

40. Graph vacío es estructuralmente válido.

Estado de aceptación:

```text
DEVICEGRAPH 1.0
IMPLEMENTADO Y VERIFICADO```

## 43. Fuera de alcance

Esta implementación no añade:

- GraphEditor;
- GraphLayout;
- SystemProfile concreto;
- GraphSerializer;
- CompositionCompiler;
- DeviceRuntime;
- TemporalBoundary metadata;
- Named Input Slots;
- Port cardinality configurable;
- Merge Device canónico;
- Hardware Mode activo;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation;
- conexiones eléctricas;
- power;
- mecánica.

## 44. Resumen

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

Validation:
DeviceGraphValidator
ValidationReport

Immutable Graph:
DeviceGraphSnapshot

Mutation Result:
DeviceGraphOperationResult

Snapshot Result:
DeviceGraphSnapshotResult

Runtime Transport:
DeviceBus separado

Runtime Compilation:
CompositionCompiler futuro

Visual Editor:
GraphEditor futuro
```
