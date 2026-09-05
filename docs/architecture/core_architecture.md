# Velocity — Arquitectura del Núcleo

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 2.15 |
| Fecha inicial | 2026-08-14 |
| Última revisión | 05/09/2026 |
| Alcance | Núcleo lógico de Velocity |

## 1. Propósito

Este documento describe cómo encajan los componentes principales del núcleo de Velocity y establece los límites que deben respetar sus implementaciones.

Los ADR explican por qué se tomó una decisión arquitectónica.

Este documento explica cómo se relacionan las decisiones aceptadas y los componentes resultantes.

Core Architecture es un documento vivo.

Debe reflejar la arquitectura vigente, no el historial cronológico.

Su propósito es permitir que cada componente pueda ser:

- comprendido independientemente;
- probado de forma aislada;
- sustituido sin modificar consumidores ajenos;
- reutilizado;
- extendido sin romper responsabilidades existentes.

No contiene:

- código de implementación;
- soluciones temporales;
- propuestas rechazadas como vigentes;
- detalles visuales;
- historial de conversación.

## 2. Definición del Core

Core es el conjunto de contratos, mecanismos y reglas que permiten colaboración sin depender de implementaciones concretas.

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
- RuntimeFactoryRegistry;
- CompositionPlan;
- System Composition;
- estado;
- health;
- lifecycle.

Core no implementa:

- comportamiento específico del vehículo;
- presentación;
- persistencia de usuario;
- telemetría concreta;
- hardware concreto.

## 3. Límites

Core no debe:

- leer directamente input del jugador;
- aplicar fuerzas sobre la nave;
- descubrir dependencias mediante SceneTree;
- dibujar UI;
- controlar cámaras;
- serializar telemetría;
- abrir red;
- acceder directamente a GPIO, I2C, SPI o serial;
- depender de cabina física;
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
		SystemProfile, DeviceGraphAssembler
		y CompositionPlan.

core/catalog/
		DeviceCatalog.

core/runtime/
		Runtime Construction Contracts
		y RuntimeFactoryRegistry.

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

SceneTree no define Core.

## 5. Mapa de componentes

| Componente | Responsabilidad | Estado |
|---|---|---|
| DeviceBus | Transportar mensajes mediante bounded FIFO | Implementado y verificado |
| DeviceBusDispatchPolicy | Definir budgets y hard maximums | Implementado y verificado |
| DeviceBusDispatchReport | Describir Dispatch Cycle | Implementado y verificado |
| BusTopics | Identidades canónicas de Topics | Implementado y verificado |
| BusMessage | Envelope inmutable | Implementado y verificado |
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
| ValidationReport | Validación por contexto | Implementado y verificado |
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
| DeviceProfileResolver | Resolución exacta | Implementado y verificado |
| DeviceCatalogDraft | Profiles editables | Implementado y verificado |
| DeviceCatalogCompiler | Compilar catálogo | Implementado y verificado |
| DeviceCatalog | Resolver Profiles | Implementado y verificado |
| DeviceCatalogCompileResult | Resultado de catálogo | Implementado y verificado |
| DeviceGraphAssembler | Construir Graph desde SystemProfile | Implementado y verificado |
| DeviceGraphAssemblyResult | Resultado de Graph assembly | Implementado y verificado |
| RuntimeFactoryKey | Identidad exacta de factory | Implementado y verificado |
| RuntimeDependencyBinding | Dependencia activa con ownership | Implementado y verificado |
| RuntimeConstructionRequest | Request pre-resuelto | Implementado y verificado |
| RuntimeDeviceHandle | Producto y ownership runtime | Implementado y verificado |
| RuntimeFactoryBuildResult | Resultado de factory | Implementado y verificado |
| RuntimeFactory behavior | Construcción y release | Verificado mediante integración |
| RuntimeHost behavior | Attach y detach | Verificado mediante integración |
| RuntimeDependencySpec | Declarar dependencia requerida sin Value activo | Diseño 1.0 activo; siguiente implementación |
| RuntimeFactoryDescriptor | Asociar Key, factory behavior y Dependency Specs | Diseño 1.0 activo; implementación pendiente |
| RuntimeFactoryRegistryDraft | Colección editable de Descriptors | Diseño 1.0 activo; implementación pendiente |
| RuntimeFactoryRegistryCompiler | Validar Draft y producir Registry | Diseño 1.0 activo; implementación pendiente |
| RuntimeFactoryRegistry | Resolver factories mediante Key exacta | Diseño 1.0 activo; implementación pendiente |
| RuntimeFactoryRegistryCompileResult | Contener Registry y ValidationReport | Diseño 1.0 activo; implementación pendiente |
| CompositionDeviceEntry | Describir construcción declarativa de un Device | Diseño 1.0 activo; implementación posterior al Registry |
| CompositionConnectionDirective | Describir wiring sin callbacks activos | Diseño 1.0 activo; implementación posterior al Registry |
| CompositionPlan | Instrucciones runtime inmutables y no ejecutables | Diseño 1.0 activo; implementación posterior al Registry |
| CompositionCompiler | Compilar Snapshot y Registry a Plan | Diseño pendiente |
| CompositionRuntime | Ejecutar Plan y poseer recursos activos | Pendiente |
| Measurement | Dato de Sensor | Contrato pendiente |

## 6. DeviceBus

DeviceBus transporta información sin interpretar significado.

Puede:

- registrar;
- eliminar;
- publicar;
- limpiar;
- ejecutar FIFO iterativo;
- aplicar budgets;
- abortar controladamente;
- producir DispatchReport;
- recuperarse.

No:

- crea Devices;
- interpreta payload;
- valida Graph;
- conoce Providers;
- conoce hardware.

Tiene owner explícito.

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

Provider no decide consumidores.

## 9. Profiles y Configurations

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

No crea runtime.

Fan-in implícito se rechaza.

Ciclos se detectan sin recursión.

Ciclo sin evidencia temporal:

```text
SIMULATION_HAZARD

graph_cycle_requires_temporal_analysis
```

## 11. SystemProfile

```text
SystemProfileDraft
		│
		▼
SystemProfileCompiler
		│
		▼
SystemProfile
```

Contiene:

- identidad;
- versión;
- metadata;
- Activation Context;
- DeviceConfiguration snapshots;
- SystemConnectionSpecs.

Usa:

```text
Profile ID

+

Profile Version
```

No depende de Graph, filesystem o runtime.

## 12. DeviceCatalog

```text
DeviceCatalogDraft
		│
		▼
DeviceCatalogCompiler
		│
		▼
DeviceCatalog
```

Propiedades:

- inmutable;
- resolución exacta;
- múltiples versiones;
- duplicado exacto bloqueante;
- sin latest;
- sin fallback;
- sin factories;
- sin filesystem.

## 13. DeviceGraphAssembler

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

Propiedades:

- stateless;
- Simulation-only;
- Hardware rechazado;
- Devices antes de Connections;
- errores por etapas;
- no Graph parcial;
- orden preservado;
- no mutación;
- no runtime.

## 14. Runtime Construction

Definido por:

```text
ADR-010

Runtime Construction Contract Design 1.1
```

Estado:

```text
IMPLEMENTADO Y VERIFICADO
```

Componentes:

```text
RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult
```

Behaviors:

```text
RuntimeFactory

RuntimeHost
```

## 15. RuntimeFactoryKey

Identidad:

```text
Profile ID

+

Profile Version

+

Activation Context
```

No contiene host target.

No existe fallback.

CompositionPlan conservará Key, no factory.

## 16. RuntimeDependencyBinding

Contiene:

```text
Dependency ID

Object

Ownership
```

Ownership:

```text
BORROWED

TRANSFERRED
```

BORROWED conserva owner original.

TRANSFERRED pasa a transacción durante build.

## 17. RuntimeConstructionRequest

Contiene:

- Device ID;
- DeviceConfiguration;
- Factory Key;
- bindings pre-resueltos.

No es service locator.

No descubre SceneTree, autoload o filesystem.

## 18. RuntimeDeviceHandle

Contiene:

- Device ID;
- Configuration;
- Factory Key;
- Primary Runtime Object;
- Host Objects;
- Dependency Bindings.

Host Objects:

```gdscript
Array[Object]
```

Handle representa ownership de una unidad.

No coordina sistema completo.

## 19. RuntimeFactoryBuildResult

Contiene:

```text
RuntimeDeviceHandle

ValidationReport
```

Valida según Activation Context.

No ejecuta cleanup.

## 20. RuntimeFactory behavior

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

Factory:

- construye;
- no inicializa;
- no inicia;
- no adjunta;
- limpia parciales;
- libera su producto.

## 21. RuntimeHost behavior

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

Controla attach/detach.

No sustituye factory release.

## 22. Construcción atómica

Éxito:

```text
Handle válido
```

Fallo:

```text
Handle null

Report

recursos parciales liberados
```

TRANSFERRED se limpia en fallo.

BORROWED se preserva.

## 23. Rollback

Orden global:

```text
inverso a adquisición
```

Si build falla:

```text
release
```

Si attach falla:

```text
detach

release
```

Si lifecycle falla:

```text
shutdown

detach

release
```

Last Known Good cambia únicamente en commit completo.

## 24. DeviceBus y Runtime

DeviceBus pertenece a CompositionRuntime.

Factory no crea Bus global.

Factory no usa autoload.

Factory produce estado equivalente a CREATED.

DeviceBus se entrega durante initialize coordinado.

## 25. Pipeline implementado

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

```text
Runtime Construction Contracts
```

## 26. Pipeline futuro

```text
RuntimeFactoryRegistryDraft
		│
		▼
RuntimeFactoryRegistryCompiler
		│
		▼
RuntimeFactoryRegistry
```

```text
DeviceGraphSnapshot
+
RuntimeFactoryRegistry
+
Activation Context
+
DeviceBusDispatchPolicy
		│
		▼
CompositionCompiler
		│
		▼
CompositionPlan
```

```text
CompositionPlan
+
RuntimeFactoryRegistry
+
resolved dependency values
+
RuntimeHost
		│
		▼
CompositionRuntime
		│
		├── DeviceBus
		├── RuntimeConstructionRequests
		├── RuntimeFactoryBuildResults
		└── RuntimeDeviceHandles
```

## 27. RuntimeFactoryRegistry

Definido por:

```text
RuntimeFactoryRegistry Design 1.0
```

Estado:

```text
DISEÑO ACTIVO
```

Está autorizado para implementación incremental.

Responsabilidad:

> Resolver RuntimeFactory mediante RuntimeFactoryKey exacta.

Pipeline:

```text
RuntimeFactoryRegistryDraft
		│
		▼
RuntimeFactoryRegistryCompiler
		│
		▼
RuntimeFactoryRegistryCompileResult
		├── RuntimeFactoryRegistry
		└── ValidationReport
```

Cada RuntimeFactoryDescriptor asocia:

```text
RuntimeFactoryKey

RuntimeFactory Object

RuntimeDependencySpecs
```

Descriptor valida:

- RuntimeFactoryKey;
- factory Object no null y con instancia válida;
- behavior `build`;
- behavior `release`;
- RuntimeDependencySpecs válidas;
- Dependency IDs únicas.

La validación no ejecuta la factory.

RuntimeDependencySpec declara:

```text
Dependency ID

Ownership
```

No contiene Value activo.

RuntimeDependencyBinding contiene posteriormente el Object que satisface la dependencia.

El Registry final:

- es inmutable;
- permite Registry vacío válido;
- conserva orden del Draft;
- resuelve por Profile ID, Profile Version y Activation Context;
- permite una misma factory Object bajo Keys diferentes;
- rechaza RuntimeFactoryKey duplicada;
- no tiene Registry ID o Registry Version;
- no utiliza latest;
- no utiliza fallback;
- no reemplaza factories silenciosamente;
- no ejecuta `build()`;
- no ejecuta `release()`.

Una compilación fallida no sustituye el Registry Last Known Good.

CompositionCompiler y CompositionRuntime deben observar el mismo Registry snapshot durante una activación.

Permanecerá separado de:

- DeviceCatalog;
- CompositionPlan;
- CompositionRuntime;
- persistencia.

Primera implementación:

```text
RuntimeDependencySpec
```

## 28. CompositionPlan

Definido por:

```text
CompositionPlan Design 1.0
```

Estado:

```text
DISEÑO ACTIVO
```

Está autorizado para implementación después de completar RuntimeFactoryRegistry 1.0.

CompositionPlan representa instrucciones runtime validadas, inmutables y no ejecutables.

Contiene:

```text
Activation Context

CompositionDeviceEntries

CompositionConnectionDirectives

DeviceBusDispatchPolicy
```

CompositionDeviceEntry conserva:

- Device ID;
- DeviceConfiguration;
- RuntimeFactoryKey;
- RuntimeDependencySpecs.

CompositionConnectionDirective conserva:

- Connection ID;
- Source Device ID;
- Source Port ID;
- Topic;
- Target Device ID;
- Target Port ID.

Forward order deriva del orden de Device Entries para:

```text
construction

attach

initialize

set_ready

start
```

Reverse order invierte Device Entries para:

```text
shutdown

rollback
```

CompositionRuntime deberá respetar phase barriers.

Plan 1.0 no requiere topological sort.

DeviceGraph puede contener ciclos.

El orden por Entries y las phase barriers permiten que todos los participantes existan antes de `start`.

Plan vacío es válido cuando contiene Activation Context y Dispatch Policy válidos.

No contiene:

- RuntimeFactory;
- Callable;
- RuntimeDependencyBinding con Value activo;
- RuntimeDeviceHandle;
- Device activo;
- Node activo;
- DeviceBus activo;
- Plan ID;
- Plan Version.

## 29. CompositionCompiler

Futuro.

Será diseñado después de implementar e integrar RuntimeFactoryRegistry 1.0 y CompositionPlan 1.0.

Entradas conceptuales:

```text
DeviceGraphSnapshot

RuntimeFactoryRegistry

Activation Context

DeviceBusDispatchPolicy
```

Salida conceptual:

```text
CompositionPlan

ValidationReport
```

Validará disponibilidad exacta de RuntimeFactoryDescriptor y trasladará Dependency Specs a Device Entries.

No:

- ejecutará factories;
- creará Devices activos;
- adjuntará Host Objects;
- poseerá DeviceBus;
- activará runtime.

## 30. CompositionRuntime

Futuro.

Recibirá:

- CompositionPlan;
- RuntimeFactoryRegistry;
- dependency values resueltos;
- RuntimeHost.

Resolverá nuevamente cada RuntimeFactoryKey en el mismo Registry snapshot antes de construir.

Poseerá:

- DeviceBus;
- RuntimeDeviceHandles;
- host attachment state;
- lifecycle;
- phase barriers;
- rollback inverso;
- shutdown;
- Runtime Safety observation.

## 31. Reglas de dependencia

1. DeviceBus no depende de Devices concretos.

2. DeviceGraph no depende de DeviceBus runtime.

3. SystemProfile no depende de DeviceGraph.

4. DeviceCatalog no contiene factories.

5. DeviceGraphAssembler no crea runtime.

6. RuntimeFactory recibe Request pre-resuelto.

7. RuntimeFactory no descubre dependencias.

8. RuntimeHost controla attach/detach.

9. RuntimeDependencySpec declara requisitos sin Value activo.

10. RuntimeDependencyBinding contiene el Value activo resuelto.

11. RuntimeFactoryRegistry no depende de DeviceCatalog.

12. RuntimeFactoryRegistry no depende de CompositionPlan.

13. RuntimeFactoryRegistry resuelve exacto y no ejecuta factories.

14. CompositionCompiler y CompositionRuntime observan el mismo Registry snapshot durante una activación.

15. CompositionPlan conserva Key, no factory.

16. CompositionPlan no contiene Callable o recursos activos.

17. CompositionCompiler no ejecuta.

18. CompositionRuntime posee recursos activos.

19. UI depende de Core.

20. Persistencia depende del modelo.

## 32. Invariantes

1. Arquitectura precede código.

2. Una responsabilidad por componente.

3. Composición sobre herencia.

4. Dependencias explícitas.

5. Drafts editables.

6. Snapshots inmutables.

7. Last Known Good.

8. Baselines inmutables.

9. Sin recursión ilimitada.

10. Hardware más estricto.

11. Build atómico.

12. Ownership explícito.

13. Rollback inverso.

14. RuntimeFactoryKey es exacta.

15. RuntimeDependencySpec no contiene Value activo.

16. Registry es inmutable y no ejecuta.

17. Registry no utiliza latest, fallback u overwrite.

18. Compiler y Runtime comparten el mismo Registry snapshot durante una activación.

19. Plan es inmutable y no ejecutable.

20. Plan conserva Key, no factory.

21. Plan no contiene Callable o recursos activos.

22. DeviceBusDispatchPolicy es obligatoria en Plan.

23. Forward order deriva de Device Entries.

24. Reverse order invierte Device Entries.

25. Ciclos no requieren topological sort en Plan 1.0.

26. Archivos completos.

## 33. Godot

Godot Engine 4.7.1 es host actual.

Runtime contracts usan Object.

No dependen de:

- Node;
- Node3D;
- SceneTree;
- paths;
- autoloads.

RuntimeHost concreto adaptará Objects.

## 34. VP-002

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

Plataforma nunca permite:

- stack overflow;
- recursión ilimitada;
- memoria ilimitada;
- queue ilimitada;
- bloqueo;
- corrupción;
- pérdida de Last Known Good;
- hardware inseguro.

## 35. Defensa en profundidad

```text
Draft validation

+

Profile y Catalog snapshot validation

+

Graph assembly

+

RuntimeFactoryRegistry compilation

+

CompositionCompiler validation

+

CompositionPlan validation

+

Runtime dependency resolution

+

Runtime construction validation

+

DeviceBus Runtime Safety

+

Runtime supervision
```

## 36. Estado implementado

```text
DeviceBus

Runtime Safety

Topic y Message Contracts

Provider System

Device Core

DeviceProfile Draft–Snapshot

DeviceConfiguration Draft–Snapshot

DeviceGraph 1.0

SystemProfile 1.0

DeviceCatalog 1.0

DeviceGraphAssembler 1.0

Runtime Construction Contract 1.0

Velocity Test Runner

Velocity Test Dashboard 0.4.0
```

## 37. Diseños activos

```text
RuntimeFactoryRegistry 1.0

CompositionPlan 1.0
```

Ambos diseños están completos, activos y autorizan implementación incremental en el orden establecido.

## 38. Pendiente

```text
Implementación de RuntimeFactoryRegistry 1.0

Implementación de CompositionPlan 1.0

Diseño e implementación de CompositionCompiler

CompositionRuntime

RuntimeHost concreto

Factories de producción

Measurement Identity

Provenance

Temporal Boundaries

SystemProfile persistence

DeviceCatalog persistence

GraphEditor

Hardware Mode

Calibration

AdaptationPolicy

RuntimeAllocation
```

## 39. Baseline global

Dashboard 0.4.0 confirma:

```text
Tests: 54
Checks: 1569
Failures: 0
Timeout: 0
Engine Error: 0
Missing Metrics: 0
Plan ExitCode: 0
RESULT: PASS
```

## 40. Tooling

Velocity Test Dashboard:

```text
0.4.0
```

Metrics Protocol:

```text
1
```

Suites automáticas:

```text
10 dominios
0 Other
```

Unittest lógico:

```text
17 tests
OK
```

## 41. Project State

```text
docs/project_state/
velocity_handoff.md

docs/project_state/
velocity_resume_prompt.md

docs/project_state/
velocity_collaboration_contract.md
```

Estos documentos permiten reanudar en un chat nuevo.

## 42. Decisiones vigentes

```text
VP-001

VP-002

ADR-001

ADR-002

ADR-003

ADR-004

ADR-005

ADR-006

ADR-007

ADR-008

ADR-009

ADR-010
```

## 43. Regla de evolución

Antes de cambiar código:

> ¿Sigue siendo correcta la responsabilidad?

Si sí, se evoluciona.

Si no, se rediseña.

No se parchea una responsabilidad equivocada.

Toda modificación se entrega como archivo completo.

## 44. Siguiente paso

Implementar incrementalmente RuntimeFactoryRegistry 1.0.

Primer archivo:

```text
res://core/runtime/runtime_dependency_spec.gd
```

Primera prueba sucesora:

```text
res://test/core/runtime/RuntimeDependencySpecTest.tscn

res://test/core/runtime/runtime_dependency_spec_test.gd
```

Orden posterior:

```text
RuntimeFactoryDescriptor

RuntimeFactoryRegistryDraft

RuntimeFactoryRegistry

RuntimeFactoryRegistryCompileResult

RuntimeFactoryRegistryCompiler

Run All

CompositionDeviceEntry

CompositionConnectionDirective

CompositionPlan

Registry–Plan Integration

Run All

CompositionCompiler Design
```

No se implementará CompositionCompiler antes de completar e integrar Registry y Plan.
