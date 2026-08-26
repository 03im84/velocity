# Velocity — Project Handoff

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
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
- interrumpir el desarrollo durante un período largo.

No sustituye:

- ADR;
- diseños;
- Core Architecture;
- Engineering Standards;
- tests;
- código;
- Git.

Resume el estado operativo vigente y dirige al lector hacia las fuentes canónicas.

## 2. Regla de recuperación

Antes de proponer código o arquitectura, un nuevo asistente debe:

1. leer este archivo completo;

2. leer Engineering Standards;

3. leer Core Architecture;

4. leer los ADR relacionados con el siguiente milestone;

5. leer el diseño activo;

6. revisar el código existente;

7. revisar las pruebas aceptadas;

8. revisar `git status`;

9. resumir el estado actual;

10. confirmar el siguiente paso antes de modificar archivos.

No debe reconstruir el proyecto desde memoria general ni inventar APIs ausentes.

## 3. Visión de Velocity

Velocity es una plataforma y juego modular de carreras antigravitatorias inspirado en Wipeout.

Objetivos:

- simulación antigravitatoria;
- nave basada en RigidBody3D;
- sistemas físicos separados;
- arquitectura modular;
- telemetría futura;
- Raspberry Pi Zero 2 W;
- cabinas físicas;
- hardware intercambiable;
- composición visual futura;
- aprendizaje técnico y experimentación.

La plataforma debe permitir que el usuario cometa errores dentro de la simulación sin comprometer el simulador.

Regla principal:

> La simulación puede fallar. El simulador no.

## 4. Filosofía de colaboración

El trabajo se realiza como tutoría técnica.

El asistente debe:

- explicar el problema;
- explicar el análisis;
- explicar la decisión;
- explicar responsabilidades;
- explicar tradeoffs;
- proponer alternativas mejores;
- no aceptar automáticamente una idea;
- corregir honestamente;
- indicar siempre la ruta exacta;
- explicar pruebas y resultados esperados;
- evitar saltos arquitectónicos.

Idioma:

```text
Español
```

Tono:

- claro;
- didáctico;
- directo;
- técnico;
- colaborativo;
- honesto.

El usuario utiliza expresiones coloquiales panameñas y venezolanas.

El tono puede ser cercano, pero las decisiones deben mantenerse rigurosas.

## 5. Forma de trabajo del usuario

El usuario:

- no descarga archivos generados por el asistente;
- lee y reescribe manualmente cada archivo;
- utiliza Godot y su editor;
- aprende mediante el proceso;
- ejecuta pruebas localmente;
- informa errores completos;
- administra Git manualmente.

Por tanto, cada entrega debe minimizar ambigüedad y riesgo de omisión.

## 6. Directriz universal de archivos completos

Toda modificación entregada debe proporcionarse como archivo completo consolidado.

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
- Core Architecture;
- Engineering Standards;
- journals nuevos.

No se utilizan:

- parches;
- cirugía manual;
- “busca esta línea”;
- “inserta después de”;
- “elimina este bloque”;
- diffs como instrucciones;
- fragmentos como estado final.

Los diffs se utilizan únicamente para auditoría.

Cuando varios archivos cambian, se entregan uno por uno y completos.

## 7. Metodología obligatoria

Toda característica importante sigue:

```text
1. Problema

2. Análisis

3. ADR

4. Diseño del componente

5. Implementación

6. Pruebas unitarias

7. Pruebas de integración

8. Refactorización
```

No se modifica código durante análisis, ADR o diseño.

La implementación comienza después de aceptar responsabilidad y contrato.

## 8. Reglas arquitectónicas

1. Arquitectura precede al código.

2. Una responsabilidad por componente.

3. Composición sobre herencia.

4. Simplicidad es una característica.

5. UI nunca define el Core.

6. No se añaden singletons por comodidad.

7. Pocos autoloads.

8. Dependencias explícitas.

9. Drafts no se utilizan por runtime.

10. Runtime utiliza snapshots o planes compilados.

11. Operaciones fallidas conservan Last Known Good.

12. Colecciones internas no se exponen mutables.

13. Tests aceptados son baselines inmutables.

14. Una arquitectura nueva utiliza pruebas sucesoras.

15. Documentación forma parte del producto.

16. Responsabilidad incorrecta se rediseña; no se parchea.

17. Algoritmos sobre datos del usuario no utilizan recursión ilimitada.

18. Hardware requiere validación más estricta que Simulation.

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

Categorías de validación:

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
```

ADR siguiente, todavía no creado:

```text
ADR-010 — Runtime Construction and Factory Binding
```

## 11. Arquitectura implementada

### DeviceBus

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

### Topic y Message Contracts

Implementado:

```text
BusTopics

BusMessage

DeviceManifest topics
```

Topics utilizan:

```gdscript
StringName
```

BusMessage es RefCounted e inmutable por contrato.

### Provider System

Provider es rol por comportamiento.

Distance Provider contract:

```gdscript
get_distance() -> float

is_valid() -> bool
```

Implementaciones verificadas:

```text
ManualDistanceProvider

PhysicsDistanceProvider
```

### Device Core

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

Lifecycle y Health permanecen separados.

### Profile y Configuration

Pipeline implementado:

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

Namespace canónico reservado:

```text
velocity.
```

Builtin inicial:

```text
velocity.distance_sensor.ideal@1
```

### DeviceGraph

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

DeviceGraph 1.0 permite:

- Devices;
- Connections;
- TopicChannels;
- fan-out;
- protección fan-in;
- validación global;
- detección iterativa de ciclos;
- Snapshot inmutable;
- Last Known Good.

Un ciclo sin evidencia temporal produce:

```text
SIMULATION_HAZARD

graph_cycle_requires_temporal_analysis
```

Simulation puede continuar.

Hardware queda bloqueado.

### SystemProfile

Implementado:

```text
SystemConnectionSpec

SystemProfileDraft

SystemProfile

SystemProfileCompileResult

SystemProfileCompiler
```

SystemProfile utiliza referencias exactas:

```text
Profile ID

+

Profile Version
```

Activation Context es explícito.

SystemProfile no depende de:

- DeviceGraph;
- filesystem;
- runtime.

### DeviceCatalog

Implementado:

```text
DeviceCatalogDraft

DeviceCatalog

DeviceCatalogCompileResult

DeviceCatalogCompiler
```

Propiedades:

- catálogo inmutable;
- múltiples versiones;
- duplicado exacto bloqueante;
- orden preservado;
- resolución exacta;
- sin latest;
- sin fallback;
- sin overwrite;
- sin factories;
- sin filesystem.

DeviceCatalog satisface DeviceProfileResolver:

```gdscript
has_profile(
	profile_id: StringName,
	profile_version: int
) -> bool
```

```gdscript
get_profile(
	profile_id: StringName,
	profile_version: int
) -> DeviceProfile
```

### DeviceGraphAssembler

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
- errores agregados por etapas;
- gate entre etapas;
- no Graph parcial;
- orden preservado;
- no mutación;
- no runtime;
- no filesystem.

## 12. System Composition Pipeline

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

## 13. Componentes pendientes principales

```text
Runtime Construction Contract

RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult

RuntimeHost contract

RuntimeFactoryRegistry

CompositionPlan

CompositionCompiler

CompositionRuntime

SystemProfile persistence

DeviceCatalog persistence

Temporal Boundary metadata

Measurement Identity

provenance

GraphEditor

ConfigurationEditor

GraphLayout

Hardware Mode compiler

Calibration

AdaptationPolicy

RuntimeAllocation
```

## 14. Decisiones actuales para ADR-010

Estas decisiones fueron aceptadas en conversación, pero todavía no están documentadas ni confirmadas en Git.

### Factory construct-only

Runtime factory:

- construye;
- no inicializa;
- no inicia;
- no apaga runtime global;
- no adjunta Nodes.

### Producto

Factory devuelve:

```text
RuntimeDeviceHandle
```

No devuelve Object genérico ni Device aislado.

### Construcción atómica

En fallo:

- factory limpia recursos creados;
- devuelve Handle null;
- produce ValidationReport.

### Rollback global

CompositionRuntime limpia Handles previos en orden inverso.

### Dependencias

Factory recibe:

```text
RuntimeConstructionRequest
```

con dependencias pre-resueltas.

No utiliza service locator.

### Ownership

Cada binding declara:

```text
BORROWED

TRANSFERRED
```

BORROWED:

- owner original permanece;
- Handle no libera.

TRANSFERRED:

- ownership pasa a la transacción;
- en éxito pertenece al Handle;
- en fallo la factory limpia.

### Nodes

Factory devuelve Nodes sin adjuntar.

CompositionRuntime utiliza RuntimeHost para attach/detach transaccional.

### DeviceBus

DeviceBus pertenece a CompositionRuntime.

No se entrega como global oculto durante construcción.

Se utiliza en inicialización posterior.

### Factory Key

Identidad exacta:

```text
Profile ID

+

Profile Version

+

Activation Context
```

No existe fallback.

### CompositionPlan

Plan guarda:

```text
RuntimeFactoryKey
```

No guarda:

- factory Object;
- Callable;
- constructor ejecutable.

## 15. Siguiente milestone

Crear y aceptar:

```text
ADR-010 — Runtime Construction and Factory Binding
```

Después:

```text
Runtime Construction Contract Design
```

No escribir código antes de aceptar ambos documentos.

## 16. Convenciones GDScript críticas

### Nunca comenzar una línea con punto

Incorrecto:

```gdscript
object
	.method()
```

Correcto:

```gdscript
object.method()
```

### Mantener acceso completo en una línea física

```gdscript
object.property

object.method()

ClassName.CONSTANT
```

### Tipos de colecciones completos

```gdscript
Array[DeviceGraphNode]

Dictionary[String, DeviceGraphNode]
```

No partir el tipo entre líneas.

### Métodos nativos de Object

Revisar conflictos con:

```text
connect()

disconnect()

emit_signal()

call()

free()

get()

set()
```

DeviceGraph utiliza:

```gdscript
connect_ports()

disconnect_ports()
```

### Naming

```text
Escenas:
PascalCase.tscn

Scripts:
snake_case.gd