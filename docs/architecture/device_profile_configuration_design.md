# Device Profile and Configuration — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Fecha | 16/08/2026 |
| Estado de implementación | COMPLETO |
| Última verificación | 16/08/2026 |
| ADR relacionado | ADR-008 — Device Definitions, Profiles and Configuration |
| Alcance | Devices ideales y configuración lógica mínima |

## 1. Propósito

Este documento traduce ADR-008 a un diseño mínimo e implementable.

La primera versión define:

- DeviceRoles;
- DeviceProfileDraft;
- DeviceProfile;
- DeviceProfileCompiler;
- DeviceConfigurationDraft;
- DeviceConfiguration;
- DeviceConfigurationCompiler;
- ValidationIssue;
- ValidationReport;
- DeviceManifestBuilder;
- BuiltinDeviceProfiles;
- identidad y versionado;
- definiciones canónicas;
- derivación mediante Save As;
- relación con DeviceManifest;
- estructura física de código y assets;
- pruebas sucesoras.

La primera versión utiliza Devices ideales.

No implementa:

- hardware detallado;
- DeviceCalibration;
- AdaptationPolicy;
- RuntimeAllocation;
- GraphEditor;
- ConfigurationEditor;
- DeviceGraph;
- Hardware Mode real.

## 2. Estructura propuesta

### 2.1 Clases del Core

```text
core/profile/
├── device_roles.gd
├── device_profile_draft.gd
├── device_profile.gd
├── device_profile_compile_result.gd
├── device_profile_compiler.gd
├── device_configuration_draft.gd
├── device_configuration.gd
├── device_configuration_compile_result.gd
├── device_configuration_compiler.gd
├── validation_issue.gd
├── validation_report.gd
├── device_manifest_build_result.gd
├── device_manifest_builder.gd
├── builtin_device_profiles.gd
└── system_profile.gd
```

### 2.2 Definiciones y datos

```text
profiles/
├── device_profiles/
│   ├── canonical/
│   └── derived/
│
├── device_configurations/
│
└── system_profiles/
```

### 2.3 Separación

```text
core/profile/
```

contiene código.

```text
profiles/
```

contiene Resources y definiciones.

No se guardarán scripts de contratos dentro de `profiles/`.

La clase anterior:

```text
profiles/profile.gd
```

será retirada después de crear sucesoras.

## 3. DeviceRoles

### 3.1 Archivo previsto

```text
core/profile/device_roles.gd
```

### 3.2 Forma

```gdscript
extends RefCounted
class_name DeviceRoles
```

### 3.3 Roles iniciales

```gdscript
const SENSOR: StringName = (
	&"sensor"
)

const ACTUATOR: StringName = (
	&"actuator"
)

const LOCAL_CONTROLLER: StringName = (
	&"local_controller"
)

const SUPERVISORY_CONTROLLER: StringName = (
	&"supervisory_controller"
)
```

### 3.4 API

```gdscript
static func is_valid(
	role: StringName
) -> bool
```

```gdscript
static func get_all(
) -> Array[StringName]
```

`get_all()` devolverá un Array nuevo.

### 3.5 Responsabilidad

DeviceRoles proporciona identidades canónicas.

No:

- crea Devices;
- define jerarquías;
- controla permisos;
- genera Ports;
- valida Graph;
- ejecuta runtime.

### 3.6 Extensibilidad

Los roles utilizan StringName en lugar de un enum cerrado.

Añadir un rol nuevo requiere:

- responsabilidad definida;
- documentación;
- constante canónica;
- pruebas;
- actualización de validación.

No se permiten roles arbitrarios no registrados en DeviceRoles.

## 4. DeviceProfileDraft

### 4.1 Archivo previsto

```text
core/profile/device_profile_draft.gd
```

### 4.2 Forma

```gdscript
extends Resource
class_name DeviceProfileDraft
```

### 4.3 Responsabilidad

> Representar una definición editable de un modelo de Device que todavía no puede utilizarse como definición activa.

DeviceProfileDraft puede:

- editarse;
- estar incompleto;
- contener errores;
- validarse;
- compilarse;
- guardarse como trabajo de usuario.

No puede:

- utilizarse directamente por runtime;
- utilizarse como definición canónica activa;
- entregarse a DeviceGraph activo;
- construir un Composition Plan.

### 4.4 Estado editable

```gdscript
@export var profile_id: StringName = &""

@export var profile_version: int = 1

@export var display_name: String = ""

@export_multiline var description: String = ""

@export var primary_role: StringName = &""

@export var capabilities: Array[String] = []

@export var supported_publishes: Array[StringName] = []

@export var supported_subscribes: Array[StringName] = []

@export var requirements: Array[String] = []

@export var based_on_profile_id: StringName = &""

@export var based_on_profile_version: int = 0
```

DeviceProfileDraft no contiene:

```gdscript
canonical = true
```

Un Draft creado por el usuario no puede declararse canónico.

### 4.5 Validación de identidad

```gdscript
func is_valid_identity() -> bool
```

Debe comprobar:

- profile ID no vacío;
- profile version mayor que cero;
- display name no vacío;
- Primary Role registrado;
- reglas de `based_on` consistentes.

La validación completa pertenece a DeviceProfileCompiler.

## 5. DeviceProfile

### 5.1 Archivo previsto

```text
core/profile/device_profile.gd
```

### 5.2 Forma

```gdscript
extends Resource
class_name DeviceProfile
```

### 5.3 Responsabilidad

> Representar un snapshot validado e inmutable de un modelo de Device.

DeviceProfile puede:

- persistirse;
- consultarse;
- referenciarse;
- utilizarse para compilación;
- utilizarse por DeviceCatalog;
- utilizarse para crear Drafts derivados.

DeviceProfile no puede editarse mediante la API soportada.

### 5.4 Estado serializable no editable

```gdscript
@export_storage var _profile_id: StringName = &""

@export_storage var _profile_version: int = 1

@export_storage var _display_name: String = ""

@export_storage var _description: String = ""

@export_storage var _primary_role: StringName = &""

@export_storage var _capabilities: Array[String] = []

@export_storage var _supported_publishes: Array[StringName] = []

@export_storage var _supported_subscribes: Array[StringName] = []

@export_storage var _requirements: Array[String] = []

@export_storage var _canonical: bool = false

@export_storage var _based_on_profile_id: StringName = &""

@export_storage var _based_on_profile_version: int = 0
```

`@export_storage` permite persistencia sin presentar campos normales de edición en el Inspector.

### 5.5 Construcción

DeviceProfile recibirá todos sus valores durante `_init()`.

Los parámetros tendrán valores por defecto para permitir carga mediante ResourceLoader.

El constructor copiará los Arrays recibidos.

### 5.6 API de lectura

```gdscript
get_profile_id() -> StringName

get_profile_version() -> int

get_display_name() -> String

get_description() -> String

get_primary_role() -> StringName

get_capabilities() -> Array[String]

get_supported_publishes() -> Array[StringName]

get_supported_subscribes() -> Array[StringName]

get_requirements() -> Array[String]

is_canonical() -> bool

get_based_on_profile_id() -> StringName

get_based_on_profile_version() -> int

is_valid() -> bool
```

Los getters de Arrays devolverán copias.

No existirán setters públicos.

## 6. DeviceProfileCompileResult

### 6.1 Archivo previsto

```text
core/profile/device_profile_compile_result.gd
```

### 6.2 Forma

```gdscript
extends RefCounted
class_name DeviceProfileCompileResult
```

### 6.3 Estado

```gdscript
var _profile: DeviceProfile

var _report: ValidationReport
```

`_profile` puede ser null.

`_report` nunca será null.

### 6.4 API

```gdscript
get_profile() -> DeviceProfile

get_report() -> ValidationReport

is_success() -> bool
```

`is_success()` requiere:

```text
profile no null;

report válido para Simulation Mode.
```

## 7. DeviceProfileCompiler

### 7.1 Archivo previsto

```text
core/profile/device_profile_compiler.gd
```

### 7.2 Forma

```gdscript
extends RefCounted
class_name DeviceProfileCompiler
```

### 7.3 Responsabilidad

> Validar un DeviceProfileDraft y producir un DeviceProfile derivado e inmutable.

### 7.4 API

```gdscript
func compile(
	draft: DeviceProfileDraft
) -> DeviceProfileCompileResult
```

### 7.5 Validaciones

Debe comprobar:

- Draft no null;
- identidad válida;
- Primary Role válido;
- capabilities sin duplicados;
- publishes sin duplicados;
- subscribes sin duplicados;
- requirements sin duplicados;
- `based_on` consistente;
- namespace permitido.

### 7.6 Namespace reservado

DeviceProfileCompiler rechazará cualquier Draft cuyo `profile_id` comience por:

```text
velocity.
```

Resultado:

```text
STRUCTURAL_ERROR

code:
reserved_profile_namespace
```

Solo BuiltinDeviceProfiles podrá crear snapshots canónicos dentro del namespace `velocity`.

Los Profiles compilados desde Draft siempre tendrán:

```text
canonical:
false
```

La detección de IDs duplicados fuera del namespace canónico pertenecerá a DeviceCatalog.

### 7.7 Resultado correcto

Produce:

```text
DeviceProfile

canonical:
false

ValidationReport sin errores bloqueantes
```

### 7.8 Resultado incorrecto

Produce:

```text
profile:
null

ValidationReport con errores
```

### 7.9 Profiles canónicos

DeviceProfileCompiler no crea Profiles canónicos.

Los Profiles canónicos serán construidos por:

```text
BuiltinDeviceProfiles
```

o una factory canónica futura.

## 8. DeviceConfigurationDraft

### 8.1 Archivo previsto

```text
core/profile/device_configuration_draft.gd
```

### 8.2 Forma

```gdscript
extends Resource
class_name DeviceConfigurationDraft
```

### 8.3 Responsabilidad

> Representar una configuración editable de una instancia que todavía no puede utilizarse por runtime.

### 8.4 Estado editable

```gdscript
@export var configuration_id: StringName = &""

@export var configuration_version: int = 1

@export var device_id: String = ""

@export var profile_id: StringName = &""

@export var profile_version: int = 1

@export var based_on_configuration_id: StringName = &""

@export var based_on_configuration_version: int = 0

@export var enabled_capabilities: Array[String] = []

@export var enabled_publishes: Array[StringName] = []

@export var enabled_subscribes: Array[StringName] = []

@export var additional_requirements: Array[String] = []
```

### 8.5 Configuraciones especializadas

Una configuración especializada podrá heredar de DeviceConfigurationDraft.

Ejemplo:

```gdscript
extends DeviceConfigurationDraft
class_name HoverMCUConfigurationDraft
```

No se añadirán campos especializados a la clase base.

### 8.6 Validación de identidad

```gdscript
func is_valid_identity() -> bool
```

Debe comprobar:

- configuration ID no vacío;
- version mayor que cero;
- Device ID no vacío;
- Profile ID no vacío;
- Profile version mayor que cero;
- `based_on` consistente.

La validación completa pertenece a DeviceConfigurationCompiler.

## 9. DeviceConfiguration

### 9.1 Archivo previsto

```text
core/profile/device_configuration.gd
```

### 9.2 Forma

```gdscript
extends Resource
class_name DeviceConfiguration
```

### 9.3 Responsabilidad

> Representar un snapshot validado e inmutable de configuración para una instancia.

### 9.4 Activation Context

```gdscript
enum ActivationContext {
	SIMULATION,
	HARDWARE
}
```

No contiene `DRAFT`.

Draft es otro tipo de objeto.

### 9.5 Estado serializable

```gdscript
@export_storage var _configuration_id: StringName = &""

@export_storage var _configuration_version: int = 1

@export_storage var _device_id: String = ""

@export_storage var _profile_id: StringName = &""

@export_storage var _profile_version: int = 1

@export_storage var _activation_context: ActivationContext = (
	ActivationContext.SIMULATION
)

@export_storage var _based_on_configuration_id: StringName = &""

@export_storage var _based_on_configuration_version: int = 0

@export_storage var _enabled_capabilities: Array[String] = []

@export_storage var _enabled_publishes: Array[StringName] = []

@export_storage var _enabled_subscribes: Array[StringName] = []

@export_storage var _additional_requirements: Array[String] = []
```

### 9.6 Construcción

Todos los valores se reciben durante `_init()`.

Los Arrays se copian.

Los parámetros tendrán valores por defecto para ResourceLoader.

### 9.7 API de lectura

```gdscript
get_configuration_id() -> StringName

get_configuration_version() -> int

get_device_id() -> String

get_profile_id() -> StringName

get_profile_version() -> int

get_activation_context() -> ActivationContext

get_based_on_configuration_id() -> StringName

get_based_on_configuration_version() -> int

get_enabled_capabilities() -> Array[String]

get_enabled_publishes() -> Array[StringName]

get_enabled_subscribes() -> Array[StringName]

get_additional_requirements() -> Array[String]

is_valid() -> bool
```

Los Arrays devueltos serán copias.

No existirán setters públicos.

## 10. DeviceConfigurationCompileResult

### 10.1 Archivo previsto

```text
core/profile/device_configuration_compile_result.gd
```

### 10.2 Forma

```gdscript
extends RefCounted
class_name DeviceConfigurationCompileResult
```

### 10.3 Estado

```gdscript
var _configuration: DeviceConfiguration

var _report: ValidationReport
```

### 10.4 API

```gdscript
get_configuration() -> DeviceConfiguration

get_report() -> ValidationReport

is_success() -> bool
```

## 11. DeviceConfigurationCompiler

### 11.1 Archivo previsto

```text
core/profile/device_configuration_compiler.gd
```

### 11.2 Forma

```gdscript
extends RefCounted
class_name DeviceConfigurationCompiler
```

### 11.3 Responsabilidad

> Validar DeviceConfigurationDraft contra DeviceProfile y producir un snapshot inmutable.

### 11.4 API inicial

```gdscript
func compile_for_simulation(
	draft: DeviceConfigurationDraft,
	profile: DeviceProfile
) -> DeviceConfigurationCompileResult
```

Hardware Mode no se compilará durante la primera versión.

### 11.5 Validaciones

Debe comprobar:

- Draft no null;
- Profile no null;
- Draft identity válida;
- Profile válido;
- Profile ID coincide;
- Profile version coincide;
- capabilities son subconjunto;
- publishes son subconjunto;
- subscribes son subconjunto;
- no existen duplicados;
- `based_on` es consistente.

### 11.6 Configuraciones especializadas

DeviceConfigurationCompiler 1.0 compilará únicamente los campos del contrato base.

Una configuración especializada deberá utilizar:

- un compiler especializado;
- una estrategia registrada;
- o una extensión futura del sistema de compilación.

El compiler base no copiará campos desconocidos dentro de un Dictionary genérico.

Durante la primera versión solo se implementará DeviceConfiguration base para Devices ideales.

### 11.7 Resultado correcto

Produce:

```text
DeviceConfiguration

Activation Context:
SIMULATION

ValidationReport válido
```

### 11.8 Resultado incorrecto

Produce:

```text
configuration:
null

ValidationReport con errores
```

## 12. DeviceManifest efectivo

DeviceManifestBuilder recibirá únicamente snapshots:

```gdscript
func build(
	profile: DeviceProfile,
	configuration: DeviceConfiguration
) -> DeviceManifestBuildResult
```

No aceptará:

```text
DeviceProfileDraft

DeviceConfigurationDraft
```

### 12.1 Copias

```text
manifest.capabilities
=
copy(configuration.enabled_capabilities)

manifest.publishes
=
copy(configuration.enabled_publishes)

manifest.subscribes
=
copy(configuration.enabled_subscribes)
```

### 12.2 Requirements

```text
manifest.requirements
=
union(
	profile.requirements,
	configuration.additional_requirements
)
```

Los requirements del Profile no pueden eliminarse.

No se permiten duplicados.

## 13. Save As y snapshots

### 13.1 Profile Save As

```text
DeviceProfile snapshot

↓

crear DeviceProfileDraft

↓

copiar valores

↓

asignar nuevo profile_id

↓

profile_version = 1

↓

based_on = original ID + version

↓

editar Draft
```

### 13.2 Configuration Save As

```text
DeviceConfiguration snapshot

↓

crear DeviceConfigurationDraft

↓

copiar valores

↓

asignar nuevo configuration_id

↓

configuration_version = 1

↓

based_on = original ID + version

↓

editar Draft
```

### 13.3 Runtime

Runtime recibe únicamente:

```text
DeviceProfile

DeviceConfiguration

DeviceManifest
```

No recibe Drafts.

## 14. Invariantes del modelo Draft–Snapshot

1. Draft es editable.

2. Snapshot no expone setters.

3. Draft nunca se ejecuta.

4. Snapshot recibe copias de Arrays.

5. Runtime no comparte objetos con el editor.

6. Canonical Profile es snapshot.

7. Save As produce Draft.

8. Compiler produce Snapshot.

9. Compiler produce ValidationReport.

10. Compiler no modifica Draft.

11. Compiler no modifica Profile.

12. Configuration snapshot tiene ActivationContext.

13. DRAFT no existe dentro de Configuration snapshot.

14. ManifestBuilder solo acepta snapshots.

15. Last Known Good conserva snapshots anteriores.

## 15. ValidationIssue

### 15.1 Archivo previsto

```text
core/profile/validation_issue.gd
```

### 15.2 Forma

```gdscript
extends RefCounted
class_name ValidationIssue
```

### 15.3 Severidades

```gdscript
enum Severity {
	INFO,
	WARNING,
	SIMULATION_HAZARD,
	STRUCTURAL_ERROR,
	PLATFORM_SAFETY_ERROR,
	HARDWARE_SAFETY_ERROR
}
```

### 15.4 Estado

```gdscript
var _code: StringName

var _severity: Severity

var _message: String

var _related_object_id: String

var _related_field: StringName

var _suggested_action: String
```

### 15.5 Construcción

Todos los valores serán recibidos mediante `_init()`.

ValidationIssue será tratado como inmutable.

### 15.6 API

```gdscript
get_code() -> StringName

get_severity() -> Severity

get_message() -> String

get_related_object_id() -> String

get_related_field() -> StringName

get_suggested_action() -> String
```

No expondrá setters.

## 16. ValidationReport

### 16.1 Archivo previsto

```text
core/profile/validation_report.gd
```

### 16.2 Forma

```gdscript
extends RefCounted
class_name ValidationReport
```

### 16.3 Responsabilidad

> Reunir resultados estructurados de una operación de validación.

### 16.4 Estado

```gdscript
var _issues: Array[ValidationIssue] = []
```

### 16.5 API de construcción

```gdscript
func add_issue(
	issue: ValidationIssue
) -> bool
```

Devuelve `false` si:

- Issue es null;
- la misma instancia ya fue añadida.

No modifica el Issue.

### 16.6 API de consulta

```gdscript
get_issues() -> Array[ValidationIssue]

get_issue_count() -> int

is_empty() -> bool

has_severity(
	severity: ValidationIssue.Severity
) -> bool

is_valid_for_simulation() -> bool

is_valid_for_hardware() -> bool
```

`get_issues()` devolverá un Array nuevo.

### 16.7 Validación para simulación

Bloquean Simulation Mode:

```text
STRUCTURAL_ERROR

PLATFORM_SAFETY_ERROR
```

No bloquean Simulation Mode:

```text
INFO

WARNING

SIMULATION_HAZARD

HARDWARE_SAFETY_ERROR
```

Un Hardware Safety Error puede modelarse en simulación.

### 16.8 Validación para hardware

Bloquean Hardware Mode:

```text
SIMULATION_HAZARD

STRUCTURAL_ERROR

PLATFORM_SAFETY_ERROR

HARDWARE_SAFETY_ERROR
```

No bloquean por sí solos:

```text
INFO

WARNING
```

Un riesgo clasificado como Simulation Hazard puede ejecutarse en simulación, pero no se considera automáticamente seguro para hardware real.

### 16.9 Finalización

La primera versión no implementará un estado `finalized`.

Por contrato, el productor deja de añadir Issues después de entregar el Report.

Una evolución futura podrá introducir un snapshot inmutable.

## 17. DeviceManifestBuildResult

### 17.1 Archivo previsto

```text
core/profile/device_manifest_build_result.gd
```

### 17.2 Forma

```gdscript
extends RefCounted
class_name DeviceManifestBuildResult
```

### 17.3 Responsabilidad

> Reunir el Manifest generado y su ValidationReport.

### 17.4 Estado

```gdscript
var _manifest: DeviceManifest

var _report: ValidationReport
```

`_manifest` puede ser null cuando existen errores estructurales.

`_report` nunca será null.

### 17.5 API

```gdscript
get_manifest() -> DeviceManifest

get_report() -> ValidationReport

is_success() -> bool
```

`is_success()` devuelve `true` cuando:

```text
manifest no es null

y

report es válido para Simulation Mode
```

### 17.6 Alcance inicial

DeviceManifestBuildResult 1.0 se utiliza únicamente con DeviceConfiguration compilada para Simulation Mode.

Por tanto, `is_success()` utiliza:

```gdscript
report.is_valid_for_simulation()
```

La construcción para Hardware Mode requerirá una evolución que utilice `is_valid_for_hardware()` y validaciones físicas adicionales.

## 18. DeviceManifestBuilder

### 18.1 Archivo previsto

```text
core/profile/device_manifest_builder.gd
```

### 18.2 Forma

```gdscript
extends RefCounted
class_name DeviceManifestBuilder
```

### 18.3 Responsabilidad

> Validar snapshots de Profile y Configuration y construir el Manifest efectivo.

DeviceManifestBuilder no conserva estado entre builds.

### 18.4 API

```gdscript
func build(
	profile: DeviceProfile,
	configuration: DeviceConfiguration
) -> DeviceManifestBuildResult
```

No acepta Drafts.

### 18.5 Validaciones mínimas

Debe comprobar:

- Profile no null;
- Configuration no null;
- Profile válido;
- Configuration válida;
- Profile ID coincide;
- Profile version coincide;
- Activation Context es SIMULATION;
- no existen inconsistencias estructurales.

### 18.6 Profile null

Produce:

```text
STRUCTURAL_ERROR

code:
profile_missing
```

No produce Manifest.

### 18.7 Configuration null

Produce:

```text
STRUCTURAL_ERROR

code:
configuration_missing
```

No produce Manifest.

### 18.8 Referencia incompatible

Produce:

```text
STRUCTURAL_ERROR

code:
profile_reference_mismatch
```

No produce Manifest.

### 18.9 Construcción correcta

Cuando no existen errores bloqueantes:

- crea DeviceManifest;
- copia capabilities;
- copia publishes;
- copia subscribes;
- une requirements;
- elimina duplicados preservando orden;
- devuelve BuildResult.

Modificar snapshots o Arrays obtenidos mediante getters no debe cambiar Manifest.

## 19. SystemProfile

### 19.1 Archivo previsto

```text
core/profile/system_profile.gd
```

### 19.2 Forma prevista

```gdscript
extends Resource
class_name SystemProfile
```

### 19.3 Implementación pospuesta parcialmente

SystemProfile necesita tipos de DeviceGraph todavía no diseñados.

ADR-008 define su responsabilidad, pero la primera implementación no fijará:

- Connections;
- Graph nodes;
- Ports;
- TopicChannels;
- layout.

### 19.4 Contrato mínimo futuro

```text
system_profile_id

system_profile_version

display_name

Device instances

DeviceConfiguration references

Graph snapshot
```

No se creará un campo Dictionary genérico para evitar diseñar la topología prematuramente.

## 20. DeviceCatalog

### 20.1 Responsabilidad

> Reunir y localizar DeviceProfiles disponibles.

### 20.2 Implementación inicial

La primera implementación puede utilizar un catálogo en memoria para pruebas.

Debe garantizar:

- Profile ID y version únicos;
- Profile válido;
- canonical y derived distinguibles.

### 20.3 Persistencia

La carga de directorios queda pospuesta hasta definir:

- estructura de assets;
- trust;
- versionado;
- errores de carga;
- Save As.

No se implementará scanning automático durante el primer bloque.

### 20.4 IDs globales

DeviceCatalog será responsable de detectar IDs duplicados fuera del namespace canónico.

DeviceProfileCompiler solo protege el namespace reservado `velocity.`.

## 21. Save As Service

La operación Save As pertenece a un servicio externo.

Responsabilidad futura:

- crear Draft desde Snapshot;
- copiar valores;
- asignar nueva identidad;
- asignar nueva version;
- establecer `based_on`;
- validar;
- guardar Resource nuevo.

Save As nunca devuelve otro snapshot directamente.

Siempre produce un Draft editable.

```text
DeviceProfile
→
DeviceProfileDraft

DeviceConfiguration
→
DeviceConfigurationDraft
```

El nuevo snapshot solo aparece después de compilar el Draft.

DeviceProfile y DeviceConfiguration no guardan archivos por sí mismos.

## 22. Activación

DeviceConfigurationDraft no se activa directamente mediante un setter.

Flujo futuro:

```text
Draft

↓

ValidationReport

↓

Configuration Snapshot

↓

ManifestBuildResult

↓

DeviceGraph validation

↓

Composition Plan

↓

Immutable Active Snapshot
```

Durante la primera implementación se verificará:

- identidad;
- referencia a Profile;
- Manifest efectivo;
- validez para Simulation Mode.

Hardware Mode permanece fuera de alcance.

## 23. Last Known Good

Last Known Good pertenece a un administrador de snapshots futuro.

DeviceConfiguration y DeviceManifestBuilder no conservan estado global activo.

La primera implementación no activa runtime.

Solo produce resultados de validación, snapshots y Manifests.

## 24. Invariantes del sistema de validación

1. ValidationIssue es inmutable.

2. ValidationReport no modifica Issues.

3. Simulation Mode bloquea Structural y Platform errors.

4. Hardware Mode bloquea Simulation Hazard, Structural, Platform y Hardware errors.

5. DeviceManifestBuildResult siempre contiene Report.

6. Manifest puede ser null en fallo.

7. Builder no conserva estado entre builds.

8. Builder no modifica Profile.

9. Builder no modifica Configuration.

10. Manifest recibe copias.

11. Profile requirements no pueden eliminarse.

12. Additional requirements se añaden sin duplicados.

13. SystemProfile no utiliza Dictionary genérico para Graph.

14. Save As pertenece a un servicio externo.

15. Last Known Good pertenece a snapshots futuros.

16. Namespace `velocity.` está reservado.

17. Compiler de Draft nunca produce `canonical = true`.

18. IDs duplicados globales pertenecen a DeviceCatalog.

19. Compiler base no serializa campos especializados desconocidos.

20. Manifest Build 1.0 se limita a Simulation Mode.

## 25. BuiltinDeviceProfiles

### 25.1 Archivo previsto

```text
core/profile/builtin_device_profiles.gd
```

### 25.2 Forma

```gdscript
extends RefCounted
class_name BuiltinDeviceProfiles
```

### 25.3 Responsabilidad

> Construir los DeviceProfiles canónicos e ideales incluidos con Velocity.

BuiltinDeviceProfiles es una factory confiable.

No:

- guarda archivos;
- modifica Profiles existentes;
- crea Configurations;
- construye DeviceGraph;
- ejecuta Devices.

### 25.4 Ideal Distance Sensor

API inicial:

```gdscript
static func create_ideal_distance_sensor(
) -> DeviceProfile
```

Profile:

```text
profile_id:
velocity.distance_sensor.ideal

profile_version:
1

display_name:
Ideal Distance Sensor

primary_role:
sensor

capabilities:
- distance_measurement
- health_reporting

supported publishes:
- distance_measurement
- health_report

supported subscribes:
none

requirements:
none

canonical:
true
```

### 25.5 Inmutabilidad

Cada llamada podrá devolver un snapshot nuevo con el mismo contenido canónico.

El consumidor no recibe acceso a un objeto mutable compartido globalmente.

Los Arrays devueltos por DeviceProfile serán copias.

### 25.6 Evolución

Otros Profiles ideales se añadirán después de verificar el primero:

```text
Ideal Hover Thruster

Ideal Hover MCU

Ideal FCC
```

## 26. Estrategia de pruebas

Se crearán pruebas nuevas para:

```text
DeviceRoles

ValidationReport

DeviceProfileDraft

DeviceProfileCompiler

BuiltinDeviceProfiles

DeviceConfigurationDraft

DeviceConfigurationCompiler

DeviceManifestBuilder
```

Cada prueba utilizará objetos nuevos.

Los snapshots serán comprobados como objetos de solo lectura mediante su API pública.

## 27. DeviceRolesTest

### Archivos previstos

```text
test/core/profile/
DeviceRolesTest.tscn

test/core/profile/
device_roles_test.gd
```

Debe verificar:

- roles son StringName;
- valores lower_snake_case;
- `is_valid()` acepta roles canónicos;
- rechaza role vacío;
- rechaza role desconocido;
- `get_all()` contiene todos;
- `get_all()` devuelve copia independiente.

## 28. ValidationReportTest

### Archivos previstos

```text
test/core/profile/
ValidationReportTest.tscn

test/core/profile/
validation_report_test.gd
```

Debe verificar:

### ValidationIssue

```text
Getters conservan valores.

No existen setters.
```

### Report vacío

```text
válido para Simulation;

válido para Hardware.
```

### INFO y WARNING

```text
no bloquean Simulation;

no bloquean Hardware.
```

### SIMULATION_HAZARD

```text
no bloquea Simulation;

bloquea Hardware.
```

### STRUCTURAL_ERROR

```text
bloquea Simulation;

bloquea Hardware.
```

### PLATFORM_SAFETY_ERROR

```text
bloquea Simulation;

bloquea Hardware.
```

### HARDWARE_SAFETY_ERROR

```text
no bloquea Simulation;

bloquea Hardware.
```

### Copia independiente

Modificar el Array de `get_issues()` no altera el Report.

### Duplicado

Añadir la misma instancia dos veces devuelve `false` en el segundo intento.

## 29. DeviceProfileDraftTest

### Archivos previstos

```text
test/core/profile/
DeviceProfileDraftTest.tscn

test/core/profile/
device_profile_draft_test.gd
```

Debe verificar:

- Draft inicial inválido;
- identidad completa válida;
- role desconocido inválido;
- `based_on` vacío requiere version 0;
- `based_on` presente requiere version mayor que 0;
- Draft permanece editable.

## 30. DeviceProfileCompilerTest

### Archivos previstos

```text
test/core/profile/
DeviceProfileCompilerTest.tscn

test/core/profile/
device_profile_compiler_test.gd
```

Debe verificar:

- Draft null;
- identidad inválida;
- role inválido;
- duplicados en todas las listas;
- namespace `velocity.` rechazado;
- compilación válida;
- snapshot `canonical = false`;
- valores preservados;
- Arrays copiados;
- no setters;
- modificar Draft no modifica Profile.

## 31. BuiltinDeviceProfilesTest

### Archivos previstos

```text
test/core/profile/
BuiltinDeviceProfilesTest.tscn

test/core/profile/
builtin_device_profiles_test.gd
```

Debe verificar:

- Profile no null;
- Profile válido;
- ID correcto;
- version correcta;
- role SENSOR;
- canonical true;
- capabilities esperadas;
- topics esperados;
- sin setters;
- Arrays independientes;
- dos llamadas producen snapshots diferentes equivalentes.

## 32. DeviceConfigurationDraftTest

### Archivos previstos

```text
test/core/profile/
DeviceConfigurationDraftTest.tscn

test/core/profile/
device_configuration_draft_test.gd
```

Debe verificar:

- Draft inicial inválido;
- identidad completa válida;
- Profile reference obligatoria;
- Device ID obligatorio;
- `based_on` consistente;
- listas editables;
- duplicados detectables por compiler.

## 33. DeviceConfigurationCompilerTest

### Archivos previstos

```text
test/core/profile/
DeviceConfigurationCompilerTest.tscn

test/core/profile/
device_configuration_compiler_test.gd
```

Debe verificar:

- Draft null;
- Profile null;
- Profile ID mismatch;
- Profile version mismatch;
- capability no soportada;
- publish no soportado;
- subscribe no soportado;
- duplicados;
- configuración válida;
- Activation Context SIMULATION;
- Arrays copiados;
- no setters;
- modificar Draft no cambia snapshot.

El compiler base no probará configuraciones especializadas en la versión 1.0.

## 34. DeviceManifestBuilderTest

### Archivos previstos

```text
test/core/profile/
DeviceManifestBuilderTest.tscn

test/core/profile/
device_manifest_builder_test.gd
```

Debe verificar:

- Profile null;
- Configuration null;
- reference mismatch;
- build válido;
- capabilities copiadas;
- publishes copiados;
- subscribes copiados;
- Profile requirements incluidos;
- additional requirements añadidos;
- requirements sin duplicados;
- Arrays independientes;
- snapshots no modificados.

## 35. Sustitución de Profile genérico

La clase:

```text
profiles/profile.gd
```

será declarada SUPERADA cuando existan:

- DeviceProfileDraft;
- DeviceProfile;
- DeviceProfileCompiler;
- DeviceConfigurationDraft;
- DeviceConfiguration;
- DeviceConfigurationCompiler;
- pruebas correspondientes.

Después:

- se retirará `profiles/profile.gd`;
- se retirará su UID;
- permanecerá en Git;
- la carpeta `profiles/` continuará como raíz de assets.

## 36. Orden de implementación

```text
1. Crear core/profile/.

2. Implementar DeviceRoles.

3. Ejecutar DeviceRolesTest.

4. Implementar ValidationIssue.

5. Implementar ValidationReport.

6. Ejecutar ValidationReportTest.

7. Implementar DeviceProfileDraft.

8. Ejecutar DeviceProfileDraftTest.

9. Implementar DeviceProfile.

10. Implementar DeviceProfileCompileResult.

11. Implementar DeviceProfileCompiler.

12. Ejecutar DeviceProfileCompilerTest.

13. Implementar BuiltinDeviceProfiles.

14. Ejecutar BuiltinDeviceProfilesTest.

15. Implementar DeviceConfigurationDraft.

16. Ejecutar DeviceConfigurationDraftTest.

17. Implementar DeviceConfiguration.

18. Implementar DeviceConfigurationCompileResult.

19. Implementar DeviceConfigurationCompiler.

20. Ejecutar DeviceConfigurationCompilerTest.

21. Implementar DeviceManifestBuildResult.

22. Implementar DeviceManifestBuilder.

23. Ejecutar DeviceManifestBuilderTest.

24. Declarar Profile genérico SUPERADO.

25. Retirar Profile genérico.

26. Ejecutar runner -All.

27. Registrar resultados.

28. Actualizar Core Architecture.
```

## 37. Criterios de aceptación

La implementación inicial satisface el diseño cuando:

1. DeviceRoles está implementado.

2. Roles canónicos están probados.

3. DeviceProfileDraft es editable.

4. DeviceProfile es snapshot sin setters.

5. DeviceProfileCompiler produce Report y Snapshot.

6. Builtin Ideal Distance Sensor es canónico.

7. DeviceConfigurationDraft es editable.

8. DeviceConfiguration es snapshot sin setters.

9. DeviceConfigurationCompiler valida Profile.

10. Activation Context es SIMULATION.

11. ValidationReport distingue contextos.

12. DeviceManifestBuilder utiliza snapshots.

13. Arrays no se comparten accidentalmente.

14. Profile requirements no se eliminan.

15. Profile genérico es retirado.

16. todas las pruebas sucesoras terminan correctamente.

17. runner `-All` termina PASS.

18. Simulation Hazard bloquea Hardware Mode.

19. DeviceProfileCompiler rechaza namespace `velocity.`.

20. BuiltinDeviceProfiles puede crear canonical Profiles.

21. Compiler base no absorbe configuración especializada.

22. Manifest Builder 1.0 utiliza Simulation snapshots.

## 38. Fuera de alcance

La implementación no añadirá todavía:

- SystemProfile concreto;
- DeviceCatalog persistente;
- Save As Service;
- GraphEditor;
- ConfigurationEditor;
- DeviceGraph;
- Hardware Mode compiler;
- DeviceCalibration;
- AdaptationPolicy;
- RuntimeAllocation;
- firmas criptográficas;
- scanning automático de assets.

## 39. Resumen de implementación

```text
Roles:
DeviceRoles

Editable Profile:
DeviceProfileDraft

Profile Snapshot:
DeviceProfile

Profile Compiler:
DeviceProfileCompiler

Canonical Factory:
BuiltinDeviceProfiles

Editable Configuration:
DeviceConfigurationDraft

Configuration Snapshot:
DeviceConfiguration

Configuration Compiler:
DeviceConfigurationCompiler

Validation:
ValidationIssue
ValidationReport

Manifest:
DeviceManifestBuilder
DeviceManifestBuildResult

SystemProfile:
diseño pospuesto

Generic Profile:
retirado después de sucesoras
```
