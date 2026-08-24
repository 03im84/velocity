# DeviceGraphAssembler — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 23/08/2026 |
| ADR relacionado | ADR-009 — System Composition Pipeline |
| Alcance | Construcción transaccional de DeviceGraphSnapshot desde SystemProfile |

## 1. Propósito

DeviceGraphAssembler convierte una composición lógica validada en una topología lógica validada.

Entrada:

```text
SystemProfile

DeviceProfileResolver
```

Salida:

```text
DeviceGraphSnapshot

ValidationReport
```

Responsabilidad:

> Construir DeviceGraphSnapshot desde SystemProfile y DeviceProfiles resueltos sin modificar las entradas.

DeviceGraphAssembler forma la frontera entre:

```text
System Composition

y

DeviceGraph
```

## 2. Problema

SystemProfile contiene:

- DeviceConfiguration snapshots;
- referencias exactas a DeviceProfile;
- SystemConnectionSpecs;
- Activation Context;
- orden de composición.

SystemProfile no contiene:

- DeviceProfile completo;
- DeviceManifest efectivo;
- DeviceGraphNode;
- InputPorts;
- OutputPorts;
- TopicChannels;
- DeviceGraphConnection.

DeviceGraphSnapshot necesita esos componentes derivados.

Sin DeviceGraphAssembler, SystemProfileCompiler tendría que construir Graph, mezclando responsabilidades.

## 3. Decisión

Velocity utiliza un componente separado:

```text
DeviceGraphAssembler
```

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
connect_ports()
		│
		▼
create_snapshot()
		│
		▼
DeviceGraphSnapshot
```

DeviceGraphAssembler no crea Devices runtime.

## 4. Activation Context

DeviceGraphAssembler 1.0 soporta únicamente:

```text
SIMULATION
```

Razón:

- DeviceManifestBuilder actual soporta Simulation;
- Hardware Mode todavía no tiene compiler;
- factories de hardware no existen;
- Hardware Safety validation no está completa;
- RuntimeAllocation no existe;
- Calibration no existe.

Un SystemProfile Hardware se rechaza explícitamente.

Issue:

```text
HARDWARE_SAFETY_ERROR

code:
device_graph_assembly_hardware_not_supported
```

Resultado:

```text
Snapshot:
null

Assembly Result:
failure
```

La existencia de un Hardware Safety Error no autoriza producir un Snapshot mediante este Assembler.

## 5. Agregación por etapas

DeviceGraphAssembler utiliza tres etapas:

```text
1. Devices

2. Connections

3. Snapshot
```

### Etapa 1 — Devices

Procesa todas las DeviceConfigurations.

Agrega todos los errores independientes de Devices.

Si la etapa termina con errores bloqueantes:

- no procesa Connections;
- no crea Snapshot;
- devuelve Report agregado.

### Etapa 2 — Connections

Solo comienza cuando Devices es válida.

Procesa todas las SystemConnectionSpecs.

Las operaciones fallidas son transaccionales.

Si la etapa termina con errores bloqueantes:

- no crea Snapshot;
- devuelve Report agregado.

### Etapa 3 — Snapshot

Solo comienza cuando Devices y Connections son válidas.

Ejecuta:

```gdscript
DeviceGraphDraft.create_snapshot()
```

Agrega el Report resultante.

No devuelve topología parcial.

## 6. Razón para no usar fail-fast

Detenerse en el primer error obligaría al usuario a corregir problemas independientes uno por uno.

Ejemplo:

```text
Profile A faltante

Profile B inválido

Profile C con Configuration inválida
```

Los tres problemas pueden reportarse durante la etapa Devices.

## 7. Razón para no continuar todas las etapas

Si faltan Nodes y aun así se procesan Connections, aparecerían errores derivados:

```text
source_device_not_found

target_device_not_found
```

Estos Issues serían consecuencia de errores anteriores y añadirían ruido.

Por tanto:

```text
agregar dentro de etapa

detener entre etapas
```

## 8. Estructura propuesta

### 8.1 Código

```text
core/composition/
├── device_graph_assembler.gd
└── device_graph_assembly_result.gd
```

### 8.2 Pruebas

```text
test/core/composition/
├── DeviceGraphAssemblerTest.tscn
├── device_graph_assembler_test.gd
├── SystemProfileCatalogGraphAssemblyIntegrationTest.tscn
└── system_profile_catalog_graph_assembly_integration_test.gd
```

## 9. Dependencias permitidas

```text
SystemProfile

SystemConnectionSpec

DeviceProfile

DeviceConfiguration

DeviceProfileResolver behavior

DeviceManifestBuilder

DeviceGraphNodeBuilder

DeviceGraphDraft

DeviceGraphSnapshot

ValidationIssue

ValidationReport
```

DeviceCatalog puede entregarse como resolver.

El Assembler no depende de la clase concreta DeviceCatalog.

## 10. Dependencias no permitidas

```text
DeviceBus runtime

Device runtime

RuntimeFactoryRegistry

CompositionCompiler

CompositionPlan

CompositionRuntime

SceneTree

filesystem

Resource loading

JSON

GraphEditor

hardware adapters

telemetría
```

## 11. DeviceGraphAssemblyResult

### 11.1 Archivo

```text
core/composition/device_graph_assembly_result.gd
```

### 11.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphAssemblyResult
```

### 11.3 Responsabilidad

> Describir el resultado transaccional de ensamblar DeviceGraphSnapshot.

### 11.4 Estado

```gdscript
var _snapshot: DeviceGraphSnapshot

var _report: ValidationReport
```

### 11.5 API

```gdscript
get_snapshot() -> DeviceGraphSnapshot

get_report() -> ValidationReport

is_success() -> bool
```

### 11.6 Success

`is_success()` requiere:

```text
Snapshot no null;

Report no null;

Report válido para Simulation;

Snapshot válido.
```

DeviceGraphAssembler 1.0 no produce éxito para Hardware.

### 11.7 Inmutabilidad

No expone setters.

## 12. DeviceGraphAssembler

### 12.1 Archivo

```text
core/composition/device_graph_assembler.gd
```

### 12.2 Forma

```gdscript
extends RefCounted
class_name DeviceGraphAssembler
```

### 12.3 Responsabilidad

> Construir DeviceGraphSnapshot sin modificar SystemProfile ni DeviceProfileResolver.

### 12.4 API

```gdscript
assemble(
	system_profile: SystemProfile,
	profile_resolver: Object
) -> DeviceGraphAssemblyResult
```

### 12.5 Stateless

DeviceGraphAssembler no conserva:

- último SystemProfile;
- último Catalog;
- último Graph;
- último Snapshot;
- DeviceBus;
- runtime state.

Cada llamada crea estado temporal nuevo.

## 13. Validación de argumentos

### 13.1 SystemProfile null

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_system_profile_missing
```

### 13.2 SystemProfile identity inválida

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_system_profile_invalid
```

### 13.3 Resolver null

```text
STRUCTURAL_ERROR

code:
device_profile_resolver_missing
```

### 13.4 Resolver incompleto

Debe exponer:

```gdscript
has_profile()

get_profile()
```

Si no:

```text
STRUCTURAL_ERROR

code:
device_profile_resolver_contract_invalid
```

### 13.5 Contexto inválido

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_activation_context_invalid
```

### 13.6 Hardware

```text
HARDWARE_SAFETY_ERROR

code:
device_graph_assembly_hardware_not_supported
```

## 14. Etapa Devices

Para cada DeviceConfiguration, en orden:

```text
1. Configuration no null.

2. Configuration válida.

3. Context coincide con SystemProfile.

4. Resolver contiene Profile exacto.

5. Resolver devuelve DeviceProfile válido.

6. Profile identity coincide.

7. DeviceManifestBuilder construye Manifest.

8. DeviceGraphNodeBuilder construye Node.

9. DeviceGraphDraft.add_device() registra Node.
```

El orden de DeviceGraphNodes coincide con el orden de DeviceConfigurations.

## 15. Configuration defensiva

SystemProfileCompiler ya valida DeviceConfigurations.

DeviceGraphAssembler repite defensivamente las invariantes necesarias porque:

- SystemProfile constructor es público;
- loaders futuros pueden construir snapshots;
- el resolver puede cambiar;
- los componentes no confían ciegamente en callers.

### Configuration null

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_configuration_missing
```

### Configuration inválida

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_configuration_invalid
```

### Context mismatch

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_configuration_context_mismatch
```

## 16. Resolución de Profile

Para cada Configuration:

```text
Profile ID
+
Profile Version
```

### Dependencia faltante

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_dependency_missing
```

### Resolver devuelve null

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_dependency_invalid
```

### Profile inválido

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_dependency_invalid
```

### Identity mismatch

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_dependency_identity_mismatch
```

No existe fallback.

## 17. Construcción de Manifest

DeviceGraphAssembler utiliza:

```gdscript
DeviceManifestBuilder.build(
	profile,
	configuration
)
```

El Report de ManifestBuilder se agrega al Report de Assembly.

Si Manifest es null o el Report bloquea Simulation:

- ese Device no se añade;
- se continúa con las demás Configurations;
- la etapa Devices termina en fallo.

DeviceGraphAssembler no duplica las validaciones internas de ManifestBuilder.

## 18. Construcción de Graph Node

Con Manifest válido:

```gdscript
DeviceGraphNodeBuilder.build(
	device_id,
	profile,
	configuration,
	manifest
)
```

El Report de NodeBuilder se agrega al Report de Assembly.

Si Node es null o el Report bloquea Simulation:

- no se añade ese Device;
- se continúa con las demás Configurations.

## 19. Add Device

Con Node válido:

```gdscript
DeviceGraphDraft.add_device(
	node
)
```

El OperationResult Report se agrega al Report de Assembly.

Si add falla:

- Graph Draft conserva estado anterior;
- se continúa con las demás Configurations;
- la etapa Devices termina en fallo.

## 20. Gate entre Devices y Connections

Después de procesar Configurations:

```text
si Report no es válido para Simulation:

	retornar Snapshot null

	no procesar Connection Specs
```

Esto evita errores derivados.

## 21. Etapa Connections

Para cada SystemConnectionSpec, en orden:

```text
1. Spec no null.

2. Spec identity válida.

3. connect_ports() con endpoints.

4. agregar OperationResult Report.

5. comprobar affected ID.
```

El orden de DeviceGraphConnections coincide con el orden de SystemConnectionSpecs aceptadas.

## 22. Spec defensiva

### Spec null

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_connection_spec_missing
```

### Spec inválida

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_connection_spec_invalid
```

### Connection ID mismatch

Si `connect_ports()` produce un ID diferente del Spec:

```text
STRUCTURAL_ERROR

code:
device_graph_assembly_connection_id_mismatch
```

Este caso representa inconsistencia interna entre contratos deterministas.

## 23. Errores de Connection

DeviceGraphAssembler no duplica las reglas de DeviceGraphDraft.

Agrega sus códigos existentes:

```text
source_device_not_found

target_device_not_found

source_port_not_found

target_port_not_found

connection_topic_mismatch

connection_semantic_mismatch

duplicate_connection

input_port_multiple_sources

self_connection_not_supported
```

Una Connection fallida no modifica las Connections anteriores.

El Assembler continúa procesando las demás Specs de la etapa.

## 24. Gate antes de Snapshot

Después de procesar Connection Specs:

```text
si Report no es válido para Simulation:

	retornar Snapshot null

	no ejecutar create_snapshot()
```

No se devuelve Graph parcial.

## 25. Etapa Snapshot

Con Devices y Connections válidas:

```gdscript
var snapshot_result := graph.create_snapshot()
```

El Report de SnapshotResult se agrega al Report de Assembly.

Si SnapshotResult falla:

```text
Snapshot:
null

Assembly Result:
failure
```

Si SnapshotResult tiene Simulation Hazard y Snapshot válido:

```text
Assembly Result:
success

Hardware:
bloqueado por Report
```

## 26. Ciclos

DeviceGraphAssembler no detecta ciclos directamente.

DeviceGraphValidator, invocado por `create_snapshot()`, produce:

```text
SIMULATION_HAZARD

code:
graph_cycle_requires_temporal_analysis
```

Simulation puede producir Snapshot.

Hardware permanece bloqueado.

## 27. SystemProfile vacío

Un SystemProfile vacío de Simulation es válido.

Assembly produce:

```text
DeviceGraphSnapshot vacío

Report válido

Result success
```

CompositionCompiler podrá decidir posteriormente que un plan vacío no es ejecutable.

## 28. Agregación de Reports

DeviceGraphAssembler utiliza un ValidationReport agregado.

Fuentes:

```text
Assembler argument validation

DeviceManifestBuilder

DeviceGraphNodeBuilder

DeviceGraphDraft.add_device()

DeviceGraphDraft.connect_ports()

DeviceGraphDraft.create_snapshot()
```

### Merge

El merge:

- obtiene Issues del Report fuente;
- los añade en orden al Report destino;
- no modifica el Report fuente;
- conserva código;
- conserva severity;
- conserva related object;
- conserva related field;
- evita crear texto sustituto genérico.

### Provenance

La procedencia inicial se reconoce mediante:

- código de Issue;
- etapa documentada;
- orden del Report.

Metadata explícita de stage podrá añadirse en una evolución futura si existe una necesidad verificable.

## 29. Report determinista

Orden global:

```text
1. Argumentos.

2. Device Configurations en orden.

3. Connection Specs en orden.

4. Snapshot validation.
```

Dentro de cada dependencia se conserva el orden de su Report.

## 30. Transaccionalidad

DeviceGraphAssembler es transaccional respecto a su salida.

Una operación fallida:

- no modifica SystemProfile;
- no modifica DeviceProfileResolver;
- no produce Snapshot parcial;
- no expone DeviceGraphDraft temporal;
- no reemplaza Last Known Good externo.

El Graph Draft temporal puede contener estado parcial internamente durante assembly, pero nunca se devuelve.

## 31. No mutación de entradas

Assembler no modifica:

- metadata de SystemProfile;
- Array de Configurations;
- Array de Connection Specs;
- DeviceConfigurations;
- DeviceProfiles;
- DeviceCatalog;
- orden de Profiles;
- Reports fuente.

Tests verificarán tamaños, orden y referencias antes y después.

## 32. No responsabilidades

DeviceGraphAssembler no:

- compila SystemProfileDraft;
- registra Profiles;
- modifica DeviceCatalog;
- crea Devices runtime;
- posee DeviceBus;
- registra suscripciones;
- controla Lifecycle;
- resuelve runtime factories;
- produce CompositionPlan;
- abre archivos;
- guarda archivos;
- dibuja UI;
- activa hardware.

## 33. DeviceGraphAssemblyResult defensivo

El constructor es público para tests y composición controlada.

`is_success()` rechaza:

- Snapshot null;
- Report null;
- Report inválido para Simulation;
- Snapshot inválido.

Un Report vacío no puede aprobar Snapshot inválido.

## 34. Estrategia de pruebas unitarias

### DeviceGraphAssemblerTest

Verifica:

- SystemProfile null;
- SystemProfile identity inválida;
- Resolver null;
- Resolver incompleto;
- Activation Context inválido;
- Hardware no soportado;
- SystemProfile vacío;
- Configuration null;
- Configuration inválida;
- context mismatch;
- dependencia faltante;
- resolver retorna null;
- Profile inválido;
- Profile identity mismatch;
- múltiples errores de Devices agregados;
- Connections no procesadas cuando Devices falla;
- ManifestBuilder failure;
- NodeBuilder failure;
- add Device failure;
- Spec null;
- Spec inválida;
- Port inexistente;
- Topic mismatch;
- duplicate Connection;
- fan-in;
- múltiples errores de Connections agregados;
- Snapshot válido;
- ciclo produce Simulation Hazard;
- orden preservado;
- entradas no modificadas;
- Result defensivo;
- Assembler sin runtime API.

## 35. Estrategia de integración

### SystemProfileCatalogGraphAssemblyIntegrationTest

Pipeline real:

```text
DeviceProfiles
		│
		▼
DeviceCatalogCompiler
		│
		▼
DeviceCatalog
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
```

Verifica:

- Catalog exacto;
- SystemProfile válido;
- Manifest efectivo;
- Graph Nodes;
- Ports generados;
- Connections aplicadas;
- TopicChannels;
- Snapshot;
- orden;
- referencias;
- no runtime;
- no modificación de entradas.

No modifica pruebas anteriores.

## 36. Fixtures

Fixtures iniciales:

```text
Ideal Sensor

Ideal Local Controller

Ideal Actuator opcional
```

Utilizarán:

- DeviceProfile snapshots válidos;
- DeviceConfiguration snapshots válidas;
- BusTopics canónicos;
- SystemConnectionSpecs deterministas;
- DeviceCatalog real.

Namespace:

```text
test.
```

## 37. Baselines preservadas

No se modifican:

```text
DeviceManifestBuilderTest

DeviceGraphNodeBuilderTest

DeviceGraphConnectionTest

DeviceGraphValidationTest

DeviceGraphSnapshotTest

SystemProfileCompilerTest

DeviceCatalogCompilerTest

SystemProfileDeviceCatalogIntegrationTest
```

DeviceGraphAssembler utiliza pruebas sucesoras.

## 38. Orden de implementación

```text
1. Aceptar este diseño.
   COMPLETADO.

2. Crear DeviceGraphAssemblyResult.
   SIGUIENTE.

3. Ejecutar parser gate.

4. Crear DeviceGraphAssembler.

5. Ejecutar parser gate.

6. Crear DeviceGraphAssemblerTest.

7. Ejecutar prueba unitaria.

8. Crear integración sucesora.

9. Ejecutar integración.

10. Ejecutar Run All.

11. Registrar baseline.

12. Actualizar System Composition Pipeline Design.

13. Actualizar Core Architecture.

14. Cerrar DeviceGraphAssembler 1.0.

15. Diseñar RuntimeFactoryRegistry
	y CompositionPlan.
```

## 39. Criterios de aceptación

1. Assembler recibe SystemProfile.

2. Assembler recibe resolver por comportamiento.

3. Soporta Simulation.

4. Rechaza Hardware explícitamente.

5. SystemProfile vacío produce Snapshot vacío.

6. Resuelve Profile exacto.

7. No existe fallback.

8. Construye Manifest mediante Builder existente.

9. Construye Node mediante Builder existente.

10. Añade Devices mediante Draft API.

11. Aplica Specs mediante connect_ports().

12. Verifica Connection ID determinista.

13. Conserva orden de Devices.

14. Conserva orden de Connections.

15. Agrega Reports por etapas.

16. No procesa Connections si Devices falla.

17. No crea Snapshot si Connections falla.

18. No devuelve Graph parcial.

19. Ciclo permite Snapshot de Simulation.

20. Ciclo bloquea Hardware mediante Report.

21. No modifica SystemProfile.

22. No modifica DeviceCatalog.

23. Result es defensivo.

24. No contiene runtime API.

25. Prueba unitaria termina PASS.

26. Integración real termina PASS.

27. Run All termina PASS.

## 40. Fuera de alcance

DeviceGraphAssembler 1.0 no implementará:

- Hardware assembly;
- RuntimeFactoryRegistry;
- CompositionCompiler;
- CompositionPlan;
- CompositionRuntime;
- Device creation;
- DeviceBus ownership;
- subscriptions runtime;
- lifecycle runtime;
- filesystem;
- persistencia;
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

## 41. Consecuencias positivas

- separación entre composición y topología;
- reutilización de Builders existentes;
- resolución exacta;
- Reports agregados;
- múltiples errores útiles por etapa;
- sin errores derivados entre etapas;
- no exposición de Graph parcial;
- orden determinista;
- integración comprobable;
- preparación para CompositionCompiler.

## 42. Consecuencias negativas

- nuevo componente Result;
- nuevo Assembler;
- merge de Reports;
- validación defensiva repetida;
- Hardware permanece bloqueado;
- SystemProfile válido todavía puede fallar durante Graph assembly.

Estas consecuencias son aceptadas.

## 43. Invariantes

1. Assembler es stateless.

2. Entrada SystemProfile es inmutable.

3. Resolver se usa por comportamiento.

4. Resolución es exacta.

5. Simulation es el único contexto soportado.

6. Hardware produce failure.

7. Devices se procesan antes de Connections.

8. Etapa fallida bloquea la siguiente.

9. Errores se agregan dentro de etapa.

10. No se devuelve Snapshot parcial.

11. Reports fuente no se modifican.

12. Orden se conserva.

13. Builders existentes son autoridad.

14. DeviceGraphDraft es autoridad de Connections.

15. DeviceGraphValidator es autoridad de topología global.

16. Assembler no crea runtime.

17. Assembler no conoce factories.

18. Assembler no abre archivos.

## 44. Estado

```text
DISEÑO ACTIVO
```

DeviceGraphAssembler 1.0 está autorizado para implementación incremental.

Primer componente:

```text
DeviceGraphAssemblyResult
```

Los componentes posteriores permanecen sujetos al orden de implementación y a sus pruebas sucesoras.