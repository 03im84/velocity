# System Composition Pipeline — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.2 |
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

Siguiente etapa:

```text
DeviceGraphAssembler
```

Persistencia, CompositionCompiler y runtime permanecen en milestones posteriores.

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

## 3. Estructura

### 3.1 Código implementado de SystemProfile

```text
core/composition/
├── system_connection_spec.gd
├── system_profile_draft.gd
├── system_profile.gd
├── system_profile_compile_result.gd
└── system_profile_compiler.gd
```

### 3.2 Código implementado de DeviceCatalog

```text
core/catalog/
├── device_catalog_draft.gd
├── device_catalog.gd
├── device_catalog_compile_result.gd
└── device_catalog_compiler.gd
```

### 3.3 Pruebas implementadas

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

```text
test/core/catalog/
├── DeviceCatalogDraftTest.tscn
├── device_catalog_draft_test.gd
├── DeviceCatalogCompilerTest.tscn
├── device_catalog_compiler_test.gd
├── SystemProfileDeviceCatalogIntegrationTest.tscn
└── system_profile_device_catalog_integration_test.gd
```

### 3.4 Componentes futuros

```text
core/composition/
├── device_graph_assembler.gd
├── device_graph_assembly_result.gd
├── runtime_factory_registry.gd
├── composition_plan.gd
├── composition_compile_result.gd
├── composition_compiler.gd
├── composition_runtime.gd
└── composition_activation_result.gd
```

Las rutas futuras deberán confirmarse en sus diseños correspondientes.

## 4. Dependencias permitidas

SystemProfile y DeviceCatalog pueden depender de:

```text
DeviceProfile

DeviceConfiguration

ValidationIssue

ValidationReport
```

SystemProfileCompiler depende del comportamiento de DeviceProfileResolver.

DeviceCatalog satisface ese contrato.

## 5. Dependencias no permitidas

SystemProfile y DeviceCatalog no dependen de:

```text
DeviceBus runtime

DeviceGraphDraft

DeviceGraphSnapshot

SceneTree

GraphEditor

filesystem

Resource persistence

JSON

hardware

telemetría

runtime factories
```

SystemProfile representa composición.

DeviceCatalog representa resolución.

Ninguno representa topología construida ni ejecución.

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

### DeviceGraphAssembler

Componente futuro que convierte SystemProfile en DeviceGraphSnapshot.

### CompositionCompiler

Componente futuro que convierte DeviceGraphSnapshot en CompositionPlan.

### CompositionPlan

Plan runtime validado e inmutable.

### CompositionRuntime

Componente futuro que ejecuta CompositionPlan y posee recursos activos.

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

Un SystemProfile vacío conserva contexto explícito.

Hardware Mode permanece fuera del alcance de la implementación runtime actual.

Un SystemProfile con contexto Hardware puede representarse y validarse como definición, pero no activarse.

## 9. SystemConnectionSpec

### 9.1 Archivo

```text
core/composition/system_connection_spec.gd
```

### 9.2 Forma

```gdscript
extends RefCounted
class_name SystemConnectionSpec
```

### 9.3 Responsabilidad

> Representar endpoints persistibles de una Connection antes de construir DeviceGraph.

### 9.4 Estado

```gdscript
var _connection_id: StringName

var _source_device_id: String

var _source_port_id: StringName

var _target_device_id: String

var _target_port_id: StringName
```

### 9.5 Construcción

El caller entrega endpoints:

```gdscript
SystemConnectionSpec.new(
	source_device_id,
	source_port_id,
	target_device_id,
	target_port_id
)
```

La clase genera Connection ID determinista.

El caller no entrega Connection ID.

### 9.6 Connection ID

Separador reservado:

```text
|
```

Formato:

```text
source_device_id
|
source_port_id
|
target_device_id
|
target_port_id
```

Ejemplo:

```text
distance_sensor|out.distance_measurement|hover_mcu|in.distance_measurement
```

### 9.7 API

```gdscript
get_connection_id() -> StringName

get_source_device_id() -> String

get_source_port_id() -> StringName

get_target_device_id() -> String

get_target_port_id() -> StringName

is_valid_identity() -> bool
```

### 9.8 Validación de identidad

Debe cumplirse:

- Connection ID no vacío;
- Source Device ID no vacío;
- Source Port ID no vacío;
- Target Device ID no vacío;
- Target Port ID no vacío;
- ningún componente contiene `|`;
- Source y Target son diferentes;
- ID coincide con endpoints.

### 9.9 No responsabilidades

SystemConnectionSpec no contiene:

- Topic;
- Semantic Kind;
- DeviceGraphNode;
- DeviceGraphConnection;
- DeviceBus;
- Callable;
- runtime factory;
- posición visual.

Topic y Semantic Kind se derivan posteriormente.

### 9.10 Inmutabilidad

No expone setters.

## 10. SystemProfileDraft

### 10.1 Archivo

```text
core/composition/system_profile_draft.gd
```

### 10.2 Forma

```gdscript
extends RefCounted
class_name SystemProfileDraft
```

### 10.3 Responsabilidad

> Representar una composición editable que todavía no puede utilizarse por Graph assembly o runtime.

### 10.4 Estado editable

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

### 10.5 Draft vacío

Un Draft recién creado puede estar vacío.

Identidad y colecciones se validan durante compilación.

### 10.6 API mínima

```gdscript
has_valid_identity() -> bool
```

La primera versión permite editar campos directamente.

No añade operaciones complejas sin una necesidad concreta de herramienta.

### 10.7 Identity validation

`has_valid_identity()` comprueba únicamente:

- System Profile ID no vacío;
- versión positiva;
- Display Name no vacío;
- Activation Context válido.

No valida:

- DeviceConfigurations;
- dependencias;
- Connection Specs;
- Graph;
- runtime.

### 10.8 No responsabilidades

SystemProfileDraft no:

- compila DeviceConfigurationDraft;
- resuelve DeviceProfile;
- construye Manifest;
- construye DeviceGraph;
- abre archivos;
- guarda archivos;
- crea runtime.

## 11. DeviceProfileResolver

### 11.1 Naturaleza

DeviceProfileResolver es un rol por comportamiento.

No existe clase base universal.

### 11.2 Contrato

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

### 11.3 Reglas

El resolver:

- utiliza coincidencia exacta;
- no selecciona latest;
- no sustituye versiones;
- devuelve null cuando no existe;
- produce resolución estable durante una compilación.

### 11.4 Validación de contrato

SystemProfileCompiler comprueba que el objeto recibido:

- no sea null;
- tenga `has_profile`;
- tenga `get_profile`.

Resolver incompleto:

```text
STRUCTURAL_ERROR

code:
device_profile_resolver_contract_invalid
```

### 11.5 Implementaciones

Durante la primera etapa se utilizó un resolver controlado de prueba.

DeviceCatalog 1.0 implementa el contrato para producción lógica.

## 12. SystemProfile

### 12.1 Archivo

```text
core/composition/system_profile.gd
```

### 12.2 Forma

```gdscript
extends RefCounted
class_name SystemProfile
```

### 12.3 Responsabilidad

> Representar una composición validada e inmutable mediante referencias versionadas.

### 12.4 Estado

```gdscript
var _system_profile_id: StringName

var _system_profile_version: int

var _display_name: String

var _description: String

var _activation_context: int

var _device_configurations: Array[DeviceConfiguration]

var _connection_specs: Array[SystemConnectionSpec]
```

### 12.5 Construcción

Todos los campos se reciben durante `_init()`.

Los Arrays se duplican.

DeviceConfiguration y SystemConnectionSpec son snapshots inmutables por contrato y pueden compartirse por referencia.

### 12.6 API

```gdscript
get_system_profile_id() -> StringName

get_system_profile_version() -> int

get_display_name() -> String

get_description() -> String

get_activation_context() -> int

get_device_configurations() -> Array[DeviceConfiguration]

get_connection_specs() -> Array[SystemConnectionSpec]

get_device_configuration(
	device_id: String
) -> DeviceConfiguration

get_connection_spec(
	connection_id: StringName
) -> SystemConnectionSpec

is_valid_identity() -> bool
```

### 12.7 Colecciones

Los getters devuelven Arrays nuevos.

No se exponen colecciones internas mutables.

### 12.8 Inmutabilidad

SystemProfile no expone:

- setters;
- add;
- remove;
- connect;
- disconnect;
- compile;
- save;
- load;
- execute;
- activate.

### 12.9 Significado de validez

SystemProfile validado significa:

- identidad válida;
- contexto válido;
- Configurations válidas;
- dependencias exactas verificadas;
- Device IDs únicos;
- Connection Specs estructuralmente válidas;
- endpoints referencian Devices conocidos.

No significa todavía:

- Ports existentes;
- Topics compatibles;
- Graph válido;
- CompositionPlan válido;
- runtime activable.

## 13. SystemProfileCompileResult

### 13.1 Archivo

```text
core/composition/system_profile_compile_result.gd
```

### 13.2 Forma

```gdscript
extends RefCounted
class_name SystemProfileCompileResult
```

### 13.3 Estado

```gdscript
var _profile: SystemProfile

var _report: ValidationReport
```

### 13.4 API

```gdscript
get_profile() -> SystemProfile

get_report() -> ValidationReport

is_success() -> bool
```

### 13.5 Success

`is_success()` requiere:

- Profile no null;
- Report no null;
- Report válido para Activation Context;
- Profile identity válida.

Para SIMULATION:

```gdscript
report.is_valid_for_simulation()
```

Para HARDWARE:

```gdscript
report.is_valid_for_hardware()
```

La implementación no activa Hardware.

Solo valida el contexto declarado.

### 13.6 Inmutabilidad

No expone setters.

## 14. SystemProfileCompiler

### 14.1 Archivo

```text
core/composition/system_profile_compiler.gd
```

### 14.2 Forma

```gdscript
extends RefCounted
class_name SystemProfileCompiler
```

### 14.3 Responsabilidad

> Validar SystemProfileDraft y producir SystemProfile snapshot.

### 14.4 API

```gdscript
compile(
	draft: SystemProfileDraft,
	profile_resolver: Object
) -> SystemProfileCompileResult
```

### 14.5 No mutación

Compiler no modifica:

- Draft;
- DeviceConfigurations;
- Connection Specs;
- DeviceProfiles;
- resolver.

### 14.6 Orden de validación

```text
1. Draft no null.

2. Resolver no null.

3. Resolver contract.

4. Draft identity.

5. Activation Context.

6. DeviceConfigurations.

7. Device IDs.

8. Profile references.

9. Resolver dependencies.

10. Connection Specs.

11. Connection endpoints.

12. Crear Snapshot.
```

El orden de Issues es determinista.

### 14.7 No responsabilidades

SystemProfileCompiler no:

- construye DeviceGraphNode;
- construye DeviceManifest;
- valida Topics de Ports;
- detecta ciclos;
- crea DeviceGraphSnapshot;
- crea Devices runtime;
- guarda archivos.

## 15. Validación de SystemProfileDraft

### 15.1 Draft null

```text
STRUCTURAL_ERROR

code:
system_profile_draft_missing
```

### 15.2 Resolver null

```text
STRUCTURAL_ERROR

code:
device_profile_resolver_missing
```

### 15.3 Resolver incompleto

```text
STRUCTURAL_ERROR

code:
device_profile_resolver_contract_invalid
```

### 15.4 System Profile ID vacío

```text
STRUCTURAL_ERROR

code:
system_profile_id_missing
```

### 15.5 Versión inválida

```text
STRUCTURAL_ERROR

code:
system_profile_version_invalid
```

### 15.6 Display Name vacío

```text
STRUCTURAL_ERROR

code:
system_profile_display_name_missing
```

### 15.7 Activation Context inválido

```text
STRUCTURAL_ERROR

code:
system_profile_activation_context_invalid
```

## 16. Validación de DeviceConfigurations

### 16.1 Configuration null

```text
STRUCTURAL_ERROR

code:
system_profile_configuration_missing
```

### 16.2 Configuration inválida

```text
STRUCTURAL_ERROR

code:
system_profile_configuration_invalid
```

### 16.3 Device ID duplicado

```text
STRUCTURAL_ERROR

code:
duplicate_system_device_id
```

### 16.4 Context mismatch

```text
STRUCTURAL_ERROR

code:
system_profile_activation_context_mismatch
```

### 16.5 Dependencia faltante

```text
STRUCTURAL_ERROR

code:
system_profile_dependency_missing
```

### 16.6 Dependency result inválido

```text
STRUCTURAL_ERROR

code:
system_profile_dependency_invalid
```

### 16.7 Dependency identity mismatch

```text
STRUCTURAL_ERROR

code:
system_profile_dependency_identity_mismatch
```

## 17. Validación de Connection Specs

### 17.1 Spec null

```text
STRUCTURAL_ERROR

code:
system_connection_spec_missing
```

### 17.2 Identidad inválida

```text
STRUCTURAL_ERROR

code:
system_connection_spec_invalid
```

### 17.3 Connection duplicada

```text
STRUCTURAL_ERROR

code:
duplicate_system_connection
```

### 17.4 Source Device desconocido

```text
STRUCTURAL_ERROR

code:
system_connection_source_device_not_found
```

### 17.5 Target Device desconocido

```text
STRUCTURAL_ERROR

code:
system_connection_target_device_not_found
```

### 17.6 Self Connection

SystemConnectionSpec rechaza Source y Target iguales.

DeviceGraph conserva validación defensiva adicional.

### 17.7 Ports

SystemProfileCompiler no valida existencia de Ports.

Eso pertenece a DeviceGraphAssembler.

## 18. Transaccionalidad de SystemProfile

SystemProfileCompiler produce un snapshot nuevo.

Draft permanece editable después de compilar.

Cambiar Draft no modifica SystemProfile.

Una compilación fallida no modifica un SystemProfile anterior.

## 19. Orden determinista

SystemProfile conserva:

- orden de DeviceConfigurations;
- orden de Connection Specs.

No se ordenan alfabéticamente durante compilación.

La serialización futura conservará orden explícito.

## 20. SystemProfile vacío

Un Draft vacío puede compilar cuando:

- identidad es válida;
- contexto es válido;
- resolver cumple contrato;
- no existen Connection Specs.

Resultado:

```text
SystemProfile no null;

Configurations vacías;

Connections vacías;

Report válido.
```

CompositionCompiler podrá rechazar posteriormente un plan sin Devices.

## 21. DeviceCatalog

### 21.1 Estado

```text
DEVICECATALOG 1.0
IMPLEMENTADO Y VERIFICADO
```

### 21.2 Pipeline

```text
DeviceCatalogDraft
		│
		▼
DeviceCatalogCompiler
		│
		▼
DeviceCatalog
```

### 21.3 Responsabilidad

> Resolver DeviceProfile snapshots mediante ID y versión exacta.

### 21.4 Componentes

```text
core/catalog/
├── device_catalog_draft.gd
├── device_catalog.gd
├── device_catalog_compile_result.gd
└── device_catalog_compiler.gd
```

### 21.5 Propiedades verificadas

- DeviceCatalogDraft editable;
- DeviceCatalog inmutable;
- resolución exacta;
- múltiples versiones por Profile ID;
- duplicado exacto bloqueante;
- orden preservado;
- Arrays independientes;
- Draft posterior independiente;
- sin latest fallback;
- sin overwrite;
- sin factories;
- sin filesystem.

### 21.6 Resolver API

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

### 21.7 Identidad

DeviceCatalog no tiene ID ni versión propios.

La identidad pertenece a cada DeviceProfile.

### 21.8 Índice

```text
Profile ID
	│
	└── Profile Version
			│
			└── DeviceProfile
```

### 21.9 Integración con SystemProfileCompiler

SystemProfileCompiler recibe DeviceCatalog como `Object`.

Solo utiliza:

```gdscript
has_profile()

get_profile()
```

No depende de la clase concreta.

### 21.10 Baseline

```text
Tests: 3
Checks: 89
Failures: 0
```

Persistencia de catálogo permanece futura.

## 22. DeviceGraphAssembler futuro

### 22.1 Responsabilidad

> Construir DeviceGraphSnapshot desde SystemProfile y DeviceProfileResolver.

### 22.2 Flujo

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
```

### 22.3 Validaciones

Graph assembly validará:

- SystemProfile no null;
- Profile disponible;
- Profile identity exacta;
- Manifest válido;
- Graph Node válido;
- Port existente;
- Topic compatible;
- Semantic Kind;
- fan-in;
- ciclos;
- TopicChannels;
- Snapshot.

### 22.4 No responsabilidades

DeviceGraphAssembler no:

- crea Devices runtime;
- conoce factories;
- guarda archivos;
- modifica SystemProfile;
- modifica DeviceProfiles;
- ejecuta CompositionPlan.

## 23. RuntimeFactoryRegistry futuro

RuntimeFactoryRegistry es independiente de DeviceCatalog.

Responsabilidad:

> Resolver factories ejecutables para un CompositionPlan.

```text
DeviceCatalog:
qué definición lógica existe.

RuntimeFactoryRegistry:
cómo construir su implementación runtime.
```

La identidad exacta de factory se definirá en diseño posterior.

## 24. CompositionPlan futuro

CompositionPlan será un snapshot inmutable.

Podrá contener:

- Device creation entries;
- factory bindings;
- Configurations;
- suscripciones;
- orden de initialize;
- orden de start;
- orden de shutdown;
- Dispatch Policy;
- supervisión requerida.

No ejecuta.

## 25. CompositionCompiler futuro

Responsabilidad:

> Convertir DeviceGraphSnapshot en CompositionPlan.

No:

- crea Devices;
- ejecuta;
- abre archivos;
- posee DeviceBus;
- modifica Graph.

## 26. CompositionRuntime futuro

Responsabilidad:

> Ejecutar CompositionPlan.

Poseerá:

- DeviceBus;
- Devices activos;
- suscripciones;
- lifecycle;
- shutdown;
- Runtime Safety observation.

No recibirá Drafts ni documentos persistentes.

## 27. Persistencia futura

SystemProfileSerializer convertirá entre:

```text
SystemProfile

y

SystemProfileDocument
```

DeviceCatalogLoader convertirá documentos de DeviceProfile en DeviceCatalogDraft.

Persistencia no forma parte del Core lógico implementado.

El formato definitivo se decidirá después de estabilizar el pipeline lógico.

## 28. Estrategia de pruebas

### 28.1 SystemProfile

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

### 28.2 DeviceCatalog

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

### 28.3 Regresión completa

```text
Tests: 46
Checks: 1282
Failures: 0
Timeout: 0
Engine Error: 0
Plan ExitCode: 0
RESULT: PASS
```

## 29. Fixtures

Los tests utilizan namespace:

```text
test.
```

Ejemplos:

```text
test.system_profile

test.sensor

test.controller
```

Los resolvers de prueba:

- no utilizan filesystem;
- resuelven ID y versión exactos;
- no representan producción.

DeviceCatalog sustituye el resolver de prueba únicamente en la integración sucesora.

## 30. Baselines preservadas

No se modificaron:

```text
DeviceProfileDraftTest

DeviceProfileCompilerTest

DeviceConfigurationDraftTest

DeviceConfigurationCompilerTest

DeviceManifestBuilderTest

DeviceGraphNodeBuilderTest

DeviceGraphConnectionTest

DeviceGraphValidationTest

DeviceGraphSnapshotTest

SystemProfileCompilerTest
```

System Composition utiliza pruebas sucesoras nuevas.

## 31. Orden de implementación

```text
1. Aceptar ADR-009.
   COMPLETADO.

2. Crear System Composition Pipeline Design.
   COMPLETADO.

3. Implementar SystemConnectionSpec.
   COMPLETADO.

4. Implementar SystemProfileDraft.
   COMPLETADO.

5. Implementar SystemProfile.
   COMPLETADO.

6. Implementar SystemProfileCompileResult.
   COMPLETADO.

7. Implementar SystemProfileCompiler.
   COMPLETADO.

8. Crear resolver de prueba.
   COMPLETADO.

9. Ejecutar pruebas de SystemProfile.
   PASS — 3 tests, 142 checks.

10. Ejecutar Run All para SystemProfile.
	PASS — 43 tests, 1193 checks.

11. Registrar SystemProfile baseline.
	COMPLETADO.

12. Cerrar SystemProfile 1.0.
	COMPLETADO.

13. Diseñar DeviceCatalog.
	COMPLETADO.

14. Implementar DeviceCatalogDraft.
	COMPLETADO.

15. Implementar DeviceCatalog.
	COMPLETADO.

16. Implementar DeviceCatalogCompileResult.
	COMPLETADO.

17. Implementar DeviceCatalogCompiler.
	COMPLETADO.

18. Ejecutar pruebas unitarias de Catalog.
	PASS — 2 tests, 67 checks.

19. Integrar DeviceCatalog con
	SystemProfileCompiler.
	PASS — 22 checks.

20. Ejecutar Run All para DeviceCatalog.
	PASS — 46 tests, 1282 checks.

21. Registrar DeviceCatalog baseline.
	EN PROCESO DOCUMENTAL.

22. Cerrar DeviceCatalog 1.0.
	EN PROCESO DOCUMENTAL.

23. Diseñar DeviceGraphAssembler.
	SIGUIENTE.
```

## 32. Criterios de aceptación de SystemProfile 1.0

1. SystemConnectionSpec es inmutable.

2. Connection ID es determinista.

3. Separador `|` está reservado.

4. SystemProfileDraft es editable.

5. SystemProfile es inmutable.

6. SystemProfile copia Arrays.

7. Getters devuelven copias.

8. DeviceConfigurations son snapshots.

9. Activation Context es explícito.

10. Context mismatch se rechaza.

11. Device IDs duplicados se rechazan.

12. Resolver utiliza contrato por comportamiento.

13. Dependencias utilizan ID y versión exactos.

14. No existe fallback latest.

15. Dependencia faltante se rechaza.

16. Dependencia inválida se rechaza.

17. Connection Specs duplicadas se rechazan.

18. Endpoints desconocidos se rechazan.

19. Ports no se validan prematuramente.

20. Draft vacío puede compilar.

21. Compilación fallida no modifica Draft.

22. Draft posterior no modifica Snapshot.

23. SystemProfile no depende de filesystem.

24. SystemProfile no depende de DeviceGraph.

25. SystemProfile no ejecuta.

26. Pruebas sucesoras terminan PASS.

27. Run All termina PASS.

Estado:

```text
SYSTEMPROFILE 1.0
IMPLEMENTADO Y VERIFICADO
```

## 33. Criterios de aceptación de DeviceCatalog 1.0

1. DeviceCatalogDraft es editable.

2. DeviceCatalog es inmutable.

3. Catalog vacío es válido.

4. Profile null se rechaza.

5. Profile inválido se rechaza.

6. Duplicado exacto se rechaza.

7. Múltiples versiones se permiten.

8. Orden se conserva.

9. `get_profiles()` devuelve copia.

10. Resolución es exacta.

11. No existe latest fallback.

12. No existe overwrite.

13. Catalog satisface DeviceProfileResolver.

14. Catalog no conoce factories.

15. Catalog no conoce filesystem.

16. Compiler no modifica Draft.

17. Draft posterior no modifica Catalog.

18. Result es defensivo.

19. Pruebas unitarias terminan PASS.

20. Integración con SystemProfileCompiler termina PASS.

21. Run All termina PASS.

Estado:

```text
DEVICECATALOG 1.0
IMPLEMENTADO Y VERIFICADO
```

## 34. Fuera de alcance actual

El pipeline actual no implementa:

- DeviceGraphAssembler;
- DeviceGraphAssemblyResult;
- RuntimeFactoryRegistry;
- CompositionCompiler;
- CompositionPlan;
- CompositionRuntime;
- GraphEditor;
- ConfigurationEditor;
- GraphLayout;
- formato persistente definitivo;
- SaveAsService;
- bundle portable;
- migración automática;
- descarga remota de Profiles;
- Hardware Mode activo;
- factories de hardware;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation;
- hot reload;
- red;
- telemetría;
- UI.

## 35. Estado

```text
SYSTEMPROFILE 1.0
IMPLEMENTADO Y VERIFICADO

DEVICECATALOG 1.0
IMPLEMENTADO Y VERIFICADO
```

Baselines acumuladas de Composition:

```text
SystemProfile:
3 tests
142 checks

DeviceCatalog:
3 tests
89 checks
```

Regresión completa:

```text
46 tests
1282 checks
0 failures
```

Siguiente milestone:

```text
DEVICEGRAPHASSEMBLER
```

DeviceGraphAssembler requerirá un diseño propio antes de implementar código.