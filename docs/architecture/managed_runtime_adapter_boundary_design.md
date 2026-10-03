# Managed Runtime Adapter Boundary — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Fecha | 03/10/2026 |
| ADR relacionado | ADR-012 — Managed Runtime Object Behaviors and Production Adapter Boundaries |
| Alcance | Resolver scoped, lifecycle delegation, source-filtered communication y Godot Node host |
| Estado de implementación | COMPLETO Y VERIFICADO |

## 1. Propósito

Definir implementaciones reutilizables de los behaviors requeridos por CompositionRuntime sin acoplarlo a Devices concretos.

Responsabilidad del boundary:

> Adaptar runtime units explícitas a dependency resolution, lifecycle, communication y Godot hosting.

## 2. Componentes

```text
RuntimeDependencyValue
ScopedRuntimeDependencyResolver
ManagedRuntimeLifecycleAdapter
RuntimeSourceFilteredSubscription
ManagedRuntimeCommunicationBinder
GodotNodeRuntimeHost
```

## 3. Dependencias permitidas

Core adapters pueden depender de:

- Object;
- Callable;
- ValidationIssue;
- ValidationReport;
- DeviceBus;
- BusMessage;
- RuntimeDeviceHandle;
- CompositionConnectionDirective.

Godot host puede depender de:

- Node;
- RuntimeDeviceHandle;
- ValidationIssue;
- ValidationReport.

## 4. Dependencias prohibidas

Adapters no dependen de:

- Device concreto;
- DistanceSensorDevice;
- DeviceProfile concreto;
- RuntimeFactory concreta;
- SceneTree discovery;
- autoload;
- filesystem;
- persistence;
- Hardware API;
- CompositionRuntime internals.

## 5. RuntimeDependencyValue

Ruta:

```text
res://core/runtime/runtime_dependency_value.gd
```

Forma:

```gdscript
extends RefCounted
class_name RuntimeDependencyValue
```

Estado:

```gdscript
var _device_id: String
var _dependency_id: StringName
var _value: Object
```

## 6. RuntimeDependencyValue API

```gdscript
get_device_id() -> String
get_dependency_id() -> StringName
get_value() -> Object
is_valid() -> bool
```

Validez requiere:

- Device ID no vacío;
- Dependency ID no vacío;
- Value no null;
- Value instance válida.

No contiene Ownership.

## 7. Resolver

Ruta:

```text
res://core/runtime/scoped_runtime_dependency_resolver.gd
```

Forma:

```gdscript
extends RefCounted
class_name ScopedRuntimeDependencyResolver
```

Constructor:

```gdscript
ScopedRuntimeDependencyResolver.new(
    values: Array[RuntimeDependencyValue]
)
```

## 8. Resolver state

Conserva copia del Array.

Construye índice interno exacto:

```text
Device ID
→ Dependency ID
→ RuntimeDependencyValue
```

Duplicado exacto marca resolver inválido.

No existe overwrite.

## 9. Resolver API

Behavior requerido:

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

Queries adicionales:

```gdscript
is_valid() -> bool
get_value_count() -> int
```

No expone values Array.

No expone register/unregister/clear.

## 10. Resolver invalid state

Si constructor recibe:

- null Entry;
- Entry inválida;
- duplicate exact key;

`is_valid()` devuelve false.

En resolver inválido:

```text
has_value → false
get_value → null
```

Esto falla cerrado durante CompositionRuntime preflight.

## 11. Resolver liveness

Un Value puede dejar de ser instance válida después de construir snapshot.

`has_value()` vuelve a verificar liveness.

`get_value()` devuelve null si Object ya no es válido.

Resolver no libera values.

## 12. Managed lifecycle adapter

Ruta:

```text
res://core/runtime/managed_runtime_lifecycle_adapter.gd
```

Forma:

```gdscript
extends RefCounted
class_name ManagedRuntimeLifecycleAdapter
```

No requiere constructor dependencies.

Es stateless.

## 13. Managed lifecycle behavior

Primary Runtime Object debe exponer:

```gdscript
runtime_initialize(
    device_bus: DeviceBus
) -> ValidationReport

runtime_set_ready() -> ValidationReport

runtime_start() -> ValidationReport

runtime_shutdown() -> ValidationReport
```

Methods permanecen en una línea física según Engineering Standards.

## 14. Lifecycle Adapter API

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

## 15. Lifecycle validation

Cada operación valida:

- Handle no null;
- Handle válido;
- Primary no null;
- Primary instance válida;
- behavior method presente;
- initialize recibe Bus no null;
- return value es ValidationReport.

## 16. Lifecycle report forwarding

Si managed method devuelve ValidationReport, Adapter devuelve la misma referencia.

No duplica Issues.

No convierte un Report bloqueante en éxito.

No agrega Issue genérico cuando Primary ya reportó causa.

## 17. Invalid return

Return distinto de ValidationReport produce nuevo Report con:

```text
managed_runtime_lifecycle_report_missing
PLATFORM_SAFETY_ERROR
```

## 18. Lifecycle structural codes

```text
managed_runtime_lifecycle_handle_missing
managed_runtime_lifecycle_handle_invalid
managed_runtime_lifecycle_primary_missing
managed_runtime_lifecycle_primary_invalid
managed_runtime_lifecycle_behavior_missing
managed_runtime_lifecycle_bus_missing
```

Severidad:

```text
STRUCTURAL_ERROR
```

## 19. Source filtered subscription

Ruta:

```text
res://core/runtime/runtime_source_filtered_subscription.gd
```

Forma:

```gdscript
extends RefCounted
class_name RuntimeSourceFilteredSubscription
```

Constructor:

```gdscript
RuntimeSourceFilteredSubscription.new(
    source_device_id: String,
    topic: StringName,
    target_endpoint: Callable
)
```

## 20. Subscription API

```gdscript
receive(message: Variant) -> void
is_valid() -> bool
get_source_device_id() -> String
get_topic() -> StringName
get_target_endpoint() -> Callable
```

## 21. Filtering

`receive()` ignora:

- value que no sea BusMessage;
- BusMessage inválido;
- source ID distinto;
- topic distinto;
- endpoint inválido.

Cuando coincide:

```gdscript
target_endpoint.call(message)
```

No modifica envelope o payload.

## 22. Binder

Ruta:

```text
res://core/runtime/managed_runtime_communication_binder.gd
```

Forma:

```gdscript
extends RefCounted
class_name ManagedRuntimeCommunicationBinder
```

Es stateful.

Conserva wrappers por Connection ID.

## 23. Target endpoint behavior

Target Primary Runtime Object debe exponer:

```gdscript
get_runtime_input_endpoint(
    port_id: StringName
) -> Callable
```

Binder no deriva method names.

## 24. Bind validation

Valida:

- Directive no null;
- Directive identity válida;
- source Handle válido;
- target Handle válido;
- Bus no null;
- source Handle Device ID coincide;
- target Handle Device ID coincide;
- Connection ID no bound;
- target Primary válido;
- endpoint behavior presente;
- endpoint result Callable;
- Callable válida.

## 25. Bind operation

```text
Resolve endpoint
↓
Create RuntimeSourceFilteredSubscription
↓
DeviceBus.subscribe(topic, wrapper.receive)
↓
Store wrapper by Connection ID
```

Solo se almacena después de subscribe exitoso.

## 26. Bind failure

Si subscribe falla:

- wrapper no se almacena;
- no existe binding parcial confirmado;
- Report bloqueante.

Código:

```text
managed_runtime_communication_subscribe_failed
```

Severidad:

```text
PLATFORM_SAFETY_ERROR
```

## 27. Unbind

Valida inputs básicos.

Si Connection ID no existe:

```text
no-op válido
```

Si existe:

```text
DeviceBus.unsubscribe(topic, wrapper.receive)
↓
remove wrapper
```

Wrapper se elimina solo después de unsubscribe exitoso.

## 28. Unbind failure

Código:

```text
managed_runtime_communication_unsubscribe_failed
PLATFORM_SAFETY_ERROR
```

Binding permanece observable para retry externo.

CompositionRuntime 1.0 será terminal FAILED si cleanup reporta error.

## 29. Binder query API

```gdscript
has_binding(
    connection_id: StringName
) -> bool

get_binding_count() -> int
```

No expone wrapper mutable.

## 30. Binder structural codes

```text
managed_runtime_communication_directive_missing
managed_runtime_communication_directive_invalid
managed_runtime_communication_source_handle_missing
managed_runtime_communication_source_handle_invalid
managed_runtime_communication_target_handle_missing
managed_runtime_communication_target_handle_invalid
managed_runtime_communication_bus_missing
managed_runtime_communication_source_mismatch
managed_runtime_communication_target_mismatch
managed_runtime_communication_duplicate_binding
managed_runtime_communication_primary_missing
managed_runtime_communication_primary_invalid
managed_runtime_communication_endpoint_behavior_missing
managed_runtime_communication_endpoint_invalid
```

Severidad:

```text
STRUCTURAL_ERROR
```

## 31. Godot host

Ruta:

```text
res://integration/godot/runtime/godot_node_runtime_host.gd
```

Forma:

```gdscript
extends RefCounted
class_name GodotNodeRuntimeHost
```

Constructor:

```gdscript
GodotNodeRuntimeHost.new(
    parent: Node
)
```

## 32. Host state

Conserva:

```text
Handle instance ID
→ attached Nodes
```

Parent se conserva por referencia.

No se descubre globalmente.

## 33. Host attach validation

Valida:

- parent no null;
- parent instance válida;
- Handle no null y válido;
- Handle no attached previamente;
- cada Host Object es Node;
- cada Node instance válida;
- Node no es parent;
- Node no tiene parent;
- Node no es ancestro del parent.

Toda validación ocurre antes del primer add_child.

## 34. Host attach

Procesa Host Objects en orden.

Por Node:

```gdscript
parent.add_child(node)
```

Después confirma:

```gdscript
node.get_parent() == parent
```

Si una confirmación falla:

- remove Nodes actuales en reverse;
- no registra Handle attached;
- agrega Issue.

## 35. Empty Host Objects

Handle con zero Host Objects es attach válido.

Se registra como attached para impedir duplicate attach.

Detach posterior es válido.

## 36. Host detach

Si Handle no está registrado:

```text
no-op válido
```

Si está registrado:

- itera Nodes reverse;
- si Node invalid, se considera no attached;
- si parent coincide, ejecuta remove_child;
- si parent null, se considera detached;
- si parent es otro Node, reporta pérdida de control.

## 37. Host unresolved detach

Nodes que continúan bajo parent inesperado permanecen en estado interno observable.

Código:

```text
godot_runtime_host_detach_parent_mismatch
PLATFORM_SAFETY_ERROR
```

No se fuerza detach desde parent ajeno.

## 38. Host query API

```gdscript
is_handle_attached(
    handle: RuntimeDeviceHandle
) -> bool

get_attached_handle_count() -> int
```

## 39. Host structural codes

```text
godot_runtime_host_parent_missing
godot_runtime_host_parent_invalid
godot_runtime_host_handle_missing
godot_runtime_host_handle_invalid
godot_runtime_host_duplicate_attach
godot_runtime_host_object_not_node
godot_runtime_host_object_invalid
godot_runtime_host_object_is_parent
godot_runtime_host_object_already_parented
godot_runtime_host_cycle_detected
```

## 40. Host platform codes

```text
godot_runtime_host_attach_failed
godot_runtime_host_detach_parent_mismatch
```

Severidad:

```text
PLATFORM_SAFETY_ERROR
```

## 41. Ownership matrix

| Recurso | Owner |
|---|---|
| Dependency Value original | Composition Root o owner externo hasta build |
| RuntimeDependencyBinding | Handle |
| Primary Runtime Object | Factory product / Handle |
| Host Objects | Factory product / Handle |
| Attachment state | GodotNodeRuntimeHost |
| Subscription wrapper | ManagedRuntimeCommunicationBinder |
| DeviceBus | CompositionRuntime |
| Active Plan | CompositionRuntime |

## 42. Threading

Todos los adapters son síncronos.

GodotNodeRuntimeHost opera en main thread por contrato de caller.

No crean threads.

No usan await.

## 43. Mutation

Adapters no modifican:

- CompositionPlan;
- Directive;
- RuntimeFactoryRegistry;
- RuntimeDeviceHandle identity;
- DeviceConfiguration;
- Dependency Specs;
- BusMessage.

Mutaciones permitidas:

- resolver index durante construcción;
- binder binding state;
- host attachment state;
- SceneTree mediante parent explícito;
- DeviceBus subscriptions.

## 44. Unit tests — Dependency Value

Verifica:

- campos;
- validez;
- Object disposed;
- no setters;
- no ownership.

## 45. Unit tests — Resolver

Verifica:

- empty válido;
- single value;
- multiple Devices;
- multiple Dependencies;
- duplicate exact;
- invalid Entry;
- missing IDs;
- disposed Value;
- no fallback;
- no mutation API.

## 46. Unit tests — Lifecycle Adapter

Verifica:

- null Handle;
- invalid Handle;
- missing Primary;
- missing behavior por fase;
- null Bus;
- invalid Report;
- exact delegation;
- same Report reference;
- lifecycle order controlado;
- shutdown después de partial initialize.

## 47. Unit tests — Subscription

Verifica:

- constructor validity;
- non-BusMessage ignored;
- invalid BusMessage ignored;
- wrong source ignored;
- wrong topic ignored;
- exact match forwarded;
- same envelope reference;
- invalid endpoint ignored.

## 48. Unit tests — Binder

Verifica:

- input validation;
- Handle identity;
- endpoint behavior;
- endpoint Callable;
- exact subscribe;
- duplicate bind;
- source filtering;
- exact unsubscribe;
- unknown unbind;
- binding count;
- subscribe failure;
- unsubscribe failure.

## 49. Unit tests — Godot Host

Verifica:

- null parent;
- invalid parent;
- null/invalid Handle;
- non-Node Host Object;
- already parented Node;
- cycle;
- empty Host Objects;
- ordered attach;
- duplicate attach;
- reverse detach;
- unknown detach;
- parent mismatch;
- Host no free.

## 50. Integration test

`ManagedRuntimeAdapterIntegrationTest` utiliza:

- CompositionRuntime real;
- production Resolver;
- production Lifecycle Adapter;
- production Binder;
- production Godot Host;
- controlled factories;
- controlled managed runtime units.

Verifica:

```text
activate
→ Nodes attached
→ communication bound
→ lifecycle running
→ matching source forwarded
→ wrong source filtered
→ shutdown
→ unbind
→ detach
→ release
```

## 51. Baselines preservadas

No se modifican tests aceptados de:

- Runtime Construction;
- RuntimeFactoryRegistry;
- CompositionPlan;
- CompositionCompiler;
- CompositionRuntime;
- DeviceBus;
- Device Core.

Se crean pruebas sucesoras.

## 52. Implementation order

```text
1. RuntimeDependencyValue.
2. RuntimeDependencyValueTest.
3. ScopedRuntimeDependencyResolver.
4. ScopedRuntimeDependencyResolverTest.
5. ManagedRuntimeLifecycleAdapter.
6. ManagedRuntimeLifecycleAdapterTest.
7. RuntimeSourceFilteredSubscription.
8. RuntimeSourceFilteredSubscriptionTest.
9. ManagedRuntimeCommunicationBinder.
10. ManagedRuntimeCommunicationBinderTest.
11. GodotNodeRuntimeHost.
12. GodotNodeRuntimeHostTest.
13. ManagedRuntimeAdapterIntegrationTest.
14. Runtime Suite.
15. Run All.
16. Refactor audit.
17. Baseline documentation.
```

## 53. Criterios de aceptación

Los 33 criterios de ADR-012 son obligatorios.

Además:

- cada archivo completo;
- parser gate por componente;
- prueba aislada por componente;
- no modificación de baselines;
- integration real con CompositionRuntime;
- cero missing metrics;
- Run All PASS;
- Hardware no activado.

## 54. Fuera de alcance

- concrete runtime factory;
- concrete Distance Sensor unit;
- Profile/Manifest correction;
- health report production;
- Physics Provider construction;
- Composition Root;
- Supervisor;
- hot swap;
- Hardware;
- persistence;
- async;
- Adapter Registry.

## 55. Estado

```text
MANAGED RUNTIME ADAPTER BOUNDARY 1.0
IMPLEMENTADO
VERIFICADO
BASELINE ACEPTADA
```

Componentes:

```text
RuntimeDependencyValue
ScopedRuntimeDependencyResolver
ManagedRuntimeLifecycleAdapter
RuntimeSourceFilteredSubscription
ManagedRuntimeCommunicationBinder
GodotNodeRuntimeHost
```

Baseline propia:

```text
RuntimeDependencyValueTest               11
ScopedRuntimeDependencyResolverTest      17
ManagedRuntimeLifecycleAdapterTest       15
RuntimeSourceFilteredSubscriptionTest     8
ManagedRuntimeCommunicationBinderTest    21
GodotNodeRuntimeHostTest                 16
ManagedRuntimeAdapterIntegrationTest     18
                                         ---
                                         106 checks
```

Runtime Suite:

```text
17 tests
420 checks
0 failures
RESULT: PASS
```

Global:

```text
76 tests
2262 checks
0 failures
0 missing metrics
Plan ExitCode: 0
RESULT: PASS
```

Corrección durante implementación:

```text
ManagedRuntimeLifecycleAdapter valida
result_value is ValidationReport
antes de asignación tipada.
```

Commit:

```text
236e031
feat(runtime): add managed runtime adapters
```

Siguiente milestone recomendado:

```text
Distance Sensor Runtime Slice 1.0
Problema y análisis
```
