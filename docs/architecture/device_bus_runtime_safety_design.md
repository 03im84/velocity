# DeviceBus Runtime Safety — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Fecha | 16/08/2026 |
| Estado de implementación | COMPLETO |
| Última verificación | 16/08/2026 |
| ADR relacionado | ADR-007 — Bounded Dispatch and Runtime Safety |
| Componentes | DeviceBus, DispatchPolicy, DispatchReport |

## 1. Propósito

Este documento traduce ADR-007 a un diseño concreto e implementable.

Define:

- DeviceBusDispatchPolicy;
- DeviceBusDispatchReport;
- Dispatch Context interno;
- Queue Entry interna;
- queue FIFO;
- presupuestos;
- hard maximums;
- aborto controlado;
- evolución de `publish()`;
- observabilidad;
- pruebas sucesoras;
- orden de migración.

Este documento no modifica DeviceGraph ni contratos de dominio.

## 2. Alcance

La implementación afectará:

```text
core/bus/device_bus.gd
```

Creará:

```text
core/bus/
device_bus_dispatch_policy.gd

core/bus/
device_bus_dispatch_report.gd
```

También creará pruebas nuevas dentro de:

```text
test/core/device_bus/
```

No afectará:

```text
BusMessage

BusTopics

Device

Provider System

DistanceMeasurement

DeviceGraph

Profile System
```

La firma de `publish()` cambiará de:

```gdscript
publish(
	topic: StringName,
	message: Variant
) -> void
```

a:

```gdscript
publish(
	topic: StringName,
	message: Variant
) -> bool
```

Los productores actuales podrán ignorar el valor retornado.

## 3. DeviceBusDispatchPolicy

### 3.1 Archivo

```text
core/bus/device_bus_dispatch_policy.gd
```

### 3.2 Forma

```gdscript
extends RefCounted
class_name DeviceBusDispatchPolicy
```

### 3.3 Responsabilidad

> Definir los presupuestos permitidos para un Dispatch Cycle.

DeviceBusDispatchPolicy no:

- ejecuta dispatch;
- conserva mensajes;
- conoce Devices;
- conoce Topics concretos;
- interpreta payloads;
- decide respuestas de dominio;
- registra logs.

### 3.4 Estado previsto

```gdscript
var _max_publications_per_cycle: int

var _max_callbacks_per_cycle: int

var _max_pending_publications: int

var _max_dispatch_time_usec: int
```

Todos los valores serán mayores que cero.

No existirá:

```text
0 = unlimited
```

### 3.5 Hard Maximums

DeviceBusDispatchPolicy definirá límites absolutos.

Forma conceptual:

```gdscript
const HARD_MAX_PUBLICATIONS_PER_CYCLE: int

const HARD_MAX_CALLBACKS_PER_CYCLE: int

const HARD_MAX_PENDING_PUBLICATIONS: int

const HARD_MAX_DISPATCH_TIME_USEC: int
```

Los valores configurados deberán cumplir:

```text
configured value > 0

configured value <= hard maximum
```

### 3.6 Construcción

La Policy recibirá sus valores durante `_init()`.

Forma conceptual:

```gdscript
DeviceBusDispatchPolicy.new(
	max_publications_per_cycle,
	max_callbacks_per_cycle,
	max_pending_publications,
	max_dispatch_time_usec
)
```

La firma y valores por defecto se definirán después de las pruebas de límites.

### 3.7 Inmutabilidad

Después de construirse, DeviceBusDispatchPolicy será tratada como solo lectura.

Expondrá getters.

No expondrá setters públicos.

Cambiar presupuestos requerirá una nueva Policy.

### 3.8 Validación

DeviceBusDispatchPolicy expondrá:

```gdscript
func is_valid() -> bool
```

Devolverá `true` únicamente cuando todos los valores estén dentro de sus límites permitidos.

DeviceBus no aceptará una Policy inválida.

### 3.9 Valores por defecto

```text
max_publications_per_cycle:
1024

max_callbacks_per_cycle:
8192

max_pending_publications:
512

max_dispatch_time_usec:
50000
```

`50000 usec` equivale a:

```text
50 ms
```

### 3.10 Hard Maximums

```text
HARD_MAX_PUBLICATIONS_PER_CYCLE:
16384

HARD_MAX_CALLBACKS_PER_CYCLE:
131072

HARD_MAX_PENDING_PUBLICATIONS:
8192

HARD_MAX_DISPATCH_TIME_USEC:
500000
```

`500000 usec` equivale a:

```text
500 ms
```

### 3.11 Reglas

Debe cumplirse:

```text
0 < configured publications
<= HARD_MAX_PUBLICATIONS_PER_CYCLE

0 < configured callbacks
<= HARD_MAX_CALLBACKS_PER_CYCLE

0 < configured pending
<= HARD_MAX_PENDING_PUBLICATIONS

0 < configured time
<= HARD_MAX_DISPATCH_TIME_USEC
```

No existe:

```text
0 = unlimited
```

### 3.12 Evolución de valores

Los valores iniciales son versionados.

Solo podrán modificarse mediante:

- profiling;
- pruebas de carga;
- resultados reproducibles;
- actualización del diseño;
- nueva versión de Policy.

## 4. DeviceBusDispatchReport

### 4.1 Archivo

```text
core/bus/device_bus_dispatch_report.gd
```

### 4.2 Forma

```gdscript
extends RefCounted
class_name DeviceBusDispatchReport
```

### 4.3 Responsabilidad

> Describir el resultado final de un Dispatch Cycle.

DeviceBusDispatchReport no:

- modifica DeviceBus;
- conserva la queue;
- conserva payloads;
- interpreta mensajes;
- ejecuta recuperación;
- cambia Health;
- registra logs.

### 4.4 Estados

```gdscript
enum Status {
	NO_DISPATCH,
	COMPLETED,
	ABORTED_PUBLICATION_BUDGET,
	ABORTED_CALLBACK_BUDGET,
	ABORTED_QUEUE_LIMIT,
	ABORTED_TIME_BUDGET
}
```

### 4.5 Datos previstos

```gdscript
var _status: Status

var _publications_accepted: int

var _publications_dispatched: int

var _callbacks_invoked: int

var _callbacks_skipped: int

var _publications_dropped: int

var _pending_peak: int

var _elapsed_usec: int

var _limit_reached: StringName

var _trigger_topic: StringName
```

### 4.6 API de lectura

```gdscript
get_status() -> Status

get_publications_accepted() -> int

get_publications_dispatched() -> int

get_callbacks_invoked() -> int

get_callbacks_skipped() -> int

get_publications_dropped() -> int

get_pending_peak() -> int

get_elapsed_usec() -> int

get_limit_reached() -> StringName

get_trigger_topic() -> StringName

is_completed() -> bool

is_aborted() -> bool
```

### 4.7 Construcción

El Report será construido al finalizar el ciclo.

Recibirá todos sus valores durante `_init()`.

Después será tratado como inmutable.

### 4.8 NO_DISPATCH

Una instancia inicial podrá representar:

```text
Status:
NO_DISPATCH
```

con todos los contadores en cero.

Esto permite que:

```gdscript
get_last_dispatch_report()
```

siempre devuelva un Report válido.

## 5. Dispatch Context interno

### 5.1 Visibilidad

Dispatch Context no será una clase global.

Será una estructura interna de DeviceBus.

Podrá implementarse como:

- clase interna;
- objeto privado;
- estructura privada equivalente.

### 5.2 Responsabilidad

Conservar el estado mutable del ciclo activo.

Datos previstos:

```text
queue

read index

start time

publications accepted

publications dispatched

callbacks invoked

publications dropped

pending peak

aborted

abort status

limit reached

trigger topic
```

### 5.3 Lifecycle

El contexto se crea cuando comienza una publicación raíz.

Existe mientras DeviceBus procesa la queue.

Al finalizar:

```text
Context
	↓
DeviceBusDispatchReport
```

Después se descarta.

DeviceBus no expone el contexto activo.

## 6. Queue Entry interna

### 6.1 Visibilidad

Queue Entry no será una clase global.

Será un dato interno de DeviceBus.

### 6.2 Estado

```text
topic: StringName

message: Variant
```

No incluirá:

- Device;
- Source ID;
- Subscriber;
- priority;
- coalescing key;
- timestamp adicional;
- delivery policy.

### 6.3 Responsabilidad

> Conservar una publicación aceptada hasta que sea despachada.

Cada llamada aceptada a `publish()` genera una Queue Entry.

No se genera una Entry por suscriptor.

## 7. Estado interno de DeviceBus

DeviceBus añadirá:

```gdscript
var _dispatch_policy: DeviceBusDispatchPolicy

var _pending_publications: Array

var _queue_read_index: int = 0

var _is_dispatching: bool = false

var _has_dispatched: bool = false

var _active_context: Variant = null

var _last_dispatch_report: DeviceBusDispatchReport
```

`_has_dispatched` cambia a `true` cuando comienza el primer Dispatch Cycle válido.

Una llamada con topic vacío no crea ciclo y no bloquea la Policy.

Después de comenzar el primer ciclo, la Policy no puede sustituirse.

DeviceBus conservará además:

```gdscript
_subscribers_by_topic
```

La queue y el contexto son infraestructura temporal.

No son estado funcional.

## 8. Configuración de DeviceBus

DeviceBus siempre se construirá con una Policy segura por defecto.

Forma:

```gdscript
var bus := DeviceBus.new()
```

DeviceBus no recibirá una Policy opcional dentro de `_init()`.

Una Policy personalizada podrá configurarse mediante:

```gdscript
func configure_dispatch_policy(
	policy: DeviceBusDispatchPolicy
) -> bool
```

### 8.1 Configuración permitida

La operación devuelve `true` cuando:

- policy no es null;
- policy es válida;
- no existe Dispatch Cycle activo;
- DeviceBus todavía no ejecutó ningún ciclo.

### 8.2 Configuración rechazada

La operación devuelve `false` cuando:

- policy es null;
- policy no supera `is_valid()`;
- DeviceBus está despachando;
- DeviceBus ya finalizó al menos un ciclo.

Cuando la operación es rechazada:

```text
la Policy anterior permanece activa.
```

DeviceBus nunca queda sin Policy válida.

### 8.3 Bloqueo de Policy

Después del primer Dispatch Cycle, la Policy queda bloqueada.

Para utilizar otros presupuestos deberá crearse otra instancia de DeviceBus.

Esto evita cambios de seguridad durante una ejecución existente.

### 8.4 Last Known Good

La Policy por defecto es el Last Known Good de DeviceBus.

Una Policy inválida no reemplaza la Policy activa.

No se realiza clamping silencioso.

### 8.5 Consulta de Policy

DeviceBus expondrá:

```gdscript
func get_dispatch_policy(
) -> DeviceBusDispatchPolicy```

## 9. API de publicación

### 9.1 Firma

```gdscript
func publish(
	topic: StringName,
	message: Variant
) -> bool
```

### 9.2 Publicación raíz

Si DeviceBus no está despachando:

1. valida la publicación;

2. crea Dispatch Context;

3. añade Queue Entry;

4. procesa la queue;

5. crea Dispatch Report;

6. almacena el Report;

7. devuelve `true` si el ciclo terminó COMPLETED;

8. devuelve `false` si el ciclo fue abortado.

### 9.3 Publicación reentrante

Si DeviceBus ya está despachando:

1. valida budgets;

2. añade Queue Entry si está permitida;

3. devuelve `true` si fue aceptada;

4. devuelve `false` si fue rechazada.

No inicia dispatch recursivo.

### 9.4 Topic vacío

```gdscript
publish(
	&"",
	message
)
```

devuelve:

```text
false
```

No crea Dispatch Cycle.

No modifica el último Report.

## 10. Last Dispatch Report

DeviceBus expondrá:

```gdscript
func get_last_dispatch_report(
) -> DeviceBusDispatchReport
```

El método devolverá el último Report finalizado.

No devolverá el contexto activo.

Antes del primer ciclo devolverá un Report:

```text
NO_DISPATCH
```

El último Report podrá ser sustituido únicamente cuando termine un ciclo nuevo.

## 11. DELIVER_ALL

DeviceBus procesará todas las publicaciones aceptadas mientras no se alcance un presupuesto.

No implementará:

- coalescing;
- deduplicación;
- prioridad;
- comparación de payload;
- modificación de timestamps;
- replacement de pending messages.

Cada Queue Entry aceptada será despachada o contabilizada como dropped durante un aborto.

## 12. Ownership y fan-out

DeviceBus no validará ownership semántico.

Cada publicación genera una sola Queue Entry.

Esa Entry realiza fan-out sobre todos los suscriptores del Topic.

DeviceGraph y CompositionCompiler validarán:

```text
Topic + Source ID
```

como stream con propietario único.

Los consumidores no deben republicar datos sin transformación.

DeviceBus no inspeccionará esa regla.

## 13. Provenance

DeviceBus no crea provenance.

Los mensajes y contratos derivados podrán conservar:

- IDs;
- sequence;
- timestamps;
- references a snapshots;
- Sources utilizados.

DeviceBus transporta esas estructuras sin interpretarlas.

## 14. Invariantes del bloque

1. Policy define budgets.

2. Policy no ejecuta dispatch.

3. Policy es inmutable después de construirse.

4. Report representa un ciclo finalizado.

5. Report no conserva mensajes.

6. Context existe únicamente durante dispatch.

7. Queue Entry contiene Topic y Message.

8. Cada publish aceptado crea una Entry.

9. Los suscriptores no crean Entries adicionales.

10. publish() devuelve bool.

11. Last Report siempre es consultable.

12. DeviceBus no expone contexto parcial.

13. DELIVER_ALL es la única política.

14. DeviceBus no implementa coalescing.

15. Ownership se valida fuera de DeviceBus.

16. Provenance pertenece a contratos de datos.

## 15. Inicio de Dispatch Cycle

Un Dispatch Cycle comienza cuando:

```text
publish() es llamado

y

_is_dispatching == false
```

Secuencia:

```text
1. Validar topic.

2. Crear Dispatch Context.

3. Limpiar queue temporal anterior.

4. Reiniciar read index.

5. Registrar start time.

6. Encolar publicación raíz.

7. Marcar _is_dispatching = true.

8. Procesar queue.

9. Finalizar Report.

10. Limpiar contexto.

11. Marcar _is_dispatching = false.
```

## 16. Enqueue

Toda publicación aceptada pasa por una operación interna de enqueue.

Responsabilidad:

```text
validar Context;

validar Publication Budget;

validar Queue Size Limit;

validar Time Budget;

crear Queue Entry;

actualizar contadores;

actualizar pending peak.
```

### 16.1 Publication Budget

Antes de aceptar:

```text
if publications_accepted
>= max_publications_per_cycle:

	abort
```

La publicación que supera el límite:

- no entra en queue;
- aumenta `publications_dropped`;
- define trigger topic;
- hace que `publish()` devuelva false.

### 16.2 Queue Size Limit

Pending Count:

```text
queue.size() - read_index
```

Antes de añadir:

```text
if pending_count
>= max_pending_publications:

	abort
```

La publicación rechazada aumenta `publications_dropped`.

### 16.3 Publicación aceptada

Cuando es aceptada:

```text
publications_accepted += 1
```

Se añade una Queue Entry:

```text
topic

message
```

Después se actualiza:

```text
pending_peak
```

## 17. Algoritmo FIFO

DeviceBus procesará queue mediante:

```text
Array + read index
```

No utilizará `pop_front()` como operación principal.

Pseudocódigo:

```text
while read_index < queue.size()
	  and not aborted:

	comprobar Time Budget

	entry = queue[read_index]

	read_index += 1

	publications_dispatched += 1

	crear snapshot de suscriptores

	para cada subscriber del snapshot:

		comprobar Callback Budget

		comprobar Time Budget

		si subscriber inválido:
			continuar

		invocar subscriber

		callbacks_invoked += 1

		comprobar Time Budget

	limpiar Callables inválidos
```

Las publicaciones reentrantes se añaden al final del mismo Array.

El call stack no crece por reentrada.

## 18. Snapshot de suscriptores

La instantánea se crea cuando una Queue Entry comienza su dispatch.

No se crea durante enqueue.

Esto permite que cambios ocurridos antes del dispatch afecten mensajes pendientes.

### 18.1 Subscribe durante Message A

Message A conserva su snapshot.

Un suscriptor añadido puede recibir Message B si B todavía no comenzó.

### 18.2 Unsubscribe durante Message A

El suscriptor continúa dentro del snapshot de A.

No aparece en snapshots posteriores.

### 18.3 Callable invalidado

Antes de invocar se comprueba:

```gdscript
subscriber.is_valid()
```

Un Callable inválido:

- no se invoca;
- se elimina del registro permanente;
- no aumenta `callbacks_invoked`;
- no aumenta `callbacks_skipped` por budget.

La invalidación no es un aborto.

## 19. Clear durante dispatch

`clear()` elimina las suscripciones permanentes.

No cancela automáticamente el Dispatch Cycle.

La instantánea del mensaje actual puede completarse.

Los mensajes pendientes posteriores crean snapshots vacíos.

Cancelar un ciclo pertenece a Runtime Safety, no a `clear()`.

## 20. Callback Budget

Antes de cada Callable válido:

```text
if callbacks_invoked
>= max_callbacks_per_cycle:

	abort
```

El callback que supera el límite no se ejecuta.

Los Callables válidos restantes del snapshot actual aumentan:

```text
callbacks_skipped
```

No se intentará estimar callbacks de mensajes pendientes cuyos snapshots nunca fueron creados.

## 21. Time Budget

Al crear Context:

```gdscript
start_usec = Time.get_ticks_usec()
```

Elapsed:

```gdscript
Time.get_ticks_usec() - start_usec
```

Se comprueba:

- antes de procesar una Entry;
- antes de cada Callable;
- después de cada Callable.

Si:

```text
elapsed_usec
>= max_dispatch_time_usec
```

el ciclo se aborta con:

```text
ABORTED_TIME_BUDGET
```

Un callback que nunca devuelve control no puede ser interrumpido por esta versión.

## 22. Aborto controlado

Al abortar:

```text
aborted = true
```

DeviceBus:

1. deja de invocar callbacks;

2. deja de procesar Entries;

3. calcula publicaciones pendientes;

4. añade pendientes a `publications_dropped`;

5. limpia queue temporal;

6. conserva suscripciones permanentes;

7. crea Dispatch Report;

8. limpia Context;

9. marca `_is_dispatching = false`;

10. devuelve control.

## 23. Limit Reached

`limit_reached` utilizará:

```gdscript
&"publication_budget"

&"callback_budget"

&"queue_limit"

&"time_budget"
```

No son Topics de DeviceBus.

Son identificadores de infraestructura.

`trigger_topic` conserva el topic durante el cual se alcanzó el límite.

## 24. Contadores

### `publications_accepted`

Publicaciones añadidas correctamente a queue.

### `publications_dispatched`

Queue Entries cuyo dispatch comenzó.

### `callbacks_invoked`

Callables válidos ejecutados.

### `callbacks_skipped`

Callables válidos del snapshot actual que no se ejecutaron debido a un aborto.

### `publications_dropped`

Incluye:

- publicación rechazada que disparó el límite;
- Queue Entries pendientes cuando se abortó.

### `pending_peak`

Mayor cantidad de Entries pendientes observada.

### `elapsed_usec`

Tiempo total observado desde el inicio hasta finalizar o abortar.

## 25. Report final

Al completar normalmente:

```text
Status:
COMPLETED

Limit:
empty StringName

Trigger Topic:
empty StringName
```

Al abortar:

```text
Status:
ABORTED_...

Limit:
identificador correspondiente

Trigger Topic:
topic relacionado
```

El Report se construye una sola vez al finalizar.

Después es inmutable.

## 26. Resultado de publicación

### 26.1 Root publish

Devuelve:

```text
true:
ciclo COMPLETED.

false:
topic inválido o ciclo abortado.
```

### 26.2 Reentrant publish

Devuelve:

```text
true:
Queue Entry aceptada.

false:
Queue Entry rechazada
o Context ya abortado.
```

Una aceptación reentrante no garantiza que el Report final sea COMPLETED.

## 27. Recuperación

Después de un aborto:

```text
queue vacía;

read index 0;

active context null;

is_dispatching false;

subscriptions intactas;

last report disponible.
```

Una publicación raíz posterior puede comenzar un ciclo nuevo.

La recuperación deberá verificarse mediante prueba.

## 28. Policy lock

`configure_dispatch_policy()` solo funciona antes del primer ciclo.

Después de finalizar un ciclo, independientemente de su resultado:

```text
Policy queda bloqueada.
```

Una Policy inválida o tardía devuelve false.

La Policy segura anterior permanece activa.

## 29. Sin suscriptores

Una publicación aceptada sin suscriptores:

```text
publications_accepted += 1

publications_dispatched += 1

callbacks_invoked += 0
```

No se considera error.

El ciclo puede finalizar COMPLETED.

## 30. DELIVER_ALL y ownership

Cada Queue Entry aceptada se procesa.

DeviceBus no:

- compara payloads;
- elimina duplicados;
- cambia timestamps;
- aplica coalescing;
- valida Source ID;
- valida ownership;
- crea provenance.

Single Publisher y no-republishing se validan fuera de DeviceBus.

## 31. Invariantes del algoritmo

1. Queue utiliza FIFO.

2. Reentrada no genera recursión.

3. Snapshot se crea al comenzar cada Entry.

4. Budgets se comprueban antes de excederse.

5. La publicación que excede un límite no entra.

6. Callback que excede budget no se ejecuta.

7. Time Budget se mide con reloj monotónico.

8. Aborto limpia estado temporal.

9. Aborto conserva suscripciones.

10. Un ciclo posterior puede comenzar.

11. Policy se bloquea después del primer ciclo.

12. Policy inválida no reemplaza la activa.

13. Report final es inmutable.

14. Last Report nunca expone Context activo.

15. DELIVER_ALL permanece como única política.

### 31.1 Thread confinement

DeviceBus 1.1 no será thread-safe.

Todas las operaciones sobre una instancia deberán ejecutarse desde el thread propietario del contexto.

Esto incluye:

```text
subscribe()

unsubscribe()

publish()

clear()

configure_dispatch_policy()
```

La queue FIFO no es una concurrent queue.

Un productor externo ejecutado en otro thread deberá transferir la publicación al thread propietario mediante un adaptador.

DeviceBus no añadirá:

- Mutex;
- Semaphore;
- locks;
- estructuras concurrentes;
- dispatch multithread;

durante esta versión.

La protección de stack y budgets no sustituye thread safety.

### 31.2 Time Budget y determinismo

Publication Budget, Callback Budget y Queue Size Limit son límites deterministas.

Con las mismas publicaciones y suscriptores producen el mismo resultado.

Time Budget depende de:

- hardware;
- carga del sistema;
- modo editor;
- procesos externos;
- velocidad del equipo.

Por tanto, un aborto por Time Budget puede ocurrir en un equipo y no en otro.

El Time Budget es una protección de integridad de plataforma.

No forma parte del resultado normal de simulación.

Si se alcanza:

```text
el Dispatch Cycle se considera inválido;

la simulación debe pausarse o detenerse;

el resultado no se utiliza como frame válido;

se produce diagnóstico;

el runtime conserva Last Known Good.
```

Las pruebas deterministas de lógica utilizarán budgets por cantidad.

La prueba específica de Time Budget utilizará una tolerancia controlada y verificará únicamente el mecanismo de protección.

Replay y simulaciones reproducibles no considerarán un ciclo abortado por tiempo como resultado válido.

### 31.3 Payload Size

Queue Size Limit limita cantidad de Entries.

No limita el tamaño de cada payload.

Un único payload podría consumir una cantidad excesiva de memoria.

DeviceBus 1.1 no inspeccionará payloads ni calculará su tamaño porque permanece agnóstico.

Durante esta versión:

- los contratos canónicos utilizarán payloads confiables;
- GraphEditor no permitirá payloads arbitrarios;
- archivos y networking validarán tamaño antes de publicar;
- Hardware Bridge tendrá límites propios.

Un Payload Size Budget genérico queda fuera de alcance hasta definir contratos serializables.

Esta limitación debe permanecer documentada.

## 32. API concreta de DeviceBusDispatchPolicy

### 32.1 Constantes por defecto

```gdscript
const DEFAULT_MAX_PUBLICATIONS_PER_CYCLE: int = 1024

const DEFAULT_MAX_CALLBACKS_PER_CYCLE: int = 8192

const DEFAULT_MAX_PENDING_PUBLICATIONS: int = 512

const DEFAULT_MAX_DISPATCH_TIME_USEC: int = 50000
```

### 32.2 Hard Maximums

```gdscript
const HARD_MAX_PUBLICATIONS_PER_CYCLE: int = 16384

const HARD_MAX_CALLBACKS_PER_CYCLE: int = 131072

const HARD_MAX_PENDING_PUBLICATIONS: int = 8192

const HARD_MAX_DISPATCH_TIME_USEC: int = 500000
```

### 32.3 Constructor

```gdscript
func _init(
	max_publications_per_cycle: int
		= DEFAULT_MAX_PUBLICATIONS_PER_CYCLE,
	max_callbacks_per_cycle: int
		= DEFAULT_MAX_CALLBACKS_PER_CYCLE,
	max_pending_publications: int
		= DEFAULT_MAX_PENDING_PUBLICATIONS,
	max_dispatch_time_usec: int
		= DEFAULT_MAX_DISPATCH_TIME_USEC
) -> void
```

La construcción almacena los valores recibidos.

No realiza clamping.

Una Policy fuera de límites permanece inválida y será rechazada por DeviceBus.

### 32.4 API de lectura

```gdscript
get_max_publications_per_cycle() -> int

get_max_callbacks_per_cycle() -> int

get_max_pending_publications() -> int

get_max_dispatch_time_usec() -> int

is_valid() -> bool
```

No existirán setters.

## 33. API concreta de DeviceBusDispatchReport

### 33.1 Constructor

```gdscript
func _init(
	status: Status,
	publications_accepted: int,
	publications_dispatched: int,
	callbacks_invoked: int,
	callbacks_skipped: int,
	publications_dropped: int,
	pending_peak: int,
	elapsed_usec: int,
	limit_reached: StringName,
	trigger_topic: StringName
) -> void
```

### 33.2 API

```gdscript
get_status() -> Status

get_publications_accepted() -> int

get_publications_dispatched() -> int

get_callbacks_invoked() -> int

get_callbacks_skipped() -> int

get_publications_dropped() -> int

get_pending_peak() -> int

get_elapsed_usec() -> int

get_limit_reached() -> StringName

get_trigger_topic() -> StringName

is_completed() -> bool

is_aborted() -> bool
```

### 33.3 Report inicial

DeviceBus construirá inicialmente:

```text
Status:
NO_DISPATCH

Counters:
0

Limit:
empty StringName

Trigger Topic:
empty StringName
```

## 34. Estrategia de pruebas

Se crearán pruebas nuevas.

No se modificará DeviceBusPublishTest para utilizar FIFO.

Pruebas previstas:

```text
DeviceBusDispatchPolicyTest

DeviceBusDispatchReportTest

DeviceBusFifoDispatchTest

DeviceBusDispatchBudgetTest

DeviceBusDispatchMutationTest

DeviceBusDispatchRecoveryTest

DeviceBusFanOutTest
```

Cada prueba utilizará una instancia nueva de DeviceBus.

Los límites pequeños se configurarán antes del primer ciclo.

## 35. DeviceBusDispatchPolicyTest

### Archivos previstos

```text
test/core/device_bus/
DeviceBusDispatchPolicyTest.tscn

test/core/device_bus/
device_bus_dispatch_policy_test.gd
```

### DBP-U01 — Defaults

Debe verificar:

```text
publications:
1024

callbacks:
8192

pending:
512

time:
50000

is_valid():
true
```

### DBP-U02 — Policy pequeña válida

Ejemplo:

```text
publications:
3

callbacks:
4

pending:
2

time:
100000
```

Debe devolver:

```text
is_valid():
true
```

### DBP-U03 — Valores cero

Cada valor igual a cero debe producir una Policy inválida.

### DBP-U04 — Valores negativos

Cada valor negativo debe producir una Policy inválida.

### DBP-U05 — Hard Maximums

Un valor exactamente igual al hard maximum es válido.

Un valor mayor es inválido.

### DBP-U06 — API inmutable

Debe verificar que no existan setters públicos.

## 36. DeviceBusDispatchReportTest

### Archivos previstos

```text
test/core/device_bus/
DeviceBusDispatchReportTest.tscn

test/core/device_bus/
device_bus_dispatch_report_test.gd
```

### DBR-U01 — NO_DISPATCH

Debe verificar:

```text
status:
NO_DISPATCH

counters:
0

is_completed():
false

is_aborted():
false
```

### DBR-U02 — COMPLETED

Debe verificar todos los getters y:

```text
is_completed():
true

is_aborted():
false
```

### DBR-U03 — Abort statuses

Cada estado:

```text
ABORTED_PUBLICATION_BUDGET

ABORTED_CALLBACK_BUDGET

ABORTED_QUEUE_LIMIT

ABORTED_TIME_BUDGET
```

debe producir:

```text
is_completed():
false

is_aborted():
true
```

### DBR-U04 — Inmutabilidad

No deben existir setters públicos.

## 37. DeviceBusFifoDispatchTest

### Archivos previstos

```text
test/core/device_bus/
DeviceBusFifoDispatchTest.tscn

test/core/device_bus/
device_bus_fifo_dispatch_test.gd
```

### DBF-U01 — Orden reentrante FIFO

Con Subscribers A y B:

```text
A recibe outer.

A publica inner.

B recibe outer.

A recibe inner.

B recibe inner.
```

Orden esperado:

```text
A:outer

B:outer

A:inner

B:inner
```

### DBF-U02 — Sin crecimiento recursivo

Una cadena de publicaciones reentrantes dentro del budget debe terminar sin stack overflow.

La prueba utilizará una cantidad suficiente para demostrar dispatch iterativo, pero muy inferior al hard maximum.

### DBF-U03 — Report completo

Debe verificar:

```text
Status:
COMPLETED

publications_accepted:
cantidad esperada

publications_dispatched:
cantidad esperada

callbacks_invoked:
cantidad esperada
```

### DBF-U04 — Policy lock

Debe verificar:

```text
Policy válida antes del primer ciclo:
aceptada.

Policy después del primer ciclo:
rechazada.

Policy original:
conservada.

get_dispatch_policy() devuelve la Policy configurada.

Después de rechazar una Policy tardía,
get_dispatch_policy() continúa devolviendo
la Policy original.
```

## 38. DeviceBusDispatchBudgetTest

### Archivos previstos

```text
test/core/device_bus/
DeviceBusDispatchBudgetTest.tscn

test/core/device_bus/
device_bus_dispatch_budget_test.gd
```

### DBB-U01 — Publication Budget

Utilizar Policy pequeña.

Crear un ciclo que intente superar publicaciones permitidas.

Debe verificar:

```text
root publish devuelve false;

status:
ABORTED_PUBLICATION_BUDGET;

limit:
publication_budget;

publications_dropped > 0;

proceso continúa.
```

### DBB-U02 — Callback Budget

Registrar más Callables que el budget.

Debe verificar:

```text
solo se ejecutan callbacks permitidos;

callbacks_skipped > 0;

status:
ABORTED_CALLBACK_BUDGET.
```

### DBB-U03 — Queue Limit

Durante un callback, encolar más mensajes que el máximo pendiente.

Debe verificar:

```text
status:
ABORTED_QUEUE_LIMIT;

publicaciones pendientes se descartan;

queue no queda activa.
```

### DBB-U04 — Time Budget

Utilizar una Policy con límite pequeño.

Un callback de prueba consume tiempo controlado y devuelve.

Debe verificar:

```text
status:
ABORTED_TIME_BUDGET;

proceso continúa;

callbacks posteriores no se ejecutan.
```

La prueba no utilizará un loop infinito.

## 39. DeviceBusDispatchMutationTest

### Archivos previstos

```text
test/core/device_bus/
DeviceBusDispatchMutationTest.tscn

test/core/device_bus/
device_bus_dispatch_mutation_test.gd
```

### DBM-U01 — Subscribe durante dispatch

Message A conserva su snapshot.

Message B pendiente utiliza el registro actualizado.

### DBM-U02 — Unsubscribe durante dispatch

Message A conserva el Subscriber eliminado.

Message B no lo incluye.

### DBM-U03 — Clear durante dispatch

Message A conserva su snapshot.

Mensajes posteriores tienen snapshots vacíos.

La queue continúa hasta quedar vacía.

### DBM-U04 — Callable invalidado

El Callable no se ejecuta.

Se elimina del registro permanente.

El ciclo no se aborta.

## 40. DeviceBusDispatchRecoveryTest

### Archivos previstos

```text
test/core/device_bus/
DeviceBusDispatchRecoveryTest.tscn

test/core/device_bus/
device_bus_dispatch_recovery_test.gd
```

### DBRC-U01 — Recuperación después de Publication Budget

Provocar aborto.

Después iniciar otro ciclo válido.

Debe verificar:

```text
segundo ciclo:
COMPLETED.
```

### DBRC-U02 — Suscripciones conservadas

Después del aborto, los Subscribers continúan registrados.

### DBRC-U03 — Queue limpia

El segundo ciclo no recibe Entries pendientes del ciclo abortado.

### DBRC-U04 — Last Report

Después del primer ciclo:

```text
Report abortado.
```

Después del segundo:

```text
Report COMPLETED.
```

## 41. DeviceBusFanOutTest

### Archivos previstos

```text
test/core/device_bus/
DeviceBusFanOutTest.tscn

test/core/device_bus/
device_bus_fan_out_test.gd
```

### DBFO-U01 — Single Publication

Una llamada a `publish()` con tres Subscribers debe producir:

```text
publications_accepted:
1

publications_dispatched:
1

callbacks_invoked:
3
```

No crea tres Queue Entries.

### DBFO-U02 — Shared Reference

Los tres Subscribers reciben la misma referencia de mensaje.

### DBFO-U03 — DELIVER_ALL

Cada Subscriber recibe la publicación.

DeviceBus no aplica coalescing.

### DBFO-U04 — No republishing

La prueba confirma fan-out sin que los consumidores publiquen nuevamente el mensaje.

La regla de ownership se confirma mediante composición y revisión del test.

## 42. Baseline anterior

La prueba:

```text
test/core/device_bus/
device_bus_publish_test.gd
```

protege orden reentrante depth-first.

Será declarada:

```text
SUPERADA
```

cuando las pruebas FIFO, budgets, mutations y recovery terminen correctamente.

No será modificada.

Después será retirada del árbol activo y permanecerá en Git.

## 43. Baselines conservados

Continuarán activos:

```text
DeviceBusRegistryTest

DeviceBusIntegrationTest

DeviceBusFailureIsolationTest
```

DeviceBusFailureIsolationTest permanece fuera de la regresión regular porque genera un error intencional.

Después de migrar DeviceBus deberán ejecutarse:

```text
DeviceBusRegistryTest

DeviceBusIntegrationTest
```

sin modificaciones.

## 44. Orden de implementación

```text
1. Implementar DeviceBusDispatchPolicy.

2. Ejecutar DeviceBusDispatchPolicyTest.

3. Implementar DeviceBusDispatchReport.

4. Ejecutar DeviceBusDispatchReportTest.

5. Migrar DeviceBus a queue FIFO.

6. Implementar configure_dispatch_policy().

7. Implementar get_last_dispatch_report().

8. Ejecutar DeviceBusFifoDispatchTest.

9. Ejecutar DeviceBusDispatchBudgetTest.

10. Ejecutar DeviceBusDispatchMutationTest.

11. Ejecutar DeviceBusDispatchRecoveryTest.

12. Ejecutar DeviceBusFanOutTest.

13. Ejecutar DeviceBusRegistryTest.

14. Ejecutar DeviceBusIntegrationTest.

15. Ejecutar pruebas de consumidores actuales.

16. Declarar DeviceBusPublishTest como SUPERADA.

17. Retirar DeviceBusPublishTest.

18. Ejecutar runner -All.

19. Registrar resultados.

20. Actualizar DeviceBus Design.

21. Actualizar Core Architecture.
```

## 45. Criterios de aceptación

Runtime Safety satisface el diseño cuando:

1. Policy tiene defaults válidos;

2. Policy rechaza valores fuera de hard maximum;

3. Policy se bloquea después del primer ciclo;

4. Report es inmutable;

5. Report inicial es NO_DISPATCH;

6. DeviceBus utiliza queue FIFO;

7. reentrada no aumenta call stack;

8. Publication Budget aborta correctamente;

9. Callback Budget aborta correctamente;

10. Queue Limit aborta correctamente;

11. Time Budget aborta correctamente;

12. aborto conserva suscripciones;

13. ciclo posterior puede completarse;

14. mutations conservan semántica aprobada;

15. fan-out utiliza una sola Queue Entry;

16. DeviceBus no implementa coalescing;

17. publish() devuelve bool;

18. Last Report es consultable;

19. pruebas sucesoras terminan correctamente;

20. regresión completa termina correctamente.

21. DeviceBus expone la Policy activa.

22. Policy se bloquea después del primer ciclo.

23. DeviceBus permanece confinado a un thread.

24. Los budgets deterministas no dependen de tiempo real.

25. Un Time Budget abortado no produce
	un frame de simulación válido.

26. La limitación de Payload Size permanece
	explícitamente documentada.

## 46. Fuera de alcance

Esta implementación no añadirá:

- DeviceGraph;
- CompositionCompiler;
- RuntimeSafety completo;
- Snapshot Repository;
- Measurement Identity;
- Provenance serialization;
- Process Isolation;
- hardware watchdog;
- prioridades;
- coalescing;
- backpressure externo.

## 47. Resumen de migración

```text
Dispatch:

recursive depth-first
→
iterative FIFO

publish():

void
→
bool

Safety:

unbounded
→
bounded Policy

Observability:

none
→
Dispatch Report

Reentrant behavior:

immediate recursion
→
enqueue

Coalescing:

none
→
continúa none

Delivery:

DELIVER_ALL

Ownership:

validado fuera del Bus

Provenance:

contrato futuro

Baseline depth-first:

SUPERADO después de pruebas sucesoras
```
