# Runtime Construction Contract — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Fecha | 04/09/2026 |
| ADR relacionado | ADR-010 — Runtime Construction and Factory Binding |
| Alcance | Identidad de factory, dependencias, request, handle, build result, factory behavior y host behavior |
| Estado de implementación | COMPLETO Y VERIFICADO |

## 1. Propósito

Runtime Construction Contract define cómo se construye una unidad runtime antes de implementar:

- RuntimeFactoryRegistry;
- CompositionPlan;
- CompositionCompiler;
- CompositionRuntime.

Componentes implementados:

- RuntimeFactoryKey;
- RuntimeDependencyBinding;
- RuntimeConstructionRequest;
- RuntimeDeviceHandle;
- RuntimeFactoryBuildResult.

Behaviors verificados mediante integración:

- RuntimeFactory;
- RuntimeHost.

La construcción es:

- explícita;
- atómica;
- transaccional;
- sin service locator;
- sin dependencias globales ocultas;
- sin host attach prematuro;
- separada de lifecycle;
- separada de activación.

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

Después de construir Handles:

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

## 3. Estructura implementada

### Código

```text
core/runtime/
├── runtime_factory_key.gd
├── runtime_dependency_binding.gd
├── runtime_construction_request.gd
├── runtime_device_handle.gd
└── runtime_factory_build_result.gd
```

### Pruebas

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

### Soporte controlado

```text
test/core/runtime/
├── runtime_test_factory.gd
├── runtime_test_host.gd
└── runtime_test_object.gd
```

Los helpers no representan producción.

## 4. Dependencias permitidas

```text
DeviceConfiguration

ValidationIssue

ValidationReport

Object
```

Runtime contracts pueden conservar Objects.

No invocan APIs específicas de Node.

## 5. Dependencias prohibidas

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

## 6. RuntimeFactoryKey

### Responsabilidad

> Identificar de forma exacta una RuntimeFactory.

### Estado

```gdscript
profile_id: StringName

profile_version: int

activation_context: int
```

### API

```gdscript
get_profile_id() -> StringName

get_profile_version() -> int

get_activation_context() -> int

is_valid() -> bool

equals(
	other: RuntimeFactoryKey
) -> bool
```

### Validación

- Profile ID no vacío;
- Profile Version positiva;
- Activation Context válido.

### Igualdad

Compara contenido.

No requiere misma referencia.

### Inmutabilidad

No expone setters.

## 7. Factory Key exacta

Identidad:

```text
Profile ID

+

Profile Version

+

Activation Context
```

Diferentes:

```text
sensor@1 + Simulation

sensor@2 + Simulation

sensor@1 + Hardware
```

No existe:

- latest;
- fallback;
- sustitución;
- host target.

## 8. RuntimeFactoryKey sin host target

RuntimeFactoryKey 1.0 no contiene:

```text
host_target
```

No existen contratos canónicos para:

- pure;
- mock;
- godot_node;
- hardware_bridge.

Una dimensión adicional requerirá una necesidad concreta y diseño propio.

## 9. RuntimeDependencyBinding

### Responsabilidad

> Representar una dependencia pre-resuelta con ownership explícito.

### Ownership

```gdscript
enum Ownership {
	BORROWED,
	TRANSFERRED,
}
```

### Estado

```gdscript
dependency_id: StringName

value: Object

ownership: int
```

### API

```gdscript
get_dependency_id() -> StringName

get_value() -> Object

get_ownership() -> int

is_borrowed() -> bool

is_transferred() -> bool

is_valid() -> bool
```

### Validación

- Dependency ID no vacío;
- Value no null;
- Ownership canónico.

### Inmutabilidad

No expone setters.

No ejecuta cleanup.

## 10. Dependency Value

RuntimeDependencyBinding acepta:

```gdscript
Object
```

Cubre:

- RefCounted;
- Resource;
- Node;
- Provider;
- adapter;
- servicio tipado.

Valores escalares pertenecen a Configuration o contratos tipados.

## 11. BORROWED

BORROWED:

- conserva owner original;
- factory puede utilizar;
- Handle puede conservar referencia;
- factory release no libera;
- Handle no asume ownership.

El binding continúa siendo explícito.

## 12. TRANSFERRED

Crear Binding o Request no transfiere ownership.

La transferencia comienza al invocar:

```gdscript
factory.build(
	request
)
```

Durante build:

```text
factory es custodio
```

En éxito:

```text
Handle asume ownership
```

En fallo:

```text
factory limpia
```

Caller no ejecuta segundo cleanup.

## 13. RuntimeConstructionRequest

### Responsabilidad

> Transportar información pre-resuelta para construcción.

### Estado

```gdscript
device_id: String

configuration: DeviceConfiguration

factory_key: RuntimeFactoryKey

dependency_bindings: Array[RuntimeDependencyBinding]
```

### API

```gdscript
get_device_id() -> String

get_configuration() -> DeviceConfiguration

get_factory_key() -> RuntimeFactoryKey

get_dependency_bindings() -> Array[RuntimeDependencyBinding]

has_dependency(
	dependency_id: StringName
) -> bool

get_dependency_binding(
	dependency_id: StringName
) -> RuntimeDependencyBinding

is_valid() -> bool
```

### Validación

- Device ID requerido;
- Configuration requerida;
- Configuration válida;
- Factory Key requerida;
- Factory Key válida;
- Device ID coincide;
- Profile ID coincide;
- Profile Version coincide;
- Activation Context coincide;
- Bindings no null;
- Bindings válidos;
- Dependency IDs únicos.

### Colecciones

Constructor copia Array.

Getter devuelve copia.

## 14. Request no es service locator

Request permite consultar solamente bindings incluidos.

No puede:

- descubrir servicios;
- buscar Nodes;
- consultar autoloads;
- recorrer SceneTree;
- cargar archivos;
- crear bindings adicionales.

## 15. RuntimeDeviceHandle

### Responsabilidad

> Representar producto exitoso y ownership de una unidad runtime.

### Estado

```gdscript
device_id: String

configuration: DeviceConfiguration

factory_key: RuntimeFactoryKey

primary_runtime_object: Object

host_objects: Array[Object]

dependency_bindings: Array[RuntimeDependencyBinding]
```

### API

```gdscript
get_device_id() -> String

get_configuration() -> DeviceConfiguration

get_factory_key() -> RuntimeFactoryKey

get_primary_runtime_object() -> Object

get_host_objects() -> Array[Object]

get_dependency_bindings() -> Array[RuntimeDependencyBinding]

has_dependency(
	dependency_id: StringName
) -> bool

get_dependency_binding(
	dependency_id: StringName
) -> RuntimeDependencyBinding

is_valid() -> bool
```

## 16. Handle validation

Debe comprobar:

- Device ID;
- Configuration;
- Factory Key;
- Primary Runtime Object;
- identidad coherente;
- Host Objects válidos;
- Host Objects sin duplicados;
- Bindings válidos;
- Dependency IDs únicos.

Primary Runtime Object debe ser una instancia válida.

## 17. Host Objects

Tipo:

```gdscript
Array[Object]
```

Reglas:

- no null;
- instance valid;
- sin duplicados;
- orden preservado;
- Array copiado;
- getter devuelve copia.

Primary Runtime Object puede aparecer una vez en Host Objects si requiere attach.

## 18. Handle no ejecutable

No expone:

- execute;
- activate;
- start_all;
- shutdown_all;
- attach;
- detach;
- release;
- dispose;
- save;
- load.

Factory conoce cleanup.

Runtime coordina sistema.

## 19. RuntimeFactoryBuildResult

### Estado

```gdscript
handle: RuntimeDeviceHandle

report: ValidationReport
```

### API

```gdscript
get_handle() -> RuntimeDeviceHandle

get_report() -> ValidationReport

is_success() -> bool
```

### Success

Requiere:

- Handle no null;
- Report no null;
- Handle válido;
- Report válido para Activation Context.

Simulation utiliza:

```gdscript
report.is_valid_for_simulation()
```

Hardware utiliza:

```gdscript
report.is_valid_for_hardware()
```

### Inmutabilidad

No expone setters.

## 20. RuntimeFactory behavior

Contrato verificado:

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

No existe clase base universal.

## 21. Factory build

Factory:

- valida Request;
- construye recursos;
- no adjunta Host Objects;
- no inicializa lifecycle;
- no publica;
- no registra subscriptions;
- no crea DeviceBus global;
- devuelve Handle completo o null;
- limpia parciales en fallo.

## 22. Factory release

La misma factory libera su producto.

Release:

- libera Primary Runtime Object;
- libera Host Objects propios;
- libera TRANSFERRED;
- preserva BORROWED;
- no coordina otros Handles;
- devuelve ValidationReport;
- tolera repetición sin double-free.

## 23. Construcción atómica

Éxito:

```text
Factory build

↓

RuntimeDeviceHandle válido

↓

RuntimeFactoryBuildResult success
```

Fallo:

```text
Factory build

↓

cleanup local

↓

TRANSFERRED liberado

↓

BORROWED preservado

↓

Handle null

↓

ValidationReport
```

No se conservan parciales vivos.

## 24. RuntimeHost behavior

Contrato verificado:

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

No existe clase base universal.

## 25. RuntimeHost recibe Handle

No recibe solamente Array de Objects.

Handle conserva:

- Device ID;
- Factory Key;
- grouping;
- provenance;
- ownership.

RuntimeHost consulta:

```gdscript
handle.get_host_objects()
```

## 26. Attach

Attach:

- valida Handle;
- procesa Host Objects en orden;
- no modifica Handle;
- no inicializa lifecycle;
- evita attach duplicado;
- revierte parcialmente si falla;
- produce ValidationReport.

## 27. Detach

Detach:

- procesa Host Objects en orden inverso;
- tolera Handle no adjunto;
- no libera BORROWED;
- no sustituye factory release;
- produce ValidationReport.

## 28. Rollback local de Host

Verificado:

```text
attach primer Host Object

↓

fallo controlado

↓

detach del objeto ya adjunto

↓

Handle no registrado como attached
```

RuntimeHost no ejecuta release.

## 29. Rollback global

Simulación de contrato:

```text
build A

build B

build C

build D falla
```

Rollback:

```text
detach C
release C

detach B
release B

detach A
release A
```

Resultado verificado:

- orden inverso;
- cero Handles adjuntos;
- objetos runtime liberados;
- no double cleanup.

## 30. DeviceBus

DeviceBus pertenece a CompositionRuntime.

Factory no crea Bus global.

Factory no usa autoload.

Factory build produce estado equivalente a:

```text
CREATED
```

DeviceBus se entregará durante initialize coordinado.

## 31. RuntimeFactoryRegistry futuro

Resolverá:

```text
RuntimeFactoryKey

→

RuntimeFactory
```

Debe validar behavior:

- build;
- release.

Mutabilidad requiere diseño propio.

No se implementa dentro de este milestone.

## 32. CompositionPlan futuro

Conservará:

- RuntimeFactoryKeys;
- dependency directives;
- lifecycle order;
- runtime policies;
- communication directives.

No conservará:

- RuntimeFactory;
- Callable;
- Handle;
- Device activo;
- Node activo;
- DeviceBus activo.

## 33. RuntimeHost concreto futuro

Los contratos base utilizan Object.

No dependen de:

- Node;
- Node3D;
- SceneTree;
- World3D;
- physics server.

Una implementación futura adaptará Host Objects.

## 34. Pruebas unitarias

### RuntimeFactoryKeyTest

```text
Checks: 24
Failures: 0
RESULT: PASS
```

### RuntimeDependencyBindingTest

```text
Checks: 23
Failures: 0
RESULT: PASS
```

### RuntimeConstructionRequestTest

```text
Checks: 29
Failures: 0
RESULT: PASS
```

### RuntimeDeviceHandleTest

```text
Checks: 35
Failures: 0
RESULT: PASS
```

### RuntimeFactoryBuildResultTest

```text
Checks: 21
Failures: 0
RESULT: PASS
```

## 35. Prueba de integración

### RuntimeConstructionContractIntegrationTest

```text
Checks: 41
Failures: 0
RESULT: PASS
```

Cobertura:

- build exitoso;
- Request válido;
- Handle completo;
- Host Objects no adjuntos;
- BORROWED preservado;
- TRANSFERRED liberado;
- release;
- release idempotente;
- build failure;
- cleanup local;
- attach;
- detach;
- attach idempotente;
- detach idempotente;
- partial attach rollback;
- reverse global rollback;
- behavior contracts.

## 36. Baseline Runtime Construction

```text
Tests: 6
Checks: 173
Failures: 0
```

## 37. Regresión global

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

## 38. Soporte de pruebas

### RuntimeTestObject

Registra:

- attach count;
- detach count;
- release count.

### RuntimeTestFactory

Verifica:

- build;
- controlled failure;
- TRANSFERRED cleanup;
- BORROWED preservation;
- Handle creation;
- release;
- repeated release;
- release order.

### RuntimeTestHost

Verifica:

- attach;
- detach;
- idempotencia;
- partial rollback;
- order.

No representan producción.

## 39. Códigos conceptuales

Factory Key:

```text
runtime_factory_profile_id_missing

runtime_factory_profile_version_invalid

runtime_factory_activation_context_invalid
```

Dependency Binding:

```text
runtime_dependency_id_missing

runtime_dependency_value_missing

runtime_dependency_ownership_invalid
```

Construction Request:

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

Handle:

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

Las primitivas actuales utilizan `is_valid()`.

Compilers posteriores producirán Issues estructurados.

## 40. Transaccionalidad

Crear Request no transfiere ownership.

Invocar build comienza transacción.

Build exitoso produce Handle.

Build fallido limpia localmente.

Runtime adquiere Handle exitoso.

Fallo global produce rollback inverso.

Last Known Good cambia únicamente después de commit completo.

## 41. Determinismo

Se conserva orden de:

- Dependency Bindings;
- Host Objects;
- Handles;
- attach;
- detach;
- release;
- rollback.

No se depende de:

- filesystem;
- SceneTree discovery;
- latest;
- fallback;
- singleton mutable.

## 42. Baselines preservadas

No se modificaron:

```text
DeviceLifecycleTest

DeviceCoreContractTest

SystemProfileCompilerTest

DeviceCatalogCompilerTest

DeviceGraphAssemblerTest

SystemProfileCatalogGraphAssemblyIntegrationTest
```

Runtime Construction utiliza pruebas sucesoras.

## 43. Commit

Implementación:

```text
4147ec4
feat(runtime):
add runtime construction contracts
```

## 44. Orden de implementación

```text
1. RuntimeFactoryKey.
   COMPLETADO.

2. RuntimeFactoryKeyTest.
   PASS — 24 checks.

3. RuntimeDependencyBinding.
   COMPLETADO.

4. RuntimeDependencyBindingTest.
   PASS — 23 checks.

5. RuntimeConstructionRequest.
   COMPLETADO.

6. RuntimeConstructionRequestTest.
   PASS — 29 checks.

7. RuntimeDeviceHandle.
   COMPLETADO.

8. RuntimeDeviceHandleTest.
   PASS — 35 checks.

9. RuntimeFactoryBuildResult.
   COMPLETADO.

10. RuntimeFactoryBuildResultTest.
	PASS — 21 checks.

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

16. Actualizar Core Architecture.
	PENDIENTE EN CIERRE DOCUMENTAL.

17. Actualizar Project Handoff.
	PENDIENTE EN CIERRE DOCUMENTAL.

18. Cerrar Runtime Construction Contract.
	COMPLETADO FUNCIONALMENTE.

19. Diseñar RuntimeFactoryRegistry.
	SIGUIENTE.

20. Diseñar CompositionPlan.
	SIGUIENTE.
```

## 45. Criterios de aceptación

1. RuntimeFactoryKey inmutable.

2. Key exacta.

3. Sin fallback.

4. Binding inmutable.

5. Value Object.

6. Ownership explícito.

7. BORROWED probado.

8. TRANSFERRED probado.

9. Request inmutable.

10. Dependencies pre-resueltas.

11. Request no es service locator.

12. Request valida Configuration.

13. Handle válido.

14. Host Objects preservados.

15. Factory construct-only.

16. Factory build y release.

17. Build atómico.

18. Failure Handle null.

19. Failure cleanup.

20. RuntimeHost attach/detach.

21. Partial rollback.

22. Reverse rollback.

23. DeviceBus no global.

24. Result defensivo.

25. Pruebas unitarias PASS.

26. Integración PASS.

27. Run All PASS.

Estado:

```text
TODOS LOS CRITERIOS SATISFECHOS
```

## 46. Fuera de alcance

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

## 47. Consecuencias

Positivas:

- factory contract explícito;
- ownership claro;
- dependencies pre-resueltas;
- no service locator;
- Host Objects soportados;
- cleanup delegado a factory;
- rollback coordinable;
- Plan puede permanecer declarativo;
- Registry separado de Catalog.

Negativas:

- cinco clases nuevas;
- behaviors adicionales;
- factories requieren build y release;
- ownership transferido exige disciplina;
- no se utiliza Callable como atajo.

Consecuencias aceptadas.

## 48. Estado

```text
RUNTIME CONSTRUCTION CONTRACT 1.0

IMPLEMENTADO

VERIFICADO

BASELINE ACEPTADA
```

Baseline:

```text
6 tests
173 checks
0 failures
```

Siguiente milestone:

```text
RuntimeFactoryRegistry Design

+

CompositionPlan Design
```

Ambos deben definirse antes de CompositionCompiler.
