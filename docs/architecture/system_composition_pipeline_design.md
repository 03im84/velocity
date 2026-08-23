# System Composition Pipeline — Diseño

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.0 |
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

La primera implementación se limitará a:

- SystemConnectionSpec;
- SystemProfileDraft;
- SystemProfile;
- SystemProfileCompileResult;
- SystemProfileCompiler;
- contrato de DeviceProfileResolver;
- pruebas unitarias.

DeviceCatalog, Graph assembly y runtime se diseñarán e implementarán en milestones sucesivos.

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

## 3. Estructura propuesta

### 3.1 Código inicial

```text
core/composition/
├── system_connection_spec.gd
├── system_profile_draft.gd
├── system_profile.gd
├── system_profile_compile_result.gd
└── system_profile_compiler.gd
```

### 3.2 Pruebas iniciales

```text
test/core/composition/
├── SystemConnectionSpecTest.tscn
├── system_connection_spec_test.gd
├── SystemProfileDraftTest.tscn
├── system_profile_draft_test.gd
├── SystemProfileCompilerTest.tscn
└── system_profile_compiler_test.gd
```

### 3.3 Componentes futuros

```text
core/catalog/
├── device_catalog.gd
└── device_catalog_result.gd

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

Las rutas futuras son conceptuales y deberán confirmarse en sus diseños correspondientes.

## 4. Dependencias permitidas para la primera etapa

```text
DeviceProfile

DeviceConfiguration

ValidationIssue

ValidationReport
```

SystemProfileCompiler puede depender del contrato de comportamiento de DeviceProfileResolver.

## 5. Dependencias no permitidas para la primera etapa

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

SystemProfile representa definición de composición.

No representa topología construida ni ejecución.

## 6. Terminología

### SystemProfileDraft

Composición editable todavía no validada como snapshot.

### SystemProfileCompiler

Componente que valida Draft y produce SystemProfile.

### SystemProfile

Snapshot validado e inmutable de una composición.

### SystemConnectionSpec

Especificación persistible de una Connection antes de construir DeviceGraph.

### DeviceProfileResolver

Rol por comportamiento que resuelve DeviceProfile mediante ID y versión exacta.

### DeviceCatalog

Implementación futura de DeviceProfileResolver.

### DeviceGraphAssembler

Componente futuro que convierte SystemProfile en DeviceGraphSnapshot.

### CompositionCompiler

Componente futuro que convierte DeviceGraphSnapshot en CompositionPlan.

### CompositionPlan

Plan runtime validado e inmutable.

### CompositionRuntime

Componente que ejecuta CompositionPlan y posee recursos activos.

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

Se utilizarán los valores canónicos definidos por:

```gdscript
DeviceConfiguration.ActivationContext
```

Todas las DeviceConfigurations de la composición deben coincidir con el contexto de SystemProfile.

Mismatch:

```text
STRUCTURAL_ERROR

code:
system_profile_activation_context_mismatch
```

Un SystemProfile vacío conserva contexto explícito.

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

El caller entrega únicamente endpoints:

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

```text
Connection ID no vacío;

Source Device ID no vacío;

Source Port ID no vacío;

Target Device ID no vacío;

Target Port ID no vacío;

ningún componente contiene `|`;

Source Device y Target Device son diferentes;

Connection ID coincide con endpoints.
```

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

Los tipos de colección permanecen completos en una línea física durante implementación.

### 10.5 Draft vacío

Un Draft recién creado puede estar vacío.

Identidad y colecciones se validan durante compilación.

### 10.6 API mínima

```gdscript
has_valid_identity() -> bool
```

La primera versión permite editar campos directamente, igual que los Drafts existentes.

No añade operaciones complejas antes de existir una necesidad de herramienta.

### 10.7 Identity validation

`has_valid_identity()` comprueba únicamente:

```text
System Profile ID no vacío;

versión positiva;

Display Name no vacío;

Activation Context válido.
```

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

No se crea una clase base universal.

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

### 11.5 Implementaciones de prueba

Los tests utilizarán un resolver local controlado.

No se añadirá DeviceCatalog de producción durante la primera etapa.

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

```text
Profile no null;

Report no null;

Report válido para Activation Context;

Profile identity válida.
```

Para SIMULATION:

```gdscript
report.is_valid_for_simulation()
```

Para HARDWARE:

```gdscript
report.is_valid_for_hardware()
```

La primera implementación no activa Hardware.

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

### 14.4 API conceptual

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

## 15. Validación de Draft

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

Si resolver afirma que existe pero devuelve null o Profile inválido:

```text
STRUCTURAL_ERROR

code:
system_profile_dependency_invalid
```

### 16.7 Dependency identity mismatch

Si el Profile devuelto no coincide exactamente con ID y versión solicitados:

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

Código:

```text
system_connection_spec_invalid
```

DeviceGraph conserva validación defensiva adicional.

### 17.7 Ports

SystemProfileCompiler no valida existencia de Ports.

Eso pertenece a DeviceGraphAssembler.

## 18. Draft transaccional

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

## 21. DeviceCatalog futuro

### 21.1 Responsabilidad

> Resolver DeviceProfile snapshots mediante ID y versión exacta.

### 21.2 API mínima prevista

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

```gdscript
get_profiles() -> Array[DeviceProfile]
```

### 21.3 No responsabilidades

DeviceCatalog no:

- conoce runtime factories;
- crea Devices;
- construye Graph;
- guarda SystemProfile;
- ejecuta CompositionPlan;
- activa hardware.

### 21.4 Persistencia

Catalog persistence tendrá loader separado.

No se implementa durante SystemProfile 1.0.

## 22. DeviceGraphAssembler futuro

### 22.1 Responsabilidad

> Construir DeviceGraphSnapshot desde SystemProfile.

### 22.2 Flujo

```text
SystemProfile
		│
		▼
Resolver exacto
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

- Profile disponible;
- Manifest válido;
- Port existente;
- Topic compatible;
- Semantic Kind;
- fan-in;
- ciclos;
- TopicChannels;
- Snapshot.

### 22.4 No responsabilidades

No crea Devices runtime.

No conoce factories.

No guarda archivos.

## 23. RuntimeFactoryRegistry futuro

RuntimeFactoryRegistry es independiente de DeviceCatalog.

Responsabilidad:

> Resolver factories ejecutables para un CompositionPlan.

No constituye autoridad canónica de DeviceProfile.

La identidad exacta de factory se definirá en diseño posterior.

## 24. CompositionPlan futuro

CompositionPlan será snapshot inmutable.

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

Posee:

- DeviceBus;
- Devices activos;
- suscripciones;
- lifecycle;
- shutdown;
- Runtime Safety observation.

No recibe Drafts ni documentos persistentes.

## 27. Persistencia futura

SystemProfileSerializer convierte entre:

```text
SystemProfile

y

SystemProfileDocument
```

No forma parte del Core lógico inicial.

El formato definitivo se decidirá después de estabilizar SystemProfile.

## 28. Estrategia de pruebas inicial

Se crearán pruebas independientes.

### SystemConnectionSpecTest

Verifica:

- ID determinista;
- getters;
- separador reservado;
- campos obligatorios;
- self-connection;
- ausencia de setters.

### SystemProfileDraftTest

Verifica:

- estado inicial;
- identidad inválida inicial;
- identidad válida;
- campos editables;
- colecciones editables;
- contexto Simulation;
- contexto Hardware;
- contexto inválido.

### SystemProfileCompilerTest

Verifica:

- Draft null;
- resolver null;
- resolver incompleto;
- identidad inválida;
- contexto inválido;
- Configuration null;
- Configuration inválida;
- Device ID duplicado;
- context mismatch;
- dependencia faltante;
- dependencia inválida;
- dependency identity mismatch;
- Connection Spec null;
- Connection Spec inválida;
- Connection duplicada;
- Source desconocido;
- Target desconocido;
- Draft vacío válido;
- compilación válida;
- orden conservado;
- Arrays independientes;
- Draft posterior no modifica Snapshot;
- Result sin setters.

## 29. Fixtures de prueba

Los tests utilizarán namespace:

```text
test.
```

Ejemplos:

```text
test.system_profile

test.sensor

test.controller
```

Resolver de prueba:

- registra DeviceProfiles en memoria;
- resuelve ID y versión exactos;
- no utiliza filesystem;
- no es implementación de producción.

## 30. Baselines existentes

Las siguientes baselines no se modifican:

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
```

System Composition utiliza pruebas sucesoras nuevas.

## 31. Orden de implementación inicial

```text
1. Aceptar este diseño.

2. Crear core/composition/.

3. Implementar SystemConnectionSpec.

4. Ejecutar SystemConnectionSpecTest.

5. Implementar SystemProfileDraft.

6. Ejecutar SystemProfileDraftTest.

7. Implementar SystemProfile.

8. Implementar SystemProfileCompileResult.

9. Implementar SystemProfileCompiler.

10. Crear resolver de prueba.

11. Ejecutar SystemProfileCompilerTest.

12. Ejecutar Run All.

13. Registrar baseline.

14. Actualizar Core Architecture.

15. Cerrar SystemProfile 1.0.

16. Diseñar DeviceCatalog.
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

## 33. Fuera de alcance inicial

SystemProfile 1.0 no implementará:

- DeviceCatalog de producción;
- persistencia;
- `.tres`;
- JSON;
- SaveAsService;
- DeviceGraphAssembler;
- RuntimeFactoryRegistry;
- CompositionCompiler;
- CompositionPlan;
- CompositionRuntime;
- GraphEditor;
- ConfigurationEditor;
- GraphLayout;
- Hardware Mode activo;
- migration;
- bundle;
- remote profiles;
- hot reload.

## 34. Resumen de responsabilidades

```text
SystemConnectionSpec:
endpoints persistibles.

SystemProfileDraft:
composición editable.

DeviceProfileResolver:
resolución exacta por comportamiento.

SystemProfileCompiler:
validación y compilación.

SystemProfile:
composición validada e inmutable.

DeviceCatalog:
resolver de producción futuro.

DeviceGraphAssembler:
construcción de topología futura.

CompositionCompiler:
compilación runtime futura.

CompositionPlan:
plan inmutable futuro.

CompositionRuntime:
ejecución futura.

Serializer:
persistencia externa futura.
```

## 35. Estado

DISEÑO ACTIVO

SystemProfile 1.0 está autorizado
para implementación incremental.

Primer componente:

SystemConnectionSpec

Los componentes posteriores permanecen
sujetos al orden de implementación
y a sus pruebas sucesoras.
