# Velocity — Arquitectura del Núcleo

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 2.13 |
| Fecha inicial | 2026-08-14 |
| Última revisión | 25/08/2026 |
| Alcance | Núcleo lógico de Velocity |

## 1. Propósito

Este documento describe cómo encajan los componentes principales del núcleo de Velocity y establece los límites que deben respetar sus implementaciones.

Los ADR explican por qué se tomó una decisión arquitectónica.

Este documento explica cómo se relacionan las decisiones aceptadas y los componentes resultantes.

La Arquitectura del Núcleo es un documento vivo.

Debe reflejar la arquitectura vigente, no el historial cronológico.

Su propósito es permitir que cada componente pueda ser:

- comprendido independientemente;
- probado de forma aislada;
- sustituido sin modificar consumidores ajenos;
- reutilizado;
- extendido sin romper responsabilidades existentes.

Este documento no contiene:

- código de implementación;
- resultados cronológicos;
- soluciones temporales;
- detalles visuales;
- propuestas rechazadas como si fueran vigentes.

## 2. Definición del Core

El Core es el conjunto de contratos, mecanismos y reglas compartidas que permiten que los subsistemas de Velocity colaboren sin depender de implementaciones concretas.

El Core proporciona infraestructura común.

No implementa:

- comportamiento específico del vehículo;
- presentación visual;
- integración concreta con hardware;
- herramientas visuales;
- persistencia de usuario.

Conceptos actuales:

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
- Runtime Construction;
- System Composition;
- estado;
- health;
- lifecycle.

Cada componente conserva una responsabilidad independiente.

## 3. Límites del Core

El Core no debe:

- leer directamente input del jugador;
- aplicar fuerzas sobre la nave;
- descubrir dependencias mediante SceneTree;
- dibujar interfaces;
- controlar cámaras;
- serializar telemetría;
- abrir conexiones de red;
- acceder directamente a GPIO, I2C, SPI o serial;
- conocer dispositivos concretos;
- depender de una cabina física;
- depender de representación visual.

Dirección general:

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

Sistemas externos dependen de contratos del Core.

El Core no depende de esos sistemas externos.

## 4. Organización

```text
core/bus/
		DeviceBus y Runtime Safety.

core/device/
		Device Core.

core/provider/
		Providers.

core/profile/
		DeviceProfile y DeviceConfiguration.

core/graph/
		DeviceGraph.

core/composition/
		SystemProfile y DeviceGraphAssembler.

core/catalog/
		DeviceCatalog.

core/runtime/
		Runtime Construction Contracts.

core/debug/
		Observación y diagnóstico.

profiles/
		Estructura persistente futura.

test/core/
		Pruebas del Core.

test/tools/
		Runner y Dashboard.

docs/project_state/
		Handoff, Resume Prompt
		y Collaboration Contract.
```

Godot Engine 4.7.1 es el host actual.

El SceneTree no define la arquitectura del Core.

## 5. Mapa de componentes

| Componente | Responsabilidad | Estado |
|---|---|---|
| DeviceBus | Transportar mensajes mediante bounded FIFO | Implementado y verificado |
| DeviceBusDispatchPolicy | Definir budgets y hard maximums | Implementado y verificado |
| DeviceBusDispatchReport | Describir Dispatch Cycle | Implementado y verificado |
| BusTopics | Identidades canónicas de Topics | Implementado y verificado |
| BusMessage | Envelope inmutable por contrato | Implementado y verificado |
| Device | Componer contratos comunes | Implementado y verificado |
| DeviceIdentity | Identidad lógica | Implementado y verificado |
| DeviceManifest | Interfaz efectiva | Implementado y verificado |
| DeviceState | Validez y timestamp | Implementado y verificado |
| DeviceHealth | Condición operacional | Implementado y verificado |
| DeviceLifecycle | Etapas operacionales | Implementado y verificado |
| Provider | Producir datos mediante comportamiento | Implementado y verificado |
| DeviceRoles | Roles canónicos | Implementado y verificado |
| DeviceProfileDraft | Definición editable | Implementado y verificado |
| DeviceProfile | Modelo validado | Implementado y verificado |
| DeviceProfileCompiler | Compilar Profile Draft | Implementado y verificado |
| DeviceConfigurationDraft | Configuración editable | Implementado y verificado |
| DeviceConfiguration | Configuración validada | Implementado y verificado |
| DeviceConfigurationCompiler | Compilar Configuration Draft | Implementado y verificado |
| DeviceManifestBuilder | Construir Manifest efectivo | Implementado y verificado |
| ValidationIssue | Resultado individual | Implementado y verificado |
| ValidationReport | Agregar validación por contexto | Implementado y verificado |
| PortSemanticKinds | Semántica de Ports | Implementado y verificado |
| DeviceGraphInputPort | Topic consumido | Implementado y verificado |
| DeviceGraphOutputPort | Topic publicado | Implementado y verificado |
| DeviceGraphTopicChannel | Canal lógico | Implementado y verificado |
| DeviceGraphConnection | Relación entre Ports | Implementado y verificado |
| DeviceGraphNode | Instancia lógica | Implementado y verificado |
| DeviceGraphNodeBuilder | Construir Graph Node | Implementado y verificado |
| DeviceGraphDraft | Topología editable | Implementado y verificado |
| DeviceGraphValidator | Validación global y ciclos | Implementado y verificado |
| DeviceGraphSnapshot | Topología inmutable | Implementado y verificado |
| DeviceGraphSnapshotResult | Resultado de Snapshot | Implementado y verificado |
| SystemConnectionSpec | Endpoints persistibles | Implementado y verificado |
| SystemProfileDraft | Composición editable | Implementado y verificado |
| SystemProfileCompiler | Compilar composición | Implementado y verificado |
| SystemProfile | Composición inmutable | Implementado y verificado |
| SystemProfileCompileResult | Resultado de compilación | Implementado y verificado |
| DeviceProfileResolver | Resolución exacta por comportamiento | Implementado y verificado |
| DeviceCatalogDraft | Profiles editables | Implementado y verificado |
| DeviceCatalogCompiler | Compilar catálogo | Implementado y verificado |
| DeviceCatalog | Resolver Profiles exactos | Implementado y verificado |
| DeviceCatalogCompileResult | Resultado de catálogo | Implementado y verificado |
| DeviceGraphAssembler | Construir Graph desde SystemProfile | Implementado y verificado |
| DeviceGraphAssemblyResult | Resultado de Graph assembly | Implementado y verificado |
| RuntimeFactoryKey | Identidad exacta de factory | Diseño activo; siguiente implementación |
| RuntimeDependencyBinding | Dependencia con ownership | Diseño activo |
| RuntimeConstructionRequest | Request pre-resuelto | Diseño activo |
| RuntimeDeviceHandle | Producto y ownership runtime | Diseño activo |
| RuntimeFactoryBuildResult | Resultado de factory | Diseño activo |
| RuntimeFactory behavior | Construcción y release | Diseño activo |
| RuntimeHost behavior | Attach y detach | Diseño activo |
| RuntimeFactoryRegistry | Resolver factories exactas | Pendiente de diseño propio |
| CompositionPlan | Instrucciones runtime | Pendiente de diseño propio |
| CompositionCompiler | Compilar Snapshot a Plan | Pendiente |
| CompositionRuntime | Ejecutar Plan | Pendiente |
| Measurement | Dato de Sensor | Contrato pendiente |

## 6. DeviceBus

DeviceBus transporta información sin interpretar su significado.

Puede:

- registrar suscriptores;
- eliminar suscriptores;
- publicar;
- limpiar;
- ejecutar FIFO iterativo;
- aplicar budgets;
- abortar controladamente;
- producir DispatchReport;
- recuperarse.

No:

- crea Devices;
- descubre Devices;
- interpreta payload;
- valida Graph;
- conoce Providers;
- conoce hardware.

DeviceBus tiene owner explícito.

No es autoload ni singleton por comodidad.

## 7. Device Core

Device es RefCounted y compone:

```text
DeviceIdentity

DeviceManifest

DeviceState

DeviceHealth

DeviceLifecycle
```

Lifecycle:

```text
CREATED

INITIALIZED

READY

RUNNING

SHUTDOWN
```

Health:

```text
HEALTHY

DEGRADED

CRITICAL

FAILED
```

Lifecycle y Health permanecen separados.

## 8. Provider

Provider es rol por comportamiento.

Responsabilidad:

> Producir datos desde una fuente concreta.

No existe clase base universal obligatoria.

Provider no decide consumidores ni distribuye mensajes.

## 9. Profile y Configuration

Pipeline:

```text
DeviceProfileDraft
		│
		▼
DeviceProfileCompiler
		│
		▼
DeviceProfile
```

```text
DeviceConfigurationDraft
		│
		▼
DeviceConfigurationCompiler
		│
		▼
DeviceConfiguration
```

```text
DeviceProfile
+
DeviceConfiguration
		│
		▼
DeviceManifestBuilder
		│
		▼
DeviceManifest
```

Drafts son editables.

Snapshots son inmutables.

Runtime no utiliza Drafts.

## 10. DeviceGraph

DeviceGraph se divide en:

```text
DeviceGraphDraft

DeviceGraphValidator

DeviceGraphSnapshot
```

Representa:

- Nodes;
- Ports;
- Topics;
- Connections;
- fan-out;
- cardinalidad;
- ciclos.

No transporta mensajes.

No crea Devices runtime.

No ejecuta.

No guarda archivos.

Fan-in implícito se rechaza.

Ciclos se detectan sin recursión.

Un ciclo sin evidencia temporal produce:

```text
SIMULATION_HAZARD

graph_cycle_requires_temporal_analysis
```

## 11. SystemProfile

Pipeline:

```text
SystemProfileDraft
		│
		▼
SystemProfileCompiler
		│
		▼
SystemProfile
```

SystemProfile contiene:

- identidad;
- versión;
- metadata;
- Activation Context;
- DeviceConfiguration snapshots;
- SystemConnectionSpecs.

SystemProfile utiliza:

```text
Profile ID

+

Profile Version
```

No depende de DeviceGraph.

No depende de filesystem.

No ejecuta.

## 12. DeviceCatalog

Pipeline:

```text
DeviceCatalogDraft
		│
		▼
DeviceCatalogCompiler
		│
		▼
DeviceCatalog
```

DeviceCatalog:

- es inmutable;
- resuelve ID y versión exactos;
- permite múltiples versiones;
- rechaza duplicado exacto;
- no implementa latest;
- no implementa fallback;
- no contiene factories;
- no abre archivos.

## 13. DeviceGraphAssembler

Pipeline:

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
DeviceGraphSnapshot
```

DeviceGraphAssembler:

- es stateless;
- soporta Simulation;
- rechaza Hardware;
- procesa Devices antes de Connections;
- agrega errores por etapas;
- no devuelve Graph parcial;
- conserva orden;
- no modifica entradas;
- no crea runtime.

## 14. Runtime Construction

Runtime Construction está definido por ADR-010.

Componentes:

```text
RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult

RuntimeFactory behavior

RuntimeHost behavior
```

Objetivo:

> Construir unidades runtime de forma atómica, con ownership y cleanup explícitos.

## 15. RuntimeFactoryKey

Identidad:

```text
Profile ID

+

Profile Version

+

Activation Context
```

No contiene:

```text
host_target
```

No existe:

- latest;
- fallback;
- sustitución de versión;
- sustitución de contexto.

CompositionPlan conservará Key, no factory.

## 16. RuntimeDependencyBinding

Estado conceptual:

```text
Dependency ID

Dependency Value

Ownership
```

Value:

```gdscript
Object
```

Ownership:

```text
BORROWED

TRANSFERRED
```

BORROWED conserva owner original.

TRANSFERRED cambia ownership durante factory build.

## 17. RuntimeConstructionRequest

Contiene:

- Device ID;
- DeviceConfiguration;
- RuntimeFactoryKey;
- RuntimeDependencyBindings pre-resueltos.

No es service locator.

No descubre dependencias.

No contiene SceneTree, autoload o filesystem.

Crear Request no transfiere ownership.

Invocar factory build inicia transferencia.

## 18. RuntimeDeviceHandle

Representa:

- identidad;
- Configuration;
- Factory Key;
- Primary Runtime Object;
- Host Objects;
- Dependency Bindings;
- ownership resultante.

Primary Runtime Object es Object no null.

Host Objects utilizan:

```gdscript
Array[Object]
```

Handle no coordina el sistema completo.

## 19. RuntimeFactory behavior

Contrato:

```gdscript
build(
	request: RuntimeConstructionRequest
) -> RuntimeFactoryBuildResult
```

```gdscript
release(
	handle: RuntimeDeviceHandle
) -> ValidationReport
```

Factory construye solamente.

No inicializa, inicia o adjunta.

La misma factory conoce cómo liberar su producto.

## 20. RuntimeHost behavior

Contrato:

```gdscript
attach(
	handle: RuntimeDeviceHandle
) -> ValidationReport
```

```gdscript
detach(
	handle: RuntimeDeviceHandle
) -> ValidationReport
```

RuntimeHost recibe Handle completo.

Interpreta Host Objects.

No sustituye factory release.

## 21. Construcción atómica

Factory build:

```text
Éxito:
Handle válido.

Fallo:
Handle null,
Report,
recursos parciales liberados.
```

Factory limpia bindings TRANSFERRED en fallo.

No libera BORROWED.

## 22. Rollback global

CompositionRuntime realizará rollback en orden inverso.

Si falla construcción:

```text
release Handles anteriores
```

Si falla attach:

```text
detach

release
```

Si falla lifecycle:

```text
shutdown

detach

release
```

Last Known Good permanece hasta commit completo.

## 23. DeviceBus y Runtime

DeviceBus pertenece a CompositionRuntime o Composition Root.

Factory no crea Bus global.

Factory no obtiene Bus mediante autoload.

Factory produce Handle en estado equivalente a CREATED.

DeviceBus se entrega durante inicialización coordinada.

## 24. System Composition Pipeline

Estado implementado:

```text
DeviceProfiles

↓

DeviceCatalog

↓

SystemProfile

↓

DeviceGraphAssembler

↓

DeviceGraphSnapshot
```

Estado diseñado:

```text
Runtime Construction Contract
```

Estado futuro:

```text
DeviceGraphSnapshot

↓

CompositionCompiler

↓

CompositionPlan

↓

CompositionRuntime
```

## 25. RuntimeFactoryRegistry futuro

Resolverá:

```text
RuntimeFactoryKey

→

RuntimeFactory
```

Contendrá comportamiento ejecutable.

Permanecerá separado de:

- DeviceCatalog;
- CompositionPlan.

Mutabilidad requiere diseño propio.

## 26. CompositionPlan futuro

Conservará:

- RuntimeFactoryKeys;
- dependency directives;
- lifecycle order;
- communication directives;
- runtime policies.

No conservará:

- RuntimeFactory;
- Callable;
- RuntimeDeviceHandle;
- Device activo;
- Node activo;
- DeviceBus activo.

## 27. CompositionCompiler futuro

Recibirá:

- DeviceGraphSnapshot;
- RuntimeFactoryRegistry;
- contexto;
- políticas.

Producirá CompositionPlan.

No:

- ejecuta factories;
- crea Devices;
- adjunta host objects;
- posee DeviceBus;
- activa runtime.

## 28. CompositionRuntime futuro

Recibirá:

- CompositionPlan;
- RuntimeFactoryRegistry;
- dependencies;
- RuntimeHost.

Poseerá:

- DeviceBus;
- Handles;
- host attachment;
- lifecycle;
- rollback;
- shutdown;
- Runtime Safety observation.

## 29. Reglas de dependencia

1. DeviceBus no depende de Devices concretos.

2. DeviceGraph no depende de DeviceBus runtime.

3. SystemProfile no depende de DeviceGraph.

4. DeviceCatalog no depende de SystemProfileCompiler.

5. DeviceCatalog no contiene factories.

6. DeviceGraphAssembler depende de resolver por comportamiento.

7. DeviceGraphAssembler no crea runtime.

8. RuntimeFactory recibe Request pre-resuelto.

9. RuntimeFactory no descubre dependencias.

10. RuntimeHost controla attach/detach.

11. CompositionPlan no contiene factory.

12. CompositionCompiler no ejecuta.

13. CompositionRuntime posee recursos activos.

14. UI depende del Core; Core no depende de UI.

15. Persistencia depende del modelo; modelo no depende del formato.

## 30. Invariantes generales

1. Arquitectura precede al código.

2. Una responsabilidad por componente.

3. Composición sobre herencia.

4. UI no define Core.

5. Dependencias explícitas.

6. Drafts son editables.

7. Snapshots son inmutables.

8. Operaciones fallidas conservan Last Known Good.

9. Pruebas aceptadas son baselines inmutables.

10. Algoritmos sobre datos del usuario no usan recursión ilimitada.

11. Hardware requiere validación más estricta.

12. Factory build es atómico.

13. Ownership de dependency es explícito.

14. Rollback global es inverso.

15. Plan no es ejecutable.

16. Toda modificación se entrega como archivo completo.

## 31. Integración con Godot

Godot Engine 4.7.1 es el host actual.

Los contratos base Runtime utilizan:

```text
Object
```

No utilizan:

- Node;
- Node3D;
- SceneTree;
- paths;
- autoloads.

Factories concretas pueden construir host objects.

RuntimeHost concreto los adapta.

## 32. Estado y representación

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

Presentación no posee estado canónico.

Unidades internas siguen Sistema Internacional.

## 33. Telemetría futura

```text
Estado
		│
		▼
Telemetry Bridge
		│
		▼
Serializer
		│
		▼
Transport
		│
		▼
Raspberry Pi
		│
		▼
Módulos
```

El juego no depende de telemetría.

## 34. Decisiones vigentes

```text
VP-001 — Architecture Precedes Code

VP-002 — The Simulation May Fail;
		 The Simulator Must Not

ADR-001 — DeviceBus

ADR-002 — DeviceGraph

ADR-003 — Provider System

ADR-004 — DeviceBus Ownership and Composition

ADR-005 — Topic and Message Contract

ADR-006 — Device Core Contract

ADR-007 — Bounded Dispatch and Runtime Safety

ADR-008 — Device Definitions, Profiles and Configuration

ADR-009 — System Composition Pipeline

ADR-010 — Runtime Construction and Factory Binding
```

## 35. Estado implementado

```text
DeviceBus

Runtime Safety

Topic and Message Contracts

Provider System

Device Core

DeviceProfile Draft–Snapshot

DeviceConfiguration Draft–Snapshot

DeviceManifestBuilder

DeviceGraph 1.0

SystemProfile 1.0

DeviceCatalog 1.0

DeviceGraphAssembler 1.0

Velocity Test Runner

Velocity Test Dashboard
```

## 36. Diseño activo

```text
Runtime Construction Contract 1.0

RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult

RuntimeFactory behavior

RuntimeHost behavior
```

## 37. Trabajo futuro

```text
RuntimeFactoryRegistry

CompositionPlan

CompositionCompiler

CompositionRuntime

RuntimeHost concreto

Factories de producción

Measurement Identity

Provenance

Temporal Boundary metadata

Zero-delay classification final

SystemProfile persistence

DeviceCatalog persistence

GraphEditor

ConfigurationEditor

GraphLayout

Hardware Mode

Calibration

AdaptationPolicy

RuntimeAllocation
```

## 38. VP-002

Contextos:

```text
Draft

Active Simulation

Active Hardware
```

Simulation puede aceptar Simulation Hazard.

Hardware no acepta:

- Structural Error;
- Platform Safety Error;
- Simulation Hazard;
- Hardware Safety Error.

La plataforma nunca permite:

- stack overflow;
- recursión ilimitada;
- memoria ilimitada;
- queue ilimitada;
- bloqueo;
- corrupción;
- pérdida de Last Known Good;
- hardware inseguro.

## 39. Defensa en profundidad

```text
Draft validation

+

Snapshot validation

+

Dependency resolution

+

Graph assembly

+

Runtime construction validation

+

CompositionCompiler validation

+

DeviceBus Runtime Safety

+

Runtime supervision
```

Una capa no sustituye a otra.

## 40. Persistencia

El Core lógico no abre ni guarda archivos cuando no es su responsabilidad.

Componentes externos futuros:

```text
SystemProfileDocument

SystemProfileLoader

SystemProfileSerializer

DeviceCatalogDocument

DeviceCatalogLoader

DeviceCatalogSerializer

SaveAsService
```

## 41. Project State

Continuidad protegida mediante:

```text
docs/project_state/
velocity_handoff.md

docs/project_state/
velocity_resume_prompt.md

docs/project_state/
velocity_collaboration_contract.md
```

Estos documentos permiten reanudar el proyecto en otro chat.

No sustituyen Git, ADR, diseños o tests.

## 42. Regla de evolución

Antes de cambiar código se pregunta:

> ¿Sigue siendo correcta la responsabilidad?

Si sí, se evoluciona dentro de límites.

Si no, se rediseña.

No se parchea una responsabilidad equivocada.

Toda modificación se entrega como archivo completo consolidado.

## 43. Siguiente paso

Implementar:

```text
RuntimeFactoryKey
```

Después:

```text
RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult

Runtime Construction Integration
```

No implementar RuntimeFactoryRegistry ni CompositionPlan antes de completar y verificar estos contratos.
