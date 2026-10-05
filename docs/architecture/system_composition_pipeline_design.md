# System Composition Pipeline — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.17 |
| Fecha | 04/10/2026 |
| ADR relacionados | ADR-009 — System Composition Pipeline; ADR-010 — Runtime Construction and Factory Binding; ADR-011 — Composition Runtime Activation, Ownership and Rollback; ADR-012 — Managed Runtime Object Behaviors and Production Adapter Boundaries; ADR-013 — Distance Sensor Simulation Runtime Slice and Configuration Fidelity; ADR-014 — Input Intent Sampling and Runtime Publication |
| Alcance | Definición, resolución, Graph assembly, construcción runtime, planificación, compilación y activación |

## 1. Propósito

Este documento describe el pipeline completo de composición de Velocity.

Estado implementado y verificado:

```text
SystemProfile 1.0
DeviceCatalog 1.0
DeviceGraphAssembler 1.0
Runtime Construction Contract 1.0
RuntimeFactoryRegistry 1.0
CompositionPlan 1.0
CompositionCompiler 1.0
CompositionRuntime 1.0
```

Pipeline full runtime verificado:

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

Slices concretos activos:

```text
Managed Runtime Adapter Boundary 1.0
Distance Sensor Runtime Slice 1.0
Input Runtime Slice 1.0
IMPLEMENTADOS Y VERIFICADOS
```

Baseline global: 85 tests, 2418 checks, PASS.

## 2. Pipeline completo

```text
Documento persistente
		│
		▼
SystemProfileLoader
		│
		▼
SystemProfileDraft
		│
		▼
SystemProfileCompiler
		│
		▼
SystemProfile
		│
		▼
DeviceGraphAssembler
		│
		▼
DeviceGraphSnapshot
		│
		▼
CompositionCompiler
		│
		▼
CompositionPlan
		│
		▼
CompositionRuntime
		│
		├── RuntimeFactoryRegistry
		├── RuntimeHost
		├── RuntimeDependencyBindings
		└── DeviceBus
				│
				▼
RuntimeConstructionRequest
				│
				▼
RuntimeFactory
				│
				▼
RuntimeFactoryBuildResult
				│
				▼
RuntimeDeviceHandle
```

## 3. Estado

### Implementado y verificado

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

Collaborators de producción:

```text
RuntimeDependencyValue
ScopedRuntimeDependencyResolver
ManagedRuntimeLifecycleAdapter
RuntimeSourceFilteredSubscription
ManagedRuntimeCommunicationBinder
GodotNodeRuntimeHost
```

Slices concretos:

```text
Distance Sensor Runtime Slice 1.0
Input Runtime Slice 1.0
```

### Siguiente diseño de producto

```text
Propulsion Runtime Slice 1.0
```

### Futuro

```text
Hover Physics Slice
Playable Vehicle Composition
CompositionRuntimeSupervisor
Last Known Good manager
Hot swap
Hardware Runtime
```

## 4. Estructura implementada

```text
core/composition/
├── system_connection_spec.gd
├── system_profile_draft.gd
├── system_profile.gd
├── system_profile_compile_result.gd
├── system_profile_compiler.gd
├── device_graph_assembly_result.gd
├── device_graph_assembler.gd
├── composition_device_entry.gd
├── composition_connection_directive.gd
├── composition_plan.gd
├── composition_compile_result.gd
├── composition_compiler.gd
├── composition_runtime_operation_result.gd
└── composition_runtime.gd
```

```text
core/catalog/
├── device_catalog_draft.gd
├── device_catalog.gd
├── device_catalog_compile_result.gd
└── device_catalog_compiler.gd
```

```text
core/runtime/
├── runtime_factory_key.gd
├── runtime_dependency_binding.gd
├── runtime_construction_request.gd
├── runtime_device_handle.gd
├── runtime_factory_build_result.gd
├── runtime_dependency_spec.gd
├── runtime_factory_descriptor.gd
├── runtime_factory_registry_draft.gd
├── runtime_factory_registry.gd
├── runtime_factory_registry_compile_result.gd
├── runtime_factory_registry_compiler.gd
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

## 5. Slices concretos implementados

```text
integration/godot/devices/distance_sensor/
├── distance_sensor_runtime_unit.gd
└── distance_sensor_runtime_factory.gd
```

```text
core/input/
└── vehicle_control_command.gd

integration/godot/input/
├── godot_input_source.gd
├── godot_input_intent_provider.gd
├── input_sampling_node.gd
├── input_runtime_unit.gd
└── input_runtime_factory.gd
```

Ambos Slices atraviesan Profile, Catalog, SystemProfile, Graph, Registry, Plan, Runtime, `ACTIVE` y `SHUTDOWN`.

## 6. SystemProfile

```text
SystemProfileDraft
		│
		▼
SystemProfileCompiler
		│
		▼
SystemProfile
```

SystemProfile contiene:

- identidad;
- versión;
- metadata;
- Activation Context;
- DeviceConfigurations;
- SystemConnectionSpecs.

No contiene DeviceGraph o runtime.

## 7. DeviceProfileResolver

```gdscript
has_profile(
	profile_id: StringName,
	profile_version: int
) -> bool
```

```gdscript
get_profile(
	profile_id: StringName,
	profile_version: int
) -> DeviceProfile
```

Resolución exacta.

Sin latest.

Sin fallback.

## 8. DeviceCatalog

```text
DeviceCatalogDraft
		│
		▼
DeviceCatalogCompiler
		│
		▼
DeviceCatalog
```

Propiedades:

- inmutable;
- múltiples versiones;
- duplicado exacto bloqueante;
- orden preservado;
- no factories;
- no filesystem.

## 9. DeviceGraphAssembler

```text
SystemProfile
		│
		▼
DeviceProfileResolver
		│
		▼
DeviceManifestBuilder
		│
		▼
DeviceGraphNodeBuilder
		│
		▼
DeviceGraphDraft
		│
		▼
DeviceGraphSnapshot
```

Propiedades:

- stateless;
- Simulation-only;
- Devices antes de Connections;
- errors por etapas;
- no Graph parcial;
- no runtime.

## 10. DeviceGraphSnapshot

Representa topología inmutable.

No contiene:

- factory;
- Handle;
- Device activo;
- Bus activo;
- Runtime.

Ciclos pueden producir Simulation Hazard.

## 11. Runtime Construction Contract

Implementa:

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

## 12. RuntimeFactoryKey

```text
Profile ID

+

Profile Version

+

Activation Context
```

No contiene host target.

No existe fallback.

## 13. RuntimeDependencyBinding

Contiene:

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

Binding representa valor activo.

## 14. RuntimeConstructionRequest

Contiene:

- Device ID;
- Configuration;
- Factory Key;
- bindings pre-resueltos.

No es service locator.

## 15. RuntimeDeviceHandle

Contiene:

- Device ID;
- Configuration;
- Factory Key;
- Primary Runtime Object;
- Host Objects;
- bindings.

Representa ownership.

## 16. RuntimeFactory behavior

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

No inicializa ni adjunta.

## 17. RuntimeHost behavior

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

## 18. RuntimeDependencySpec

RuntimeDependencySpec declara una dependencia requerida.

Contiene:

```text
Dependency ID

Ownership
```

No contiene Value.

Todas las Specs 1.0 son obligatorias.

No existe optional flag.

## 19. Spec y Binding

```text
RuntimeDependencySpec

qué se necesita
```

```text
RuntimeDependencyBinding

qué Object satisface
la dependencia
```

Flujo:

```text
Factory Descriptor

↓

Dependency Specs

↓

Composition Device Entry

↓

Composition Plan

↓

Composition Runtime

↓

Dependency Bindings

↓

Construction Request
```

## 20. RuntimeFactoryDescriptor

Contiene:

```text
RuntimeFactoryKey

RuntimeFactory Object

RuntimeDependencySpecs
```

Valida:

- Key;
- factory no null;
- factory instance válida;
- `build`;
- `release`;
- Specs;
- Dependency IDs únicas.

No ejecuta factory.

## 21. RuntimeFactoryRegistryDraft

Contiene:

```gdscript
descriptors: Array[RuntimeFactoryDescriptor]
```

Es editable.

Puede estar incompleto.

Compiler establece validez.

## 22. RuntimeFactoryRegistry

Pipeline:

```text
RuntimeFactoryRegistryDraft

↓

RuntimeFactoryRegistryCompiler

↓

RuntimeFactoryRegistry
```

Registry final es inmutable.

No tiene ID o versión propios.

## 23. Registry lookup

```text
RuntimeFactoryKey

→

RuntimeFactoryDescriptor

→

RuntimeFactory
```

Exacto por:

```text
Profile ID

Profile Version

Activation Context
```

No existe latest, fallback u overwrite.

## 24. Registry index

```text
Profile ID
	│
	└── Profile Version
			│
			└── Activation Context
					│
					└── Descriptor
```

No utiliza key concatenada.

## 25. Registry y factory compartida

La misma factory Object puede registrarse bajo Keys diferentes.

Solo una Key exacta duplicada es error.

Registry no infiere compatibilidad.

## 26. Registry no ejecuta

No invoca:

- build;
- release.

Solo valida behavior y devuelve referencias.

## 27. CompositionDeviceEntry

Contiene:

```text
Device ID

DeviceConfiguration

RuntimeFactoryKey

RuntimeDependencySpecs
```

No contiene:

- factory;
- Dependency Values;
- Bindings activos;
- Handle;
- DeviceBus.

## 28. CompositionConnectionDirective

Contiene:

```text
Connection ID

Source Device ID

Source Port ID

Topic

Target Device ID

Target Port ID
```

No contiene:

- Callable;
- Subscriber Object;
- DeviceBus;
- RuntimeDeviceHandle;
- DeviceGraphConnection como modelo interno.

## 29. CompositionPlan

Estado:

```text
Activation Context

CompositionDeviceEntries

CompositionConnectionDirectives

DeviceBusDispatchPolicy
```

No tiene Plan ID o Plan Version.

Es inmutable y no ejecutable.

## 30. Plan vacío

Plan vacío es válido cuando:

- contexto válido;
- Dispatch Policy válida;
- Entries vacías;
- Directives vacías.

Representa no-op.

Deployment puede rechazarlo externamente.

## 31. DeviceBusDispatchPolicy

Es obligatoria.

Razones:

- reproducibilidad;
- budgets explícitos;
- VP-002;
- no defaults ocultos;
- misma política en compile y runtime.

## 32. Orden de lifecycle

Forward order deriva de Device Entries:

```text
construction

attach

initialize

set_ready

start
```

Reverse order:

```text
shutdown

rollback
```

No se almacenan Arrays duplicados por fase.

## 33. Phase barriers

CompositionRuntime completa cada fase para todos antes de la siguiente.

```text
construir todos

↓

adjuntar todos

↓

inicializar todos

↓

set_ready todos

↓

start todos
```

## 34. Ciclos

DeviceGraph permite ciclos.

Plan no requiere topological sort.

Phase barriers permiten que todos existan antes de start.

Scheduling avanzado permanece futuro.

## 35. Communication directives

Connection Directives preservan:

- Source ID;
- Source Port;
- Topic;
- Target ID;
- Target Port;
- orden.

Runtime delega callbacks, endpoints y source filtering al Communication Binder explícito.

Plan no contiene callbacks.

## 36. Source identity

Stream identity:

```text
Topic

+

Source Device ID
```

Plan conserva ambos.

Esto permite filtrado futuro por Source ID.

## 37. Dependency flow

```text
RuntimeFactoryDescriptor

↓

RuntimeDependencySpecs

↓

CompositionDeviceEntry

↓

CompositionPlan

↓

CompositionRuntime

↓

RuntimeDependencyBindings

↓

RuntimeConstructionRequest
```

## 38. CompositionCompiler

Documento activo:

```text
docs/architecture/composition_compiler_design.md
Versión 1.2
```

Estado:

```text
IMPLEMENTADO Y VERIFICADO
```

Entradas:

```text
DeviceGraphSnapshot

RuntimeFactoryRegistry

Activation Context

DeviceBusDispatchPolicy
```

Salida:

```text
CompositionCompileResult
	├── CompositionPlan
	└── ValidationReport
```

Compiler 1.0 es Simulation-only.

Hardware queda bloqueado con HARDWARE_SAFETY_ERROR.

No ejecuta runtime.

## 39. CompositionRuntime

Documento activo:

```text
docs/architecture/composition_runtime_design.md
Versión 1.1
```

ADR:

```text
ADR-011 1.1
ACEPTADO
IMPLEMENTADO
VERIFICADO
```

Runtime 1.0 es:

- Simulation-only;
- stateful y one-shot;
- owner de DeviceBus y Handles;
- transaccional;
- phase-barriered;
- rollback inverso;
- cleanup best effort;
- shutdown explícito;
- sin hot swap interno.

Last Known Good y hot swap pertenecen a Supervisor futuro.

Commit:

```text
cc9a7ae
feat(runtime): add transactional composition runtime
```

Adapter boundary sucesor:

```text
managed Primary behaviors
scoped dependency resolution
source-filtered communication
explicit Godot Node host
```

CompositionRuntime 1.0 permanece sin cambios.

## 40. Rollback

Factory build local es atómico.

Rollback global usa orden inverso:

```text
shutdown initialized Handles
→ unbind Directives
→ detach Handles
→ release Handles
→ clear DeviceBus
```

Cada subfase continúa ante error y agrega Issues.

CompositionRuntime 1.0 no sustituye otro runtime activo.

Last Known Good pertenece a un Supervisor futuro.

## 41. No service locator

Factory recibe bindings pre-resueltos.

No descubre:

- servicios;
- Nodes;
- Devices;
- filesystem;
- hardware;
- singletons.

## 42. Baselines

SystemProfile:

```text
3 tests / 142 checks
```

DeviceCatalog:

```text
3 tests / 89 checks
```

DeviceGraphAssembler:

```text
2 tests / 114 checks
```

Runtime Construction:

```text
6 tests / 173 checks
```

RuntimeFactoryRegistry:

```text
4 tests / 141 checks
```

CompositionPlan:

```text
4 tests / 141 checks
```

CompositionCompiler:

```text
3 tests / 119 checks
```

CompositionRuntime:

```text
4 tests / 186 checks
```

Distance Sensor Runtime Slice:

```text
3 tests / 55 checks
```

Input Runtime Slice:

```text
6 tests / 101 checks
```

Suites vigentes:

```text
Composition Suite: 16 tests / 702 checks
Runtime Suite:     20 tests / 475 checks
Input Suite:        6 tests / 101 checks
```

Global vigente:

```text
85 tests
2418 checks
0 failures
0 timeout
0 engine errors
0 missing metrics
Plan ExitCode: 0
RESULT: PASS
```

## 43. Tooling

```text
Velocity Test Dashboard:        0.4.0
Velocity Tooling Dashboard Web: 0.5.0
Runner Metrics Protocol:        1
Velocity Submit Tool:           1.0.0
```

Automatic suites:

```text
11 domains
Input incluido
0 Other
```

## 44. Orden completado

```text
1. RuntimeFactoryRegistry 1.0.
2. CompositionPlan 1.0.
3. CompositionCompiler 1.0.
4. CompositionRuntime 1.0.
5. Managed Runtime Adapter Boundary 1.0.
6. Distance Sensor Runtime Slice 1.0.
7. Input Runtime Slice 1.0.

Todos IMPLEMENTADOS Y VERIFICADOS.
```

Últimos milestones concretos:

```text
53ffe1d feat(runtime): add distance sensor runtime slice
80c5118 test(input): add runtime pipeline integration
```

## 45. Baselines preservadas

Las pruebas aceptadas de Runtime Construction, Registry, Plan, Compiler, CompositionRuntime, Managed Adapters y Distance Sensor no fueron modificadas para hacer pasar Input Runtime Slice.

Input añade una prueba sucesora de full pipeline y conserva las baselines anteriores.

## 46. Fuera de alcance

- Propulsion Runtime Slice;
- Hover Physics Slice;
- Playable Vehicle Composition;
- Composition Runtime Root de producto;
- CompositionRuntimeSupervisor;
- Last Known Good manager;
- hot swap;
- multiple active runtimes;
- Hardware Runtime;
- scheduling SCC;
- persistence;
- host target en Factory Key;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation;
- telemetría concreta;
- automatic recovery.

## 47. Invariantes

1. Registry es inmutable.
2. Registry lookup es exacto.
3. Descriptor contiene Key, factory y Specs.
4. Registry no ejecuta.
5. Plan guarda Key, no factory.
6. Plan no contiene Callable.
7. Plan no contiene recursos activos.
8. Dependency Specs no contienen Values.
9. Device Entries son tipadas.
10. Connection Directives son tipadas.
11. Dispatch Policy es obligatoria.
12. Forward order deriva de Entries.
13. Reverse order invierte Entries.
14. Plan vacío es válido.
15. Ciclos no requieren topological sort.
16. CompositionCompiler no ejecuta.
17. CompositionRuntime posee recursos.
18. Factories concretas son construct-only.
19. RuntimeUnit publica solo mientras está RUNNING.
20. Dependencias BORROWED sobreviven shutdown y release.

## 48. Estado

```text
SYSTEMPROFILE 1.0
DEVICECATALOG 1.0
DEVICEGRAPHASSEMBLER 1.0
RUNTIME CONSTRUCTION CONTRACT 1.0
RUNTIMEFACTORYREGISTRY 1.0
COMPOSITIONPLAN 1.0
COMPOSITIONCOMPILER 1.0
COMPOSITIONRUNTIME 1.0
MANAGED RUNTIME ADAPTER BOUNDARY 1.0
DISTANCE SENSOR RUNTIME SLICE 1.0
INPUT RUNTIME SLICE 1.0

IMPLEMENTADOS Y VERIFICADOS
```

Baseline vigente:

```text
Input Suite: 6 tests / 101 checks
Runtime Suite: 20 tests / 475 checks
Run All: 85 tests / 2418 checks
Failures: 0
Missing Metrics: 0
RESULT: PASS
```

Último feature/test commit:

```text
80c5118 test(input): add runtime pipeline integration
```

Siguiente milestone de producto:

```text
Propulsion Runtime Slice 1.0
PROBLEMA Y DISEÑO PENDIENTES
```
