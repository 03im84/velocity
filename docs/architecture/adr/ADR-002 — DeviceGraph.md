# ADR-002 — DeviceGraph

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.1 |
| Fecha | 22/08/2026 |
| Componentes | DeviceGraphDraft, DeviceGraphNode, Ports, TopicChannel, Connection, DeviceGraphValidator, DeviceGraphSnapshot |
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
- ValidationIssue;
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

Responsabilidad del conjunto DeviceGraph:

> Representar y validar Devices, Ports, TopicChannels y Connections.

La topología editable pertenecerá a:

```text
DeviceGraphDraft
```

La validación global pertenecerá a:

```text
DeviceGraphValidator
```

La topología validada e inmutable pertenecerá a:

```text
DeviceGraphSnapshot
```

DeviceGraph será independiente de:

- SceneTree;
- DeviceBus runtime;
- UI;
- persistencia;
- hardware;
- comportamiento de Devices.

La primera versión trabajará con Devices ideales y conexiones lógicas de datos y comandos.

## 4. Modelo conceptual

```text
DeviceGraphNode
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
		DeviceGraphNode
```

Una Connection representa:

```text
Source DeviceGraphNode

Source OutputPort

TopicChannel

Target DeviceGraphNode

Target InputPort
```

No representa una llamada directa entre objetos.

## 5. DeviceGraphNode

DeviceGraphNode es la representación lógica de una instancia dentro del Graph.

No es:

- Node de Godot;
- escena;
- Device runtime;
- propietario del Device;
- componente visual.

DeviceGraphNode contiene o referencia:

- Device ID;
- Primary Role;
- DeviceProfile snapshot;
- DeviceConfiguration snapshot;
- DeviceManifest efectivo;
- InputPorts;
- OutputPorts.

DeviceGraphNode no modifica Profile, Configuration o Manifest.

## 6. Primary Role

Cada DeviceGraphNode tiene un único rol principal.

Roles iniciales:

```text
SENSOR

ACTUATOR

LOCAL_CONTROLLER

SUPERVISORY_CONTROLLER
```

El rol proviene de DeviceProfile.

Las capacidades adicionales provienen de DeviceManifest.

Un Device no acumula múltiples roles principales para mezclar responsabilidades.

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

Recibe Measurements y Setpoints.

Produce Commands, Results y Health.

### Supervisory Controller

Coordina subsistemas y objetivos globales.

Ejemplo:

```text
FlightControlComputer
```

Define Setpoints, modos y restricciones.

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

Los Ports pueden declarar significado de flujo.

Tipos iniciales:

```text
UNSPECIFIED

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

Si ambos Kinds son específicos, deben ser iguales.

Si uno o ambos son `UNSPECIFIED`, la compatibilidad se determina inicialmente por Topic.

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
Source DeviceGraphNode

Source OutputPort

TopicChannel

Target DeviceGraphNode

Target InputPort
```

Una Connection es válida cuando:

1. Source Device existe;

2. Target Device existe;

3. Source y Target son diferentes;

4. OutputPort pertenece al Source;

5. InputPort pertenece al Target;

6. OutputPort publica el Topic;

7. InputPort consume el Topic;

8. los Topics coinciden;

9. los Semantic Kinds son compatibles;

10. la Connection no está duplicada;

11. el Target InputPort no tiene otra Connection entrante;

12. las referencias utilizan IDs válidos;

13. Connection ID coincide con sus endpoints.

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

Composition Runtime crea las suscripciones y filtros necesarios.

DeviceBus transporta los mensajes.

Ningún Device utiliza otro Device como mecanismo principal de comunicación.

## 14. Single Semantic Owner

Cada stream tiene un propietario semántico por combinación:

```text
Topic + Source ID
```

Ejemplo:

```text
distance_measurement
+
front_left_distance_sensor
```

DeviceGraph debe detectar ownership duplicado.

Múltiples Sources pueden publicar el mismo Topic.

Ejemplo:

```text
front_left_distance_sensor

front_right_distance_sensor

rear_left_distance_sensor

rear_right_distance_sensor
```

Todos pueden publicar:

```text
distance_measurement
```

Cada uno conserva Source ID diferente.

La existencia de múltiples Sources para el mismo Topic no constituye por sí sola un error.

## 15. Fan-out y fan-in

### 15.1 Fan-out

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

### 15.2 Fan-in

Un mismo InputPort no puede recibir múltiples Connections.

Rechazado:

```text
Source A ──┐
		   ├──► mismo Target InputPort
Source B ──┘
```

Produce:

```text
STRUCTURAL_ERROR

code:
input_port_multiple_sources
```

Cuando un sistema necesite combinar varias fuentes deberá utilizar un Device explícito de:

- merge;
- selección;
- arbitraje;
- votación;
- fusión;
- transformación.

### 15.3 Limitación inicial

DeviceGraph 1.0 genera un Port por:

```text
direction + Topic
```

Por tanto, un Merge Device para varias fuentes del mismo Topic requerirá en el futuro:

- Named Input Slots;
- metadata de cardinalidad;
- Port definitions especializados.

Esta limitación se acepta para mantener DeviceGraph 1.0 simple y explícito.

No se permitirá fan-in implícito como solución temporal.

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

La validación utiliza contratos, Ports y ownership.

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

DeviceGraph permite representar control loops.

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

DeviceGraph no analiza estabilidad matemática.

## 19. Ciclos y fronteras temporales

### 19.1 Problema temporal

Un zero-delay cycle regresa a su origen sin frontera temporal.

Ejemplo:

```text
A publica X.

B recibe X y publica Y.

A recibe Y y publica X.
```

Puede provocar message storm.

### 19.2 Información disponible

DeviceGraph 1.0 todavía no contiene metadata que demuestre la presencia de:

- Physics Frame;
- Scheduler Tick;
- Timer;
- Hardware Sample;
- External Input;
- otra frontera temporal.

Por tanto, DeviceGraph no afirmará que un ciclo es zero-delay sin evidencia.

### 19.3 Política conservadora

Cada componente cíclico se reportará como:

```text
SIMULATION_HAZARD

code:
graph_cycle_requires_temporal_analysis
```

Consecuencias:

```text
Simulation Mode:
permitido.

Hardware Mode:
bloqueado.
```

Esto cumple VP-002:

> La simulación puede fallar. El simulador no.

### 19.4 Validación futura

CompositionCompiler podrá:

- demostrar una frontera temporal;
- aceptar el loop para runtime;
- identificar un zero-delay cycle;
- producir un Platform Safety Error cuando corresponda.

DeviceBus bounded FIFO y sus budgets proporcionan protección runtime adicional, pero no sustituyen la validación previa.

### 19.5 Algoritmo seguro

La detección de ciclos:

- será iterativa;
- no utilizará recursión;
- tendrá complejidad `O(V + E)`;
- producirá un Issue por componente cíclico;
- tendrá orden determinista;
- no enumerará combinaciones ilimitadas de caminos.

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
- crear DeviceGraphNode;
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

DeviceGraph tiene dos formas conceptuales.

### DeviceGraphDraft

Mutable mediante API controlada.

Puede estar incompleto.

No puede utilizarse directamente por Runtime.

### DeviceGraphSnapshot

Validado e inmutable.

Puede entregarse a CompositionCompiler.

La activación utilizará snapshots.

Las modificaciones posteriores del Draft no alteran el Graph activo.

## 27. VP-002

DeviceGraph debe cumplir:

- Draft no ejecuta;
- snapshots son inmutables;
- cambios transaccionales;
- Last Known Good;
- Structural Errors bloqueantes;
- Platform Safety Errors bloqueantes;
- Simulation Hazards permitidos en Simulation Mode;
- Simulation Hazards bloqueados en Hardware Mode;
- Hardware Safety Errors bloqueados en Hardware Mode;
- recursos runtime limitados;
- zero-delay cycles protegidos;
- algoritmos sobre Graph sin recursión ilimitada.

## 28. ValidationReport

DeviceGraph utiliza ValidationReport.

Validaciones iniciales:

- Device ID duplicado;
- DeviceGraphNode inválido;
- Profile inválido;
- Configuration inválida;
- Manifest inválido;
- Port ID duplicado;
- Port con Device inexistente;
- Topic incompatible;
- Semantic Kind incompatible;
- Connection duplicada;
- Connection ID incoherente;
- InputPort con múltiples Sources;
- stream owner duplicado;
- referencia inexistente;
- TopicChannel inconsistente;
- ciclo sin análisis temporal;
- Graph incompleto;
- operación transaccional fallida.

ValidationReport no modifica DeviceGraph.

## 29. Mutaciones transaccionales

DeviceGraphDraft no expone colecciones internas directamente.

Operaciones:

```text
add_device()

remove_device()

connect_ports()

disconnect_ports()
```

Cada operación:

1. valida argumentos;

2. prepara el cambio;

3. verifica invariantes locales;

4. aplica completamente;

5. o no modifica el Graph.

Una operación fallida conserva el estado anterior.

La validación global defensiva permanece en DeviceGraphValidator.

## 30. Eliminación de Device

DeviceGraph 1.0 rechaza eliminar un DeviceGraphNode que tenga Connections.

La herramienta debe desconectar primero.

DeviceGraph no deja Connections huérfanas.

Una operación futura podrá retirar un Device y sus Connections como una única transacción explícita.

## 31. Relación con Composition Runtime

CompositionRuntime o CompositionCompiler utilizará el Graph Snapshot para:

- crear Devices;
- aplicar Configurations;
- registrar suscripciones;
- configurar DeviceBus;
- establecer filtros por Source ID;
- establecer orden de inicialización;
- establecer orden de shutdown;
- observar Runtime Safety;
- comprobar fronteras temporales.

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
DeviceGraph validation

+

CompositionCompiler validation

+

DeviceBus bounded FIFO

+

Runtime Safety
```

Esto aplica defensa en profundidad.

## 33. Devices ideales

DeviceGraph 1.0 utiliza Devices ideales.

Información suficiente:

- Device ID;
- Primary Role;
- DeviceProfile;
- DeviceConfiguration;
- DeviceManifest;
- Ports;
- TopicChannels;
- Connections.

No incluye todavía:

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
- implementa políticas de degradación;
- demuestra estabilidad matemática;
- inventa fronteras temporales.

## 35. API conceptual

DeviceGraph debe permitir conceptualmente:

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

Las colecciones internas mutables no se exponen directamente.

## 36. Componentes relacionados y futuros

Componentes alrededor del Graph:

```text
DeviceGraphValidator

DeviceCatalog

GraphEditor

ConfigurationEditor

CompositionCompiler

GraphSerializer

ProfileBuilder

GraphLayout

RuntimeInspector
```

DeviceGraphValidator forma parte del núcleo lógico.

Los demás componentes no serán métodos gigantes dentro de DeviceGraphDraft.

## 37. Implementación inicial

La primera implementación incluye:

- DeviceGraphNode;
- InputPort;
- OutputPort;
- TopicChannel;
- Connection;
- DeviceGraphDraft;
- DeviceGraphValidator;
- validación estructural;
- detección conservadora de ciclos;
- DeviceGraphSnapshot;
- pruebas.

No necesita todavía:

- editor visual;
- persistencia;
- SystemProfile completo;
- hardware;
- ConfigurationEditor;
- metadata temporal.

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

Descartado porque Draft, validación, snapshot, runtime y UI tienen responsabilidades diferentes.

### Rechazar todos los ciclos

Descartado porque impediría feedback loops legítimos.

### Permitir ciclos en Hardware sin evidencia temporal

Descartado porque no es fail-safe.

### Detección recursiva de ciclos

Descartada porque un Graph definido por el usuario no debe poder provocar stack overflow.

### Fan-in implícito

Descartado porque oculta arbitraje dentro del consumidor.

### Un Source global por Topic

Descartado porque impediría múltiples sensores del mismo tipo con Source IDs diferentes.

## 39. Consecuencias positivas

- topología explícita;
- composición visual viable;
- validación centralizada;
- base para SystemProfile;
- base para CompositionCompiler;
- ownership identificable;
- loops representables;
- Ports comprobables;
- fan-in explícito;
- independencia de escenas;
- cabinas conectables mediante Bus;
- documentación automática futura;
- Hardware bloqueado cuando falta evidencia temporal.

## 40. Consecuencias negativas

- nuevas clases;
- más contratos;
- necesidad de mantener snapshots;
- validación adicional;
- relación con SystemProfile;
- necesidad de CompositionCompiler;
- mayor disciplina en Ports y ownership;
- un Merge Device del mismo Topic requerirá Named Input Slots futuros;
- algunos Graphs válidos para simulación no serán válidos para hardware.

Estas consecuencias son aceptadas.

## 41. Invariantes

1. DeviceGraph representa topología.

2. DeviceGraph no transporta mensajes.

3. Toda comunicación runtime utiliza DeviceBus.

4. DeviceGraph no crea Devices runtime.

5. Cada Device tiene un rol principal.

6. Ports derivan del Manifest efectivo.

7. TopicChannel representa un Topic.

8. Connection está mediada por TopicChannel.

9. No existen referencias directas de comunicación.

10. Stream ownership utiliza Topic + Source ID.

11. Múltiples Source IDs pueden compartir Topic.

12. DeviceBus realiza fan-out.

13. Un InputPort admite como máximo una Connection entrante.

14. Fan-in requiere un Device explícito.

15. Consumers no republican datos sin transformación.

16. Derived outputs utilizan contratos nuevos.

17. Feedback loops están permitidos.

18. Un ciclo sin evidencia temporal es Simulation Hazard.

19. Un ciclo sin evidencia temporal bloquea Hardware Mode.

20. DeviceGraph no afirma zero-delay sin evidencia.

21. La detección de ciclos no utiliza recursión.

22. Graph activo utiliza Snapshot.

23. Draft no ejecuta.

24. Graph no persiste archivos.

25. UI depende del modelo.

26. SystemProfile representa persistencia futura.

27. Mutaciones son transaccionales.

28. Operaciones fallidas conservan el estado anterior.

29. Colecciones internas no se exponen mutables.

30. VP-002 se aplica a toda operación.

31. DeviceGraphValidator no modifica sus entradas.

32. Los reportes de validación tienen orden determinista.

## 42. Criterios de aceptación

DeviceGraph 1.0 satisface ADR-002 cuando:

1. existe DeviceGraphNode;

2. existen InputPort y OutputPort;

3. existe TopicChannel;

4. existe Connection;

5. existe DeviceGraphDraft;

6. existe DeviceGraphValidator;

7. Device ID duplicado es rechazado;

8. Ports se generan desde Manifest;

9. Connection valida Source y Target;

10. Connection valida Topic;

11. Connection duplicada es rechazada;

12. InputPort con múltiples Sources es rechazado;

13. ownership duplicado es detectable;

14. ValidationReport describe errores;

15. operaciones fallidas son transaccionales;

16. colecciones devueltas son copias;

17. los ciclos se detectan sin recursión;

18. un ciclo produce Simulation Hazard;

19. Simulation Mode permite el ciclo no clasificado;

20. Hardware Mode bloquea el ciclo no clasificado;

21. existe Graph Snapshot inmutable;

22. DeviceGraph no depende de DeviceBus runtime;

23. pruebas terminan correctamente;

24. regresión completa termina PASS;

25. Connection ID es determinista;

26. TopicChannel Registry es validable;

27. Snapshot no es ejecutable.

## 43. Fuera de alcance

ADR-002 no implementará todavía:

- GraphEditor;
- ConfigurationEditor;
- SystemProfile completo;
- GraphSerializer;
- GraphLayout;
- CompositionCompiler completo;
- DeviceRuntime;
- Hardware Mode activo;
- TemporalBoundary metadata;
- Named Input Slots;
- Port cardinality configurable;
- Merge Device canónico;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation.