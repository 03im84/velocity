# System Composition Pipeline — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.6 |
| Fecha | 04/09/2026 |
| ADR relacionados | ADR-009 — System Composition Pipeline; ADR-010 — Runtime Construction and Factory Binding |
| Alcance | Definición, resolución, Graph assembly, construcción runtime, planificación, compilación y activación |

## 1. Propósito

Este documento describe el pipeline completo de composición de Velocity.

Estado implementado:

```text
SystemProfile 1.0

DeviceCatalog 1.0

DeviceGraphAssembler 1.0

Runtime Construction Contract 1.0
```

Diseños activos:

```text
RuntimeFactoryRegistry 1.0

CompositionPlan 1.0
```

Siguiente implementación:

```text
RuntimeDependencySpec
```

CompositionCompiler permanece posterior a Registry y Plan.

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

### Implementado

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

```text
RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult

RuntimeFactory behavior

RuntimeHost behavior
```

### Diseñado

```text
RuntimeDependencySpec

RuntimeFactoryDescriptor

RuntimeFactoryRegistryDraft

RuntimeFactoryRegistryCompiler

RuntimeFactoryRegistry

CompositionDeviceEntry

CompositionConnectionDirective

CompositionPlan
```

### Futuro

```text
CompositionCompiler

CompositionRuntime
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
└── device_graph_assembler.gd
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
└── runtime_factory_build_result.gd
```

## 5. Estructura siguiente

### RuntimeFactoryRegistry

```text
core/runtime/
├── runtime_dependency_spec.gd
├── runtime_factory_descriptor.gd
├── runtime_factory_registry_draft.gd
├── runtime_factory_registry.gd
├── runtime_factory_registry_compile_result.gd
└── runtime_factory_registry_compiler.gd
```

### CompositionPlan

```text
core/composition/
├── composition_device_entry.gd
├── composition_connection_directive.gd
└── composition_plan.gd
```

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

Runtime futuro resolverá callbacks y source filtering.

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

## 38. CompositionCompiler futuro

Entradas:

```text
DeviceGraphSnapshot

RuntimeFactoryRegistry

Activation Context

DeviceBusDispatchPolicy
```

Salida:

```text
CompositionPlan

ValidationReport
```

No ejecuta.

## 39. CompositionRuntime futuro

Entradas:

- CompositionPlan;
- Registry;
- dependency values;
- RuntimeHost.

Posee:

- DeviceBus;
- Handles;
- attach state;
- lifecycle;
- rollback;
- shutdown.

## 40. Rollback

Factory build local es atómico.

Rollback global usa orden inverso.

Last Known Good cambia únicamente después de commit.

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

Global:

```text
54 tests
1569 checks
0 failures
0 missing metrics
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

## 44. Orden siguiente

```text
1. RuntimeDependencySpec.

2. RuntimeDependencySpecTest.

3. RuntimeFactoryDescriptor.

4. RuntimeFactoryDescriptorTest.

5. RuntimeFactoryRegistryDraft.

6. RuntimeFactoryRegistryDraftTest.

7. RuntimeFactoryRegistry.

8. CompileResult.

9. RegistryCompiler.

10. RegistryCompilerTest.

11. CompositionDeviceEntry.

12. CompositionDeviceEntryTest.

13. CompositionConnectionDirective.

14. CompositionConnectionDirectiveTest.

15. CompositionPlan.

16. CompositionPlanTest.

17. Registry–Plan Integration.

18. Run All.

19. CompositionCompiler Design.
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

- CompositionCompiler;
- CompositionRuntime;
- factory execution real;
- RuntimeHost concreto;
- dependency resolution activa;
- DeviceBus activo;
- lifecycle execution;
- scheduling SCC;
- persistence;
- host target;
- Hardware runtime;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation.

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
IMPLEMENTADO Y VERIFICADO

DEVICECATALOG 1.0
IMPLEMENTADO Y VERIFICADO

DEVICEGRAPHASSEMBLER 1.0
IMPLEMENTADO Y VERIFICADO

RUNTIME CONSTRUCTION CONTRACT 1.0
IMPLEMENTADO Y VERIFICADO

RUNTIMEFACTORYREGISTRY 1.0
DISEÑO ACTIVO

COMPOSITIONPLAN 1.0
DISEÑO ACTIVO
```

Siguiente implementación:

```text
RuntimeDependencySpec
```