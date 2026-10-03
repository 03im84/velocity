# Velocity — Project Handoff

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.7 |
| Fecha de actualización | 02/10/2026 |
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

> El usuario puede fallar. El simulador no.

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
The User or Environment May Err;
The Simulator Must Remain Safe
```

VP-002 vigente:

```text
Versión 2.0

docs/decisions/
VP-002 — The User or Environment May Err;
The Simulator Must Remain Safe.md
```

Lema corto:

> El usuario puede fallar. El simulador no.

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

### RuntimeFactoryRegistry

```text
RuntimeDependencySpec

RuntimeFactoryDescriptor

RuntimeFactoryRegistryDraft

RuntimeFactoryRegistry

RuntimeFactoryRegistryCompileResult

RuntimeFactoryRegistryCompiler
```

Lookup exacto.

Registry inmutable.

Sin latest, fallback u overwrite.

No ejecución de factories.

### CompositionPlan

```text
CompositionDeviceEntry

CompositionConnectionDirective

CompositionPlan
```

Plan inmutable y no ejecutable.

Dispatch Policy explícita.

Órdenes forward y reverse derivados.

Registry–Plan Integration verificada.

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

RuntimeFactoryRegistry 1.0

CompositionPlan 1.0
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

Último milestone completado:

```text
CompositionPlan 1.0
IMPLEMENTADO Y VERIFICADO
```

Integración completada:

```text
RuntimeFactoryRegistry–CompositionPlan
PASS
```

Diseño activo:

```text
CompositionCompiler Design 1.0
```

Decisiones principales:

- Compiler stateless;
- cuatro inputs explícitos;
- CompositionCompileResult;
- Simulation-only;
- Hardware Safety gate;
- Device stage antes de Connection stage;
- no Plan parcial;
- no factory execution;
- no service locator.

Implementación comienza después del commit documental.

## 21. RuntimeFactoryRegistry 1.0

Estado:

```text
IMPLEMENTADO Y VERIFICADO
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

Baseline:

```text
Tests: 4
Checks: 141
Failures: 0
RESULT: PASS
```

Commit:

```text
ca2aa04
feat(runtime): add immutable factory registry
```

## 22. CompositionPlan 1.0

Estado:

```text
IMPLEMENTADO Y VERIFICADO
```

RuntimeFactoryRegistry 1.0 está completo e integrado con Plan.

Componentes implementados:

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

Baseline propia:

```text
4 tests
141 checks
0 failures
```

Composition Suite:

```text
9 tests
397 checks
0 failures
```

Commit:

```text
3d62a7b
feat(composition): add immutable composition plan
```

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
Planned: 62
Completed: 62
Passed: 62
Failed: 0
Timeout: 0
Engine Error: 0
Not Run: 0
Total Runs: 62
Checks: 1851
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

RuntimeFactoryRegistry:

```text
4 tests
141 checks
```

Runtime Suite:

```text
10 tests
314 checks
```

CompositionPlan:

```text
4 tests
141 checks
```

Composition Suite:

```text
9 tests
397 checks
```

## 26. Documentos vigentes

```text
Core Architecture:
2.19

Engineering Standards:
1.4

Project Decision VP-002:
2.0

ADR-002:
1.2

ADR-007:
1.1

ADR-010:
1.1

System Composition Pipeline Design:
1.9

Runtime Construction Contract Design:
1.1

RuntimeFactoryRegistry Design:
1.3

CompositionPlan Design:
1.3

CompositionCompiler Design:
1.1

Velocity Test Dashboard Design:
1.4

DeviceGraphAssembler Design:
1.1

DeviceCatalog Design:
1.1

DeviceGraph Design:
1.3

Project Handoff:
1.7

Resume Prompt:
1.7

Collaboration Contract:
1.1
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
c65ed67
docs(composition):
define composition compiler
```

Commits relevantes:

```text
f2c65de
docs(composition):
record composition plan 1.0 baseline

3d62a7b
feat(composition):
add immutable composition plan

c235b6b
docs(runtime):
record factory registry 1.0 baseline

2a7f9a7
chore(editor):
add custom theme switcher

ca2aa04
feat(runtime):
add immutable factory registry

77a68e3
docs(runtime):
define factory registry and composition plan

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

Estado sincronizado previo al cierre documental:

```text
## main...origin/main
```

Implementación permanece limpia.

El Dashboard Java experimental permanece externo y no forma parte de Velocity.


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

### Revisión arquitectónica inmediata

```text
1. Registrar VP-002 versión 2.0.

2. Conservar redirect histórico de VP-002 1.0.

3. Restaurar contenido correcto de ADR-010.

4. Actualizar Engineering Standards 1.4.

5. Actualizar Collaboration Contract 1.1.

6. Actualizar Core Architecture 2.19.

7. Actualizar CompositionCompiler Design 1.1.

8. Ejecutar auditoría documental.

9. Crear commit de arquitectura.

10. Ejecutar push a origin/main.
```

Commit sugerido:

```text
docs(architecture): clarify simulator integrity and restore ADR-010
```

### Primera implementación posterior

```text
res://core/composition/composition_compile_result.gd
```

Prueba sucesora:

```text
res://test/core/composition/CompositionCompileResultTest.tscn

res://test/core/composition/composition_compile_result_test.gd
```

No se implementará antes del commit de revisión.

## 35. Regla final

El proyecto no depende del chat.

Git conserva producto.

ADR conserva decisiones.

Diseños conservan contratos.

Tests conservan comportamiento.

Dashboard cuantifica baseline.

Handoff conserva continuidad.
