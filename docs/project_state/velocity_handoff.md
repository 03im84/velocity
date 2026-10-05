# Velocity — Project Handoff

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.24 |
| Fecha de actualización | 04/10/2026 |
| Zona horaria | GMT-5, sin DST |
| Engine | Godot Engine 4.7.1 stable |
| Repositorio | https://github.com/03im84/velocity |
| Rama principal | main |
| Propósito | Recuperación y transferencia completa del contexto de trabajo |

## 1. Propósito

Este documento permite continuar Velocity después de:

- perder acceso a un chat;
- comenzar otra conversación;
- cambiar de asistente o modelo;
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
7. leer diseños activos;
8. revisar código y tests;
9. revisar Git;
10. resumir estado;
11. esperar confirmación.

No debe inventar APIs, clases, rutas, versiones o decisiones.

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

Regla canónica:

> El usuario o el entorno pueden equivocarse. Una operación puede ser rechazada o abortada. El simulador debe permanecer seguro, consistente y recuperable.

Lema:

> El usuario puede fallar. El simulador no.

## 4. Colaboración

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

El usuario delegó decisiones técnicas ordinarias al asistente en beneficio del proyecto.

Debe interrumpirse al usuario solamente cuando sea necesario:

- copiar entregables;
- ejecutar Godot o Dashboard;
- proporcionar el primer error;
- hacer staging, commit o push;
- aprobar una decisión destructiva o de alto impacto.

## 5. Entrega de archivos

Toda modificación se entrega como archivo completo consolidado.

Package layout:

```text
package-root/
├── repository_files/
├── README.txt
├── SHA256SUMS.txt
└── SUBMIT_MANIFEST.json
```

Mientras Velocity Submit Tool no esté implementado, el usuario copia únicamente `repository_files/`.

Después de su baseline, el ZIP permanece fuera de Velocity y la herramienta ejecuta:

```text
Install
→ tests
→ Submit
```

Nunca se guardan dentro del repositorio:

```text
README.txt
SHA256SUMS.txt
SUBMIT_MANIFEST.json
carpeta del paquete
archivo ZIP
```

No se utilizan parches, cirugía manual o fragmentos como estado final.

## 6. Metodología obligatoria

```text
1. Problema
2. Análisis
3. Alternativas y tradeoffs
4. ADR
5. Diseño
6. Revisión y aprobación
7. Commit documental
8. Implementación
9. Pruebas unitarias
10. Integración
11. Refactor audit
12. Regresión
13. Baseline
14. Submit
```

No se escribe implementación durante problema, análisis, ADR o diseño abierto.

Una característica no está terminada hasta:

- prueba sucesora PASS;
- integración PASS;
- Suite relevante PASS;
- Run All PASS;
- refactor audit;
- documentación actualizada;
- Git sincronizado.

## 7. Principios

1. Arquitectura antes que código.
2. Una responsabilidad por componente.
3. Composición sobre herencia.
4. Simplicidad es una característica.
5. UI no define Core.
6. Dependencias explícitas.
7. Pocos autoloads.
8. Sin singleton por comodidad.
9. Drafts editables.
10. Snapshots y planes para runtime.
11. Last Known Good.
12. Colecciones protegidas.
13. Baselines inmutables.
14. Pruebas sucesoras.
15. Documentación es producto.
16. Sin recursión ilimitada.
17. Hardware más estricto.
18. Cleanup best effort con observabilidad.

## 8. Project Decisions

```text
VP-001
Architecture Precedes Code

VP-002 2.0
The User or Environment May Err;
The Simulator Must Remain Safe
```

Documento vigente:

```text
docs/decisions/
VP-002 — The User or Environment May Err; The Simulator Must Remain Safe.md
```

El archivo anterior de VP-002 permanece como redirect histórico `SUPERSEDED`.

## 9. ADR vigentes

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
ADR-011 — Composition Runtime Activation, Ownership and Rollback
ADR-012 — Managed Runtime Object Behaviors and Production Adapter Boundaries
ADR-013 — Distance Sensor Simulation Runtime Slice and Configuration Fidelity
ADR-014 — Input Intent Sampling and Runtime Publication
```

Todos aceptados.

ADR-010 a ADR-014 están implementados y verificados en sus baselines vigentes.

## 10. Arquitectura implementada

```text
DeviceBus y Runtime Safety
Topic y Message Contracts
Provider System
Device Core
DeviceProfile y DeviceConfiguration
DeviceGraph 1.0
SystemProfile 1.0
DeviceCatalog 1.0
DeviceGraphAssembler 1.0
Runtime Construction Contract 1.0
RuntimeFactoryRegistry 1.0
CompositionPlan 1.0
CompositionCompiler 1.0
CompositionRuntime 1.0
Managed Runtime Adapter Boundary 1.0
Distance Sensor Runtime Slice 1.0
Input Runtime Slice 1.0
Velocity Test Runner
Velocity Test Dashboard 0.4.0
Velocity Tooling Dashboard Web 0.5.1
Velocity Submit Tool 1.0.0
Product Roadmap y Gantt 1.0
```

## 11. Pipeline completo verificado

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
↓
RuntimeFactoryRegistry
↓
CompositionCompiler
↓
CompositionPlan
↓
CompositionRuntime
↓
ACTIVE
↓
SHUTDOWN
```

Prueba autoritativa:

```text
FullCompositionRuntimePipelineIntegrationTest
50 checks
0 failures
RESULT: PASS
```

## 12. Runtime Construction Contract 1.0

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

RuntimeFactoryKey:

```text
Profile ID
+
Profile Version
+
Activation Context
```

No existe latest o fallback.

Ownership:

```text
BORROWED
TRANSFERRED
```

Factory construye y libera.

No inicializa, inicia, adjunta o crea Bus global.

RuntimeHost controla attach/detach.

## 13. RuntimeFactoryRegistry 1.0

Componentes:

```text
RuntimeDependencySpec
RuntimeFactoryDescriptor
RuntimeFactoryRegistryDraft
RuntimeFactoryRegistry
RuntimeFactoryRegistryCompileResult
RuntimeFactoryRegistryCompiler
```

Registry:

- inmutable;
- exacto;
- sin latest;
- sin fallback;
- sin overwrite;
- no ejecuta factories;
- separado de DeviceCatalog y CompositionPlan.

Baseline propia:

```text
4 tests
141 checks
0 failures
```

Commit:

```text
ca2aa04 feat(runtime): add immutable factory registry
```

## 14. CompositionPlan 1.0

Componentes:

```text
CompositionDeviceEntry
CompositionConnectionDirective
CompositionPlan
```

Plan es inmutable y no ejecutable.

Contiene:

- Activation Context;
- Device Entries;
- Connection Directives;
- DeviceBusDispatchPolicy.

Conserva Key y Dependency Specs.

No contiene factory, Callable, Value activo, Handle o Bus activo.

Forward order deriva de Entries.

Reverse order invierte Entries.

Baseline propia:

```text
4 tests
141 checks
0 failures
```

Commit:

```text
3d62a7b feat(composition): add immutable composition plan
```

## 15. CompositionCompiler 1.0

Componentes:

```text
CompositionCompileResult
CompositionCompiler
```

Compiler:

- stateless;
- Simulation-only;
- recibe Snapshot, Registry, Context y Policy;
- produce CompositionPlan;
- valida factory exacta;
- traslada Dependency Specs;
- no ejecuta factories o runtime;
- no produce Plan parcial.

Baseline propia:

```text
3 tests
119 checks
0 failures
```

Commit:

```text
4f36fee feat(composition): add composition compiler
```

## 16. CompositionRuntime 1.0

Componentes:

```text
CompositionRuntimeOperationResult
CompositionRuntime
```

Forma:

```gdscript
extends RefCounted
class_name CompositionRuntime
```

Constructor:

```text
RuntimeFactoryRegistry
RuntimeDependencyValueResolver behavior
RuntimeHost behavior
RuntimeLifecycleAdapter behavior
RuntimeCommunicationBinder behavior
```

API:

```gdscript
activate(plan) -> CompositionRuntimeOperationResult
shutdown() -> CompositionRuntimeOperationResult

get_state()
is_active()
get_active_plan()
get_device_bus()
get_handles()
get_handle(device_id)
get_last_dispatch_report()
```

Estados:

```text
CREATED
ACTIVATING
ACTIVE
SHUTTING_DOWN
SHUTDOWN
FAILED
```

`SHUTDOWN` y `FAILED` son terminales.

Runtime 1.0 es:

- Simulation-only;
- stateful;
- one-shot;
- transaccional;
- owner de DeviceBus y Handles;
- sin hot swap;
- sin service locator;
- sin singleton;
- sin IO;
- sin threads.

## 17. Activation pipeline

```text
Preflight
├── validate Plan, Registry and collaborators
└── resolve declared Dependency Values
↓
Create Bus
↓
Configure Policy
↓
Create Bindings and Build All
↓
Attach All
↓
Bind All Communication
↓
Initialize All
↓
Ready All
↓
Start All
↓
Commit ACTIVE
```

ACTIVE se publica únicamente después de completar todas las fases.

No se expone candidato parcial.

## 18. Rollback y shutdown

Orden:

```text
shutdown initialized Handles reverse
↓
unbind bound Directives reverse
↓
detach attached Handles reverse
↓
release built Handles reverse
↓
DeviceBus.clear
```

Si initialize falla parcialmente, el Handle actual se incluye en shutdown best effort.

Cleanup continúa aunque una operación reporte error.

Los Issues se agregan.

Un shutdown limpio termina `SHUTDOWN`.

Un shutdown con cleanup error termina `FAILED`.

## 19. Hardware y Last Known Good

Hardware Runtime 1.0 está bloqueado con:

```text
HARDWARE_SAFETY_ERROR
```

CompositionRuntime 1.0 no sustituye otra instancia activa.

Last Known Good y hot swap pertenecen a un `CompositionRuntimeSupervisor` futuro.

## 20. Baseline CompositionRuntime

Baseline histórica preservada:

```text
CompositionRuntimeOperationResultTest:          17 checks
CompositionRuntimeTest:                         62 checks
CompositionRuntimeIntegrationTest:              57 checks
FullCompositionRuntimePipelineIntegrationTest:  50 checks
Total:                                  4 tests / 186 checks
Composition Suite:                     16 tests / 702 checks
RESULT: PASS
```

## 21. Input Runtime Slice 1.0

Componentes:

```text
VehicleControlCommand
BusTopics.VEHICLE_CONTROL_COMMAND
GodotInputSource
GodotInputIntentProvider
InputSamplingNode
InputRuntimeUnit
InputRuntimeFactory
```

Flujo:

```text
Godot Input
→ GodotInputSource
→ GodotInputIntentProvider
→ InputSamplingNode
→ InputRuntimeUnit
→ VehicleControlCommand
→ DeviceBus
```

Contrato runtime:

```text
Factory Key: velocity.input.player / 1 / Simulation
Dependency: input_intent_provider / BORROWED
Capability: vehicle_control_input
Publishes: vehicle_control_command
Subscribes: none
```

Full pipeline verificado hasta `ACTIVE → physics tick → command → SHUTDOWN`.

## 22. Baseline global

```text
Planned: 85
Completed: 85
Passed: 85
Failed: 0
Timeout: 0
Engine Error: 0
Not Run: 0
Total Runs: 85
Checks: 2418
Check Failures: 0
Missing Metrics: 0
Plan ExitCode: 0
RESULT: PASS
```

Suites:

```text
Input Suite:    6 tests / 101 checks PASS
Runtime Suite: 20 tests / 475 checks PASS
```

## 23. Refactor audit

Input Runtime Slice fue revisado después de aislamiento, integración, Suites y Run All.

Se verificó:

- responsabilidad;
- límites Core/Godot;
- ownership `BORROWED`;
- lifecycle;
- determinismo;
- naming;
- package scope;
- cleanup y release.

Resultado:

```text
PASS
SIN CAMBIO OBLIGATORIO
```

## 24. Documentos y Git

Documentos vigentes:

```text
Core Architecture:                  2.27
Engineering Standards:              1.9
Project Decision VP-002:            2.0
ADR-010:                            1.1
ADR-011:                            1.1
ADR-012:                            1.1
ADR-013:                            1.1
ADR-014:                            1.1
System Composition Pipeline Design: 1.17
Runtime Construction Contract:      1.1
RuntimeFactoryRegistry Design:      1.5
CompositionPlan Design:             1.5
CompositionCompiler Design:         1.4
CompositionRuntime Design:          1.1
Managed Runtime Adapter Design:      1.1
Distance Sensor Runtime Design:     1.1
Input Runtime Slice Design:         1.1
Velocity Submit Tool Design:         1.4
Velocity Tooling Dashboard Web:      1.4
Product Roadmap:                    1.1
Playable Vertical Slice Design:     1.1
Project Handoff:                    1.24
Resume Prompt:                      1.24
Collaboration Contract:             1.5
```

Repositorio:

```text
https://github.com/03im84/velocity
```

Último commit del Input Runtime Slice:

```text
80c5118 test(input): add runtime pipeline integration
```

Commits del Slice:

```text
f06d76a docs(input): define input runtime slice
5522583 feat(input): add vehicle control command
bd3098f feat(input): add godot input intent provider
393e878 feat(input): add input sampling node
f4345cb feat(input): add input runtime unit
0b0b233 feat(input): add input runtime factory
80c5118 test(input): add runtime pipeline integration
```

Commits posteriores aceptados:

```text
26002da docs(input): record input runtime baseline
d36c7ee fix(tools): make web dashboard reload-safe
b219462 feat(tools): add delivery rollback command
```

Estado confirmado después de Rollback 1.1:

```text
## main...origin/main
HEAD b219462
```

## 25. Tooling

```text
Velocity Test Dashboard:          0.4.0
Velocity Tooling Dashboard Web:   0.5.2 verified
Runner Metrics Protocol:          1
Velocity Submit Tool:             1.1.0 verified
```

Suites automáticas:

```text
All
DeviceBus
DeviceCore
Providers
Profiles
Message Contracts
DeviceGraph
Composition
DeviceCatalog
Runtime
Debug
Input
```

```text
Other: 0
```

Baseline de tooling aceptada antes del candidato Rollback:

```text
VTD Web: 43 tests PASS
Tooling total: 104 tests PASS
```

Web VTD Reload Safety 0.5.1:

```text
fresh page starts from bootstrap event cursor
SSE reconnect preserves Last-Event-ID replay
stale delivery prompts are rejected against /api/state
successful Install reloads tests and roadmap
43 Web tests PASS
```

Velocity Submit Tool Rollback 1.1 fue reconstruido sobre `d36c7ee` sin restaurar archivos obsoletos del backup.

```text
Submit Tool:     62 tests PASS
Web VTD:         47 tests PASS
Dashboard Logic: 17 tests PASS
Total tooling:  126 tests PASS
Windows E2E self-rollback: PASS
```

Self-rollback real restauró `d36c7ee`, dejó Git limpio y eliminó el receipt. La Delivery final pasó 126 tooling tests en Windows y fue submitted en `b219462`.

## 26. Convenciones GDScript

Nunca comenzar línea con `.`.

Mantener en la misma línea física:

```gdscript
object.property
object.method()
ClassName.CONSTANT
Array[Type]
Dictionary[Key, Value]
```

Revisar métodos heredados de Object:

```text
connect
disconnect
emit_signal
call
free
get
set
```

DeviceGraph utiliza:

```text
connect_ports
disconnect_ports
```

Naming:

```text
Escenas: PascalCase.tscn
Scripts: snake_case.gd
Resources: snake_case.tres
Clases: PascalCase
Métodos: snake_case
Constantes: UPPER_SNAKE_CASE
Códigos: lower_snake_case StringName
```

## 27. Protocolo de pruebas

Ante fallo:

1. no modificar archivos;
2. pedir primer error completo;
3. incluir ruta, línea y mensaje;
4. clasificar parser, contrato o comportamiento;
5. modificar solo después del análisis.

Autoridad:

```text
Godot Console
+
headless
+
Velocity Test Runner / Dashboard
```

No usar `Run Current Scene` como evidencia.

## 28. Protocolo Git

Antes de commit:

```powershell
git status --short
git diff --check
git diff --cached --name-status
git diff --cached --check
```

No usar:

```powershell
git add .
```

Después de commit:

```powershell
git log -1 --oneline
git status --short
```

Después del milestone:

```powershell
git push origin main
git status -sb
```

Estado sincronizado:

```text
## main...origin/main
```

`Submit` significa staging + commit + push.

## 29. Current direction

```text
Target: Playable Vertical Slice 1.0
Completed: Input Runtime Slice 1.0
Current product milestone: Propulsion Runtime Slice 1.0
```

Roadmap versionado:

```text
docs/project_state/velocity_roadmap.json
Version: 1.1
Current milestone: propulsion_runtime_slice
```

Antes de Propulsion se requieren problema, alternativas, ADR, diseño y aprobación.

Trabajo operativo separado:

```text
Velocity Submit Tool Rollback 1.1
IMPLEMENTADO Y VERIFICADO
WINDOWS END-TO-END SELF-ROLLBACK PASS
126 TOOLING TESTS PASS
COMMIT b219462
```

Backup externo preservado:

```text
C:\Users\fuent\Documents\VelocityRecovery-20261004-162750
```

Rollback 1.1 queda cerrado. El siguiente trabajo de producto, Propulsion, comienza desde problema y análisis separados.

## 30. Trabajo futuro explícito

```text
Propulsion Runtime Slice
Hover Physics Slice
Playable Vehicle Composition
Simple Track Scene
Chase Camera
Checkpoint and Lap Loop
Minimal HUD
CompositionRuntimeSupervisor
Last Known Good manager
Hot swap
Hardware Runtime
Measurement Identity
Provenance
Temporal Boundaries
Persistence
GraphEditor
Calibration
AdaptationPolicy
RuntimeAllocation
Telemetry
Automatic recovery
```

## 31. Project State Package

```text
docs/project_state/velocity_handoff.md
docs/project_state/velocity_resume_prompt.md
docs/project_state/velocity_collaboration_contract.md
```

En un chat nuevo se adjuntan los tres.

## 32. Jerarquía de autoridad

1. código versionado;
2. tests aceptados;
3. ADR aceptados;
4. diseños activos;
5. Core Architecture;
6. Engineering Standards;
7. Project Handoff;
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
- riesgos o contradicciones;
- archivos requeridos.

No debe escribir implementación en su primera respuesta.

## 34. Regla final

El proyecto no depende del chat.

```text
Git conserva producto.
ADR conserva decisiones.
Diseños conservan contratos.
Tests conservan comportamiento.
Dashboard cuantifica baseline.
Handoff conserva continuidad.
```
