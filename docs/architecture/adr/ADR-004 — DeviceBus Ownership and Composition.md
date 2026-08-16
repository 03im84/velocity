# ADR-004 — DeviceBus Ownership and Composition

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.0 |
| Fecha | 2026-08-15 |
| Componente | DeviceBus |
| Alcance | Propiedad, composición y ciclo de vida |

## 1. Contexto

ADR-001 establece que DeviceBus es el mecanismo interno para intercambiar mensajes de forma desacoplada.

El diseño de DeviceBus 1.0 establece que el componente:

- hereda de RefCounted;
- no es un Node;
- no es un autoload;
- no es un singleton global;
- debe crearse explícitamente;
- debe poder existir fuera del árbol de escenas.

La arquitectura anterior utilizaba DeviceBus como un Node hijo.

Ejemplo:

```text
TestRoot
└── DeviceBus
```

Los consumidores obtenían la referencia mediante:

```gdscript
@onready var device_bus: DeviceBus = $DeviceBus
```

Este modelo ya no es compatible con la implementación RefCounted.

La nueva arquitectura necesita definir:

- quién crea DeviceBus;
- quién conserva su referencia;
- cómo reciben el Bus los participantes;
- cuándo comienzan las publicaciones;
- cómo se realiza el cierre;
- cómo se utiliza el Bus dentro de pruebas;
- cómo se sustituyen las escenas de la arquitectura anterior.

## 2. Problema

Un componente RefCounted no pertenece automáticamente al árbol de escenas.

Sin una regla de propiedad explícita podrían aparecer soluciones incompatibles:

- convertir DeviceBus nuevamente en Node;
- añadirlo como autoload;
- crear un Bus dentro de cada Device;
- utilizar variables estáticas;
- buscarlo mediante rutas globales;
- crear instancias diferentes que deberían comunicarse;
- conservar referencias después del cierre;
- iniciar Devices antes de entregar sus dependencias.

Estas soluciones ocultarían dependencias o fragmentarían el sistema de comunicación.

Velocity necesita un modelo de composición que mantenga DeviceBus:

- explícito;
- reemplazable;
- comprobable;
- independiente del SceneTree;
- limitado al contexto que lo utiliza.

## 3. Decisión

Cada ejecución de Velocity tendrá una Composition Root explícita.

La Composition Root será responsable de:

1. crear una instancia de DeviceBus;

2. conservar la referencia principal durante la ejecución;

3. crear o localizar los participantes del contexto;

4. entregar la misma instancia de DeviceBus a esos participantes;

5. registrar o permitir que se registren suscripciones;

6. iniciar los componentes después de entregar sus dependencias;

7. coordinar el cierre;

8. limpiar el Bus al terminar;

9. liberar su referencia principal.

Modelo conceptual:

```text
Composition Root
	  │
	  ├── crea DeviceBus
	  │
	  ├── conecta productores
	  │
	  ├── conecta consumidores
	  │
	  ├── inicia la ejecución
	  │
	  └── coordina el cierre
```

La Composition Root es un rol arquitectónico.

Esta decisión no obliga a crear inmediatamente una clase llamada:

```text
CompositionRoot
```

Una escena raíz, una prueba o una herramienta pueden cumplir ese rol.

## 4. Cantidad de instancias

DeviceBus no será global.

Cada contexto independiente tendrá su propia instancia.

Ejemplos:

```text
Juego en ejecución
	└── DeviceBus A

Prueba unitaria
	└── DeviceBus B

Prueba de integración
	└── DeviceBus C

Herramienta futura
	└── DeviceBus D
```

Estas instancias no comparten:

- suscripciones;
- topics activos;
- mensajes;
- referencias;
- ciclo de vida.

La regla inicial será:

> Una instancia de DeviceBus por contexto de composición, salvo que una decisión posterior justifique más.

## 5. Inyección de dependencias

Los participantes recibirán DeviceBus explícitamente.

Los mecanismos permitidos incluyen:

```gdscript
func attach(
	bus: DeviceBus
) -> void
```

```gdscript
func initialize_sensor(
	sensor_id: String,
	bus: DeviceBus,
	provider: Object
) -> bool
```

También podrán utilizarse constructores o métodos de configuración cuando correspondan a la responsabilidad del componente.

Los participantes no buscarán DeviceBus mediante:

```gdscript
$DeviceBus
```

```gdscript
get_node()
```

```gdscript
get_tree()
```

```gdscript
/root/DeviceBus
```

Tampoco crearán una instancia propia por conveniencia.

## 6. Propiedad de la referencia

La Composition Root conserva la referencia principal de DeviceBus.

Los participantes pueden conservar referencias secundarias mientras permanezcan conectados al contexto.

“Propiedad” describe la responsabilidad arquitectónica sobre el ciclo de vida.

No se refiere a la propiedad `owner` de los Nodes de Godot.

Un participante no debe:

- sustituir silenciosamente la instancia recibida;
- crear otro Bus;
- liberar el Bus;
- limpiar suscripciones ajenas;
- asumir que el Bus es global;
- conservar la referencia después de su cierre.

## 7. Orden de inicialización

El orden general será:

```text
1. Crear DeviceBus.

2. Crear o localizar participantes.

3. Entregar DeviceBus a los participantes.

4. Registrar suscripciones.

5. Inicializar Devices.

6. Marcar Devices como Ready.

7. Iniciar productores y consumidores.
```

Ningún productor debe comenzar a publicar antes de recibir sus dependencias.

La Composition Root debe garantizar que DeviceBus exista antes de iniciar participantes que necesiten comunicarse.

## 8. Orden de cierre

El orden general será:

```text
1. Detener productores.

2. Detener consumidores.

3. Ejecutar detach() o unsubscribe().

4. Ejecutar shutdown() en los Devices.

5. Ejecutar DeviceBus.clear().

6. Liberar referencias secundarias.

7. Liberar la referencia principal.
```

El cierre debe impedir que un productor continúe publicando mientras sus consumidores están siendo destruidos.

`clear()` elimina registros.

No destruye Devices ni sustituye el proceso de shutdown.

## 9. Aplicación en pruebas

Cada prueba nueva será su propia Composition Root.

La prueba:

- crea DeviceBus;
- conserva la referencia;
- crea productores y consumidores;
- entrega el Bus;
- ejecuta el comportamiento;
- verifica resultados;
- limpia el contexto.

Ejemplo conceptual:

```gdscript
var device_bus: DeviceBus = DeviceBus.new()
```

DeviceBus no se añadirá como Node de la escena de prueba.

Modelo:

```text
TestRoot
├── Nodes físicos, si son necesarios
├── productor de prueba
└── consumidor de prueba

DeviceBus:
Referencia RefCounted conservada por TestRoot
```

Las pruebas no compartirán una instancia global.

## 10. Pruebas de la arquitectura anterior

Las pruebas anteriores utilizaban DeviceBus como Node.

No serán modificadas silenciosamente para aparentar que validan la arquitectura nueva.

El proceso de sustitución será:

```text
1. Conservar temporalmente la prueba anterior.

2. Identificar su garantía observable.

3. Crear una prueba sucesora nueva.

4. Ejecutar la prueba sucesora.

5. Comprobar que protege la garantía necesaria.

6. Registrar la sustitución en project_journal.

7. Declarar la prueba anterior como SUPERADA.

8. Retirarla del árbol activo.

9. Conservarla mediante el historial de Git.
```

Las pruebas anteriores no permanecerán rotas dentro del conjunto activo únicamente para conservar archivos históricos.

Git será el registro histórico de esas versiones.

## 11. Aplicación a BusDebugListener

BusDebugListener ya recibe DeviceBus explícitamente:

```gdscript
func attach(
	bus: DeviceBus
) -> void
```

Este patrón es compatible con ADR-004.

`detach()` deberá:

1. eliminar sus suscripciones;

2. liberar su referencia secundaria al Bus.

BusDebugListener no creará su propia instancia.

## 12. Aplicación a DistanceSensorDevice

DistanceSensorDevice ya recibe DeviceBus mediante:

```gdscript
func initialize_sensor(
	sensor_id: String,
	bus: DeviceBus,
	provider: Object
) -> bool
```

Este patrón es compatible con ADR-004.

DistanceSensorDevice:

- no creará su propio Bus;
- conservará la referencia recibida;
- publicará mediante esa instancia;
- liberará la referencia durante su cierre cuando se diseñe dicha etapa.

La migración de su llamada a `publish()` queda fuera de este ADR.

Primero deberá definirse el contrato canónico de Topic y Message.

## 13. DeviceRuntime

No se creará inmediatamente una clase `DeviceRuntime`.

Una clase futura podría administrar:

- DeviceBus;
- Devices;
- registro;
- inicio;
- cierre;
- perfiles;
- DeviceGraph.

Todavía no existe una necesidad suficiente para fijar todas esas responsabilidades.

Si la lógica de Composition Root empieza a repetirse, se analizará un DeviceRuntime mediante una decisión separada.

## 14. Alternativas descartadas

### 14.1 Autoload

Descartado porque:

- crea estado global;
- oculta dependencias;
- dificulta pruebas aisladas;
- impide contextos independientes;
- contradice ADR-001.

### 14.2 Un Bus por Device

Descartado porque los Devices terminarían conectados a buses diferentes y no podrían intercambiar mensajes.

También convertiría a cada Device en propietario de infraestructura ajena a su responsabilidad.

### 14.3 DeviceBus como Node

Descartado porque:

- revierte el diseño aprobado;
- añade dependencia al SceneTree;
- obliga a utilizar escenas;
- dificulta herramientas independientes;
- no aporta una capacidad necesaria.

### 14.4 Clase estática

Descartada porque convertiría el registro de suscripciones en estado global oculto.

### 14.5 Service Locator

Descartado porque sustituye una dependencia explícita por una búsqueda global.

### 14.6 DeviceRuntime inmediato

Pospuesto porque anticiparía responsabilidades todavía no diseñadas.

## 15. Consecuencias

### 15.1 Positivas

- dependencias visibles;
- pruebas aisladas;
- contextos independientes;
- ausencia de estado global;
- ciclo de vida explícito;
- sustitución sencilla;
- compatibilidad con RefCounted;
- herramientas futuras sin SceneTree;
- inicialización controlada;
- cierre ordenado.

### 15.2 Negativas

- la Composition Root debe conectar componentes explícitamente;
- las escenas anteriores deben ser sustituidas;
- los participantes necesitan métodos de configuración;
- el orden de inicialización requiere disciplina;
- no existe acceso global por conveniencia;
- algunas pruebas antiguas dejan de representar la arquitectura vigente.

Estas consecuencias son aceptadas.

## 16. Invariantes

Las siguientes reglas no deberán romperse:

1. DeviceBus nunca será autoload.

2. DeviceBus nunca será un Node hijo.

3. DeviceBus nunca será descubierto mediante rutas.

4. Los participantes recibirán el Bus explícitamente.

5. Un Device no creará su propio Bus.

6. Cada contexto conservará su propia instancia.

7. La Composition Root controlará inicio y cierre.

8. Los participantes eliminarán sus suscripciones antes del cierre.

9. Las pruebas crearán contextos independientes.

10. Los baselines anteriores serán sustituidos, no reescritos silenciosamente.

11. DeviceBus no controlará el ciclo de vida de Devices.

12. `clear()` no sustituirá `shutdown()`.

## 17. Decisiones no incluidas

Este ADR no define:

- una clase concreta para Composition Root;
- la implementación de DeviceRuntime;
- el contrato de DeviceGraph;
- el contrato de Provider;
- el contrato de Measurement;
- el contrato canónico Topic/Message;
- el formato de telemetría;
- networking;
- persistencia;
- perfiles;
- concurrencia entre contextos.

Estas decisiones requieren sus propios diseños o ADR.

## 18. Criterios de aceptación

Una composición satisface ADR-004 si:

1. crea DeviceBus explícitamente;

2. conserva su referencia durante el contexto;

3. entrega la misma instancia a los participantes;

4. no utiliza `$DeviceBus`;

5. no utiliza un autoload;

6. no permite que Devices creen buses privados;

7. inicia productores después de entregar dependencias;

8. detiene productores antes de limpiar el Bus;

9. elimina suscripciones antes del cierre;

10. puede ejecutarse de forma independiente de otros contextos.

## 19. Regla de evolución

Si la composición comienza a repetirse o acumular responsabilidades, no se ampliará DeviceBus para resolver el problema.

Se evaluará un componente externo, como DeviceRuntime, mediante una decisión arquitectónica separada.

DeviceBus debe continuar limitado al intercambio de mensajes.

La Composition Root debe continuar limitada a crear, conectar, iniciar y cerrar el contexto.