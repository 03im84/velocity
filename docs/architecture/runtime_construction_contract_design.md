# Runtime Construction Contract — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 25/08/2026 |
| ADR relacionado | ADR-010 — Runtime Construction and Factory Binding |
| Alcance | Identidad de factory, dependencias, request, handle, build result, factory behavior y host behavior |

## 1. Propósito

Este documento traduce ADR-010 a contratos concretos e implementables.

Define:

- RuntimeFactoryKey;
- RuntimeDependencyBinding;
- RuntimeConstructionRequest;
- RuntimeDeviceHandle;
- RuntimeFactoryBuildResult;
- RuntimeFactory behavior;
- RuntimeHost behavior;
- ownership;
- construcción atómica;
- cleanup;
- límites frente a CompositionRuntime.

La primera implementación se limita a contratos y pruebas.

No implementa todavía:

- RuntimeFactoryRegistry;
- CompositionPlan;
- CompositionCompiler;
- CompositionRuntime;
- RuntimeHost concreto;
- factories concretas de producción.

## 2. Pipeline conceptual

```text
CompositionPlan
		│
		├── RuntimeFactoryKey
		├── dependency directives
		└── lifecycle order
				│
				▼
CompositionRuntime
		│
		├── pre-resolved dependencies
		├── RuntimeFactoryRegistry
		└── RuntimeHost
				│
				▼
RuntimeConstructionRequest
				│
				▼
RuntimeFactory.build()
				│
				▼
RuntimeFactoryBuildResult
				│
				▼
RuntimeDeviceHandle
```

Después de construir todos los Handles:

```text
RuntimeHost.attach()
		│
		▼
initialize
		│
		▼
set_ready
		│
		▼
start
		│
		▼
commit Active Simulation
```

## 3. Estructura propuesta

### 3.1 Código

```text
core/runtime/
├── runtime_factory_key.gd
├── runtime_dependency_binding.gd
├── runtime_construction_request.gd
├── runtime_device_handle.gd
└── runtime_factory_build_result.gd
```

### 3.2 Pruebas

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
└── runtime_construction_contract_integration_test.gd
```

### 3.3 Soporte de prueba

```text
test/core/runtime/
├── runtime_test_factory.gd
├── runtime_test_host.gd
└── runtime_test_object.gd
```

Los helpers de prueba no representan implementaciones de producción.

## 4. Dependencias permitidas

```text
DeviceProfile

DeviceConfiguration

ValidationIssue

ValidationReport

Object
```

Runtime contracts pueden referenciar objetos host mediante `Object`.

No invocan APIs específicas de Node.

## 5. Dependencias no permitidas

```text
SceneTree

Node paths

autoloads

DeviceBus global

DeviceGraphDraft

SystemProfileDraft

filesystem

JSON

GraphEditor

hardware adapters concretos

telemetría
```

Factories concretas futuras podrán depender de adapters explícitos mediante bindings.

Los contratos base no descubren esas dependencias.

## 6. RuntimeFactoryKey

### 6.1 Archivo

```text
core/runtime/runtime_factory_key.gd
```

### 6.2 Forma

```gdscript
extends RefCounted
class_name RuntimeFactoryKey
```

### 6.3 Responsabilidad

> Identificar de forma exacta una RuntimeFactory.

### 6.4 Estado

```gdscript
var _profile_id: StringName

var _profile_version: int

var _activation_context: int
```

### 6.5 Construcción

```gdscript
RuntimeFactoryKey.new(
	profile_id,
	profile_version,
	activation_context
)
```

### 6.6 API

```gdscript
get_profile_id() -> StringName

get_profile_version() -> int

get_activation_context() -> int

is_valid() -> bool

equals(
	other: RuntimeFactoryKey
) -> bool
```

### 6.7 Validación

Debe cumplirse:

```text
Profile ID no vacío;

Profile Version positiva;

Activation Context es SIMULATION
o HARDWARE.
```

### 6.8 Igualdad

Dos Keys son iguales cuando coinciden:

```text
Profile ID

AND

Profile Version

AND

Activation Context
```

No se utiliza identidad de referencia para igualdad lógica.

### 6.9 Inmutabilidad

No expone setters.

## 7. RuntimeFactoryKey y contexto

Estas Keys son diferentes:

```text
test.sensor@1 + SIMULATION

test.sensor@1 + HARDWARE
```

No existe sustitución entre contextos.

Estas Keys también son diferentes:

```text
test.sensor@1 + SIMULATION

test.sensor@2 + SIMULATION
```

No existe sustitución entre versiones.

## 8. RuntimeFactoryKey sin host target

RuntimeFactoryKey 1.0 no contiene:

```text
host_target
```

No existen todavía contratos canónicos para:

- pure;
- mock;
- godot_node;
- hardware_bridge.

Si el proyecto necesita varias implementaciones para la misma Key, se diseñará una dimensión adicional explícita.

No se utiliza string libre como solución anticipada.

## 9. RuntimeDependencyBinding

### 9.1 Archivo

```text
core/runtime/runtime_dependency_binding.gd
```

### 9.2 Forma

```gdscript
extends RefCounted
class_name RuntimeDependencyBinding
```

### 9.3 Responsabilidad

> Representar una dependencia runtime pre-resuelta con ownership explícito.

### 9.4 Ownership enum

```gdscript
enum Ownership {
	BORROWED,
	TRANSFERRED,
}
```

### 9.5 Estado

```gdscript
var _dependency_id: StringName

var _value: Object

var _ownership: int
```

### 9.6 Tipo de Value

RuntimeDependencyBinding 1.0 acepta:

```gdscript
Object
```

Esto cubre:

- RefCounted;
- Resource;
- Node;
- adapters;
- Providers;
- servicios tipados.

No acepta scalar Variant como dependency value.

Valores escalares pertenecen a:

- DeviceConfiguration;
- Profile;
- request metadata;
- contratos tipados futuros.

### 9.7 Construcción

```gdscript
RuntimeDependencyBinding.new(
	dependency_id,
	value,
	ownership
)
```

### 9.8 API

```gdscript
get_dependency_id() -> StringName

get_value() -> Object

get_ownership() -> int

is_borrowed() -> bool

is_transferred() -> bool

is_valid() -> bool
```

### 9.9 Validación

Debe cumplirse:

```text
Dependency ID no vacío;

Value no null;

Ownership es BORROWED
o TRANSFERRED.
```

### 9.10 Inmutabilidad

No expone setters.

## 10. BORROWED

Una dependencia BORROWED:

- conserva su owner original;
- puede ser utilizada por factory y Handle;
- no se libera durante cleanup del Handle;
- no se transfiere a otro componente;
- debe permanecer viva durante el uso del Handle.

Ejemplos:

- DeviceBus compartido;
- servicio global poseído por CompositionRuntime;
- RuntimeHost compartido;
- world adapter compartido.

BORROWED no significa global oculto.

El binding continúa siendo explícito.

## 11. TRANSFERRED

Una dependencia TRANSFERRED cambia ownership al comenzar la llamada de factory.

### Antes de `build()`

El caller es owner.

### Durante `build()`

La factory es responsable de la transacción.

### En éxito

RuntimeDeviceHandle asume ownership.

### En fallo

La factory libera la dependencia antes de devolver.

El caller no realiza un segundo cleanup.

Ejemplos futuros:

- Provider privado del Device;
- adapter privado;
- buffer exclusivo;
- recurso host creado para una instancia.

## 12. Request creado pero no ejecutado

Crear RuntimeConstructionRequest no transfiere ownership.

La transferencia comienza cuando CompositionRuntime invoca:

```gdscript
factory.build(
	request
)
```

Si un Request nunca se entrega a una factory, el caller conserva ownership de todos los bindings.

## 13. IDs de dependencia

Dependency ID utiliza:

```gdscript
StringName
```

Ejemplos conceptuales:

```text
distance_provider

runtime_clock

world_query

telemetry_transport
```

No se definen todavía IDs canónicos de producción.

Cada familia de factory deberá documentar sus dependencies.

No se infieren mediante nombre de clase.

## 14. RuntimeConstructionRequest

### 14.1 Archivo

```text
core/runtime/runtime_construction_request.gd
```

### 14.2 Forma

```gdscript
extends RefCounted
class_name RuntimeConstructionRequest
```

### 14.3 Responsabilidad

> Transportar toda la información pre-resuelta necesaria para construir un runtime object.

### 14.4 Estado

```gdscript
var _device_id: String

var _configuration: DeviceConfiguration

var _factory_key: RuntimeFactoryKey

var _dependency_bindings: Array[RuntimeDependencyBinding]
```

### 14.5 Construcción

```gdscript
RuntimeConstructionRequest.new(
	device_id,
	configuration,
	factory_key,
	dependency_bindings
)
```

El Array se duplica durante construcción.

### 14.6 API

```gdscript
get_device_id() -> String

get_configuration() -> DeviceConfiguration

get_factory_key() -> RuntimeFactoryKey

get_dependency_bindings() -> Array[RuntimeDependencyBinding]

get_dependency_binding(
	dependency_id: StringName
) -> RuntimeDependencyBinding

has_dependency(
	dependency_id: StringName
) -> bool

is_valid() -> bool
```

### 14.7 No service locator

El Request permite consultar únicamente bindings incluidos explícitamente.

No puede:

- descubrir cualquier servicio;
- buscar Nodes;
- consultar autoloads;
- recorrer SceneTree;
- cargar archivos;
- descargar dependencias;
- crear bindings adicionales.

## 15. Validación del Request

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
- Binding no null;
- Binding válido;
- Dependency IDs únicos.

## 16. Códigos del Request

Códigos conceptuales:

```text
runtime_construction_device_id_missing

runtime_construction_configuration_missing

runtime_construction_configuration_invalid

runtime_construction_factory_key_missing

runtime_construction_factory_key_invalid

runtime_construction_device_id_mismatch

runtime_construction_profile_identity_mismatch

runtime_construction_activation_context_mismatch

runtime_construction_dependency_missing

runtime_construction_dependency_invalid

runtime_construction_duplicate_dependency
```

La implementación concreta decidirá si `is_valid()` devuelve bool solamente o si un Compiler externo produce ValidationReport.

La primera versión puede utilizar `is_valid()` en primitivas y pruebas específicas para códigos en componentes posteriores.

## 17. Colecciones del Request

`get_dependency_bindings()` devuelve Array nuevo.

RuntimeDependencyBinding es inmutable y puede compartirse por referencia.

Modificar el Array recibido por el constructor no cambia el Request.

Modificar el Array retornado no cambia el Request.

## 18. RuntimeDeviceHandle

### 18.1 Archivo

```text
core/runtime/runtime_device_handle.gd
```

### 18.2 Forma

```gdscript
extends RefCounted
class_name RuntimeDeviceHandle
```

### 18.3 Responsabilidad

> Representar el producto exitoso y el ownership resultante de una RuntimeFactory.

### 18.4 Estado

```gdscript
var _device_id: String

var _configuration: DeviceConfiguration

var _factory_key: RuntimeFactoryKey

var _primary_runtime_object: Object

var _host_objects: Array[Object]

var _dependency_bindings: Array[RuntimeDependencyBinding]
```

### 18.5 Construcción

```gdscript
RuntimeDeviceHandle.new(
	device_id,
	configuration,
	factory_key,
	primary_runtime_object,
	host_objects,
	dependency_bindings
)
```

Los Arrays se duplican.

### 18.6 API

```gdscript
get_device_id() -> String

get_configuration() -> DeviceConfiguration

get_factory_key() -> RuntimeFactoryKey

get_primary_runtime_object() -> Object

get_host_objects() -> Array[Object]

get_dependency_bindings() -> Array[RuntimeDependencyBinding]

get_dependency_binding(
	dependency_id: StringName
) -> RuntimeDependencyBinding

is_valid() -> bool
```

### 18.7 Primary Runtime Object

Debe ser no null.

Representa el objeto principal construido para el Device.

Puede ser:

- Device;
- adapter;
- controller;
- bridge;
- wrapper runtime;
- host object.

No se obliga a una clase base universal.

## 19. Host Objects en Handle

Host Objects se representan como:

```gdscript
Array[Object]
```

Esto permite contener Nodes sin que el contrato base invoque APIs de Node.

Reglas:

- ningún elemento null;
- referencias duplicadas rechazadas;
- orden preservado;
- Array copiado;
- pueden incluir Primary Runtime Object si también requiere attach;
- la misma referencia no aparece dos veces dentro de Host Objects.

RuntimeHost interpreta host objects.

## 20. Dependency Bindings en Handle

Handle conserva los bindings utilizados por la factory.

Reglas:

- Binding no null;
- Binding válido;
- Dependency IDs únicos;
- orden preservado.

Para cleanup:

```text
BORROWED:
no liberar.

TRANSFERRED:
factory.release() debe liberar
cuando corresponda.
```

## 21. Validación del Handle

Debe comprobar:

- Device ID no vacío;
- Configuration válida;
- Factory Key válida;
- Device ID coincide con Configuration;
- Profile ID coincide con Key;
- Profile Version coincide con Key;
- Activation Context coincide con Key;
- Primary Runtime Object no null;
- Host Objects válidos y únicos;
- Dependency Bindings válidos y únicos.

## 22. Handle no ejecutable

RuntimeDeviceHandle no expone:

```text
execute

activate

start_all

shutdown_all

attach

detach

save

load
```

Handle representa ownership de una unidad runtime.

No coordina el sistema completo.

## 23. RuntimeFactoryBuildResult

### 23.1 Archivo

```text
core/runtime/runtime_factory_build_result.gd
```

### 23.2 Forma

```gdscript
extends RefCounted
class_name RuntimeFactoryBuildResult
```

### 23.3 Estado

```gdscript
var _handle: RuntimeDeviceHandle

var _report: ValidationReport
```

### 23.4 API

```gdscript
get_handle() -> RuntimeDeviceHandle

get_report() -> ValidationReport

is_success() -> bool
```

### 23.5 Success

Requiere:

```text
Handle no null;

Report no null;

Handle válido;

Report válido para Activation Context
de RuntimeFactoryKey.
```

Para Simulation:

```gdscript
report.is_valid_for_simulation()
```

Para Hardware:

```gdscript
report.is_valid_for_hardware()
```

### 23.6 Inmutabilidad

No expone setters.

## 24. RuntimeFactory behavior

RuntimeFactory es rol por comportamiento.

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

No se crea clase base universal.

## 25. Factory build

`build()`:

- valida Request;
- construye recursos;
- no adjunta host objects;
- no inicializa lifecycle;
- no publica;
- no registra suscripciones;
- no crea DeviceBus global;
- produce Handle completo o null;
- limpia parciales en failure.

## 26. Factory release

La misma factory conoce cómo liberar el Handle que construyó.

`release()`:

- recibe RuntimeDeviceHandle;
- libera recursos propios;
- libera bindings TRANSFERRED;
- no libera bindings BORROWED;
- no libera recursos globales;
- no coordina otros Handles;
- devuelve ValidationReport;
- debe ser segura ante cleanup parcial;
- no debe provocar double-free.

CompositionRuntime coordina el orden.

Factory implementa el detalle.

## 27. Repeated release

CompositionRuntime debe invocar release como máximo una vez por Handle adquirido.

La implementación de factory debe tolerar defensivamente una repetición sin:

- double-free;
- crash;
- corrupción;
- excepción no contenida.

Una repetición puede producir WARNING o resultado neutral según diseño de la factory concreta.

No se introduce estado mutable público en RuntimeDeviceHandle únicamente para esta comprobación.

## 28. Construcción atómica

Durante `build()` la factory es responsable de:

- objetos creados;
- recursos abiertos;
- bindings TRANSFERRED;
- host objects todavía no adjuntos.

En failure:

```text
Handle:
null

Report:
failure

recursos:
liberados
```

Un resultado fallido con Handle no null es incoherente.

RuntimeFactoryBuildResult lo rechazará.

## 29. RuntimeHost behavior

RuntimeHost es rol por comportamiento.

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

No se crea clase base universal.

## 30. RuntimeHost recibe Handle

RuntimeHost recibe RuntimeDeviceHandle completo.

No recibe únicamente Array de Objects.

Esto preserva:

- Device ID;
- Factory Key;
- agrupación;
- orden;
- provenance;
- rollback por Handle.

RuntimeHost consulta:

```gdscript
handle.get_host_objects()
```

## 31. RuntimeHost.attach()

Attach:

- valida Handle;
- procesa Host Objects en orden;
- no modifica Handle;
- no inicializa Device lifecycle;
- registra qué objetos adjuntó;
- revierte parcialmente si falla dentro del mismo Handle;
- produce ValidationReport.

Una implementación Godot futura podrá adjuntar Nodes.

El contrato base no conoce SceneTree.

## 32. RuntimeHost.detach()

Detach:

- recibe Handle;
- procesa Host Objects en orden inverso;
- tolera objetos ya separados;
- no libera bindings BORROWED;
- no sustituye factory.release();
- produce ValidationReport.

Orden global entre Handles pertenece a CompositionRuntime.

## 33. Secuencia de activación futura

```text
1. Validar CompositionPlan.

2. Resolver RuntimeFactoryKeys.

3. Resolver RuntimeDependencyBindings.

4. Crear RuntimeConstructionRequests.

5. Factory build de todos los Handles.

6. RuntimeHost attach de todos los Handles.

7. Crear o asignar DeviceBus.

8. initialize en orden.

9. set_ready en orden.

10. start en orden.

11. commit de nueva Active Simulation.
```

## 34. Rollback futuro

Si falla factory build:

```text
release Handles anteriores
en orden inverso.
```

Si falla attach:

```text
detach Handles adjuntos
en orden inverso;

release todos los Handles
en orden inverso.
```

Si falla lifecycle:

```text
shutdown componentes iniciados;

detach Handles;

release Handles;

conservar Last Known Good.
```

## 35. DeviceBus

DeviceBus no forma parte de RuntimeConstructionRequest 1.0 como dependencia global de construcción.

CompositionRuntime:

- crea o recibe DeviceBus;
- conserva ownership;
- lo entrega durante initialize;
- limpia al finalizar;
- observa DispatchReport.

Una factory no usa autoload para obtenerlo.

Si una implementación concreta necesita una referencia preparatoria, deberá declararse explícitamente y no cambiar ownership global.

## 36. RuntimeFactoryRegistry futuro

RuntimeFactoryRegistry resolverá:

```text
RuntimeFactoryKey
→ RuntimeFactory
```

Debe validar el behavior contract:

```text
build

release
```

No se diseña su mutabilidad en este documento.

Requerirá diseño propio.

## 37. CompositionPlan futuro

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
- Object activo;
- Node activo;
- DeviceBus activo.

## 38. Host independence

Los contratos base utilizan:

```text
Object
```

para objetos runtime y host.

No utilizan:

- Node;
- Node3D;
- SceneTree;
- World3D;
- physics server;
- autoload.

RuntimeHost concreto adapta esos objetos al host.

## 39. Errores y ValidationReport

Errores conceptuales de Key:

```text
runtime_factory_profile_id_missing

runtime_factory_profile_version_invalid

runtime_factory_activation_context_invalid
```

Errores conceptuales de Binding:

```text
runtime_dependency_id_missing

runtime_dependency_value_missing

runtime_dependency_ownership_invalid
```

Errores conceptuales de Request:

```text
runtime_construction_device_id_missing

runtime_construction_configuration_missing

runtime_construction_configuration_invalid

runtime_construction_factory_key_missing

runtime_construction_factory_key_invalid

runtime_construction_device_id_mismatch

runtime_construction_profile_identity_mismatch

runtime_construction_activation_context_mismatch

runtime_construction_dependency_missing

runtime_construction_dependency_invalid

runtime_construction_duplicate_dependency
```

Errores conceptuales de Handle:

```text
runtime_handle_device_id_missing

runtime_handle_configuration_missing

runtime_handle_configuration_invalid

runtime_handle_factory_key_missing

runtime_handle_factory_key_invalid

runtime_handle_identity_mismatch

runtime_handle_primary_object_missing

runtime_handle_host_object_missing

runtime_handle_duplicate_host_object

runtime_handle_dependency_missing

runtime_handle_dependency_invalid

runtime_handle_duplicate_dependency
```

Los primeros contratos podrán utilizar `is_valid()`.

Components de compilación posteriores producirán Issues estructurados.

## 40. Transaccionalidad

Crear Request no transfiere ownership.

Invocar factory build comienza la transacción local.

Build exitoso produce Handle.

Build fallido limpia localmente.

CompositionRuntime adquiere Handle exitoso.

Fallo global produce rollback inverso.

Last Known Good solo cambia después de commit completo.

## 41. Determinismo

Se conserva orden de:

- Dependency Bindings;
- Host Objects;
- Handles;
- attach;
- lifecycle;
- rollback.

No se depende de:

- filesystem;
- global registry mutable;
- SceneTree discovery;
- latest;
- fallback;
- hash iteration no controlada.

## 42. Estrategia de pruebas

### RuntimeFactoryKeyTest

Verifica:

- Profile ID;
- Profile Version;
- Context;
- identidad inválida;
- igualdad lógica;
- diferencias por versión;
- diferencias por contexto;
- ausencia de setters.

### RuntimeDependencyBindingTest

Verifica:

- BORROWED;
- TRANSFERRED;
- ID vacío;
- Value null;
- Ownership inválido;
- getters;
- ausencia de setters.

### RuntimeConstructionRequestTest

Verifica:

- identidad;
- Configuration;
- Factory Key;
- correspondencia de Device ID;
- correspondencia de Profile;
- correspondencia de Version;
- correspondencia de Context;
- Binding null;
- Binding inválido;
- Dependency ID duplicado;
- lookup;
- Arrays independientes;
- ausencia de service locator.

### RuntimeDeviceHandleTest

Verifica:

- identidad;
- Primary Runtime Object;
- Host Objects;
- bindings;
- referencias duplicadas;
- null objects;
- correspondencia con Configuration y Key;
- Arrays independientes;
- no ejecución;
- ausencia de setters.

### RuntimeFactoryBuildResultTest

Verifica:

- Handle null;
- Report null;
- Handle inválido;
- Simulation Report;
- Hardware Report;
- getters;
- ausencia de setters.

### RuntimeConstructionContractIntegrationTest

Utiliza factory y host controlados.

Verifica:

- build exitoso;
- Handle completo;
- transferred ownership;
- borrowed ownership;
- host objects sin attach durante build;
- RuntimeHost attach;
- RuntimeHost detach;
- factory release;
- failure cleanup;
- rollback conceptual;
- entradas no modificadas.

## 43. Baselines preservadas

No se modifican:

```text
DeviceLifecycleTest

DeviceCoreContractTest

SystemProfileCompilerTest

DeviceCatalogCompilerTest

DeviceGraphAssemblerTest

SystemProfileCatalogGraphAssemblyIntegrationTest
```

Runtime Construction utiliza pruebas sucesoras.

## 44. Orden de implementación

```text
1. Implementar RuntimeFactoryKey.

2. Ejecutar RuntimeFactoryKeyTest.

3. Implementar RuntimeDependencyBinding.

4. Ejecutar RuntimeDependencyBindingTest.

5. Implementar RuntimeConstructionRequest.

6. Ejecutar RuntimeConstructionRequestTest.

7. Implementar RuntimeDeviceHandle.

8. Ejecutar RuntimeDeviceHandleTest.

9. Implementar RuntimeFactoryBuildResult.

10. Ejecutar RuntimeFactoryBuildResultTest.

11. Crear Test RuntimeFactory.

12. Crear Test RuntimeHost.

13. Ejecutar RuntimeConstructionContractIntegrationTest.

14. Ejecutar Run All.

15. Registrar baseline.

16. Actualizar Core Architecture.

17. Actualizar Project Handoff.

18. Cerrar Runtime Construction Contract 1.0.

19. Diseñar RuntimeFactoryRegistry.

20. Diseñar CompositionPlan.
```

## 45. Criterios de aceptación

1. RuntimeFactoryKey es inmutable.

2. Key incluye Profile ID.

3. Key incluye Profile Version.

4. Key incluye Activation Context.

5. Key usa igualdad lógica.

6. No existe fallback.

7. RuntimeDependencyBinding es inmutable.

8. Dependency Value es Object.

9. Ownership es explícito.

10. BORROWED está probado.

11. TRANSFERRED está probado.

12. Request es inmutable.

13. Request contiene bindings pre-resueltos.

14. Request no es service locator.

15. Request valida coherencia con Configuration.

16. Handle es inmutable por contrato.

17. Handle representa ownership.

18. Handle conserva Host Objects.

19. Host Objects no se adjuntan durante build.

20. Factory construye solamente.

21. Factory expone build y release.

22. Build es atómico.

23. Failure produce Handle null.

24. Failure limpia TRANSFERRED.

25. RuntimeHost recibe Handle.

26. RuntimeHost controla attach/detach.

27. DeviceBus no es global oculto.

28. Result es defensivo.

29. Pruebas sucesoras terminan PASS.

30. Run All termina PASS.

## 46. Fuera de alcance

Runtime Construction Contract 1.0 no implementará:

- RuntimeFactoryRegistry;
- CompositionPlan;
- CompositionCompiler;
- CompositionRuntime;
- GodotRuntimeHost;
- HardwareRuntimeHost;
- factories de producción;
- Device creation real;
- SceneTree attach real;
- DeviceBus initialization real;
- lifecycle runtime real;
- persistence;
- host target;
- factory variants;
- hardware;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation.

## 47. Consecuencias positivas

- factory contract explícito;
- ownership claro;
- dependencias pre-resueltas;
- no service locator;
- soporte de Objects host;
- Core sin dependencia de Node;
- cleanup delegado a quien construye;
- rollback global coordinable;
- Plan no ejecutable;
- Registry separado de Catalog.

## 48. Consecuencias negativas

- cinco clases nuevas;
- dos behaviors documentados;
- factories necesitan build y release;
- CompositionRuntime debe coordinar más etapas;
- ownership transferido requiere disciplina;
- no se puede utilizar Callable como atajo.

Estas consecuencias son aceptadas.

## 49. Invariantes

1. Key es exacta.

2. Binding ownership es explícito.

3. Request contiene dependencias pre-resueltas.

4. Request no descubre servicios.

5. Factory construye solamente.

6. Factory build es atómico.

7. Factory release conoce su producto.

8. Handle representa una unidad runtime.

9. Handle no coordina sistema completo.

10. RuntimeHost recibe Handle.

11. Host attach ocurre después de build.

12. DeviceBus pertenece a CompositionRuntime.

13. Rollback global es inverso.

14. Plan guarda Key, no factory.

15. Registry permanece separado de Catalog.

16. Last Known Good solo cambia después de commit.

## 50. Estado

```text
DISEÑO ACTIVO
```

Runtime Construction Contract 1.0 está autorizado para implementación incremental.

Primer componente:

```text
RuntimeFactoryKey
```

RuntimeFactoryRegistry y CompositionPlan permanecen fuera de esta implementación.
