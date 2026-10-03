# ADR-012 — Managed Runtime Object Behaviors and Production Adapter Boundaries

| Campo | Valor |
|---|---|
| Estado | ACEPTADO — IMPLEMENTADO — VERIFICADO |
| Versión | 1.1 |
| Fecha | 03/10/2026 |
| Componentes | ScopedRuntimeDependencyResolver, ManagedRuntimeLifecycleAdapter, ManagedRuntimeCommunicationBinder, RuntimeSourceFilteredSubscription, GodotNodeRuntimeHost |
| Alcance | Frontera entre CompositionRuntime, objetos runtime administrados, DeviceBus y Godot Node host |

## 1. Contexto

CompositionRuntime 1.0 está implementado y verificado.

Recibe colaboradores explícitos:

```text
RuntimeFactoryRegistry
RuntimeDependencyValueResolver behavior
RuntimeHost behavior
RuntimeLifecycleAdapter behavior
RuntimeCommunicationBinder behavior
```

Los behaviors fueron verificados mediante test doubles.

Todavía no existen implementaciones reutilizables de producción.

## 2. Problema

Los objetos runtime concretos no comparten una clase base obligatoria.

`RuntimeDeviceHandle` conserva:

```text
Primary Runtime Object: Object
Host Objects: Array[Object]
```

El Adapter no puede asumir que Primary es:

- Device;
- Node;
- DistanceSensorDevice;
- una clase concreta;
- una versión concreta de Profile.

Tampoco debe descubrir behavior mediante SceneTree, autoload o service locator.

## 3. Evidencia actual

`Device` es `RefCounted` y expone lifecycle que devuelve `bool`:

```gdscript
initialize() -> bool
set_ready() -> bool
start() -> bool
shutdown() -> bool
```

`DistanceSensorDevice` es `Node` y requiere:

```gdscript
initialize_sensor(
    sensor_id,
    device_bus,
    provider
) -> bool
```

Estas firmas no son intercambiables.

## 4. Discrepancia de Device concreto

El Profile canónico ideal de Distance Sensor declara:

```text
distance_measurement
health_reporting
```

y publica:

```text
distance_measurement
health_report
```

`DistanceSensorDevice` construye internamente un Manifest que solo declara:

```text
distance_measurement
```

Además no consume el `DeviceConfiguration` compilado.

Por tanto, el sensor actual no debe definir prematuramente la frontera genérica de adapters.

## 5. Decisión principal

Las factories podrán producir como Primary Runtime Object una unidad administrada por behavior.

No se requiere herencia común.

Lifecycle behavior canónico:

```gdscript
runtime_initialize(
    device_bus: DeviceBus
) -> ValidationReport

runtime_set_ready() -> ValidationReport

runtime_start() -> ValidationReport

runtime_shutdown() -> ValidationReport
```

Communication endpoint behavior:

```gdscript
get_runtime_input_endpoint(
    port_id: StringName
) -> Callable
```

## 6. Razón

El behavior vive junto al producto runtime que conoce:

- su implementación concreta;
- sus dependencias;
- su DeviceConfiguration;
- sus recursos;
- su lifecycle local;
- sus endpoints.

El adapter global solo coordina y valida.

No contiene type switches o Profile switches.

## 7. Primary Runtime Object

Puede ser:

- controller;
- runtime unit;
- wrapper;
- Device concreto que ya cumpla behavior.

No necesita ser Node.

No necesita heredar Device.

No necesita heredar una clase adapter.

## 8. Host Objects

Los Nodes que deben entrar a SceneTree permanecen en:

```text
RuntimeDeviceHandle Host Objects
```

Primary Runtime Object y Host Objects pueden representar responsabilidades distintas.

Ejemplo futuro:

```text
Primary:
DistanceSensorRuntimeUnit

Host Objects:
DistanceSensorDevice
PhysicsDistanceProvider cuando corresponda
```

## 9. ManagedRuntimeLifecycleAdapter

Implementa el behavior requerido por CompositionRuntime:

```gdscript
initialize(handle, device_bus)
set_ready(handle)
start(handle)
shutdown(handle)
```

Obtiene Primary Runtime Object y delega a los methods `runtime_*`.

No conoce Profiles o clases concretas.

## 10. Lifecycle Reports

Los methods administrados devuelven `ValidationReport`.

No devuelven `bool`.

Razones:

- conservar causa;
- severidad explícita;
- related object y field;
- integración directa con CompositionRuntime;
- cleanup issues acumulables.

Wrappers concretos convierten APIs `bool` cuando sea necesario.

## 11. Partial initialize

`runtime_shutdown()` debe tolerar:

- initialize parcial;
- estado CREATED;
- estado inicializado;
- cleanup best effort;
- llamada repetida segura según contrato local.

CompositionRuntime incluye el Handle actual en rollback antes de invocar initialize.

## 12. ScopedRuntimeDependencyResolver

Se implementará un resolver inmutable y scoped a una activación.

Lookup exacto:

```text
Device ID
+
Dependency ID
→ Object
```

No tendrá:

- register después de construcción;
- fallback;
- lookup por tipo;
- lookup global;
- acceso por path;
- SceneTree;
- autoload;
- filesystem.

## 13. Dependency values

La entrada será una colección de valores explícitos.

Cada valor conserva:

```text
Device ID
Dependency ID
Object
```

Ownership no pertenece al resolver.

Ownership continúa definido por `RuntimeDependencySpec` y se materializa en `RuntimeDependencyBinding`.

## 14. Resolver no es service locator

La instancia:

- pertenece a una activación;
- solo resuelve IDs declarados;
- no expone búsqueda arbitraria;
- no es singleton;
- no es autoload;
- no es mutable después de construcción.

CompositionRuntime sigue consultando únicamente Specs del Plan.

## 15. GodotNodeRuntimeHost

Se implementará fuera de `core/` porque depende de `Node`.

Constructor:

```gdscript
GodotNodeRuntimeHost.new(
    parent: Node
)
```

Parent es explícito.

No se descubre SceneTree.

## 16. Host responsibility

GodotNodeRuntimeHost:

- valida Handle;
- valida parent vivo;
- exige Host Objects Node;
- valida que no tengan parent;
- adjunta en orden;
- revierte attach parcial;
- detach en orden inverso;
- conserva attachment state por Handle.

No libera Nodes.

Factory release conserva destrucción y ownership.

## 17. Host idempotencia

Attach duplicado se rechaza o retorna Report bloqueante sin duplicar Nodes.

Detach de Handle no attached es no-op válido.

Detach parcial conserva observabilidad de Nodes no confirmados.

## 18. ManagedRuntimeCommunicationBinder

Implementa:

```gdscript
bind(
    directive,
    source_handle,
    target_handle,
    device_bus
) -> ValidationReport

unbind(
    directive,
    source_handle,
    target_handle,
    device_bus
) -> ValidationReport
```

No contiene callbacks en Plan.

## 19. Endpoint resolution

Binder obtiene Primary Runtime Object del target.

Exige:

```gdscript
get_runtime_input_endpoint(
    target_port_id
) -> Callable
```

Endpoint debe ser válido.

No se busca por Node path.

No se busca por method name derivado del Port ID.

## 20. RuntimeSourceFilteredSubscription

Binder crea un wrapper `RefCounted` por Connection Directive.

Conserva:

```text
Source Device ID
Topic
Target Callable
```

Recibe mensajes desde DeviceBus.

Solo reenvía cuando:

- message es BusMessage;
- BusMessage es válido;
- source_id coincide;
- topic coincide;
- target Callable continúa válida.

## 21. Envelope completo

El endpoint recibe `BusMessage` completo.

No recibe únicamente payload.

Razones:

- conserva provenance;
- conserva source identity;
- conserva timestamp;
- conserva topic;
- target decide interpretación de payload.

## 22. Binder ownership

Binder posee subscription wrappers durante bind.

DeviceBus conserva Callable registrada.

En unbind:

1. obtiene wrapper exacto;
2. usa la misma Callable;
3. ejecuta unsubscribe;
4. elimina wrapper después de confirmación.

No existe callback anónimo irrecuperable.

## 23. Duplicate connection

Connection ID ya bound no se vuelve a registrar.

Binder no aplica overwrite.

Unbind de Connection ID desconocida es no-op válido para idempotencia best effort.

## 24. Source Handle

Source Handle se utiliza para validar que el endpoint lógico coincide con la Directive.

La publicación concreta continúa siendo responsabilidad del runtime unit source.

Binder no modifica source y no república mensajes.

## 25. Adapter scope

Resolver, Host y Binder son instancias scoped al CompositionRuntime que los utiliza.

No son globales.

No se registran como autoload.

Lifecycle Adapter puede ser stateless, pero también se entrega explícitamente.

## 26. Factory responsibility preservada

RuntimeFactory continúa:

- construct-only;
- creando Primary Runtime Object;
- creando Host Objects;
- procesando Dependency Bindings;
- produciendo Handle;
- limpiando parciales;
- liberando producto.

Factory no:

- adjunta Nodes;
- ejecuta lifecycle;
- crea DeviceBus global;
- suscribe comunicación.

## 27. RuntimeDeviceHandle preservado

No se añaden campos de adapter a Handle 1.0.

Primary Runtime Object behavior evita romper el contrato aceptado.

Host Objects permanecen explícitos.

Dependency Bindings permanecen explícitos.

## 28. CompositionRuntime preservado

CompositionRuntime 1.0 no se modifica para introducir esta frontera.

Continúa dependiendo de behaviors explícitos.

Las nuevas implementaciones satisfacen esos behaviors.

## 29. Alternativas rechazadas

### Type switches centrales

Rechazados por acoplamiento a clases concretas.

### Adapter Registry por Profile

No seleccionado en 1.0 por añadir un segundo Registry sin necesidad demostrada.

### Adapters dentro de Handle

Rechazados porque rompen RuntimeDeviceHandle 1.0 y mezclan producto con coordinación.

### Factory ejecuta lifecycle

Rechazada por ADR-010.

### Factory adjunta Nodes

Rechazada por ADR-010.

### Forzar herencia Device

Rechazada por composición sobre herencia.

### Resolver mutable global

Rechazado como service locator.

### Callback dentro de CompositionPlan

Rechazado porque Plan permanece declarativo.

### Derivar method name desde Port ID

Rechazado por reflection implícita y contratos frágiles.

## 30. Seguridad

Aplica VP-002 2.0.

Errores producen ValidationReports.

No se permite:

- Node attach global;
- fallback de dependency;
- callback no removible;
- overwrite de binding;
- lifecycle parcial sin shutdown best effort;
- double ownership;
- Hardware activation.

## 31. Simulation-only

Boundary 1.0 se valida únicamente para Simulation.

GodotNodeRuntimeHost representa host Simulation.

Hardware adapters requieren decisión sucesora.

## 32. Estructura prevista

```text
core/runtime/
├── runtime_dependency_value.gd
├── scoped_runtime_dependency_resolver.gd
├── managed_runtime_lifecycle_adapter.gd
├── runtime_source_filtered_subscription.gd
└── managed_runtime_communication_binder.gd
```

```text
integration/godot/runtime/
└── godot_node_runtime_host.gd
```

## 33. Pruebas previstas

```text
test/core/runtime/
├── RuntimeDependencyValueTest.tscn
├── ScopedRuntimeDependencyResolverTest.tscn
├── ManagedRuntimeLifecycleAdapterTest.tscn
├── RuntimeSourceFilteredSubscriptionTest.tscn
├── ManagedRuntimeCommunicationBinderTest.tscn
├── GodotNodeRuntimeHostTest.tscn
└── ManagedRuntimeAdapterIntegrationTest.tscn
```

Scripts siguen convención `snake_case.gd`.

## 34. Integration target

Prueba sucesora:

```text
CompositionPlan
+
RuntimeFactoryRegistry
+
controlled managed runtime units
+
production Resolver
+
production Lifecycle Adapter
+
production Communication Binder
+
Godot Node RuntimeHost
↓
CompositionRuntime ACTIVE
↓
BusMessage source filtering
↓
SHUTDOWN
```

Factories concretas permanecen controladas en esta prueba.

## 35. Distance Sensor milestone posterior

Después de cerrar Boundary 1.0:

```text
Distance Sensor Runtime Slice 1.0
```

Debe resolver antes de factory production:

- Configuration como autoridad;
- Manifest efectivo;
- health_reporting declarado pero no implementado;
- provider ownership;
- Node lifecycle;
- release real.

## 36. Consecuencias positivas

- no type switches;
- no segundo Registry;
- Handle preservado;
- Runtime preservado;
- lifecycle extensible;
- communication wiring explícito;
- source filtering real;
- Node host explícito;
- resolver scoped;
- composición sobre herencia;
- adapters reutilizables.

## 37. Consecuencias negativas

- factories concretas deben crear runtime units;
- Primary Objects necesitan behavior uniforme;
- endpoint providers requieren contrato adicional;
- Binder conserva wrappers stateful;
- Host depende de parent explícito;
- concrete Distance Sensor se pospone;
- más componentes antes del primer Device production.

Estas consecuencias son aceptadas.

## 38. Criterios de aceptación

1. Resolver scoped e inmutable.
2. Lookup exacto por Device y Dependency ID.
3. Sin fallback.
4. Sin mutation API.
5. Lifecycle delegate sin type switch.
6. Primary behavior explícito.
7. ValidationReport obligatorio.
8. Partial initialize tolerado.
9. Host parent explícito.
10. Host Objects Node.
11. Attach transaccional.
12. Detach reverse.
13. Host no libera Nodes.
14. Endpoint lookup explícito.
15. No method name derivado.
16. BusMessage completo.
17. Source ID filtrado.
18. Topic filtrado.
19. Subscription wrapper owned.
20. Unsubscribe exacto.
21. Duplicate connection bloqueada.
22. RuntimeDeviceHandle sin cambios.
23. CompositionRuntime sin cambios.
24. Factory responsibility preservada.
25. No singleton.
26. No autoload.
27. No SceneTree discovery.
28. No service locator.
29. Simulation-only.
30. Tests unitarios PASS.
31. Integration PASS.
32. Runtime Suite PASS.
33. Run All PASS.

## 39. Fuera de alcance

- concrete Distance Sensor factory;
- concrete Distance Sensor runtime unit;
- Profile/Manifest reconciliation;
- health reporting implementation;
- Physics Provider factory;
- Composition Root production;
- Supervisor;
- Last Known Good replacement;
- hot swap;
- Hardware adapters;
- persistence;
- plugin discovery;
- Adapter Registry;
- async lifecycle;
- threads.

## 40. Estado

```text
ADR-012 1.1
ACEPTADO
IMPLEMENTADO
VERIFICADO
```

Implementación:

```text
RuntimeDependencyValue
ScopedRuntimeDependencyResolver
ManagedRuntimeLifecycleAdapter
RuntimeSourceFilteredSubscription
ManagedRuntimeCommunicationBinder
GodotNodeRuntimeHost
```

Pruebas sucesoras:

```text
7 tests
106 checks
0 failures
0 missing metrics
```

Runtime Suite:

```text
17 tests
420 checks
RESULT: PASS
```

Global:

```text
76 tests
2262 checks
0 failures
0 missing metrics
RESULT: PASS
```

Commit:

```text
236e031
feat(runtime): add managed runtime adapters
```

Distance Sensor Runtime Slice permanece como decisión sucesora.
