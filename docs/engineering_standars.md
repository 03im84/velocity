# Velocity — Engineering Standards

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Última revisión | 22/08/2026 |
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

Una corrección local es válida cuando:

- la responsabilidad sigue siendo correcta;
- el contrato no cambia de significado;
- la modificación permanece dentro del componente responsable;
- las pruebas existentes se conservan.

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

No se crea un ADR nuevo cuando la decisión pertenece claramente al alcance de un ADR existente.

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

No se añaden tipos que obliguen a conversiones artificiales o escondan una responsabilidad incorrecta.

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

`Object.connect()` ya tiene otro contrato.

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

La coincidencia de nombre no se acepta únicamente porque el parser todavía no haya fallado.

El nombre público debe comunicar la responsabilidad real y evitar ambigüedad con el engine.

## 9. Contratos y datos

### 9.1 StringName

Se utiliza `StringName` para identidades canónicas repetidas:

- Topics;
- semantic kinds;
- roles;
- códigos;
- Connection IDs cuando corresponda.

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

### 9.4 References inmutables

Referencias a objetos inmutables pueden compartirse.

No se realizan deep copies sin una necesidad concreta.

Ejemplo:

```text
DeviceGraphSnapshot copia Arrays.

DeviceGraphNode y DeviceGraphConnection
pueden conservarse por referencia
porque son inmutables por contrato.
```

### 9.5 Variant

`Variant` se utiliza cuando la abstracción requiere transportar datos heterogéneos.

No se utiliza para evitar definir un contrato conocido.

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
- no sustituyen excepciones de plataforma;
- permiten fallo esperado de dominio.

### 10.5 Last Known Good

Una operación fallida no modifica el último estado válido.

Flujo:

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

Cuando una operación puede fallar de forma esperada, devuelve un Result estructurado.

## 12. ValidationIssue y ValidationReport

### 12.1 Categorías

Velocity distingue:

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

Simulation no acepta:

- Structural Error;
- Platform Safety Error.

### 12.3 Hardware Mode

Hardware no acepta:

- Structural Error;
- Platform Safety Error;
- Simulation Hazard;
- Hardware Safety Error.

### 12.4 Códigos

Cada Issue utiliza un código estable.

Tests y herramientas comprueban códigos, no texto de presentación.

### 12.5 Mensajes

Los mensajes deben:

- describir el problema;
- evitar ambigüedad;
- identificar objeto relacionado;
- identificar campo relacionado;
- no depender de UI.

### 12.6 No mutación

ValidationReport describe.

No corrige ni modifica automáticamente el objeto validado.

## 13. Runtime Safety

### 13.1 Regla principal

> La simulación puede fallar. El simulador no.

### 13.2 Nunca permitido

Una configuración creada por el usuario no puede provocar:

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

Los algoritmos sobre Graphs, mensajes o configuraciones del usuario deben ser:

- iterativos cuando la profundidad no está acotada;
- lineales o justificadamente acotados;
- deterministas;
- capaces de abortar o reportar;
- resistentes a entradas mal formadas.

No se utiliza recursión sobre un Graph de tamaño controlado por el usuario.

### 13.4 Defensa en profundidad

```text
Draft validation

+

Snapshot validation

+

Compiler validation

+

Runtime budgets

+

Runtime supervision
```

Ninguna capa sustituye a las demás.

## 14. DeviceBus

### 14.1 Responsabilidad

DeviceBus transporta mensajes.

No interpreta payloads ni topología.

### 14.2 Ownership

DeviceBus tiene propietario explícito.

No es:

- autoload;
- singleton global;
- Node por conveniencia.

### 14.3 Dispatch

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

### 14.4 Reentrancia

Una publicación realizada desde un callback se encola.

No inicia recursión depth-first.

### 14.5 Fan-out

Una publicación se entrega a todos los suscriptores válidos según orden contractual.

El mismo mensaje puede conservar la misma referencia cuando el contrato es inmutable.

### 14.6 Mutación durante dispatch

La iteración actual utiliza un snapshot de suscriptores.

Mutaciones afectan publicaciones posteriores según el contrato probado.

### 14.7 Topic ownership

DeviceBus no valida ownership semántico.

La validación pertenece a componentes externos como DeviceGraph o CompositionCompiler.

## 15. DeviceGraph

### 15.1 Responsabilidades separadas

```text
DeviceGraphDraft:
edición transaccional.

DeviceGraphValidator:
validación global.

DeviceGraphSnapshot:
estructura validada e inmutable.
```

### 15.2 No ejecución

DeviceGraph no:

- transporta mensajes;
- publica;
- se suscribe;
- ejecuta Devices;
- controla Lifecycle;
- crea runtime;
- serializa;
- dibuja UI.

### 15.3 Collections

Dictionaries internos no se exponen.

Getters de colecciones devuelven Arrays independientes.

### 15.4 Connection IDs

Connection IDs son deterministas.

Formato:

```text
source_device
|
source_port
|
target_device
|
target_port
```

El separador `|` está reservado.

### 15.5 Fan-out

Un OutputPort puede alimentar múltiples InputPorts.

### 15.6 Fan-in

Un InputPort admite una Connection entrante.

Varias fuentes requieren un Device explícito de:

- merge;
- arbitraje;
- selección;
- transformación.

### 15.7 Ciclos

Los ciclos se detectan sin recursión.

Un ciclo sin evidencia temporal produce:

```text
SIMULATION_HAZARD

graph_cycle_requires_temporal_analysis
```

Simulation puede continuar.

Hardware queda bloqueado.

### 15.8 Snapshot

Snapshot significa válido para Simulation cuando:

```gdscript
snapshot.is_valid()
```

Hardware se decide mediante ValidationReport y CompositionCompiler.

### 15.9 Graph vacío

Un Graph vacío es estructuralmente válido.

CompositionCompiler puede decidir que no es ejecutable.

## 16. Pruebas

### 16.1 Ubicación

Las pruebas nuevas del Core se ubican bajo:

```text
res://test/core/
```

### 16.2 Naming

Escena:

```text
ComponentNameTest.tscn
```

Script:

```text
component_name_test.gd
```

### 16.3 Independencia

Cada test crea sus propios objetos.

No depende del orden de ejecución de otros tests.

No utiliza estado global compartido.

### 16.4 Salida

Cada prueba imprime:

```text
[PASS] descripción
```

Resumen:

```text
Checks: N
Failures: N
RESULT: PASS o FAIL
```

Finaliza mediante:

```gdscript
get_tree().quit(
	_failure_count
)
```

### 16.5 Fallos

Si una prueba falla:

1. no se modifica código inmediatamente;

2. se captura el primer error completo;

3. se identifica archivo y línea;

4. se determina si es parser, contrato o comportamiento;

5. después se propone el cambio.

### 16.6 Baselines inmutables

Una prueba aceptada se convierte en baseline.

No se modifica para probar una arquitectura diferente.

Se crea una prueba sucesora.

Antes de retirar una prueba anterior:

1. crear sucesora;

2. ejecutar sucesora;

3. ejecutar regresión;

4. registrar sustitución;

5. retirar del árbol activo;

6. conservar historia en Git.

### 16.7 No corrupción privada

Las pruebas no modifican Dictionaries privados para fabricar estados.

Se utilizan:

- APIs públicas;
- constructores;
- fixtures controlados;
- Validators que aceptan Arrays;
- operaciones fallidas reales.

### 16.8 Ejecución autoritativa

No se utiliza `Run Current Scene` del editor como evidencia autoritativa.

Se utiliza:

```text
Godot Console
+
headless
+
Velocity Test Runner
```

Variable de sistema:

```text
GODOT_CONSOLE
```

### 16.9 Runner

El runner debe:

- aplicar timeout;
- continuar después de fallos;
- detectar errores de Godot aunque ExitCode sea cero;
- producir summary;
- devolver exit code agregado.

Códigos reservados:

```text
124:
TIMEOUT

125:
proceso no confirmado

126:
ENGINE_ERROR con ExitCode Godot 0
```

### 16.10 Dashboard

Velocity Test Dashboard es interfaz del runner.

No define contratos del Core.

El estado local no se versiona:

```text
test/tools/test_dashboard.local.json
test/tools/.test_dashboard/
```

`Pause` y `Resume` utilizan un único botón dinámico.

## 17. Archivos generados y UID

### 17.1 UID de Godot

Los archivos:

```text
*.gd.uid
```

generados por Godot se versionan junto con su script cuando forman parte del proyecto.

No se crean manualmente.

### 17.2 Caché

No se versionan:

```text
__pycache__/
*.py[cod]
```

### 17.3 Estado local

Configuraciones personales y estado de UI se excluyen mediante `.gitignore`.

### 17.4 Archivos accidentales

Capturas temporales como:

```text
list.txt
shorts.txt
```

no se añaden al repositorio.

Antes de eliminarlas se verifica su contenido.

## 18. Documentación

### 18.1 ADR

Ruta:

```text
res://docs/architecture/adr/
```

Nombre:

```text
ADR-XXX — Título.md
```

Cada ADR registra:

- estado;
- versión;
- fecha;
- contexto;
- problema;
- decisión;
- alternativas;
- consecuencias;
- invariantes;
- criterios de aceptación;
- fuera de alcance.

### 18.2 Diseños

Los diseños se ubican en:

```text
res://docs/architecture/
```

Un diseño incluye:

- responsabilidad;
- estructura;
- API;
- invariantes;
- estrategia de pruebas;
- orden de implementación;
- criterios de aceptación;
- estado actual.

### 18.3 Project Decisions

Ruta:

```text
res://docs/decisions/
```

Las Project Decisions expresan reglas que atraviesan varios ADR.

### 18.4 Engineering Notes

Ruta:

```text
res://docs/engineering_notes/
```

Una Engineering Note registra:

- auditoría;
- hallazgo;
- riesgo;
- evidencia;
- acciones.

No sustituye ADR o diseño.

### 18.5 Project Journal

Ruta:

```text
res://docs/project_journal/
```

Formato de nombre:

```text
pjXXXX_DDMMAA.txt
```

Ejemplo:

```text
pj0021_220826.txt
```

El journal utiliza:

- zona horaria GMT-5;
- sin DST;
- fecha visible DD/MM/AAAA.

El journal es histórico.

No se reescribe para fingir que una decisión posterior ya existía.

Correcciones de formato que no cambian significado pueden registrarse en un commit documental.

### 18.6 Encoding

Los documentos se guardan como UTF-8.

No se copian al archivo caracteres mojibake como:

```text
Ã
â
Â
```

Si PowerShell muestra mojibake, se verifica la codificación antes de modificar el archivo.

## 19. Git

### 19.1 Commits por responsabilidad

Cada commit representa una responsabilidad coherente.

Ejemplos:

```text
feat(device-graph): add full graph validation

feat(device-graph): add immutable graph snapshots

docs(device-graph): close device graph 1.0
```

### 19.2 Staging explícito

Cuando el working tree contiene varios milestones no se utiliza:

```powershell
git add .
```

Se añaden rutas explícitas.

### 19.3 Auditoría previa

Antes del commit:

```powershell
git status --short
git diff --check
git diff --cached --name-status
```

### 19.4 Commit de implementación

Incluye:

- código;
- UID;
- pruebas sucesoras;
- retiro de archivos reemplazados cuando corresponda.

### 19.5 Commit documental

Puede incluir:

- ADR;
- diseño;
- Core Architecture;
- journal;
- Engineering Standards;
- Engineering Notes.

### 19.6 Working tree

Después del commit:

```powershell
git status --short
```

debe estar vacío o contener únicamente cambios explícitamente diferidos.

### 19.7 Push

Después de cerrar y verificar el milestone:

```powershell
git push origin main
```

Después:

```powershell
git status -sb
```

Resultado esperado:

```text
## main...origin/main
```

### 19.8 Historia

Git conserva la historia de archivos retirados.

No se mantienen implementaciones obsoletas en el árbol activo únicamente por miedo a perderlas.

## 20. Anti-patterns prohibidos

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
- mezclar código, UI y hardware en un componente;
- republishing sin transformación;
- fan-in implícito;
- DeviceGraph transportando mensajes;
- DeviceBus validando topología;
- Provider distribuyendo a consumidores;
- Componentes nombrados como métodos nativos incompatibles;
- parche que conserva una responsabilidad incorrecta;
- documentación que describe un estado anterior;
- commit con caché o estado local.

## 21. Checklist de implementación

Antes de considerar terminada una característica:

### Arquitectura

- [ ] El problema está definido.
- [ ] La responsabilidad es única.
- [ ] Las dependencias son explícitas.
- [ ] ADR creado o actualizado.
- [ ] Diseño aceptado.
- [ ] Fuera de alcance documentado.

### Código

- [ ] Naming correcto.
- [ ] Sin conflicto con métodos nativos.
- [ ] Sin líneas comenzando con `.`.
- [ ] Tipos de colecciones en una línea.
- [ ] Sin dependencias ocultas.
- [ ] Mutaciones transaccionales.
- [ ] Collections protegidas.
- [ ] Runtime Safety considerada.

### Pruebas

- [ ] Prueba sucesora creada.
- [ ] Prueba aislada PASS.
- [ ] Parser sin errores.
- [ ] Run All PASS.
- [ ] Sin timeout.
- [ ] Sin Engine Error.
- [ ] Baseline registrada.

### Documentación

- [ ] Diseño actualizado.
- [ ] Core Architecture actualizado.
- [ ] Journal creado.
- [ ] Engineering Note creada si corresponde.
- [ ] Versiones y fechas correctas.

### Git

- [ ] `git diff --check` limpio.
- [ ] Staging revisado.
- [ ] Commit por responsabilidad.
- [ ] Working tree limpio.
- [ ] Remoto sincronizado.

## 22. Regla final

Cuando exista duda entre avanzar rápido y conservar una responsabilidad correcta, se conserva la responsabilidad correcta.

Cuando exista duda entre ocultar un fallo y reportarlo, se reporta.

Cuando exista duda entre permitir una simulación peligrosa y comprometer la plataforma:

> La simulación puede fallar. El simulador no.
