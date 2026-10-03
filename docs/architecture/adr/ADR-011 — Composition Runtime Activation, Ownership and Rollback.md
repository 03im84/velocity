# ADR-011 — Composition Runtime Activation, Ownership and Rollback

| Campo | Valor |
|---|---|
| Estado | ACEPTADO — IMPLEMENTADO — VERIFICADO |
| Versión | 1.1 |
| Fecha | 03/10/2026 |
| Componentes | CompositionRuntime, CompositionRuntimeOperationResult, DeviceBus, RuntimeFactoryRegistry, RuntimeHost, lifecycle adapter, communication binder, dependency value resolver |
| Alcance | Activación Simulation, ownership activo, phase barriers, rollback y shutdown |

## 1. Contexto

Velocity ya puede compilar:

```text
DeviceGraphSnapshot

+

RuntimeFactoryRegistry

↓

CompositionPlan
```

CompositionPlan es inmutable y no ejecutable.

Falta coordinar recursos activos.

## 2. Problema

Runtime debe:

- crear DeviceBus;
- resolver Dependency Values;
- construir Requests;
- invocar factories;
- conservar Handles;
- adjuntar Host Objects;
- enlazar comunicación;
- ejecutar lifecycle;
- hacer rollback;
- ejecutar shutdown.

Los contratos actuales no definen quién coordina esas responsabilidades globales.

## 3. Decisión

Velocity introducirá `CompositionRuntime` como owner stateful de una activación Simulation.

CompositionRuntime 1.0 será:

- Simulation-only;
- one-shot;
- transaccional;
- sin hot swap;
- sin service locator;
- sin singleton;
- sin threads;
- sin IO.

## 4. One-shot Runtime

Una instancia procesa como máximo una activación.

Estados:

```text
CREATED

ACTIVATING

ACTIVE

SHUTTING_DOWN

SHUTDOWN

FAILED
```

`SHUTDOWN` y `FAILED` son terminales en 1.0.

No se reutiliza una instancia para otro Plan.

## 5. Last Known Good

Last Known Good no pertenece a una instancia one-shot.

Un Supervisor futuro será owner de la referencia activa.

Flujo futuro:

```text
Runtime A activo

Runtime B candidato

B activa completamente

Supervisor commit B

A shutdown
```

Si B falla, A permanece activo.

Supervisor y hot swap están fuera de alcance de 1.0.

## 6. Colaboradores explícitos

CompositionRuntime recibe por constructor:

```text
RuntimeFactoryRegistry

RuntimeDependencyValueResolver behavior

RuntimeHost behavior

RuntimeLifecycleAdapter behavior

RuntimeCommunicationBinder behavior
```

Ninguno se descubre globalmente.

## 7. RuntimeDependencyValueResolver

Behavior:

```gdscript
has_value(
	device_id: String,
	dependency_id: StringName
) -> bool
```

```gdscript
get_value(
	device_id: String,
	dependency_id: StringName
) -> Object
```

Runtime consulta únicamente Dependencies declaradas por Entry.

No es un service locator de acceso libre.

Runtime crea Binding utilizando Ownership declarado por Spec.

## 8. RuntimeLifecycleAdapter

Behavior:

```gdscript
initialize(
	handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
) -> ValidationReport
```

```gdscript
set_ready(
	handle: RuntimeDeviceHandle
) -> ValidationReport
```

```gdscript
start(
	handle: RuntimeDeviceHandle
) -> ValidationReport
```

```gdscript
shutdown(
	handle: RuntimeDeviceHandle
) -> ValidationReport
```

Adapter permite que Primary Runtime Object permanezca `Object`.

No se fuerza herencia de Device.

## 9. RuntimeCommunicationBinder

Behavior:

```gdscript
bind(
	directive: CompositionConnectionDirective,
	source_handle: RuntimeDeviceHandle,
	target_handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
) -> ValidationReport
```

```gdscript
unbind(
	directive: CompositionConnectionDirective,
	source_handle: RuntimeDeviceHandle,
	target_handle: RuntimeDeviceHandle,
	device_bus: DeviceBus
) -> ValidationReport
```

Binder resuelve callbacks y source filtering.

Plan no contiene Callable.

## 10. RuntimeHost

Se conserva ADR-010:

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

## 11. DeviceBus ownership

Cada CompositionRuntime crea un DeviceBus.

Aplica `DeviceBusDispatchPolicy` antes de cualquier dispatch.

Bus no es autoload o singleton.

Bus no se comparte entre candidato y runtime activo.

## 12. Activation pipeline

```text
Preflight
↓
Create Bus
↓
Configure Policy
↓
Resolve Bindings
↓
Build All
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

## 13. Phase barriers

Cada fase termina para todos antes de la siguiente.

Runtime usa los órdenes derivados por CompositionPlan.

No calcula topological sort.

## 14. Preflight

Antes de adquirir recursos valida:

- State CREATED;
- Plan no null y válida;
- Simulation Context;
- Registry válida;
- collaborator behaviors completos;
- cada Entry Key disponible;
- cada Descriptor válido;
- Specs de Entry coinciden con Descriptor;
- todas las dependency values declaradas están disponibles;
- todos los Values son Objects vivos.

Preflight fallido no crea Bus ni ejecuta factory.

## 15. Dependency bindings

Runtime itera Specs de Entry.

Por Spec:

```text
Dependency ID

+

Resolver Value

+

Spec Ownership

↓

RuntimeDependencyBinding
```

No acepta dependencies extra.

## 16. TRANSFERRED boundary

TRANSFERRED comienza en:

```gdscript
factory.build(
	request
)
```

Si build actual falla, factory limpia TRANSFERRED de ese Request.

Runtime no repite ese cleanup.

Handles construidos anteriormente se liberan en orden inverso.

## 17. RuntimeConstructionRequest

Runtime crea Request desde:

- CompositionDeviceEntry Device ID;
- Configuration;
- Factory Key;
- Bindings resueltos.

Request debe ser válido antes de build.

## 18. Build phase

Para cada Entry en construction order:

- resolver Descriptor exacto;
- obtener factory Object;
- crear Request;
- invocar build;
- validar Build Result;
- conservar Handle.

Un fallo bloquea fases posteriores.

## 19. Attach phase

RuntimeHost recibe cada Handle en attach order.

Fallo actual debe revertir attach parcial dentro de Host behavior.

Runtime revierte Handles attached previamente.

## 20. Communication phase

Después de attach, Binder procesa Directives en orden.

Recibe source y target Handle exactos.

Toda comunicación queda enlazada antes de initialize y start.

## 21. Lifecycle phases

Orden:

```text
initialize all

set_ready all

start all
```

Cada operación devuelve ValidationReport.

Report bloqueante activa rollback.

Lifecycle Adapter debe tolerar `shutdown()` después de initialize parcial y debe ser idempotente para cleanup best effort.

## 22. Commit

Runtime cambia a ACTIVE únicamente cuando:

- todos los Handles existen;
- todos están attached;
- todas las Directives están bound;
- todos initialized;
- todos ready;
- todos started.

No existe ACTIVE parcial.

## 23. Rollback

Orden general:

```text
shutdown current partially initialized Handle when applicable

shutdown confirmed initialized Handles reverse

unbind Directives reverse

detach Handles reverse

release Handles reverse

DeviceBus.clear
```

Rollback continúa aunque una operación falle.

Issues se agregan.

State final:

```text
FAILED
```

## 24. Build failure actual

Factory del build fallido limpia sus parciales.

Runtime libera únicamente Handles exitosos anteriores.

Esto evita double cleanup de TRANSFERRED.

## 25. Shutdown activo

Orden:

```text
shutdown reverse

unbind reverse

detach reverse

release reverse

clear Bus
```

Si cleanup completo:

```text
SHUTDOWN
```

Si cleanup reporta errores:

```text
FAILED
```

## 26. Cleanup best effort

Un error de cleanup no detiene el resto del cleanup.

La plataforma debe conservar máxima capacidad de recuperación y reportar recursos no confirmados.

## 27. Operation Result

CompositionRuntimeOperationResult contiene:

```text
success

operation

ValidationReport
```

Operaciones canónicas:

```text
activate

shutdown
```

No ejecuta acciones.

## 28. Runtime API

Conceptual:

```gdscript
activate(
	plan: CompositionPlan
) -> CompositionRuntimeOperationResult
```

```gdscript
shutdown(
) -> CompositionRuntimeOperationResult
```

Queries:

```gdscript
get_state()

is_active()

get_active_plan()

get_device_bus()

get_handles()

get_handle(
	device_id: String
)
```

## 29. Empty Plan

Empty Plan Simulation es activable.

Runtime crea Bus configurado y queda ACTIVE sin Handles.

Shutdown limpia Bus y termina SHUTDOWN.

## 30. Hardware

Plan Hardware produce:

```text
HARDWARE_SAFETY_ERROR
```

No se adquieren recursos.

Hardware Runtime requiere diseño sucesor.

## 31. Registry consistency

Composition Root debe entregar el mismo Registry utilizado por Compiler.

Runtime revalida equivalencia observable:

- Key existe;
- Descriptor válido;
- Specs coinciden.

No existe Registry ID o hash en 1.0.

## 32. Cycles

Runtime no rechaza ciclos estructurales permitidos por Plan.

Phase barriers garantizan existencia de todos antes de start.

Binder determina comunicación concreta.

## 33. Runtime Safety observation

CompositionRuntime expone DeviceBus.

No crea thread supervisor.

Supervisor futuro podrá observar:

- DeviceBusDispatchReport;
- Health;
- lifecycle;
- runtime failures.

## 34. Bounded execution

Runtime recorre colecciones acotadas.

No usa recursión.

No crea queues propias.

No crea threads.

No realiza IO.

## 35. Seguridad

Aplica VP-002 2.0:

> El usuario o el entorno pueden equivocarse. Una operación puede ser rechazada o abortada. El simulador debe permanecer seguro, consistente y recuperable.

Errores de Plan, dependencies, factory, host, communication o lifecycle se contienen mediante transacción y rollback.

## 36. Alternativas rechazadas

### CompositionRuntime como autoload

Rechazada por ownership global implícito.

### Factory controla lifecycle

Rechazada por ADR-010.

### Runtime descubre dependencies

Rechazada por service locator implícito.

### Plan contiene callbacks

Rechazada porque Plan debe ser declarativo.

### Hot swap dentro de Runtime 1.0

Rechazada por conflictos de recursos y falta de Supervisor.

### Primary Object debe heredar Device

Rechazada porque Runtime Construction usa Object y composition sobre herencia.

### Cleanup se detiene en primer error

Rechazada porque puede dejar más recursos activos.

## 37. Consecuencias positivas

- ownership explícito;
- activación transaccional;
- phase barriers;
- rollback verificable;
- dependencies explícitas;
- communication desacoplada;
- factories construct-only;
- empty runtime válido;
- test doubles simples;
- Last Known Good futuro posible.

## 38. Consecuencias negativas

- tres collaborator behaviors nuevos;
- adapters de producción pendientes;
- hot swap no disponible;
- Supervisor pendiente;
- Hardware bloqueado;
- FAILED terminal;
- cleanup externo puede no confirmarse;
- Runtime requiere pruebas extensas.

Estas consecuencias son aceptadas.

## 39. Criterios de aceptación

1. Simulation-only.

2. State machine explícita.

3. One-shot.

4. Registry explícito.

5. Dependency Resolver explícito.

6. RuntimeHost explícito.

7. Lifecycle Adapter explícito.

8. Communication Binder explícito.

9. DeviceBus owned.

10. Policy aplicada antes de dispatch.

11. Preflight sin adquisición.

12. Key exacta.

13. Specs coinciden.

14. Values declarados solamente.

15. Ownership desde Spec.

16. Requests válidos.

17. Build all barrier.

18. Attach all barrier.

19. Bind all barrier.

20. Initialize all barrier.

21. Ready all barrier.

22. Start all barrier.

23. ACTIVE solo después de commit.

24. Rollback inverso.

25. Cleanup best effort.

26. No double cleanup.

27. Shutdown inverso.

28. Empty Plan válido.

29. Hardware bloqueado.

30. No service locator.

31. No singleton.

32. No filesystem.

33. No threads.

34. No hot swap.

35. Last Known Good externo.

36. Pruebas unitarias PASS.

37. Pruebas de integración PASS.

38. Run All PASS.

## 40. Estado

```text
ADR-011 1.1
ACEPTADO
IMPLEMENTADO
VERIFICADO
```

La implementación mantiene la decisión original:

- Simulation-only;
- stateful y one-shot;
- collaborators explícitos;
- DeviceBus owned;
- phase barriers;
- commit ACTIVE completo;
- rollback inverso;
- cleanup best effort;
- SHUTDOWN y FAILED terminales;
- Hardware bloqueado;
- sin hot swap, singleton, service locator, IO o threads.

CompositionRuntime Design 1.1 desarrolla y registra esta decisión.

## 41. Evidencia de implementación

Componentes:

```text
res://core/composition/composition_runtime_operation_result.gd
res://core/composition/composition_runtime.gd
```

Pruebas sucesoras:

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

Las pruebas de integración demostraron fallo controlado y rollback en:

```text
build
attach
bind
initialize
ready
start
```

También demostraron agregación de errores de cleanup y ausencia de double cleanup.

## 42. Baseline aceptada

```text
CompositionRuntime:
4 tests
186 checks
0 failures

Composition Suite:
16 tests
702 checks
0 failures
0 missing metrics

Run All:
69 tests
2156 checks
0 failures
0 missing metrics
Plan ExitCode: 0
RESULT: PASS
```

Commit:

```text
cc9a7ae
feat(runtime): add transactional composition runtime
```

El milestone `CompositionRuntime 1.0` queda cerrado.

Production Runtime Adapters, Supervisor, Last Known Good manager, hot swap y Hardware Runtime requieren decisiones sucesoras.
