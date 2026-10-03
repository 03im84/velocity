# System Composition Pipeline — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.12 |
| Fecha | 03/10/2026 |
| ADR relacionados | ADR-009 — System Composition Pipeline; ADR-010 — Runtime Construction and Factory Binding; ADR-011 — Composition Runtime Activation, Ownership and Rollback |
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

Siguiente milestone recomendado:

```text
Production Runtime Adapters
Problema y análisis
```

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
↓
DeviceCatalog
↓
SystemProfile
↓
DeviceGraphAssembler
↓
DeviceGraphSnapshot
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

Contratos y componentes:

```text
RuntimeFactoryKey
RuntimeDependencyBinding
RuntimeConstructionRequest
RuntimeDeviceHandle
RuntimeFactoryBuildResult
RuntimeDependencySpec
RuntimeFactoryDescriptor
RuntimeFactoryRegistryDraft
RuntimeFactoryRegistry
RuntimeFactoryRegistryCompileResult
RuntimeFactoryRegistryCompiler
CompositionDeviceEntry
CompositionConnectionDirective
CompositionPlan
CompositionCompileResult
CompositionCompiler
CompositionRuntimeOperationResult
CompositionRuntime
```

### Futuro

```text
Production Runtime Adapters
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
└── runtime_factory_registry_compiler.gd
```

## 5. Estructura siguiente

CompositionRuntime 1.0 está cerrado.

Siguiente frontera de trabajo:

```text
Production Runtime Adapters
```

Debe comenzar por problema y análisis antes de decidir:

- Godot RuntimeHost concreto;
- Dependency Value Resolver de producción;
- Lifecycle Adapter de producción;
- Communication Binder de producción;
- factories concretas;
- Composition Root.

Supervisor, hot swap y Hardware Runtime permanecen posteriores.

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
3 tests
142 checks
```

DeviceCatalog:

```text
3 tests
89 checks
```

DeviceGraphAssembler:

```text
2 tests
114 checks
```

Runtime Construction:

```text
6 tests
173 checks
```

RuntimeFactoryRegistry:

```text
4 tests
141 checks
```

Runtime Suite preservada:

```text
10 tests
314 checks
```

CompositionPlan:

```text
4 tests
141 checks
```

CompositionCompiler:

```text
3 tests
119 checks
```

CompositionRuntime:

```text
4 tests
186 checks
```

Composition Suite vigente:

```text
16 tests
702 checks
```

Global vigente:

```text
69 tests
2156 checks
0 failures
0 missing metrics
Plan ExitCode: 0
RESULT: PASS
```

## 43. Tooling

Velocity Test Dashboard:

```text
0.4.0
```

Runner Metrics Protocol:

```text
1
```

Automatic suites:

```text
10 domains
0 Other
```

## 44. Orden completado

```text
1. RuntimeFactoryRegistry 1.0.
   IMPLEMENTADO Y VERIFICADO.

2. CompositionPlan 1.0.
   IMPLEMENTADO Y VERIFICADO.

3. CompositionCompiler 1.0.
   IMPLEMENTADO Y VERIFICADO.

4. ADR-011 y CompositionRuntime Design.
   ACEPTADOS.

5. CompositionRuntimeOperationResult.
   PASS — 17 checks.

6. CompositionRuntime.
   PASS — 62 checks.

7. Runtime transaction integration.
   PASS — 57 checks.

8. Full runtime pipeline integration.
   PASS — 50 checks.

9. Composition Suite.
   PASS — 16 tests, 702 checks.

10. Run All.
    PASS — 69 tests, 2156 checks.

11. Feature commit.
    cc9a7ae.

12. Registrar baseline documental.
    COMPLETADO EN ESTA REVISIÓN.
```

Siguiente trabajo:

```text
Production Runtime Adapters
Problema y análisis
```

## 45. Baselines preservadas

No se modifican:

```text
RuntimeFactoryKeyTest

RuntimeDependencyBindingTest

RuntimeConstructionRequestTest

RuntimeDeviceHandleTest

RuntimeFactoryBuildResultTest

RuntimeConstructionContractIntegrationTest
```

## 46. Fuera de alcance

- Production Runtime Adapters;
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
- telemetry concreta;
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

IMPLEMENTADOS Y VERIFICADOS
```

ADR-011:

```text
ACEPTADO
IMPLEMENTADO
VERIFICADO
```

Baseline final:

```text
Composition Suite:
16 tests
702 checks
0 failures

Run All:
69 tests
2156 checks
0 failures
0 missing metrics
RESULT: PASS
```

Último commit de implementación:

```text
cc9a7ae
feat(runtime): add transactional composition runtime
```

Siguiente milestone recomendado:

```text
Production Runtime Adapters
Problema y análisis
```
