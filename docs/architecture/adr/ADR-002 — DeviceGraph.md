# ADR-002 — DeviceGraph

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.0 |
| Fecha | 18/08/2026 |
| Componentes | DeviceGraph, DeviceNode, Ports, TopicChannel, Connection |
| Alcance | Topología lógica, validación y base para composición visual |

## 1. Contexto

Velocity está diseñado como un sistema de sistemas compuesto por:

- Sensors;
- Actuators;
- Local Controllers;
- Supervisory Controllers;
- Bridges;
- herramientas;
- cabinas;
- telemetría;
- runtime de simulación.

Los componentes se comunican mediante DeviceBus.

Los contratos actuales proporcionan:

- DeviceIdentity;
- DeviceProfile;
- DeviceConfiguration;
- DeviceManifest;
- DeviceState;
- DeviceHealth;
- DeviceLifecycle;
- BusTopics;
- BusMessage;
- bounded FIFO dispatch;
- ValidationReport.

La composición manual de Devices, Ports, Topics, Connections, Profiles y Configurations crecerá rápidamente.

Velocity necesita un modelo lógico que permita comprender, validar, editar y posteriormente compilar la topología del sistema.

## 2. Problema

Sin DeviceGraph, las conexiones existirían únicamente como código dentro de una Composition Root.

Esto dificulta responder:

- qué Devices existen;
- qué rol tiene cada Device;
- qué publica cada Device;
- qué consume;
- qué Connections existen;
- qué inputs están incompletos;
- qué stream tiene ownership ambiguo;
- qué feedback loops existen;
- qué requisitos faltan;
- cómo representar visualmente el sistema;
- cómo guardar la composición;
- cómo generar un Composition Plan;
- cómo conectar una cabina sin modificar productores.

Una interfaz visual sin un modelo independiente produciría una arquitectura definida por widgets y escenas.

Eso contradice:

> Visualization is built on architecture, never the opposite.

## 3. Decisión

Velocity utilizará DeviceGraph como modelo lógico de topología.

Responsabilidad única:

> Representar y validar Devices, Ports, TopicChannels y Connections.

DeviceGraph será independiente de:

- SceneTree;
- DeviceBus runtime;
- UI;
- persistencia;
- hardware;
- comportamiento de Devices.

La primera versión trabajará con Devices ideales y conexiones de datos y comandos.

## 4. Modelo conceptual

```text
DeviceNode
	│
	├── OutputPort
	│       │
	│       ▼
	│   TopicChannel
	│       │
	│       ▼
	└── InputPort
			│
			▼
		DeviceNode
```

Una Connection representa:

```text
Source Device

Source OutputPort

TopicChannel

Target Device

Target InputPort
```

No representa una llamada directa entre objetos.

## 5. DeviceNode

DeviceNode es la representación lógica de una instancia dentro del Graph.

No es:

- Node de Godot;
- escena;
- Device runtime;
- propietario del Device;
- componente visual.

DeviceNode contendrá o referenciará:

- Device ID;
- Primary Role;
- DeviceProfile snapshot;
- DeviceConfiguration snapshot;
- DeviceManifest efectivo;
- InputPorts;
- OutputPorts.

DeviceNode no modifica Profile, Configuration o Manifest.

## 6. Primary Role

Cada DeviceNode tendrá un único rol principal.

Roles iniciales:

```text
SENSOR

ACTUATOR

LOCAL_CONTROLLER

SUPERVISORY_CONTROLLER
```

El rol proviene de DeviceProfile.

Las capacidades adicionales provienen de DeviceManifest.

Un Device no acumulará múltiples roles principales para mezclar responsabilidades.

## 7. Jerarquía de autoridad

### Sensor

Observa y produce Measurements.

No tiene autoridad de control.

### Actuator

Consume Commands y afecta el sistema físico.

No define estrategia global.

### Local Controller

Toma decisiones dentro de un subsistema.

Ejemplo:

```text
HoverMCU
```

Recibe Measurements y setpoints.

Produce Commands, resultados y Health.

### Supervisory Controller

Coordina subsistemas y objetivos globales.

Ejemplo:

```text
FlightControlComputer
```

Define setpoints, modos y restricciones.

No ejecuta directamente el control físico local.

DeviceGraph representa esta jerarquía.

No ejecuta las decisiones.

## 8. OutputPort

OutputPort representa:

> Este Device puede publicar este TopicChannel.

Los OutputPorts se derivan de:

```gdscript
DeviceManifest.publishes
```

Información conceptual:

- Port ID;
- Device ID propietario;
- Topic;
- Semantic Kind;
- dirección Output.

OutputPort no publica mensajes.

## 9. InputPort

InputPort representa:

> Este Device puede consumir este TopicChannel.

Los InputPorts se derivan de:

```gdscript
DeviceManifest.subscribes
```

Información conceptual:

- Port ID;
- Device ID propietario;
- Topic;
- Semantic Kind;
- dirección Input.

InputPort no contiene directamente un Callable runtime durante la fase lógica.

## 10. Semantic Kind

Los Ports podrán declarar significado de flujo.

Tipos conceptuales iniciales:

```text
MEASUREMENT

COMMAND

SETPOINT

RESULT

STATE

HEALTH

EVENT
```

Semantic Kind ayuda a:

- comprender;
- validar;
- representar;
- prevenir conexiones incorrectas.

No modifica el routing de DeviceBus.

La representación concreta se definirá en el diseño.

## 11. TopicChannel

TopicChannel representa un canal lógico de DeviceBus.

Identidad:

```gdscript
StringName
```

Ejemplo:

```gdscript
BusTopics.DISTANCE_MEASUREMENT
```

TopicChannel no:

- almacena mensajes;
- publica;
- se suscribe;
- conoce callbacks;
- controla queue;
- reemplaza DeviceBus.

Es una representación del contrato de comunicación.

## 12. Connection

Connection asocia:

```text
Source DeviceNode

Source OutputPort

TopicChannel

Target DeviceNode

Target InputPort
```

Una Connection es válida cuando:

1. Source Device existe;

2. Target Device existe;

3. OutputPort pertenece al Source;

4. InputPort pertenece al Target;

5. OutputPort publica el Topic;

6. InputPort consume el Topic;

7. los Semantic Kinds son compatibles;

8. la Connection no está duplicada;

9. las referencias utilizan IDs válidos.

Connection no crea una referencia directa de comunicación entre Devices.

## 13. DeviceBus obligatorio

Toda comunicación runtime de datos y comandos utiliza DeviceBus.

Modelo real:

```text
Publisher
	│
	▼
DeviceBus
	│
	▼
Subscriber
```

DeviceGraph describe la relación.

Composition Runtime crea las suscripciones.

DeviceBus transporta los mensajes.

Ningún Device utiliza otro Device como mecanismo principal de comunicación.

## 14. Single Semantic Owner

Cada stream tendrá un propietario semántico por combinación:

```text
Topic + Source ID
```

Ejemplo:

```text
distance_measurement
+
front_left_distance_sensor
```

DeviceGraph deberá poder detectar ownership duplicado.

Múltiples Sources pueden publicar el mismo Topic.

Ejemplo:

```text
front_left_distance_sensor

front_right_distance_sensor

rear_left_distance_sensor

rear_right_distance_sensor
```

Todos publican:

```text
distance_measurement
```

Cada uno conserva Source ID diferente.

## 15. Fan-out

Una publicación puede tener múltiples consumidores.

```text
DistanceMeasurement
	│
	├──► HoverMCU
	├──► Debug
	├──► Telemetry
	├──► Replay
	└──► CockpitBridge
```

DeviceBus realiza fan-out.

DeviceGraph representa las relaciones.

No se crea una publicación nueva por consumidor.

## 16. No republishing sin transformación

Un consumidor no vuelve a publicar un mensaje sin cambios.

Incorrecto:

```text
Sensor
	↓ DistanceMeasurement
MCU
	↓ misma DistanceMeasurement
FCC
```

Correcto:

```text
Sensor
	↓ DistanceMeasurement
MCU
	↓ HoverControlResult
FCC
	↓ FlightControlState
```

Cada publicación derivada tiene significado y ownership nuevos.

DeviceGraph no implementa esta regla mediante inspección de payload.

La validación utilizará contratos, Ports y ownership.

## 17. Provenance

Los resultados derivados podrán conservar información sobre sus entradas.

Ejemplos:

- Source IDs;
- Message IDs;
- Frame IDs;
- timestamps;
- snapshots;
- inputs utilizados;
- inputs faltantes;
- modo degradado.

Provenance no implica referencia directa al Device productor.

DeviceGraph no crea provenance.

El contrato pertenece al futuro sistema de Measurement, Snapshot y Data Flow.

## 18. Feedback loops

DeviceGraph permitirá representar control loops.

Ejemplo:

```text
Sensor
	↓
MCU
	↓
Actuator
	↓
Physics
	↓
Sensor
```

Los loops físicos válidos contienen una frontera temporal.

Ejemplos:

- Physics Frame;
- Process Frame;
- Scheduler Tick;
- Timer;
- Hardware Sample;
- External Input.

DeviceGraph no analizará estabilidad matemática.

## 19. Zero-delay cycles

Un zero-delay cycle regresa a su origen sin frontera temporal.

Ejemplo:

```text
A publica X.

B recibe X y publica Y.

A recibe Y y publica X.
```

Puede provocar message storm.

DeviceGraph deberá representar información suficiente para que GraphValidator o CompositionCompiler lo detecten.

DeviceBus bounded FIFO y sus budgets proporcionan protección runtime adicional.

## 20. DeviceProfile

DeviceProfile representa el modelo de Device.

DeviceGraph utiliza:

- Profile ID;
- Profile version;
- Primary Role;
- capacidades posibles.

DeviceGraph no modifica DeviceProfile.

Solo utiliza snapshots validados.

## 21. DeviceConfiguration

DeviceConfiguration representa la configuración validada de una instancia.

DeviceGraph utiliza:

- Configuration ID;
- Configuration version;
- Device ID;
- Profile reference;
- Activation Context.

DeviceGraph no recibe DeviceConfigurationDraft.

DeviceGraph no compila Configuration.

## 22. DeviceManifest

DeviceManifest representa la interfaz efectiva.

DeviceGraph utiliza Manifest para generar Ports.

```text
Manifest publishes
	↓
OutputPorts

Manifest subscribes
	↓
InputPorts
```

DeviceGraph no construye Manifest.

DeviceManifestBuilder permanece externo.

## 23. SystemProfile

SystemProfile será la representación persistente canónica de una composición.

DeviceGraph será el modelo lógico en memoria.

Carga:

```text
SystemProfile
	↓
DeviceGraph
```

Guardado:

```text
DeviceGraph validado
	↓
nuevo SystemProfile snapshot
```

DeviceGraph no abre ni guarda archivos.

Un componente externo realizará serialización.

## 24. GraphEditor

GraphEditor permitirá:

- seleccionar DeviceProfile;
- crear DeviceConfigurationDraft;
- compilar Configuration;
- construir Manifest;
- crear DeviceNode;
- crear Ports;
- crear Connections;
- validar;
- guardar SystemProfile.

GraphEditor depende de DeviceGraph.

DeviceGraph no depende de GraphEditor.

## 25. Layout visual

DeviceGraph 1.0 no almacena:

- posición visual;
- color;
- tamaño;
- zoom;
- iconos;
- estilo.

La presentación pertenecerá a un modelo externo como:

```text
GraphLayout
```

o metadata de editor.

La misma topología podrá tener múltiples representaciones.

## 26. Draft y Snapshot

DeviceGraph tendrá dos formas conceptuales.

### DeviceGraph Draft

Mutable mediante API controlada.

Puede estar incompleto.

No puede utilizarse directamente por Runtime.

### DeviceGraph Snapshot

Validado e inmutable.

Puede entregarse a CompositionCompiler.

La activación utilizará snapshots.

Las modificaciones no alterarán el Graph activo.

## 27. VP-002

DeviceGraph deberá cumplir:

- Draft no ejecuta;
- snapshots son inmutables;
- cambios transaccionales;
- Last Known Good;
- Structural Errors bloqueantes;
- Platform Safety Errors bloqueantes;
- Simulation Hazards permitidos en Simulation Mode;
- Hardware Safety Errors bloqueados en Hardware Mode;
- recursos runtime limitados;
- zero-delay cycles protegidos.

## 28. ValidationReport

DeviceGraph utilizará ValidationReport.

Validaciones iniciales:

- Device ID duplicado;
- DeviceNode inválido;
- Profile inválido;
- Configuration inválida;
- Manifest inválido;
- Port ID duplicado;
- Port con Device inexistente;
- Topic incompatible;
- Semantic Kind incompatible;
- Connection duplicada;
- stream owner duplicado;
- referencia inexistente;
- zero-delay cycle;
- Graph incompleto;
- operación transaccional fallida.

ValidationReport no modifica DeviceGraph.

## 29. Mutaciones transaccionales

DeviceGraph Draft no expondrá Arrays internos directamente.

Operaciones conceptuales:

```text
add_device()

remove_device()

connect_ports()

disconnect_ports()
```

Cada operación:

1. valida argumentos;

2. prepara el cambio;

3. verifica invariantes;

4. aplica completamente;

5. o no modifica el Graph.

Una operación fallida conserva el estado anterior.

## 30. Eliminación de Device

Eliminar un DeviceNode deberá considerar sus Connections.

La política concreta se definirá en el diseño.

Opciones posibles:

- rechazar si tiene Connections;
- retirar Connections de forma transaccional;
- requerir confirmación desde herramienta.

DeviceGraph no dejará Connections huérfanas.

## 31. Relación con Composition Runtime

Composition Runtime o CompositionCompiler utilizará el Graph Snapshot para:

- crear Devices;
- aplicar Configurations;
- registrar suscripciones;
- configurar DeviceBus;
- establecer orden de inicialización;
- establecer orden de shutdown;
- observar Runtime Safety.

DeviceGraph no ejecuta el plan.

## 32. Relación con DeviceBus Runtime Safety

DeviceGraph no reemplaza:

- Publication Budget;
- Callback Budget;
- Queue Size Limit;
- Time Budget;
- Dispatch Report.

Protección:

```text
Graph validation

+

CompositionCompiler validation

+

DeviceBus bounded FIFO

+

Runtime Safety
```

Esto aplica defensa en profundidad.

## 33. Devices ideales

DeviceGraph 1.0 utilizará Devices ideales.

Información suficiente:

- Device ID;
- Primary Role;
- DeviceProfile;
- DeviceConfiguration;
- DeviceManifest;
- Ports;
- TopicChannels;
- Connections.

No incluirá todavía:

- hardware real;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation;
- conexiones eléctricas;
- power;
- mecánica;
- GPIO;
- I2C;
- serial.

## 34. No responsabilidades

DeviceGraph no:

- crea Devices runtime;
- destruye Devices runtime;
- controla Lifecycle;
- modifica Health;
- modifica State;
- publica mensajes;
- se suscribe a DeviceBus;
- transporta mensajes;
- interpreta payloads;
- compila Profiles;
- compila Configurations;
- construye Manifests;
- serializa;
- guarda SystemProfiles;
- dibuja UI;
- controla hardware;
- implementa lógica MCU;
- implementa lógica FCC;
- implementa políticas de degradación.

## 35. API conceptual

DeviceGraph deberá permitir conceptualmente:

```text
add_device()

remove_device()

get_device()

get_devices()

connect_ports()

disconnect_ports()

get_connections()

get_topic_channels()

validate()

create_snapshot()
```

Las firmas concretas se definirán en el diseño.

No se devolverán referencias directas a colecciones internas mutables.

## 36. Herramientas futuras

Componentes futuros alrededor del Graph:

```text
DeviceCatalog

GraphEditor

ConfigurationEditor

GraphValidator

CompositionCompiler

GraphSerializer

ProfileBuilder

GraphLayout

RuntimeInspector
```

No serán métodos gigantes dentro de DeviceGraph.

## 37. Implementación inicial

La primera implementación podrá limitarse a:

- DeviceNode;
- InputPort;
- OutputPort;
- TopicChannel;
- Connection;
- DeviceGraph Draft;
- validación estructural;
- snapshot;
- pruebas.

No necesita todavía:

- editor visual;
- persistencia;
- SystemProfile completo;
- hardware;
- ConfigurationEditor.

## 38. Alternativas descartadas

### Sin DeviceGraph

Insuficiente para composición visual y perfiles complejos.

### DeviceGraph transporta mensajes

Descartado porque duplicaría DeviceBus.

### DeviceGraph crea Devices

Descartado porque mezclaría topología y runtime.

### DeviceGraph controla Lifecycle

Descartado porque pertenece a Composition Runtime.

### DeviceGraph guarda archivos

Descartado porque persistencia es otra responsabilidad.

### UI como modelo

Descartado porque la arquitectura no puede depender de widgets.

### Graph monolítico

Descartado porque Profile, Configuration, Manifest, runtime y UI tienen responsabilidades independientes.

## 39. Consecuencias positivas

- topología explícita;
- composición visual viable;
- validación centralizada;
- base para SystemProfile;
- base para CompositionCompiler;
- ownership identificable;
- loops representables;
- Ports comprobables;
- independencia de escenas;
- cabinas conectables mediante Bus;
- documentación automática futura.

## 40. Consecuencias negativas

- nuevas clases;
- más contratos;
- necesidad de mantener snapshots;
- validación adicional;
- relación con SystemProfile;
- necesidad de CompositionCompiler;
- mayor disciplina en Ports y ownership.

Estas consecuencias son aceptadas.

## 41. Invariantes

1. DeviceGraph representa topología.

2. DeviceGraph no transporta mensajes.

3. Toda comunicación utiliza DeviceBus.

4. DeviceGraph no crea Devices runtime.

5. Cada Device tiene un rol principal.

6. Ports derivan del Manifest efectivo.

7. TopicChannel representa un Topic.

8. Connection está mediada por TopicChannel.

9. No existen referencias directas de comunicación.

10. Stream ownership utiliza Topic + Source ID.

11. DeviceBus realiza fan-out.

12. Consumers no republican datos sin transformación.

13. Derived outputs utilizan contratos nuevos.

14. Feedback loops están permitidos.

15. Zero-delay cycles requieren protección.

16. Graph activo utiliza snapshot.

17. Draft no ejecuta.

18. Graph no persiste archivos.

19. UI depende del modelo.

20. SystemProfile representa persistencia futura.

21. Mutaciones son transaccionales.

22. Operaciones fallidas conservan estado anterior.

23. Collections internas no se exponen mutables.

24. VP-002 se aplica a toda operación.

## 42. Criterios de aceptación

La primera implementación satisface ADR-002 cuando:

1. existe DeviceNode;

2. existen InputPort y OutputPort;

3. existe TopicChannel;

4. existe Connection;

5. existe DeviceGraph Draft;

6. Device ID duplicado es rechazado;

7. Ports se generan desde Manifest;

8. Connection valida Source y Target;

9. Connection valida Topic;

10. Connection duplicada es rechazada;

11. ownership duplicado es detectable;

12. ValidationReport describe errores;

13. operaciones fallidas son transaccionales;

14. collections devueltas son copias;

15. existe Graph Snapshot inmutable;

16. DeviceGraph no depende de DeviceBus runtime;

17. pruebas terminan correctamente;

18. regresión completa termina PASS.

## 43. Fuera de alcance

ADR-002 no implementará todavía:

- GraphEditor;
- ConfigurationEditor;
- SystemProfile completo;
- GraphSerializer;
- GraphLayout;
- CompositionCompiler completo;
- DeviceRuntime;
- Hardware Mode;
