# DeviceCatalog — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Fecha | 23/08/2026 |
| ADR relacionado | ADR-009 — System Composition Pipeline |
| Alcance | Resolución exacta e inmutable de DeviceProfiles |

## 1. Propósito

DeviceCatalog proporciona una vista estable de DeviceProfile snapshots.

Responsabilidad:

> Resolver DeviceProfile mediante Profile ID y Profile Version exactos.

DeviceCatalog permite que:

- SystemProfileCompiler verifique dependencias;
- DeviceGraphAssembler resuelva Profiles;
- herramientas consulten Profiles disponibles;
- varias versiones coexistan;
- una operación de compilación observe un conjunto estable.

DeviceCatalog no representa runtime ni persistencia.

DeviceCatalog 1.0 está implementado y verificado.

## 2. Problema

El contrato DeviceProfileResolver está definido por comportamiento:

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

Las primeras pruebas de SystemProfile utilizaron un resolver controlado.

Producción necesitaba una implementación que:

- validara Profiles;
- rechazara duplicados exactos;
- permitiera varias versiones;
- preservara orden;
- permaneciera estable durante compilación;
- no utilizara fallback;
- no conociera factories;
- no abriera archivos.

DeviceCatalog 1.0 satisface esa necesidad.

## 3. Decisión de mutabilidad

DeviceCatalog utiliza:

```text
DeviceCatalogDraft
		│
		▼
DeviceCatalogCompiler
		│
		▼
DeviceCatalog
```

### DeviceCatalogDraft

Editable.

Puede estar incompleto.

### DeviceCatalog

Snapshot inmutable.

No permite register/remove.

### Razón

Un catálogo mutable podría cambiar mientras:

- SystemProfileCompiler resuelve dependencias;
- DeviceGraphAssembler construye Nodes;
- una herramienta enumera Profiles.

Un snapshot inmutable garantiza resolución estable.

## 4. Identidad del catálogo

DeviceCatalog 1.0 no tiene:

- Catalog ID;
- Catalog Version;
- filename canónico;
- hash;
- manifest de fuentes.

La identidad y versión pertenecen a cada DeviceProfile.

DeviceCatalog es una vista de resolución, no un artefacto persistente monolítico.

Persistencia y bundles permanecen externos.

## 5. Política de versiones

El mismo Profile ID puede coexistir con varias versiones.

Permitido:

```text
test.distance_sensor@1

test.distance_sensor@2

test.distance_sensor@3
```

Rechazado:

```text
test.distance_sensor@2

test.distance_sensor@2
```

La identidad única es:

```text
Profile ID
+
Profile Version
```

## 6. Política de duplicados

Un duplicado exacto produce:

```text
STRUCTURAL_ERROR

code:
duplicate_device_profile_identity
```

Se rechaza incluso cuando ambas entradas apuntan a la misma instancia.

No existe:

```text
last write wins

first write wins silencioso

overwrite

merge automático
```

Una compilación fallida no produce DeviceCatalog.

## 7. Resolución exacta

DeviceCatalog no implementa:

```text
latest

nearest

compatible

fallback

upgrade automático

downgrade automático
```

`has_profile()` y `get_profile()` utilizan coincidencia exacta.

Si no existe la combinación solicitada:

```text
has_profile():
false

get_profile():
null
```

## 8. Estructura implementada

### 8.1 Código

```text
core/catalog/
├── device_catalog_draft.gd
├── device_catalog.gd
├── device_catalog_compile_result.gd
└── device_catalog_compiler.gd
```

### 8.2 Pruebas

```text
test/core/catalog/
├── DeviceCatalogDraftTest.tscn
├── device_catalog_draft_test.gd
├── DeviceCatalogCompilerTest.tscn
├── device_catalog_compiler_test.gd
├── SystemProfileDeviceCatalogIntegrationTest.tscn
└── system_profile_device_catalog_integration_test.gd
```

### 8.3 Persistencia futura

```text
catalog/
├── device_catalog_document.gd
├── device_catalog_loader.gd
└── device_catalog_serializer.gd
```

Las rutas de persistencia son conceptuales y no forman parte de DeviceCatalog 1.0.

## 9. Dependencias permitidas

```text
DeviceProfile

ValidationIssue

ValidationReport
```

## 10. Dependencias no permitidas

```text
Device runtime

DeviceBus

DeviceGraph

SystemProfile

RuntimeFactoryRegistry

SceneTree

filesystem

Resource loading

JSON

GraphEditor

hardware

telemetría
```

DeviceCatalog puede entregarse a SystemProfileCompiler porque satisface el contrato DeviceProfileResolver.

DeviceCatalog no depende de SystemProfileCompiler.

## 11. DeviceCatalogDraft

### 11.1 Archivo

```text
core/catalog/device_catalog_draft.gd
```

### 11.2 Forma

```gdscript
extends RefCounted
class_name DeviceCatalogDraft
```

### 11.3 Responsabilidad

> Representar una colección editable de DeviceProfile snapshots antes de compilar un catálogo.

### 11.4 Estado

```gdscript
var profiles: Array[DeviceProfile] = []
```

### 11.5 Draft vacío

Un Draft nuevo contiene un Array vacío.

Puede compilar a un DeviceCatalog vacío válido.

### 11.6 Edición

La primera versión permite editar directamente:

```gdscript
draft.profiles
```

No añade register/remove antes de existir una necesidad de herramienta.

### 11.7 Estado incompleto

DeviceCatalogDraft puede contener:

- Array vacío;
- Profiles válidos;
- Profile null;
- Profiles duplicados;
- varias versiones.

El Compiler establece la frontera de validez.

### 11.8 No responsabilidades

DeviceCatalogDraft no:

- valida;
- resuelve dependencias;
- abre archivos;
- crea Devices;
- conoce factories;
- construye Graph;
- ejecuta;
- guarda.

## 12. DeviceCatalog

### 12.1 Archivo

```text
core/catalog/device_catalog.gd
```

### 12.2 Forma

```gdscript
extends RefCounted
class_name DeviceCatalog
```

### 12.3 Responsabilidad

> Resolver DeviceProfile snapshots de forma exacta y estable.

### 12.4 Estado

```gdscript
var _profiles: Array[DeviceProfile] = []

var _profiles_by_id: Dictionary = {}
```

`_profiles_by_id` utiliza una estructura anidada:

```text
Profile ID
	│
	└── Profile Version
			│
			└── DeviceProfile
```

No utiliza una key concatenada con separador.

Esto evita ambigüedad entre identidad y formato interno.

### 12.5 Construcción

El constructor recibe:

```gdscript
profiles: Array[DeviceProfile]
```

Durante `_init()`:

1. duplica el Array;

2. construye el índice interno;

3. no modifica el Array recibido.

### 12.6 API

```gdscript
get_profiles() -> Array[DeviceProfile]
```

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
is_valid() -> bool
```

### 12.7 API deliberadamente ausente

DeviceCatalog no expone:

```text
register_profile()

remove_profile()

replace_profile()

get_latest()

get_compatible()

load()

save()

create_device()

get_factory()
```

### 12.8 Colecciones

`get_profiles()` devuelve un Array nuevo.

Los DeviceProfiles se comparten por referencia porque son snapshots inmutables por contrato.

### 12.9 Orden

`get_profiles()` conserva el orden de entrada del Draft.

El índice no modifica ese orden.

### 12.10 Catálogo vacío

Un DeviceCatalog vacío es válido.

```text
get_profiles():
[]

has_profile():
false

get_profile():
null
```

## 13. Índice interno

El índice se construye conceptualmente así:

```text
profiles_by_id[profile_id][profile_version] = profile
```

Un Profile ID puede tener múltiples versiones.

Ejemplo:

```text
test.distance_sensor
	├── 1 → DeviceProfile v1
	├── 2 → DeviceProfile v2
	└── 3 → DeviceProfile v3
```

No se exponen Dictionaries internos.

Cuando una construcción directa contiene duplicados, el índice conserva la primera entrada y el Catalog resulta inválido.

No existe overwrite.

## 14. DeviceCatalog.is_valid()

`is_valid()` comprueba:

- Profile no null;
- Profile válido;
- Profile ID no vacío;
- Profile Version positiva;
- identidad exacta no duplicada;
- índice coherente con el Array;
- cantidad indexada coherente;
- orden del Array no alterado.

`is_valid()` no comprueba:

- filesystem;
- disponibilidad de runtime factory;
- DeviceConfiguration;
- DeviceGraph;
- hardware;
- compatibilidad semántica entre versiones.

## 15. DeviceCatalogCompileResult

### 15.1 Archivo

```text
core/catalog/device_catalog_compile_result.gd
```

### 15.2 Forma

```gdscript
extends RefCounted
class_name DeviceCatalogCompileResult
```

### 15.3 Estado

```gdscript
var _catalog: DeviceCatalog

var _report: ValidationReport
```

### 15.4 API

```gdscript
get_catalog() -> DeviceCatalog

get_report() -> ValidationReport

is_success() -> bool
```

### 15.5 Success

`is_success()` requiere:

```text
Catalog no null;

Report no null;

Report válido para Simulation;

Catalog válido.
```

DeviceCatalog es neutral respecto a Activation Context.

No activa Simulation o Hardware.

### 15.6 Defensa

Un Report válido no puede aprobar:

- Catalog null;
- Catalog con Profiles null;
- Catalog con duplicados;
- Catalog incoherente.

### 15.7 Inmutabilidad

No expone setters.

## 16. DeviceCatalogCompiler

### 16.1 Archivo

```text
core/catalog/device_catalog_compiler.gd
```

### 16.2 Forma

```gdscript
extends RefCounted
class_name DeviceCatalogCompiler
```

### 16.3 Responsabilidad

> Validar DeviceCatalogDraft y producir DeviceCatalog snapshot.

### 16.4 API

```gdscript
compile(
	draft: DeviceCatalogDraft
) -> DeviceCatalogCompileResult
```

### 16.5 Orden de validación

```text
1. Draft no null.

2. Profiles en orden de entrada.

3. Profile no null.

4. Profile válido.

5. Identity no duplicada.

6. Crear Catalog.

7. Validar Catalog defensivamente.
```

### 16.6 No mutación

Compiler no modifica:

- Draft;
- Array del Draft;
- DeviceProfiles;
- orden.

## 17. Validaciones

### 17.1 Draft null

```text
STRUCTURAL_ERROR

code:
device_catalog_draft_missing
```

### 17.2 Profile null

```text
STRUCTURAL_ERROR

code:
device_catalog_profile_missing
```

### 17.3 Profile inválido

```text
STRUCTURAL_ERROR

code:
device_catalog_profile_invalid
```

### 17.4 Identidad duplicada

```text
STRUCTURAL_ERROR

code:
duplicate_device_profile_identity
```

### 17.5 Snapshot defensivo inválido

```text
STRUCTURAL_ERROR

code:
device_catalog_snapshot_invalid
```

## 18. Profiles canónicos y derivados

DeviceCatalog acepta:

- canonical DeviceProfiles;
- derived DeviceProfiles;
- user DeviceProfiles;
- test DeviceProfiles.

La condición es que el snapshot sea válido.

DeviceCatalog no decide precedencia mediante:

- canonical flag;
- parent ID;
- origen del archivo;
- directorio;
- nombre de usuario.

La identidad exacta continúa siendo autoridad.

## 19. Parent references

DeviceProfile puede conservar referencia a parent.

DeviceCatalog 1.0 no resuelve herencia.

La compilación de DeviceProfile debe ocurrir antes de entrar al catálogo.

DeviceCatalog almacena snapshots ya validados.

## 20. Persistencia externa

DeviceCatalog no abre:

- `.tres`;
- JSON;
- directorios;
- paquetes;
- red.

Flujo futuro:

```text
DeviceProfile Documents
		│
		▼
DeviceCatalogLoader
		│
		▼
DeviceCatalogDraft
		│
		▼
DeviceCatalogCompiler
		│
		▼
DeviceCatalog
```

Loader y formato persistente se diseñarán después.

## 21. Relación con DeviceProfileResolver

DeviceCatalog satisface directamente:

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

Por tanto, puede entregarse a:

```text
SystemProfileCompiler

DeviceGraphAssembler
```

sin que esos componentes dependan de la clase concreta.

## 22. Relación con RuntimeFactoryRegistry

DeviceCatalog y RuntimeFactoryRegistry permanecen separados.

```text
DeviceCatalog:
DeviceProfile snapshots.

RuntimeFactoryRegistry:
factories ejecutables.
```

DeviceCatalog no contiene:

- Callable;
- script path;
- scene path;
- class constructor;
- hardware adapter;
- runtime instance.

## 23. Transaccionalidad

Una compilación fallida:

- no modifica Draft;
- no produce Catalog;
- no sobrescribe un Catalog anterior;
- devuelve ValidationReport;
- preserva Last Known Good externo.

Para añadir un Profile:

```text
copiar o editar Draft

↓

compilar nuevo Catalog

↓

sustituir referencia únicamente en éxito
```

## 24. Estabilidad de resolución

DeviceCatalog es inmutable.

Durante una compilación:

```text
has_profile(id, version)
```

y:

```text
get_profile(id, version)
```

observan el mismo estado.

No existe mutación concurrente mediante API pública.

La integración con SystemProfileCompiler verifica esta propiedad después de modificar el Draft original.

## 25. Determinismo

Para el mismo Array de DeviceProfiles:

- el orden de `get_profiles()` es igual;
- los lookups exactos son iguales;
- los duplicados producen los mismos Issues;
- el Report conserva orden de entrada;
- no depende de filesystem.

## 26. Estrategia de pruebas

### DeviceCatalogDraftTest

Verifica:

- Draft es RefCounted;
- Draft no es Node;
- Array inicial vacío;
- Array editable;
- acepta Profile null como estado Draft;
- permite varias versiones;
- no tiene runtime;
- no tiene persistencia.

### DeviceCatalogCompilerTest

Verifica:

- Draft null;
- Profile null;
- Profile inválido;
- identidad duplicada;
- misma instancia duplicada;
- mismo ID y distinta versión permitido;
- IDs diferentes y misma versión permitido;
- Catalog vacío;
- compilación válida;
- orden preservado;
- `has_profile()` exacto;
- `get_profile()` exacto;
- versión faltante devuelve null;
- ID faltante devuelve null;
- Arrays independientes;
- Draft posterior no cambia Catalog;
- Result defensivo;
- Catalog sin setters;
- Catalog sin register/remove;
- Catalog sin latest;
- Catalog sin factories;
- Catalog sin filesystem.

### SystemProfileDeviceCatalogIntegrationTest

Verifica:

- DeviceCatalog satisface DeviceProfileResolver;
- SystemProfileCompiler acepta DeviceCatalog;
- dependencias exactas se resuelven;
- versión faltante no utiliza fallback;
- varias versiones coexisten;
- versión solicitada se conserva;
- Catalog permanece estable;
- SystemProfileCompiler no modifica Catalog.

### 26.1 Baselines aceptadas

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

Regresión completa:

```text
Tests: 46
Checks: 1282
Failures: 0
Timeout: 0
Engine Error: 0
Plan ExitCode: 0
RESULT: PASS
```

## 27. Fixtures

Los tests utilizan DeviceProfiles:

```text
test.sensor@1

test.sensor@2

test.controller@1
```

También se utilizan:

- Profile canonical;
- Profile de usuario;
- Profile null;
- Profile con ID vacío;
- duplicate identity;
- misma instancia repetida.

No se utiliza filesystem.

## 28. Baselines preservadas

No se modificaron:

```text
DeviceProfileCompilerTest

BuiltinDeviceProfilesTest

SystemProfileCompilerTest

DeviceGraphNodeBuilderTest

DeviceGraphSnapshotTest
```

DeviceCatalog utiliza pruebas sucesoras independientes.

## 29. Orden de implementación

```text
1. Aceptar este diseño.
   COMPLETADO.

2. Crear core/catalog/.
   COMPLETADO.

3. Implementar DeviceCatalogDraft.
   COMPLETADO.

4. Ejecutar DeviceCatalogDraftTest.
   PASS — 14 checks.

5. Implementar DeviceCatalog.
   COMPLETADO.

6. Implementar DeviceCatalogCompileResult.
   COMPLETADO.

7. Implementar DeviceCatalogCompiler.
   COMPLETADO.

8. Ejecutar DeviceCatalogCompilerTest.
   PASS — 53 checks.

9. Crear integración sucesora con
   SystemProfileCompiler.
   COMPLETADO.

10. Ejecutar
	SystemProfileDeviceCatalogIntegrationTest.
	PASS — 22 checks.

11. Ejecutar Run All.
	PASS — 46 tests, 1282 checks.

12. Registrar baseline.
	COMPLETADO.

13. Actualizar Core Architecture.
	PENDIENTE EN COMMIT DOCUMENTAL.

14. Cerrar DeviceCatalog 1.0.
	PENDIENTE EN COMMIT DOCUMENTAL.

15. Diseñar DeviceGraphAssembler.
	SIGUIENTE.
```

## 30. Prueba de integración sucesora

Prueba:

```text
SystemProfileDeviceCatalogIntegrationTest
```

Responsabilidad:

> Verificar que SystemProfileCompiler puede resolver dependencias utilizando DeviceCatalog sin conocer su implementación concreta.

Baseline aceptada:

```text
Checks: 22
Failures: 0
RESULT: PASS
```

La integración demuestra que SystemProfileCompiler depende únicamente de:

```gdscript
has_profile()

get_profile()
```

SystemProfileCompiler no depende de la clase concreta DeviceCatalog.

La prueba anterior `SystemProfileCompilerTest` permanece inmutable.

## 31. Criterios de aceptación

1. DeviceCatalogDraft es editable.

2. DeviceCatalog es inmutable.

3. Catalog vacío es válido.

4. Profile null se rechaza durante compilación.

5. Profile inválido se rechaza.

6. Duplicado exacto se rechaza.

7. Múltiples versiones se permiten.

8. Orden se conserva.

9. `get_profiles()` devuelve copia.

10. `has_profile()` utiliza identidad exacta.

11. `get_profile()` utiliza identidad exacta.

12. No existe latest fallback.

13. No existe overwrite.

14. Catalog satisface DeviceProfileResolver.

15. Catalog no conoce factories.

16. Catalog no conoce filesystem.

17. Compiler no modifica Draft.

18. Draft posterior no modifica Catalog.

19. Result es defensivo.

20. Pruebas unitarias terminan PASS.

21. Integración con SystemProfileCompiler termina PASS.

22. Run All termina PASS.

Estado de aceptación:

```text
DEVICECATALOG 1.0
IMPLEMENTADO Y VERIFICADO
```

Todos los criterios de aceptación de DeviceCatalog 1.0 están satisfechos.

## 32. Fuera de alcance

DeviceCatalog 1.0 no implementa:

- persistencia;
- Resource loading;
- directory scanning;
- JSON;
- remote registry;
- package manager;
- marketplace;
- catalog identity;
- catalog version;
- hashes;
- bundle;
- migration;
- latest resolution;
- compatibility ranges;
- semantic versioning;
- runtime factories;
- Device creation;
- Graph assembly;
- UI;
- hardware.

## 33. Consecuencias positivas

- resolución estable;
- exactitud versionada;
- múltiples versiones;
- sin overwrite silencioso;
- pruebas aisladas;
- Core independiente de filesystem;
- SystemProfileCompiler reutilizable;
- DeviceGraphAssembler futuro reutilizable;
- separación de factories.

## 34. Consecuencias negativas

- cuatro componentes nuevos;
- añadir Profiles requiere recompilar Catalog;
- no existe carga automática;
- no existe latest;
- persistencia requiere adapters futuros;
- catálogo completo comparte referencias a snapshots inmutables.

Estas consecuencias son aceptadas.

## 35. Invariantes

1. Draft es mutable.

2. Catalog es inmutable.

3. Profiles son snapshots válidos.

4. Identidad es Profile ID + Profile Version.

5. Varias versiones pueden coexistir.

6. Duplicado exacto es Structural Error.

7. No existe overwrite.

8. No existe fallback.

9. Orden se conserva.

10. Collections devueltas son copias.

11. Resolver es exacto.

12. Catalog no crea Devices.

13. Catalog no contiene factories.

14. Catalog no abre archivos.

15. Compilación fallida no produce Catalog.

16. DeviceCatalog no tiene identidad propia en 1.0.

## 36. Estado

```text
DEVICECATALOG 1.0
IMPLEMENTADO Y VERIFICADO
```

Componentes completados:

```text
DeviceCatalogDraft

DeviceCatalog

DeviceCatalogCompileResult

DeviceCatalogCompiler
```

Integración completada:

```text
SystemProfileCompiler
+
DeviceCatalog
```

Baselines:

```text
Tests: 3
Checks: 89
Failures: 0
```

Regresión:

```text
Tests: 46
Checks: 1282
Failures: 0
```

Siguiente milestone:

```text
DeviceGraphAssembler
```

Persistencia de catálogo permanece fuera de alcance.