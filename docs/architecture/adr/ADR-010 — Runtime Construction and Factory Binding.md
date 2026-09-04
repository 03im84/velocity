# Velocity — Resume Prompt

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Fecha | 25/08/2026 |
| Propósito | Reanudar Velocity sin perder arquitectura, metodología, baselines o estilo de colaboración |

## 1. Instrucciones de uso

Al comenzar un chat nuevo, adjuntar:

```text
velocity_handoff.md

velocity_resume_prompt.md

velocity_collaboration_contract.md
```

También es recomendable adjuntar:

- ADR del milestone actual;
- diseño activo;
- `git status -sb`;
- URL del repositorio.

Después, copiar el prompt de la sección 2.

No permitir implementación antes de verificar el resumen inicial.

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

4. Respeta ADR aceptados, diseños activos y pruebas registradas.

5. Considera las pruebas aceptadas como baselines inmutables.

6. Una arquitectura nueva requiere pruebas sucesoras.

7. Toda modificación debe entregarse como archivo completo consolidado.

8. No utilices parches, diffs, inserciones parciales, eliminaciones parciales ni instrucciones quirúrgicas.

9. Si una prueba falla, solicita el primer error completo antes de modificar código.

10. La ejecución autoritativa utiliza Godot Console, headless y Velocity Test Runner.

11. No utilices Run Current Scene como evidencia autoritativa.

12. No modifiques código durante problema, análisis, ADR o diseño abierto.

13. Propón alternativas y tradeoffs.

14. No aceptes automáticamente mis ideas ni las tuyas.

15. Mantén una responsabilidad principal por componente.

16. Prefiere composición sobre herencia.

17. No añadas singleton o autoload por comodidad.

18. Aplica siempre:

	La simulación puede fallar.
	El simulador no.

19. El usuario lee y reescribe manualmente cada archivo.

20. Indica siempre la ruta exacta.

21. Trabaja en español.

22. Mantén un tono claro, didáctico, directo, cercano y honesto.

En tu primera respuesta debes entregar únicamente:

A. confirmación de lectura;

B. visión del proyecto;

C. último milestone implementado;

D. baseline global;

E. último commit y estado Git conocido;

F. milestone arquitectónico actual;

G. siguiente componente autorizado;

H. decisiones aceptadas;

I. riesgos o contradicciones;

J. archivos adicionales requeridos;

K. pregunta de confirmación.

No escribas implementación en la primera respuesta.

Si no puedes acceder al repositorio o a un archivo:

- indícalo;
- solicita la ruta exacta;
- no reconstruyas contenido por intuición.

Jerarquía de autoridad:

1. código versionado;

2. pruebas aceptadas;

3. ADR aceptados;

4. diseños activos;

5. Core Architecture;

6. Engineering Standards;

7. velocity_handoff.md;

8. velocity_collaboration_contract.md;

9. journals históricos;

10. conversación previa.

Espera confirmación antes de avanzar.
```

## 3. Estado técnico que debe reconocer

Último milestone implementado:

```text
DeviceGraphAssembler 1.0
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

Baseline global:

```text
48 tests

1396 checks

0 failures

0 timeout

0 engine errors

Plan ExitCode 0

RESULT PASS
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

## 4. Milestone arquitectónico actual

```text
Runtime Construction Contract 1.0
```

Documentos:

```text
ADR-010 — Runtime Construction and Factory Binding

Runtime Construction Contract Design 1.0
```

Estado:

```text
ADR ACEPTADO

DISEÑO ACTIVO

IMPLEMENTACIÓN PENDIENTE
```

## 5. Siguiente componente autorizado

```text
RuntimeFactoryKey
```

Después:

```text
RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult

Runtime Construction Contract Integration
```

No implementar todavía:

```text
RuntimeFactoryRegistry

CompositionPlan

CompositionCompiler

CompositionRuntime
```

## 6. Decisiones aceptadas de Runtime Construction

### Factory

```text
construct-only
```

Factory no:

- inicializa;
- ejecuta set_ready;
- ejecuta start;
- coordina shutdown global;
- adjunta host objects;
- crea DeviceBus global;
- descubre dependencias;
- consulta service locator.

### Factory behavior

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

### Producto

```text
RuntimeDeviceHandle
```

No:

- Object genérico;
- Device aislado;
- Callable.

### Factory Key

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

No existe fallback.

### Dependencies

```text
RuntimeDependencyBinding
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

### BORROWED

- owner original permanece;
- Handle no libera;
- factory release no libera.

### TRANSFERRED

- transferencia comienza al invocar build;
- factory es custodio durante construcción;
- Handle asume ownership en éxito;
- factory limpia en fallo;
- caller no realiza segundo cleanup.

### Request

```text
RuntimeConstructionRequest
```

Contiene:

- Device ID;
- DeviceConfiguration;
- RuntimeFactoryKey;
- bindings pre-resueltos.

No es service locator.

### Handle

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

### RuntimeHost

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

Factory no adjunta Nodes.

RuntimeHost recibe Handle completo.

### DeviceBus

DeviceBus pertenece a CompositionRuntime.

Factory no crea Bus global.

Factory produce estado equivalente a CREATED.

### Rollback

Factory failure:

```text
cleanup local
Handle null
Report
```

Global failure:

```text
rollback en orden inverso
```

Last Known Good cambia únicamente después de commit completo.

### CompositionPlan

CompositionPlan guarda:

```text
RuntimeFactoryKey
```

No guarda:

- RuntimeFactory;
- Callable;
- RuntimeDeviceHandle;
- Device activo;
- Node activo;
- DeviceBus activo.

## 7. Respuesta inicial esperada

Una respuesta correcta debe indicar:

```text
He leído los documentos.

Último milestone implementado:
DeviceGraphAssembler 1.0.

Baseline:
48 tests.
1396 checks.
0 failures.

Milestone actual:
Runtime Construction Contract 1.0.

ADR-010:
aceptado.

Diseño:
activo.

Siguiente componente:
RuntimeFactoryKey.

No implementaré Registry,
CompositionPlan, Compiler o Runtime
antes de completar los contratos previos.
```

Después debe esperar confirmación.

## 8. Señales de pérdida de contexto

Detener si el asistente propone:

- DeviceBus como autoload;
- singleton global;
- DeviceCatalog con factories;
- DeviceGraph transportando mensajes;
- SystemProfile como Resource mutable directo;
- resolución latest;
- Callable genérico como factory;
- factory dentro de CompositionPlan;
- factory devuelve Device directamente;
- factory inicia lifecycle;
- factory adjunta Nodes;
- service locator;
- host_target como Factory Key inicial;
- Object genérico como resultado;
- CompositionCompiler ejecutando runtime;
- topological sort obligatorio ignorando ciclos;
- pruebas aceptadas modificadas;
- archivos por fragmentos;
- código antes de diseño.

## 9. Borrador alternativo recuperado

Existe fuera del repositorio:

```text
recovered_runtime_factory_and_composition_plan_design_250826.md
```

No es arquitectura canónica.

Ideas candidatas:

- lifecycle ordering;
- DispatchPolicy;
- subscription directives;
- host abstractions;
- Last Known Good.

Alternativas rechazadas:

- Callable;
- factory en Plan;
- factory devuelve Device;
- host_target como identidad;
- Registry mutable sin diseño;
- Array[Dictionary];
- topological order obligatorio.

No implementar el borrador directamente.

## 10. Protocolo de fallo

Si una prueba falla:

1. detener cambios;

2. copiar primer error completo;

3. incluir archivo y línea;

4. clasificar parser, contrato o comportamiento;

5. revisar responsabilidad;

6. entregar archivo completo corregido;

7. ejecutar prueba nuevamente;

8. no aceptar baseline hasta PASS.

## 11. Protocolo Git

Antes de commit:

```powershell
git status --short

git diff --check

git diff --cached --name-status

git diff --cached --check
```

Después de commit:

```powershell
git log -1 --oneline

git status --short
```

Después de milestone:

```powershell
git push origin main

git status -sb
```

Resultado esperado:

```text
## main...origin/main
```

## 12. Protocolo de recuperación

Si el chat original desaparece:

1. abrir Agent Mode;

2. adjuntar los tres documentos;

3. adjuntar ADR-010;

4. adjuntar Runtime Construction Contract Design;

5. pegar este prompt;

6. exigir resumen;

7. comparar baseline;

8. comparar siguiente componente;

9. verificar Git;

10. continuar solo si coincide.

## 13. Regla final

Un chat nuevo no necesita imitar una voz exacta.

Debe conservar:

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
