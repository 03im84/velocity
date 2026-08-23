# ADR-009 — System Composition Pipeline

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 23/08/2026 |
| Componentes | SystemProfileDraft, SystemProfileCompiler, SystemProfile, DeviceProfileResolver, DeviceCatalog, DeviceGraphAssembler, RuntimeFactoryRegistry, CompositionCompiler, CompositionPlan, CompositionRuntime |
| Alcance | Definición, resolución, construcción, compilación y ejecución de composiciones |

## 1. Contexto

Velocity dispone actualmente de:

- DeviceBus;
- bounded FIFO dispatch;
- Runtime Safety;
- Topic y Message Contracts;
- Provider System;
- Device Core;
- DeviceProfile;
- DeviceConfiguration;
- DeviceManifestBuilder;
- ValidationIssue;
- ValidationReport;
- DeviceGraphDraft;
- DeviceGraphValidator;
- DeviceGraphSnapshot.

DeviceGraph 1.0 puede:

- representar Devices;
- representar Ports;
- representar Connections;
- validar topología;
- detectar fan-in;
- detectar ciclos;
- producir un Snapshot inmutable.

DeviceGraphSnapshot representa estructura lógica validada.

No representa:

- persistencia;
- catálogo;
- resolución de dependencias;
- factories;
- plan runtime;
- ejecución;
- ownership de DeviceBus.

Velocity necesita una cadena explícita desde una composición persistente hasta un runtime activo.

## 2. Problema

Sin un pipeline de composición definido, los siguientes componentes podrían adquirir responsabilidades incompatibles:

- SystemProfile podría convertirse en archivo, Graph y runtime al mismo tiempo;
- DeviceCatalog podría conocer factories ejecutables;
- CompositionCompiler podría crear e iniciar Devices;
- DeviceGraphSnapshot podría convertirse en formato persistente;
- CompositionRuntime podría interpretar archivos directamente;
- GraphEditor podría definir contratos del Core;
- Hardware Mode podría activarse sin validación completa.

La implementación directa de cualquiera de estos componentes produciría dependencias prematuras.

## 3. Decisión

Velocity utilizará un System Composition Pipeline dividido en etapas independientes.

Pipeline lógico:

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

Persistencia permanecerá externa al Core lógico:

```text
SystemProfileSerializer
		│
		├── load
		└── save
```

## 4. Separación de etapas

Cada etapa responde una pregunta distinta.

```text
SystemProfileDraft:
¿Qué composición está editando el usuario?

SystemProfileCompiler:
¿La definición es internamente coherente
y sus dependencias existen?

SystemProfile:
¿Cuál es la composición validada
y versionada?

DeviceGraphAssembler:
¿Qué topología lógica resulta
de esa composición?

DeviceGraphSnapshot:
¿Cuál es la topología validada
e inmutable?

CompositionCompiler:
¿Qué instrucciones runtime deben ejecutarse?

CompositionPlan:
¿Cuál es el plan validado e inmutable?

CompositionRuntime:
¿Cómo se crean, inician, supervisan
y detienen los recursos activos?
```

Ninguna etapa responde las preguntas de las demás.

## 5. Identidad de SystemProfile

SystemProfile tendrá identidad propia.

Campos conceptuales mínimos:

```text
System Profile ID

System Profile Version

Display Name

Description

Activation Context

DeviceConfigurations

Connection Specifications
```

Identidades:

```text
System Profile ID:
StringName

System Profile Version:
int positivo
```

SystemProfile ID no depende de:

- nombre de archivo;
- ruta;
- nombre visual;
- SceneTree;
- instance ID de Godot.

## 6. Activation Context

SystemProfile declara explícitamente:

```text
SIMULATION

o

HARDWARE
```

Todas las DeviceConfigurations incluidas deben declarar el mismo Activation Context.

Una composición mezclada produce:

```text
STRUCTURAL_ERROR

code:
system_profile_activation_context_mismatch
```

Razones:

- evita ambigüedad;
- impide mezclar configuraciones de simulación y hardware;
- permite validar un perfil vacío;
- hace explícito el contexto antes de Graph assembly;
- aplica VP-002.

Hardware Mode permanece fuera del alcance de la primera implementación.

Un SystemProfile con contexto Hardware podrá representarse, pero no activarse hasta que exista Hardware Mode compiler.

## 7. Dependencias versionadas

SystemProfile no embebe copias completas de DeviceProfile.

Cada DeviceConfiguration conserva:

```text
Profile ID
+
Profile Version
```

Estas referencias forman el dependency lock de la composición.

La resolución siempre utiliza coincidencia exacta.

No se permite:

```text
latest

nearest

compatible enough

fallback automático
```

Si la versión exacta no existe, la compilación falla.

## 8. Razón para no embeber DeviceProfiles

Embeber DeviceProfiles completos dentro de SystemProfile produciría:

- duplicación;
- divergencia;
- archivos mayores;
- ambigüedad sobre definición canónica;
- actualización difícil;
- conflictos entre snapshot embebido y catálogo.

La portabilidad futura podrá resolverse mediante un bundle explícito.

Un bundle no cambia la identidad versionada de las dependencias.

## 9. DeviceConfiguration en SystemProfile

SystemProfile contiene DeviceConfiguration snapshots validados.

No contiene:

```text
DeviceConfigurationDraft
```

Flujo correcto:

```text
DeviceConfigurationDraft
		│
		▼
DeviceConfigurationCompiler
		│
		▼
DeviceConfiguration
		│
		▼
SystemProfileDraft
```

SystemProfileCompiler no compila DeviceConfigurationDraft.

Esto conserva una responsabilidad por compiler.

## 10. SystemProfileDraft

SystemProfileDraft representa una composición editable.

Puede estar:

- vacío;
- incompleto;
- desconectado;
- con dependencias faltantes;
- con Connections todavía inválidas;
- en proceso de edición.

SystemProfileDraft no:

- ejecuta;
- crea DeviceGraph;
- abre archivos;
- resuelve factories;
- controla DeviceBus;
- inicia Devices.

La edición ocurre mediante API controlada o herramientas externas.

## 11. SystemProfileCompiler

Responsabilidad:

> Validar SystemProfileDraft y producir un SystemProfile snapshot.

SystemProfileCompiler valida inicialmente:

- System Profile ID;
- versión positiva;
- display name;
- Activation Context;
- DeviceConfigurations no null;
- DeviceConfigurations válidas;
- Device IDs únicos;
- Profile references exactas;
- dependencias disponibles;
- Activation Context coherente;
- Connection Specifications válidas;
- endpoints referencian Device IDs conocidos;
- Connection Specifications no duplicadas;
- separador reservado;
- orden determinista.

SystemProfileCompiler no:

- construye DeviceGraphNode;
- construye DeviceManifest;
- valida Topics de Ports;
- detecta ciclos;
- crea Snapshot de Graph;
- crea Devices runtime;
- guarda archivos.

## 12. SystemProfile

SystemProfile es un snapshot lógico:

```text
RefCounted

inmutable por contrato

independiente de filesystem

independiente de UI

independiente de runtime
```

SystemProfile copia colecciones durante construcción.

Los getters devuelven colecciones independientes.

No expone setters.

SystemProfile representa una composición estructuralmente válida.

No significa todavía:

- Graph válido;
- CompositionPlan válido;
- runtime activable;
- Hardware autorizado.

## 13. SystemConnectionSpec

SystemProfile no almacena directamente DeviceGraphConnection.

Utiliza una especificación lógica previa al Graph:

```text
SystemConnectionSpec
```

Campos conceptuales:

```text
Connection ID

Source Device ID

Source Port ID

Target Device ID

Target Port ID
```

No almacena:

- Topic duplicado;
- Semantic Kind duplicado;
- referencia a DeviceGraphNode;
- referencia a DeviceBus;
- Callable;
- objeto runtime.

Topic y Semantic Kind se resuelven posteriormente mediante:

- DeviceProfile;
- DeviceConfiguration;
- DeviceManifest;
- Ports generados.

Esto evita dos fuentes de verdad.

## 14. SystemConnectionSpec ID

Connection ID utiliza formato determinista:

```text
source_device_id
|
source_port_id
|
target_device_id
|
target_port_id
```

El caller no proporciona un ID arbitrario.

El separador:

```text
|
```

permanece reservado.

SystemConnectionSpec y DeviceGraphConnection utilizan identidad compatible.

## 15. Graph validation diferida

SystemProfileCompiler valida que los endpoints referencien Device IDs conocidos.

No valida todavía:

- existencia real del Port;
- Topic compatibility;
- Semantic Kind;
- InputPort cardinality;
- ciclos;
- TopicChannel Registry.

Estas validaciones pertenecen a:

```text
DeviceGraphAssembler

+

DeviceGraphValidator
```

SystemProfile válido no implica Graph válido.

Cada etapa produce su propio ValidationReport.

## 16. DeviceProfileResolver

SystemProfileCompiler y DeviceGraphAssembler dependen de un rol de resolución por comportamiento.

Contrato conceptual:

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

No se exige una clase base universal.

El resolver debe devolver únicamente coincidencia exacta.

Durante una operación de compilación, la resolución debe ser estable.

## 17. DeviceCatalog

DeviceCatalog será una implementación de DeviceProfileResolver.

Responsabilidad:

> Resolver DeviceProfile snapshots mediante ID y versión.

DeviceCatalog no:

- crea Devices runtime;
- conoce factories;
- inicia escenas;
- guarda SystemProfiles;
- compila DeviceGraph;
- ejecuta CompositionPlan;
- decide Hardware Mode;
- dibuja UI.

La carga persistente del catálogo pertenece a componentes externos.

## 18. Dependencia faltante

Si DeviceProfileResolver no contiene la referencia exacta:

```text
Profile ID
+
Profile Version
```

SystemProfileCompiler produce:

```text
STRUCTURAL_ERROR

code:
system_profile_dependency_missing
```

No se sustituye automáticamente por otra versión.

El resultado no contiene SystemProfile snapshot.

## 19. SystemProfile vacío

Un SystemProfile sin DeviceConfigurations es estructuralmente válido cuando:

- tiene identidad válida;
- tiene versión válida;
- tiene Display Name;
- tiene Activation Context válido;
- no contiene Connections.

Razón:

- el conjunto vacío no contiene referencias corruptas;
- herramientas pueden comenzar desde una composición vacía;
- utilidad runtime pertenece a CompositionCompiler.

CompositionCompiler podrá rechazar un plan sin Devices.

## 20. Persistencia

SystemProfile no abre ni guarda archivos.

Componentes externos futuros:

```text
SystemProfileDocument

SystemProfileLoader

SystemProfileSerializer

SaveAsService
```

El formato persistente podrá ser:

- `.tres`;
- JSON;
- otro formato versionado.

La elección de formato no modifica el contrato lógico de SystemProfile.

## 21. SystemProfileDocument

Un documento persistente es un DTO.

Puede contener:

- valores primitivos;
- IDs;
- versiones;
- listas;
- Connection Specifications serializadas.

No contiene comportamiento de dominio.

No sustituye SystemProfile.

Loader y Serializer convierten entre documento y modelo lógico.

## 22. Save As Service

SaveAsService será responsable de:

- solicitar destino;
- validar extensión;
- evitar overwrite accidental;
- escribir de forma segura;
- reportar errores de filesystem;
- conservar el documento anterior ante fallo.

No pertenece a SystemProfile.

No se implementará en la primera etapa del pipeline.

## 23. DeviceGraphAssembler

Responsabilidad:

> Construir DeviceGraphSnapshot desde SystemProfile y DeviceProfiles resueltos.

Flujo conceptual:

```text
SystemProfile
		│
		├── DeviceConfigurations
		└── SystemConnectionSpecs
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

DeviceGraphAssembler no:

- guarda archivos;
- crea Devices runtime;
- conoce factories;
- ejecuta CompositionPlan;
- modifica SystemProfile;
- modifica DeviceProfiles.

## 24. DeviceGraphAssemblyResult

DeviceGraphAssembler utilizará un Result propio cuando sea implementado.

Contenido conceptual:

```text
DeviceGraphSnapshot

ValidationReport
```

No se reutiliza automáticamente DeviceGraphSnapshotResult si eso oculta errores previos al Draft.

El diseño concreto decidirá si puede componerse con SnapshotResult sin mezclar responsabilidades.

## 25. RuntimeFactoryRegistry

RuntimeFactoryRegistry permanece separado de DeviceCatalog.

```text
DeviceCatalog:
qué definición lógica existe.

RuntimeFactoryRegistry:
cómo construir una implementación runtime.
```

RuntimeFactoryRegistry podrá resolver mediante una identidad futura como:

```text
Profile ID

Device Type

Runtime Adapter ID
```

La identidad concreta se definirá antes de implementación.

RuntimeFactoryRegistry no almacena DeviceProfile como autoridad canónica.

## 26. CompositionCompiler

Responsabilidad:

> Convertir DeviceGraphSnapshot en CompositionPlan.

CompositionCompiler puede utilizar:

- DeviceGraphSnapshot;
- RuntimeFactoryRegistry;
- políticas runtime;
- contexto de activación;
- ValidationReport.

CompositionCompiler no:

- crea Devices;
- inicia Devices;
- crea SceneTree;
- posee DeviceBus activo;
- abre archivos;
- guarda SystemProfile;
- modifica Graph Snapshot.

## 27. CompositionPlan

CompositionPlan es:

```text
RefCounted

inmutable por contrato

validado

no ejecutable por sí solo
```

Podrá describir:

- orden de creación;
- factory bindings;
- Device IDs;
- configuraciones;
- suscripciones;
- orden de inicialización;
- orden de start;
- orden de shutdown;
- Dispatch Policy;
- supervisión requerida.

El contenido concreto se definirá en diseño posterior.

## 28. CompositionRuntime

Responsabilidad:

> Ejecutar un CompositionPlan validado.

CompositionRuntime será propietario de:

- DeviceBus runtime;
- Devices activos;
- runtime adapters;
- suscripciones;
- lifecycle coordinado;
- shutdown;
- observación de DispatchReport;
- recuperación o detención controlada.

CompositionRuntime no recibe:

- SystemProfileDraft;
- documentos persistentes;
- Graph Draft;
- UI widgets.

## 29. Ownership de DeviceBus

CompositionRuntime o su Composition Root crea DeviceBus.

SystemProfile, DeviceCatalog, DeviceGraph y CompositionCompiler no poseen un Bus activo.

Flujo:

```text
CompositionPlan
		│
		▼
CompositionRuntime
		│
		├── crea DeviceBus
		├── crea Devices mediante factories
		├── entrega dependencias
		├── inicializa
		├── inicia
		└── apaga
```

## 30. ValidationReport por etapa

Cada etapa produce su propio ValidationReport.

```text
SystemProfileCompiler:
valida definición y dependencias.

DeviceGraphAssembler:
valida construcción del Graph.

DeviceGraphValidator:
valida topología.

CompositionCompiler:
valida plan runtime.

CompositionRuntime:
reporta estado de activación.
```

Los Reports no se mezclan mediante pérdida de provenance.

Una etapa puede agregar Issues anteriores a un resultado compuesto, pero debe conservar el origen de la etapa.

## 31. Contextos y VP-002

### Draft

Puede estar incompleto.

No ejecuta.

### Active Simulation

Requiere:

```text
SystemProfile válido para Simulation

DeviceGraphSnapshot válido para Simulation

CompositionPlan válido para Simulation
```

Puede aceptar Simulation Hazard.

### Active Hardware

Requiere:

```text
SystemProfile válido para Hardware

DeviceGraphSnapshot válido para Hardware

CompositionPlan válido para Hardware

Hardware Safety validation
```

No acepta Simulation Hazard.

Hardware Mode permanece fuera de alcance inicial.

## 32. Transaccionalidad

Cada transición produce un objeto nuevo.

```text
Draft
→ Snapshot

SystemProfile
→ DeviceGraphSnapshot

DeviceGraphSnapshot
→ CompositionPlan

CompositionPlan
→ Active Runtime
```

Una etapa fallida:

- no modifica la entrada;
- no reemplaza Last Known Good;
- no activa parcialmente runtime;
- devuelve un Result;
- conserva ValidationReport.

## 33. Orden determinista

SystemProfile conserva orden explícito para:

- DeviceConfigurations;
- Connection Specifications.

DeviceGraphAssembler conserva ese orden al crear:

- DeviceGraphNodes;
- Connections.

CompositionCompiler produce un plan determinista para las mismas entradas y dependencias.

No se depende de orden accidental de filesystem.

## 34. Versionado

Versiones son enteros positivos.

Las referencias son exactas.

Una versión nueva no reemplaza silenciosamente una versión anterior.

Migración pertenece a un servicio explícito futuro.

No se modifica un snapshot existente para convertirlo en otra versión.

## 35. Alternativas descartadas

### SystemProfile embebe DeviceProfiles

Descartado por duplicación y divergencia.

### SystemProfile como Resource mutable directo

Descartado porque mezcla dominio, mutabilidad y persistencia.

### Dictionary o JSON como modelo de dominio

Descartado porque elimina contratos tipados y Draft–Snapshot.

### Persistir DeviceGraphSnapshot directamente

Descartado porque Graph Snapshot no contiene identidad completa de composición ni dependency lock como responsabilidad principal.

### Resolver automáticamente latest version

Descartado porque rompe reproducibilidad.

### DeviceCatalog contiene factories

Descartado porque mezcla definición lógica y construcción runtime.

### CompositionCompiler crea Devices

Descartado porque mezcla compilación y ejecución.

### CompositionRuntime carga archivos

Descartado porque mezcla runtime y persistencia.

### GraphEditor define SystemProfile

Descartado porque UI no define el Core.

### Un componente CompositionManager monolítico

Descartado porque mezclaría todas las etapas.

## 36. Consecuencias positivas

- dependencias explícitas;
- versiones reproducibles;
- Core independiente de archivos;
- persistencia sustituible;
- Graph reutilizable;
- runtime auditable;
- CompositionPlan inspeccionable;
- Hardware más seguro;
- herramientas visuales posibles;
- pruebas aisladas por etapa;
- Last Known Good preservado;
- factories separadas de definiciones.

## 37. Consecuencias negativas

- más componentes;
- más Results;
- más etapas de validación;
- necesidad de resolver dependencias;
- compartir un SystemProfile requiere Profiles compatibles;
- se necesita DeviceGraphAssembler;
- se necesita RuntimeFactoryRegistry;
- persistencia requiere adapters externos;
- activación no será inmediata desde un archivo.

Estas consecuencias son aceptadas.

## 38. Invariantes

1. SystemProfileDraft es editable.

2. SystemProfile es inmutable.

3. SystemProfile no abre archivos.

4. SystemProfile no embebe DeviceProfiles completos.

5. DeviceProfile references utilizan ID y versión exactos.

6. DeviceConfigurations incluidas son snapshots.

7. SystemProfile declara Activation Context.

8. Todas las Configurations coinciden con el contexto.

9. SystemProfileCompiler no construye DeviceGraph.

10. DeviceGraphAssembler no crea runtime.

11. DeviceCatalog no contiene factories runtime.

12. RuntimeFactoryRegistry no es catálogo canónico de Profiles.

13. CompositionCompiler no ejecuta.

14. CompositionPlan es inmutable.

15. CompositionRuntime no carga Drafts o documentos.

16. Cada etapa produce Result y ValidationReport.

17. Fallo conserva Last Known Good.

18. Orden es determinista.

19. No existe fallback automático de versión.

20. Hardware requiere validación más estricta.

21. UI depende del pipeline; el pipeline no depende de UI.

22. Persistencia depende del modelo; el modelo no depende del formato.

## 39. Criterios de aceptación arquitectónica

ADR-009 se considera implementado cuando:

1. existe SystemConnectionSpec;

2. existe SystemProfileDraft;

3. existe SystemProfile;

4. existe SystemProfileCompileResult;

5. existe SystemProfileCompiler;

6. referencias exactas son validadas;

7. dependencia faltante produce Structural Error;

8. Activation Context es coherente;

9. Device IDs duplicados son rechazados;

10. Connection Specifications duplicadas son rechazadas;

11. endpoints desconocidos son rechazados;

12. colecciones devueltas son copias;

13. snapshots no tienen setters;

14. existe contrato de DeviceProfileResolver;

15. DeviceCatalog implementa resolución exacta;

16. existe DeviceGraphAssembler;

17. Graph assembly produce Result;

18. existe contrato de RuntimeFactoryRegistry;

19. CompositionCompiler produce CompositionPlan;

20. CompositionPlan es inmutable;

21. CompositionRuntime posee recursos activos;

22. persistencia permanece externa;

23. pruebas sucesoras terminan PASS;

24. regresión completa termina PASS.

Los criterios podrán satisfacerse mediante varios milestones.

## 40. Fuera de alcance inicial

La primera implementación no incluirá todavía:

- GraphEditor;
- ConfigurationEditor;
- GraphLayout;
- formato persistente definitivo;
- SaveAsService;
- bundle portable;
- migración automática;
- descarga remota de Profiles;
- marketplace;
- Hardware Mode activo;
- factories de hardware;
- Calibration;
- AdaptationPolicy;
- RuntimeAllocation;
- hot reload de runtime;
- distributed runtime;
- red;
- telemetría;
- UI.

## 41. Orden arquitectónico propuesto

```text
1. Aceptar ADR-009.

2. Crear System Composition Pipeline Design.

3. Implementar SystemConnectionSpec.

4. Implementar SystemProfileDraft.

5. Implementar DeviceProfileResolver contract.

6. Implementar SystemProfile.

7. Implementar SystemProfileCompileResult.

8. Implementar SystemProfileCompiler.

9. Crear pruebas de SystemProfile.

10. Diseñar DeviceCatalog.

11. Implementar DeviceCatalog.

12. Diseñar DeviceGraphAssembler.

13. Implementar DeviceGraphAssembler.

14. Diseñar RuntimeFactoryRegistry.

15. Diseñar CompositionPlan.

16. Diseñar CompositionCompiler.

17. Implementar Compilation Pipeline.

18. Diseñar CompositionRuntime.

19. Implementar activación de Simulation.

20. Diseñar persistencia externa.
```

## 42. Estado

ADR-009 define la dirección del pipeline.

No autoriza todavía implementación de:

- SystemProfile;
- DeviceCatalog;
- DeviceGraphAssembler;
- CompositionCompiler;
- CompositionRuntime.

Primero debe ser revisado y aceptado.
