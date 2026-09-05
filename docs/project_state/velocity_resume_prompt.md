# Velocity — Resume Prompt

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.2 |
| Fecha | 04/09/2026 |
| Propósito | Reanudar Velocity sin perder arquitectura, metodología, baselines o colaboración |

## 1. Archivos a adjuntar

En un chat nuevo, adjuntar:

```text
velocity_handoff.md

velocity_resume_prompt.md

velocity_collaboration_contract.md
```

También adjuntar cuando sea posible:

- ADR del milestone;
- diseños activos;
- `git status -sb`;
- URL del repositorio.

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

Antes de responder:

1. Lee completamente los tres documentos.

2. No propongas código todavía.

3. No inventes APIs, clases, rutas, versiones o decisiones.

4. Respeta ADR, diseños activos y pruebas.

5. Las pruebas aceptadas son baselines inmutables.

6. Una arquitectura nueva requiere prueba sucesora.

7. Toda modificación se entrega como archivo completo consolidado.

8. No uses parches, diffs, inserciones parciales, eliminaciones parciales o cirugía manual.

9. Si una prueba falla, solicita el primer error completo.

10. La ejecución autoritativa utiliza Godot Console, headless y Velocity Test Runner.

11. No uses Run Current Scene como evidencia autoritativa.

12. No escribas código durante problema, análisis, ADR o diseño abierto.

13. Propón alternativas y tradeoffs.

14. No aceptes automáticamente mis ideas ni las tuyas.

15. Mantén una responsabilidad por componente.

16. Prefiere composición sobre herencia.

17. No añadas singleton o autoload por comodidad.

18. Aplica:

	La simulación puede fallar.
	El simulador no.

19. El usuario reescribe manualmente los archivos.

20. Indica siempre la ruta exacta.

21. Trabaja en español.

22. Mantén tono claro, didáctico, directo, cercano y honesto.

Tu primera respuesta debe incluir únicamente:

A. confirmación de lectura;

B. visión del proyecto;

C. último milestone completado;

D. baseline global;

E. último commit y estado Git conocido;

F. siguiente milestone arquitectónico;

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

Últimos milestones completados:

```text
DeviceGraphAssembler 1.0

Runtime Construction Contract 1.0

Velocity Test Dashboard 0.4.0
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
```

Runtime contracts implementados:

```text
RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult
```

## 4. Baseline global

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

## 5. Tooling

Velocity Test Dashboard:

```text
0.4.0
```

Runner Metrics Protocol:

```text
1
```

Dashboard Logic:

```text
17 unittests
OK
```

Suites:

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
```

Tests en Other:

```text
0
```

## 6. ADR vigentes

```text
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

ADR-010 está implementado por Runtime Construction Contract 1.0.

## 7. RuntimeFactoryKey

```text
Profile ID

+

Profile Version

+

Activation Context
```

No contiene host target.

No existe fallback.

## 8. RuntimeDependencyBinding

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

BORROWED no se libera por factory.

TRANSFERRED pasa a la transacción durante build.

## 9. RuntimeConstructionRequest

Contiene:

- Device ID;
- DeviceConfiguration;
- RuntimeFactoryKey;
- bindings pre-resueltos.

No es service locator.

## 10. RuntimeDeviceHandle

Contiene:

- Device ID;
- Configuration;
- Factory Key;
- Primary Runtime Object;
- Host Objects;
- bindings.

No coordina el sistema completo.

## 11. RuntimeFactory behavior

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

## 12. RuntimeHost behavior

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

## 13. Rollback

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

Last Known Good cambia solo después de commit completo.

## 14. Siguiente milestone

Diseñar conjuntamente:

```text
RuntimeFactoryRegistry

CompositionPlan
```

No implementar todavía:

```text
RuntimeFactoryRegistry

CompositionPlan

CompositionCompiler

CompositionRuntime
```

## 15. RuntimeFactoryRegistry debe resolver

```text
RuntimeFactoryKey

→

RuntimeFactory
```

Decisiones pendientes:

- mutabilidad;
- Draft–Compiler–Snapshot;
- behavior validation;
- duplicados;
- estabilidad;
- lookup;
- release binding;
- persistencia externa.

## 16. CompositionPlan debe definir

- Factory Keys;
- Device entries tipadas;
- dependency directives;
- lifecycle order;
- communication directives;
- DeviceBusDispatchPolicy;
- rollback directives;
- ciclos;
- grupos;
- orden estable.

Plan no contiene:

- factory;
- Callable;
- Handle;
- Device activo;
- Node activo;
- DeviceBus activo.

## 17. Señales de pérdida de contexto

Detener si un asistente propone:

- DeviceBus como autoload;
- singleton global;
- DeviceCatalog con factories;
- DeviceGraph transportando mensajes;
- latest;
- fallback;
- Callable como factory;
- factory dentro de Plan;
- factory devuelve Device directamente;
- factory inicia lifecycle;
- factory adjunta Nodes;
- service locator;
- host target como Factory Key actual;
- CompositionCompiler ejecutando runtime;
- topological sort obligatorio ignorando ciclos;
- tests modificados;
- archivos por fragmentos;
- código antes de diseño.

## 18. Borrador alternativo

Existe fuera del repositorio:

```text
recovered_runtime_factory_and_composition_plan_design_250826.md
```

No es arquitectura canónica.

Ideas candidatas:

- lifecycle order;
- DispatchPolicy;
- communication directives;
- host abstractions.

Alternativas rechazadas:

- Callable;
- factory en Plan;
- host target como Key;
- Registry mutable sin diseño;
- Dictionary entries;
- topological order obligatorio.

## 19. Protocolo de fallo

1. detener;

2. copiar primer error;

3. incluir archivo y línea;

4. clasificar;

5. revisar responsabilidad;

6. entregar archivo completo;

7. probar;

8. aceptar baseline solo en PASS.

## 20. Protocolo Git

```powershell
git status --short

git diff --check

git diff --cached --name-status

git diff --cached --check
```

Después:

```powershell
git log -1 --oneline

git status --short
```

Push:

```powershell
git push origin main

git status -sb
```

## 21. Respuesta inicial correcta

Debe indicar:

```text
Últimos milestones:

DeviceGraphAssembler 1.0

Runtime Construction Contract 1.0

Dashboard 0.4.0

Baseline:

54 tests

1569 checks

0 failures

Siguiente milestone:

RuntimeFactoryRegistry Design

+

CompositionPlan Design
```

No debe escribir código.

## 22. Regla final

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