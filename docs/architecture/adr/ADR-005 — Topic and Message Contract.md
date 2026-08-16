# ADR-005 — Topic and Message Contract

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.1 |
| Fecha | 2026-08-15 |
| Componentes | BusTopics, BusMessage, DeviceManifest |
| Alcance | Identidad de topics y envelope de mensajes |

## 1. Contexto

Velocity utiliza DeviceBus para intercambiar mensajes entre productores y consumidores.

ADR-001 establece que DeviceBus:

- no conoce tipos concretos;
- no interpreta mensajes;
- no transforma mensajes;
- entrega el mismo mensaje recibido;
- utiliza topics para localizar suscriptores.

El diseño de DeviceBus 1.0 establece la firma:

```gdscript
func publish(
	topic: StringName,
	message: Variant
) -> void
```

La auditoría EN003 encontró diferentes representaciones para un topic.

### BusTopics

```gdscript
String
```

### BusMessage

```gdscript
topic: String
```

### DeviceManifest

```gdscript
publishes: Array[String]
subscribes: Array[String]
```

### DeviceBus

```gdscript
StringName
```

También se encontró que BusMessage:

- hereda de Resource;
- se construye mediante asignaciones sucesivas;
- expone campos mutables;
- utiliza un Dictionary obligatorio como data;
- puede modificarse después de ser publicado.

Velocity necesita un contrato canónico para topics y mensajes antes de migrar consumidores reales al nuevo DeviceBus.

## 2. Problema

Mantener múltiples representaciones obliga a convertir entre:

```text
String
StringName
```

en productores, consumidores y adaptadores.

Esto produce:

- conversiones repetidas;
- contratos ambiguos;
- riesgo de topics inconsistentes;
- firmas diferentes para el mismo concepto;
- mayor posibilidad de errores;
- dificultad para definir manifests;
- dificultad para validar integraciones.

El BusMessage mutable también permite que:

- se publique un mensaje incompleto;
- el productor lo modifique después de publicar;
- un consumidor cambie lo que reciben consumidores posteriores;
- el envelope pierda consistencia con el topic utilizado por DeviceBus.

## 3. Decisión

Velocity utilizará:

```gdscript
StringName
```

como representación canónica de todos los topics internos.

Se alinearán:

```text
BusTopics
BusMessage
DeviceManifest
DeviceBus
```

BusMessage se rediseñará como un envelope de ejecución, construido de forma completa y tratado como solo lectura después de su creación.

## 4. Contrato canónico de Topic

Un Topic representa la identidad interna de un canal de comunicación.

Su tipo será:

```gdscript
StringName
```

Ejemplo:

```gdscript
&"distance_measurement"
```

Un Topic no representa:

- texto de interfaz;
- nombre traducible;
- dirección de red;
- formato de serialización;
- ruta del árbol de escenas;
- identificador visual.

Los adaptadores externos podrán convertir un Topic a String cuando necesiten serializarlo o mostrarlo.

La conversión no ocurrirá dentro de DeviceBus.

## 5. Convención de nombres

Los topics utilizarán:

```text
lower_snake_case
```

Ejemplos:

```text
test_message
distance_measurement
temperature_measurement
health_report
propulsion_command
```

No se utilizarán:

```text
DistanceMeasurement
distance-measurement
DISTANCE_MEASUREMENT
distance measurement
```

DeviceBus no validará ni normalizará esta convención.

La convención será responsabilidad de:

- BusTopics;
- contratos;
- pruebas;
- revisión de código.

## 6. BusTopics

BusTopics será el catálogo canónico de topics conocidos por la plataforma.

Las constantes utilizarán:

```gdscript
StringName
```

Ejemplo:

```gdscript
const DISTANCE_MEASUREMENT: StringName = (
	&"distance_measurement"
)
```

Los productores y consumidores utilizarán una constante existente cuando el topic forme parte del catálogo oficial.

No repetirán literales si ya existe una identidad canónica.

Añadir un nuevo topic deberá estar respaldado por:

- una capacidad real;
- un productor;
- un consumidor o integración prevista;
- un contrato de payload conocido.

## 7. Relación entre DeviceBus y BusMessage

DeviceBus continuará utilizando:

```gdscript
publish(
	topic: StringName,
	message: Variant
)
```

DeviceBus no cambiará a:

```gdscript
publish(
	message: BusMessage
)
```

porque eso obligaría al Bus a conocer un tipo concreto.

BusMessage también conservará el topic dentro de su envelope.

Por tanto, existirán:

```text
Topic de routing:
Argumento entregado a DeviceBus.publish()

Topic del envelope:
BusMessage.get_topic()
```

La regla de consistencia será:

> El productor debe entregar a DeviceBus el mismo topic contenido en BusMessage.

Ejemplo:

```gdscript
device_bus.publish(
	message.get_topic(),
	message
)
```

DeviceBus no comprobará que el mensaje sea BusMessage ni inspeccionará su topic.

La consistencia pertenece al productor y a sus pruebas.

### 7.1 Validación antes de publicar

DeviceBus permanece agnóstico respecto al tipo concreto del mensaje.

Por tanto, DeviceBus no ejecutará:

```gdscript
message.is_valid()```

## 8. Forma de BusMessage

BusMessage será una clase derivada de:

```gdscript
RefCounted
```

Declaración prevista:

```gdscript
extends RefCounted
class_name BusMessage
```

BusMessage no será:

- Node;
- escena;
- autoload;
- singleton;
- Resource editable;
- mecanismo de persistencia;
- serializador.

BusMessage representa un objeto temporal de ejecución.

La serialización pertenecerá a adaptadores externos.

## 9. Construcción de BusMessage

BusMessage se construirá en una sola operación.

Firma prevista:

```gdscript
BusMessage.new(
	source_id,
	topic,
	timestamp,
	payload
)
```

La construcción completa evita que el mensaje exista temporalmente con campos incompletos.

Los campos internos serán:

```text
_source_id: String
_topic: StringName
_timestamp: float
_payload: Variant
```

Los valores serán recibidos mediante `_init()`.

## 10. API pública de BusMessage

BusMessage expondrá únicamente operaciones de lectura y validación.

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
``````

```gdscript
func is_valid() -> bool
```

BusMessage no expondrá:

- setters;
- propiedades exportadas;
- set_data();
- métodos de transformación;
- métodos de serialización;
- métodos de routing;
- acceso a DeviceBus.

## 11. Validación de BusMessage

Un BusMessage será válido cuando:

```text
source_id no esté vacío;
topic no esté vacío.
```

El payload podrá ser `null` si el contrato concreto permite un mensaje sin datos adicionales.

ADR-005 no impone una validación semántica universal sobre payload.

Cada contrato concreto será responsable de validar su contenido.

El timestamp será conservado como float.

La semántica completa del tiempo será definida por un sistema futuro.

## 12. Payload

BusMessage utilizará:

```gdscript
Variant
```

para su payload.

Esto permite transportar:

- Measurement;
- Command;
- Dictionary;
- Resource;
- RefCounted;
- tipos primitivos;
- otros contratos futuros.

DeviceBus y BusMessage no interpretarán el payload.

El consumidor conocerá el contrato correspondiente al topic al que se suscribió.

Ejemplo:

```text
Topic:
distance_measurement

Payload:
DistanceMeasurement
```

No será obligatorio envolver un payload tipado dentro de un Dictionary.

## 13. Inmutabilidad contractual

BusMessage será tratado como solo lectura después de su construcción.

BusMessage:

- recibe sus valores durante `_init()`;
- no expone setters;
- no modifica sus campos;
- solo expone getters.

Los productores:

- completan el payload antes de publicar;
- no modifican el envelope después de publicarlo;
- utilizan el mismo topic para routing y envelope.

Los consumidores:

- no modifican el envelope;
- no cambian su topic;
- no cambian source_id;
- no cambian timestamp;
- tratan el payload según su contrato.

DeviceBus:

- no copia el mensaje;
- no modifica el mensaje;
- no valida el payload;
- no inspecciona el envelope.

La inmutabilidad de payloads concretos será definida por sus propios contratos.

## 14. Source ID

`source_id` continuará utilizando:

```gdscript
String
```

ADR-005 no rediseña DeviceIdentity.

El source ID identifica al productor que originó el mensaje.

Una decisión futura podrá evaluar si debe migrar a StringName.

## 15. Timestamp

`timestamp` continuará utilizando:

```gdscript
float
```

Representará segundos dentro del dominio temporal utilizado por el productor.

ADR-005 no define:

- reloj global;
- tiempo de simulación;
- tiempo real;
- epoch;
- sincronización de red;
- replay clock.

Estas decisiones pertenecen al futuro sistema de tiempo.

## 16. DeviceManifest

Los campos:

```gdscript
publishes
subscribes
```

utilizarán:

```gdscript
Array[StringName]
``````

Las consultas correspondientes recibirán:

```gdscript
StringName
```

Forma prevista:

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

Los campos:

```text
capabilities
requirements
``````

continuarán utilizando String.

No representan topics de DeviceBus.

## 17. Aplicación a DistanceSensorDevice

DistanceSensorDevice construirá conceptualmente:

```gdscript
var message := BusMessage.new(
	device.get_identity().get_device_id(),
	BusTopics.DISTANCE_MEASUREMENT,
	measurement.timestamp,
	measurement
)
```

Después publicará:

```gdscript
device_bus.publish(
	message.get_topic(),
	message
)
```


DistanceSensorDevice no:

- convierte topics manualmente;
- crea un Dictionary intermedio;
- llama a set_data();
- utiliza la firma anterior publish(message).

## 18. Aplicación a BusDebugListener

BusDebugListener continuará suscribiéndose mediante:

```gdscript
BusTopics.DISTANCE_MEASUREMENT
```

Su callback recibirá BusMessage.

El payload se obtendrá mediante:

```gdscript
var measurement: DistanceMeasurement = (
	message.get_payload()
)
```

No utilizará:

```gdscript
message.get_data()["measurement"]
```

`detach()` eliminará la misma combinación Topic y Callable que fue registrada durante `attach()`.


## 19. Alternativas descartadas

### 19.1 Mantener String

Descartado porque mantendría conversiones y contratos distintos frente a DeviceBus.

### 19.2 Convertir dentro de DeviceBus

Descartado porque DeviceBus no debe transformar identidades recibidas.

### 19.3 DeviceBus recibe únicamente BusMessage

Descartado porque obligaría al Bus a conocer un tipo concreto y rompería ADR-001.

### 19.4 Eliminar Topic de BusMessage

Descartado porque consumidores genéricos pueden necesitar identificar el canal original.

### 19.5 Mantener BusMessage mutable

Descartado porque permite construcción incompleta y modificaciones después de publicar.

### 19.6 Mantener BusMessage como Resource editable

Descartado porque BusMessage es un objeto temporal de ejecución, no un recurso de autoría.

### 19.7 Mantener Dictionary obligatorio

Descartado porque añade envoltorios innecesarios y limita payloads tipados.

## 20. Consecuencias

### 20.1 Positivas

- un solo tipo canónico para topics;
- API consistente;
- ausencia de conversiones repetidas;
- mensajes construidos completamente;
- envelope de solo lectura;
- payloads tipados directos;
- DeviceBus permanece agnóstico;
- mejor soporte para debug, replay y telemetría;
- contratos más fáciles de probar.

### 20.2 Negativas

- BusMessage deja de ser compatible con su API anterior;
- productores deben cambiar su forma de construir mensajes;
- consumidores deben utilizar getters;
- DeviceManifest debe migrar sus tipos;
- pruebas anteriores deben ser sustituidas;
- payloads mutables todavía requieren disciplina contractual.

Estas consecuencias son aceptadas.

## 21. Alcance de migración

La implementación de ADR-005 afectará:

```text
core/bus/bus_topics.gd

core/bus/bus_message.gd

core/device/device_manifest.gd

core/device/sensors/distance_sensor_device.gd

core/debug/bus_debug_listener.gd```

También requerirá pruebas nuevas para:

- BusTopics;
- BusMessage;
- DeviceManifest;
- publicación de DistanceSensorDevice;
- recepción en BusDebugListener.

No se modificarán silenciosamente pruebas anteriores.

Se crearán pruebas sucesoras.

## 22. Fuera de alcance

ADR-005 no rediseña:

- DistanceProvider;
- PhysicsDistanceProvider;
- ManualDistanceProvider;
- DistanceMeasurement;
- DeviceIdentity;
- DeviceGraph;
- ProfileSystem;
- telemetría;
- networking;
- serialización;
- sistema de tiempo.

Provider System permanece bajo ADR-003.

## 23. Invariantes

Las siguientes reglas no deberán romperse:

1. Todos los topics internos utilizan StringName.

2. Los topics oficiales se declaran en BusTopics.

3. Los nombres utilizan lower_snake_case.

4. DeviceBus no conoce BusMessage.

5. BusMessage contiene su topic.

6. El productor utiliza el mismo topic para routing y envelope.

7. BusMessage se construye completamente.

8. BusMessage no expone setters.

9. DeviceBus no modifica ni copia el mensaje.

10. El payload se transporta sin interpretación.

11. DeviceManifest utiliza StringName para publishes y subscribes.

12. La serialización permanece fuera de BusMessage.

13. Todo productor valida BusMessage antes de publicarlo.

14. Un BusMessage inválido no se entrega a DeviceBus.

## 24. Criterios de aceptación

La migración satisface ADR-005 si:

1. BusTopics utiliza StringName;

2. BusMessage hereda de RefCounted;

3. BusMessage se construye mediante `_init()`;

4. BusMessage solo expone getters e is_valid();

5. BusMessage utiliza Variant como payload;

6. DeviceManifest utiliza Array[StringName];

7. DistanceSensorDevice usa publish(topic, message);

8. BusDebugListener usa get_payload();

9. no quedan llamadas activas a set_data();

10. no quedan productores activos usando publish(message);

11. las pruebas sucesoras terminan correctamente;

12. DeviceBus no necesita ser modificado.

## 25. Regla de evolución

Un nuevo tipo de mensaje no debe ampliar DeviceBus.

Debe definir:

- su topic;
- su payload;
- su productor;
- sus consumidores;
- sus invariantes.

DeviceBus continuará limitado al routing.

BusMessage continuará limitado al envelope.

Los payloads concretos continuarán siendo contratos independientes.
