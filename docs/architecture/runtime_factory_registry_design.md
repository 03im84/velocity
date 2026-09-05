# RuntimeFactoryRegistry — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 04/09/2026 |
| ADR relacionados | ADR-009 — System Composition Pipeline; ADR-010 — Runtime Construction and Factory Binding |
| Alcance | Declaración, validación y resolución exacta de RuntimeFactories |

## 1. Propósito

RuntimeFactoryRegistry proporciona una vista estable e inmutable de RuntimeFactories.

Responsabilidad:

> Resolver RuntimeFactory mediante RuntimeFactoryKey exacta.

RuntimeFactoryRegistry permite que:

- CompositionCompiler valide disponibilidad;
- CompositionPlan conserve Keys;
- CompositionRuntime resuelva factories;
- dependencias requeridas sean conocidas antes de build;
- compile y runtime observen un conjunto estable.

RuntimeFactoryRegistry no ejecuta factories.

## 2. Pipeline

```text
RuntimeFactoryRegistryDraft
		│
		▼
RuntimeFactoryRegistryCompiler
		│
		▼
RuntimeFactoryRegistry
```

Contenido:

```text
RuntimeFactoryDescriptor
		│
		├── RuntimeFactoryKey
		├── RuntimeFactory Object
		└── RuntimeDependencySpecs
```

## 3. Decisión de mutabilidad

RuntimeFactoryRegistry utiliza:

```text
Draft

↓

Compiler

↓

Snapshot inmutable
```

El Registry final no expone:

- register;
- unregister;
- replace;
- clear.

Razón:

La factory resuelta durante CompositionCompiler debe conservar el mismo significado durante CompositionRuntime.

## 4. Identidad del Registry

RuntimeFactoryRegistry 1.0 no tiene:

- Registry ID;
- Registry Version;
- content hash;
- filename canónico;
- host target.

La identidad pertenece a cada RuntimeFactoryKey.

Registry es una vista de resolución, no un artefacto persistente monolítico.

## 5. Identidad de factory

RuntimeFactoryKey utiliza:

```text
Profile ID

+

Profile Version

+

Activation Context
```

No existe:

- latest;
- fallback;
- nearest;
- compatible;
- sustitución de contexto;
- sustitución de versión.

## 6. Componentes

```text
core/runtime/
├── runtime_dependency_spec.gd
├── runtime_factory_descriptor.gd
├── runtime_factory_registry_draft.gd
├── runtime_factory_registry.gd
├── runtime_factory_registry_compile_result.gd
└── runtime_factory_registry_compiler.gd
```

## 7. Pruebas

```text
test/core/runtime/
├── RuntimeDependencySpecTest.tscn
├── runtime_dependency_spec_test.gd
├── RuntimeFactoryDescriptorTest.tscn
├── runtime_factory_descriptor_test.gd
├── RuntimeFactoryRegistryDraftTest.tscn
├── runtime_factory_registry_draft_test.gd
├── RuntimeFactoryRegistryCompilerTest.tscn
└── runtime_factory_registry_compiler_test.gd
```

Integración futura:

```text
CompositionPlanRuntimeFactoryRegistryIntegrationTest
```

## 8. Dependencias permitidas

```text
RuntimeFactoryKey

RuntimeDependencyBinding.Ownership

RuntimeConstructionRequest

RuntimeFactoryBuildResult

RuntimeDeviceHandle

ValidationIssue

ValidationReport

Object
```

## 9. Dependencias prohibidas

```text
DeviceCatalog

DeviceProfile storage

DeviceGraphDraft

SystemProfileDraft

CompositionRuntime

DeviceBus activo

SceneTree

filesystem

JSON

GraphEditor

hardware adapters concretos
```

Registry puede ser recibido por CompositionCompiler y CompositionRuntime.

Registry no depende de ellos.

## 10. RuntimeDependencySpec

### Archivo

```text
core/runtime/runtime_dependency_spec.gd
```

### Forma

```gdscript
extends RefCounted
class_name RuntimeDependencySpec
```

### Responsabilidad

> Declarar una dependencia requerida por una RuntimeFactory sin contener su valor activo.

### Estado

```gdscript
var _dependency_id: StringName

var _ownership: int
```

### Ownership

Utiliza valores canónicos:

```gdscript
RuntimeDependencyBinding.Ownership.BORROWED

RuntimeDependencyBinding.Ownership.TRANSFERRED
```

### Construcción

```gdscript
RuntimeDependencySpec.new(
	dependency_id,
	ownership
)
```

### API

```gdscript
get_dependency_id() -> StringName

get_ownership() -> int

is_borrowed() -> bool

is_transferred() -> bool

is_valid() -> bool
```

### Validación

- Dependency ID no vacío;
- Ownership válido.

### Dependencias obligatorias

Todas las RuntimeDependencySpecs de 1.0 son obligatorias.

No existe:

- optional flag;
- fallback value;
- default Object;
- lazy dependency;
- dynamic discovery.

### No Value

RuntimeDependencySpec no contiene:

```text
Object

Resource

Node

Provider activo
```

El valor aparece posteriormente en RuntimeDependencyBinding.

### Inmutabilidad

No expone setters.

## 11. Spec y Binding

```text
RuntimeDependencySpec

declaración:
qué se necesita.
```

```text
RuntimeDependencyBinding

resolución:
qué Object satisface
la dependencia.
```

Flujo:

```text
RuntimeFactoryDescriptor
		│
		▼
RuntimeDependencySpec
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
RuntimeDependencyBinding
		│
		▼
RuntimeConstructionRequest
```

## 12. RuntimeFactoryDescriptor

### Archivo

```text
core/runtime/runtime_factory_descriptor.gd
```

### Forma

```gdscript
extends RefCounted
class_name RuntimeFactoryDescriptor
```

### Responsabilidad

> Asociar RuntimeFactoryKey, factory behavior y dependency requirements.

### Estado

```gdscript
var _factory_key: RuntimeFactoryKey

var _factory: Object

var _dependency_specs: Array[RuntimeDependencySpec]
```

### Construcción

```gdscript
RuntimeFactoryDescriptor.new(
	factory_key,
	factory,
	dependency_specs
)
```

El Array se copia.

### API

```gdscript
get_factory_key() -> RuntimeFactoryKey

get_factory() -> Object

get_dependency_specs() -> Array[RuntimeDependencySpec]

get_dependency_spec(
	dependency_id: StringName
) -> RuntimeDependencySpec

has_dependency(
	dependency_id: StringName
) -> bool

is_valid() -> bool
```

## 13. Descriptor validation

Debe comprobar:

- Factory Key no null;
- Factory Key válida;
- Factory Object no null;
- Factory Object instance válida;
- factory expone `build`;
- factory expone `release`;
- Dependency Spec no null;
- Dependency Spec válida;
- Dependency IDs únicas.

No ejecuta `build()` para validar registro.

No ejecuta `release()`.

## 14. Factory behavior

Factory Object debe exponer:

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

GDScript permite comprobar presencia mediante:

```gdscript
has_method()
```

RuntimeFactoryDescriptor 1.0 no utiliza reflection compleja para validar tipos de argumentos o retorno.

La prueba de integración valida comportamiento real.

## 15. Mismo factory Object bajo varias Keys

Permitido:

```text
Factory Object A
	├── Profile X@1 + Simulation
	├── Profile X@2 + Simulation
	└── Profile X@1 + Hardware
```

Cada RuntimeFactoryDescriptor es explícito.

Solo RuntimeFactoryKey duplicada es error.

Una factory compartida debe ser segura para ese uso.

RuntimeFactoryRegistry no infiere soporte automáticamente.

## 16. RuntimeFactoryRegistryDraft

### Archivo

```text
core/runtime/runtime_factory_registry_draft.gd
```

### Forma

```gdscript
extends RefCounted
class_name RuntimeFactoryRegistryDraft
```

### Responsabilidad

> Representar una colección editable de RuntimeFactoryDescriptors.

### Estado

```gdscript
var descriptors: Array[RuntimeFactoryDescriptor] = []
```

### Draft vacío

Puede compilar a Registry vacío válido.

### Estado incompleto

Puede contener:

- Descriptor válido;
- Descriptor null;
- Descriptor inválido;
- Key duplicada;
- misma factory con Keys diferentes.

Compiler establece validez.

### No responsabilidades

Draft no:

- resuelve;
- ejecuta;
- valida;
- abre archivos;
- crea Devices;
- modifica factories.

## 17. RuntimeFactoryRegistry

### Archivo

```text
core/runtime/runtime_factory_registry.gd
```

### Forma

```gdscript
extends RefCounted
class_name RuntimeFactoryRegistry
```

### Responsabilidad

> Resolver RuntimeFactoryDescriptor y RuntimeFactory mediante Key exacta.

### Estado

```gdscript
var _descriptors: Array[RuntimeFactoryDescriptor] = []

var _descriptors_by_profile: Dictionary = {}
```

Índice conceptual:

```text
Profile ID
	│
	└── Profile Version
			│
			└── Activation Context
					│
					└── RuntimeFactoryDescriptor
```

No utiliza key string concatenada.

## 18. Registry API

```gdscript
get_descriptors() -> Array[RuntimeFactoryDescriptor]
```

```gdscript
has_factory(
	factory_key: RuntimeFactoryKey
) -> bool
```

```gdscript
get_factory(
	factory_key: RuntimeFactoryKey
) -> Object
```

```gdscript
get_descriptor(
	factory_key: RuntimeFactoryKey
) -> RuntimeFactoryDescriptor
```

```gdscript
is_valid() -> bool
```

## 19. Lookup exacto

Si Key es null o inválida:

```text
has_factory:
false

get_factory:
null

get_descriptor:
null
```

Si Profile ID existe, pero versión no:

```text
false / null
```

Si ID y versión existen, pero contexto no:

```text
false / null
```

No existe fallback.

## 20. Registry vacío

Registry vacío es válido.

```text
get_descriptors:
[]

has_factory:
false

get_factory:
null

get_descriptor:
null
```

CompositionCompiler podrá producir error si Graph requiere una Key ausente.

## 21. Registry inmutable

No expone:

```text
register_factory

unregister_factory

replace_factory

clear

set_descriptors
```

Para cambiar bindings:

```text
editar Draft

↓

compilar nuevo Registry

↓

sustituir referencia en éxito
```

## 22. Orden

`get_descriptors()` conserva orden del Draft.

El índice no cambia orden.

Una misma entrada siempre resuelve el mismo Descriptor y factory Object.

## 23. RuntimeFactoryRegistry.is_valid()

Comprueba:

- Descriptor no null;
- Descriptor válido;
- RuntimeFactoryKey única;
- índice coherente;
- cantidad indexada coherente;
- referencia resuelta coincide;
- orden del Array preservado.

No ejecuta factories.

## 24. RuntimeFactoryRegistryCompileResult

### Archivo

```text
core/runtime/runtime_factory_registry_compile_result.gd
```

### Forma

```gdscript
extends RefCounted
class_name RuntimeFactoryRegistryCompileResult
```

### Estado

```gdscript
var _registry: RuntimeFactoryRegistry

var _report: ValidationReport
```

### API

```gdscript
get_registry() -> RuntimeFactoryRegistry

get_report() -> ValidationReport

is_success() -> bool
```

### Success

Requiere:

- Registry no null;
- Report no null;
- Report válido para Simulation;
- Registry válido.

Registry es una colección de bindings para varios contextos.

No activa Hardware.

### Inmutabilidad

No expone setters.

## 25. RuntimeFactoryRegistryCompiler

### Archivo

```text
core/runtime/runtime_factory_registry_compiler.gd
```

### Forma

```gdscript
extends RefCounted
class_name RuntimeFactoryRegistryCompiler
```

### Responsabilidad

> Validar Draft y producir RuntimeFactoryRegistry inmutable.

### API

```gdscript
compile(
	draft: RuntimeFactoryRegistryDraft
) -> RuntimeFactoryRegistryCompileResult
```

### Orden

```text
1. Draft no null.

2. Descriptor en orden.

3. Descriptor no null.

4. Descriptor válido.

5. Key única.

6. Crear Registry.

7. Validar Registry defensivamente.
```

### No mutación

Compiler no modifica:

- Draft;
- Descriptor Array;
- Keys;
- factories;
- Dependency Specs.

## 26. Duplicate Key

Una Key duplicada produce:

```text
STRUCTURAL_ERROR

code:
duplicate_runtime_factory_key
```

Se rechaza incluso si ambos Descriptors contienen la misma factory.

No existe overwrite.

## 27. Validaciones

### Draft null

```text
STRUCTURAL_ERROR

code:
runtime_factory_registry_draft_missing
```

### Descriptor null

```text
STRUCTURAL_ERROR

code:
runtime_factory_descriptor_missing
```

### Descriptor inválido

```text
STRUCTURAL_ERROR

code:
runtime_factory_descriptor_invalid
```

### Key duplicada

```text
STRUCTURAL_ERROR

code:
duplicate_runtime_factory_key
```

### Snapshot inválido

```text
STRUCTURAL_ERROR

code:
runtime_factory_registry_snapshot_invalid
```

## 28. Behavior incompleto

RuntimeFactoryDescriptor inválido cuando factory no expone:

```text
build

release
```

Compiler reporta:

```text
runtime_factory_descriptor_invalid
```

Los tests del Descriptor verifican cuál método falta.

## 29. Transaccionalidad

Compilación fallida:

- no modifica Draft;
- no modifica factories;
- no produce Registry;
- no sobrescribe Registry anterior;
- devuelve ValidationReport.

Last Known Good se sustituye externamente solo en éxito.

## 30. Estabilidad

Registry final es inmutable.

CompositionCompiler y CompositionRuntime pueden compartir la misma instancia.

Para la misma Key:

```text
has_factory

get_descriptor

get_factory
```

observan el mismo estado.

## 31. Separación de DeviceCatalog

```text
DeviceCatalog

RuntimeFactoryKey sin contexto runtime:
Profile ID + Profile Version

→ DeviceProfile
```

```text
RuntimeFactoryRegistry

Profile ID + Profile Version
+ Activation Context

→ RuntimeFactory
```

DeviceCatalog no contiene factories.

Registry no almacena DeviceProfile como autoridad.

## 32. Separación de CompositionPlan

Registry contiene factories ejecutables.

Plan contiene RuntimeFactoryKeys.

Plan no contiene Registry.

Plan no contiene factory.

CompositionRuntime recibe ambos.

## 33. No ejecución

Registry no invoca:

```text
build

release
```

durante:

- construcción;
- compilación;
- lookup;
- validación.

Solo devuelve referencias.

## 34. Persistencia

RuntimeFactoryRegistry 1.0 no abre:

- `.tres`;
- JSON;
- scripts por path;
- directorios;
- red.

Factory registration persistente requiere otro diseño.

## 35. Seguridad

Factory Object se valida como instancia viva.

No se acepta null.

No se ejecuta código durante validación.

No existe selección aproximada.

No se reemplaza factory silenciosamente.

## 36. Estrategia de pruebas

### RuntimeDependencySpecTest

Verifica:

- BORROWED;
- TRANSFERRED;
- ID vacío;
- ownership inválido;
- getters;
- ausencia de Value;
- ausencia de setters.

### RuntimeFactoryDescriptorTest

Verifica:

- Key null;
- Key inválida;
- factory null;
- factory sin build;
- factory sin release;
- Spec null;
- Spec inválida;
- Dependency ID duplicada;
- Descriptor válido;
- Arrays independientes;
- lookups;
- ausencia de ejecución.

### RuntimeFactoryRegistryDraftTest

Verifica:

- Array vacío;
- Array editable;
- null permitido en Draft;
- misma factory con varias Keys;
- no resolver;
- no ejecutar;
- no persistencia.

### RuntimeFactoryRegistryCompilerTest

Verifica:

- Draft null;
- Descriptor null;
- Descriptor inválido;
- duplicate Key;
- misma factory bajo Keys distintas;
- varias versiones;
- varios contextos;
- Registry vacío;
- compilación válida;
- orden;
- lookup exacto;
- versión faltante;
- contexto faltante;
- Arrays independientes;
- Draft posterior;
- Result defensivo;
- Registry sin mutaciones;
- Registry sin latest;
- Registry sin ejecución.

## 37. Integración futura

Después de CompositionPlan se creará:

```text
CompositionPlanRuntimeFactoryRegistryIntegrationTest
```

Verificará:

- cada Device Entry conserva Key;
- Registry resuelve Key;
- Plan no contiene factory;
- misma factory puede resolver varias Keys;
- contexto incorrecto falla;
- no fallback;
- no ejecución durante validación.

## 38. Baselines preservadas

No se modifican:

```text
RuntimeFactoryKeyTest

RuntimeDependencyBindingTest

RuntimeConstructionRequestTest

RuntimeDeviceHandleTest

RuntimeFactoryBuildResultTest

RuntimeConstructionContractIntegrationTest
```

Registry utiliza pruebas sucesoras.

## 39. Orden de implementación

```text
1. Implementar RuntimeDependencySpec.

2. Ejecutar RuntimeDependencySpecTest.

3. Implementar RuntimeFactoryDescriptor.

4. Ejecutar RuntimeFactoryDescriptorTest.

5. Implementar RuntimeFactoryRegistryDraft.

6. Ejecutar RuntimeFactoryRegistryDraftTest.

7. Implementar RuntimeFactoryRegistry.

8. Implementar CompileResult.

9. Implementar Compiler.

10. Ejecutar RuntimeFactoryRegistryCompilerTest.

11. Ejecutar Run All.

12. Registrar baseline.

13. Diseñar CompositionPlan.

14. Integrar Plan y Registry.

15. Diseñar CompositionCompiler.
```

## 40. Criterios de aceptación

1. RuntimeDependencySpec inmutable.

2. Specs obligatorias.

3. Descriptor inmutable.

4. Descriptor valida Key.

5. Descriptor valida factory.

6. Descriptor valida build.

7. Descriptor valida release.

8. Descriptor valida Specs.

9. Dependency IDs únicas.

10. Draft editable.

11. Registry inmutable.

12. Registry vacío válido.

13. Lookup exacto.

14. Varias versiones permitidas.

15. Varios contextos permitidos.

16. Duplicate Key rechazado.

17. Misma factory bajo varias Keys permitida.

18. Sin overwrite.

19. Sin latest.

20. Sin fallback.

21. Orden preservado.

22. Arrays independientes.

23. Compiler no modifica Draft.

24. Registry no ejecuta factories.

25. Registry no depende de DeviceCatalog.

26. Registry no depende de CompositionPlan.

27. Result defensivo.

28. Pruebas sucesoras PASS.

29. Run All PASS.

## 41. Fuera de alcance

RuntimeFactoryRegistry 1.0 no implementará:

- CompositionPlan;
- CompositionCompiler;
- CompositionRuntime;
- factory execution;
- Device creation;
- RuntimeHost;
- persistence;
- script loading;
- plugin discovery;
- host target;
- latest;
- compatibility ranges;
- factory priority;
- factory replacement;
- hot reload;
- hardware activation.

## 42. Consecuencias positivas

- factories explícitas;
- dependencies declaradas;
- resolución exacta;
- estabilidad;
- múltiples versiones;
- múltiples contextos;
- Plan no ejecutable;
- Catalog separado;
- pruebas aisladas.

## 43. Consecuencias negativas

- seis componentes adicionales;
- Registry debe recompilarse para cambiar;
- no existe plugin loading;
- no existe latest;
- behavior signature se prueba por integración;
- no se ejecuta factory para validarla.

Estas consecuencias son aceptadas.

## 44. Invariantes

1. Key es exacta.

2. Spec no contiene Value.

3. Descriptor asocia Key, factory y Specs.

4. Factory expone build y release.

5. Key única por Registry.

6. Misma factory puede tener varias Keys.

7. Registry es inmutable.

8. Registry no ejecuta.

9. Registry no contiene DeviceProfile como autoridad.

10. Registry no forma parte del Plan.

11. Plan guarda Key.

12. No existe fallback.

13. No existe overwrite.

14. Orden se conserva.

15. Persistencia es externa.

## 45. Estado

```text
DISEÑO ACTIVO
```

RuntimeFactoryRegistry 1.0 está autorizado para implementación incremental.

Primer componente:

```text
RuntimeDependencySpec
```

CompositionPlan permanece pendiente de su documento de diseño completo.