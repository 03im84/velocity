# Velocity — Arquitectura del Núcleo

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 2.11 |
| Fecha inicial | 2026-08-14 |
| Última revisión | 23/08/2026 |
| Alcance | Núcleo lógico de Velocity |

## 1. Propósito

Este documento describe cómo encajan los componentes principales del núcleo de Velocity y establece los límites que deben respetar sus implementaciones.

Los Architecture Decision Records, o ADR, explican por qué se tomó una decisión arquitectónica.

Este documento explica cómo se relacionan las decisiones aceptadas y los componentes resultantes.

La Arquitectura del Núcleo es un documento vivo.

Debe reflejar la arquitectura vigente del proyecto, no el historial de cómo fue construida.

Su propósito es permitir que cada componente del núcleo pueda ser:

- comprendido de forma independiente;
- probado de forma aislada;
- sustituido sin modificar consumidores ajenos;
- reutilizado por diferentes sistemas;
- extendido sin romper responsabilidades existentes.

Este documento no contiene:

- código de implementación;
- resultados cronológicos;
- registros de experimentos;
- soluciones temporales;
- detalles visuales.

## 2. Definición del Core

El Core es el conjunto de contratos, mecanismos y reglas compartidas que permiten que los subsistemas de Velocity colaboren sin depender de implementaciones concretas.

El Core proporciona infraestructura común.

No implementa:

- comportamiento específico del vehículo;
- presentación visual;
- integración concreta con hardware;
- herramientas visuales;
- persistencia de usuario.

Dentro del Core existen conceptos como:

- DeviceBus;
- Topic y Message Contracts;
- Device;
- Provider;
- DeviceProfile;
- DeviceConfiguration;
- DeviceManifest;
- ValidationReport;
- DeviceGraph;
- SystemProfile;
- DeviceCatalog;
- DeviceGraphAssembler;
- System Composition;
- contratos de estado;
- contratos de salud;
- contratos de lifecycle.

La existencia de un concepto dentro del Core no significa que todos sus componentes deban conocerse entre sí.

Cada componente conserva una responsabilidad independiente.

Por ejemplo, DeviceBus pertenece al Core, pero no conoce:

- Devices concretos;
- Providers;
- sensores;
- física;
- telemetría;
- DeviceGraph;
- SystemProfile;
- DeviceCatalog;
- DeviceGraphAssembler;
- hardware.

## 3. Límites del Core

El Core no debe:

- leer directamente input del jugador;
- ejecutar raycasts;
- aplicar fuerzas sobre la nave;
- acceder al árbol de escenas para descubrir dependencias;
- dibujar interfaces;
- controlar cámaras;
- reproducir efectos visuales;
- serializar telemetría;
- abrir conexiones de red;
- acceder a GPIO, I2C, SPI o puertos seriales;
- conocer dispositivos concretos;
- depender de una cabina física;
- depender de una representación visual.

Los sistemas externos pueden depender de contratos definidos por el Core.

El Core nunca debe depender de esos sistemas externos.

Dirección general de dependencia:

```text
Presentación
Integraciones
Hardware
Telemetría
Herramientas
		  │
		  ▼
		 Core
```

El Core permanece en la parte interna de la arquitectura.

## 4. Relación con el juego

Velocity utiliza Godot Engine como host de ejecución.

La arquitectura del núcleo no está definida por:

- escenas;
- interfaces;
- widgets;
- herramientas del editor;
- rutas del SceneTree.

La organización vigente incluye:

```text
core/bus/
		Comunicación y Runtime Safety de DeviceBus.

core/device/
		Contratos comunes de Device.

core/provider/
		Implementaciones y contratos de Providers.

core/profile/
		Drafts, snapshots y compilación de Profiles
		y Configurations.

core/graph/
		Topología lógica, validación y snapshots
		de DeviceGraph.

core/composition/
		SystemProfile Draft–Snapshot,
		DeviceGraphAssembler futuro
		y pipeline de composición.

core/catalog/
		DeviceCatalog Draft–Snapshot y resolución
		exacta de DeviceProfiles.

core/debug/
		Observación y diagnóstico del Core.

profiles/
		Estructura persistente futura para perfiles
		y configuraciones.

test/core/
		Pruebas unitarias y de integración del Core.

test/tools/
		Runner y Dashboard de pruebas.
```

Los sistemas físicos pueden usar infraestructura del Core cuando necesiten intercambiar información con otros subsistemas.

El Core no absorbe lógica interna del vehículo únicamente para centralizarla.

Hover, sustentación, dirección, propulsión y frenado permanecen en sus módulos específicos.

## 5. Mapa de componentes del Core

| Componente | Responsabilidad | Estado arquitectónico |
|---|---|---|
| DeviceBus | Transportar mensajes mediante bounded FIFO dispatch | ADR-001, ADR-004 y ADR-007 implementados y verificados |
| DeviceBusDispatchPolicy | Definir límites configurables y hard maximums | Runtime Safety Design 1.1 implementado |
| DeviceBusDispatchReport | Describir cada Dispatch Cycle | Runtime Safety Design 1.1 implementado |
| BusTopics | Proporcionar identidades canónicas StringName | ADR-005 implementado y verificado |
| BusMessage | Representar un envelope inmutable por contrato | ADR-005 implementado y verificado |
| Device | Componer identidad, manifest, estado, health y lifecycle | ADR-006 implementado y verificado |
| DeviceIdentity | Representar identidad lógica de Device | Implementado y verificado |
| DeviceManifest | Declarar capabilities, publishes, subscribes y requirements | Implementado y verificado |
| DeviceState | Representar validez y timestamp | Implementado y verificado |
| DeviceHealth | Representar condición operacional, faults y warnings | Implementado y verificado |
| DeviceLifecycle | Representar etapas y transiciones operacionales | Implementado y verificado |
| Provider | Producir datos mediante un contrato de comportamiento | ADR-003 y Provider System Design 1.1 implementados |
| DeviceRoles | Proporcionar roles principales canónicos | ADR-008 implementado y verificado |
| DeviceProfileDraft | Representar una definición editable | ADR-008 implementado y verificado |
| DeviceProfile | Representar un snapshot validado de modelo | ADR-008 implementado y verificado |
| DeviceProfileCompiler | Compilar Profile Draft a snapshot | ADR-008 implementado y verificado |
| DeviceConfigurationDraft | Representar configuración editable de instancia | ADR-008 implementado y verificado |
| DeviceConfiguration | Representar configuración validada de instancia | ADR-008 implementado y verificado |
| DeviceConfigurationCompiler | Compilar Configuration Draft a snapshot | ADR-008 implementado y verificado |
| DeviceManifestBuilder | Construir Manifest efectivo desde snapshots | ADR-008 implementado y verificado |
| ValidationIssue | Representar un resultado individual de validación | Implementado y verificado |
| ValidationReport | Reunir Issues y decidir validez por contexto | Implementado y verificado |
| PortSemanticKinds | Proporcionar significado lógico de Ports | ADR-002 implementado y verificado |
| DeviceGraphInputPort | Representar un Topic consumido | ADR-002 implementado y verificado |
| DeviceGraphOutputPort | Representar un Topic publicado | ADR-002 implementado y verificado |
| DeviceGraphTopicChannel | Representar un canal lógico de DeviceBus | ADR-002 implementado y verificado |
| DeviceGraphConnection | Representar una relación lógica entre Ports | ADR-002 implementado y verificado |
| DeviceGraphNode | Representar una instancia lógica dentro del Graph | ADR-002 implementado y verificado |
| DeviceGraphNodeBuilder | Construir Graph Nodes desde snapshots | ADR-002 implementado y verificado |
| DeviceGraphDraft | Mantener topología editable y transaccional | ADR-002 implementado y verificado |
| DeviceGraphValidator | Validar topología y detectar ciclos iterativamente | ADR-002 implementado y verificado |
| DeviceGraphSnapshot | Representar topología validada e inmutable | ADR-002 implementado y verificado |
| DeviceGraphSnapshotResult | Describir creación transaccional de Snapshot | ADR-002 implementado y verificado |
| SystemConnectionSpec | Representar endpoints persistibles antes de construir DeviceGraph | ADR-009 implementado y verificado |
| SystemProfileDraft | Representar una composición editable | ADR-009 implementado y verificado |
| DeviceProfileResolver | Resolver DeviceProfile mediante ID y versión exacta | Contrato por comportamiento implementado y verificado |
| SystemProfileCompiler | Compilar SystemProfileDraft a snapshot | ADR-009 implementado y verificado |
| SystemProfile | Representar una composición validada e inmutable | ADR-009 implementado y verificado |
| SystemProfileCompileResult | Describir compilación transaccional de SystemProfile | Implementado y verificado |
| DeviceCatalogDraft | Representar una colección editable de DeviceProfiles | DeviceCatalog Design 1.1 implementado y verificado |
| DeviceCatalog | Resolver DeviceProfiles mediante ID y versión exacta | ADR-009 y DeviceCatalog Design 1.1 implementados y verificados |
| DeviceCatalogCompileResult | Describir compilación transaccional del catálogo | Implementado y verificado |
| DeviceCatalogCompiler | Compilar DeviceCatalogDraft a snapshot | Implementado y verificado |
| DeviceGraphAssembler | Construir DeviceGraphSnapshot desde SystemProfile | ADR-009 aceptado; DeviceGraphAssembler Design 1.0 activo; implementación pendiente |
| DeviceGraphAssemblyResult | Describir ensamblaje transaccional de Graph | DeviceGraphAssembler Design 1.0 activo; implementación pendiente |
| RuntimeFactoryRegistry | Resolver factories ejecutables | ADR-009 aceptado; implementación futura |
| CompositionCompiler | Convertir DeviceGraphSnapshot en CompositionPlan | ADR-009 aceptado; implementación futura |
| CompositionPlan | Representar instrucciones runtime inmutables | ADR-009 aceptado; implementación futura |
| CompositionRuntime | Ejecutar CompositionPlan y poseer recursos activos | ADR-009 aceptado; implementación futura |
| Measurement | Representar un dato producido por un Sensor | Concepto definido; contrato pendiente |

Un componente pendiente solo se implementará cuando exista una necesidad verificable y su responsabilidad esté definida.

## 6. Responsabilidades de los componentes

### 6.1 DeviceBus

DeviceBus gestiona intercambio desacoplado de mensajes.

Puede:

- registrar suscriptores;
- eliminar suscriptores;
- publicar mensajes;
- consultar registros;
- limpiar registros;
- ejecutar dispatch FIFO iterativo;
- limitar publicaciones;
- limitar callbacks;
- limitar queue;
- limitar tiempo;
- abortar de manera controlada;
- producir DispatchReport;
- recuperarse en ciclos posteriores.

No puede:

- crear Devices;
- descubrir Devices;
- almacenar estado funcional;
- interpretar mensajes;
- transformar mensajes;
- realizar cálculos físicos;
- conocer Providers;
- conocer sensores concretos;
- registrar logs;
- serializar datos;
- comunicarse por red;
- acceder a hardware;
- validar DeviceGraph.

DeviceBus transporta información sin conocer su significado.

### 6.2 Device

Device es una unidad funcional lógica que puede interactuar con DeviceBus.

Puede actuar como:

- productor;
- consumidor;
- productor y consumidor.

Los Devices no utilizan referencias directas como mecanismo principal de comunicación.

Los componentes internos de una misma responsabilidad pueden colaborar mediante composición sin convertirse automáticamente en participantes del Bus.

Device mantiene separados:

- Identity;
- Manifest;
- State;
- Health;
- Lifecycle.

### 6.3 Provider

Provider es un rol arquitectónico basado en comportamiento.

Responsabilidad:

> Producir datos desde una fuente concreta.

La fuente puede ser:

- mundo físico de Godot;
- simulación;
- grabación;
- prueba;
- conexión externa;
- hardware futuro.

Provider no:

- decide consumidores;
- distribuye mensajes;
- modifica HUD;
- controla la nave;
- hereda obligatoriamente de una clase universal.

Cada familia de Provider define su propio contrato.

### 6.4 DeviceProfile y DeviceConfiguration

DeviceProfile representa el modelo validado de un tipo de Device.

DeviceConfiguration representa la configuración validada de una instancia.

Flujo:

```text
DeviceProfileDraft
→ DeviceProfileCompiler
→ DeviceProfile

DeviceConfigurationDraft
→ DeviceConfigurationCompiler
→ DeviceConfiguration

Snapshots
→ DeviceManifestBuilder
→ DeviceManifest
```

Drafts son editables.

Snapshots son inmutables por contrato.

DeviceGraph recibe snapshots validados.

No compila Drafts.

### 6.5 DeviceGraph

DeviceGraph representa topología lógica.

Se divide en:

```text
DeviceGraphDraft
		Topología editable.

DeviceGraphValidator
		Validación global sin mutación.

DeviceGraphSnapshot
		Topología validada e inmutable.
```

DeviceGraph representa:

- Devices;
- InputPorts;
- OutputPorts;
- TopicChannels;
- Connections;
- fan-out;
- cardinalidad de InputPorts;
- ciclos dirigidos.

DeviceGraph no:

- transporta mensajes;
- sustituye DeviceBus;
- crea Devices runtime;
- controla Lifecycle;
- ejecuta comportamiento;
- serializa archivos;
- dibuja UI;
- decide Hardware Mode;
- demuestra estabilidad matemática;
- inventa fronteras temporales.

Fan-out está permitido.

Fan-in implícito está rechazado.

Un ciclo sin evidencia temporal produce:

```text
SIMULATION_HAZARD
```

Esto permite Simulation Mode y bloquea Hardware Mode.

DeviceGraphSnapshot representa estructura.

No es un plan ejecutable.

### 6.6 System Composition

System Composition transforma una definición editable en una composición validada, una topología lógica, un plan y finalmente un runtime activo.

```text
SystemProfileDraft
		│
		▼
SystemProfileCompiler
		│
		▼
SystemProfile
		│
		▼
DeviceGraphAssembler
		│
		▼
DeviceGraphSnapshot
		│
		▼
CompositionCompiler
		│
		▼
CompositionPlan
		│
		▼
CompositionRuntime
```

SystemProfile utiliza referencias exactas:

```text
Profile ID
+
Profile Version
```

DeviceProfileResolver resuelve esas referencias.

DeviceCatalog implementa DeviceProfileResolver.

RuntimeFactoryRegistry permanece separado de DeviceCatalog.

```text
DeviceCatalog:
qué definición lógica existe.

RuntimeFactoryRegistry:
cómo construir su implementación runtime.
```

Persistencia permanece externa al Core lógico.

SystemProfile no abre ni guarda archivos.

SystemProfile contiene:

- identidad;
- versión;
- Display Name;
- descripción;
- Activation Context;
- DeviceConfiguration snapshots;
- SystemConnectionSpecs.

SystemProfileCompiler valida:

- identidad;
- contexto;
- Configurations;
- Device IDs;
- referencias exactas;
- dependencias;
- Connection Specs;
- endpoints conocidos.

SystemProfileCompiler no valida Ports.

#### DeviceCatalog

DeviceCatalog utiliza:

```text
DeviceCatalogDraft
		│
		▼
DeviceCatalogCompiler
		│
		▼
DeviceCatalog
```

DeviceCatalog está implementado y verificado.

Propiedades:

- snapshot inmutable;
- resolución exacta;
- múltiples versiones;
- duplicados exactos bloqueados;
- orden preservado;
- Arrays independientes;
- sin overwrite;
- sin latest;
- sin factories;
- sin filesystem.

#### DeviceGraphAssembler

DeviceGraphAssembler Design 1.0 está activo.

Responsabilidad:

> Construir DeviceGraphSnapshot desde SystemProfile y DeviceProfileResolver.

Pipeline interno:

```text
SystemProfile
		│
		▼
DeviceProfileResolver
		│
		▼
DeviceManifestBuilder
		│
		▼
DeviceGraphNodeBuilder
		│
		▼
DeviceGraphDraft
		│
		▼
connect_ports()
		│
		▼
create_snapshot()
		│
		▼
DeviceGraphSnapshot
```

DeviceGraphAssembler 1.0:

- soportará Simulation;
- rechazará Hardware explícitamente;
- agregará errores por etapas;
- procesará Devices antes de Connections;
- no expondrá Graph parcial;
- conservará orden;
- no modificará entradas;
- no creará Devices runtime;
- no conocerá factories;
- no abrirá archivos.

#### Etapas posteriores

CompositionCompiler producirá CompositionPlan.

CompositionPlan no ejecutará.

CompositionRuntime poseerá:

- DeviceBus activo;
- Devices activos;
- suscripciones;
- lifecycle;
- shutdown;
- supervisión runtime.

### 6.7 Measurement

Measurement representa conceptualmente un dato producido por un Sensor.

Ejemplos:

- distancia;
- orientación;
- velocidad;
- temperatura;
- energía;
- fuerza aplicada.

DeviceBus no conoce su contenido concreto.

Measurement Identity, provenance y snapshots de datos permanecen pendientes.

## 7. Reglas de dependencia

1. DeviceBus no depende de Devices concretos.

2. DeviceGraph no depende de DeviceBus runtime.

3. SystemProfile no depende de DeviceGraph.

4. SystemProfile no depende de filesystem.

5. SystemProfileCompiler depende de DeviceProfileResolver por comportamiento.

6. DeviceCatalog implementa DeviceProfileResolver.

7. DeviceCatalog no depende de SystemProfileCompiler.

8. DeviceCatalog no depende de runtime factories.

9. DeviceGraphAssembler depende del comportamiento de DeviceProfileResolver.

10. DeviceGraphAssembler no depende de la clase concreta DeviceCatalog.

11. DeviceGraphAssembler no depende de runtime factories.

12. CompositionCompiler no ejecuta CompositionPlan.

13. Un productor no conoce a sus consumidores.

14. Un consumidor no necesita conocer la implementación del productor.

15. Un Provider no conoce los destinos finales de sus datos.

16. Presentación depende de datos estructurados; los datos no dependen de presentación.

17. Telemetría depende del estado; el juego no depende de telemetría.

18. Hardware depende de contratos de plataforma; el Core no depende de hardware concreto.

19. Ningún componente crea otro si esa creación no forma parte de su responsabilidad.

20. Las dependencias se entregan explícitamente cuando sea posible.

21. Añadir un consumidor no obliga a modificar al productor.

22. Drafts no se utilizan directamente por runtime.

23. Runtime utiliza snapshots o planes compilados.

Dirección general:

```text
Presentación
Integraciones
Hardware
Devices concretos
		  │
		  ▼
Contratos del Core
		  ▲
		  │
Componentes del Core
```

## 8. Flujo conceptual de información

Flujo runtime básico:

```text
Fuente de datos
		  │
		  ▼
Provider
		  │
		  ▼
Publisher Device
		  │
		  ▼
DeviceBus
		  │
		  ▼
Consumer Device
		  │
		  ▼
Sistema consumidor
```

Cada bloque responde una pregunta diferente:

```text
Provider:
¿Qué dato puedo producir?

Publisher Device:
¿Cuándo y bajo qué identidad publico?

DeviceBus:
¿A qué suscriptores entrego?

Consumer Device:
¿Qué hago con el mensaje?

Sistema consumidor:
¿Cómo utiliza el dominio esa información?
```

DeviceBus no responde las demás preguntas.

## 9. Flujo futuro de telemetría

```text
Estado del juego
		  │
		  ▼
Telemetry Bridge
		  │
		  ▼
Serialización
		  │
		  ▼
Transporte
		  │
		  ▼
Raspberry Pi Zero 2 W
		  │
		  ▼
Módulos especializados
```

El estado del juego no conoce:

- dirección IP;
- formato físico de cabina;
- indicador conectado;
- tecnología analógica o digital;
- estilo visual.

La Raspberry Pi puede actuar como Sim-Brain.

Los módulos especializados reciben únicamente la información útil para su responsabilidad.

La apariencia de cabina es independiente del significado interno de los datos.

## 10. Integración con Godot

Godot Engine 4.7.1 es el host de ejecución actual.

El SceneTree no define la arquitectura del Core.

Escenas y Nodes pueden:

- representar objetos físicos;
- participar en lifecycle de Godot;
- acceder al mundo 3D;
- recibir input;
- mostrar información;
- reproducir audio;
- adaptar datos del Core al engine.

Los componentes del Core evitan depender de:

- rutas concretas;
- búsquedas globales;
- escenas específicas;
- componentes visuales;
- editor;
- Signals como columna vertebral entre subsistemas.

Signals pueden utilizarse dentro de un componente cuando sean apropiadas.

DeviceBus no es autoload ni singleton por conveniencia.

### 10.1 Propiedad de DeviceBus

Cada contexto de ejecución tiene una Composition Root explícita.

La Composition Root:

- crea DeviceBus;
- conserva su referencia principal;
- entrega la misma instancia;
- coordina inicialización;
- coordina cierre;
- limpia el Bus;
- libera referencias.

DeviceBus no es:

- Node hijo;
- autoload;
- singleton global;
- dependencia descubierta mediante rutas.

Composition Root es un rol arquitectónico.

No obliga todavía a crear una clase concreta con ese nombre.

## 11. Estado y representación

Estado de simulación y representación permanecen separados.

```text
Simulación
		│
		▼
Estado estructurado
		│
		├──► HUD
		├──► Debug
		├──► IA
		├──► Replay
		└──► Telemetría
```

HUD, telemetría y cabina física no son propietarios del estado.

Cada consumidor puede transformar datos para presentación, pero no modifica la verdad interna.

Las unidades internas siguen el Sistema Internacional.

Las conversiones de presentación ocurren fuera del estado canónico.

## 12. Invariantes generales

1. Cada componente tiene una responsabilidad principal.

2. Arquitectura precede al código.

3. UI nunca define el modelo interno.

4. Componentes concretos dependen de contratos estables.

5. Añadir un consumidor no modifica un productor.

6. Ningún componente conoce infraestructura innecesaria.

7. Telemetría es consumidor, no dependencia del juego.

8. Pruebas aceptadas son baselines inmutables.

9. Una nueva integración requiere prueba sucesora.

10. Responsabilidad incorrecta se rediseña; no se parchea.

11. Composición se prefiere sobre herencia.

12. No se añade abstracción sin necesidad concreta.

13. Documentación arquitectónica forma parte del producto.

14. Decisiones estructurales se registran.

15. Drafts pueden estar incompletos.

16. Runtime utiliza snapshots inmutables.

17. Operaciones fallidas conservan Last Known Good.

18. La simulación puede fallar; el simulador no.

19. Algoritmos sobre datos del usuario no utilizan recursión ilimitada.

20. Hardware requiere validación más estricta que Simulation.

21. DeviceGraph representa topología, no ejecución.

22. DeviceBus transporta mensajes, no topología.

23. SystemProfile representa composición, no Graph.

24. DeviceProfileResolver utiliza ID y versión exactos.

25. DeviceCatalog es estable e inmutable.

26. No existe fallback automático de Profile version.

27. RuntimeFactoryRegistry permanece separado de DeviceCatalog.

28. DeviceGraphAssembler no crea runtime.

29. DeviceGraphAssembler no expone Graph parcial.

30. CompositionCompiler será obligatorio antes de runtime compuesto.

31. CompositionRuntime será propietario de recursos activos.

## 13. Composición y comunicación

DeviceGraph no se inserta físicamente dentro del transporte de cada mensaje.

Flujo de composición:

```text
SystemProfileDraft
		│
		▼
SystemProfileCompiler
		│
		▼
SystemProfile
		│
		▼
DeviceGraphAssembler
		│
		▼
DeviceGraphSnapshot
		│
		▼
CompositionCompiler
		│
		▼
CompositionPlan
		│
		▼
CompositionRuntime
```

Resolución lógica:

```text
DeviceCatalog
		│
		├──► SystemProfileCompiler
		└──► DeviceGraphAssembler
```

Flujo de mensajes runtime:

```text
Publisher
		│
		▼
DeviceBus
		│
		▼
Consumer
```

SystemProfile describe composición.

DeviceCatalog resuelve definiciones.

DeviceGraphAssembler construye topología.

DeviceGraph valida topología.

CompositionCompiler produce instrucciones.

CompositionRuntime crea participantes y suscripciones.

DeviceBus transporta mensajes.

Las responsabilidades permanecen separadas.

## 14. Decisiones vigentes

### VP-001 — Architecture Precedes Code

Toda característica importante sigue:

```text
Problema
→ Análisis
→ ADR
→ Diseño
→ Implementación
→ Pruebas unitarias
→ Pruebas de integración
→ Refactorización
```

### VP-002 — The Simulation May Fail; The Simulator Must Not

Velocity permite degradación, inestabilidad, daño y fallo dentro de la simulación.

Ninguna ejecución puede comprometer:

- Core;
- editor;
- proceso principal;
- memoria;
- stack;
- datos persistentes;
- definiciones canónicas;
- hardware real;
- capacidad de detener y recuperar.

Contextos:

```text
Draft

Active Simulation

Active Hardware
```

Categorías:

```text
Structural Error

Platform Safety Error

Simulation Hazard

Hardware Safety Error
```

### ADR-001 — DeviceBus

DeviceBus gestiona intercambio desacoplado de mensajes.

### ADR-002 — DeviceGraph

DeviceGraph representa y valida topología lógica.

Draft, Validator y Snapshot permanecen separados de runtime y UI.

### ADR-003 — Provider System

Provider es un rol basado en comportamiento.

No existe clase base universal obligatoria.

### ADR-004 — DeviceBus Ownership and Composition

Composition Root posee y distribuye explícitamente DeviceBus.

DeviceBus no es singleton global.

### ADR-005 — Topic and Message Contract

Topics utilizan StringName.

BusTopics es catálogo canónico.

BusMessage es RefCounted construido completamente y sin setters públicos.

### ADR-006 — Device Core Contract

Device es RefCounted y compone:

```text
DeviceIdentity
DeviceManifest
DeviceState
DeviceHealth
DeviceLifecycle
```

### ADR-007 — Bounded Dispatch and Runtime Safety

DeviceBus utiliza FIFO iterativo con:

- Publication Budget;
- Callback Budget;
- Queue Size Limit;
- Time Budget;
- hard maximums;
- aborto controlado;
- DispatchReport;
- recuperación.

### ADR-008 — Device Definitions, Profiles and Configuration

Velocity separa:

```text
DeviceProfileDraft
DeviceProfile
DeviceConfigurationDraft
DeviceConfiguration
DeviceManifest
SystemProfile
```

Drafts son editables.

Snapshots son validados e inmutables por contrato.

### ADR-009 — System Composition Pipeline

Velocity separa:

```text
SystemProfileDraft

SystemProfileCompiler

SystemProfile

DeviceGraphAssembler

DeviceGraphSnapshot

CompositionCompiler

CompositionPlan

CompositionRuntime
```

SystemProfile utiliza referencias exactas:

```text
Profile ID
+
Profile Version
```

DeviceProfileResolver es un rol por comportamiento.

DeviceCatalog implementa ese contrato.

DeviceCatalog y RuntimeFactoryRegistry permanecen separados.

SystemProfile es un snapshot RefCounted independiente de persistencia.

DeviceGraphAssembler convierte composición validada en topología validada.

CompositionCompiler produce un plan y no ejecuta runtime.

## 15. Estado vigente y trabajo futuro

### 15.1 Implementado y verificado

```text
DeviceBus

Bounded FIFO Dispatch

Runtime Safety Policy

Dispatch Reports

Topic and Message Contract

Provider System

Device Core

DeviceProfile Draft–Snapshot

DeviceConfiguration Draft–Snapshot

DeviceManifestBuilder

ValidationIssue y ValidationReport

DeviceGraph Primitives

DeviceGraphNodeBuilder

DeviceGraphDraft

DeviceGraph Connections

DeviceGraphValidator

Fan-in Protection

Iterative Cycle Detection

DeviceGraphSnapshot

DeviceGraphSnapshotResult

SystemConnectionSpec

SystemProfileDraft

DeviceProfileResolver contract

SystemProfileCompiler

SystemProfile

SystemProfileCompileResult

DeviceCatalogDraft

DeviceCatalogCompiler

DeviceCatalog

DeviceCatalogCompileResult

SystemProfile–DeviceCatalog Integration

Velocity Test Runner

Velocity Test Dashboard
```

### 15.2 Diseño activo

```text
DeviceGraphAssembler

DeviceGraphAssemblyResult
```

### 15.3 Pendiente

```text
Measurement Identity

Measurement snapshots y provenance

DeviceCatalogDocument

DeviceCatalogLoader

DeviceCatalogSerializer

Save As Service

SystemProfileDocument

SystemProfileLoader

SystemProfileSerializer

RuntimeFactoryRegistry

CompositionCompiler

CompositionPlan

CompositionRuntime

Temporal Boundary metadata

Zero-delay classification

Named Input Slots

Port cardinality configurable

Merge Device canónico

ConfigurationEditor

GraphEditor

GraphLayout

Runtime Safety externo

Callbacks no confiables

Hardware Mode compiler

DeviceCalibration

AdaptationPolicy

RuntimeAllocation
```

La presencia de un elemento en diseño activo o pendiente no implica implementación completada.

Cada milestone requiere diseño aceptado, código incremental y pruebas sucesoras.

## 16. Regla de evolución

Antes de modificar un componente importante no se pregunta:

> ¿Qué código debemos cambiar?

Se pregunta:

> ¿Sigue siendo correcta la responsabilidad?

Si la responsabilidad sigue siendo correcta, la implementación evoluciona dentro de sus límites.

Si dejó de ser correcta, el componente se rediseña.

No se añade un parche para conservar una responsabilidad equivocada.

La meta es que cada componente pueda ser comprendido, probado y sustituido de forma independiente.

## 17. System Integrity y experimentación

Velocity separa:

```text
fallo del sistema simulado

fallo de la plataforma de simulación
```

La simulación puede representar:

- pérdida de sustentación;
- sobretemperatura;
- batería agotada;
- control inestable;
- sensores defectuosos;
- actuadores degradados;
- configuraciones físicamente malas;
- ciclos de control experimentales.

La plataforma no puede permitir:

- stack overflow;
- recursión ilimitada;
- message storm ilimitada;
- crecimiento ilimitado de memoria;
- bloqueo permanente del proceso principal;
- corrupción de snapshots;
- pérdida de Last Known Good;
- activación accidental de hardware;
- pérdida de control del editor.

### 17.1 Draft

Draft puede estar:

- incompleto;
- desconectado;
- degradado;
- experimental.

Draft no ejecuta.

### 17.2 Active Simulation

Active Simulation puede aceptar:

- INFO;
- WARNING;
- SIMULATION_HAZARD;
- Hardware Safety Error cuando la política lo permita en simulación.

No acepta:

- Structural Error;
- Platform Safety Error.

### 17.3 Active Hardware

Active Hardware requiere validación completa para hardware.

No acepta:

- Structural Error;
- Platform Safety Error;
- Simulation Hazard;
- Hardware Safety Error.

### 17.4 Defensa en profundidad

```text
Draft validation

+

Snapshot validation

+

Dependency resolution

+

Graph assembly

+

CompositionCompiler validation

+

DeviceBus Runtime Safety

+

Runtime supervision
```

Una capa no sustituye a las demás.

La regla final permanece:

> La simulación puede fallar. El simulador no.