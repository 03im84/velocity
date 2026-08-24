# Velocity — Engineering Standards

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.3 |
| Última revisión | 23/08/2026 |
| Engine | Godot Engine 4.7.1 stable |
| Alcance | Arquitectura, implementación, pruebas, documentación y Git |

## 1. Propósito

Este documento define las reglas de ingeniería obligatorias para Velocity.

Su objetivo es mantener:

- responsabilidades claras;
- componentes sustituibles;
- código verificable;
- pruebas reproducibles;
- documentación vigente;
- seguridad de plataforma;
- evolución arquitectónica controlada.

Estas reglas se aplican a:

- Core;
- Devices;
- Providers;
- DeviceBus;
- Profiles;
- Configurations;
- DeviceGraph;
- System Composition;
- DeviceCatalog;
- herramientas;
- pruebas;
- documentación;
- integración futura con hardware.

Una implementación que funciona pero contradice estas reglas no se considera terminada.

## 2. Principios rectores

### 2.1 La arquitectura precede al código

Antes de implementar una característica importante se define:

1. problema;

2. análisis;

3. decisión arquitectónica;

4. responsabilidad;

5. dependencias;

6. contrato público;

7. estrategia de pruebas.

No se escribe código para descubrir después qué responsabilidad debía tener.

### 2.2 Una responsabilidad por componente

Cada componente debe poder describirse mediante una responsabilidad principal.

Si una descripción requiere varias responsabilidades independientes, el componente debe dividirse.

Ejemplo correcto:

```text
DeviceGraphDraft:
mantener topología editable.

DeviceGraphValidator:
validar topología.

DeviceGraphSnapshot:
representar topología validada e inmutable.
```

Ejemplo incorrecto:

```text
DeviceGraph:
editar, validar, ejecutar, serializar,
dibujar UI y controlar hardware.
```

### 2.3 Rediseñar antes que parchear

Si cambia la responsabilidad de un componente, se rediseña.

No se añade una condición, flag o dependencia únicamente para conservar una responsabilidad equivocada.

Una corrección local es válida conceptualmente cuando:

- la responsabilidad sigue siendo correcta;
- el contrato no cambia de significado;
- la modificación permanece dentro del componente responsable;
- las pruebas existentes se conservan.

Aunque el cambio conceptual sea local, la entrega se realiza mediante el archivo completo consolidado.

### 2.4 Composición sobre herencia

Se prefiere composición cuando:

- las responsabilidades pueden existir de forma independiente;
- una dependencia puede ser sustituida;
- una implementación necesita un comportamiento, no una identidad;
- una jerarquía obligaría a heredar estado o métodos innecesarios.

La herencia se utiliza cuando existe una relación real y estable de especialización.

### 2.5 Simplicidad es una característica

No se añade:

- abstracción sin necesidad;
- clase universal;
- singleton por comodidad;
- metadata futura sin consumidor;
- generalización sin caso concreto;
- configuración que todavía no puede validarse.

La solución más pequeña que conserva responsabilidad, seguridad y extensibilidad es preferida.

### 2.6 La documentación es parte del producto

Una característica estructural no está completa si:

- su decisión no está registrada;
- su diseño está desactualizado;
- sus pruebas no están registradas;
- Core Architecture todavía describe el estado anterior;
- el journal no registra el milestone.

### 2.7 El archivo completo es la unidad de entrega

La unidad de modificación entregada al usuario es el archivo completo.

Aplica a:

- código;
- tests;
- escenas;
- documentos;
- configuraciones;
- scripts de herramientas;
- journals nuevos;
- archivos de diseño;
- ADR;
- Core Architecture.

No se entregan instrucciones quirúrgicas para reconstruir un archivo existente.

### 2.8 Estado canónico único

Después de una modificación debe existir una sola versión canónica completa del archivo.

No se distribuye el estado final entre:

- fragmentos;
- reemplazos parciales;
- mensajes anteriores;
- instrucciones “inserta después de”;
- instrucciones “elimina esta parte”;
- parches manuales.

## 3. Metodología obligatoria

Toda característica importante utiliza este orden:

```text
1. Problema

2. Análisis

3. ADR

4. Diseño del componente

5. Implementación

6. Pruebas unitarias

7. Pruebas de integración

8. Refactorización
```

### 3.1 Problema

Debe describir:

- qué necesidad existe;
- por qué el sistema actual no la resuelve;
- qué riesgo existe si no se resuelve;
- qué queda fuera de alcance.

### 3.2 Análisis

Debe evaluar:

- responsabilidades;
- dependencias;
- alternativas;
- tradeoffs;
- seguridad;
- compatibilidad;
- impacto sobre baselines.

No se modifica código durante análisis.

### 3.3 ADR

Se crea o actualiza un ADR cuando cambia:

- responsabilidad;
- propiedad;
- dirección de dependencias;
- modelo de datos;
- política de seguridad;
- ciclo de vida;
- contrato estructural.

No se crea un ADR nuevo cuando la decisión pertenece claramente al alcance de uno existente.

En ese caso se actualiza su versión.

### 3.4 Diseño

El diseño define:

- archivos;
- clases;
- estado;
- API;
- invariantes;
- códigos de validación;
- estrategia de pruebas;
- orden de implementación;
- criterios de aceptación.

No se modifica código mientras el diseño permanece abierto.

### 3.5 Implementación

La implementación comienza únicamente después de aceptar responsabilidad y contrato.

Los componentes nuevos se introducen de forma incremental.

Cada parser gate debe pasar antes de añadir la siguiente responsabilidad.

Cuando un archivo cambia, se entrega de nuevo completo.

### 3.6 Pruebas unitarias

Cada componente nuevo recibe una prueba nueva e independiente.

Una prueba aceptada no se modifica para validar otra arquitectura.

### 3.7 Pruebas de integración

Después de pruebas aisladas se ejecuta:

```text
Run All
```

La ejecución autoritativa utiliza Godot Console en modo headless.

### 3.8 Refactorización

Solo se refactoriza cuando existe una necesidad observada:

- duplicación;
- responsabilidad mezclada;
- algoritmo inseguro;
- API ambigua;
- dificultad de prueba;
- dependencia incorrecta.

No se refactoriza por gusto después de una regresión satisfactoria.

Si una refactorización modifica un archivo, se entrega el archivo completo resultante.

## 4. Responsabilidad y dependencias

### 4.1 Dependencias explícitas

Las dependencias se entregan explícitamente cuando sea posible.

No se descubren mediante:

- rutas globales;
- búsquedas en SceneTree;
- autoloads por comodidad;
- singletons ocultos;
- nombres mágicos de Nodes.

### 4.2 Dirección de dependencia

Las implementaciones concretas dependen de contratos internos.

Los contratos internos no dependen de:

- UI;
- telemetría;
- hardware;
- escenas concretas;
- herramientas visuales;
- implementaciones específicas.

### 4.3 Componentes del Core

Los componentes del Core no conocen infraestructura que no necesitan.

Ejemplos:

```text
DeviceBus no conoce DeviceGraph.

DeviceGraph no conoce DeviceBus runtime.

Provider no conoce consumidores.

SystemProfile no conoce DeviceGraph.

DeviceCatalog no conoce SystemProfileCompiler.

DeviceCatalog no conoce runtime factories.

DeviceGraphAssembler no conoce runtime factories.

DeviceGraphSnapshot no conoce CompositionRuntime.

Simulation no conoce Telemetry transport.
```

### 4.4 Creación de componentes

Un componente crea otro únicamente cuando esa creación forma parte de su responsabilidad.

Cuando la creación pertenece al ensamblaje del sistema se utiliza una Composition Root.

## 5. Godot Engine

### 5.1 Versión autoritativa

Velocity utiliza:

```text
Godot Engine 4.7.1 stable
```

Los contratos se verifican contra esta versión.

### 5.2 Core lógico

Los componentes lógicos del Core utilizan preferentemente:

```gdscript
RefCounted
```

cuando no necesitan:

- SceneTree;
- `_process`;
- `_physics_process`;
- transform;
- lifecycle de Node;
- editor visual.

### 5.3 Uso de Node

Se utiliza `Node`, `Node3D` u otra clase visual cuando el componente necesita realmente:

- pertenecer a SceneTree;
- lifecycle de Godot;
- acceso al mundo;
- transform;
- física;
- rendering;
- Signals locales.

### 5.4 SceneTree no es arquitectura

Las rutas de escena no definen dependencias del Core.

Una escena puede actuar como Composition Root, pero el Core no descubre dependencias recorriendo el árbol.

### 5.5 Autoloads

Se utilizan pocos autoloads.

Ningún componente se convierte en autoload:

- por comodidad;
- para evitar inyección de dependencias;
- para simular una variable global;
- para ocultar ownership.

### 5.6 Unidades

Las unidades internas siguen el Sistema Internacional.

Ejemplos:

```text
distancia:
metros

tiempo:
segundos

velocidad:
metros por segundo

fuerza:
newtons

masa:
kilogramos
```

Las conversiones de presentación ocurren fuera del estado canónico.

## 6. Convenciones de nombres y rutas

### 6.1 Escenas

Las escenas utilizan PascalCase:

```text
DeviceGraphSnapshotTest.tscn
DistanceSensorPhysicsIntegrationTest.tscn
```

### 6.2 Scripts

Los scripts utilizan snake_case:

```text
device_graph_snapshot.gd
distance_sensor_device.gd
```

### 6.3 Resources

Los Resources utilizan snake_case:

```text
ideal_distance_sensor.tres
hover_mcu_configuration.tres
```

### 6.4 Clases

Las clases globales utilizan PascalCase:

```gdscript
class_name DeviceGraphSnapshot
class_name DeviceBusDispatchPolicy
```

### 6.5 Métodos y variables

Métodos y variables utilizan snake_case:

```gdscript
create_snapshot()
source_device_id
```

### 6.6 Constantes

Las constantes utilizan UPPER_SNAKE_CASE:

```gdscript
const CONNECTION_ID_SEPARATOR: String = "|"
```

### 6.7 Error codes

Los códigos de validación utilizan `StringName` y lower_snake_case:

```gdscript
&"duplicate_device_id"
&"input_port_multiple_sources"
&"graph_cycle_requires_temporal_analysis"
```

### 6.8 IDs

Los IDs lógicos se tratan como datos de dominio.

No se construyen con:

- paths de escena;
- instance IDs de Godot;
- nombres visuales;
- índices temporales.

## 7. Formato GDScript

### 7.1 Ninguna línea comienza con punto

Incorrecto:

```gdscript
object
	.method()
```

Correcto:

```gdscript
object.method()
```

### 7.2 No separar acceso de miembro

Se conserva en la misma línea física:

```gdscript
object.property
object.method()
ClassName.CONSTANT
```

Incorrecto:

```gdscript
object
	.property
```

Incorrecto:

```gdscript
ClassName
	.CONSTANT
```

### 7.3 Cadenas de métodos

No se parte una cadena colocando `.` al comienzo de otra línea.

Si la expresión es larga se utiliza una variable intermedia.

Correcto:

```gdscript
var builder := DeviceManifestBuilder.new()

var result := builder.build(
	profile,
	configuration
)
```

### 7.4 Tipos de colecciones

`Array[Type]` debe permanecer completo en una línea física.

Correcto:

```gdscript
var devices: Array[DeviceGraphNode] = []
```

Incorrecto:

```gdscript
var devices: Array[
	DeviceGraphNode
] = []
```

`Dictionary[Key, Value]` también permanece completo en una línea.

Correcto:

```gdscript
var devices_by_id: Dictionary[String, DeviceGraphNode] = {}
```

### 7.5 Literales largos

Si una cadena, ID o expresión es demasiado larga, se utilizan variables intermedias.

No se rompe una expresión en posiciones que hagan ambiguo el parser.

### 7.6 Firmas

Las firmas multilínea mantienen:

- nombre;
- argumentos;
- tipo de retorno;
- tipo de colección completo.

Ejemplo:

```gdscript
func validate(
	devices: Array[DeviceGraphNode],
	connections: Array[DeviceGraphConnection]
) -> ValidationReport:
```

### 7.7 Tipos explícitos

Se utilizan tipos explícitos cuando:

- forman parte del contrato;
- evitan Variant innecesario;
- documentan colecciones;
- previenen incompatibilidades;
- mejoran el análisis estático.

### 7.8 Null

Un componente que acepta `null` debe definir explícitamente:

- qué significa;
- qué resultado produce;
- si modifica estado;
- qué error se reporta.

### 7.9 Getters y setters

Snapshots y objetos inmutables exponen getters.

No exponen setters para campos que forman parte de su identidad.

Drafts pueden exponer campos editables cuando esa mutabilidad forma parte de su responsabilidad.

## 8. Métodos heredados de Object

Antes de nombrar un método público en una clase derivada de `Object`, se revisan los métodos nativos existentes.

No se ocultan con firmas incompatibles métodos como:

```text
connect()

disconnect()

emit_signal()

call()

free()

get()

set()
```

Incorrecto:

```gdscript
extends RefCounted

func connect(
	source_id: String,
	target_id: String
) -> bool:
```

Correcto:

```gdscript
func connect_ports(
	source_device_id: String,
	source_port_id: StringName,
	target_device_id: String,
	target_port_id: StringName
) -> DeviceGraphOperationResult:
```

Correcto:

```gdscript
func disconnect_ports(
	connection_id: StringName
) -> DeviceGraphOperationResult:
```

## 9. Contratos y datos

### 9.1 StringName

Se utiliza `StringName` para identidades canónicas repetidas:

- Topics;
- semantic kinds;
- roles;
- códigos;
- Connection IDs;
- Profile IDs;
- System Profile IDs.

### 9.2 String

Se utiliza `String` para:

- Device IDs;
- texto descriptivo;
- mensajes;
- rutas;
- contenido editable.

### 9.3 Objetos inmutables

Un objeto tratado como snapshot:

- recibe estado durante construcción;
- copia colecciones mutables;
- no expone setters;
- devuelve copias de colecciones;
- conserva identidad estable.

### 9.4 Referencias inmutables

Referencias a objetos inmutables pueden compartirse.

No se realizan deep copies sin una necesidad concreta.

### 9.5 Variant

`Variant` se utiliza cuando la abstracción requiere transportar datos heterogéneos.

No se utiliza para evitar definir un contrato conocido.

### 9.6 Roles por comportamiento

Cuando una dependencia representa una capacidad y no una identidad común, puede definirse mediante comportamiento.

Ejemplos:

```text
Provider

DeviceProfileResolver
```

No se crea una clase base universal únicamente para expresar el contrato.

## 10. Draft, Compiler y Snapshot

### 10.1 Draft

Draft representa estado editable.

Puede estar:

- incompleto;
- inválido;
- experimental.

Draft no se utiliza directamente por runtime.

### 10.2 Compiler

Compiler:

- recibe Draft o snapshots de entrada;
- valida;
- produce un nuevo snapshot o plan;
- no modifica las entradas;
- devuelve un Result con ValidationReport.

### 10.3 Snapshot

Snapshot:

- representa estado validado;
- es inmutable por contrato;
- copia colecciones;
- no expone mutaciones;
- no ejecuta comportamiento salvo que su responsabilidad lo exija explícitamente.

### 10.4 Result

Los Results:

- representan éxito o fallo;
- contienen producto y ValidationReport;
- no exponen setters;
- permiten fallo esperado de dominio.

### 10.5 Last Known Good

Una operación fallida no modifica el último estado válido.

```text
estado válido

↓

operación propuesta

↓

validación

├── éxito:
│   nuevo estado válido
│
└── fallo:
	estado válido anterior
```

## 11. Mutaciones transaccionales

Toda mutación estructural:

1. valida argumentos;

2. calcula el cambio;

3. comprueba invariantes;

4. aplica el cambio completo;

5. o no modifica el componente.

Una operación fallida no debe:

- insertar parcialmente;
- borrar parcialmente;
- dejar referencias huérfanas;
- contaminar un Report posterior;
- alterar Last Known Good.

## 12. ValidationIssue y ValidationReport

### 12.1 Categorías

```text
INFO

WARNING

STRUCTURAL_ERROR

PLATFORM_SAFETY_ERROR

SIMULATION_HAZARD

HARDWARE_SAFETY_ERROR
```

### 12.2 Simulation Mode

Simulation puede aceptar:

- INFO;
- WARNING;
- SIMULATION_HAZARD;
- Hardware Safety Error cuando la política lo permita.

No acepta:

- Structural Error;
- Platform Safety Error.

### 12.3 Hardware Mode

Hardware no acepta:

- Structural Error;
- Platform Safety Error;
- Simulation Hazard;
- Hardware Safety Error.

### 12.4 Códigos

Tests y herramientas comprueban códigos estables, no texto de presentación.

### 12.5 No mutación

ValidationReport describe.

No corrige automáticamente el objeto validado.

## 13. Runtime Safety

### 13.1 Regla principal

> La simulación puede fallar. El simulador no.

### 13.2 Nunca permitido

Una configuración del usuario no puede provocar:

- stack overflow;
- recursión ilimitada;
- queue ilimitada;
- crecimiento ilimitado de memoria;
- bloqueo permanente;
- corrupción de datos;
- pérdida de Last Known Good;
- activación insegura de hardware;
- pérdida de control del editor.

### 13.3 Algoritmos sobre datos del usuario

Los algoritmos deben ser:

- iterativos cuando profundidad no está acotada;
- lineales o justificadamente acotados;
- deterministas;
- capaces de abortar o reportar;
- resistentes a entradas mal formadas.

### 13.4 Defensa en profundidad

```text
Draft validation

+

Snapshot validation

+

Dependency resolution

+

Graph assembly

+

Compiler validation

+

Runtime budgets

+

Runtime supervision
```

## 14. DeviceBus

DeviceBus transporta mensajes.

No interpreta payloads ni topología.

Tiene propietario explícito.

No es autoload, singleton global ni Node por conveniencia.

Dispatch utiliza:

- FIFO iterativo;
- Publication Budget;
- Callback Budget;
- Queue Size Limit;
- Time Budget;
- hard maximums;
- aborto controlado;
- DispatchReport;
- recuperación.

## 15. DeviceGraph

Responsabilidades:

```text
DeviceGraphDraft:
edición transaccional.

DeviceGraphValidator:
validación global.

DeviceGraphSnapshot:
estructura validada e inmutable.
```

DeviceGraph no ejecuta.

Connection IDs son deterministas.

Fan-out está permitido.

Fan-in implícito está rechazado.

Los ciclos se detectan sin recursión.

Un ciclo sin evidencia temporal produce:

```text
SIMULATION_HAZARD

graph_cycle_requires_temporal_analysis
```

## 16. System Composition

### 16.1 Pipeline

```text
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

### 16.2 DeviceCatalog

```text
DeviceCatalogDraft
		│
		▼
DeviceCatalogCompiler
		│
		▼
DeviceCatalog
```

DeviceCatalog:

- es inmutable;
- conserva múltiples versiones;
- rechaza duplicados exactos;
- no tiene ID propio;
- no tiene versión propia;
- no conoce factories;
- no abre archivos.

### 16.3 DeviceGraphAssembler

DeviceGraphAssembler:

- es stateless;
- soporta Simulation;
- rechaza Hardware;
- procesa Devices antes de Connections;
- agrega Reports por etapas;
- no devuelve Graph parcial;
- no modifica entradas;
- no crea runtime.

### 16.4 Factories

RuntimeFactoryRegistry permanece separado de DeviceCatalog.

```text
DeviceCatalog:
qué definición existe.

RuntimeFactoryRegistry:
cómo construir runtime.
```

### 16.5 No ejecución prematura

SystemProfile no construye Graph.

DeviceCatalog no crea Devices.

DeviceGraphAssembler no ejecuta runtime.

CompositionCompiler no crea Devices.

CompositionPlan no ejecuta.

CompositionRuntime poseerá recursos activos.

## 17. Pruebas

### 17.1 Naming

Escena:

```text
ComponentNameTest.tscn
```

Script:

```text
component_name_test.gd
```

### 17.2 Independencia

Cada test crea sus objetos y no depende del orden de ejecución.

### 17.3 Salida

```text
[PASS] descripción

Checks: N
Failures: N
RESULT: PASS o FAIL
```

### 17.4 Fallos

Ante un fallo:

1. no modificar código inmediatamente;

2. capturar primer error completo;

3. identificar archivo y línea;

4. clasificar parser, contrato o comportamiento;

5. después proponer cambio.

### 17.5 Baselines

Una prueba aceptada es baseline inmutable.

Otra arquitectura requiere prueba sucesora.

### 17.6 Ejecución autoritativa

```text
Godot Console
+
headless
+
Velocity Test Runner
```

### 17.7 Códigos del runner

```text
124:
TIMEOUT

125:
proceso no confirmado

126:
ENGINE_ERROR con ExitCode Godot 0
```

## 18. Archivos generados y UID

Los `*.gd.uid` generados por Godot se versionan con su script.

No se crean manualmente.

No se versionan:

```text
__pycache__/
*.py[cod]
```

Estado local y archivos accidentales no entran al repositorio.

## 19. Documentación

### 19.1 Rutas

ADR:

```text
res://docs/architecture/adr/
```

Diseños:

```text
res://docs/architecture/
```

Engineering Notes:

```text
res://docs/engineering_notes/
```

Project Journal:

```text
res://docs/project_journal/
```

### 19.2 Journal

Formato:

```text
pjXXXX_DDMMAA.txt
```

Zona horaria:

```text
GMT-5
sin DST
```

### 19.3 Encoding

Documentos se guardan como UTF-8.

No se copian caracteres mojibake.

### 19.4 Entrega completa universal

Toda modificación entregada se proporciona como archivo completo consolidado.

Aplica a:

- código;
- tests;
- escenas;
- documentos;
- configuraciones;
- scripts;
- herramientas;
- journals nuevos;
- ADR;
- diseños;
- Core Architecture;
- Engineering Standards.

La entrega indica:

1. ruta exacta;

2. si es creación o reemplazo;

3. versión anterior cuando corresponda;

4. versión nueva cuando corresponda;

5. contenido completo;

6. instrucción de reemplazo total;

7. comando de verificación.

### 19.5 Prohibición de cirugía manual

No se entregan instrucciones como:

- “busca esta línea”;
- “inserta después de”;
- “elimina este bloque”;
- “reemplaza esta sección”;
- parches parciales;
- diffs como método de construcción;
- fragmentos distribuidos entre mensajes.

Los diffs se utilizan únicamente para auditoría.

### 19.6 Aplicación a cambios pequeños

La regla de archivo completo aplica incluso cuando el cambio conceptual sea pequeño.

Razón:

- evita omisiones;
- evita versiones parciales;
- evita referencias desalineadas;
- preserva contexto;
- reduce errores manuales;
- mantiene una fuente canónica.

### 19.7 Una entrega por archivo

Cuando varios archivos extensos cambian, se entregan uno por uno.

Después se realiza auditoría conjunta.

### 19.8 Verificación documental

Después de reemplazar:

- verificar cabecera;
- verificar versión;
- verificar fecha;
- verificar estado;
- verificar code fences;
- verificar ausencia de contradicciones;
- ejecutar `git diff --check`.

## 20. Git

### 20.1 Commits por responsabilidad

Cada commit representa una responsabilidad coherente.

### 20.2 Staging explícito

No se utiliza:

```powershell
git add .
```

cuando existen varios cambios.

### 20.3 Auditoría

```powershell
git status --short
git diff --check
git diff --cached --name-status
git diff --cached --check
```

### 20.4 Push

```powershell
git push origin main
git status -sb
```

Resultado esperado:

```text
## main...origin/main
```

## 21. Anti-patterns prohibidos

No se acepta:

- singleton por comodidad;
- autoload para ocultar ownership;
- EventBus global sin límites;
- recursión sobre datos del usuario;
- Arrays internos expuestos;
- Snapshot con setters;
- Draft utilizado por runtime;
- UI como modelo de dominio;
- test que corrompe campos privados;
- modificar baseline para otra arquitectura;
- mezclar código, UI y hardware;
- republishing sin transformación;
- fan-in implícito;
- DeviceGraph transportando mensajes;
- DeviceBus validando topología;
- Provider distribuyendo consumidores;
- DeviceCatalog conteniendo runtime factories;
- resolución latest automática;
- overwrite silencioso;
- método público incompatible con Object;
- parche que conserva responsabilidad incorrecta;
- documentación desactualizada;
- entrega de archivos mediante cirugía manual;
- fragmentos de código como estado final;
- commit con caché o estado local.

## 22. Checklist

### Arquitectura

- [ ] Problema definido.
- [ ] Responsabilidad única.
- [ ] Dependencias explícitas.
- [ ] ADR creado o actualizado.
- [ ] Diseño aceptado.
- [ ] Fuera de alcance documentado.

### Código

- [ ] Archivo completo entregado.
- [ ] Naming correcto.
- [ ] Sin conflicto con métodos nativos.
- [ ] Sin líneas comenzando con `.`.
- [ ] Tipos de colecciones en una línea.
- [ ] Sin dependencias ocultas.
- [ ] Mutaciones transaccionales.
- [ ] Collections protegidas.
- [ ] Runtime Safety considerada.

### Pruebas

- [ ] Archivo de prueba completo entregado.
- [ ] Prueba sucesora creada.
- [ ] Prueba aislada PASS.
- [ ] Parser sin errores.
- [ ] Run All PASS.
- [ ] Sin timeout.
- [ ] Sin Engine Error.
- [ ] Baseline registrada.

### Documentación

- [ ] Cada documento se entregó completo.
- [ ] Versión anterior identificada.
- [ ] Versión nueva identificada.
- [ ] Cabecera verificada.
- [ ] Core Architecture actualizado.
- [ ] Journal creado.
- [ ] Versiones y fechas correctas.
- [ ] Code fences cerrados.
- [ ] Sin estados contradictorios.
- [ ] UTF-8.
- [ ] `git diff --check` limpio.

### Git

- [ ] Staging revisado.
- [ ] Commit por responsabilidad.
- [ ] Working tree limpio.
- [ ] Remoto sincronizado.

## 23. Regla final

Cuando exista duda entre avanzar rápido y conservar una responsabilidad correcta, se conserva la responsabilidad correcta.

Cuando exista duda entre ocultar un fallo y reportarlo, se reporta.

Toda modificación se entrega como archivo completo consolidado.

No se realizan cirugías manuales sobre archivos.

Cuando exista duda entre permitir una simulación peligrosa y comprometer la plataforma:

> La simulación puede fallar. El simulador no.