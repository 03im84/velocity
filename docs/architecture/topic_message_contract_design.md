# Topic and Message Contract — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.2 |
| Fecha | 2026-08-15 |
| Estado de implementación | COMPLETO |
| Última verificación | 2026-08-15 |
| ADR relacionado | ADR-005 — Topic and Message Contract |
| Componentes | BusTopics, BusMessage, DeviceManifest |

## 1. Propósito

Este documento traduce ADR-005 a un diseño concreto e implementable.

Define:

- la representación canónica de Topic;
- las constantes de BusTopics;
- la forma y API de BusMessage;
- la representación de topics en DeviceManifest;
- las reglas de construcción;
- las reglas de solo lectura;
- los casos que deberán verificarse;
- el orden de migración.

Este documento no modifica DeviceBus.

## 2. Alcance

El diseño afecta:

```text
core/bus/bus_topics.gd

core/bus/bus_message.gd

core/device/device_manifest.gd
```

Después de aprobar estos contratos se migrarán:

```text
core/device/sensors/distance_sensor_device.gd

core/debug/bus_debug_listener.gd
```

El diseño no afecta todavía:

```text
DistanceProvider

PhysicsDistanceProvider

ManualDistanceProvider

DistanceMeasurement

DeviceIdentity

DeviceGraph

Telemetry
```

## 3. Contrato de Topic

El tipo canónico será:

```gdscript
StringName
```

Un topic válido para contratos internos:

- no está vacío;
- utiliza lower_snake_case;
- representa un canal de comunicación;
- se declara en BusTopics cuando forma parte del catálogo oficial.

Ejemplos:

```gdscript
&"test_message"

&"distance_measurement"

&"temperature_measurement"

&"health_report"

&"propulsion_command"
```

DeviceBus solo comprobará que el topic no esté vacío.

La validación semántica y la convención de nombre pertenecen al catálogo y a sus pruebas.

## 4. Diseño de BusTopics

BusTopics conservará su responsabilidad actual:

> Proporcionar identidades canónicas para los topics conocidos por Velocity.

Forma prevista:

```gdscript
extends RefCounted
class_name BusTopics
```

Constantes previstas:

```gdscript
const TEST_MESSAGE: StringName = (
	&"test_message"
)

const DISTANCE_MEASUREMENT: StringName = (
	&"distance_measurement"
)

const TEMPERATURE_MEASUREMENT: StringName = (
	&"temperature_measurement"
)

const HEALTH_REPORT: StringName = (
	&"health_report"
)

const PROPULSION_COMMAND: StringName = (
	&"propulsion_command"
)
```

BusTopics no tendrá:

- estado de instancia;
- métodos de publicación;
- acceso a DeviceBus;
- conversión a formatos externos;
- validación de payload;
- lógica de routing.

Los componentes utilizarán las constantes directamente.

No será necesario crear:

```gdscript
BusTopics.new()
```

## 5. Diseño de BusMessage

BusMessage será un envelope de ejecución.

Forma prevista:

```gdscript
extends RefCounted
class_name BusMessage
```

BusMessage no será:

- Node;
- Resource editable;
- autoload;
- singleton;
- serializador;
- contenedor de routing.

### 5.1 Estado interno

BusMessage almacenará:

```gdscript
var _source_id: String
var _topic: StringName
var _timestamp: float
var _payload: Variant
```

Los campos serán privados por convención.

No utilizará:

```gdscript
@export
```

BusMessage no está diseñado para editarse en el Inspector.

### 5.2 Construcción

Firma prevista:

```gdscript
func _init(
	p_source_id: String,
	p_topic: StringName,
	p_timestamp: float,
	p_payload: Variant = null
) -> void
```

La construcción asignará:

```gdscript
_source_id = p_source_id
_topic = p_topic
_timestamp = p_timestamp
_payload = p_payload
```

Todos los campos del envelope quedan definidos durante la creación.

No se construirá un BusMessage mediante asignaciones sucesivas.

### 5.3 API de lectura

BusMessage expondrá:

```gdscript
func get_source_id() -> String
```

```gdscript
func get_topic() -> StringName
```

```gdscript
func get_timestamp() -> float
```

```gdscript
func get_payload() -> Variant
```

Cada método devolverá el campo correspondiente.

### 5.4 Validación

BusMessage expondrá:

```gdscript
func is_valid() -> bool
```

El resultado será `true` cuando:

```text
source_id no esté vacío

y

topic no esté vacío
```

Forma conceptual:

```gdscript
return (
	not _source_id.is_empty()
	and _topic != &""
)
```

El payload puede ser `null`.

El timestamp no será validado semánticamente por BusMessage.

### 5.5 API no permitida

BusMessage no tendrá:

```text
set_source_id()

set_topic()

set_timestamp()

set_payload()

set_data()

serialize()

publish()

route()
```

Tampoco expondrá públicamente sus variables internas.

### 5.6 Inmutabilidad contractual

Después de construir BusMessage:

- el productor no modifica el envelope;
- DeviceBus no modifica el envelope;
- los consumidores no modifican el envelope;
- los consumidores acceden mediante getters.

El payload se entrega por referencia cuando su tipo tenga semántica de referencia.

BusMessage no clona el payload.

Los contratos concretos definirán la política de mutabilidad de sus payloads.

## 6. Diseño de DeviceManifest

DeviceManifest continuará heredando de:

```gdscript
Resource
```

Los campos de topics cambiarán de:

```gdscript
var publishes: Array[String] = []
var subscribes: Array[String] = []
```

a:

```gdscript
@export var publishes: Array[StringName] = []
@export var subscribes: Array[StringName] = []
```

Los campos:

```gdscript
var capabilities: Array[String] = []
var requirements: Array[String] = []
```

no cambiarán.

No representan topics de DeviceBus.

### 6.1 Consultas

Las firmas previstas serán:

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

Ambas utilizarán:

```gdscript
Array.has(topic)
```

### 6.2 Responsabilidad

DeviceManifest describe:

- capacidades;
- topics publicados;
- topics consumidos;
- requisitos.

DeviceManifest no:

- publica mensajes;
- se suscribe al Bus;
- valida payloads;
- crea DeviceBus;
- controla lifecycle.

## 7. Relación entre los contratos

```text
BusTopics
	│
	│ proporciona StringName canónico
	▼
BusMessage
	│
	│ conserva Topic y Payload
	▼
DeviceBus.publish(
	topic,
	message
)

DeviceManifest
	│
	└── declara qué topics publica o consume un Device
```

DeviceBus no depende de:

```text
BusTopics
BusMessage
DeviceManifest
```

Son los productores y consumidores quienes combinan estos contratos.

### 7.1 Validación en el productor

Todo productor que construya BusMessage deberá:

1. crear el mensaje completamente;

2. ejecutar `is_valid()`;

3. terminar sin publicar si el mensaje no es válido;

4. entregar a DeviceBus el mismo topic contenido en el envelope.

Forma prevista:

```gdscript
var message := BusMessage.new(
	source_id,
	topic,
	timestamp,
	payload
)

if not message.is_valid():
	return

device_bus.publish(
	message.get_topic(),
	message
)```

## 8. Invariantes del diseño

```text
1. Todos los topics internos utilizan StringName.

2. BusTopics contiene las identidades oficiales.

3. Los nombres utilizan lower_snake_case.

4. BusMessage se construye completamente.

5. BusMessage no expone setters.

6. BusMessage solo expone getters e is_valid().

7. BusMessage utiliza Variant como payload.

8. DeviceBus no conoce BusMessage.

9. DeviceManifest utiliza Array[StringName] para topics.

10. Capabilities y requirements permanecen como String.

11. La serialización permanece fuera de estos componentes.

12. El mismo Topic debe utilizarse para routing y envelope.

13. Los productores validan BusMessage antes de publicarlo.

14. Los mensajes inválidos no llegan a DeviceBus.```

## 9. Estrategia de pruebas

La migración utilizará pruebas nuevas.

No se modificarán las pruebas anteriores para hacerlas compatibles con el contrato nuevo.

Las pruebas se dividirán en:

```text
Pruebas unitarias de contratos

Prueba de routing mediante DeviceBus

Prueba de BusDebugListener

Prueba de DistanceSensorDevice

Pruebas sucesoras de Provider System
```

Cada prueba creará sus propias instancias y no utilizará estado global.

## 10. Pruebas de BusTopics

Se creará:

```text
test/core/message_contract/
BusTopicsContractTest.tscn

test/core/message_contract/
bus_topics_contract_test.gd
```

### TC-U01 — Tipos canónicos

Debe verificar que todas las constantes conocidas sean:

```gdscript
StringName
```

Topics incluidos:

```text
TEST_MESSAGE

DISTANCE_MEASUREMENT

TEMPERATURE_MEASUREMENT

HEALTH_REPORT

PROPULSION_COMMAND
```

### TC-U02 — Valores canónicos

Debe verificar:

```text
TEST_MESSAGE
= test_message

DISTANCE_MEASUREMENT
= distance_measurement

TEMPERATURE_MEASUREMENT
= temperature_measurement

HEALTH_REPORT
= health_report

PROPULSION_COMMAND
= propulsion_command
```

### TC-U03 — Topics no vacíos

Ninguna constante oficial puede ser:

```gdscript
&""
```

Las pruebas de BusTopics se convierten en la garantía del catálogo canónico.

## 11. Pruebas de BusMessage

Se creará:

```text
test/core/message_contract/
BusMessageContractTest.tscn

test/core/message_contract/
bus_message_contract_test.gd
```

### BM-U01 — Construcción válida

Construir:

```text
source_id:
sensor_a

topic:
distance_measurement

timestamp:
10.5

payload:
objeto de prueba
```

Debe verificar:

```text
is_valid() devuelve true.

get_source_id() devuelve sensor_a.

get_topic() devuelve distance_measurement.

get_timestamp() devuelve 10.5.

get_payload() devuelve el mismo payload.
```

### BM-U02 — Source ID vacío

Un mensaje con:

```gdscript
source_id == ""
```

debe producir:

```text
is_valid() == false
```

### BM-U03 — Topic vacío

Un mensaje con:

```gdscript
topic == &""
```

debe producir:

```text
is_valid() == false
```

### BM-U04 — Payload null

Un mensaje con source ID y topic válidos podrá utilizar:

```gdscript
payload == null
```

y continuar siendo válido.

### BM-U05 — Identidad del payload

Si el payload es un objeto, `get_payload()` devuelve la misma referencia.

BusMessage no realiza copias.

### BM-U06 — Envelope de solo lectura

Debe verificarse que BusMessage no exponga:

```text
set_source_id()

set_topic()

set_timestamp()

set_payload()

set_data()
```

También debe verificarse que BusMessage exponga:

```text
get_source_id()

get_topic()

get_timestamp()

get_payload()

is_valid()
```

### BM-U07 — Tipo de ejecución

Debe verificarse que BusMessage:

```text
sea RefCounted;

no sea Resource;

no sea Node.```

## 12. Pruebas de DeviceManifest

Se creará:

```text
test/core/message_contract/
DeviceManifestTopicTest.tscn

test/core/message_contract/
device_manifest_topic_test.gd
```

### DM-U01 — Topic publicado

Añadir:

```gdscript
BusTopics.DISTANCE_MEASUREMENT
```

a:

```gdscript
publishes
```

Debe verificar:

```text
publishes_topic() devuelve true.
```

### DM-U02 — Topic consumido

Añadir:

```gdscript
BusTopics.HEALTH_REPORT
```

a:

```gdscript
subscribes
```

Debe verificar:

```text
subscribes_to() devuelve true.
```

### DM-U03 — Topic inexistente

Debe verificar que un topic no registrado devuelva:

```text
false
```

### DM-U04 — Separación de conceptos

`capabilities` y `requirements` continuarán aceptando String.

No se utilizarán como listas de topics.

### DM-U05 — Tipo canónico de los Arrays

Debe verificarse que:

```gdscript
publishes```

## 13. Prueba de routing

Se creará una prueba nueva:

```text
test/core/message_contract/
BusMessageRoutingTest.tscn

test/core/message_contract/
bus_message_routing_test.gd
```

Recorrido:

```text
Productor de prueba
		│
		▼
BusMessage
		│
		▼
DeviceBus.publish(
	message.get_topic(),
	message
)
		│
		▼
Consumidor de prueba
```

### BM-I01 — Routing y envelope

Debe verificar:

```text
El consumidor recibe el mensaje.

El consumidor recibe la misma referencia.

El topic de routing coincide con get_topic().

El source ID permanece intacto.

El timestamp permanece intacto.

El payload permanece intacto.
```

DeviceBus no será modificado para ejecutar esta prueba.

## 14. Prueba sucesora de BusDebugListener

Se creará una prueba nueva.

Ruta prevista:

```text
test/core/debug/
BusDebugListenerIntegrationTest.tscn

test/core/debug/
bus_debug_listener_integration_test.gd
```

Debe verificar:

```text
attach() registra exactamente una suscripción.

Un segundo attach() no deja la suscripción anterior.

detach() elimina la suscripción.

detach() libera la referencia secundaria.

El listener recibe un BusMessage válido.

El listener obtiene DistanceMeasurement
mediante get_payload().
```

La prueba anterior no será modificada para validar este comportamiento.

## 15. Prueba sucesora de DistanceSensorDevice

Se creará una prueba nueva.

Ruta prevista:

```text
test/core/device/
DistanceSensorMessageTest.tscn

test/core/device/
distance_sensor_message_test.gd
```

Utilizará un Provider exclusivo de prueba.

Ese Provider:

- no tendrá class_name;
- no modificará Provider System;
- implementará get_distance();
- implementará is_valid();
- existirá únicamente dentro del test.

La prueba debe verificar:

```text
DistanceSensorDevice recibe DeviceBus
mediante initialize_sensor().

DistanceSensorDevice publica en
BusTopics.DISTANCE_MEASUREMENT.

El mensaje es BusMessage.

message.get_topic() coincide con
el topic de routing.

message.get_payload() devuelve
DistanceMeasurement.

DistanceMeasurement conserva:
- distance;
- valid;
- timestamp.

El source ID coincide con la identidad
del Device.
```

Esta prueba no decide la arquitectura de Provider System.

## 16. Pruebas de Provider System

Las siguientes pruebas anteriores no serán sustituidas durante ADR-005:

```text
physics_distance_provider_test

DistanceSensorIntegrationTest
con PhysicsDistanceProvider
```

Su sustitución requiere primero:

```text
ADR-003 — Provider System
```

ADR-005 no modificará Providers para conseguir que esas pruebas funcionen.

## 17. Orden de implementación

La migración seguirá este orden:

```text
1. Implementar BusTopics.

2. Ejecutar BusTopicsContractTest.

3. Implementar BusMessage.

4. Ejecutar BusMessageContractTest.

5. Implementar DeviceManifest.

6. Ejecutar DeviceManifestTopicTest.

7. Crear BusMessageRoutingTest.

8. Ejecutar BusMessageRoutingTest.

9. Migrar BusDebugListener.

10. Crear y ejecutar su prueba sucesora.

11. Migrar DistanceSensorDevice.

12. Crear y ejecutar su prueba sucesora.

13. Buscar usos de APIs anteriores.

14. Registrar resultados.

15. Evaluar pruebas anteriores para sustitución.
```

Cada etapa debe terminar correctamente antes de comenzar la siguiente.

## 18. APIs anteriores que deberán desaparecer

Después de completar la migración activa no deben quedar usos de:

```gdscript
BusMessage.new()
```

sin argumentos.

Tampoco deben quedar usos activos de:

```gdscript
message.source_id = ...

message.topic = ...

message.timestamp = ...

message.set_data(...)

message.get_data()

device_bus.publish(message)
```

Las llamadas nuevas utilizarán:

```gdscript
var message := BusMessage.new(
	source_id,
	topic,
	timestamp,
	payload
)

device_bus.publish(
	message.get_topic(),
	message
)
```

Las búsquedas finales excluirán temporalmente:

```text
core/tests/
core/bus/device_bus_bckup.gd
```

porque pertenecen a la arquitectura anterior.

## 19. Política de pruebas anteriores

Una prueba anterior será declarada SUPERADA únicamente cuando:

1. su garantía observable haya sido identificada;

2. exista una prueba sucesora;

3. la prueba sucesora termine correctamente;

4. la nueva prueba utilice la arquitectura vigente;

5. la sustitución se registre en project_journal.

Después podrá retirarse del árbol activo.

El archivo continuará disponible en el historial de Git.

## 20. Criterios de aceptación

El diseño podrá declararse implementado cuando:

1. BusTopics utilice StringName;

2. todas sus constantes sean no vacías;

3. BusMessage herede de RefCounted;

4. BusMessage se construya completamente;

5. BusMessage solo exponga lectura y validación;

6. BusMessage utilice Variant como payload;

7. DeviceManifest utilice Array[StringName];

8. BusMessageRoutingTest termine correctamente;

9. BusDebugListener utilice get_payload();

10. BusDebugListener utilice unsubscribe();

11. DistanceSensorDevice utilice publish(topic, message);

12. DistanceSensorDevice publique DistanceMeasurement directamente como payload;

13. las pruebas sucesoras terminen correctamente;

14. DeviceBus no haya sido modificado;

15. no se haya modificado Provider System.

16. Los productores activos ejecutan is_valid() antes de publicar BusMessage.

## 21. Fuera de alcance

Este diseño no resolverá:

- duplicidad de DistanceProvider;
- estado interno de ManualDistanceProvider;
- PhysicsDistanceProvider;
- inmutabilidad de DistanceMeasurement;
- reloj global;
- telemetría;
- serialización;
- replay;
- networking;
- DeviceGraph.

Estos elementos requieren decisiones separadas.

## 22. Resumen de migración

```text
BusTopics:
String → StringName

BusMessage:
Resource mutable
→
RefCounted de solo lectura

Data:
Dictionary obligatorio
→
Payload Variant

DeviceManifest:
Array[String]
→
Array[StringName]

Publicación:
publish(message)
→
publish(message.get_topic(), message)

Consumidor:
get_data()
→
get_payload()

Pruebas:
Modificar anteriores
→
Crear sucesoras

Provider System:
Sin cambios
```
