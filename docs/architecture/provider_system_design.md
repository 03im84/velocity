# Provider System — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 2026-08-15 |
| ADR relacionado | ADR-003 — Provider System |
| Componentes | ManualDistanceProvider, PhysicsDistanceProvider |

## 1. Propósito

Este documento traduce ADR-003 a un diseño concreto e implementable para Provider System.

Define:

- el contrato de Distance Provider;
- la implementación manual;
- la implementación física;
- la relación con DistanceSensorDevice;
- la propiedad de los Providers;
- el orden de migración;
- las pruebas sucesoras;
- los criterios para retirar las clases anteriores.

Este documento no crea una clase base universal.

## 2. Provider como rol

Provider es un rol arquitectónico.

Un objeto es un Distance Provider cuando expone:

```gdscript
func get_distance() -> float
```

y:

```gdscript
func is_valid() -> bool
```

La clase base concreta del objeto no forma parte del contrato.

Son implementaciones válidas:

```text
RefCounted

Node

Node3D

Resource
```

siempre que cumplan:

- el contrato requerido;
- la responsabilidad de producir datos;
- los invariantes de su implementación.

## 3. Contrato Distance Provider

### 3.1 `get_distance()`

Firma:

```gdscript
func get_distance() -> float
```

Devuelve la distancia actual en:

```text
metros
```

Cuando la lectura no sea utilizable podrá devolver:

```text
0.0
```

El valor no debe interpretarse sin consultar `is_valid()`.

### 3.2 `is_valid()`

Firma:

```gdscript
func is_valid() -> bool
```

Devuelve `true` cuando la lectura actual puede utilizarse.

Devuelve `false` cuando:

- la fuente no está configurada;
- no existe una lectura;
- no existe una superficie;
- el componente físico no está disponible;
- el valor debe ser ignorado.

### 3.3 Responsabilidad del contrato

El contrato solo responde:

```text
¿Qué distancia produce esta fuente?

¿Es utilizable la lectura actual?
```

No responde:

- qué Device consume el dato;
- qué topic se utiliza;
- cuándo se publica;
- cómo se construye DistanceMeasurement;
- cómo se serializa;
- cómo se representa en pantalla.

## 4. ManualDistanceProvider

Archivo:

```text
core/device/sensors/providers/
manual_distance_provider.gd
```

Forma prevista:

```gdscript
extends RefCounted
class_name ManualDistanceProvider
```

### 4.1 Estado interno

```gdscript
var _distance: float = 0.0
var _valid: bool = false
```

El estado pertenece a ManualDistanceProvider.

No pertenece a una clase base.

### 4.2 API pública

```gdscript
func set_distance(
	value: float
) -> void
```

Comportamiento:

```text
_distance = value
_valid = true
```

```gdscript
func invalidate() -> void
```

Comportamiento:

```text
_valid = false
```

`invalidate()` no borra la última distancia.

```gdscript
func get_distance() -> float
```

Devuelve:

```text
_distance
```

```gdscript
func is_valid() -> bool
```

Devuelve:

```text
_valid
```

### 4.3 Límites

ManualDistanceProvider no:

- utiliza Node;
- participa en SceneTree;
- conoce DistanceSensorDevice;
- conoce DeviceBus;
- construye DistanceMeasurement;
- construye BusMessage;
- imprime información;
- registra telemetría.

## 5. PhysicsDistanceProvider

Archivo:

```text
core/device/sensors/providers/
physics_distance_provider.gd
```

Forma:

```gdscript
extends Node3D
class_name PhysicsDistanceProvider
```

### 5.1 Dependencia física

```gdscript
@export var ray_cast: RayCast3D
```

PhysicsDistanceProvider necesita Node3D porque utiliza:

- posición global;
- RayCast3D;
- colisiones del mundo;
- actualización física.

### 5.2 `get_distance()`

Comportamiento previsto:

```text
Si ray_cast es null:
	devolver 0.0.

Actualizar RayCast.

Si no existe colisión:
	devolver 0.0.

Si existe colisión:
	calcular distancia entre la posición
	del RayCast y el punto de colisión.
```

La unidad será:

```text
metros
```

### 5.3 `is_valid()`

Comportamiento previsto:

```text
Si ray_cast es null:
	devolver false.

Actualizar RayCast.

Devolver ray_cast.is_colliding().
```

### 5.4 Límites

PhysicsDistanceProvider no:

- crea RayCast3D;
- busca el RayCast por ruta global;
- conoce DistanceSensorDevice;
- conoce DeviceBus;
- publica mensajes;
- construye Measurements;
- aplica fuerzas;
- controla la superficie detectada.

La Composition Root o la escena configura `ray_cast`.

## 6. DistanceSensorDevice

DistanceSensorDevice continuará recibiendo:

```gdscript
provider: Object
```

durante:

```gdscript
initialize_sensor()
```

La validación será:

```gdscript
if not provider.has_method(
	&"get_distance"
):
	return false
```

```gdscript
if not provider.has_method(
	&"is_valid"
):
	return false
```

Después de validar:

```text
distance_provider = provider
```

DistanceSensorDevice no necesita conocer la clase concreta.

### 6.1 Dependencias obligatorias

DistanceSensorDevice requiere:

```text
DeviceBus válido

Provider no nulo
```

La validación debe ocurrir antes de llamar métodos del Provider.

Orden previsto:

```gdscript
if device != null:
	return false

if bus == null:
	return false

if provider == null:
	return false

if not provider.has_method(
	&"get_distance"
):
	return false

if not provider.has_method(
	&"is_valid"
):
	return false
```

Si falta alguna dependencia:

```text
initialize_sensor() devuelve false.

No se crea el Device interno.

No se conserva una referencia parcial.
```

DistanceSensorDevice no intentará crear reemplazos para dependencias nulas.

### 6.2 Producción de Measurement

Durante `publish_measurement()`:

```text
1. Solicitar get_distance().

2. Solicitar is_valid().

3. Crear DistanceMeasurement.

4. Asignar timestamp.

5. Crear BusMessage.

6. Validar BusMessage.

7. Publicar mediante DeviceBus.
```

Provider entrega valores de origen.

DistanceSensorDevice produce Measurement.

## 7. Propiedad y composición

La Composition Root será responsable de:

- crear o localizar el Provider;
- configurar dependencias físicas;
- crear o localizar DistanceSensorDevice;
- crear DeviceBus;
- entregar Provider y Bus al Sensor;
- iniciar el contexto;
- coordinar el cierre.

Modelo:

```text
Composition Root
	  │
	  ├──► Provider
	  ├──► DeviceBus
	  └──► DistanceSensorDevice
```

DistanceSensorDevice conserva una referencia secundaria al Provider.

No controla su ciclo de vida.

## 8. Clases base anteriores

Los archivos:

```text
distance_provider.gd

distance_provider_protoype.gd
```

no formarán parte del diseño final.

### `distance_provider.gd`

Su herencia RefCounted no puede representar PhysicsDistanceProvider.

### `distance_provider_protoype.gd`

Duplica:

```gdscript
class_name DistanceProvider
```

y conserva código experimental incompleto.

Ninguno será convertido en una interfaz simulada.

Después de completar la migración:

- ambos serán retirados;
- sus UID serán retirados;
- permanecerán disponibles en Git.

## 9. Invariantes de diseño

1. Provider es un rol.

2. No existe clase base universal obligatoria.

3. Distance Provider expone `get_distance()`.

4. Distance Provider expone `is_valid()`.

5. La distancia utiliza metros.

6. Provider no conoce DeviceBus.

7. Provider no construye BusMessage.

8. Provider no construye DistanceMeasurement.

9. DistanceSensorDevice valida el contrato.

10. La Composition Root entrega el Provider.

11. ManualDistanceProvider conserva estado propio.

12. PhysicsDistanceProvider conserva Node3D.

13. Las fuentes pueden sustituirse sin modificar DistanceSensorDevice.

14. No se introduce DistanceReading en esta versión.

15. DistanceSensorDevice rechaza DeviceBus nulo.

16. DistanceSensorDevice rechaza Provider nulo.

17. Una inicialización fallida no crea el Device interno.

## 10. Estrategia de pruebas

Provider System utilizará pruebas nuevas.

No se modificarán las pruebas anteriores para adaptarlas a la arquitectura nueva.

Las pruebas se dividirán en:

```text
Prueba unitaria de ManualDistanceProvider

Prueba de contrato inválido

Prueba física de PhysicsDistanceProvider

Prueba de integración física completa
```

Cada prueba tendrá una responsabilidad independiente.

## 11. ManualDistanceProviderTest

Se creará:

```text
test/core/provider/
ManualDistanceProviderTest.tscn

test/core/provider/
manual_distance_provider_test.gd
```

### MDP-U01 — Estado inicial

Debe verificar:

```text
get_distance() devuelve 0.0.

is_valid() devuelve false.
```

### MDP-U02 — Establecer distancia

Después de:

```gdscript
provider.set_distance(
	12.5
)
```

debe verificar:

```text
get_distance() devuelve 12.5.

is_valid() devuelve true.
```

### MDP-U03 — Invalidar lectura

Después de:

```gdscript
provider.invalidate()
```

debe verificar:

```text
is_valid() devuelve false.

get_distance() continúa devolviendo 12.5.
```

La invalidación no elimina el último valor.

## 12. InvalidDistanceProviderTest

Se creará:

```text
test/core/provider/
InvalidDistanceProviderTest.tscn

test/core/provider/
invalid_distance_provider_test.gd
```

La prueba utilizará cinco configuraciones inválidas.

### 12.1 Provider nulo

Con:

```text
DeviceBus válido

Provider nulo
```

debe verificar:

```text
initialize_sensor() devuelve false.

No se crea el Device interno.
```

### 12.2 DeviceBus nulo

Con:

```text
DeviceBus nulo

Provider válido de prueba
```

debe verificar:

```text
initialize_sensor() devuelve false.

No se crea el Device interno.
```

### 12.3 Provider sin contrato

Existe una instancia, pero no implementa:

```text
get_distance()

is_valid()
```

Debe verificar:

```text
initialize_sensor() devuelve false.

No se crea el Device interno.
```

### 12.4 Provider con contrato incompleto: solo `get_distance()`

El Provider implementa:

```gdscript
get_distance()
```

pero no implementa:

```gdscript
is_valid()
```

Debe verificar:

```text
initialize_sensor() devuelve false.

No se crea el Device interno.
```

### 12.5 Provider con contrato incompleto: solo `is_valid()`

El Provider implementa:

```gdscript
is_valid()
```

pero no implementa:

```gdscript
get_distance()
```

Debe verificar:

```text
initialize_sensor() devuelve false.

No se crea el Device interno.
```

Estas pruebas garantizan que no se construya un Sensor parcialmente configurado.

## 13. PhysicsDistanceProviderTest sucesora

Se creará:

```text
test/core/provider/
PhysicsDistanceProviderTest.tscn

test/core/provider/
physics_distance_provider_test.gd
```

La escena contendrá:

```text
PhysicsDistanceProviderTest
│
├── PhysicsDistanceProvider
│   └── RayCast3D
│
└── Ground
	├── MeshInstance3D
	└── CollisionShape3D
```

No contendrá:

```text
DeviceBus
DistanceSensorDevice
BusMessage
```

### PDP-I01 — Provider sin RayCast

Una instancia sin `ray_cast` debe verificar:

```text
is_valid() devuelve false.

get_distance() devuelve 0.0.
```

### PDP-I02 — RayCast sin colisión

Con un RayCast configurado sin capas de colisión:

```text
is_valid() devuelve false.

get_distance() devuelve 0.0.
```

### PDP-I03 — Superficie válida

Al habilitar la capa correspondiente y actualizar física:

```text
is_valid() devuelve true.

get_distance() devuelve una distancia
coherente con la geometría.
```

La comparación física utilizará un rango o tolerancia.

No dependerá de igualdad exacta de punto flotante.

### PDP-I04 — Independencia

La escena no necesita DeviceBus.

Esto demuestra que PhysicsDistanceProvider solo produce datos.

## 14. DistanceSensorPhysicsIntegrationTest

Se creará:

```text
test/core/provider/
DistanceSensorPhysicsIntegrationTest.tscn

test/core/provider/
distance_sensor_physics_integration_test.gd
```

La escena contendrá:

```text
DistanceSensorPhysicsIntegrationTest
│
├── DistanceSensor
│
├── PhysicsDistanceProvider
│   └── RayCast3D
│
└── Ground
	├── MeshInstance3D
	└── CollisionShape3D
```

DeviceBus será una variable RefCounted conservada por el script raíz.

No será un Node hijo.

### Flujo

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
Consumer de prueba
```

### DSP-I01 — Composición

Debe verificar:

```text
La Composition Root crea DeviceBus.

DistanceSensorDevice recibe DeviceBus.

DistanceSensorDevice recibe PhysicsDistanceProvider.

initialize_sensor() devuelve true.
```

### DSP-I02 — Medición física

Debe verificar:

```text
PhysicsDistanceProvider es válido.

La distancia corresponde a la geometría.

DistanceSensorDevice publica un mensaje.
```

### DSP-I03 — Contratos

Debe verificar:

```text
El topic es DISTANCE_MEASUREMENT.

El mensaje es BusMessage.

El payload es DistanceMeasurement.

DistanceMeasurement.valid es true.

DistanceMeasurement.distance coincide
con el Provider.

El source ID coincide con el Sensor.
```

### DSP-I04 — Independencia

Debe verificar que:

```text
PhysicsDistanceProvider no conoce DeviceBus.

DeviceBus no conoce PhysicsDistanceProvider.
```

Esta independencia se confirma por composición y revisión de dependencias.

## 15. Orden de migración

La implementación seguirá este orden:

```text
1. Buscar referencias a distance_provider_protoype.gd.

2. Retirar distance_provider_protoype.gd
   y su UID si no existen referencias.

3. Migrar ManualDistanceProvider para heredar
   directamente de RefCounted.

4. Declarar su estado interno.

5. Ejecutar ManualDistanceProviderTest.

6. Ejecutar InvalidDistanceProviderTest.

7. Ejecutar PhysicsDistanceProviderTest sucesora.

8. Ejecutar DistanceSensorPhysicsIntegrationTest.

9. Buscar referencias a distance_provider.gd.

10. Retirar distance_provider.gd y su UID
	si no existen referencias.

11. Declarar las pruebas físicas anteriores
	como SUPERADAS.

12. Retirar las pruebas anteriores.

13. Ejecutar la regresión completa.

14. Registrar resultados.
```

No se eliminarán ambos archivos anteriores antes de comprobar sus referencias.

El archivo prototype se retira primero porque genera una clase global duplicada.

La clase base restante se conserva temporalmente hasta que ManualDistanceProvider deje de heredar de ella.

## 16. Auditoría de referencias

Antes de retirar archivos se buscarán:

```text
distance_provider_protoype.gd

distance_provider.gd

DistanceProvider
```

La búsqueda incluirá:

```text
*.gd

*.tscn

*.tres

project.godot
```

Las referencias encontradas en documentación histórica no bloquean la eliminación.

Las referencias activas en código o escenas deben resolverse primero.

## 17. Implementación de ManualDistanceProvider

La forma final será:

```gdscript
extends RefCounted
class_name ManualDistanceProvider
```

Estado:

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

No conservará:

```text
extends DistanceProvider

variables públicas distance y valid

dependencias hacia DeviceBus
```

## 18. Implementación de PhysicsDistanceProvider

PhysicsDistanceProvider conservará su API actual si las pruebas demuestran que satisface el diseño.

Forma:

```gdscript
extends Node3D
class_name PhysicsDistanceProvider
```

No se modificará únicamente para que el archivo parezca nuevo.

Solo se cambiará código si una prueba revela una diferencia frente al contrato aprobado.

## 19. Política de errores

Los Providers no imprimirán errores por una lectura inválida.

Representarán el estado mediante:

```gdscript
is_valid() == false
```

y un valor seguro:

```gdscript
get_distance() == 0.0
```

cuando no exista lectura.

La observabilidad futura se implementará fuera del Provider.

## 20. Pruebas anteriores

Después de aprobar las sucesoras:

```text
core/tests/physics_provider_test/
```

será declarada:

```text
SUPERADA
```

por:

```text
test/core/provider/
PhysicsDistanceProviderTest
```

Y:

```text
core/tests/DistanceSensorIntegrationTest/
```

será declarada:

```text
SUPERADA
```

por:

```text
test/core/provider/
DistanceSensorPhysicsIntegrationTest
```

Las pruebas anteriores se retirarán del árbol activo.

Permanecerán disponibles en Git.

## 21. Criterios de aceptación

Provider System satisface el diseño cuando:

1. no existe una clase global duplicada;

2. ManualDistanceProvider hereda de RefCounted;

3. ManualDistanceProvider declara `_distance`;

4. ManualDistanceProvider declara `_valid`;

5. ManualDistanceProvider supera su prueba;

6. un Provider incompleto es rechazado;

7. PhysicsDistanceProvider conserva Node3D;

8. PhysicsDistanceProvider supera su prueba física;

9. la integración física completa termina correctamente;

10. Provider no conoce DeviceBus;

11. DistanceSensorDevice acepta Providers diferentes;

12. `distance_provider_protoype.gd` es retirado;

13. `distance_provider.gd` es retirado;

14. las pruebas anteriores tienen sucesoras;

15. la regresión completa termina correctamente;

16. DeviceBus nulo es rechazado durante `initialize_sensor()`;

17. Provider nulo es rechazado durante `initialize_sensor()`;

18. una dependencia inválida no deja estado parcial.

## 22. Fuera de alcance

Esta implementación no añadirá:

- DistanceReading;
- ProviderRegistry;
- ProviderFactory;
- ProviderRuntime;
- caching;
- scheduling;
- telemetría;
- hardware;
- networking;
- threads.

## 23. Resumen de migración

```text
DistanceProvider base:
Retirada

DistanceProvider prototype:
Retirado

Provider:
Rol por comportamiento

Contrato:
get_distance()
is_valid()

ManualDistanceProvider:
RefCounted con estado propio

PhysicsDistanceProvider:
Node3D

DistanceSensorDevice:
Valida métodos y dependencias obligatorias

DeviceBus:
Sin cambios

Pruebas anteriores:
Sustituidas antes de retirarse
```