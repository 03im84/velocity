# Velocity — Project Handoff

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.3 |
| Fecha de actualización | 05/09/2026 |
| Zona horaria | GMT-5, sin DST |
| Engine | Godot Engine 4.7.1 stable |
| Repositorio | https://github.com/03im84/velocity |
| Rama principal | main |
| Propósito | Recuperación y transferencia completa del contexto de trabajo |

## 1. Propósito

Este documento permite continuar Velocity después de:

- perder acceso a un chat;
- comenzar otra conversación;
- cambiar de asistente;
- cambiar de modelo;
- cambiar de dispositivo;
- compactar contexto;
- interrumpir desarrollo.

No sustituye:

- Git;
- código;
- tests;
- ADR;
- diseños;
- Core Architecture;
- Engineering Standards.

Resume el estado operativo vigente.

## 2. Protocolo de recuperación

Antes de proponer código, un asistente nuevo debe:

1. leer este archivo;

2. leer Collaboration Contract;

3. leer Resume Prompt;

4. leer Engineering Standards;

5. leer Core Architecture;

6. leer ADR del milestone;

7. leer los diseños activos;

8. revisar código;

9. revisar tests;

10. revisar Git;

11. resumir estado;

12. esperar confirmación.

No debe inventar APIs.

## 3. Visión

Velocity es una plataforma y juego modular de carreras antigravitatorias inspirado en Wipeout.

Objetivos:

- simulación antigravitatoria;
- nave RigidBody3D;
- sistemas físicos separados;
- arquitectura modular;
- telemetría futura;
- Raspberry Pi;
- cabinas físicas;
- hardware intercambiable;
- composición visual;
- aprendizaje técnico.

Regla:

> La simulación puede fallar. El simulador no.

## 4. Colaboración

El asistente trabaja como tutor y colega técnico.

Debe:

- explicar;
- analizar;
- proponer alternativas;
- exponer tradeoffs;
- no aceptar ideas automáticamente;
- corregir honestamente;
- usar rutas exactas;
- preservar baselines;
- entregar archivos completos.

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

## 5. Usuario

El usuario:

- reescribe manualmente archivos;
- no depende de descargas;
- aprende durante el proceso;
- ejecuta Godot;
- ejecuta tests;
- administra Git.

Toda entrega debe ser inequívoca.

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
- fragmentos;
- inserciones parciales;
- eliminaciones parciales.

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

No se escribe código durante análisis o diseño abierto.

## 8. Principios

1. Arquitectura antes que código.

2. Una responsabilidad por componente.

3. Composición sobre herencia.

4. Simplicidad.

5. UI no define Core.

6. Dependencias explícitas.

7. Pocos autoloads.

8. Sin singleton por comodidad.

9. Drafts editables.

10. Runtime usa snapshots y planes.

11. Last Known Good.

12. Colecciones protegidas.

13. Baselines inmutables.

14. Pruebas sucesoras.

15. Documentación es producto.

16. Sin recursión ilimitada.

17. Hardware más estricto.

## 9. Project Decisions

```text
VP-001
Architecture Precedes Code

VP-002
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

Todos aceptados.

## 11. Arquitectura implementada

### DeviceBus

- bounded FIFO;
- budgets;
- abort;
- recovery;
- DispatchReport;
- fan-out;
- explicit owner.

### Topic y Message

```text
BusTopics

BusMessage

DeviceManifest topics
```

### Provider

```text
ManualDistanceProvider

PhysicsDistanceProvider
```

Provider es rol por comportamiento.

### Device Core

```text
Device

DeviceIdentity

DeviceManifest

DeviceState

DeviceHealth

DeviceLifecycle
```

### Profiles

```text
DeviceProfileDraft
→ DeviceProfileCompiler
→ DeviceProfile
```

```text
DeviceConfigurationDraft
→ DeviceConfigurationCompiler
→ DeviceConfiguration
```

```text
Snapshots
→ DeviceManifestBuilder
→ DeviceManifest
```

### DeviceGraph

```text
PortSemanticKinds

InputPort

OutputPort

TopicChannel

Connection

DeviceGraphNode

DeviceGraphDraft

DeviceGraphValidator

DeviceGraphSnapshot
```

Fan-in protegido.

Ciclos iterativos.

Simulation Hazard para ciclos no clasificados.

### SystemProfile

```text
SystemConnectionSpec

SystemProfileDraft

SystemProfileCompiler

SystemProfile

SystemProfileCompileResult
```

### DeviceCatalog

```text
DeviceCatalogDraft

DeviceCatalogCompiler

DeviceCatalog

DeviceCatalogCompileResult
```

Resolución exacta.

Múltiples versiones.

Sin latest.

### DeviceGraphAssembler

```text
DeviceGraphAssemblyResult

DeviceGraphAssembler
```

SystemProfile a DeviceGraphSnapshot.

Simulation-only.

Sin Graph parcial.

### Runtime Construction

```text
RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult
```

Behaviors verificados:

```text
RuntimeFactory

RuntimeHost
```

## 12. Runtime Construction Contract

Estado:

```text
IMPLEMENTADO Y VERIFICADO
```

### RuntimeFactoryKey

```text
Profile ID

+

Profile Version

+

Activation Context
```

No host target.

No fallback.

### RuntimeDependencyBinding

```text
Dependency ID

Object

BORROWED o TRANSFERRED
```

### RuntimeConstructionRequest

Contiene:

- Device ID;
- Configuration;
- Factory Key;
- bindings pre-resueltos.

No service locator.

### RuntimeDeviceHandle

Contiene:

- Device ID;
- Configuration;
- Factory Key;
- Primary Runtime Object;
- Host Objects;
- bindings.

### RuntimeFactoryBuildResult

Handle + ValidationReport.

Validez según contexto.

## 13. Factory behavior

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
- no crea Bus global;
- limpia parciales;
- libera su producto.

## 14. RuntimeHost behavior

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

Attach y detach son transaccionales.

## 15. Ownership

### BORROWED

Owner original permanece.

Factory release no libera.

### TRANSFERRED

Transferencia comienza en build.

Handle asume en éxito.

Factory limpia en fallo.

## 16. Rollback

Factory failure:

```text
cleanup local
Handle null
Report
```

Global failure:

```text
rollback inverso
```

Last Known Good cambia solo después de commit.

## 17. DeviceBus futuro

DeviceBus pertenece a CompositionRuntime.

Factory no crea Bus global.

Factory produce estado CREATED.

Bus se entrega durante initialize.

## 18. Pipeline implementado

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

## 19. Pipeline futuro

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
```

CompositionRuntime poseerá:

- DeviceBus;
- RuntimeDeviceHandles;
- host attachment state;
- lifecycle;
- phase barriers;
- rollback inverso;
- shutdown;
- Runtime Safety observation.

## 20. Milestone actual

Diseños completos y activos:

```text
RuntimeFactoryRegistry 1.0

CompositionPlan 1.0
```

Orden de implementación:

```text
RuntimeFactoryRegistry 1.0

↓

CompositionPlan 1.0

↓

Registry–Plan Integration

↓

CompositionCompiler Design
```

CompositionCompiler no está autorizado para implementación.

## 21. RuntimeFactoryRegistry 1.0

Estado:

```text
DISEÑO ACTIVO
```

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

Componentes diseñados:

```text
RuntimeDependencySpec

RuntimeFactoryDescriptor

RuntimeFactoryRegistryDraft

RuntimeFactoryRegistry

RuntimeFactoryRegistryCompileResult

RuntimeFactoryRegistryCompiler
```

RuntimeDependencySpec declara:

```text
Dependency ID

Ownership
```

No contiene Value activo.

RuntimeFactoryDescriptor asocia:

```text
RuntimeFactoryKey

RuntimeFactory Object

RuntimeDependencySpecs
```

Registry final:

- es inmutable;
- permite Registry vacío válido;
- conserva orden;
- resuelve exacto;
- permite la misma factory Object bajo Keys diferentes;
- rechaza Key duplicada;
- no utiliza latest;
- no utiliza fallback;
- no utiliza overwrite;
- no ejecuta `build()`;
- no ejecuta `release()`;
- permanece separado de DeviceCatalog;
- permanece separado de CompositionPlan.

CompositionCompiler y CompositionRuntime deben observar el mismo Registry snapshot durante una activación.

Primera implementación:

```text
res://core/runtime/runtime_dependency_spec.gd
```

## 22. CompositionPlan 1.0

Estado:

```text
DISEÑO ACTIVO
```

Será implementado después de completar RuntimeFactoryRegistry 1.0.

Componentes diseñados:

```text
CompositionDeviceEntry

CompositionConnectionDirective

CompositionPlan
```

Plan contiene:

```text
Activation Context

CompositionDeviceEntries

CompositionConnectionDirectives

DeviceBusDispatchPolicy
```

DeviceBusDispatchPolicy es obligatoria.

Forward order deriva de Device Entries para:

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

CompositionRuntime respetará phase barriers.

Plan 1.0 no requiere topological sort.

DeviceGraph puede contener ciclos.

Plan vacío con contexto y Dispatch Policy válidos es válido.

Plan no contiene:

- RuntimeFactory;
- Callable;
- RuntimeDependencyBinding con Value activo;
- RuntimeDeviceHandle;
- Device activo;
- Node activo;
- DeviceBus activo;
- Plan ID;
- Plan Version.

## 23. Tooling

### Runner

Metrics Protocol:

```text
1
```

Agrega:

- Total checks;
- Check failures;
- Missing metrics.

### Dashboard

Versión:

```text
0.4.0
```

Funciones:

- automatic suites;
- aliases;
- overrides;
- checks por test;
- checks totales;
- missing metrics;
- Repeat;
- Pause/Resume;
- Stop;
- Run All.

### Dashboard Logic

```text
17 unittests
OK
```

## 24. Baseline global

```text
Planned: 54
Completed: 54
Passed: 54
Failed: 0
Timeout: 0
Engine Error: 0
Not Run: 0
Total Runs: 54
Checks: 1569
Check Failures: 0
Missing Metrics: 0
Plan ExitCode: 0
RESULT: PASS
```

## 25. Baselines por milestone

DeviceGraph:

```text
7 tests
359 checks
```

SystemProfile:

```text
3 tests
142 checks
```

DeviceCatalog:

```text
3 tests
89 checks
```

DeviceGraphAssembler:

```text
2 tests
114 checks
```

Runtime Construction:

```text
6 tests
173 checks
```

## 26. Documentos vigentes

```text
Core Architecture:
2.15

Engineering Standards:
1.3

System Composition Pipeline Design:
1.6

Runtime Construction Contract Design:
1.1

RuntimeFactoryRegistry Design:
1.0

CompositionPlan Design:
1.0

Velocity Test Dashboard Design:
1.4

DeviceGraphAssembler Design:
1.1

DeviceCatalog Design:
1.1

DeviceGraph Design:
1.3

Project Handoff:
1.3

Resume Prompt:
1.3

Collaboration Contract:
1.0
```

## 27. Git

Repositorio:

```text
https://github.com/03im84/velocity
```

Rama:

```text
main
```

Último commit conocido:

```text
659c3c3
docs(runtime):
close runtime construction contract 1.0
```

Commits relevantes:

```text
5056e15
docs(tools):
record dashboard 0.4.0 baseline

db330c2
feat(tools):
add test metrics and automatic suites

4147ec4
feat(runtime):
add runtime construction contracts

1dee94c
docs(runtime):
define runtime construction contract

e21caed
docs(project):
add recovery and collaboration package
```

Estado local esperado durante este cierre:

```text
 M docs/architecture/core_architecture.md
 M docs/architecture/system_composition_pipeline_design.md
 M docs/project_state/velocity_handoff.md
 M docs/project_state/velocity_resume_prompt.md
?? docs/architecture/runtime_factory_registry_design.md
?? docs/architecture/composition_plan_design.md
?? docs/project_journal/pj0032_040926.txt
```

Implementación permanece limpia.


## 28. Convenciones GDScript

Nunca comenzar línea con `.`.

Mantener:

```gdscript
object.property

object.method()

ClassName.CONSTANT
```

Mantener tipos completos:

```gdscript
Array[Type]

Dictionary[Key, Value]
```

Revisar métodos Object:

```text
connect

disconnect

emit_signal

call

free

get

set
```

## 29. Pruebas

Ante fallo:

1. no modificar;

2. copiar primer error completo;

3. incluir archivo y línea;

4. clasificar;

5. entregar archivo completo corregido.

Autoridad:

```text
Godot Console

+

headless

+

Velocity Test Runner
```

## 30. Project State Package

```text
velocity_handoff.md

velocity_resume_prompt.md

velocity_collaboration_contract.md
```

En un chat nuevo se adjuntan los tres.

## 31. Borrador alternativo

Conservado fuera del repositorio:

```text
recovered_runtime_factory_and_composition_plan_design_250826.md
```

No es arquitectura canónica.

No implementar directamente.

Ideas incorporadas a los diseños activos:

- lifecycle order derivado;
- phase barriers;
- DeviceBusDispatchPolicy obligatoria;
- communication directives tipadas;
- rollback inverso;
- Last Known Good.

Ideas que permanecen futuras:

- RuntimeHost concreto;
- scheduling mediante SCC;
- temporal boundaries.

Alternativas rechazadas:

- Callable;
- factory en Plan;
- host target como Key;
- Registry mutable sin diseño;
- Dictionaries genéricos;
- topological order obligatorio.

## 32. Jerarquía de autoridad

1. código;

2. tests;

3. ADR;

4. diseños;

5. Core Architecture;

6. Engineering Standards;

7. handoff;

8. Collaboration Contract;

9. journals;

10. conversación.

## 33. Protocolo de chat nuevo

Un asistente nuevo debe resumir:

- visión;
- último milestone;
- baseline;
- Git;
- siguiente milestone;
- decisiones aceptadas;
- archivos requeridos.

No debe escribir código en primera respuesta.

## 34. Próximo paso exacto

### Cierre documental inmediato

```text
1. Guardar Project Handoff 1.3.

2. Actualizar Resume Prompt a 1.3.

3. Ejecutar auditoría documental.

4. Crear commit arquitectónico.

5. Ejecutar push a origin/main.
```

Commit sugerido:

```text
docs(runtime): define factory registry and composition plan
```

### Primera implementación posterior

```text
res://core/runtime/runtime_dependency_spec.gd
```

Prueba sucesora:

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

RuntimeFactoryRegistryCompilerTest

Run All

CompositionDeviceEntry

CompositionConnectionDirective

CompositionPlan

Registry–Plan Integration

Run All

CompositionCompiler Design
```

No se implementará CompositionCompiler antes de completar e integrar Registry y Plan.

## 35. Regla final

El proyecto no depende del chat.

Git conserva producto.

ADR conserva decisiones.

Diseños conservan contratos.

Tests conservan comportamiento.

Dashboard cuantifica baseline.

Handoff conserva continuidad.
