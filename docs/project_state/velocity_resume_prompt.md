# Velocity — Resume Prompt

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.20 |
| Fecha | 03/10/2026 |
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
composition_runtime_design.md
ADR-011 — Composition Runtime Activation, Ownership and Rollback.md
system_composition_pipeline_design.md
git status -sb
git log -1 --oneline
```

Repositorio:

```text
https://github.com/03im84/velocity
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

- Runtime Construction Contract 1.0 está implementado y verificado.
- RuntimeFactoryRegistry 1.0 está implementado y verificado.
- CompositionPlan 1.0 está implementado y verificado.
- CompositionCompiler 1.0 está implementado y verificado.
- ADR-011 1.1 está aceptado, implementado y verificado.
- CompositionRuntimeOperationResult 1.0 está implementado y verificado.
- CompositionRuntime 1.0 está implementado y verificado.
- Full Composition Runtime Pipeline está verificado hasta ACTIVE y SHUTDOWN.
- Velocity Submit Tool 1.0.0 está implementado y verificado.
- Guided ZIP picker, transactional Install y Submit están activos.
- 44 tests propios y 61 tests de tooling pasan.
- Windows launcher, process Bypass y Tkinter picker están verificados.
- ADR-012 está aceptado.
- Managed Runtime Adapter Boundary Design 1.0 está activo.
- Managed Runtime Adapter Boundary 1.0 está implementado y verificado.
- Runtime Suite: 17 tests / 420 checks PASS.
- Run All: 76 tests / 2262 checks PASS.

Baseline esperada:

- 69 tests.
- 2156 checks.
- 0 failures.
- 0 missing metrics.
- Plan ExitCode 0.
- RESULT PASS.

Composition Suite esperada:

- 16 tests.
- 702 checks.
- 0 failures.

Último commit de implementación esperado:

cc9a7ae feat(runtime): add transactional composition runtime

Milestone actual:

Velocity Submit Tool 1.0.0
IMPLEMENTADO Y VERIFICADO

Managed Runtime Adapter Boundary tiene ADR y diseño aceptados; su implementación está autorizada después del commit documental.

Antes de responder:

1. Lee completamente los tres documentos de Project State.

2. Revisa ADR-011 y CompositionRuntime Design 1.1.

3. No inventes APIs, clases, rutas, versiones o decisiones.

4. Respeta código versionado, pruebas aceptadas, ADR y diseños.

5. Las pruebas aceptadas son baselines inmutables.

6. Una arquitectura nueva requiere prueba sucesora.

7. Toda modificación se entrega como archivo completo consolidado.

8. No uses parches, diffs, fragmentos, inserciones parciales o cirugía manual.

9. Antes de instalar Velocity Submit Tool, los paquetes se extraen fuera de Velocity y solo repository_files/ entra al repositorio.

10. Después de su baseline, el ZIP permanece externo y guided mode ejecuta Install; README.txt, SHA256SUMS.txt, SUBMIT_MANIFEST.json, carpeta y ZIP nunca entran al repositorio.

11. Si una prueba falla, solicita el primer error completo con ruta y línea.

12. La ejecución autoritativa utiliza Godot Console, headless y Velocity Test Runner.

13. No uses Run Current Scene como evidencia autoritativa.

14. No escribas código durante problema, análisis, ADR o diseño abierto.

15. Propón alternativas y tradeoffs.

16. No aceptes automáticamente mis ideas ni las tuyas.

17. Mantén una responsabilidad por componente.

18. Prefiere composición sobre herencia.

19. No añadas singleton o autoload por comodidad.

20. Aplica:

    El usuario o el entorno pueden equivocarse.
    El simulador debe permanecer seguro.

21. Trabaja en español.

22. Mantén tono claro, didáctico, directo, cercano y honesto.

23. CompositionRuntime 1.0 es Simulation-only, one-shot y transaccional.

24. SHUTDOWN y FAILED son terminales.

25. Last Known Good y hot swap pertenecen a un Supervisor futuro.

26. Hardware Runtime permanece bloqueado.

27. Production collaborators no pueden convertirse en service locators.

Tu primera respuesta debe incluir únicamente:

A. confirmación de lectura;
B. visión del proyecto;
C. último milestone completado;
D. baseline global y Composition Suite;
E. último commit y estado Git conocido;
F. milestone recomendado;
G. decisiones aceptadas;
H. riesgos o contradicciones;
I. archivos adicionales requeridos;
J. pregunta de confirmación.

No escribas implementación en la primera respuesta.

Si no puedes acceder a un archivo:

- indícalo;
- solicita la ruta;
- no reconstruyas por intuición.

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

Espera confirmación antes de avanzar.
```

## 3. Estado técnico esperado

Milestones completados:

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
```

Pipeline implementado:

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

## 4. CompositionRuntime 1.0

Componentes:

```text
res://core/composition/composition_runtime_operation_result.gd
res://core/composition/composition_runtime.gd
```

Constructor:

```text
RuntimeFactoryRegistry
RuntimeDependencyValueResolver behavior
RuntimeHost behavior
RuntimeLifecycleAdapter behavior
RuntimeCommunicationBinder behavior
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

Características:

- Simulation-only;
- stateful;
- one-shot;
- transaccional;
- DeviceBus owned;
- phase barriers;
- commit ACTIVE completo;
- rollback inverso;
- shutdown inverso;
- cleanup best effort;
- sin hot swap;
- sin service locator;
- sin singleton;
- sin IO;
- sin threads.

## 5. Activation y rollback

Activation:

```text
Preflight
├── validate Plan, Registry and collaborators
└── resolve declared Dependency Values
→ Create Bus
→ Configure Policy
→ Create Bindings and Build All
→ Attach All
→ Bind All
→ Initialize All
→ Ready All
→ Start All
→ ACTIVE
```

Rollback y shutdown:

```text
shutdown reverse
→ unbind reverse
→ detach reverse
→ release reverse
→ DeviceBus.clear
```

Si initialize falla parcialmente, el Handle actual entra en shutdown best effort.

Cleanup no se detiene por el primer error.

## 6. Runtime tests

```text
CompositionRuntimeOperationResultTest
17 checks
PASS

CompositionRuntimeTest
62 checks
PASS

CompositionRuntimeIntegrationTest
57 checks
PASS

FullCompositionRuntimePipelineIntegrationTest
50 checks
PASS
```

Total:

```text
4 tests
186 checks
0 failures
```

## 7. Baseline global

```text
Planned: 69
Completed: 69
Passed: 69
Failed: 0
Timeout: 0
Engine Error: 0
Not Run: 0
Total Runs: 69
Checks: 2156
Check Failures: 0
Missing Metrics: 0
Plan ExitCode: 0
RESULT: PASS
```

Composition Suite:

```text
Planned: 16
Completed: 16
Passed: 16
Failed: 0
Checks: 702
Check Failures: 0
Missing Metrics: 0
RESULT: PASS
```

## 8. Documentos canónicos

```text
Core Architecture:                  2.26
Engineering Standards:              1.9
Project Decision VP-002:            2.0
ADR-010:                            1.1
ADR-011:                            1.1
ADR-012:                            1.1
System Composition Pipeline Design: 1.16
Runtime Construction Contract:      1.1
RuntimeFactoryRegistry Design:      1.5
CompositionPlan Design:             1.5
CompositionCompiler Design:         1.4
CompositionRuntime Design:          1.1
Velocity Submit Tool Design:         1.2
Velocity Tooling Dashboard Web:      1.2
Managed Runtime Adapter Design:      1.1
Distance Sensor Runtime Design:     1.1
Product Roadmap:                    1.0
Playable Vertical Slice Design:     1.0
Project Handoff:                    1.20
Resume Prompt:                      1.20
Collaboration Contract:             1.5
```

## 9. Git

Último commit de implementación:

```text
cc9a7ae
feat(runtime): add transactional composition runtime
```

Commit de diseño anterior:

```text
0563dd5
docs(runtime): define composition runtime activation
```

Estado esperado después del push de implementación:

```text
## main...origin/main
```

Último commit documental:

```text
38a5ea7
docs(runtime): record composition runtime 1.0 baseline
```

Tooling baseline:

```text
f7bd176 feat(tools): add guided package delivery
19d1be8 docs(tools): record guided package delivery baseline
```

Próximo commit documental:

```text
docs(runtime): define managed adapter boundary
```

## 10. RuntimeFactoryRegistry y Plan

Registry:

- lookup exacto;
- inmutable;
- no ejecuta;
- no fallback;
- no latest;
- no overwrite.

CompositionPlan:

- inmutable;
- no ejecutable;
- conserva Keys y Specs;
- no contiene factory, Callable, Value activo, Handle o Bus;
- conserva DeviceBusDispatchPolicy;
- deriva órdenes forward y reverse.

CompositionCompiler y CompositionRuntime utilizan la misma Registry explícita durante una activación.

## 11. Velocity Submit Tool 1.0.0

Estado:

```text
IMPLEMENTADO Y VERIFICADO
```

Entrada principal:

```text
tools\git\velocity_submit.bat
```

Contrato:

```text
native ZIP picker
→ Install
→ authoritative tests
→ second invocation
→ Submit
```

Baseline:

```text
44 own tests PASS
17 Dashboard Logic PASS
61 total tooling PASS
Windows launcher PASS
Tkinter picker PASS
```

Commit:

```text
f7bd176 feat(tools): add guided package delivery
```

## 12. Ownership

```text
BORROWED
```

Owner original permanece.

```text
TRANSFERRED
```

Transferencia comienza en `factory.build(request)`.

Factory limpia el request actual si build falla.

Runtime libera Handles exitosos anteriores en orden inverso.

## 13. Last Known Good

CompositionRuntime 1.0 no reemplaza otra instancia activa.

Un Supervisor futuro será owner de Last Known Good.

Hot swap no está diseñado para 1.0.

No añadirlo como parche.

## 14. Current direction

```text
Product target: Playable Vertical Slice 1.0
Current milestone: Input Runtime Slice 1.0
```

Roadmap/Gantt is data-driven from `velocity_roadmap.json`.

## 15. Fuera de alcance actual

```text
Distance Sensor Runtime Slice
CompositionRuntimeSupervisor
Last Known Good manager
hot swap
multi-runtime
Hardware Runtime
production factories
persistence
telemetry concreta
automatic recovery
```

## 16. Señales de pérdida de contexto

Detener si un asistente propone:

- DeviceBus como autoload;
- singleton global;
- DeviceCatalog con factories;
- DeviceGraph transportando mensajes;
- latest o fallback;
- Callable como factory;
- factory dentro de Plan;
- factory inicia lifecycle;
- factory adjunta Nodes;
- service locator;
- Registry mutable;
- Registry dentro de Plan;
- RuntimeDependencySpec con Value activo;
- Plan sin Dispatch Policy;
- Compiler ejecutando runtime;
- Runtime reutilizable después de FAILED o SHUTDOWN;
- hot swap dentro de Runtime 1.0;
- Hardware activation sin diseño sucesor;
- tests aceptados modificados;
- archivos por fragmentos;
- código antes de diseño.

## 17. Protocolo de fallo

```text
1. Detener.
2. Copiar primer error completo.
3. Incluir archivo y línea.
4. Clasificar parser, contrato o comportamiento.
5. Revisar responsabilidad.
6. Entregar archivo completo corregido.
7. Ejecutar prueba aislada.
8. Ejecutar regresión.
9. Aceptar baseline solo en PASS.
```

## 18. Protocolo Git

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

Después:

```powershell
git log -1 --oneline
git status --short
git push origin main
git status -sb
```

`Submit` significa staging + commit + push.

## 19. Tooling

Velocity Test Dashboard:

```text
0.4.0
```

Runner Metrics Protocol:

```text
1
```

El experimento Java VTD permanece externo.

Python VTD permanece canónico.

## 20. Regla final

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
Project State Package
```
