# CompositionRuntime — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 02/10/2026 |
| ADR relacionado | ADR-011 — Composition Runtime Activation, Ownership and Rollback |
| Alcance | Activación Simulation, ownership, DeviceBus, phase barriers, rollback y shutdown |
| Estado de implementación | NO IMPLEMENTADO |

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

## 5. Tests previstos

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

Test doubles:

```text
test/core/composition/
├── runtime_test_dependency_value_resolver.gd
├── runtime_test_lifecycle_adapter.gd
└── runtime_test_communication_binder.gd
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
- initialized Handles;
- ready Handles;
- started Handles.

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

Invoca:

```gdscript
lifecycle_adapter.initialize(
	handle,
	candidate_bus
)
```

Handle se registra initialized solo después de Report válido.

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

## 60. Error codes — collaborators

```text
composition_runtime_report_missing

composition_runtime_host_attach_failed

composition_runtime_communication_bind_failed

composition_runtime_initialize_failed

composition_runtime_ready_failed

composition_runtime_start_failed
```

## 61. Error codes — cleanup

```text
composition_runtime_shutdown_failed

composition_runtime_communication_unbind_failed

composition_runtime_host_detach_failed

composition_runtime_factory_release_failed
```

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

Verifica:

- operation canónica;
- success true/false;
- Report null;
- Report bloqueante;
- getters;
- no setters;
- no execution.

## 70. Runtime input tests

Verifica:

- collaborators null;
- collaborator contract incompleto;
- Plan null;
- Plan inválida;
- Hardware Plan;
- Registry inválida;
- state inválido;
- preflight sin adquisición.

## 71. Dependency tests

Verifica:

- zero Specs;
- BORROWED;
- TRANSFERRED;
- missing Value;
- invalid availability type;
- null Value;
- disposed Value;
- exact Binding ownership;
- no extra lookup.

## 72. Activation success tests

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

## 73. Failure tests

Verifica fallo controlado en:

- build;
- attach;
- bind;
- initialize;
- ready;
- start.

Cada caso verifica orden de rollback y cero double cleanup.

## 74. Shutdown tests

Verifica:

- reverse lifecycle;
- reverse unbind;
- reverse detach;
- reverse release;
- Bus clear;
- SHUTDOWN;
- repeated shutdown rejected;
- cleanup Issues aggregated.

## 75. Integration tests

CompositionRuntimeIntegrationTest:

- Plan + Registry + test collaborators;
- success activation;
- failure activation;
- shutdown.

FullCompositionRuntimePipelineIntegrationTest:

```text
DeviceCatalog
→ SystemProfile
→ DeviceGraphAssembler
→ CompositionCompiler
→ CompositionPlan
→ CompositionRuntime
→ ACTIVE
→ SHUTDOWN
```

## 76. Baselines preservadas

No se modifican:

- Runtime Construction tests;
- Registry tests;
- CompositionPlan tests;
- CompositionCompiler tests;
- full logical pipeline integration.

Runtime utiliza pruebas sucesoras.

## 77. Orden de implementación futuro

```text
1. CompositionRuntimeOperationResult.

2. Operation Result Test.

3. Test Dependency Resolver.

4. Test Lifecycle Adapter.

5. Test Communication Binder.

6. CompositionRuntime skeleton y preflight.

7. Runtime input tests.

8. Build stage.

9. Attach stage.

10. Communication stage.

11. Lifecycle stages.

12. Rollback.

13. Shutdown.

14. Runtime integration.

15. Full pipeline integration.

16. Composition Suite.

17. Run All.

18. Registrar baseline.
```

No iniciar antes de aceptar ADR-011 y cerrar commit documental.

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
COMPOSITIONRUNTIME DESIGN 1.0
ACTIVO
```

ADR:

```text
ADR-011 ACEPTADO
```

Implementación:

```text
AUTORIZADA DESPUÉS DEL COMMIT DOCUMENTAL
```

Primer componente futuro:

```text
res://core/composition/composition_runtime_operation_result.gd
```
