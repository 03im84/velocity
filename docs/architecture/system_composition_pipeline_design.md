# System Composition Pipeline — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.5 |
| Fecha | 04/09/2026 |
| ADR relacionados | ADR-009 — System Composition Pipeline; ADR-010 — Runtime Construction and Factory Binding |
| Alcance | Definición, resolución, Graph assembly, construcción runtime, compilación y activación |

## 1. Propósito

Este documento describe el pipeline completo de composición de Velocity.

Define la relación entre:

- SystemProfile;
- DeviceCatalog;
- DeviceGraphAssembler;
- DeviceGraphSnapshot;
- Runtime Construction Contract;
- RuntimeFactoryRegistry;
- CompositionPlan;
- CompositionCompiler;
- CompositionRuntime;
- persistencia externa.

Estado implementado:

```text
SystemProfile 1.0

DeviceCatalog 1.0

DeviceGraphAssembler 1.0

Runtime Construction Contract 1.0
```

Siguiente etapa arquitectónica:

```text
RuntimeFactoryRegistry

+

CompositionPlan
```

Ambos deben diseñarse antes de CompositionCompiler.

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

### Implementado y verificado

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

```text
RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult

RuntimeFactory behavior

RuntimeHost behavior
```

### Pendiente de diseño

```text
RuntimeFactoryRegistry

CompositionPlan
```

### Posterior

```text
CompositionCompiler

CompositionRuntime
```

## 4. Estructura implementada

### SystemProfile

```text
core/composition/
├── system_connection_spec.gd
├── system_profile_draft.gd
├── system_profile.gd
├── system_profile_compile_result.gd
└── system_profile_compiler.gd
```

### DeviceCatalog

```text
core/catalog/
├── device_catalog_draft.gd
├── device_catalog.gd
├── device_catalog_compile_result.gd
└── device_catalog_compiler.gd
```

### DeviceGraphAssembler

```text
core/composition/
├── device_graph_assembly_result.gd
└── device_graph_assembler.gd
```

### Runtime Construction

```text
core/runtime/
├── runtime_factory_key.gd
├── runtime_dependency_binding.gd
├── runtime_construction_request.gd
├── runtime_device_handle.gd
└── runtime_factory_build_result.gd
```

## 5. Dependencias permitidas

El pipeline lógico puede depender de:

```text
DeviceProfile

DeviceConfiguration

DeviceManifest

DeviceGraphNode

DeviceGraphSnapshot

RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

ValidationIssue

ValidationReport

Object
```

## 6. Dependencias prohibidas

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

Los contratos base no conocen el host.

## 7. SystemProfile

Pipeline:

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
- Display Name;
- descripción;
- Activation Context;
- DeviceConfiguration snapshots;
- SystemConnectionSpecs.

SystemProfile utiliza referencias exactas:

```text
Profile ID

+

Profile Version
```

No depende de DeviceGraph, filesystem o runtime.

## 8. DeviceProfileResolver

Contrato:

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

## 9. DeviceCatalog

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
- satisface DeviceProfileResolver;
- no contiene factories;
- no abre archivos.

## 10. DeviceGraphAssembler

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
DeviceGraphSnapshot
```

DeviceGraphAssembler:

- es stateless;
- soporta Simulation;
- rechaza Hardware;
- procesa Devices antes de Connections;
- agrega errores por etapas;
- no devuelve Graph parcial;
- conserva orden;
- no modifica entradas;
- no crea runtime.

## 11. DeviceGraphSnapshot

Representa topología lógica validada e inmutable.

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

## 12. Runtime Construction Contract

Objetivo:

> Construir una unidad runtime de manera atómica con ownership y cleanup explícitos.

Componentes:

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

## 13. RuntimeFactoryKey

Identidad:

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

No existe:

- latest;
- fallback;
- sustitución de versión;
- sustitución de contexto.

CompositionPlan conservará Key.

No conservará factory.

## 14. RuntimeDependencyBinding

Estado:

```text
Dependency ID

Dependency Value

Ownership
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

BORROWED conserva owner original.

TRANSFERRED cambia ownership durante build.

## 15. RuntimeConstructionRequest

Contiene:

- Device ID;
- DeviceConfiguration;
- RuntimeFactoryKey;
- RuntimeDependencyBindings pre-resueltos.

No es service locator.

No descubre dependencias.

No contiene SceneTree, autoload o filesystem.

Crear Request no transfiere ownership.

Invocar factory build inicia transacción.

## 16. RuntimeDeviceHandle

Contiene:

- Device ID;
- Configuration;
- Factory Key;
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

Handle representa ownership de una unidad runtime.

No coordina el sistema completo.

## 17. RuntimeFactoryBuildResult

Contiene:

```text
RuntimeDeviceHandle

ValidationReport
```

Success requiere:

- Handle no null;
- Report no null;
- Handle válido;
- Report válido para Activation Context.

No ejecuta cleanup.

## 18. RuntimeFactory behavior

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

Factory:

- construye solamente;
- no inicializa;
- no inicia;
- no adjunta;
- no crea DeviceBus global;
- limpia parciales;
- libera su producto cuando Runtime coordina.

## 19. RuntimeHost behavior

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

- recibe Handle completo;
- procesa Host Objects;
- evita attach duplicado;
- tolera detach repetido;
- revierte attach parcial;
- no sustituye factory release.

## 20. Construcción atómica

Éxito:

```text
RuntimeConstructionRequest

↓

RuntimeFactory.build()

↓

RuntimeFactoryBuildResult

↓

RuntimeDeviceHandle válido
```

Fallo:

```text
Factory limpia recursos creados

↓

Factory limpia TRANSFERRED

↓

Factory preserva BORROWED

↓

Handle null

↓

ValidationReport
```

## 21. Rollback global

Si falla una construcción posterior:

```text
release Handles anteriores
en orden inverso
```

Si falla attach:

```text
detach

↓

release
```

Si falla lifecycle:

```text
shutdown

↓

detach

↓

release
```

Last Known Good cambia solo después de commit completo.

## 22. DeviceBus ownership

DeviceBus pertenece a CompositionRuntime.

Factory no crea Bus global.

Factory no utiliza autoload.

Factory produce estado equivalente a:

```text
CREATED
```

DeviceBus se entrega durante initialize coordinado.

## 23. RuntimeFactoryRegistry siguiente

Responsabilidad prevista:

> Resolver RuntimeFactory mediante RuntimeFactoryKey exacta.

Mapa conceptual:

```text
RuntimeFactoryKey

→

RuntimeFactory
```

Debe validar behavior:

```text
build

release
```

Permanecerá separado de:

- DeviceCatalog;
- CompositionPlan.

La mutabilidad debe decidirse antes de implementación.

## 24. CompositionPlan siguiente

Responsabilidad prevista:

> Representar instrucciones runtime inmutables y no ejecutables.

Conservará:

- RuntimeFactoryKeys;
- dependency directives;
- lifecycle order;
- communication directives;
- runtime policies.

No conservará:

- RuntimeFactory;
- Callable;
- RuntimeDeviceHandle;
- Device activo;
- Node activo;
- DeviceBus activo.

## 25. Lifecycle order pendiente

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

La política debe evaluar:

- orden estable;
- strongly connected components;
- grupos;
- fases;
- temporal boundaries.

## 26. CompositionCompiler futuro

Recibirá:

- DeviceGraphSnapshot;
- RuntimeFactoryRegistry;
- Activation Context;
- runtime policies.

Producirá CompositionPlan.

No:

- ejecuta factories;
- crea Devices;
- adjunta Host Objects;
- posee DeviceBus;
- activa runtime.

## 27. CompositionRuntime futuro

Recibirá:

- CompositionPlan;
- RuntimeFactoryRegistry;
- dependencies;
- RuntimeHost.

Poseerá:

- DeviceBus;
- RuntimeDeviceHandles;
- host attachment;
- lifecycle;
- rollback;
- shutdown;
- Runtime Safety observation.

## 28. Persistencia futura

Persistencia permanece externa.

```text
SystemProfileDocument

SystemProfileLoader

SystemProfileSerializer

DeviceCatalogDocument

DeviceCatalogLoader

DeviceCatalogSerializer

SaveAsService
```

Runtime Objects no forman parte de SystemProfile persistente.

## 29. No service locator

Dependencies llegan pre-resueltas.

Factory no busca:

- Nodes;
- Devices;
- servicios;
- filesystem;
- hardware;
- singletons.

RuntimeConstructionRequest contiene únicamente bindings declarados.

## 30. Baseline SystemProfile

```text
Tests: 3
Checks: 142
Failures: 0
```

## 31. Baseline DeviceCatalog

```text
Tests: 3
Checks: 89
Failures: 0
```

## 32. Baseline DeviceGraphAssembler

```text
Tests: 2
Checks: 114
Failures: 0
```

## 33. Baseline Runtime Construction

```text
Tests: 6
Checks: 173
Failures: 0
```

## 34. Baseline global

Confirmada mediante Dashboard 0.4.0:

```text
Tests: 54
Checks: 1569
Failures: 0
Timeout: 0
Engine Error: 0
Missing Metrics: 0
Plan ExitCode: 0
RESULT: PASS
```

## 35. Baselines preservadas

No se modificaron:

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

## 36. Herramienta autoritativa

Velocity Test Dashboard:

```text
0.4.0
```

Runner Metrics Protocol:

```text
1
```

La baseline global ahora agrega checks automáticamente.

## 37. Orden de implementación

```text
1. SystemProfile 1.0.
   COMPLETADO.

2. DeviceCatalog 1.0.
   COMPLETADO.

3. DeviceGraphAssembler 1.0.
   COMPLETADO.

4. ADR-010.
   ACEPTADO.

5. Runtime Construction Design.
   ACTIVO.

6. RuntimeFactoryKey.
   COMPLETADO.

7. RuntimeDependencyBinding.
   COMPLETADO.

8. RuntimeConstructionRequest.
   COMPLETADO.

9. RuntimeDeviceHandle.
   COMPLETADO.

10. RuntimeFactoryBuildResult.
	COMPLETADO.

11. Test RuntimeFactory.
	COMPLETADO.

12. Test RuntimeHost.
	COMPLETADO.

13. Runtime Construction Integration.
	PASS — 41 checks.

14. Run All.
	PASS — 54 tests, 1569 checks.

15. Registrar baseline.
	COMPLETADO.

16. Cerrar Runtime Construction.
	EN PROCESO DOCUMENTAL.

17. Diseñar RuntimeFactoryRegistry.
	SIGUIENTE.

18. Diseñar CompositionPlan.
	SIGUIENTE.

19. CompositionCompiler.
	POSTERIOR.

20. CompositionRuntime.
	FUTURO.
```

## 38. Criterios del pipeline implementado

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

```text
IMPLEMENTADO Y VERIFICADO
```

Cumple:

- Factory Key exacta;
- ownership explícito;
- dependencies pre-resueltas;
- Request inmutable;
- Handle inmutable;
- Build Result defensivo;
- factory construct-only;
- factory release;
- RuntimeHost behavior;
- atomic build;
- partial rollback;
- reverse rollback;
- no service locator;
- no DeviceBus global;
- pruebas PASS;
- integración PASS;
- Run All PASS.

## 39. Componentes futuros

```text
RuntimeFactoryRegistry

CompositionPlan

CompositionCompiler

CompositionRuntime

RuntimeHost concreto

Factories de producción

Persistence adapters

Hardware runtime
```

## 40. Fuera de alcance actual

- Registry implementation;
- Plan implementation;
- CompositionCompiler;
- CompositionRuntime;
- factories concretas;
- RuntimeHost concreto;
- Device creation real;
- DeviceBus activation;
- lifecycle real;
- persistence;
- UI;
- Hardware Mode;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation.

## 41. Invariantes

1. SystemProfile representa composición.

2. DeviceCatalog resuelve Profiles.

3. DeviceGraphAssembler construye topología.

4. DeviceGraphSnapshot no ejecuta.

5. RuntimeFactory construye solamente.

6. Factory recibe Request pre-resuelto.

7. Ownership es explícito.

8. Build es atómico.

9. Handle representa ownership.

10. RuntimeHost controla attach/detach.

11. DeviceBus pertenece a CompositionRuntime.

12. Plan guardará Key, no factory.

13. Registry permanecerá separado de Catalog.

14. Rollback global será inverso.

15. Last Known Good cambia solo en commit.

16. Hardware requiere contratos adicionales.

## 42. Commits relevantes

Runtime Construction:

```text
4147ec4
feat(runtime):
add runtime construction contracts
```

Dashboard 0.4.0:

```text
db330c2
feat(tools):
add test metrics and automatic suites
```

## 43. Estado

```text
SYSTEMPROFILE 1.0
IMPLEMENTADO Y VERIFICADO

DEVICECATALOG 1.0
IMPLEMENTADO Y VERIFICADO

DEVICEGRAPHASSEMBLER 1.0
IMPLEMENTADO Y VERIFICADO

RUNTIME CONSTRUCTION CONTRACT 1.0
IMPLEMENTADO Y VERIFICADO

VELOCITY TEST DASHBOARD 0.4.0
IMPLEMENTADO Y VERIFICADO
```

Siguiente milestone arquitectónico:

```text
RuntimeFactoryRegistry

+

CompositionPlan
```

Ambos se diseñarán antes de CompositionCompiler.
