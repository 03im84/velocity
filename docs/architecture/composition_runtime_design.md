# CompositionRuntime — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Fecha | 03/10/2026 |
| ADR relacionado | ADR-011 — Composition Runtime Activation, Ownership and Rollback |
| Alcance | Activación Simulation, ownership, DeviceBus, phase barriers, rollback y shutdown |
| Estado de implementación | COMPLETO Y VERIFICADO |

## 1. Propósito

CompositionRuntime ejecuta un CompositionPlan de forma transaccional.

Responsabilidad:

> Construir, enlazar, iniciar, poseer y cerrar una composición runtime sin perder control de la plataforma.

CompositionRuntime no compila Plan.

## 2. Entrada

Constructor recibe colaboradores estables:

```text
RuntimeFactoryRegistry

RuntimeDependencyValueResolver behavior

RuntimeHost behavior

RuntimeLifecycleAdapter behavior

RuntimeCommunicationBinder behavior
```

Activation recibe:

```text
CompositionPlan
```

## 3. Salida operacional

```text
CompositionRuntimeOperationResult
	├── success
	├── operation
	└── ValidationReport
```

Runtime conserva estado activo internamente.

## 4. Componentes

```text
core/composition/
├── composition_runtime_operation_result.gd
└── composition_runtime.gd
```

## 5. Tests implementados

```text
test/core/composition/
├── CompositionRuntimeOperationResultTest.tscn
├── composition_runtime_operation_result_test.gd
├── CompositionRuntimeTest.tscn
├── composition_runtime_test.gd
├── CompositionRuntimeIntegrationTest.tscn
├── composition_runtime_integration_test.gd
├── FullCompositionRuntimePipelineIntegrationTest.tscn
└── full_composition_runtime_pipeline_integration_test.gd
```

Test doubles unitarios:

```text
test/core/composition/
├── runtime_test_dependency_value_resolver.gd
├── runtime_test_lifecycle_adapter.gd
└── runtime_test_communication_binder.gd
```

Test doubles transaccionales compartidos:

```text
test/core/composition/
├── runtime_integration_test_trace.gd
├── runtime_integration_test_factory.gd
├── runtime_integration_test_host.gd
├── runtime_integration_test_lifecycle_adapter.gd
└── runtime_integration_test_communication_binder.gd
```

Reutiliza:

```text
test/core/runtime/runtime_test_factory.gd

test/core/runtime/runtime_test_host.gd

test/core/runtime/runtime_test_object.gd
```

## 6. Forma

```gdscript
extends RefCounted
class_name CompositionRuntime
```

## 7. Constructor

```gdscript
CompositionRuntime.new(
	factory_registry,
	dependency_value_resolver,
	runtime_host,
	lifecycle_adapter,
	communication_binder
)
```

Todos los colaboradores se conservan por referencia.

No se descubren globalmente.

## 8. State

```gdscript
enum State {
	CREATED,
	ACTIVATING,
	ACTIVE,
	SHUTTING_DOWN,
	SHUTDOWN,
	FAILED,
}
```

Estado inicial:

```text
CREATED
```

## 9. One-shot

Transiciones permitidas:

```text
CREATED
→ ACTIVATING
→ ACTIVE
→ SHUTTING_DOWN
→ SHUTDOWN
```

Fallo durante activation:

```text
ACTIVATING
→ FAILED
```

Fallo durante shutdown:

```text
SHUTTING_DOWN
→ FAILED
```

No se permite:

- segunda activation;
- activation después de shutdown;
- retry desde FAILED;
- reemplazo de Plan activo;
- hot swap interno.

## 10. Public API

```gdscript
activate(
	plan: CompositionPlan
) -> CompositionRuntimeOperationResult
```

```gdscript
shutdown(
) -> CompositionRuntimeOperationResult
```

```gdscript
get_state() -> int

is_active() -> bool

get_active_plan() -> CompositionPlan

get_device_bus() -> DeviceBus

get_handles() -> Array[RuntimeDeviceHandle]

get_handle(
	device_id: String
) -> RuntimeDeviceHandle
```

## 11. Operation Result

### Forma

```gdscript
extends RefCounted
class_name CompositionRuntimeOperationResult
```

### Operations

```gdscript
const OPERATION_ACTIVATE: StringName = &"activate"

const OPERATION_SHUTDOWN: StringName = &"shutdown"
```

### Estado

```gdscript
var _success: bool

var _operation: StringName

var _report: ValidationReport
```

### API

```gdscript
is_success() -> bool

get_operation() -> StringName

get_report() -> ValidationReport
```

Result no ejecuta acciones.

## 12. Result validation

Success verdadero requiere:

- operation canónica;
- Report no null;
- Report válido para Simulation.

Runtime crea success false cuando cleanup o activation falla.

## 13. RuntimeFactoryRegistry

Registry es obligatorio.

Debe ser válido.

Runtime resuelve por Key exacta.

No existe fallback.

No almacena factory en Plan.

## 14. Registry preflight

Por cada Entry:

- Key no null;
- Key válida;
- Key disponible;
- Descriptor no null;
- Descriptor válido;
- Specs de Entry coinciden con Descriptor.

Specs coinciden por:

- cantidad;
- orden;
- Dependency ID;
- Ownership.

## 15. Registry instance invariant

Composition Root debe entregar la misma Registry utilizada por CompositionCompiler.

Runtime 1.0 no puede verificar identidad histórica porque Registry no tiene ID.

Runtime verifica equivalencia observable de Keys y Specs.

## 16. Dependency resolver contract

Objeto debe exponer:

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

`has_value` debe devolver bool.

`get_value` debe devolver Object vivo.

## 17. Dependency preflight

Por cada Spec:

1. consultar has_value;
2. comprobar bool;
3. exigir true;
4. obtener Value;
5. comprobar Object no null;
6. comprobar instance válida.

Preflight no crea Binding y no transfiere ownership.

## 18. Binding creation

Durante Build stage:

```gdscript
RuntimeDependencyBinding.new(
	spec.get_dependency_id(),
	resolved_value,
	spec.get_ownership()
)
```

Binding debe ser válida.

Runtime itera Specs; no acepta extras.

## 19. RuntimeHost contract

Objeto debe exponer:

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

## 20. Lifecycle Adapter contract

Objeto debe exponer:

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

Adapter no es owner del Handle.

`shutdown()` debe tolerar:

- initialize parcial;
- llamada best effort;
- llamada repetida durante cleanup.

## 21. Communication Binder contract

Objeto debe exponer:

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

Binder resuelve callback, adapter y source filtering.

## 22. Collaborator validation

Constructor no ejecuta colaboradores.

Activation preflight verifica presencia de methods.

No intenta validar firmas mediante reflection compleja.

Integración prueba comportamiento real.

## 23. Activation initial validation

Debe comprobar:

- State CREATED;
- Plan no null;
- Plan válida;
- Plan Simulation;
- Registry no null y válida;
- Resolver behavior;
- Host behavior;
- Lifecycle behavior;
- Binder behavior.

Cualquier error bloquea adquisición.

## 24. Hardware gate

Plan Hardware produce:

```text
composition_runtime_hardware_not_supported
HARDWARE_SAFETY_ERROR
```

No se crea DeviceBus.

No se resuelven Values.

No se ejecutan factories.

## 25. Preflight no acquisition

Preflight puede consultar Resolver.

No puede:

- crear Binding;
- invocar build;
- adjuntar;
- bind communication;
- ejecutar lifecycle;
- transferir ownership.

## 26. DeviceBus creation

Después de preflight:

```gdscript
var candidate_bus := DeviceBus.new()
```

Después:

```gdscript
candidate_bus.configure_dispatch_policy(
	plan.get_dispatch_policy()
)
```

Policy failure bloquea Build.

## 27. Candidate state

Activation utiliza variables locales para:

- candidate Bus;
- built Handles;
- attached Handles;
- bound Directives;
- initialized Handles.

Ready y Start son phase barriers sobre el conjunto initialized.

No requieren colecciones de ownership adicionales porque rollback ejecuta `shutdown()` sobre todos los Handles que alcanzaron initialize, incluyendo el Handle cuyo initialize pudo fallar parcialmente.

Campos activos se asignan únicamente en commit.

## 28. Build stage

Orden:

```gdscript
plan.get_construction_order()
```

Por Device ID:

- obtener Entry;
- resolver Descriptor;
- obtener factory;
- crear Bindings;
- crear Request;
- validar Request;
- invocar build;
- validar Result;
- obtener Handle;
- comprobar Handle Device ID y Key;
- agregar Handle.

## 29. Factory behavior validation

Factory debe exponer:

```text
build

release
```

Registry Descriptor ya valida methods.

Runtime conserva validación defensiva.

## 30. Build Report

Runtime agrega Issues de RuntimeFactoryBuildResult Report.

Report null produce:

```text
PLATFORM_SAFETY_ERROR
```

Result fallido bloquea activation.

## 31. Build failure ownership

Factory fallida es responsable de:

- recursos locales;
- TRANSFERRED del request actual.

Runtime no vuelve a limpiar ese request.

Runtime libera Handles anteriores.

## 32. Handle validation

Handle exitoso debe:

- no ser null;
- ser válido;
- coincidir Device ID;
- coincidir Configuration;
- coincidir Factory Key.

Mismatch produce Structural Error y rollback.

## 33. Attach stage

Orden:

```gdscript
plan.get_attach_order()
```

Por Handle:

- invocar Host.attach;
- exigir Report no null;
- agregar Issues;
- exigir Report válido para Simulation;
- registrar Handle attached.

## 34. Attach failure

Host behavior revierte parcial actual.

Runtime ejecuta detach solo para Handles anteriores confirmados.

Después libera todos los Handles construidos en reverse.

## 35. Communication stage

Orden de Plan Directives.

Por Directive:

- obtener source Handle;
- obtener target Handle;
- invocar Binder.bind;
- exigir Report no null;
- agregar Issues;
- registrar Directive bound.

## 36. Communication failure

Binder behavior revierte parcial actual.

Runtime ejecuta unbind para Directives anteriores confirmadas en reverse.

Después detach y release reverse.

## 37. Initialize stage

Orden:

```gdscript
plan.get_initialization_order()
```

Antes de invocar initialize, Runtime registra el Handle en el conjunto sujeto a shutdown best effort.

Después invoca:

```gdscript
lifecycle_adapter.initialize(
	handle,
	candidate_bus
)
```

Esta secuencia es intencional: si initialize falla después de producir efectos parciales, rollback incluye primero al Handle actual y luego a los anteriores en orden inverso.

## 38. Ready stage

Orden:

```gdscript
plan.get_ready_order()
```

Invoca:

```gdscript
lifecycle_adapter.set_ready(
	handle
)
```

## 39. Start stage

Orden:

```gdscript
plan.get_start_order()
```

Invoca:

```gdscript
lifecycle_adapter.start(
	handle
)
```

## 40. Lifecycle failure

Si `initialize()` falla, Runtime ejecuta primero shutdown best effort sobre el Handle actual porque puede contener efectos parciales.

Después ejecuta shutdown para Handles initialized anteriores en reverse.

Si `set_ready()` o `start()` fallan, el Handle actual ya pertenece al conjunto initialized y se incluye en shutdown reverse.

Después:

- unbind reverse;
- detach reverse;
- release reverse;
- Bus clear.

## 41. Commit ACTIVE

Después de completar Start para todos:

Runtime asigna:

- active Plan;
- DeviceBus;
- Handles.

State:

```text
ACTIVE
```

Antes de ese punto, getters activos devuelven null o Arrays vacíos.

## 42. Activation success

Devuelve:

```text
success true
operation activate
Report válido
```

## 43. Activation failure

Devuelve:

```text
success false
operation activate
Report con Issues
```

State:

```text
FAILED
```

No existe active Plan.

No existe active Bus.

No se exponen Handles parciales.

## 44. Rollback order

```text
1. shutdown initialized Handles reverse.

2. unbind bound Directives reverse.

3. detach attached Handles reverse.

4. release built Handles reverse.

5. clear candidate Bus.
```

Cada subfase continúa ante error.

## 45. Report merge

Report null de collaborator produce:

```text
composition_runtime_report_missing
PLATFORM_SAFETY_ERROR
```

Issues no se duplican por referencia.

Cleanup Issues se agregan al Report original.

## 46. Release lookup

Para release:

- obtener Handle Key;
- resolver Descriptor en Registry;
- obtener factory;
- invocar release.

Registry exacta permanece disponible durante toda la vida Runtime.

## 47. Shutdown

Permitido únicamente desde ACTIVE.

State cambia:

```text
ACTIVE
→ SHUTTING_DOWN
```

Orden:

- lifecycle shutdown reverse;
- communication unbind reverse;
- host detach reverse;
- factory release reverse;
- DeviceBus.clear.

## 48. Shutdown success

Limpia referencias activas.

State:

```text
SHUTDOWN
```

Result:

```text
success true
operation shutdown
```

## 49. Shutdown failure

Runtime intenta todo cleanup.

Limpia referencias confirmadas cuando corresponde.

State:

```text
FAILED
```

Result success false.

Report conserva todos los Issues.

## 50. Query behavior por State

### CREATED

```text
active Plan: null
Bus: null
Handles: []
```

### ACTIVATING

No se exponen candidatos parciales.

### ACTIVE

Getters devuelven snapshots activos.

### SHUTTING_DOWN

Runtime no acepta otra operación.

### SHUTDOWN

Referencias activas limpias.

### FAILED

No permite retry.

Report de operación conserva causa.

## 51. Handle lookup

```gdscript
get_handle(
	device_id
)
```

Devuelve null para:

- ID vacío;
- ID desconocido;
- state no ACTIVE.

## 52. Array protection

`get_handles()` devuelve copia.

Runtime conserva orden de construction.

No expone mutación interna.

## 53. Empty Plan

Activation:

- preflight válido;
- Bus creado;
- Policy configurada;
- cero Builds;
- cero Attach;
- cero Bind;
- cero lifecycle;
- commit ACTIVE.

Shutdown:

- clear Bus;
- SHUTDOWN.

## 54. No hot swap

`activate()` desde ACTIVE se rechaza.

No construye candidato nuevo.

No modifica runtime activo.

Supervisor futuro coordinará replacement.

## 55. Last Known Good

CompositionRuntime 1.0 no almacena otro runtime.

Cada instancia representa candidato o runtime activo.

Supervisor futuro conserva Last Known Good.

Este límite evita hot swap inseguro.

## 56. Runtime Safety observation

API puede exponer:

```gdscript
get_last_dispatch_report() -> DeviceBusDispatchReport
```

Devuelve null si Bus no existe.

No crea polling o thread.

## 57. Error codes — state e inputs

```text
composition_runtime_state_invalid

composition_runtime_plan_missing

composition_runtime_plan_invalid

composition_runtime_hardware_not_supported

composition_runtime_registry_missing

composition_runtime_registry_invalid

composition_runtime_dependency_resolver_missing

composition_runtime_dependency_resolver_contract_invalid

composition_runtime_host_missing

composition_runtime_host_contract_invalid

composition_runtime_lifecycle_adapter_missing

composition_runtime_lifecycle_adapter_contract_invalid

composition_runtime_communication_binder_missing

composition_runtime_communication_binder_contract_invalid
```

## 58. Error codes — preflight

```text
composition_runtime_factory_missing

composition_runtime_descriptor_invalid

composition_runtime_dependency_specs_mismatch

composition_runtime_dependency_availability_invalid

composition_runtime_dependency_missing

composition_runtime_dependency_value_invalid
```

## 59. Error codes — Bus y build

```text
composition_runtime_bus_policy_rejected

composition_runtime_binding_invalid

composition_runtime_request_invalid

composition_runtime_factory_build_result_missing

composition_runtime_factory_build_failed

composition_runtime_handle_invalid

composition_runtime_handle_identity_mismatch
```

## 60. Error codes — collaborator invocation

CompositionRuntime conserva los Issues devueltos por factories y colaboradores.

No sustituye sus códigos por códigos genéricos de fase.

Si un collaborator devuelve un valor que no es `ValidationReport`, Runtime agrega:

```text
composition_runtime_report_missing
```

con severidad:

```text
PLATFORM_SAFETY_ERROR
```

Los tests de integración utilizan códigos controlados propios para demostrar preservación de causa en build, attach, bind, initialize, ready, start y cleanup.

## 61. Error codes — cleanup

Cleanup conserva y agrega los Issues producidos por:

- Lifecycle Adapter;
- Communication Binder;
- RuntimeHost;
- RuntimeFactory.

Si el Descriptor necesario para release deja de estar disponible, Runtime agrega:

```text
composition_runtime_factory_release_failed
```

Un Issue de cleanup no detiene las operaciones restantes.

## 62. Severities

Structure y contratos inválidos:

```text
STRUCTURAL_ERROR
```

Report null, state imposible o pérdida de control:

```text
PLATFORM_SAFETY_ERROR
```

Hardware no soportado:

```text
HARDWARE_SAFETY_ERROR
```

## 63. No mutation

Runtime no modifica:

- Plan;
- Registry;
- Entries;
- Directives;
- Specs;
- Configurations;
- Dispatch Policy.

## 64. No execution durante preflight

Preflight no invoca:

- factory.build;
- factory.release;
- host.attach;
- host.detach;
- binder.bind;
- binder.unbind;
- lifecycle methods.

## 65. No service locator

Resolver se consulta solo para Specs declaradas.

Runtime no busca:

- Nodes;
- autoloads;
- filesystem;
- global services;
- factories por path;
- hardware.

## 66. No IO

CompositionRuntime no abre:

- archivos;
- red;
- serial;
- GPIO;
- JSON;
- resources por path.

## 67. Threading

CompositionRuntime 1.0 es síncrono.

No crea threads.

No usa await.

No crea queues propias.

## 68. Complexity

Preflight:

```text
O(entries + specs)
```

Activation:

```text
O(entries + directives + cleanup)
```

Registry lookup promedio:

```text
O(1) por Key
```

## 69. Operation Result tests

`CompositionRuntimeOperationResultTest` verifica:

- operation canónica;
- success true/false;
- Report null;
- Report bloqueante;
- getters;
- no setters;
- no execution.

Baseline:

```text
1 test
17 checks
0 failures
RESULT: PASS
```

## 70. Runtime unit tests

`CompositionRuntimeTest` verifica:

- estado inicial;
- collaborators requeridos;
- contratos incompletos;
- Plan null e inválida;
- Hardware gate;
- empty activation y shutdown;
- dependency preflight;
- ownership;
- phase barriers;
- shutdown inverso;
- API y límites de contrato.

Baseline:

```text
1 test
62 checks
0 failures
RESULT: PASS
```

## 71. Dependency verification

La prueba unitaria y la integración full pipeline verifican:

- zero Specs;
- BORROWED;
- TRANSFERRED;
- missing Value;
- exact Binding ownership;
- orden de consulta;
- ausencia de lookup extra;
- preservación de BORROWED en shutdown;
- liberación de TRANSFERRED en shutdown.

## 72. Activation success verification

Verifica:

- empty Plan;
- multiple Entries;
- build order;
- attach order;
- bind order;
- initialize barrier;
- ready barrier;
- start barrier;
- ACTIVE commit;
- Handle lookup;
- Bus Policy;
- no duplicate activation.

## 73. Transaction failure integration

`CompositionRuntimeIntegrationTest` verifica fallo controlado en:

- build;
- attach;
- bind;
- initialize;
- ready;
- start.

Cada caso verifica:

- phase barrier;
- causa original;
- rollback inverso;
- current partially initialized Handle;
- cleanup best effort;
- agregación de errores;
- cero double cleanup;
- cero estado activo parcial.

Baseline:

```text
1 test
57 checks
0 failures
RESULT: PASS
```

## 74. Shutdown verification

Verifica:

- reverse lifecycle;
- reverse unbind;
- reverse detach;
- reverse release;
- Bus clear;
- SHUTDOWN limpio;
- FAILED cuando cleanup reporta error;
- cleanup Issues agregados;
- repeated shutdown rejected;
- ausencia de double cleanup.

## 75. Full pipeline integration

`FullCompositionRuntimePipelineIntegrationTest` verifica:

```text
DeviceProfiles
→ DeviceCatalog
→ SystemProfile
→ DeviceGraphAssembler
→ DeviceGraphSnapshot
→ RuntimeFactoryRegistry
→ CompositionCompiler
→ CompositionPlan
→ CompositionRuntime
→ ACTIVE
→ SHUTDOWN
```

Comprueba preservación de identidades, referencias de Configuration, Dependency Specs, Policy, Connection ID, ownership BORROWED/TRANSFERRED, phase barriers y cleanup inverso.

Baseline:

```text
1 test
50 checks
0 failures
RESULT: PASS
```

## 76. Baselines preservadas

No se modificaron pruebas aceptadas de:

- Runtime Construction;
- RuntimeFactoryRegistry;
- CompositionPlan;
- CompositionCompiler;
- pipeline lógico previo.

CompositionRuntime utiliza pruebas sucesoras.

Regresión final:

```text
Composition Suite
16 tests
702 checks
0 failures
0 missing metrics
RESULT: PASS
```

```text
Run All
69 tests
2156 checks
0 failures
0 missing metrics
Plan ExitCode: 0
RESULT: PASS
```

## 77. Orden de implementación ejecutado

```text
1. CompositionRuntimeOperationResult.
   COMPLETADO.

2. Operation Result Test.
   PASS — 17 checks.

3. Test Dependency Resolver.
   COMPLETADO.

4. Test Lifecycle Adapter.
   COMPLETADO.

5. Test Communication Binder.
   COMPLETADO.

6. CompositionRuntime preflight y state machine.
   COMPLETADO.

7. Build, attach y communication stages.
   COMPLETADO.

8. Lifecycle phase barriers.
   COMPLETADO.

9. Rollback y shutdown.
   COMPLETADO.

10. CompositionRuntimeTest.
    PASS — 62 checks.

11. Runtime integration.
    PASS — 57 checks.

12. Full pipeline integration.
    PASS — 50 checks.

13. Composition Suite.
    PASS — 16 tests, 702 checks.

14. Run All.
    PASS — 69 tests, 2156 checks.

15. Refactor audit.
    COMPLETADO — sin cambio obligatorio.

16. Baseline de implementación.
    REGISTRADA.
```

## 78. Criterios de aceptación

1. One-shot state machine.

2. Simulation-only.

3. Explicit Registry.

4. Explicit Resolver.

5. Explicit Host.

6. Explicit Lifecycle Adapter.

7. Explicit Communication Binder.

8. Owned DeviceBus.

9. Policy configured before dispatch.

10. Preflight no acquisition.

11. Exact Keys.

12. Matching Specs.

13. Declared Values only.

14. Ownership from Specs.

15. Valid Requests.

16. Atomic Builds.

17. Build phase barrier.

18. Attach phase barrier.

19. Communication phase barrier.

20. Initialize phase barrier.

21. Ready phase barrier.

22. Start phase barrier.

23. ACTIVE commit after all phases.

24. No partial active state.

25. Reverse rollback.

26. Best-effort cleanup.

27. No double cleanup.

28. Reverse shutdown.

29. Empty Plan activation.

30. Hardware blocked.

31. No hot swap.

32. Last Known Good external.

33. No service locator.

34. No singleton.

35. No IO.

36. No threads.

37. Bounded loops.

38. Operation Reports.

39. Tests PASS.

40. Integration PASS.

41. Run All PASS.

## 79. Fuera de alcance

- Supervisor;
- Last Known Good manager;
- hot swap;
- multi-runtime;
- Hardware Runtime;
- production factories;
- production host;
- production resolver;
- production lifecycle adapter;
- production binder;
- asynchronous activation;
- threads;
- scheduler SCC;
- temporal boundary runtime;
- persistence;
- telemetry;
- automatic recovery;
- restart policy.

## 80. Estado

```text
COMPOSITIONRUNTIME DESIGN 1.1
ACTIVO
```

ADR:

```text
ADR-011 1.1
ACEPTADO
IMPLEMENTADO
VERIFICADO
```

Implementación:

```text
CompositionRuntimeOperationResult 1.0
CompositionRuntime 1.0
COMPLETOS Y VERIFICADOS
```

Baseline propia:

```text
4 tests
186 checks
0 failures
0 missing metrics
RESULT: PASS
```

Composition Suite:

```text
16 tests
702 checks
0 failures
0 missing metrics
RESULT: PASS
```

Baseline global:

```text
69 tests
2156 checks
0 failures
0 missing metrics
Plan ExitCode: 0
RESULT: PASS
```

Commit de implementación:

```text
cc9a7ae
feat(runtime): add transactional composition runtime
```

Siguiente milestone recomendado:

```text
Production Runtime Adapters
Problema y análisis
```

No se implementarán adapters de producción antes de cerrar su problema, análisis y diseño.
