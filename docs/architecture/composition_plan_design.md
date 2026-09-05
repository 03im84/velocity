# CompositionPlan — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 04/09/2026 |
| ADR relacionados | ADR-009 — System Composition Pipeline; ADR-010 — Runtime Construction and Factory Binding |
| Alcance | Directivas runtime inmutables, orden por fases, comunicación y Runtime Safety |

## 1. Propósito

CompositionPlan representa instrucciones runtime validadas, inmutables y no ejecutables.

Responsabilidad:

> Describir qué debe construir y coordinar CompositionRuntime sin contener recursos activos.

CompositionPlan es la frontera entre:

```text
CompositionCompiler

y

CompositionRuntime
```

## 2. Entrada futura

CompositionCompiler producirá CompositionPlan desde:

```text
DeviceGraphSnapshot

RuntimeFactoryRegistry

DeviceBusDispatchPolicy

Activation Context
```

CompositionPlan no se construye desde SystemProfileDraft.

No interpreta archivos.

## 3. Salida

CompositionPlan contiene:

- CompositionDeviceEntries;
- CompositionConnectionDirectives;
- Activation Context;
- DeviceBusDispatchPolicy;
- orden derivado por fases.

No ejecuta.

## 4. Pipeline

```text
DeviceGraphSnapshot
		│
		├── DeviceGraphNodes
		└── DeviceGraphConnections
				│
				▼
RuntimeFactoryRegistry
		│
		└── RuntimeFactoryDescriptors
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

## 5. Identidad del Plan

CompositionPlan 1.0 no tiene:

- Plan ID;
- Plan Version;
- filename;
- UUID;
- content hash.

CompositionPlan es un snapshot anónimo de compilación.

Provenance futura puede conservarse en CompositionCompileResult.

No se inventa identidad antes de necesitar persistencia o comparación entre Plans.

## 6. Plan vacío

CompositionPlan vacío es estructuralmente válido cuando:

- Activation Context es válido;
- DeviceBusDispatchPolicy es válida;
- Device Entries están vacías;
- Connection Directives están vacías.

Representa un no-op.

Una capa de deployment puede rechazarlo por utilidad.

El Core no lo rechaza por seguridad.

## 7. Activation Context

CompositionPlan declara:

```text
SIMULATION

o

HARDWARE
```

Todas las CompositionDeviceEntries deben utilizar el mismo contexto.

CompositionPlan 1.0 puede representar ambos contextos.

CompositionCompiler y CompositionRuntime aplicarán políticas adicionales.

Hardware activo permanece futuro.

## 8. DeviceBusDispatchPolicy

CompositionPlan requiere una política explícita:

```text
DeviceBusDispatchPolicy
```

No es opcional.

No depende de defaults globales.

Razones:

- reproducibilidad;
- VP-002;
- budgets explícitos;
- misma política entre compile y runtime;
- auditoría;
- tests deterministas.

La política debe ser válida.

## 9. Estructura propuesta

### Código

```text
core/composition/
├── composition_device_entry.gd
├── composition_connection_directive.gd
└── composition_plan.gd
```

### Pruebas

```text
test/core/composition/
├── CompositionDeviceEntryTest.tscn
├── composition_device_entry_test.gd
├── CompositionConnectionDirectiveTest.tscn
├── composition_connection_directive_test.gd
├── CompositionPlanTest.tscn
└── composition_plan_test.gd
```

### Integración futura

```text
CompositionPlanRuntimeFactoryRegistryIntegrationTest
```

## 10. Dependencias permitidas

```text
DeviceConfiguration

DeviceBusDispatchPolicy

RuntimeFactoryKey

RuntimeDependencySpec

ValidationIssue

ValidationReport
```

CompositionConnectionDirective utiliza IDs y Topic.

No necesita DeviceGraphConnection como estado interno.

## 11. Dependencias prohibidas

```text
RuntimeFactory Object

Callable

RuntimeDeviceHandle

RuntimeConstructionRequest

RuntimeDependencyBinding con Value activo

Device activo

Node activo

DeviceBus activo

CompositionRuntime

SceneTree

filesystem

JSON

GraphEditor
```

## 12. CompositionDeviceEntry

### Archivo

```text
core/composition/composition_device_entry.gd
```

### Forma

```gdscript
extends RefCounted
class_name CompositionDeviceEntry
```

### Responsabilidad

> Describir la construcción declarativa de un Device runtime.

### Estado

```gdscript
var _device_id: String

var _configuration: DeviceConfiguration

var _factory_key: RuntimeFactoryKey

var _dependency_specs: Array[RuntimeDependencySpec]
```

### Construcción

```gdscript
CompositionDeviceEntry.new(
	device_id,
	configuration,
	factory_key,
	dependency_specs
)
```

El Array se copia.

### API

```gdscript
get_device_id() -> String

get_configuration() -> DeviceConfiguration

get_factory_key() -> RuntimeFactoryKey

get_dependency_specs() -> Array[RuntimeDependencySpec]

get_dependency_spec(
	dependency_id: StringName
) -> RuntimeDependencySpec

has_dependency(
	dependency_id: StringName
) -> bool

is_valid() -> bool
```

## 13. Device Entry validation

Debe comprobar:

- Device ID no vacío;
- Configuration no null;
- Configuration válida;
- Factory Key no null;
- Factory Key válida;
- Configuration Device ID coincide;
- Configuration Profile ID coincide con Key;
- Configuration Profile Version coincide con Key;
- Configuration Activation Context coincide con Key;
- Dependency Spec no null;
- Dependency Spec válida;
- Dependency IDs únicas.

## 14. Device Entry no contiene runtime activo

CompositionDeviceEntry no contiene:

- RuntimeFactory;
- RuntimeDependencyBinding;
- Dependency Value;
- RuntimeDeviceHandle;
- Primary Runtime Object;
- Host Objects;
- DeviceBus.

RuntimeDependencySpecs describen requisitos.

CompositionRuntime resuelve Values posteriormente.

## 15. Device Entry inmutable

No expone setters.

Getters de Dependency Specs devuelven Arrays nuevos.

DeviceConfiguration, Factory Key y Specs son snapshots inmutables por contrato.

## 16. CompositionConnectionDirective

### Archivo

```text
core/composition/composition_connection_directive.gd
```

### Forma

```gdscript
extends RefCounted
class_name CompositionConnectionDirective
```

### Responsabilidad

> Representar una relación de comunicación compilada sin contener callback o Device activo.

### Estado

```gdscript
var _connection_id: StringName

var _source_device_id: String

var _source_port_id: StringName

var _topic: StringName

var _target_device_id: String

var _target_port_id: StringName
```

### Construcción

El caller entrega:

```gdscript
CompositionConnectionDirective.new(
	source_device_id,
	source_port_id,
	topic,
	target_device_id,
	target_port_id
)
```

Connection ID se genera de forma determinista.

### Connection ID

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

El separador `|` permanece reservado.

### API

```gdscript
get_connection_id() -> StringName

get_source_device_id() -> String

get_source_port_id() -> StringName

get_topic() -> StringName

get_target_device_id() -> String

get_target_port_id() -> StringName

is_valid_identity() -> bool
```

## 17. Connection Directive validation

Debe comprobar:

- Connection ID no vacío;
- Source Device ID no vacío;
- Source Port ID no vacío;
- Topic no vacío;
- Target Device ID no vacío;
- Target Port ID no vacío;
- Source y Target diferentes;
- componentes sin `|`;
- ID coincide con endpoints.

Compatibilidad de Topic y Ports ya fue validada por DeviceGraph.

CompositionPlan conserva validación defensiva de endpoints conocidos.

## 18. Connection Directive no contiene callback

No contiene:

- Callable;
- Subscriber Object;
- DeviceBus;
- RuntimeDeviceHandle;
- RuntimeFactory;
- DeviceGraphConnection reference como modelo interno.

CompositionRuntime necesitará un contrato posterior para convertir Target Port en endpoint runtime.

No se inventa ese callback dentro del Plan.

## 19. CompositionPlan

### Archivo

```text
core/composition/composition_plan.gd
```

### Forma

```gdscript
extends RefCounted
class_name CompositionPlan
```

### Responsabilidad

> Representar un plan runtime inmutable y no ejecutable.

### Estado

```gdscript
var _activation_context: int

var _device_entries: Array[CompositionDeviceEntry]

var _connection_directives: Array[CompositionConnectionDirective]

var _dispatch_policy: DeviceBusDispatchPolicy
```

### Construcción

```gdscript
CompositionPlan.new(
	activation_context,
	device_entries,
	connection_directives,
	dispatch_policy
)
```

Los Arrays se copian.

## 20. CompositionPlan API

```gdscript
get_activation_context() -> int

get_device_entries() -> Array[CompositionDeviceEntry]

get_connection_directives() -> Array[CompositionConnectionDirective]

get_dispatch_policy() -> DeviceBusDispatchPolicy

get_device_entry(
	device_id: String
) -> CompositionDeviceEntry

get_connection_directive(
	connection_id: StringName
) -> CompositionConnectionDirective

get_construction_order() -> Array[String]

get_attach_order() -> Array[String]

get_initialization_order() -> Array[String]

get_ready_order() -> Array[String]

get_start_order() -> Array[String]

get_shutdown_order() -> Array[String]

get_rollback_order() -> Array[String]

is_valid() -> bool
```

## 21. Plan validation

Debe comprobar:

- Activation Context válido;
- Dispatch Policy no null;
- Dispatch Policy válida;
- Device Entry no null;
- Device Entry válida;
- Device IDs únicos;
- Entry Context coincide con Plan;
- Connection Directive no null;
- Directive identity válida;
- Connection IDs únicas;
- Source Device existe;
- Target Device existe.

No ejecuta factories para validar.

## 22. Orden base

Orden forward se deriva de Device Entries:

```text
construction

attach

initialize

set_ready

start
```

Todos devuelven:

```text
Device IDs en orden de entries
```

No se almacenan Arrays separados.

## 23. Phase barriers

CompositionRuntime debe completar cada fase para todos los Devices antes de comenzar la siguiente.

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

Esto permite que todos los participantes existan antes de iniciar publicaciones.

## 24. Shutdown y rollback

Orden inverso de Device Entries:

```text
shutdown

rollback
```

Si entries son:

```text
A
B
C
```

orden inverso:

```text
C
B
A
```

## 25. Razón para derivar órdenes

No se almacenan siete Arrays de Device IDs.

Evita:

- IDs faltantes;
- IDs duplicados;
- órdenes contradictorios;
- validación redundante;
- Plan inflado.

La primera versión utiliza una política simple y determinista.

## 26. Ciclos

DeviceGraph puede contener ciclos.

CompositionPlan no requiere topological sort.

Phase barriers permiten:

- construir todos;
- adjuntar todos;
- inicializar todos;
- preparar todos;
- iniciar después.

Un ciclo conserva Simulation Hazard del pipeline de compilación.

Scheduling avanzado podrá añadir:

- SCC groups;
- priorities;
- temporal boundaries;
- explicit phases.

No forma parte de Plan 1.0.

## 27. Connection order

Connection Directives conservan orden de DeviceGraphConnections.

Plan no reordena por Topic o Device ID.

El orden es determinista.

## 28. Communication directives

CompositionConnectionDirective representa intención de wiring.

CompositionRuntime futuro resolverá:

- Target Device Handle;
- Target Port;
- runtime callback o adapter;
- DeviceBus subscription;
- Source filtering cuando corresponda.

Plan no contiene callback.

## 29. Source filtering

Stream identity utiliza:

```text
Topic

+

Source Device ID
```

Connection Directive conserva ambos.

Esto permite que CompositionRuntime implemente filtrado por Source ID cuando múltiples Devices publican el mismo Topic.

El mecanismo concreto permanece futuro.

## 30. Dependency flow

```text
RuntimeFactoryDescriptor
		│
		▼
RuntimeDependencySpecs
		│
		▼
CompositionDeviceEntry
		│
		▼
CompositionPlan
		│
		▼
CompositionRuntime
		│
		▼
RuntimeDependencyBindings
		│
		▼
RuntimeConstructionRequest
```

Plan contiene Specs.

No contiene Values.

## 31. RuntimeFactory availability

CompositionCompiler debe comprobar que cada DeviceGraphNode tenga RuntimeFactoryDescriptor exacto.

CompositionPlan conserva Key.

CompositionRuntime vuelve a resolver Key en Registry antes de build.

No existe fallback.

## 32. Dispatch Policy

Plan conserva referencia a DeviceBusDispatchPolicy inmutable.

CompositionRuntime utiliza esa política al crear DeviceBus.

No modifica Policy.

Policy inválida hace Plan inválido.

## 33. Plan no ejecutable

CompositionPlan no expone:

```text
execute

activate

build

create_device

attach

initialize

start

shutdown

publish

subscribe
```

Es descripción, no ejecución.

## 34. Plan inmutable

No expone setters.

Arrays del constructor se copian.

Getters devuelven copias.

Entries, Directives, Keys, Specs y Policy son inmutables por contrato.

## 35. Plan vacío

Plan vacío con contexto y Policy válidos:

```text
is_valid:
true
```

Órdenes:

```text
[]
```

CompositionRuntime puede tratarlo como no-op.

Una capa de deployment puede rechazarlo externamente.

## 36. RuntimeFactoryRegistry relation

Registry contiene:

```text
RuntimeFactoryDescriptor

RuntimeFactory Object
```

Plan contiene:

```text
RuntimeFactoryKey

RuntimeDependencySpecs
```

Plan no contiene Registry.

CompositionRuntime recibe ambos.

## 37. CompositionCompiler futuro

Responsabilidad:

> Convertir DeviceGraphSnapshot y RuntimeFactoryRegistry en CompositionPlan.

Entradas conceptuales:

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

## 38. CompositionRuntime futuro

Recibe:

- CompositionPlan;
- RuntimeFactoryRegistry;
- resolved dependency values;
- RuntimeHost.

Posee:

- DeviceBus;
- RuntimeDeviceHandles;
- host attach state;
- lifecycle;
- rollback;
- shutdown.

## 39. Error codes conceptuales

Device Entry:

```text
composition_device_id_missing

composition_device_configuration_missing

composition_device_configuration_invalid

composition_device_factory_key_missing

composition_device_factory_key_invalid

composition_device_identity_mismatch

composition_device_dependency_missing

composition_device_dependency_invalid

composition_device_duplicate_dependency
```

Connection Directive:

```text
composition_connection_source_device_missing

composition_connection_source_port_missing

composition_connection_topic_missing

composition_connection_target_device_missing

composition_connection_target_port_missing

composition_connection_self_reference

composition_connection_reserved_separator
```

Plan:

```text
composition_plan_activation_context_invalid

composition_plan_dispatch_policy_missing

composition_plan_dispatch_policy_invalid

composition_plan_device_entry_missing

composition_plan_device_entry_invalid

composition_plan_duplicate_device_id

composition_plan_connection_directive_missing

composition_plan_connection_directive_invalid

composition_plan_duplicate_connection_id

composition_plan_source_device_not_found

composition_plan_target_device_not_found
```

Las primitivas iniciales pueden usar `is_valid()`.

CompositionCompiler producirá Reports estructurados.

## 40. Estrategia de pruebas

### CompositionDeviceEntryTest

Verifica:

- Device ID;
- Configuration;
- Factory Key;
- Dependency Specs;
- identidad;
- context;
- Profile ID;
- Profile Version;
- nulls;
- duplicate Dependency ID;
- lookup;
- Arrays independientes;
- ausencia de runtime values;
- ausencia de factory;
- inmutabilidad.

### CompositionConnectionDirectiveTest

Verifica:

- ID determinista;
- Source Device;
- Source Port;
- Topic;
- Target Device;
- Target Port;
- campos requeridos;
- self reference;
- separador reservado;
- no callback;
- no DeviceBus;
- no setters.

### CompositionPlanTest

Verifica:

- Plan vacío;
- Context;
- Policy obligatoria;
- Entries;
- Directives;
- duplicate Device ID;
- duplicate Connection ID;
- Source desconocido;
- Target desconocido;
- orden forward;
- orden reverse;
- phase consistency;
- ciclos no requeridos para validar Plan;
- Arrays independientes;
- lookups;
- no ejecución;
- no factories;
- no Callables;
- no active resources.

## 41. Integración futura

```text
CompositionPlanRuntimeFactoryRegistryIntegrationTest
```

Verificará:

- cada Entry conserva Key;
- Registry resuelve Descriptor;
- Specs coinciden;
- Plan no contiene factory;
- mismo factory Object bajo varias Keys;
- contexto incorrecto falla;
- versión incorrecta falla;
- no fallback;
- no ejecución.

## 42. Baselines preservadas

No se modifican:

```text
DeviceBusDispatchPolicyTest

DeviceGraphSnapshotTest

RuntimeFactoryKeyTest

RuntimeDependencyBindingTest

RuntimeConstructionRequestTest

RuntimeDeviceHandleTest

RuntimeFactoryBuildResultTest

RuntimeConstructionContractIntegrationTest
```

Plan utiliza pruebas sucesoras.

## 43. Orden de implementación

```text
1. Implementar CompositionDeviceEntry.

2. Ejecutar CompositionDeviceEntryTest.

3. Implementar CompositionConnectionDirective.

4. Ejecutar CompositionConnectionDirectiveTest.

5. Implementar CompositionPlan.

6. Ejecutar CompositionPlanTest.

7. Integrar con RuntimeFactoryRegistry.

8. Ejecutar Run All.

9. Registrar baseline.

10. Diseñar CompositionCompiler.
```

La implementación de Plan comenzará después de completar RuntimeFactoryRegistry 1.0.

## 44. Criterios de aceptación

1. Device Entry tipada.

2. Connection Directive tipada.

3. Plan inmutable.

4. Plan sin identidad propia.

5. Plan vacío válido.

6. Activation Context explícito.

7. Dispatch Policy obligatoria.

8. Factory Keys exactas.

9. Dependency Specs declaradas.

10. Sin Dependency Values.

11. Sin RuntimeFactory.

12. Sin Callable.

13. Sin RuntimeDeviceHandle.

14. Connection Directives sin callbacks.

15. Device IDs únicos.

16. Connection IDs únicos.

17. Endpoints conocidos.

18. Orden forward derivado.

19. Orden reverse derivado.

20. Phase barriers definidos.

21. Ciclos no requieren topological sort.

22. Arrays independientes.

23. Lookups exactos.

24. No ejecución.

25. Pruebas sucesoras PASS.

26. Integración Registry PASS.

27. Run All PASS.

## 45. Fuera de alcance

CompositionPlan 1.0 no implementará:

- CompositionCompiler;
- CompositionRuntime;
- factory execution;
- dependency resolution activa;
- RuntimeDependencyBinding Values;
- DeviceBus activo;
- callbacks;
- RuntimeHost;
- lifecycle execution;
- scheduling SCC;
- temporal boundary resolution;
- Plan ID;
- Plan Version;
- serialization;
- hot reload;
- Hardware activation.

## 46. Consecuencias positivas

- Plan tipado;
- no Dictionaries genéricos;
- no factories ejecutables;
- orden determinista;
- phase barriers;
- rollback derivable;
- Dispatch Policy explícita;
- soporte de ciclos;
- source identity preservada;
- dependency requirements visibles;
- runtime auditable.

## 47. Consecuencias negativas

- tres clases nuevas;
- no custom order por fase;
- no optional dependencies;
- no callbacks compilados todavía;
- CompositionRuntime necesitará resolver endpoints;
- Plan no tiene identidad para comparación externa.

Estas consecuencias son aceptadas.

## 48. Invariantes

1. Plan es inmutable.

2. Plan no ejecuta.

3. Plan no contiene factory.

4. Plan no contiene Callable.

5. Plan no contiene recursos activos.

6. Entries conservan Key.

7. Entries conservan Dependency Specs.

8. Directives son tipadas.

9. Source ID y Topic se conservan.

10. Dispatch Policy es obligatoria.

11. Forward order deriva de Entries.

12. Reverse order invierte Entries.

13. Phase barriers son obligatorias.

14. Plan vacío es válido.

15. Ciclos no se rechazan por ordering.

16. CompositionRuntime recibe Registry aparte.

## 49. Estado

```text
DISEÑO ACTIVO
```

CompositionPlan 1.0 está autorizado para implementación después de completar RuntimeFactoryRegistry 1.0.

Primer componente futuro:

```text
CompositionDeviceEntry
```

Siguiente implementación inmediata del proyecto:

```text
RuntimeDependencySpec
```