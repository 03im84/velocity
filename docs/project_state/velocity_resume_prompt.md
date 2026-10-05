# Velocity — Resume Prompt

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.24 |
| Fecha | 04/10/2026 |
| Propósito | Reanudar Velocity sin perder arquitectura, metodología, baselines o colaboración |

## 1. Archivos a adjuntar

En un chat nuevo, adjuntar:

```text
velocity_handoff.md
velocity_resume_prompt.md
velocity_collaboration_contract.md
```

También adjuntar cuando sea posible:

```text
input_runtime_slice_design.md
ADR-014 — Input Intent Sampling and Runtime Publication.md
velocity_roadmap.json
git status -sb
git log -1 --oneline
```

Repositorio:

```text
https://github.com/03im84/velocity
```

Engine:

```text
Godot Engine 4.7.1 stable
```

## 2. Prompt listo para copiar

```text
Estoy continuando el desarrollo de Velocity.

Repositorio:
https://github.com/03im84/velocity

Engine:
Godot Engine 4.7.1 stable

Rama:
main

He adjuntado:
- velocity_handoff.md
- velocity_resume_prompt.md
- velocity_collaboration_contract.md

Estado arquitectónico esperado:
- DeviceBus y Runtime Safety están implementados.
- Topic y Message Contracts están implementados.
- Device Core, Profiles, Configuration y DeviceGraph están implementados.
- SystemProfile, DeviceCatalog y DeviceGraphAssembler están implementados.
- Runtime Construction Contract 1.0 está implementado.
- RuntimeFactoryRegistry, CompositionPlan y CompositionCompiler están implementados.
- CompositionRuntime 1.0 está implementado y verificado.
- Managed Runtime Adapter Boundary 1.0 está implementado y verificado.
- Distance Sensor Runtime Slice 1.0 está implementado y verificado.
- Input Runtime Slice 1.0 está implementado y verificado.
- ADR-014 1.1 está aceptado, implementado y verificado.
- Input Suite: 6 tests / 101 checks PASS.
- Runtime Suite: 20 tests / 475 checks PASS.
- Run All: 85 tests / 2418 checks PASS.
- 0 failures, 0 timeout, 0 engine errors y 0 missing metrics.
- Último commit del Slice: 80c5118 test(input): add runtime pipeline integration.
- Input baseline documental: 26002da docs(input): record input runtime baseline.
- Web VTD Reload Safety: d36c7ee fix(tools): make web dashboard reload-safe.
- Delivery Rollback 1.1: b219462 feat(tools): add delivery rollback command.
- main está sincronizada con origin/main en b219462.

Target de producto:
Playable Vertical Slice 1.0.

Siguiente milestone de producto:
Propulsion Runtime Slice 1.0.
Problema, alternativas, ADR y diseño todavía pendientes.

Trabajo operativo separado:
Velocity Submit Tool Rollback 1.1 está implementado y verificado.
Windows self-rollback restauró d36c7ee con Git limpio y receipt ausente.
Baseline final: 126 tooling tests PASS.
Feature commit: b219462 feat(tools): add delivery rollback command.
main quedó sincronizada con origin/main.
El backup original sigue preservado fuera del repositorio en:
C:\Users\fuent\Documents\VelocityRecovery-20261004-162750
No mezclar con Propulsion.

Antes de responder:
1. Lee completamente los tres documentos de Project State.
2. Revisa ADR-014, Input Runtime Slice Design y velocity_roadmap.json.
3. Revisa Git; no inventes el estado actual.
4. No inventes APIs, clases, rutas, versiones o decisiones.
5. Respeta código versionado, tests aceptados, ADR y diseños.
6. Las pruebas aceptadas son baselines inmutables.
7. Una arquitectura nueva requiere prueba sucesora.
8. Toda modificación se entrega como archivo completo mediante Web VTD Delivery.
9. No uses parches, fragmentos ni cirugía manual.
10. Si una prueba falla, detente y solicita el primer error completo con archivo, línea y backtrace.
11. La autoridad de pruebas es Godot Console, headless y Velocity Tooling Dashboard Web.
12. No uses Run Current Scene como evidencia autoritativa.
13. No escribas implementación antes de cerrar problema, análisis, ADR y diseño.
14. Propón alternativas y tradeoffs.
15. Mantén una responsabilidad por componente.
16. Prefiere composición sobre herencia.
17. No añadas singleton, autoload o service locator por comodidad.
18. Hardware Runtime permanece bloqueado sin diseño sucesor.
19. Trabaja en español con tono claro, didáctico, directo, cercano, riguroso y honesto.
20. No existe trabajo en background: cada entrega se realiza en tiempo real.

Tu primera respuesta debe incluir únicamente:
A. confirmación de lectura;
B. visión del proyecto;
C. último milestone completado;
D. baseline global, Input Suite y Runtime Suite;
E. último commit y estado Git conocido;
F. siguiente milestone de producto;
G. trabajo operativo pendiente;
H. decisiones aceptadas;
I. riesgos o contradicciones;
J. pregunta de confirmación.

No escribas implementación en la primera respuesta.

Jerarquía de autoridad:
1. código versionado;
2. pruebas aceptadas;
3. ADR aceptados;
4. diseños activos;
5. Core Architecture;
6. Engineering Standards;
7. velocity_handoff.md;
8. velocity_collaboration_contract.md;
9. journals;
10. conversación.
```

## 3. Visión

Velocity es una plataforma y juego modular de carreras antigravitatorias inspirado en Wipeout.

Objetivos:

- nave antigravitatoria jugable;
- arquitectura modular;
- composición explícita;
- simulación segura;
- hardware futuro;
- telemetría futura;
- aprendizaje técnico.

Regla canónica:

> El usuario o el entorno pueden equivocarse. Una operación puede ser rechazada o abortada. El simulador debe permanecer seguro, consistente y recuperable.

Lema:

> El usuario puede fallar. El simulador no.

## 4. Arquitectura implementada

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
```

## 5. Pipeline runtime

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

CompositionRuntime 1.0 es:

- Simulation-only;
- stateful;
- one-shot;
- transaccional;
- owner de DeviceBus;
- phase-barriered;
- best-effort cleanup;
- terminal después de `SHUTDOWN` o `FAILED`.

Last Known Good y hot swap pertenecen a un Supervisor futuro.

## 6. Input Runtime Slice 1.0

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

Factory Key:

```text
velocity.input.player / 1 / Simulation
```

Dependency:

```text
input_intent_provider / BORROWED
```

Effective Configuration:

```text
capability: vehicle_control_input
publishes: vehicle_control_command
subscribes: none
```

Lifecycle:

```text
CREATED → INITIALIZED → READY → RUNNING → SHUTDOWN
```

Invariantes:

- Provider fuera de Core;
- Factory construct-only;
- Sampler es Host Object owned;
- sampling solo en `RUNNING`;
- neutral command válido;
- valores finitos y acotados;
- source identity preservada;
- Provider `BORROWED` sobrevive release;
- sin autoload, singleton, service locator o thread.

## 7. Input tests

```text
VehicleControlCommandTest:                   12 checks
GodotInputIntentProviderTest:                17 checks
InputSamplingNodeTest:                       10 checks
InputRuntimeUnitTest:                        18 checks
InputRuntimeFactoryTest:                     21 checks
InputRuntimePipelineIntegrationTest:         23 checks
```

```text
Input Suite
Planned: 6
Passed: 6
Checks: 101
Failures: 0
RESULT: PASS
```

La integración concreta verifica:

```text
Profile
→ Catalog
→ SystemProfile
→ Graph
→ Registry
→ Plan
→ Runtime
→ ACTIVE
→ physics tick
→ command
→ SHUTDOWN
```

`output_port_unconnected / INFO` es esperado para este Device source-only.

## 8. Baseline vigente

Runtime Suite:

```text
Planned: 20
Completed: 20
Passed: 20
Checks: 475
Failures: 0
Timeout: 0
Engine Error: 0
Missing Metrics: 0
RESULT: PASS
```

Run All:

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

## 9. Documentos canónicos

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

## 10. Git

Commits del Input Runtime Slice:

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

Estado confirmado:

```text
## main...origin/main
HEAD b219462
```

El estado Git actual debe comprobarse en cada reanudación.

## 11. Dirección actual

```text
Product target: Playable Vertical Slice 1.0
Completed: Input Runtime Slice 1.0
Current product milestone: Propulsion Runtime Slice 1.0
```

Roadmap:

```text
docs/project_state/velocity_roadmap.json
Version: 1.1
current_milestone: propulsion_runtime_slice
```

Propulsion todavía requiere:

```text
Problem
Analysis
Alternatives and tradeoffs
ADR
Design
Review and approval
Documentation commit
```

## 12. Web VTD Reload Safety 0.5.1

Contrato vigente:

```text
fresh page
→ bootstrap event cursor
→ no historical prompt replay

SSE reconnect
→ Last-Event-ID
→ missed live events replayed

pending prompt
→ confirm against /api/state
→ display once

successful Install
→ refresh tests and roadmap
```

Baseline:

```text
VTD Web: 43 tests PASS
Submit Tool: 44 tests PASS
Dashboard Logic: 17 tests PASS
Total tooling: 104 tests PASS
```

## 13. Velocity Submit Tool Rollback 1.1

```text
Velocity Submit Tool Rollback 1.1
Estado: IMPLEMENTADO Y VERIFICADO
Feature commit: b219462
Self-rollback baseline verificada: d36c7ee
```

Backup externo original:

```text
C:\Users\fuent\Documents\VelocityRecovery-20261004-162750
```

El backup fue auditado fuera del repositorio. No restaurar literalmente.

Excluidos:

- Factory Input antigua;
- escena snake_case antigua;
- receipt histórico;
- logs Git históricos.

Candidato reconstruido:

```text
DeliveryRollback
--rollback / -Rollback
Web endpoint y botón rollback
confirmación textual ROLLBACK
exact receipt/branch/HEAD/index/allowlist/hash gates
safe derived UID removal
reverse restore
clean-status postcondition
```

Baseline local:

```text
Submit Tool:     62 tests PASS
Web VTD:         47 tests PASS
Dashboard Logic: 17 tests PASS
Total tooling:  126 tests PASS
```

Acceptance ejecutada:

```text
validation candidate installed
→ 125 Windows tooling tests PASS
→ self-rollback PASS
→ d36c7ee clean
→ receipt none
```

Finalización:

```text
final delivery installed
→ 126 Windows tooling tests PASS
→ visual Environment/alignment PASS
→ Submit PASS
→ b219462 synchronized
```

Rollback 1.1 está cerrado. No mezclar futuros cambios de tooling con Propulsion.

## 14. Fuera de alcance actual

```text
Propulsion implementation antes de ADR
Hover Physics
Playable Vehicle Composition
track
camera
HUD
lap system
CompositionRuntimeSupervisor
Last Known Good manager
hot swap
Hardware Runtime
telemetry persistente
```

## 15. Protocolo de fallo

```text
1. Detener.
2. No modificar archivos.
3. Capturar primer error completo.
4. Incluir archivo, línea y backtrace.
5. Clasificar parser, contract o behavior.
6. Revisar responsabilidad.
7. Corregir mediante archivo completo.
8. Ejecutar prueba aislada.
9. Ejecutar Suite relevante.
10. Ejecutar Run All.
```

## 16. Protocolo Git y Delivery

Flujo normal:

```text
Select ZIP
→ Install
→ authoritative tests
→ Prepare Submit
→ textual SUBMIT confirmation
→ exact staging
→ commit
→ push
```

`Submit` significa staging + commit + push.

No usar:

```text
git add .
git add -A
git commit -a
git reset --hard
git clean -fd
git clean -fdx
git restore .
git checkout -- .
force push
amend de commit publicado
```

Los ZIP permanecen fuera del repositorio.

## 17. Metodología

```text
1. Problema
2. Análisis
3. Alternativas y tradeoffs
4. ADR
5. Diseño
6. Revisión y aprobación
7. Commit documental
8. Implementación
9. Unit tests
10. Integración
11. Refactor audit
12. Regresión
13. Baseline
14. Submit
```

## 18. Regla final

Un nuevo chat no necesita imitar una voz exacta.

Debe preservar:

- decisiones;
- rigor;
- metodología;
- honestidad;
- cercanía;
- baselines;
- responsabilidades;
- seguridad;
- aprendizaje.

La continuidad depende de:

```text
Git
+
ADR
+
Diseños
+
Tests
+
Project State
```
