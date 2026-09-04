# Velocity — Project Handoff

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Fecha de actualización | 25/08/2026 |
| Zona horaria | GMT-5, sin DST |
| Engine | Godot Engine 4.7.1 stable |
| Repositorio | https://github.com/03im84/velocity |
| Rama principal | main |
| Propósito | Recuperación y transferencia completa del contexto de trabajo |

## 1. Propósito

Este documento permite continuar Velocity después de:

- perder acceso a un chat;
- comenzar una conversación nueva;
- cambiar de asistente;
- cambiar de modelo;
- cambiar de dispositivo;
- compactar contexto;
- interrumpir el desarrollo.

No sustituye:

- ADR;
- diseños;
- Core Architecture;
- Engineering Standards;
- tests;
- código;
- Git.

Resume el estado operativo vigente y dirige hacia las fuentes canónicas.

## 2. Regla de recuperación

Antes de proponer código o arquitectura, un asistente nuevo debe:

1. leer este archivo;

2. leer Collaboration Contract;

3. leer Resume Prompt;

4. leer Engineering Standards;

5. leer Core Architecture;

6. leer ADR del milestone;

7. leer diseño activo;

8. revisar código;

9. revisar tests;

10. revisar Git;

11. resumir estado;

12. esperar confirmación.

No debe reconstruir APIs mediante intuición.

## 3. Visión de Velocity

Velocity es una plataforma y juego modular de carreras antigravitatorias inspirado en Wipeout.

Objetivos:

- simulación antigravitatoria;
- nave RigidBody3D;
- sistemas físicos separados;
- arquitectura modular;
- telemetría futura;
- Raspberry Pi Zero 2 W;
- cabinas físicas;
- hardware intercambiable;
- composición visual futura;
- aprendizaje técnico.

Regla principal:

> La simulación puede fallar. El simulador no.

## 4. Forma de colaboración

El asistente trabaja como tutor y colega técnico.

Debe:

- explicar problema;
- explicar análisis;
- explicar decisiones;
- proponer alternativas;
- explicar tradeoffs;
- no aceptar ideas automáticamente;
- corregir honestamente;
- indicar rutas exactas;
- entregar archivos completos;
- interpretar pruebas;
- preservar continuidad.

Idioma:

```text
Español
```

Tono:

- claro;
- didáctico;
- directo;
- cercano;
- riguroso;
- honesto.

## 5. Forma de trabajo del usuario

El usuario:

- no descarga entregables generados;
- reescribe manualmente;
- aprende durante el proceso;
- ejecuta Godot localmente;
- ejecuta pruebas;
- administra Git.

Por tanto, no se entregan reconstrucciones parciales.

## 6. Directriz universal

Toda modificación se entrega como archivo completo consolidado.

Aplica a:

- código;
- tests;
- escenas;
- documentos;
- configuraciones;
- scripts;
- herramientas;
- ADR;
- diseños;
- journals nuevos.

No se utilizan:

- parches;
- cirugía;
- diffs como construcción;
- inserciones parciales;
- eliminaciones parciales;
- fragmentos como estado final.

## 7. Metodología

```text
1. Problema

2. Análisis

3. ADR

4. Diseño

5. Implementación

6. Pruebas unitarias

7. Pruebas de integración

8. Refactorización
```

No se escribe código durante problema, análisis, ADR o diseño abierto.

## 8. Principios

1. Arquitectura antes que código.

2. Una responsabilidad por componente.

3. Composición sobre herencia.

4. Simplicidad es una característica.

5. UI no define Core.

6. Dependencias explícitas.

7. Pocos autoloads.

8. Sin singleton por comodidad.

9. Drafts editables.

10. Runtime usa snapshots o planes.

11. Last Known Good.

12. Colecciones protegidas.

13. Tests aceptados son inmutables.

14. Nueva arquitectura usa prueba sucesora.

15. Documentación es producto.

16. Responsabilidad incorrecta se rediseña.

17. Sin recursión ilimitada.

18. Hardware es más estricto.

## 9. Project Decisions

### VP-001

```text
Architecture Precedes Code
```

### VP-002

```text
The Simulation May Fail;
The Simulator Must Not
```

Contextos:

```text
Draft

Active Simulation

Active Hardware
```

Severities:

```text
INFO

WARNING

STRUCTURAL_ERROR

PLATFORM_SAFETY_ERROR

SIMULATION_HAZARD

HARDWARE_SAFETY_ERROR
```

## 10. ADR vigentes

```text
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

Todos están aceptados.

## 11. DeviceBus

Implementado:

- subscriptions;
- FIFO iterativo;
- no recursión reentrante;
- Publication Budget;
- Callback Budget;
- Queue Size Limit;
- Time Budget;
- hard maximums;
- aborto controlado;
- recuperación;
- DispatchReport;
- DELIVER_ALL;
- fan-out.

DeviceBus no conoce:

- Device concreto;
- DeviceGraph;
- Provider;
- telemetría;
- hardware;
- payload semantics.

## 12. Topic y Message Contracts

Implementado:

```text
BusTopics

BusMessage

DeviceManifest topics
```

Topics utilizan StringName.

BusMessage es RefCounted e inmutable por contrato.

## 13. Provider System

Provider es rol por comportamiento.

Distance Provider:

```gdscript
get_distance() -> float

is_valid() -> bool
```

Implementaciones:

```text
ManualDistanceProvider

PhysicsDistanceProvider
```

## 14. Device Core

Implementado:

```text
Device

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

## 15. Profile y Configuration

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

Namespace canónico:

```text
velocity.
```

Builtin inicial:

```text
velocity.distance_sensor.ideal@1
```

## 16. DeviceGraph

Implementado:

```text
PortSemanticKinds

DeviceGraphInputPort

DeviceGraphOutputPort

DeviceGraphTopicChannel

DeviceGraphConnection

DeviceGraphNode

DeviceGraphNodeBuilder

DeviceGraphOperationResult

DeviceGraphDraft

DeviceGraphValidator

DeviceGraphSnapshot

DeviceGraphSnapshotResult
```

Propiedades:

- fan-out;
- protección fan-in;
- validación global;
- ciclos iterativos;
- Snapshot inmutable;
- Last Known Good.

Ciclo sin evidencia temporal:

```text
SIMULATION_HAZARD

graph_cycle_requires_temporal_analysis
```

## 17. SystemProfile

Implementado:

```text
SystemConnectionSpec

SystemProfileDraft

SystemProfile

SystemProfileCompileResult

SystemProfileCompiler
```

Utiliza:

```text
Profile ID

+

Profile Version
```

Activation Context es explícito.

No depende de Graph, filesystem o runtime.

## 18. DeviceCatalog

Implementado:

```text
DeviceCatalogDraft

DeviceCatalog

DeviceCatalogCompileResult

DeviceCatalogCompiler
```

Propiedades:

- inmutable;
- múltiples versiones;
- duplicado exacto bloqueante;
- resolución exacta;
- sin latest;
- sin fallback;
- sin overwrite;
- sin factories;
- sin filesystem.

## 19. DeviceGraphAssembler

Implementado:

```text
DeviceGraphAssemblyResult

DeviceGraphAssembler
```

Pipeline:

```text
SystemProfile

+

DeviceProfileResolver

↓

DeviceManifestBuilder

↓

DeviceGraphNodeBuilder

↓

DeviceGraphDraft

↓

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

## 20. Pipeline implementado

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

## 21. Runtime Construction Contract

Estado:

```text
ADR-010 ACEPTADO

DESIGN 1.0 ACTIVO

IMPLEMENTACIÓN PENDIENTE
```

Componentes autorizados:

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

## 22. RuntimeFactoryKey

Identidad exacta:

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

## 23. RuntimeDependencyBinding

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

BORROWED no se libera por Handle.

TRANSFERRED pasa a factory transaction durante build.

## 24. RuntimeConstructionRequest

Contiene:

- Device ID;
- DeviceConfiguration;
- RuntimeFactoryKey;
- bindings pre-resueltos.

No es service locator.

No descubre SceneTree, autoload o filesystem.

Crear Request no transfiere ownership.

Invocar factory build inicia la transacción.

## 25. RuntimeDeviceHandle

Contiene:

- Device ID;
- Configuration;
- Factory Key;
- Primary Runtime Object;
- Host Objects;
- Dependency Bindings.

Primary Runtime Object:

```gdscript
Object
```

Host Objects:

```gdscript
Array[Object]
```

Handle representa ownership de una unidad runtime.

No coordina sistema completo.

## 26. RuntimeFactory behavior

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
- libera su producto cuando Runtime coordina.

## 27. RuntimeHost behavior

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

## 28. Construcción y rollback

Factory build exitoso:

```text
Handle válido
```

Factory build fallido:

```text
Handle null

Report

recursos parciales liberados
```

Rollback global:

```text
orden inverso
```

Last Known Good solo cambia después de commit completo.

## 29. DeviceBus futuro

DeviceBus pertenece a CompositionRuntime.

Factory no crea Bus global.

Factory no usa autoload.

Factory produce estado equivalente a CREATED.

DeviceBus se entrega en initialize coordinado.

## 30. Pipeline futuro

```text
DeviceGraphSnapshot

↓

CompositionCompiler

↓

CompositionPlan

↓

CompositionRuntime

↓

RuntimeConstructionRequest

↓

RuntimeFactory

↓

RuntimeDeviceHandle
```

## 31. RuntimeFactoryRegistry futuro

Resolverá:

```text
RuntimeFactoryKey

→

RuntimeFactory
```

Permanecerá separado de DeviceCatalog y CompositionPlan.

Requiere diseño propio después de Runtime Construction Contract.

## 32. CompositionPlan futuro

Conservará:

- RuntimeFactoryKeys;
- dependency directives;
- lifecycle order;
- communication directives;
- runtime policies.

No conservará:

- factory;
- Callable;
- Handle;
- Device activo;
- Node activo;
- DeviceBus activo.

## 33. CompositionRuntime futuro

Poseerá:

- DeviceBus;
- Handles;
- RuntimeHost;
- attach state;
- lifecycle;
- rollback;
- shutdown;
- Runtime Safety observation.

## 34. Siguiente componente

```text
RuntimeFactoryKey
```

Orden posterior:

```text
RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult

Runtime Construction Integration

RuntimeFactoryRegistry Design

CompositionPlan Design

CompositionCompiler

CompositionRuntime
```

## 35. Convenciones GDScript

Nunca comenzar línea con `.`.

Mantener en línea física:

```gdscript
object.property

object.method()

ClassName.CONSTANT
```

Mantener completos:

```gdscript
Array[Type]

Dictionary[Key, Value]
```

Revisar conflictos con Object:

```text
connect

disconnect

emit_signal

call

free

get

set
```

Naming:

```text
Escenas:
PascalCase.tscn

Scripts:
snake_case.gd

Resources:
snake_case.tres

Classes:
PascalCase

Métodos:
snake_case

Constantes:
UPPER_SNAKE_CASE

Codes:
lower_snake_case StringName
```

## 36. Pruebas

No modificar baselines aceptadas.

Crear pruebas sucesoras.

Ante fallo:

1. no cambiar código;

2. copiar primer error completo;

3. incluir archivo y línea;

4. clasificar;

5. después cambiar.

Ejecución autoritativa:

```text
Godot Console

+

headless

+

Velocity Test Runner
```

## 37. Herramientas

Godot:

```text
4.7.1 stable
```

Runner:

```text
res://test/tools/run_godot_tests.ps1
```

Dashboard:

```text
Velocity Test Dashboard 0.3.2
```

Códigos:

```text
124 TIMEOUT

125 proceso no confirmado

126 ENGINE_ERROR con ExitCode 0
```

## 38. Baseline vigente

```text
Planned: 48
Completed: 48
Passed: 48
Failed: 0
Timeout: 0
Engine Error: 0
Not Run: 0
Plan ExitCode: 0
RESULT: PASS
```

Total:

```text
48 tests

1396 checks

0 failures
```

## 39. Documentos vigentes

```text
Core Architecture:
2.13

Engineering Standards:
1.3

System Composition Pipeline Design:
1.4

Runtime Construction Contract Design:
1.0

DeviceGraphAssembler Design:
1.1

DeviceCatalog Design:
1.1

DeviceGraph Design:
1.3
```

## 40. Git

Repositorio:

```text
https://github.com/03im84/velocity
```

Rama:

```text
main
```

Último commit publicado antes del paquete ADR-010:

```text
e21caed
docs(project): add recovery and collaboration package
```

Último estado remoto confirmado:

```text
## main...origin/main
```

El paquete arquitectónico ADR-010 está pendiente de commit.

## 41. Borrador alternativo recuperado

Archivo local fuera del repositorio:

```text
recovered_runtime_factory_and_composition_plan_design_250826.md
```

No es arquitectura canónica.

Ideas candidatas:

- lifecycle order;
- DispatchPolicy;
- subscription directives;
- host abstractions;
- Last Known Good.

Alternativas rechazadas:

- Callable genérico;
- factory en Plan;
- factory devuelve Device;
- host_target como Key;
- Registry mutable sin diseño;
- Array[Dictionary];
- topological order obligatorio.

## 42. Project State Package

```text
docs/project_state/
velocity_handoff.md

docs/project_state/
velocity_resume_prompt.md

docs/project_state/
velocity_collaboration_contract.md
```

En un chat nuevo se adjuntan los tres.

## 43. Jerarquía de autoridad

1. código versionado;

2. tests aceptados;

3. ADR;

4. diseños activos;

5. Core Architecture;

6. Engineering Standards;

7. handoff;

8. Collaboration Contract;

9. journals;

10. conversación anterior.

## 44. Protocolo de actualización

Actualizar este archivo después de cada milestone.

Cada actualización se entrega completa.

Actualizar:

- versión;
- fecha;
- baseline;
- commits;
- componentes;
- documentos;
- siguiente milestone;
- decisiones abiertas.

## 45. Regla final

El chat facilita colaboración.

Git conserva producto.

ADR conserva decisiones.

Diseños conservan contratos.

Tests conservan comportamiento.

Handoff conserva continuidad.

Si el chat desaparece, el proyecto debe continuar desde estas fuentes sin reconstruir su historia de memoria.
