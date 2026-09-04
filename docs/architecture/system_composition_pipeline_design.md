# System Composition Pipeline — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.4 |
| Fecha | 25/08/2026 |
| ADR relacionados | ADR-009 — System Composition Pipeline; ADR-010 — Runtime Construction and Factory Binding |
| Alcance | Definición, resolución, Graph assembly, construcción runtime, compilación y activación |

## 1. Propósito

Este documento describe el pipeline completo de composición de Velocity.

Define la relación entre:

- SystemProfileDraft;
- SystemProfileCompiler;
- SystemProfile;
- DeviceProfileResolver;
- DeviceCatalog;
- DeviceGraphAssembler;
- DeviceGraphSnapshot;
- RuntimeFactoryKey;
- RuntimeDependencyBinding;
- RuntimeConstructionRequest;
- RuntimeDeviceHandle;
- RuntimeFactoryBuildResult;
- RuntimeFactoryRegistry;
- RuntimeHost;
- CompositionCompiler;
- CompositionPlan;
- CompositionRuntime;
- persistencia externa.

Estado implementado:

```text
SystemProfile 1.0

DeviceCatalog 1.0

DeviceGraphAssembler 1.0
```

Estado arquitectónico activo:

```text
Runtime Construction Contract 1.0
```

Siguiente componente:

```text
RuntimeFactoryKey
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

## 3. Estado del pipeline

### 3.1 Implementado

```text
DeviceProfiles
		│
		▼
DeviceCatalog
		│
		▼
SystemProfile
		│
		▼
DeviceGraphAssembler
		│
		▼
DeviceGraphSnapshot
```

### 3.2 Diseñado y autorizado

```text
RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult

RuntimeFactory behavior

RuntimeHost behavior
```

### 3.3 Pendiente de diseño

```text
RuntimeFactoryRegistry

CompositionPlan

CompositionCompiler

CompositionRuntime
```

## 4. Estructura implementada

### 4.1 SystemProfile

```text
core/composition/
├── system_connection_spec.gd
├── system_profile_draft.gd
├── system_profile.gd
├── system_profile_compile_result.gd
└── system_profile_compiler.gd
```

### 4.2 DeviceCatalog

```text
core/catalog/
├── device_catalog_draft.gd
├── device_catalog.gd
├── device_catalog_compile_result.gd
└── device_catalog_compiler.gd
```

### 4.3 DeviceGraphAssembler

```text
core/composition/
├── device_graph_assembly_result.gd
└── device_graph_assembler.gd
```

## 5. Estructura autorizada para Runtime Construction

```text
core/runtime/
├── runtime_factory_key.gd
├── runtime_dependency_binding.gd
├── runtime_construction_request.gd
├── runtime_device_handle.gd
└── runtime_factory_build_result.gd
```

Pruebas:

```text
test/core/runtime/
├── RuntimeFactoryKeyTest.tscn
├── runtime_factory_key_test.gd
├── RuntimeDependencyBindingTest.tscn
├── runtime_dependency_binding_test.gd
├── RuntimeConstructionRequestTest.tscn
├── runtime_construction_request_test.gd
├── RuntimeDeviceHandleTest.tscn
├── runtime_device_handle_test.gd
├── RuntimeFactoryBuildResultTest.tscn
├── runtime_factory_build_result_test.gd
├── RuntimeConstructionContractIntegrationTest.tscn
├── runtime_construction_contract_integration_test.gd
├── runtime_test_factory.gd
├── runtime_test_host.gd
└── runtime_test_object.gd
```

## 6. Dependencias permitidas

El pipeline lógico puede depender de:

```text
DeviceProfile

DeviceConfiguration

DeviceManifest

DeviceGraphNode

DeviceGraphDraft

DeviceGraphSnapshot

ValidationIssue

ValidationReport

Object
```

SystemProfileCompiler y DeviceGraphAssembler dependen del comportamiento DeviceProfileResolver.

Runtime contracts utilizan `Object` sin invocar APIs específicas de Node.

## 7. Dependencias prohibidas

Los componentes lógicos no descubren dependencias mediante:

```text
SceneTree

Node paths

autoloads

singletons globales

filesystem

JSON

GraphEditor

hardware adapters concretos

telemetría
```

RuntimeHost concreto podrá adaptar Objects a un host.

Los contratos base no conocen ese host.

## 8. SystemConnectionSpec

Responsabilidad:

> Representar endpoints persistibles antes de construir DeviceGraph.

Contiene:

- Connection ID determinista;
- Source Device ID;
- Source Port ID;
- Target Device ID;
- Target Port ID.

No contiene:

- Topic;
- Semantic Kind;
- DeviceGraphConnection;
- factory;
- runtime object.

## 9. SystemProfileDraft

Representa composición editable.

Contiene:

- System Profile ID;
- versión;
- Display Name;
- descripción;
- Activation Context;
- DeviceConfiguration snapshots;
- SystemConnectionSpecs.

Puede estar incompleto.

No ejecuta.

## 10. SystemProfileCompiler

Responsabilidad:

> Validar SystemProfileDraft y producir SystemProfile.

Valida:

- identidad;
- contexto;
- Configurations;
- Device IDs;
- dependencias exactas;
- Connection Specs;
- endpoints conocidos.

No valida Ports, Topics, fan-in o ciclos.

## 11. SystemProfile

SystemProfile es:

```text
RefCounted

inmutable

independiente de filesystem

independiente de DeviceGraph

no ejecutable
```

Utiliza referencias exactas:

```text
Profile ID

+

Profile Version
```

## 12. DeviceProfileResolver

Contrato por comportamiento:

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

No existe fallback.

## 13. DeviceCatalog

Pipeline:

```text
DeviceCatalogDraft
		│
		▼
DeviceCatalogCompiler
		│
		▼
DeviceCatalog
```

DeviceCatalog:

- es inmutable;
- permite múltiples versiones;
- rechaza duplicado exacto;
- conserva orden;
- no implementa latest;
- no contiene factories;
- no abre archivos;
- satisface DeviceProfileResolver.

## 14. DeviceGraphAssembler

Responsabilidad:

> Construir DeviceGraphSnapshot desde SystemProfile y DeviceProfileResolver.

Pipeline:

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
connect_ports()
		│
		▼
create_snapshot()
		│
		▼
DeviceGraphSnapshot
```

Propiedades:

- stateless;
- Simulation-only;
- Hardware rechazado;
- Devices antes de Connections;
- errores agregados por etapas;
- gate entre etapas;
- no Graph parcial;
- orden preservado;
- no mutación;
- no runtime;
- no filesystem.

## 15. DeviceGraphSnapshot

Representa topología validada e inmutable.

No contiene:

- RuntimeFactory;
- RuntimeDeviceHandle;
- DeviceBus activo;
- Device activo;
- CompositionRuntime.

Un ciclo sin evidencia temporal produce:

```text
SIMULATION_HAZARD

graph_cycle_requires_temporal_analysis
```

Simulation puede continuar.

Hardware queda bloqueado.

## 16. Runtime Construction Contract

Runtime Construction define cómo transformar una directiva de plan en una unidad runtime construida.

Pipeline:

```text
RuntimeFactoryKey
		│
		▼
RuntimeFactoryRegistry
		│
		▼
RuntimeFactory
		│
		▲
RuntimeConstructionRequest
		│
		▼
RuntimeFactoryBuildResult
		│
		▼
RuntimeDeviceHandle
```

## 17. Factory construct-only

RuntimeFactory:

- construye;
- valida Request;
- produce Handle;
- limpia parciales;
- libera Handles propios cuando se solicita.

RuntimeFactory no:

- inicializa;
- ejecuta set_ready;
- ejecuta start;
- coordina shutdown global;
- adjunta host objects;
- crea DeviceBus global;
- descubre dependencias;
- consulta service locator.

## 18. RuntimeFactory behavior

Contrato:

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

No requiere clase base universal.

La misma factory que construye conoce cómo liberar.

## 19. RuntimeFactoryKey

Identidad exacta:

```text
Profile ID

+

Profile Version

+

Activation Context
```

No contiene `host_target` en 1.0.

No existe:

- latest;
- fallback;
- sustitución de contexto;
- sustitución de versión.

CompositionPlan almacenará RuntimeFactoryKey.

No almacenará factory Object.

## 20. RuntimeDependencyBinding

Contiene:

```text
Dependency ID

Dependency Value

Ownership
```

Dependency Value:

```gdscript
Object
```

Ownership:

```text
BORROWED

TRANSFERRED
```

## 21. BORROWED

BORROWED conserva owner original.

Factory y Handle pueden utilizar la dependencia.

Factory release no la libera.

Ejemplo:

```text
DeviceBus compartido
```

El binding continúa siendo explícito.

## 22. TRANSFERRED

TRANSFERRED cambia ownership al invocar `factory.build()`.

En éxito:

```text
RuntimeDeviceHandle asume ownership.
```

En fallo:

```text
RuntimeFactory limpia.
```

Caller no ejecuta un segundo cleanup.

## 23. RuntimeConstructionRequest

Contiene:

- Device ID;
- DeviceConfiguration;
- RuntimeFactoryKey;
- RuntimeDependencyBindings pre-resueltos.

No contiene:

- service locator;
- SceneTree;
- autoload;
- filesystem;
- factory;
- Draft;
- CompositionRuntime mutable.

Crear Request no transfiere ownership.

La transferencia comienza al invocar factory.

## 24. RuntimeDeviceHandle

Contiene:

- Device ID;
- DeviceConfiguration;
- RuntimeFactoryKey;
- Primary Runtime Object;
- Host Objects;
- Dependency Bindings.

Primary Runtime Object:

```gdscript
Object
```

Host Objects:

```gdscript
Array[Object]
```

Handle representa una unidad runtime.

No coordina el sistema completo.

## 25. Host Objects

Factories pueden construir Objects host.

No pueden adjuntarlos.

RuntimeDeviceHandle conserva las referencias.

RuntimeHost recibe Handle completo.

Esto permite:

- agrupación;
- Device ID;
- Factory Key;
- rollback;
- provenance.

## 26. RuntimeHost behavior

Contrato conceptual:

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

RuntimeHost:

- valida Handle;
- adjunta objetos en orden;
- revierte attach parcial;
- separa en orden inverso;
- no libera BORROWED;
- no sustituye factory.release().

## 27. RuntimeFactoryBuildResult

Contiene:

```text
RuntimeDeviceHandle

ValidationReport
```

Success requiere:

- Handle no null;
- Report no null;
- Handle válido;
- Report válido para contexto.

No expone setters.

## 28. Construcción atómica

Éxito:

```text
Factory build

↓

Handle válido

↓

CompositionRuntime adquiere Handle
```

Fallo:

```text
Factory build

↓

limpieza local

↓

Handle null

↓

ValidationReport
```

No se conservan parciales vivos.

## 29. Rollback global

Si una construcción posterior falla:

```text
release Handles anteriores
en orden inverso.
```

Si attach falla:

```text
detach Handles adjuntos

↓

release Handles construidos
```

Si lifecycle falla:

```text
shutdown iniciados

↓

detach

↓

release
```

Last Known Good permanece hasta commit.

## 30. DeviceBus ownership

DeviceBus pertenece a CompositionRuntime o Composition Root.

RuntimeFactory no crea DeviceBus global.

RuntimeFactory no obtiene Bus desde autoload.

Factory build produce estado equivalente a:

```text
CREATED
```

DeviceBus se entrega durante initialize coordinado.

## 31. RuntimeFactoryRegistry futuro

Resolverá:

```text
RuntimeFactoryKey

→

RuntimeFactory
```

Contendrá comportamiento ejecutable.

Permanecerá separado de DeviceCatalog y CompositionPlan.

Su mutabilidad requiere diseño propio.

## 32. CompositionPlan futuro

CompositionPlan conservará:

- RuntimeFactoryKeys;
- dependency directives;
- lifecycle order;
- runtime policies;
- communication directives.

No conservará:

- RuntimeFactory;
- Callable;
- RuntimeDeviceHandle;
- Device activo;
- Node activo;
- DeviceBus activo.

## 33. Lifecycle order

CompositionPlan deberá describir:

- construction;
- attach;
- initialize;
- set_ready;
- start;
- shutdown;
- rollback.

No se asume topological sort completo.

DeviceGraph permite ciclos.

La política debe considerar:

- orden estable;
- strongly connected components;
- grupos;
- fases;
- temporal boundaries.

## 34. CompositionCompiler futuro

CompositionCompiler recibirá:

- DeviceGraphSnapshot;
- RuntimeFactoryRegistry;
- runtime policies;
- contexto.

Producirá CompositionPlan.

No:

- crea Devices;
- ejecuta factories;
- adjunta Nodes;
- posee DeviceBus;
- activa runtime.

## 35. CompositionRuntime futuro

CompositionRuntime recibirá:

- CompositionPlan;
- RuntimeFactoryRegistry;
- dependencies;
- RuntimeHost.

Poseerá:

- DeviceBus;
- RuntimeDeviceHandles;
- lifecycle;
- attach state;
- rollback;
- shutdown;
- Runtime Safety observation.

## 36. Persistencia futura

Persistencia permanece externa.

Componentes futuros:

```text
SystemProfileDocument

SystemProfileLoader

SystemProfileSerializer

DeviceCatalogDocument

DeviceCatalogLoader

DeviceCatalogSerializer

SaveAsService
```

Runtime objects no se serializan como parte de SystemProfile.

## 37. No service locator

Las dependencies llegan pre-resueltas.

Factory no puede buscar arbitrariamente:

- Nodes;
- Devices;
- servicios;
- filesystem;
- hardware;
- singletons.

RuntimeConstructionRequest contiene únicamente bindings declarados.

## 38. No host target inicial

`host_target` se descarta como dimensión inicial de RuntimeFactoryKey.

No existen contratos estables para:

- pure;
- mock;
- godot_node;
- hardware_bridge.

Si aparece una necesidad concreta, se diseñará explícitamente.

## 39. Baseline de SystemProfile

```text
Tests: 3
Checks: 142
Failures: 0
```

## 40. Baseline de DeviceCatalog

```text
Tests: 3
Checks: 89
Failures: 0
```

## 41. Baseline de DeviceGraphAssembler

```text
Tests: 2
Checks: 114
Failures: 0
```

## 42. Baseline global

```text
Tests: 48
Checks: 1396
Failures: 0
Timeout: 0
Engine Error: 0
Plan ExitCode: 0
RESULT: PASS
```

## 43. Baselines preservadas

No se modifican:

```text
DeviceLifecycleTest

DeviceCoreContractTest

DeviceManifestBuilderTest

DeviceGraphSnapshotTest

SystemProfileCompilerTest

DeviceCatalogCompilerTest

DeviceGraphAssemblerTest

SystemProfileCatalogGraphAssemblyIntegrationTest
```

Runtime Construction utiliza pruebas sucesoras.

## 44. Orden de implementación

```text
1. SystemProfile 1.0.
   COMPLETADO.

2. DeviceCatalog 1.0.
   COMPLETADO.

3. DeviceGraphAssembler 1.0.
   COMPLETADO.

4. ADR-010.
   ACEPTADO.

5. Runtime Construction Contract Design.
   ACTIVO.

6. RuntimeFactoryKey.
   SIGUIENTE.

7. RuntimeDependencyBinding.
   PENDIENTE.

8. RuntimeConstructionRequest.
   PENDIENTE.

9. RuntimeDeviceHandle.
   PENDIENTE.

10. RuntimeFactoryBuildResult.
	PENDIENTE.

11. Test RuntimeFactory.
	PENDIENTE.

12. Test RuntimeHost.
	PENDIENTE.

13. Runtime Construction Integration.
	PENDIENTE.

14. Run All.
	OBLIGATORIO.

15. RuntimeFactoryRegistry Design.
	POSTERIOR.

16. CompositionPlan Design.
	POSTERIOR.

17. CompositionCompiler.
	POSTERIOR A AMBOS DISEÑOS.

18. CompositionRuntime.
	FUTURO.
```

## 45. Criterios de aceptación del pipeline implementado

### SystemProfile

```text
IMPLEMENTADO Y VERIFICADO
```

### DeviceCatalog

```text
IMPLEMENTADO Y VERIFICADO
```

### DeviceGraphAssembler

```text
IMPLEMENTADO Y VERIFICADO
```

### Runtime Construction Contract

Pendiente de implementación.

Requiere:

- Key exacta;
- bindings con ownership;
- Request inmutable;
- Handle inmutable;
- Factory Build Result;
- Factory behavior;
- Host behavior;
- pruebas;
- integración;
- Run All.

## 46. Fuera de alcance actual

- RuntimeFactoryRegistry;
- CompositionPlan;
- CompositionCompiler;
- CompositionRuntime;
- factories de producción;
- RuntimeHost concreto;
- Hardware runtime;
- DeviceBus activation;
- lifecycle runtime;
- persistence;
- UI;
- GraphEditor;
- Temporal Boundary metadata;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation.

## 47. Invariantes

1. SystemProfile representa composición.

2. DeviceCatalog resuelve Profiles.

3. DeviceGraphAssembler construye topología.

4. DeviceGraphSnapshot no ejecuta.

5. RuntimeFactory construye solamente.

6. Factory recibe Request.

7. Dependencies llegan pre-resueltas.

8. Ownership es explícito.

9. Build es atómico.

10. Handle representa ownership.

11. RuntimeHost controla attach/detach.

12. DeviceBus pertenece a CompositionRuntime.

13. Plan guarda Factory Key.

14. Plan no guarda factory.

15. Registry permanece separado de Catalog.

16. Rollback es inverso.

17. Last Known Good solo cambia en commit.

18. Hardware requiere contratos adicionales.

## 48. Estado

```text
SYSTEMPROFILE 1.0
IMPLEMENTADO Y VERIFICADO

DEVICECATALOG 1.0
IMPLEMENTADO Y VERIFICADO

DEVICEGRAPHASSEMBLER 1.0
IMPLEMENTADO Y VERIFICADO

RUNTIME CONSTRUCTION CONTRACT 1.0
DISEÑO ACTIVO
```

Siguiente componente:

```text
RuntimeFactoryKey
```
