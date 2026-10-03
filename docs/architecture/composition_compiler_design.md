# CompositionCompiler — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Fecha | 02/10/2026 |
| ADR relacionados | ADR-009 — System Composition Pipeline; ADR-010 — Runtime Construction and Factory Binding |
| Alcance | Compilación transaccional de DeviceGraphSnapshot a CompositionPlan |
| Estado de implementación | NO IMPLEMENTADO |

## 1. Propósito

CompositionCompiler convierte topología lógica validada en instrucciones runtime declarativas.

Responsabilidad:

> Compilar DeviceGraphSnapshot y RuntimeFactoryRegistry en CompositionPlan sin ejecutar runtime.

Entrada conceptual:

```text
DeviceGraphSnapshot

+

RuntimeFactoryRegistry

+

Activation Context

+

DeviceBusDispatchPolicy
```

Salida:

```text
CompositionCompileResult
	├── CompositionPlan
	└── ValidationReport
```

## 2. Estado previo

Implementado y verificado:

```text
DeviceGraphSnapshot

RuntimeFactoryRegistry 1.0

CompositionPlan 1.0

DeviceBusDispatchPolicy
```

CompositionCompiler no crea ninguno de esos contratos.

Los consume.

## 3. Pipeline

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
CompositionCompileResult
		├── CompositionPlan
		└── ValidationReport
```

## 4. Componentes

```text
core/composition/
├── composition_compile_result.gd
└── composition_compiler.gd
```

## 5. Pruebas previstas

```text
test/core/composition/
├── CompositionCompileResultTest.tscn
├── composition_compile_result_test.gd
├── CompositionCompilerTest.tscn
├── composition_compiler_test.gd
├── SystemCompositionCompilerIntegrationTest.tscn
└── system_composition_compiler_integration_test.gd
```

Las pruebas anteriores permanecen inmutables.

## 6. No Draft

CompositionCompiler 1.0 no utiliza:

```text
CompositionCompilerDraft
```

Razón:

Las entradas ya son snapshots o políticas inmutables.

No existe estado editable propio del Compiler.

## 7. No Compile Request

CompositionCompiler 1.0 no añade:

```text
CompositionCompileRequest
```

La API tiene cuatro parámetros explícitos y tipados.

Otro snapshot no reduce complejidad suficiente todavía.

Si futuras entradas requieren provenance, scheduling o deployment policy, esta decisión podrá revisarse.

## 8. API

```gdscript
compile(
	graph_snapshot: DeviceGraphSnapshot,
	factory_registry: RuntimeFactoryRegistry,
	activation_context: int,
	dispatch_policy: DeviceBusDispatchPolicy
) -> CompositionCompileResult
```

Compiler es stateless.

Una instancia puede compilar múltiples inputs independientes.

## 9. Activation Context

Contextos canónicos:

```text
SIMULATION

HARDWARE
```

Context inválido produce error estructural.

CompositionCompiler 1.0 compila únicamente:

```text
SIMULATION
```

## 10. Hardware gate

Hardware produce:

```text
code:
composition_compile_hardware_not_supported

severity:
HARDWARE_SAFETY_ERROR
```

Resultado:

```text
Plan:
null

Report:
contiene Issue
```

Razón:

DeviceGraphSnapshot.is_valid() expresa validez para Simulation.

Snapshot no conserva todo el ValidationReport upstream.

Un ciclo puede ser aceptable para Simulation y bloqueante para Hardware.

CompositionCompiler no puede reconstruir toda evidencia safety desde Snapshot solamente.

Hardware requerirá un diseño sucesor con evidencia explícita.

Esta respuesta aplica VP-002 2.0:

```text
Solicitud sin evidencia safety
→ operación rechazada
→ Plan null
→ simulador seguro y recuperable
```

El rechazo controlado es comportamiento correcto del simulador.

## 11. Scope del Report

CompositionCompileResult contiene únicamente Issues producidos durante composición.

No copia automáticamente:

- DeviceCatalog Report;
- SystemProfile Report;
- DeviceGraphAssembly Report;
- DeviceGraph validation hazards upstream.

El caller conserva esos Results.

Una futura Composition Orchestrator podrá agregar reports del pipeline.

## 12. Validación de inputs

Debe comprobar:

- Activation Context válido;
- Graph Snapshot no null;
- Registry no null;
- Dispatch Policy no null;
- Hardware gate;
- Graph Snapshot válido;
- Registry válido;
- Dispatch Policy válida.

No se accede a una entrada antes de comprobar null.

## 13. Orden de validación inicial

```text
1. Activation Context.

2. Required references.

3. Hardware gate.

4. Snapshot validity.

5. Registry validity.

6. Dispatch Policy validity.
```

Errores iniciales bloquean stages posteriores.

## 14. Device stage

Por cada DeviceGraphNode, en orden:

```text
DeviceGraphNode
		│
		▼
DeviceConfiguration
		│
		▼
RuntimeFactoryKey
		│
		▼
RuntimeFactoryDescriptor
		│
		▼
CompositionDeviceEntry
```

## 15. DeviceGraphNode validation

Compiler comprueba defensivamente:

- Node no null;
- Node válida;
- Device ID no vacío;
- Configuration no null;
- Configuration válida;
- Configuration Device ID coincide;
- Configuration Activation Context coincide con Compiler.

Snapshot válido debería garantizar parte de estas reglas.

La defensa se conserva porque el Compiler es una frontera pública.

## 16. Factory Key derivation

Key se construye desde:

```text
Configuration Profile ID

+

Configuration Profile Version

+

Compiler Activation Context
```

Forma conceptual:

```gdscript
RuntimeFactoryKey.new(
	configuration.get_profile_id(),
	configuration.get_profile_version(),
	activation_context
)
```

Configuration Context debe coincidir antes de crear Key.

## 17. Factory availability

Para cada Key:

```gdscript
factory_registry.has_factory(
	factory_key
)
```

Debe ser true.

Después:

```gdscript
factory_registry.get_descriptor(
	factory_key
)
```

Debe devolver Descriptor no null y válido.

No existe:

- latest;
- fallback;
- nearest;
- compatible;
- context substitution;
- version substitution.

## 18. Dependency Specs

Compiler obtiene:

```gdscript
descriptor.get_dependency_specs()
```

Specs se entregan a CompositionDeviceEntry.

No se resuelven Values.

No se crean RuntimeDependencyBindings.

No se consulta service locator.

## 19. CompositionDeviceEntry creation

Forma conceptual:

```gdscript
CompositionDeviceEntry.new(
	node.get_device_id(),
	configuration,
	factory_key,
	descriptor.get_dependency_specs()
)
```

Entry debe resultar válida.

Entries conservan orden de DeviceGraphNodes.

## 20. Device error aggregation

Device stage procesa todos los Nodes.

Agrega errores independientes.

Ejemplo:

```text
Device A:
factory faltante

Device B:
context mismatch

Device C:
Descriptor inválido
```

Los tres Issues pueden aparecer en el mismo Report.

## 21. Device gate

Si Device stage deja Report inválido para Simulation:

- no se compilan Connections;
- no se crea CompositionPlan;
- Result contiene Plan null.

No se producen errores derivados de Connections cuando faltan Entries.

## 22. Connection stage

Por cada DeviceGraphConnection, en orden:

```text
DeviceGraphConnection
		│
		▼
CompositionConnectionDirective
```

Forma conceptual:

```gdscript
CompositionConnectionDirective.new(
	connection.get_source_device_id(),
	connection.get_source_port_id(),
	connection.get_topic(),
	connection.get_target_device_id(),
	connection.get_target_port_id()
)
```

## 23. Connection validation

Compiler comprueba:

- Connection no null;
- identity válida;
- Source Entry existe;
- Target Entry existe;
- Directive válida;
- Directive Connection ID coincide con Graph Connection ID.

Topic y compatibilidad de Ports ya fueron validados por DeviceGraph.

Compiler no repite semántica completa del Graph.

## 24. Connection order

Directives conservan orden de DeviceGraphConnections.

Compiler no reordena por:

- Topic;
- Source ID;
- Target ID;
- Connection ID.

## 25. Source identity

Directive conserva:

```text
Topic

+

Source Device ID
```

Esto permite source filtering futuro.

Compiler no crea filtros o callbacks.

## 26. Connection error aggregation

Connection stage procesa todas las Connections cuando Device stage fue válido.

Agrega errores independientes.

No devuelve Directives parciales en un Plan.

## 27. Connection gate

Si Connection stage deja Report inválido para Simulation:

- Entries temporales se descartan como salida;
- no se crea CompositionPlan;
- Result contiene Plan null.

## 28. Plan creation

Después de ambos gates:

```gdscript
CompositionPlan.new(
	activation_context,
	device_entries,
	connection_directives,
	dispatch_policy
)
```

Compiler entrega la misma referencia de Policy.

CompositionPlan copia Arrays.

## 29. Plan defensive validation

Compiler ejecuta:

```gdscript
plan.is_valid()
```

Si false:

```text
code:
composition_compile_plan_invalid

severity:
STRUCTURAL_ERROR
```

Result devuelve Plan null.

## 30. CompositionCompileResult

### Archivo

```text
core/composition/composition_compile_result.gd
```

### Forma

```gdscript
extends RefCounted
class_name CompositionCompileResult
```

### Estado

```gdscript
var _plan: CompositionPlan

var _report: ValidationReport
```

### Construcción

```gdscript
CompositionCompileResult.new(
	plan,
	report
)
```

### API

```gdscript
get_plan() -> CompositionPlan

get_report() -> ValidationReport

is_success() -> bool
```

No expone setters.

## 31. Result success

Success requiere:

- Plan no null;
- Report no null;
- Plan válida;
- Activation Context válido;
- Report válido para Plan Context.

Simulation:

```gdscript
report.is_valid_for_simulation()
```

Hardware defensivo:

```gdscript
report.is_valid_for_hardware()
```

Compiler 1.0 no produce Plan Hardware.

Result conserva soporte defensivo para futuro.

## 32. Result no ejecución

CompositionCompileResult no:

- compila;
- ejecuta;
- activa;
- hace rollback;
- modifica Plan;
- modifica Report.

## 33. Compiler transaccional

Éxito:

```text
Plan válido

+

Report válido
```

Fallo:

```text
Plan null

+

Report con Issues
```

No existe Plan parcial.

Last Known Good se sustituye externamente solo en éxito.

## 34. Input non-mutation

Compiler no modifica:

- DeviceGraphSnapshot;
- DeviceGraphNodes;
- DeviceGraphConnections;
- DeviceConfigurations;
- RuntimeFactoryRegistry;
- RuntimeFactoryDescriptors;
- RuntimeDependencySpecs;
- DeviceBusDispatchPolicy.

## 35. Registry stability

CompositionCompiler recibe un Registry snapshot.

CompositionRuntime deberá recibir la misma instancia.

Plan no contiene Registry.

Result no contiene Registry.

Composition Root futura conserva la referencia.

No se inventa:

- Registry ID;
- Registry Version;
- content hash.

## 36. Cycles

Compiler no ejecuta topological sort.

Conserva orden de Graph Nodes.

CompositionPlan deriva lifecycle order del orden de Entries.

Phase barriers permiten ciclos estructurales en Simulation.

## 37. Empty compilation

Inputs válidos:

```text
Snapshot vacío

Registry vacío

Simulation Context

Policy válida
```

Producen:

```text
CompositionPlan vacío válido
```

Esto representa no-op.

## 38. Extra Registry entries

Registry puede contener Descriptors no utilizados por Snapshot.

No es error.

Compiler valida disponibilidad requerida, no exhaustividad del Registry.

## 39. Shared Descriptor

Varios Nodes pueden derivar la misma RuntimeFactoryKey.

Todos pueden usar el mismo Descriptor explícito.

Cada Node produce CompositionDeviceEntry independiente.

Compiler no duplica factory.

Compiler no ejecuta factory.

## 40. Error codes — inputs

### Snapshot missing

```text
composition_compile_snapshot_missing
STRUCTURAL_ERROR
```

### Snapshot invalid

```text
composition_compile_snapshot_invalid
STRUCTURAL_ERROR
```

### Registry missing

```text
composition_compile_registry_missing
STRUCTURAL_ERROR
```

### Registry invalid

```text
composition_compile_registry_invalid
STRUCTURAL_ERROR
```

### Activation Context invalid

```text
composition_compile_activation_context_invalid
STRUCTURAL_ERROR
```

### Hardware unsupported

```text
composition_compile_hardware_not_supported
HARDWARE_SAFETY_ERROR
```

### Dispatch Policy missing

```text
composition_compile_dispatch_policy_missing
STRUCTURAL_ERROR
```

### Dispatch Policy invalid

```text
composition_compile_dispatch_policy_invalid
STRUCTURAL_ERROR
```

## 41. Error codes — Devices

```text
composition_compile_node_missing

composition_compile_node_invalid

composition_compile_configuration_missing

composition_compile_configuration_context_mismatch

composition_compile_factory_key_invalid

composition_compile_factory_missing

composition_compile_descriptor_invalid

composition_compile_device_entry_invalid
```

Todos utilizan:

```text
STRUCTURAL_ERROR
```

## 42. Error codes — Connections

```text
composition_compile_connection_missing

composition_compile_connection_invalid

composition_compile_directive_invalid

composition_compile_connection_id_mismatch
```

Todos utilizan:

```text
STRUCTURAL_ERROR
```

## 43. Error code — Plan

```text
composition_compile_plan_invalid
STRUCTURAL_ERROR
```

## 44. Issue related object

Device errors utilizan:

```text
Device ID
```

Cuando Node es null:

```text
Node index
```

Connection errors utilizan:

```text
Connection ID
```

Cuando Connection es null:

```text
Connection index
```

## 45. Dependencies permitidas

```text
DeviceGraphSnapshot

DeviceGraphNode

DeviceGraphConnection

DeviceConfiguration

RuntimeFactoryKey

RuntimeFactoryRegistry

RuntimeFactoryDescriptor

RuntimeDependencySpec

CompositionDeviceEntry

CompositionConnectionDirective

CompositionPlan

CompositionCompileResult

DeviceBusDispatchPolicy

ValidationIssue

ValidationReport
```

## 46. Dependencies prohibidas

```text
DeviceCatalog

SystemProfileDraft

DeviceGraphDraft

RuntimeConstructionRequest

RuntimeDependencyBinding con Value

RuntimeDeviceHandle

RuntimeHost

DeviceBus activo

CompositionRuntime

SceneTree

Node path

autoload

filesystem

JSON

GraphEditor

hardware adapter concreto
```

## 47. No execution

Compiler no invoca:

```text
RuntimeFactory.build

RuntimeFactory.release

RuntimeHost.attach

RuntimeHost.detach

Device.initialize

Device.set_ready

Device.start

Device.shutdown
```

## 48. No service locator

Compiler no busca:

- factory por path;
- services;
- Nodes;
- Providers;
- hardware;
- dependency values;
- global state.

Toda factory llega mediante Registry explícito.

## 49. Persistence

CompositionCompiler no abre o guarda archivos.

Persistence permanece externa.

## 50. Threading

CompositionCompiler 1.0 es síncrono y stateless.

No crea threads.

No bloquea esperando IO.

Su complejidad depende linealmente de Nodes, Connections y lookups exactos del Registry.

## 51. Estrategia de pruebas — Result

CompositionCompileResultTest verifica:

- Plan null;
- Report null;
- Plan inválido;
- Report bloqueante;
- Result válido;
- getters;
- ausencia de setters;
- ausencia de ejecución.

## 52. Estrategia de pruebas — Compiler inputs

CompositionCompilerTest verifica:

- Context inválido;
- Snapshot null;
- Registry null;
- Policy null;
- Hardware gate;
- Snapshot inválido;
- Registry inválido;
- Policy inválida.

## 53. Estrategia de pruebas — Empty

Verifica:

- Snapshot vacío;
- Registry vacío;
- Policy válida;
- Plan vacío;
- órdenes vacíos;
- Report sin Issues.

## 54. Estrategia de pruebas — Devices

Snapshot inválido se rechaza antes de Device stage.

Con Snapshot válido verifica:

- Context mismatch;
- factory faltante;
- varias factories;
- varias versiones;
- varios Nodes con misma Key;
- Specs trasladadas;
- orden preservado;
- factories faltantes agregadas;
- Connection stage gated después de error de Device.

Los códigos defensivos de Node inválida protegen cambios futuros del contrato, pero no requieren fabricar un Snapshot inválido que ya sería rechazado por el gate inicial.

## 55. Estrategia de pruebas — Connections

Con Snapshot válido verifica:

- orden preservado;
- Source ID;
- Source Port;
- Topic;
- Target ID;
- Target Port;
- Connection ID preservado;
- ciclos sin topological sort.

Los códigos defensivos de Connection y Directive protegen la frontera ante evolución futura. Snapshot inválido se prueba mediante `composition_compile_snapshot_invalid`.

## 56. Estrategia de pruebas — Safety

Verifica:

- Hardware Safety Error;
- factory build count cero;
- factory release count cero;
- no RuntimeDeviceHandle;
- no DeviceBus;
- no RuntimeHost;
- no mutación de inputs;
- Result transaccional.

## 57. Integración sucesora

```text
SystemCompositionCompilerIntegrationTest
```

Pipeline:

```text
DeviceProfile
		│
		▼
DeviceCatalog
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
```

RuntimeFactoryRegistry se entrega explícitamente.

## 58. Baselines preservadas

No se modifican:

```text
DeviceGraphAssemblerTest

SystemProfileCatalogGraphAssemblyIntegrationTest

RuntimeFactoryRegistryCompilerTest

CompositionDeviceEntryTest

CompositionConnectionDirectiveTest

CompositionPlanTest

CompositionPlanRuntimeFactoryRegistryIntegrationTest
```

Compiler utiliza pruebas sucesoras.

## 59. Orden de implementación futuro

```text
1. Implementar CompositionCompileResult.

2. Ejecutar CompositionCompileResultTest.

3. Implementar CompositionCompiler.

4. Ejecutar CompositionCompilerTest.

5. Implementar integración sucesora.

6. Ejecutar SystemCompositionCompilerIntegrationTest.

7. Ejecutar Composition Suite.

8. Ejecutar Run All.

9. Registrar baseline.
```

No iniciar hasta cerrar este diseño documental.

## 60. Criterios de aceptación

1. Compiler stateless.

2. Inputs explícitos.

3. Simulation-only.

4. Hardware bloqueado con Hardware Safety Error.

5. Snapshot obligatorio y válido.

6. Registry obligatorio y válido.

7. Context obligatorio y válido.

8. Dispatch Policy obligatoria y válida.

9. Empty compilation válida.

10. Factory Key exacta.

11. Sin fallback.

12. Descriptor exacto.

13. Dependency Specs trasladadas.

14. Sin Dependency Values.

15. Device Entries tipadas.

16. Device order preservado.

17. Connection Directives tipadas.

18. Connection order preservado.

19. Connection ID coincide.

20. Ciclos sin topological sort.

21. Plan final válido.

22. No Plan parcial.

23. Report estructurado.

24. Result defensivo.

25. No mutación de inputs.

26. No factory execution.

27. No RuntimeDeviceHandle.

28. No RuntimeHost.

29. No DeviceBus activo.

30. No service locator.

31. No filesystem.

32. No persistence.

33. No threads.

34. Last Known Good externo.

35. Pruebas unitarias PASS.

36. Integración sucesora PASS.

37. Composition Suite PASS.

38. Run All PASS.

## 61. Fuera de alcance

CompositionCompiler 1.0 no implementará:

- CompositionRuntime;
- factory execution;
- Dependency Value resolution;
- RuntimeConstructionRequest;
- RuntimeDeviceHandle;
- RuntimeHost;
- DeviceBus activo;
- lifecycle execution;
- callback resolution;
- endpoint adapters;
- Hardware compilation;
- upstream report aggregation;
- provenance ID;
- Plan serialization;
- Registry hashing;
- scheduling SCC;
- temporal boundaries;
- hot reload;
- persistence.

## 62. Consecuencias positivas

- frontera compile/runtime explícita;
- Plan reproducible;
- factories exactas;
- Specs visibles;
- cero ejecución durante compile;
- orden determinista;
- ciclos preservados;
- Policy explícita;
- errores por stage;
- salida transaccional;
- fácil prueba aislada.

## 63. Consecuencias negativas

- Hardware compilation permanece bloqueado;
- reports upstream no se agregan automáticamente;
- caller debe conservar Registry exacto;
- no existe provenance hash;
- no existe scheduling avanzado;
- dos componentes adicionales;
- Compiler repite validación defensiva de snapshots.

Estas consecuencias son aceptadas.

## 64. Invariantes

1. Compiler no ejecuta.

2. Compiler no modifica inputs.

3. Key es exacta.

4. Registry es explícito.

5. Policy es explícita.

6. Context es explícito.

7. Plan guarda Key, no factory.

8. Plan no guarda Registry.

9. Entry guarda Specs, no Values.

10. Directive guarda intención, no callback.

11. Device stage precede Connection stage.

12. Error de Device bloquea Connections.

13. Error de Connection bloquea Plan.

14. No Plan parcial.

15. Empty Plan es válido.

16. Ciclos no requieren topological sort.

17. Hardware está bloqueado en 1.0.

18. Last Known Good se sustituye externamente.

## 65. Estado

```text
COMPOSITIONCOMPILER DESIGN 1.0
ACTIVO
```

Problema:

```text
CERRADO
```

Análisis:

```text
CERRADO
```

Implementación:

```text
NO AUTORIZADA HASTA COMMIT DOCUMENTAL
```

Primer componente futuro:

```text
res://core/composition/composition_compile_result.gd
```
