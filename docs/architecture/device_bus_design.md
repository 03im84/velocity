# DeviceBus — Diseño del Componente

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 2026-08-14 |
| ADR relacionado | ADR-001 — DeviceBus |
| Implementación prevista | `res://scripts/core/device_bus.gd` |

## 1. Propósito

Este documento traduce las decisiones de ADR-001 a un diseño concreto e implementable para DeviceBus.

ADR-001 define por qué existe DeviceBus, cuál es su responsabilidad y cuáles son sus límites.

Este documento define:

- la forma del componente;
- su modelo de ejecución;
- su API pública concreta;
- el comportamiento observable de sus operaciones;
- las reglas que deberá satisfacer su implementación;
- los casos que deberán ser verificados mediante pruebas.

Este documento no amplía la responsabilidad definida en ADR-001.

## 2. Responsabilidad

DeviceBus tiene una única responsabilidad:

> Gestionar el intercambio desacoplado de mensajes entre productores y consumidores.

DeviceBus administra registros de suscriptores y entrega mensajes publicados a los consumidores correspondientes.

No interpreta el contenido de los mensajes y no conoce las implementaciones concretas que participan en el intercambio.

## 3. Forma del componente

DeviceBus será una clase derivada de:

```gdscript
RefCounted
```

La declaración prevista será:

```gdscript
extends RefCounted
class_name DeviceBus
```

DeviceBus no será:

- un Node;
- una escena;
- un autoload;
- una clase estática;
- un singleton global.

DeviceBus no necesita participar en el árbol de escenas porque:

- no procesa frames;
- no tiene representación física;
- no recibe input;
- no dibuja información;
- no necesita notificaciones del SceneTree.

## 4. Ciclo de vida

DeviceBus será creado explícitamente por un componente externo.

El propietario concreto del Bus será definido cuando se diseñe la composición general de la aplicación.

DeviceBus no:

- se crea a sí mismo;
- crea Devices;
- destruye Devices;
- controla el ciclo de vida de sus suscriptores;
- busca dependencias dentro del árbol de escenas.

Al heredar de RefCounted, la instancia permanecerá activa mientras existan referencias hacia ella.

Esto permite:

- crear buses independientes;
- utilizar un Bus diferente en cada prueba;
- sustituir su implementación;
- controlar explícitamente su alcance;
- evitar estado global oculto.

## 5. Modelo de ejecución

DeviceBus 1.0 utilizará publicación síncrona.

El flujo será:

```text
Publisher
	│
	│ publish()
	▼
DeviceBus
	│
	│ entrega inmediata
	▼
Subscribers
	│
	▼
publish() termina
```

Cuando un productor llama a `publish()`, DeviceBus intenta entregar el mensaje a los suscriptores antes de devolver el control al productor.

DeviceBus 1.0 no utilizará:

- colas internas;
- publicación diferida;
- `_process()`;
- `_physics_process()`;
- threads;
- workers;
- timers;
- llamadas diferidas al SceneTree.

La publicación se ejecuta dentro del mismo flujo de ejecución que realizó la llamada.

Una publicación síncrona permite:

- conservar un orden determinista;
- ejecutar pruebas aisladas;
- evitar estados intermedios;
- prescindir del árbol de escenas;
- mantener pequeña la responsabilidad del Bus.

La consecuencia aceptada es que un suscriptor lento puede retrasar la finalización de `publish()`.

DeviceBus no resolverá ese problema mediante colas internas. Si un consumidor necesita trabajo asíncrono, deberá gestionarlo fuera del Bus.

### 5.1 Concurrencia

DeviceBus 1.0 no ofrecerá garantías thread-safe.

Todas las operaciones sobre una misma instancia deberán ejecutarse desde un único hilo de ejecución.

DeviceBus no utilizará:

- Mutex;
- Semaphore;
- locks;
- estructuras concurrentes;
- colas entre threads.

Si en el futuro un productor externo necesita publicar desde otro thread, deberá utilizar un adaptador que transfiera la operación al contexto propietario del Bus.

Añadir concurrencia directamente a DeviceBus requerirá una nueva decisión de diseño.

La ausencia de soporte thread-safe mantiene la versión 1.0:

- pequeña;
- determinista;
- fácil de probar;
- libre de mecanismos de sincronización innecesarios.

## 6. Tipos públicos

### 6.1 Topic

Los topics utilizarán:

```gdscript
StringName
```

Un topic representa una identidad interna.

Ejemplos:

```gdscript
&"distance"
&"imu"
&"motor_command"
```

Un topic no es texto de presentación para el usuario.

### 6.2 Subscriber

Los suscriptores utilizarán:

```gdscript
Callable
```

DeviceBus conoce una función que puede invocar, pero no necesita conocer la clase, escena o Device que contiene esa función.

### 6.3 Message

Los mensajes utilizarán:

```gdscript
Variant
```

DeviceBus podrá recibir diferentes tipos de mensaje sin depender de sus implementaciones concretas.

El uso de Variant no elimina la necesidad de contratos de mensaje.

Los contratos concretos, como `DistanceMeasurement` o `MotorCommand`, serán diseñados por separado.

DeviceBus los transportará sin interpretarlos.

## 7. API pública

DeviceBus expondrá únicamente las siguientes operaciones.

### 7.1 Registrar un suscriptor

```gdscript
func subscribe(
	topic: StringName,
	subscriber: Callable
) -> bool
```

Devuelve:

- `true` cuando la suscripción fue creada;
- `false` cuando la suscripción fue rechazada.

### 7.2 Eliminar un suscriptor

```gdscript
func unsubscribe(
	topic: StringName,
	subscriber: Callable
) -> bool
```

Devuelve:

- `true` cuando una suscripción existente fue eliminada;
- `false` cuando la suscripción no existía.

### 7.3 Publicar un mensaje

```gdscript
func publish(
	topic: StringName,
	message: Variant
) -> void
```

Entrega el mensaje a los suscriptores registrados para el topic.

`publish()` no devuelve la cantidad de consumidores.

El productor no debe modificar su comportamiento en función de cuántos consumidores recibieron el mensaje.

### 7.4 Limpiar el Bus

```gdscript
func clear() -> void
```

Elimina todos los registros de suscripción.

No destruye suscriptores ni modifica Devices.

### 7.5 Consultar un topic

```gdscript
func has_subscribers(
	topic: StringName
) -> bool
```

Devuelve `true` cuando el topic tiene al menos un suscriptor válido.

### 7.6 Consultar la cantidad de suscriptores

```gdscript
func get_subscriber_count(
	topic: StringName
) -> int
```

Devuelve la cantidad de suscriptores válidos registrados para el topic.

### 7.7 Consultar los topics

```gdscript
func get_topics() -> Array[StringName]
```

Devuelve los topics que contienen suscriptores activos.

## 8. Límites de la API

La API pública de DeviceBus 1.0 estará formada solamente por:

```text
subscribe()
unsubscribe()
publish()
clear()
has_subscribers()
get_subscriber_count()
get_topics()
```

No se añadirán métodos públicos para:

- logging;
- historial;
- serialización;
- networking;
- filtrado complejo;
- prioridades;
- transformación de mensajes;
- descubrimiento de Devices;
- acceso a la física;
- acceso al árbol de escenas.

Si aparece la necesidad de una nueva operación pública, primero deberá comprobarse que pertenece a la responsabilidad definida por ADR-001.

## 9. Modelo del registro

DeviceBus organizará las suscripciones mediante la relación conceptual:

```text
Topic
  │
  └──► Lista ordenada de Callables
```

Ejemplo:

```text
distance
  │
  ├──► HUD.on_distance
  ├──► Suspension.on_distance
  └──► Telemetry.on_distance
```

Cada topic identifica una lista independiente.

La lista conserva los Callables en el orden en que fueron registrados.

La representación interna debe permitir:

- localizar suscriptores por topic;
- conservar el orden de registro;
- detectar duplicados;
- eliminar una suscripción exacta;
- eliminar topics vacíos;
- consultar los topics activos.

La estructura interna no será expuesta directamente por la API pública.

## 10. Validación de topics

### 10.1 Topic vacío

El topic vacío no es una identidad válida.

La operación:

```gdscript
subscribe(
	&"",
	subscriber
)
```

será rechazada y devolverá:

```text
false
```

El registro no será modificado.

Para las demás operaciones, un topic vacío tendrá el siguiente comportamiento:

```text
unsubscribe()             devuelve false
publish()                 no realiza entregas
has_subscribers()         devuelve false
get_subscriber_count()    devuelve 0
```

Un topic vacío no será almacenado.

### 10.2 Normalización

DeviceBus no normalizará los topics.

No realizará:

- conversión a minúsculas;
- conversión a mayúsculas;
- eliminación de espacios;
- sustitución de caracteres;
- creación de prefijos;
- validación de nombres de dominio.

Por tanto:

```gdscript
&"distance"
&"Distance"
&"DISTANCE"
```

son topics diferentes.

Las convenciones semánticas para nombrar topics serán definidas fuera de DeviceBus.

DeviceBus únicamente comprobará que el topic no esté vacío.

## 11. Validación de suscriptores

### 11.1 Callable inválido

`subscribe()` comprobará que el Callable sea válido.

La comprobación conceptual será:

```gdscript
subscriber.is_valid()
```

Si el Callable no es válido:

```text
subscribe() devuelve false
```

El topic no será creado y el registro no será modificado.

DeviceBus no necesitará conocer:

- la clase del suscriptor;
- el Node que contiene el método;
- la ruta de la escena;
- el nombre concreto del método.

### 11.2 Firma del suscriptor

Un suscriptor debe poder recibir un mensaje como argumento.

Contrato conceptual:

```gdscript
func receive(
	message: Variant
) -> void
```

El método puede utilizar cualquier nombre.

Ejemplos:

```gdscript
func on_distance(
	message: Variant
) -> void
```

```gdscript
func handle_measurement(
	message: Variant
) -> void
```

DeviceBus no inspeccionará la cantidad de argumentos durante `subscribe()`.

La compatibilidad de la firma forma parte del contrato del suscriptor.

Esto evita que DeviceBus tenga que interpretar:

- métodos;
- argumentos opcionales;
- argumentos enlazados;
- tipos concretos del consumidor.

## 12. Suscripciones duplicadas

La combinación:

```text
Topic + Callable
```

identifica una suscripción.

La misma combinación solo puede registrarse una vez.

Primera operación:

```gdscript
bus.subscribe(
	&"distance",
	hud.on_distance
)
```

Resultado:

```text
true
```

Si se repite exactamente la misma operación:

```gdscript
bus.subscribe(
	&"distance",
	hud.on_distance
)
```

el resultado será:

```text
false
```

El Callable no se añadirá por segunda vez y conservará su posición original.

Esta regla evita entregas duplicadas causadas por errores de inicialización.

### 12.1 Un Callable en diferentes topics

El mismo Callable puede registrarse en diferentes topics.

Ejemplo:

```gdscript
bus.subscribe(
	&"distance",
	debug_panel.on_message
)

bus.subscribe(
	&"imu",
	debug_panel.on_message
)
```

Ambas suscripciones son válidas porque representan combinaciones diferentes.

## 13. Orden del registro

Los suscriptores se conservan en orden de registro.

Si se registran:

```text
A
B
C
```

el registro será:

```text
[A, B, C]
```

Si se elimina `B`, el registro será:

```text
[A, C]
```

Los elementos restantes no se reordenan.

Si `B` se registra nuevamente, ocupará una posición nueva al final:

```text
[A, C, B]
```

El orden del registro será la base del orden determinista de publicación.

## 14. Eliminación de suscripciones

`unsubscribe()` elimina únicamente la combinación exacta:

```text
Topic + Callable
```

Si la suscripción existe:

```text
unsubscribe() devuelve true
```

Si la suscripción no existe:

```text
unsubscribe() devuelve false
```

La eliminación no afecta:

- otros Callables del mismo topic;
- el mismo Callable registrado en otros topics;
- otros topics;
- el objeto que contiene el Callable.

DeviceBus elimina el registro.

No destruye ni libera el suscriptor.

### 14.1 Topics sin suscriptores

Cuando se elimina el último suscriptor de un topic, el topic también será eliminado.

Antes:

```text
distance
  └──► HUD.on_distance
```

Después de eliminar la última suscripción:

```text
distance
  └──► no existe
```

Esto garantiza que:

```gdscript
has_subscribers(&"distance")
```

devuelva:

```text
false
```

También garantiza que `get_topics()` no incluya topics vacíos.

## 15. Orden de los topics

`get_topics()` devolverá los topics activos en el orden en que fueron creados.

Ejemplo inicial:

```text
1. distance
2. imu
3. motor_command
```

Resultado:

```gdscript
[
	&"distance",
	&"imu",
	&"motor_command"
]
```

Si `imu` pierde su último suscriptor:

```gdscript
[
	&"distance",
	&"motor_command"
]
```

Si posteriormente se crea nuevamente:

```gdscript
[
	&"distance",
	&"motor_command",
	&"imu"
]
```

El topic recreado se considera un registro nuevo y aparece al final.

`get_topics()` devolverá un Array nuevo.

No devolverá una referencia directa a la estructura interna de DeviceBus.

## 16. Callables invalidados

Un Callable puede ser válido durante `subscribe()` y dejar de serlo posteriormente.

Ejemplo conceptual:

```text
1. Un método de un Node se registra.
2. El Node es liberado.
3. El Callable deja de ser válido.
```

DeviceBus no controla el ciclo de vida del suscriptor.

Cuando encuentre un Callable inválido:

1. no intentará invocarlo;

2. continuará con los demás suscriptores;

3. eliminará la referencia inválida de su registro;

4. eliminará el topic si ya no quedan suscriptores válidos.

La limpieza será interna y silenciosa.

DeviceBus no:

- imprimirá un error;
- registrará un log;
- intentará recrear el suscriptor;
- intentará localizar un reemplazo.

### 16.1 Consultas y Callables invalidados

Las siguientes operaciones reflejarán únicamente suscriptores válidos:

```text
has_subscribers()
get_subscriber_count()
get_topics()
```

Antes de devolver su resultado, estas operaciones podrán eliminar referencias inválidas encontradas en el registro.

Ejemplo:

```text
distance
  └──► Callable inválido
```

Después de consultar:

```gdscript
has_subscribers(&"distance")
```

el resultado será:

```text
false
```

El topic desaparecerá si no conserva otros Callables válidos.

Esta limpieza forma parte del mantenimiento mínimo del registro.

No representa estado funcional de un Device.

## 17. Limpieza completa

`clear()` eliminará:

- todos los topics;
- todas las listas de suscriptores;
- todas las referencias a Callables conservadas por DeviceBus.

`clear()` no:

- destruye Devices;
- libera Nodes;
- modifica mensajes;
- reinicia la simulación;
- imprime información;
- crea nuevos registros.

Después de `clear()`:

```gdscript
get_topics()
```

devuelve:

```gdscript
[]
```

Para cualquier topic:

```gdscript
has_subscribers(topic)
```

devuelve:

```text
false
```

y:

```gdscript
get_subscriber_count(topic)
```

devuelve:

```text 
0 
```

## 18. Instantánea de publicación

Al comenzar `publish()`, DeviceBus creará una copia superficial de la lista de suscriptores correspondiente al topic.

Ejemplo:

```text
Registro actual
[A, B, C]
	 │
	 │ copia superficial
	 ▼
Instantánea
[A, B, C]
```

DeviceBus recorrerá la instantánea.

No recorrerá directamente la lista interna conservada en el registro.

La copia será superficial porque debe conservar:

- los mismos Callables;
- el mismo orden;
- la identidad de los suscriptores.

DeviceBus no crea copias de los objetos suscriptores.

Cada llamada a `publish()` crea su propia instantánea.

## 19. Modificaciones durante una publicación

Una modificación realizada durante `publish()`:

- se aplica inmediatamente al registro interno;
- no altera la instantánea de la publicación actual;
- afecta a las publicaciones posteriores.

Esta regla se aplica a:

- `subscribe()`;
- `unsubscribe()`;
- `clear()`.

### 19.1 Suscripción durante una publicación

Registro inicial:

```text
[A, B]
```

Durante el callback de `A`, se registra `C`.

El registro interno pasa a ser:

```text
[A, B, C]
```

La instantánea actual permanece:

```text
[A, B]
```

Resultado:

```text
Publicación actual:
A
B

Publicación siguiente:
A
B
C
```

Un suscriptor añadido durante `publish()` participa a partir de la siguiente publicación.

### 19.2 Eliminación durante una publicación

Registro inicial:

```text
[A, B, C]
```

Durante el callback de `A`, se elimina la suscripción de `B`.

El registro interno pasa a ser:

```text
[A, C]
```

La instantánea actual permanece:

```text
[A, B, C]
```

Resultado:

```text
Publicación actual:
A
B
C

Publicación siguiente:
A
C
```

Un suscriptor eliminado durante `publish()` todavía recibe la publicación actual si:

- estaba presente en la instantánea;
- su Callable continúa siendo válido.

### 19.3 Clear durante una publicación

Registro inicial:

```text
[A, B, C]
```

Durante el callback de `A`, se ejecuta:

```gdscript
bus.clear()
```

El registro interno queda vacío:

```text
[]
```

La instantánea actual permanece:

```text
[A, B, C]
```

Resultado:

```text
Publicación actual:
A
B
C

Publicación siguiente:
ningún suscriptor
```

`clear()` no cancela una publicación que ya comenzó.

## 20. Callables invalidados durante una publicación

Antes de cada invocación, DeviceBus comprobará que el Callable de la instantánea continúe siendo válido.

Comprobación conceptual:

```gdscript
subscriber.is_valid()
```

Si el Callable dejó de ser válido:

1. no será invocado;

2. DeviceBus continuará con el siguiente suscriptor;

3. la referencia inválida será eliminada del registro interno si todavía existe;

4. el topic será eliminado si ya no conserva suscriptores válidos.

Una desuscripción y una invalidación no representan el mismo caso.

Un Callable desuscrito pero todavía válido puede recibir la publicación actual porque permanece en la instantánea.

Un Callable invalidado no debe ser invocado aunque permanezca en la instantánea.

## 21. Orden de publicación

DeviceBus recorrerá la instantánea desde el primer elemento hasta el último.

Si la instantánea contiene:

```text
[A, B, C]
```

el orden de entrega será:

```text
A
│
▼
B
│
▼
C
```

DeviceBus no utilizará:

- prioridades;
- orden alfabético;
- orden por clase;
- orden por nombre de método;
- orden del árbol de escenas;
- orden aleatorio.

El orden de publicación será el orden de registro existente en el momento de crear la instantánea.

## 22. Publicaciones reentrantes

Una publicación es reentrante cuando un suscriptor llama nuevamente a `publish()` antes de que termine la publicación actual.

Las publicaciones reentrantes estarán permitidas.

Se ejecutarán de forma:

- síncrona;
- inmediata;
- depth-first.

Ejemplo con suscriptores `A` y `B`:

```text
1. A recibe "outer".
2. A publica "inner".
3. A recibe "inner".
4. B recibe "inner".
5. Termina publish("inner").
6. B recibe "outer".
7. Termina publish("outer").
```

Orden observable:

```text
A:outer
A:inner
B:inner
B:outer
```

Cada publicación crea su propia instantánea.

### 22.1 Registro utilizado por una publicación reentrante

Una publicación reentrante utiliza el registro vigente en el momento en que comienza.

Ejemplo:

```text
Registro exterior inicial:
[A, B]
```

Durante el callback exterior, `A` elimina a `B` y después realiza una publicación interna.

La publicación exterior conserva:

```text
[A, B]
```

La publicación interior crea una instantánea nueva:

```text
[A]
```

Resultado:

```text
A:outer
A:inner
B:outer
```

`B` no recibe el mensaje interno porque ya no existía en el registro al comenzar la publicación interior.

`B` todavía recibe el mensaje exterior porque permanecía en la instantánea exterior.

### 22.2 Riesgo de recursión

DeviceBus no intentará detectar ciclos semánticos de publicación.

Ejemplo de ciclo:

```text
A recibe distance
	│
	└──► publica distance
			  │
			  └──► A recibe distance
						│
						└──► ...
```

Detectar estos ciclos requeriría interpretar relaciones entre topics y Devices.

Esa responsabilidad no pertenece a DeviceBus.

La prevención de ciclos pertenece al diseño de los Devices y, posteriormente, a DeviceGraph.

## 23. Identidad del mensaje

DeviceBus entregará a cada suscriptor el mismo valor o referencia que recibió.

Conceptualmente:

```text
message
   │
   ├──► A
   ├──► B
   └──► C
```

DeviceBus no ejecutará una operación equivalente a:

```gdscript
message.duplicate()
```

Tampoco creará una copia diferente para cada suscriptor.

DeviceBus:

- no interpreta el mensaje;
- no transforma el mensaje;
- no clona el mensaje;
- no modifica el mensaje.

### 23.1 Mensajes mutables

Si el mensaje es un objeto mutable, un consumidor podría modificarlo antes de que sea entregado a los consumidores posteriores.

DeviceBus no impedirá esa modificación mediante copias automáticas.

La inmutabilidad será responsabilidad de:

- los contratos de mensaje;
- los productores;
- los consumidores.

Los contratos concretos deberán definir si sus datos pueden modificarse después de ser publicados.

## 24. Publicación sin suscriptores

Si `publish()` recibe:

- un topic vacío;
- un topic inexistente;
- un topic sin Callables válidos;

la operación termina sin realizar entregas.

`publish()` devuelve:

```gdscript
void
```

Por tanto, no devuelve:

- un error;
- una cantidad de consumidores;
- una lista de resultados.

DeviceBus tampoco imprime información.

Publicar en un topic sin suscriptores es una operación válida sin efecto observable.

## 25. Aislamiento de fallos

ADR-001 establece:

> Un fallo en un suscriptor no debe impedir intentar la entrega a los demás.

DeviceBus recorrerá todos los Callables válidos de la instantánea.

Si una invocación produce un error normal de GDScript y el control regresa al llamador, DeviceBus continuará con el siguiente suscriptor.

El error puede ser reportado por Godot.

Ese reporte pertenece al engine y al suscriptor que produjo el fallo.

DeviceBus no añadirá:

- `print()`;
- `push_error()`;
- logging;
- historial de fallos;
- almacenamiento de resultados;
- interpretación del error.

La implementación deberá verificarse específicamente con Godot Engine 4.7.1.

## 26. Límite del aislamiento

DeviceBus puede aislar:

- Callables inválidos;
- suscriptores eliminados del registro;
- objetos liberados;
- callbacks con errores normales de ejecución que devuelven el control.

DeviceBus no puede proteger el proceso frente a:

- un ciclo infinito dentro de un suscriptor;
- un bloqueo permanente;
- una finalización intencional de la aplicación;
- un fallo fatal del engine;
- un cierre del sistema operativo;
- agotamiento de memoria;
- recursión ilimitada;
- desbordamiento de la pila.

Estas situaciones están fuera de la responsabilidad de un Bus ejecutado dentro del mismo proceso.

## 27. Estado interno

DeviceBus conservará únicamente el registro de suscripciones.

La variable privada prevista será:

```gdscript
var _subscribers_by_topic: Dictionary[StringName, Array] = {}
```

La relación conceptual será:

```text
StringName
	│
	▼
Array de Callables
```

Ejemplo conceptual:

```gdscript
{
	&"distance": [
		hud.on_distance,
		suspension.on_distance,
	],

	&"imu": [
		hud.on_imu,
		telemetry.on_imu,
	],
}
```

Cada valor del Dictionary será una lista ordenada de Callables.

Aunque el tipo del valor sea `Array`, el invariante interno establece que sus elementos deben ser Callables.

### 27.1 Nombre del registro

La variable se llamará:

```gdscript
_subscribers_by_topic
```

El nombre expresa:

- que contiene suscriptores;
- que están organizados por topic;
- que la variable es privada.

No se utilizarán nombres ambiguos como:

```gdscript
_data
_events
_callbacks
_bus
_registry
```

La variable tampoco se llamará `SubscriptionRegistry`.

`SubscriptionRegistry` representa un posible componente futuro con una responsabilidad propia. Todavía no existe en DeviceBus 1.0.

### 27.2 Estado no almacenado

DeviceBus no almacenará:

- el último mensaje;
- historial de mensajes;
- cantidad total de publicaciones;
- último error;
- publisher actual;
- Device actual;
- Node propietario;
- referencia al SceneTree;
- cola de mensajes;
- mensajes pendientes;
- prioridades;
- filtros;
- resultados de consumidores.

Las instantáneas de publicación serán variables locales dentro de `publish()`.

No formarán parte del estado permanente del Bus.

## 28. Funciones privadas

DeviceBus utilizará únicamente las funciones auxiliares necesarias para mantener los invariantes del registro.

### 28.1 Limpiar Callables inválidos

```gdscript
func _prune_invalid_subscribers(
	topic: StringName
) -> void
```

Responsabilidad:

> Eliminar del topic los Callables que dejaron de ser válidos.

Esta función podrá ser utilizada por:

- `publish()`;
- `has_subscribers()`;
- `get_subscriber_count()`;
- `get_topics()`.

La eliminación debe conservar el orden relativo de los Callables válidos.

La función no:

- imprime información;
- registra logs;
- devuelve errores;
- destruye suscriptores;
- busca reemplazos.

### 28.2 Eliminar un topic vacío

```gdscript
func _erase_topic_if_empty(
	topic: StringName
) -> void
```

Responsabilidad:

> Eliminar el topic cuando su lista no contiene suscriptores.

Esta función podrá ser utilizada por:

- `unsubscribe()`;
- `_prune_invalid_subscribers()`.

La función no crea topics y no modifica otras listas.

### 28.3 Funciones privadas no incluidas

DeviceBus 1.0 no incluirá funciones como:

```gdscript
_validate_message()
_transform_message()
_log_delivery()
_report_error()
_find_device()
_create_subscription()
_sort_subscribers()
_get_priority()
_process_queue()
```

Estas operaciones no pertenecen a la responsabilidad definida por ADR-001.

Tampoco se crearán inicialmente:

- una clase `Subscription`;
- una clase `SubscriptionRegistry`;
- una clase `Topic`;
- una clase de resultado de publicación.

El registro simple debe demostrar primero que resuelve la necesidad actual.

## 29. Invariantes internos

Al terminar una operación pública, el registro debe cumplir las siguientes reglas.

### 29.1 Topics válidos

Ninguna clave puede ser:

```gdscript
&""
```

### 29.2 Listas no vacías

No deben permanecer topics asociados a listas vacías.

### 29.3 Sin duplicados

Una lista no puede contener dos veces el mismo Callable.

### 29.4 Orden estable

La posición de cada Callable representa su orden de registro.

Eliminar un elemento no reordena los elementos restantes.

### 29.5 Tipos consistentes

Las claves del registro son `StringName`.

Los elementos de cada lista son `Callable`.

### 29.6 Sin estado funcional

El registro contiene únicamente información necesaria para administrar suscripciones.

No almacena el estado de los Devices.

### 29.7 Instantáneas temporales

Una instantánea existe únicamente durante la llamada a `publish()` que la creó.

DeviceBus no conserva instantáneas después de finalizar una publicación.

### 29.8 Referencias inválidas transitorias

Un Callable puede invalidarse sin que DeviceBus sea notificado.

Por ello, una referencia inválida puede existir temporalmente hasta que una publicación o consulta la detecte.

Después de detectarla, DeviceBus debe eliminarla del registro.

## 30. Orden de implementación

La implementación de DeviceBus 1.0 seguirá este orden:

```text
1. Declaración de DeviceBus.

2. Registro interno.

3. subscribe().

4. unsubscribe().

5. clear().

6. has_subscribers().

7. get_subscriber_count().

8. get_topics().

9. _erase_topic_if_empty().

10. _prune_invalid_subscribers().

11. publish().
```

`publish()` se implementará al final porque depende de que ya estén definidos:

- el registro;
- el orden;
- la eliminación;
- las consultas;
- la limpieza de Callables inválidos.

La implementación se realizará en etapas verificables.

No se escribirá todo el componente antes de comprobar sus partes fundamentales.

## 31. Plan de pruebas unitarias

Las pruebas de DeviceBus serán nuevas.

No se modificarán pruebas anteriores del hover o del DistanceSensor para comprobar el Bus.

Cada prueba comenzará con una instancia nueva de DeviceBus para evitar estado compartido.

### DB-U01 — Bus recién creado

Debe verificar:

```text
get_topics() devuelve un Array vacío.

has_subscribers() devuelve false.

get_subscriber_count() devuelve 0.

publish() no produce entregas.
```

### DB-U02 — Suscripción válida

Debe verificar:

```text
subscribe() devuelve true.

El topic aparece en get_topics().

has_subscribers() devuelve true.

get_subscriber_count() devuelve 1.
```

### DB-U03 — Topic vacío

Debe verificar:

```text
subscribe() devuelve false.

unsubscribe() devuelve false.

publish() no entrega mensajes.

has_subscribers() devuelve false.

get_subscriber_count() devuelve 0.

El topic no aparece en get_topics().
```

### DB-U04 — Callable inválido

Debe verificar:

```text
subscribe() devuelve false.

El registro no cambia.
```

### DB-U05 — Suscripción duplicada

Debe verificar:

```text
La primera suscripción devuelve true.

La segunda suscripción devuelve false.

La cantidad permanece en 1.

El mensaje se entrega una sola vez.
```

### DB-U06 — Mismo Callable en topics diferentes

Debe verificar:

```text
Ambas suscripciones son aceptadas.

Cada topic conserva un registro independiente.
```

### DB-U07 — Orden determinista

Registrar:

```text
A
B
C
```

Publicar un mensaje y comprobar:

```text
A
B
C
```

### DB-U08 — Unsubscribe

Debe verificar:

```text
Eliminar una suscripción existente devuelve true.

Eliminarla nuevamente devuelve false.

Otros suscriptores permanecen.

El orden restante no cambia.
```

### DB-U09 — Eliminación de topic vacío

Debe verificar:

```text
Al eliminar el último suscriptor,
el topic desaparece de get_topics().
```

### DB-U10 — Orden de topics

Debe verificar:

```text
Los topics aparecen en orden de creación.

Un topic eliminado desaparece.

Un topic recreado aparece al final.
```

### DB-U11 — Clear

Debe verificar:

```text
Todos los topics desaparecen.

Todas las cantidades vuelven a cero.

Las publicaciones posteriores no entregan mensajes.
```

### DB-U12 — Identidad del mensaje

Debe verificar que todos los consumidores reciben:

```text
el mismo valor o referencia
```

También debe comprobar que DeviceBus no modifica el mensaje.

### DB-U13 — Callable invalidado

Debe verificar:

```text
El Callable inválido no es invocado.

Los demás suscriptores sí son invocados.

La referencia inválida desaparece del registro.
```

### DB-U14 — Subscribe durante publish

Registro inicial:

```text
A
B
```

Durante el callback de `A`, se registra `C`.

Primera publicación esperada:

```text
A
B
```

Segunda publicación esperada:

```text
A
B
C
```

### DB-U15 — Unsubscribe durante publish

Registro inicial:

```text
A
B
C
```

Durante el callback de `A`, se elimina `B`.

Primera publicación esperada:

```text
A
B
C
```

Segunda publicación esperada:

```text
A
C
```

### DB-U16 — Clear durante publish

Debe verificar:

```text
La publicación actual completa su instantánea.

La publicación siguiente no entrega mensajes.
```

### DB-U17 — Publicación reentrante

Con los suscriptores `A` y `B`, debe comprobar:

```text
A:outer
A:inner
B:inner
B:outer
```

### DB-E01 — Continuidad después de un error de GDScript

Esta no es una prueba unitaria ordinaria.

Es una verificación de compatibilidad con el comportamiento de Godot Engine 4.7.1.

Configurar:

```text
A válido.

B produce intencionalmente un error de ejecución.

C válido.```

Esta prueba se ejecutará específicamente con Godot Engine 4.7.1.

El error generado por `B` forma parte intencional de esta prueba.

La prueba será correcta únicamente si `C` recibe el mensaje después del fallo de `B`.

## 32. Prueba de integración

La implementación inicial de DeviceBus no modificará ningún sistema existente del juego.

Después de aprobar las pruebas unitarias se creará una prueba de integración nueva.

Recorrido conceptual:

```text
Productor de prueba
		│
		▼
	DeviceBus
		│
		▼
Consumidor de prueba
```

Esta prueba verificará que dos componentes independientes pueden colaborar mediante la API pública del Bus.

La primera prueba de integración no utilizará:

- HoverSensorSystem;
- HoverLiftSystem;
- Ship;
- HUD;
- telemetría;
- hardware;
- networking.

Esto permite validar la integración del Bus sin modificar baselines existentes.

La integración con un Device real será un hito separado y requerirá su propio diseño.

## 33. Criterios para comenzar la implementación

No se escribirá `device_bus.gd` hasta que:

1. ADR-001 esté registrado;

2. `core_architecture.md` se encuentre activo;

3. `device_bus_design.md` esté completo;

4. todas las decisiones abiertas de DeviceBus 1.0 estén resueltas;

5. el plan de pruebas unitarias esté definido;

6. la prueba de integración esté separada de los baselines existentes;

7. ninguna responsabilidad externa permanezca dentro del diseño.

## 34. Resumen del diseño

DeviceBus 1.0 será:

```text
Una clase RefCounted.

Creada explícitamente.

No global.

No autoload.

Síncrona.

Determinista.

Agnóstica al contenido.

Organizada por topics StringName.

Con suscriptores Callable.

Con mensajes Variant.

Sin colas.

Sin historial.

Sin logging.

Sin networking.

Sin serialización.

Sin dependencias hacia física, HUD, Devices concretos o hardware.
```

Su estado interno estará limitado a:

```text
Topic
	│
	▼
Lista ordenada de Callables
```

Su API pública estará limitada a:

```text
subscribe()
unsubscribe()
publish()
clear()
has_subscribers()
get_subscriber_count()
get_topics()
```

Su implementación deberá satisfacer los 18 casos de prueba definidos en este documento.
