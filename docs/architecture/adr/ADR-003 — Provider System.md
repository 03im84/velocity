# ADR-003 — Provider System

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.0 |
| Fecha | 2026-08-15 |
| Componentes | Provider, DistanceSensorDevice |
| Alcance | Producción e inyección de datos |

## 1. Contexto

Velocity necesita obtener datos desde fuentes diferentes.

Ejemplos:

- valores manuales;
- mundo físico de Godot;
- replay;
- pruebas;
- hardware futuro;
- networking;
- simulaciones externas.

Los Devices que consumen datos no deben depender directamente de una fuente concreta.

DistanceSensorDevice necesita obtener:

```text
distance
valid
```

sin conocer si los valores provienen de:

- un RayCast3D;
- un valor manual;
- una grabación;
- un dispositivo físico;
- una prueba.

El concepto utilizado para representar una fuente de datos es Provider.

## 2. Estado encontrado

La implementación anterior contenía:

```text
distance_provider.gd

distance_provider_protoype.gd

manual_distance_provider.gd

physics_distance_provider.gd
```

Dos archivos declaraban:

```gdscript
class_name DistanceProvider
```

Esto producía una clase global duplicada.

Además:

- ManualDistanceProvider esperaba variables no declaradas;
- PhysicsDistanceProvider necesitaba heredar de Node3D;
- la clase base DistanceProvider heredaba de RefCounted;
- GDScript no permite herencia múltiple;
- la clase base no podía representar todos los Providers.

## 3. Problema

Una clase base universal obligaría a elegir una única jerarquía.

Si la base hereda de RefCounted:

```text
ManualDistanceProvider
	└── DistanceProvider
			└── RefCounted
```

PhysicsDistanceProvider no puede heredar simultáneamente de Node3D.

Si la base hereda de Node:

- Providers manuales necesitan SceneTree sin utilizarlo;
- Providers de prueba se convierten en Nodes;
- herramientas externas quedan ligadas a escenas;
- se añaden capacidades innecesarias.

Velocity necesita un contrato que permita diferentes clases base sin mezclar responsabilidades.

## 4. Decisión

Provider será un rol arquitectónico.

No será una clase base universal obligatoria.

Cada familia de Provider definirá un contrato de comportamiento.

Un objeto satisface un contrato cuando expone las operaciones requeridas, independientemente de su clase base.

Para Distance Provider, el contrato será:

```gdscript
func get_distance() -> float
```

```gdscript
func is_valid() -> bool
```

Un Provider podrá heredar de:

- RefCounted;
- Node;
- Node3D;
- Resource;
- otra clase adecuada para su fuente;

siempre que respete la responsabilidad y el contrato correspondiente.

## 5. Responsabilidad de Provider

Un Provider tiene una única responsabilidad:

> Producir datos desde una fuente concreta.

Un Provider:

- obtiene o conserva datos;
- los expone mediante un contrato;
- informa si la lectura es válida;
- permanece independiente de sus consumidores.

Un Provider no:

- crea Devices;
- conoce DeviceBus;
- publica mensajes;
- construye BusMessage;
- construye telemetría;
- controla HUD;
- aplica fuerzas;
- controla lifecycle de Devices;
- conoce quién consume sus datos.

## 6. Contrato Distance Provider

El contrato inicial de Distance Provider está formado por:

```gdscript
func get_distance() -> float
```

y:

```gdscript
func is_valid() -> bool
```

### `get_distance()`

Devuelve la distancia actual en:

```text
metros
```

de acuerdo con el sistema interno de unidades de Velocity.

Cuando la lectura no sea válida puede devolver:

```text
0.0
```

El consumidor debe consultar `is_valid()` para interpretar el resultado.

### `is_valid()`

Devuelve:

```text
true
```

cuando la fuente puede producir una lectura utilizable.

Devuelve:

```text
false
```

cuando:

- la fuente no está configurada;
- no existe una superficie;
- no existe una lectura manual válida;
- el dispositivo externo no está disponible;
- la lectura no puede utilizarse.

## 7. Validación del contrato

DistanceSensorDevice validará el Provider durante su inicialización.

Comprobaciones:

```gdscript
provider.has_method(
	&"get_distance"
)
```

```gdscript
provider.has_method(
	&"is_valid"
)
```

Si falta cualquiera de los métodos:

```text
initialize_sensor() devuelve false.
```

DistanceSensorDevice no intentará corregir ni completar un Provider inválido.

No se creará todavía un componente `ProviderValidator`.

## 8. Responsabilidad de DistanceSensorDevice

DistanceSensorDevice:

1. recibe un Provider;

2. valida su contrato;

3. solicita distancia y validez;

4. construye DistanceMeasurement;

5. asigna timestamp;

6. construye BusMessage;

7. valida el envelope;

8. publica mediante DeviceBus.

Flujo:

```text
Fuente concreta
	  │
	  ▼
Distance Provider
	  │
	  │ distance + valid
	  ▼
DistanceSensorDevice
	  │
	  │ DistanceMeasurement
	  ▼
BusMessage
	  │
	  ▼
DeviceBus
```

Provider no produce DistanceMeasurement.

DistanceMeasurement continúa siendo el dato producido por el Sensor.

Provider proporciona los valores de origen.

## 9. ManualDistanceProvider

ManualDistanceProvider heredará de:

```gdscript
RefCounted
```

Tendrá estado propio:

```gdscript
var _distance: float = 0.0
var _valid: bool = false
```

API:

```gdscript
func set_distance(
	value: float
) -> void
```

```gdscript
func invalidate() -> void
```

```gdscript
func get_distance() -> float
```

```gdscript
func is_valid() -> bool
```

`set_distance()`:

- almacena el valor;
- marca la lectura como válida.

`invalidate()`:

- conserva el último valor;
- marca la lectura como inválida.

ManualDistanceProvider no necesita Node ni SceneTree.

## 10. PhysicsDistanceProvider

PhysicsDistanceProvider conservará:

```gdscript
extends Node3D
```

Necesita Node3D porque utiliza:

- posición global;
- RayCast3D;
- mundo físico;
- colisiones.

Continuará exponiendo:

```gdscript
get_distance() -> float
```

```gdscript
is_valid() -> bool
```

Si no existe RayCast3D:

```text
get_distance() devuelve 0.0

is_valid() devuelve false
```

Si no existe colisión:

```text
get_distance() devuelve 0.0

is_valid() devuelve false
```

PhysicsDistanceProvider no conocerá DeviceBus ni DistanceSensorDevice.

## 11. Propiedad y composición

La Composition Root:

- crea o localiza el Provider;
- crea o localiza DistanceSensorDevice;
- crea DeviceBus;
- entrega el Provider al Sensor;
- entrega DeviceBus al Sensor;
- controla el lifecycle cuando el Provider sea Node.

Modelo:

```text
Composition Root
	  │
	  ├──► Provider
	  ├──► DeviceBus
	  └──► DistanceSensorDevice
```

DistanceSensorDevice conserva una referencia secundaria al Provider.

DistanceSensorDevice no:

- crea el Provider;
- destruye el Provider;
- busca el Provider mediante rutas globales;
- sustituye silenciosamente la implementación.

## 12. Diversidad de clases base

El contrato no obliga a utilizar la misma clase base.

Ejemplos válidos:

```text
ManualDistanceProvider
	└── RefCounted

PhysicsDistanceProvider
	└── Node3D

DistanceSensorTestProvider
	└── RefCounted
```

Compartir un contrato no significa compartir una jerarquía.

La sustitución se logra mediante comportamiento compatible e inyección explícita.

## 13. Lectura atómica

Se evaluó introducir un contrato como:

```text
DistanceReading
```

que agrupara distancia y validez en un único objeto.

La alternativa podría reducir lecturas repetidas en Providers físicos.

Sin embargo, introduciría:

- una clase nueva;
- un contrato adicional;
- migración de pruebas aprobadas;
- mayor complejidad inmediata.

No existe todavía evidencia de una inconsistencia real entre distancia y validez.

La lectura atómica queda pospuesta.

Si aparece un problema verificable, se analizará antes de modificar el contrato.

## 14. Clases anteriores

Los archivos:

```text
distance_provider.gd

distance_provider_protoype.gd
```

no representan correctamente un contrato universal.

Serán declarados superados.

Después de crear y ejecutar pruebas sucesoras:

- se retirarán del árbol activo;
- sus UID serán retirados;
- permanecerán disponibles en Git;
- no se conservarán como backups comentados.

## 15. Alternativas descartadas

### 15.1 Clase base RefCounted

Descartada porque no puede ser heredada por PhysicsDistanceProvider junto con Node3D.

### 15.2 Clase base Node

Descartada porque obligaría a Providers puros y de prueba a depender del SceneTree.

### 15.3 Clase base Node3D

Descartada porque limitaría Providers que no tienen representación espacial.

### 15.4 Provider publica directamente al Bus

Descartada porque mezclaría adquisición de datos, medición y comunicación.

### 15.5 Provider construye DistanceMeasurement

Descartada porque Measurement es producido por el Sensor, no por la fuente.

### 15.6 ProviderRegistry inmediato

Pospuesto porque no existe necesidad de descubrir o administrar múltiples Providers dinámicamente.

### 15.7 DistanceReading inmediato

Pospuesto porque la necesidad de lectura atómica todavía no ha sido demostrada.

## 16. Pruebas

Se crearán pruebas nuevas.

### ManualDistanceProviderTest

Verificará:

- estado inicial inválido;
- distancia inicial;
- set_distance();
- lectura válida;
- invalidate();
- conservación del último valor.

### PhysicsDistanceProviderTest sucesora

Verificará:

- comportamiento sin RayCast;
- comportamiento sin colisión;
- comportamiento con superficie;
- distancia física;
- ausencia de dependencia hacia DeviceBus.

### DistanceSensorPhysicsIntegrationTest

Verificará:

```text
PhysicsDistanceProvider
		│
		▼
DistanceSensorDevice
		│
		▼
DistanceMeasurement
		│
		▼
BusMessage
		│
		▼
DeviceBus
		│
		▼
Consumer
```

### InvalidDistanceProviderTest

Verificará que un objeto sin el contrato completo sea rechazado por DistanceSensorDevice.

## 17. Sustitución de pruebas anteriores

La prueba:

```text
core/tests/physics_provider_test/
```

será sustituida por una prueba sin Node DeviceBus.

La prueba:

```text
core/tests/DistanceSensorIntegrationTest/
```

será sustituida por una prueba con Composition Root explícita y DeviceBus RefCounted.

Las pruebas anteriores no serán editadas para adaptarse.

Cuando sus sucesoras terminen correctamente:

1. se registrará la sustitución;

2. se declararán SUPERADAS;

3. se retirarán del árbol activo;

4. permanecerán en el historial de Git.

## 18. Alcance de implementación

La implementación afectará:

```text
core/device/sensors/providers/
manual_distance_provider.gd

core/device/sensors/providers/
physics_distance_provider.gd
```

Serán retirados:

```text
core/device/sensors/providers/
distance_provider.gd

core/device/sensors/providers/
distance_provider_protoype.gd
```

Se crearán pruebas dentro de:

```text
test/core/provider/
```

DistanceSensorDevice conservará su API actual.

## 19. Fuera de alcance

ADR-003 no implementará:

- ProviderRegistry;
- ProviderFactory;
- ProviderGraph;
- ProviderRuntime;
- DistanceReading;
- caching genérico;
- scheduling genérico;
- threads;
- hardware;
- networking;
- telemetría;
- replay.

## 20. Consecuencias

### 20.1 Positivas

- elimina la clase global duplicada;
- elimina herencia artificial;
- permite Providers Node y RefCounted;
- facilita dobles de prueba;
- mantiene composición sobre herencia;
- conserva independencia respecto a DeviceBus;
- permite fuentes futuras;
- evita abstracciones prematuras.

### 20.2 Negativas

- GDScript no verifica el contrato en compilación;
- la validación ocurre en runtime;
- los nombres de métodos requieren disciplina;
- cada familia debe documentar su contrato;
- no existe una interfaz universal formal;
- distance y valid se consultan por separado.

Estas consecuencias son aceptadas.

## 21. Invariantes

1. Provider es un rol, no una base obligatoria.

2. Provider produce datos.

3. Provider no publica en DeviceBus.

4. Provider no construye BusMessage.

5. Provider no conoce consumidores.

6. DistanceSensorDevice valida el contrato.

7. La Composition Root entrega el Provider.

8. Providers puros pueden ser RefCounted.

9. Providers físicos pueden ser Node3D.

10. No se fuerza una jerarquía común.

11. La distancia interna utiliza metros.

12. Un Provider inválido es rechazado.

13. Las pruebas anteriores se sustituyen antes de retirarse.

14. No se añaden registries o factories sin necesidad.

## 22. Criterios de aceptación

La implementación satisface ADR-003 si:

1. existe una sola clase global por nombre;

2. ManualDistanceProvider hereda de RefCounted;

3. ManualDistanceProvider declara su estado;

4. PhysicsDistanceProvider conserva Node3D;

5. ambos implementan get_distance();

6. ambos implementan is_valid();

7. ninguno conoce DeviceBus;

8. DistanceSensorDevice acepta ambos;

9. un objeto con contrato incompleto es rechazado;

10. las pruebas sucesoras terminan correctamente;

11. las clases base anteriores son retiradas;

12. las pruebas anteriores son retiradas después de ser sustituidas.

## 23. Regla de evolución

Una nueva fuente de datos implementará el contrato de la familia correspondiente.

No se ampliará Provider con responsabilidades de:

- comunicación;
- telemetría;
- lifecycle de Devices;
- transformación de mensajes;
- routing;
- presentación.

Si el contrato actual deja de expresar lecturas coherentes, se revisará antes de añadir parches o caches implícitos.