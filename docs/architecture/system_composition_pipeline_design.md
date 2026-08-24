# System Composition Pipeline — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.3 |
| Fecha | 23/08/2026 |
| ADR relacionado | ADR-009 — System Composition Pipeline |
| Alcance | Definición, resolución, Graph assembly, compilación y runtime |

## 1. Propósito

Este documento traduce ADR-009 a un diseño concreto e implementable.

Define la relación entre:

- SystemProfileDraft;
- SystemProfileCompiler;
- SystemProfile;
- DeviceProfileResolver;
- DeviceCatalog;
- DeviceGraphAssembler;
- RuntimeFactoryRegistry;
- CompositionCompiler;
- CompositionPlan;
- CompositionRuntime;
- persistencia externa.

SystemProfile 1.0 implementa y verifica:

- SystemConnectionSpec;
- SystemProfileDraft;
- SystemProfile;
- SystemProfileCompileResult;
- SystemProfileCompiler;
- contrato de DeviceProfileResolver;
- resolver controlado de pruebas;
- pruebas unitarias;
- regresión completa.

DeviceCatalog 1.0 implementa y verifica:

- DeviceCatalogDraft;
- DeviceCatalog;
- DeviceCatalogCompileResult;
- DeviceCatalogCompiler;
- resolución exacta;
- múltiples versiones;
- integración con SystemProfileCompiler.

DeviceGraphAssembler 1.0 implementa y verifica:

- DeviceGraphAssemblyResult;
- DeviceGraphAssembler;
- resolución exacta desde SystemProfile;
- construcción de DeviceManifest;
- construcción de DeviceGraphNode;
- Connections desde SystemConnectionSpec;
- DeviceGraphSnapshot;
- agregación de Reports por etapas;
- integración completa.

Siguiente etapa:

```text
RuntimeFactoryRegistry

+

CompositionPlan
```

Estos contratos deben definirse antes de implementar CompositionCompiler.

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
```

Dependencias laterales:

```text
DeviceProfileResolver
		│
		├──► SystemProfileCompiler
		└──► DeviceGraphAssembler

RuntimeFactoryRegistry
		│
		└──► CompositionCompiler
```

Persistencia:

```text
SystemProfileSerializer
		│
		├── load
		└── save
```

## 3. Estructura implementada

### 3.1 SystemProfile

```text
core/composition/
├── system_connection_spec.gd
├── system_profile_draft.gd
├── system_profile.gd
├── system_profile_compile_result.gd
└── system_profile_compiler.gd
```

### 3.2 DeviceCatalog

```text
core/catalog/
├── device_catalog_draft.gd
├── device_catalog.gd
├── device_catalog_compile_result.gd
└── device_catalog_compiler.gd
```

### 3.3 DeviceGraphAssembler

```text
core/composition/
├── device_graph_assembly_result.gd
└── device_graph_assembler.gd
```

### 3.4 Pruebas de SystemProfile

```text
test/core/composition/
├── SystemConnectionSpecTest.tscn
├── system_connection_spec_test.gd
├── SystemProfileDraftTest.tscn
├── system_profile_draft_test.gd
├── SystemProfileCompilerTest.tscn
├── system_profile_compiler_test.gd
└── system_profile_test_resolver.gd
```

### 3.5 Pruebas de DeviceCatalog

```text
test/core/catalog/
├── DeviceCatalogDraftTest.tscn
├── device_catalog_draft_test.gd
├── DeviceCatalogCompilerTest.tscn
├── device_catalog_compiler_test.gd
├── SystemProfileDeviceCatalogIntegrationTest.tscn
└── system_profile_device_catalog_integration_test.gd
```

### 3.6 Pruebas de DeviceGraphAssembler

```text
test/core/composition/
├── DeviceGraphAssemblerTest.tscn
├── device_graph_assembler_test.gd
├── SystemProfileCatalogGraphAssemblyIntegrationTest.tscn
└── system_profile_catalog_graph_assembly_integration_test.gd
```

### 3.7 Componentes futuros

```text
core/composition/
├── runtime_factory_registry.gd
├── composition_plan.gd
├── composition_compile_result.gd
├── composition_compiler.gd
├── composition_runtime.gd
└── composition_activation_result.gd
```

Las rutas futuras deberán confirmarse en sus diseños correspondientes.

## 4. Dependencias permitidas

El pipeline lógico implementado puede depender de:

```text
DeviceProfile

DeviceConfiguration

DeviceManifest

DeviceGraphNode

DeviceGraphDraft

DeviceGraphSnapshot

ValidationIssue

ValidationReport
```

SystemProfileCompiler y DeviceGraphAssembler dependen del comportamiento de DeviceProfileResolver.

DeviceCatalog satisface ese contrato.

## 5. Dependencias no permitidas

SystemProfile, DeviceCatalog y DeviceGraphAssembler no dependen de:

```text
DeviceBus runtime

Device runtime

RuntimeFactoryRegistry

CompositionRuntime

SceneTree

GraphEditor

filesystem

Resource persistence

JSON

hardware adapters

telemetría
```

El pipeline implementado representa definición, resolución y topología.

No representa ejecución.

## 6. Terminología

### SystemConnectionSpec

Especificación persistible de endpoints antes de construir DeviceGraph.

### SystemProfileDraft

Composición editable todavía no validada como snapshot.

### SystemProfileCompiler

Componente que valida Draft y produce SystemProfile.

### SystemProfile

Snapshot validado e inmutable de una composición.

### DeviceProfileResolver

Rol por comportamiento que resuelve DeviceProfile mediante ID y versión exactos.

### DeviceCatalogDraft

Colección editable de DeviceProfile snapshots.

### DeviceCatalogCompiler

Componente que valida Draft y produce DeviceCatalog.

### DeviceCatalog

Snapshot inmutable que implementa DeviceProfileResolver.

### DeviceGraphAssemblyResult

Resultado transaccional de Graph assembly.

### DeviceGraphAssembler

Componente que convierte SystemProfile en DeviceGraphSnapshot.

### RuntimeFactoryRegistry

Componente futuro que resolverá factories ejecutables.

### CompositionCompiler

Componente futuro que convertirá DeviceGraphSnapshot en CompositionPlan.

### CompositionPlan

Plan runtime validado e inmutable.

### CompositionRuntime

Componente futuro que ejecutará CompositionPlan y poseerá recursos activos.

## 7. Identidad de SystemProfile

SystemProfile utiliza:

```text
System Profile ID

System Profile Version
```

Tipos:

```gdscript
system_profile_id: StringName

system_profile_version: int
```

Reglas:

```text
ID no vacío;

versión mayor que cero.
```

System Profile ID no depende de:

- nombre de archivo;
- ruta;
- Display Name;
- SceneTree;
- instance ID de Godot.

## 8. Activation Context

SystemProfile declara un Activation Context explícito.

Valores iniciales:

```text
SIMULATION

HARDWARE
```

Se utilizan los valores canónicos de:

```gdscript
DeviceConfiguration.ActivationContext
```

Todas las DeviceConfigurations deben coincidir con el contexto de SystemProfile.

Mismatch:

```text
STRUCTURAL_ERROR

code:
system_profile_activation_context_mismatch
```

DeviceGraphAssembler 1.0 soporta solamente Simulation.

Hardware assembly produce:

```text
HARDWARE_SAFETY_ERROR

code:
device_graph_assembly_hardware_not_supported
```

Hardware Mode activo permanece fuera de alcance.

## 9. SystemConnectionSpec

### 9.1 Responsabilidad

> Representar endpoints persistibles de una Connection antes de construir DeviceGraph.

### 9.2 Estado

```gdscript
var _connection_id: StringName

var _source_device_id: String

var _source_port_id: StringName

var _target_device_id: String

var _target_port_id: StringName
```

### 9.3 Construcción

```gdscript
SystemConnectionSpec.new(
	source_device_id,
	source_port_id,
	target_device_id,
	target_port_id
)
```

Connection ID se genera de forma determinista.

### 9.4 Formato

```text
source_device_id
|
source_port_id
|
target_device_id
|
target_port_id
```

### 9.5 No responsabilidades

SystemConnectionSpec no contiene:

- Topic;
- Semantic Kind;
- DeviceGraphNode;
- DeviceGraphConnection;
- DeviceBus;
- Callable;
- runtime factory;
- posición visual.

## 10. SystemProfileDraft

Responsabilidad:

> Representar una composición editable que todavía no puede utilizarse por Graph assembly o runtime.

Estado:

```gdscript
var system_profile_id: StringName = &""

var system_profile_version: int = 1

var display_name: String = ""

var description: String = ""

var activation_context: int = (
	DeviceConfiguration.ActivationContext.SIMULATION
)

var device_configurations: Array[DeviceConfiguration] = []

var connection_specs: Array[SystemConnectionSpec] = []
```

Draft puede estar:

- vacío;
- incompleto;
- con null;
- con dependencias faltantes;
- con Specs inválidas.

SystemProfileCompiler establece la frontera de validez.

## 11. DeviceProfileResolver

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

Reglas:

- coincidencia exacta;
- sin latest;
- sin fallback;
- sin sustitución;
- resolución estable durante operación.

DeviceCatalog implementa este contrato.

## 12. SystemProfile

Responsabilidad:

> Representar una composición validada e inmutable mediante referencias versionadas.

SystemProfile contiene:

- identidad;
- versión;
- Display Name;
- descripción;
- Activation Context;
- DeviceConfiguration snapshots;
- SystemConnectionSpecs.

SystemProfile no contiene:

- DeviceProfile completo;
- DeviceGraph;
- DeviceBus;
- runtime factory;
- filesystem;
- UI.

Los Arrays se copian.

Los getters devuelven copias.

No expone setters ni ejecución.

## 13. SystemProfileCompileResult

Contiene:

```text
SystemProfile

ValidationReport
```

Success requiere:

- Profile no null;
- Report no null;
- identity válida;
- Report válido para Activation Context.

No expone setters.

## 14. SystemProfileCompiler

Responsabilidad:

> Validar SystemProfileDraft y producir SystemProfile.

Valida:

- Draft;
- resolver;
- identidad;
- contexto;
- Configurations;
- Device IDs;
- dependencias;
- Connection Specs;
- endpoints conocidos.

No valida:

- existencia de Ports;
- Topic;
- Semantic Kind;
- fan-in;
- ciclos;
- Graph Snapshot.

Estas responsabilidades pertenecen a DeviceGraphAssembler y DeviceGraph.

## 15. Códigos de SystemProfile

```text
system_profile_draft_missing

device_profile_resolver_missing

device_profile_resolver_contract_invalid

system_profile_id_missing

system_profile_version_invalid

system_profile_display_name_missing

system_profile_activation_context_invalid

system_profile_configuration_missing

system_profile_configuration_invalid

duplicate_system_device_id

system_profile_activation_context_mismatch

system_profile_dependency_missing

system_profile_dependency_invalid

system_profile_dependency_identity_mismatch

system_connection_spec_missing

system_connection_spec_invalid

duplicate_system_connection

system_connection_source_device_not_found

system_connection_target_device_not_found
```

## 16. SystemProfile transaccional

SystemProfileCompiler produce un snapshot nuevo.

Draft permanece editable.

Cambiar Draft no modifica SystemProfile.

Compilación fallida no produce Profile.

SystemProfile vacío es válido.

## 17. DeviceCatalog

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

Propiedades:

- Draft editable;
- Catalog inmutable;
- resolución exacta;
- múltiples versiones;
- duplicado exacto bloqueante;
- orden preservado;
- Arrays independientes;
- sin latest;
- sin overwrite;
- sin factories;
- sin filesystem.

DeviceCatalog no tiene ID ni versión propios.

La identidad pertenece a DeviceProfile.

## 18. Códigos de DeviceCatalog

```text
device_catalog_draft_missing

device_catalog_profile_missing

device_catalog_profile_invalid

duplicate_device_profile_identity

device_catalog_snapshot_invalid
```

## 19. DeviceCatalog transaccional

Compilación fallida:

- no modifica Draft;
- no produce Catalog;
- no sobrescribe referencia anterior.

Draft posterior no modifica Catalog.

Catalog vacío es válido.

## 20. DeviceGraphAssemblyResult

Contiene:

```text
DeviceGraphSnapshot

ValidationReport
```

Success requiere:

- Snapshot no null;
- Report no null;
- Report válido para Simulation;
- Snapshot válido.

No expone setters.

## 21. DeviceGraphAssembler

Responsabilidad:

> Construir DeviceGraphSnapshot desde SystemProfile y DeviceProfileResolver.

API:

```gdscript
assemble(
	system_profile: SystemProfile,
	profile_resolver: Object
) -> DeviceGraphAssemblyResult
```

Assembler es stateless.

No conserva última operación.

## 22. Pipeline interno de Graph assembly

```text
SystemProfile
		│
		▼
DeviceConfigurations
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
DeviceGraphDraft.add_device()
		│
		▼
SystemConnectionSpecs
		│
		▼
DeviceGraphDraft.connect_ports()
		│
		▼
DeviceGraphDraft.create_snapshot()
		│
		▼
DeviceGraphSnapshot
```

## 23. Etapas de Graph assembly

```text
1. Devices

2. Connections

3. Snapshot
```

Errores se agregan dentro de etapa.

Una etapa fallida bloquea la siguiente.

No se devuelve Graph parcial.

## 24. Device stage

Por cada Configuration:

1. Configuration no null;

2. Configuration válida;

3. Context coincide;

4. Profile exacto disponible;

5. Profile válido;

6. Profile identity coincide;

7. Manifest válido;

8. Graph Node válido;

9. add Device exitoso.

El orden de Nodes sigue Configurations.

## 25. Connection stage

Por cada Spec:

1. Spec no null;

2. Spec identity válida;

3. connect_ports();

4. merge OperationResult Report;

5. verificar Connection ID.

El orden de Connections sigue Specs.

DeviceGraphDraft permanece autoridad de validación local.

## 26. Snapshot stage

```gdscript
DeviceGraphDraft.create_snapshot()
```

DeviceGraphValidator permanece autoridad de validación global.

Ciclos producen:

```text
SIMULATION_HAZARD

graph_cycle_requires_temporal_analysis
```

Simulation puede producir Snapshot.

Hardware queda bloqueado.

SystemProfile vacío produce Snapshot vacío.

## 27. Agregación de Reports

Fuentes:

```text
Assembler validation

DeviceManifestBuilder

DeviceGraphNodeBuilder

DeviceGraphDraft.add_device()

DeviceGraphDraft.connect_ports()

DeviceGraphDraft.create_snapshot()
```

Merge conserva:

- código;
- severity;
- message;
- related object;
- related field;
- orden.

Report fuente no se modifica.

Report null produce:

```text
PLATFORM_SAFETY_ERROR

device_graph_assembly_report_missing
```

## 28. Códigos de DeviceGraphAssembler

```text
device_graph_assembly_system_profile_missing

device_graph_assembly_system_profile_invalid

device_graph_assembly_activation_context_invalid

device_graph_assembly_hardware_not_supported

device_graph_assembly_configuration_missing

device_graph_assembly_configuration_invalid

device_graph_assembly_configuration_context_mismatch

device_graph_assembly_dependency_missing

device_graph_assembly_dependency_invalid

device_graph_assembly_dependency_identity_mismatch

device_graph_assembly_manifest_missing

device_graph_assembly_node_missing

device_graph_assembly_add_device_failed

device_graph_assembly_connection_spec_missing

device_graph_assembly_connection_spec_invalid

device_graph_assembly_connect_failed

device_graph_assembly_connection_id_mismatch

device_graph_assembly_snapshot_missing

device_graph_assembly_report_missing
```

También conserva códigos delegados de Builders y DeviceGraph.

## 29. No mutación

DeviceGraphAssembler no modifica:

- SystemProfile;
- DeviceConfigurations;
- Connection Specs;
- DeviceProfiles;
- DeviceCatalog;
- Reports fuente.

No expone DeviceGraphDraft temporal.

No devuelve Snapshot parcial.

## 30. No runtime

El pipeline implementado no:

- crea Devices runtime;
- posee DeviceBus;
- registra suscripciones;
- controla Lifecycle;
- resuelve factories;
- produce CompositionPlan;
- ejecuta;
- abre archivos.

## 31. Baselines de SystemProfile

SystemConnectionSpecTest:

```text
Checks: 23
Failures: 0
RESULT: PASS
```

SystemProfileDraftTest:

```text
Checks: 32
Failures: 0
RESULT: PASS
```

SystemProfileCompilerTest:

```text
Checks: 87
Failures: 0
RESULT: PASS
```

SystemProfile 1.0:

```text
Tests: 3
Checks: 142
Failures: 0
```

## 32. Baselines de DeviceCatalog

DeviceCatalogDraftTest:

```text
Checks: 14
Failures: 0
RESULT: PASS
```

DeviceCatalogCompilerTest:

```text
Checks: 53
Failures: 0
RESULT: PASS
```

SystemProfileDeviceCatalogIntegrationTest:

```text
Checks: 22
Failures: 0
RESULT: PASS
```

DeviceCatalog 1.0:

```text
Tests: 3
Checks: 89
Failures: 0
```

## 33. Baselines de DeviceGraphAssembler

DeviceGraphAssemblerTest:

```text
Checks: 87
Failures: 0
RESULT: PASS
```

SystemProfileCatalogGraphAssemblyIntegrationTest:

```text
Checks: 27
Failures: 0
RESULT: PASS
```

DeviceGraphAssembler 1.0:

```text
Tests: 2
Checks: 114
Failures: 0
```

## 34. Regresión completa

```text
Tests: 48
Checks: 1396
Failures: 0
Timeout: 0
Engine Error: 0
Plan ExitCode: 0
RESULT: PASS
```

## 35. Baselines preservadas

No se modificaron:

```text
DeviceProfileCompilerTest

DeviceConfigurationCompilerTest

DeviceManifestBuilderTest

DeviceGraphNodeBuilderTest

DeviceGraphConnectionTest

DeviceGraphValidationTest

DeviceGraphSnapshotTest

SystemProfileCompilerTest

DeviceCatalogCompilerTest

SystemProfileDeviceCatalogIntegrationTest
```

Cada etapa utiliza pruebas sucesoras.

## 36. Orden de implementación

```text
1. Aceptar ADR-009.
   COMPLETADO.

2. Implementar SystemProfile 1.0.
   COMPLETADO.

3. Ejecutar pruebas de SystemProfile.
   PASS — 3 tests, 142 checks.

4. Implementar DeviceCatalog 1.0.
   COMPLETADO.

5. Integrar Catalog con SystemProfile.
   PASS — 22 checks.

6. Ejecutar pruebas de DeviceCatalog.
   PASS — 3 tests, 89 checks.

7. Implementar DeviceGraphAssemblyResult.
   COMPLETADO.

8. Implementar DeviceGraphAssembler.
   COMPLETADO.

9. Ejecutar DeviceGraphAssemblerTest.
   PASS — 87 checks.

10. Ejecutar integración completa.
	PASS — 27 checks.

11. Ejecutar Run All.
	PASS — 48 tests, 1396 checks.

12. Registrar baseline.
	COMPLETADO.

13. Cerrar DeviceGraphAssembler 1.0.
	EN PROCESO DOCUMENTAL.

14. Diseñar RuntimeFactoryRegistry.
	SIGUIENTE.

15. Diseñar CompositionPlan.
	SIGUIENTE.

16. Implementar CompositionCompiler.
	POSTERIOR A AMBOS DISEÑOS.
```

## 37. Criterios de aceptación de SystemProfile

```text
SYSTEMPROFILE 1.0
IMPLEMENTADO Y VERIFICADO
```

Cumple:

- Draft editable;
- Snapshot inmutable;
- contexto explícito;
- referencias exactas;
- resolver por comportamiento;
- dependencia faltante bloqueante;
- Specs deterministas;
- no Graph prematuro;
- no filesystem;
- no runtime.

## 38. Criterios de aceptación de DeviceCatalog

```text
DEVICECATALOG 1.0
IMPLEMENTADO Y VERIFICADO
```

Cumple:

- Draft editable;
- Catalog inmutable;
- múltiples versiones;
- duplicado exacto bloqueante;
- resolución exacta;
- sin latest;
- sin overwrite;
- sin factories;
- sin filesystem;
- integración por comportamiento.

## 39. Criterios de aceptación de DeviceGraphAssembler

```text
DEVICEGRAPHASSEMBLER 1.0
IMPLEMENTADO Y VERIFICADO
```

Cumple:

- SystemProfile como entrada;
- resolver por comportamiento;
- Simulation soportada;
- Hardware rechazado;
- etapas ordenadas;
- Reports agregados;
- Builders reutilizados;
- Graph Draft reutilizado;
- Snapshot transaccional;
- ciclos preservados;
- no mutación;
- no Graph parcial;
- no runtime;
- prueba unitaria PASS;
- integración PASS;
- Run All PASS.

## 40. Componentes futuros

### RuntimeFactoryRegistry

Resolverá factories ejecutables.

Permanecerá separado de DeviceCatalog.

### CompositionPlan

Representará instrucciones runtime inmutables.

No ejecutará.

### CompositionCompiler

Convertirá DeviceGraphSnapshot en CompositionPlan.

No creará Devices.

### CompositionRuntime

Ejecutará CompositionPlan.

Poseerá DeviceBus y Devices activos.

## 41. Persistencia futura

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

Persistencia permanece externa al Core lógico.

## 42. Fuera de alcance actual

- RuntimeFactoryRegistry;
- CompositionPlan;
- CompositionCompiler;
- CompositionRuntime;
- Hardware assembly;
- Hardware Mode activo;
- Device creation;
- DeviceBus ownership runtime;
- lifecycle runtime;
- persistencia;
- UI;
- GraphEditor;
- ConfigurationEditor;
- GraphLayout;
- Temporal Boundary metadata;
- zero-delay classification final;
- named slots;
- configurable cardinality;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation.

## 43. Invariantes

1. SystemProfileDraft es editable.

2. SystemProfile es inmutable.

3. DeviceCatalog es inmutable.

4. Resolución es exacta.

5. DeviceGraphAssembler es stateless.

6. Devices se procesan antes de Connections.

7. Etapa fallida bloquea la siguiente.

8. No se devuelve Graph parcial.

9. Reports fuente no se modifican.

10. Orden se conserva.

11. DeviceGraphDraft valida Connections.

12. DeviceGraphValidator valida topología global.

13. Simulation es contexto soportado.

14. Hardware assembly está bloqueado.

15. RuntimeFactoryRegistry permanece separado.

16. CompositionCompiler no ejecutará.

17. CompositionRuntime poseerá recursos activos.

## 44. Estado

```text
SYSTEMPROFILE 1.0
IMPLEMENTADO Y VERIFICADO

DEVICECATALOG 1.0
IMPLEMENTADO Y VERIFICADO

DEVICEGRAPHASSEMBLER 1.0
IMPLEMENTADO Y VERIFICADO
```

Baselines acumuladas:

```text
SystemProfile:
3 tests
142 checks

DeviceCatalog:
3 tests
89 checks

DeviceGraphAssembler:
2 tests
114 checks
```

Regresión completa:

```text
48 tests
1396 checks
0 failures
```

Siguiente milestone arquitectónico:

```text
RuntimeFactoryRegistry

+

CompositionPlan
```

Ambos deben diseñarse antes de implementar CompositionCompiler.