# Hover Physics Slice 1.0 — Problema, análisis y alternativas

| Campo | Valor |
|---|---|
| Estado | ALTERNATIVA E IMPLEMENTADA Y VERIFICADA |
| Fecha | 04/10/2026 |
| Baseline | 9b677c5 — docs(propulsion): record propulsion runtime baseline |
| Target | Playable Vertical Slice 1.0 |
| Dependencia | Distance Sensor Runtime Slice 1.0 |

## 1. Punto de partida

Velocity dispone de:

```text
Distance Sensor Runtime Slice 1.0
→ DistanceMeasurement
→ distance_measurement
→ DeviceBus
```

`DistanceMeasurement` contiene:

```text
distance: float
valid: bool
timestamp: float
```

También dispone de managed runtime, source-filtered binding, perfiles, factories y sinks `BORROWED` demostrados por Propulsion Runtime Slice.

Todavía no existe:

- HoverPoint command/model;
- spring-damper policy;
- Hover RuntimeUnit;
- Hover RuntimeFactory;
- Hover Force Sink;
- hover point Profile;
- integración Distance Sensor → Hover;
- estabilidad cerrada verificada;
- adapter `RigidBody3D`;
- composición de múltiples hover points.

## 2. Problema

Hover Physics Slice 1.0 debe convertir mediciones válidas de distancia al suelo en fuerza de sustentación acotada:

```text
DistanceMeasurement
→ height error
→ separation rate
→ spring-damper policy
→ bounded lift force
→ HoverForceSink
```

Debe hacerlo sin:

- fuerza no finita o no acotada;
- usar una medición inválida;
- conservar fuerza stale indefinidamente;
- depender de SceneTree discovery;
- acoplar Core a `RigidBody3D`;
- mezclar propulsion longitudinal;
- adelantar pitch/roll controller;
- crear singleton, autoload o thread;
- activar Hardware Runtime.

## 3. Física mínima necesaria

Spring puro:

```text
F = k * (target_height - distance)
```

no basta porque:

- no disipa oscilación;
- en target exacto produce fuerza cero;
- bajo gravedad el equilibrio queda desplazado debajo del target.

Modelo recomendado:

```text
height_error = target_height - distance

distance_rate =
(current_distance - previous_distance)
/ (current_timestamp - previous_timestamp)

raw_lift =
equilibrium_force
+ stiffness * height_error
- damping * distance_rate

lift = clamp(raw_lift, 0, max_lift_force)
```

Semántica de `distance_rate`:

```text
positive → el vehículo se aleja del suelo
negative → el vehículo se acerca al suelo
```

Por tanto:

```text
-damping * distance_rate
```

reduce lift al subir y aumenta lift al caer.

## 4. Por qué existe equilibrium_force

En target y velocidad cero:

```text
height_error = 0
distance_rate = 0
```

Sin bias:

```text
lift = 0
```

Con equilibrium force:

```text
lift = equilibrium_force
```

En una nave futura, la suma de fuerzas de equilibrio de todos los hover points debe aproximar el peso que soportan.

Hover 1.0 no calcula masa o distribución de peso. Recibe ese valor explícito en el modelo por punto.

## 5. Alternativa A — RayCast y RigidBody monolíticos

```text
HoverNode
→ RayCast3D
→ calculate spring
→ RigidBody3D.apply_force
```

### Ventajas

- patrón común en prototipos;
- movimiento visible rápidamente.

### Costes

- acopla sensor, policy, body, punto y lifecycle;
- evita DeviceBus y CompositionRuntime;
- difícil de probar sin escena física;
- mezcla varias responsabilidades;
- no reutiliza Distance Sensor Runtime.

### Decisión

```text
RECHAZADA
```

## 6. Alternativa B — Spring sin damping

### Ventaja

- fórmula mínima.

### Costes

- oscilación persistente;
- estabilidad dependiente de drag accidental;
- no satisface stability policy;
- amplifica ruido y discretización.

### Decisión

```text
RECHAZADA
```

## 7. Alternativa C — Damping desde velocidad del RigidBody

```text
DistanceMeasurement
+
body vertical velocity
→ spring-damper
```

### Ventajas

- velocity directa;
- no deriva ruido de distancia.

### Costes

- exige body y frame de referencia ahora;
- añade otra dependencia física;
- adelanta Vehicle Composition;
- dificulta tests independientes.

### Decisión

```text
VÁLIDA PARA UN PROFILE SUCESOR, NO PARA HOVER 1.0
```

## 8. Alternativa D — Un controller central de múltiples puntos

```text
front_left + front_right + rear_left + rear_right
→ central hover controller
→ forces + pitch/roll balancing
```

### Ventajas

- control coordinado;
- puede corregir pitch y roll.

### Costes

- exige topología completa de nave;
- acopla número y posición de puntos;
- adelanta allocation y body geometry;
- multiplica alcance antes de probar un punto.

### Decisión

```text
DIFERIDA A PLAYABLE VEHICLE COMPOSITION
```

## 9. Alternativa E — Hover point independiente con derivative de distancia

```text
DistanceMeasurement de un Source exacto
→ HoverPointRuntimeUnit
→ HoverSpringDamperModel
→ bounded lift force
→ HoverForceSink
```

Cada hover point es un Device actuator independiente.

Múltiples points se obtienen por composición de múltiples instancias, no por arrays ocultos dentro de un singleton.

### Ventajas

- reutiliza Distance Sensor Runtime;
- una responsabilidad por Device;
- no necesita `RigidBody3D`;
- source filtering asocia sensor y point exactos;
- fórmula determinista y testeable;
- topología escalable;
- fuerza acotada;
- fallos observables;
- permite futura composición de cuatro puntos.

### Costes

- derivative sensible a timestamp/ruido;
- primer sample no tiene rate previo;
- requiere política explícita de gaps;
- todavía no aplica fuerza a un cuerpo real;
- balancing multi-point queda para otro milestone.

### Decisión recomendada

```text
SELECCIONAR ALTERNATIVA E
```

## 10. Modelo propuesto

```text
HoverSpringDamperModel
```

Parámetros inmutables:

```text
target_height_meters > 0
equilibrium_force_newtons >= 0
spring_stiffness_newtons_per_meter >= 0
damping_newton_seconds_per_meter >= 0
max_lift_force_newtons >= equilibrium_force_newtons
max_sample_interval_seconds > 0
```

API conceptual:

```text
calculate_lift_force_newtons(
    distance_meters,
    distance_rate_meters_per_second
)
```

Output:

```text
finite
0 <= lift <= max_lift_force
```

No output negativo: HoverPoint 1.0 solo empuja alejando la nave del suelo.

## 11. Primer sample

Sin medición anterior no existe derivative fiable.

Política propuesta:

```text
first valid sample
→ distance_rate = 0
→ spring + equilibrium only
```

El sample se conserva como baseline temporal para el siguiente.

## 12. Timestamp y sample gaps

Requisitos:

```text
current_timestamp > previous_timestamp
delta <= max_sample_interval_seconds
```

Si timestamp no avanza o el gap excede el máximo:

```text
no force output
Issue observable
current sample becomes new temporal baseline
```

Esto evita derivative infinito, negativo en tiempo o basado en información stale.

El siguiente sample válido puede recuperar operación.

## 13. Medición inválida

Se rechaza:

- payload no `DistanceMeasurement`;
- `valid == false`;
- distance no finita;
- distance negativa;
- timestamp no finito o negativo;
- mismatch entre payload y BusMessage timestamp.

Política:

```text
fail neutral
no sink invocation
clear previous temporal sample
Issue observable
```

Limpiar history evita calcular el siguiente derivative contra una medición anterior a la interrupción.

## 14. HoverForceSink behavior

Dependencia:

```text
hover_force_sink / BORROWED
```

Behavior:

```gdscript
apply_hover_force(
    force_newtons: float,
    timestamp: float
) -> bool
```

El RuntimeUnit entrega únicamente un escalar lift no negativo.

El sink físico futuro decide:

- dirección local de lift;
- punto de aplicación;
- frame de referencia;
- llamada `RigidBody3D.apply_force()`.

DistanceMeasurement 1.0 no contiene surface normal. Hover 1.0 no inventa una.

## 15. Profile propuesto

```text
profile_id: velocity.hover.spring_damper_point
profile_version: 1
role: ACTUATOR
capability: hover_lift_force
publishes: none
subscribes: distance_measurement
```

Factory Key:

```text
velocity.hover.spring_damper_point / 1 / Simulation
```

Dependencies:

```text
hover_model / BORROWED
hover_force_sink / BORROWED
```

## 16. RuntimeUnit propuesto

```text
HoverPointRuntimeUnit
```

Lifecycle:

```text
CREATED → INITIALIZED → READY → RUNNING → SHUTDOWN
```

Endpoint:

```text
in.distance_measurement
```

Durante `RUNNING`:

1. validar BusMessage y payload;
2. validar timestamp;
3. calcular derivative si existe sample temporal compatible;
4. calcular lift con modelo;
5. revalidar bounds;
6. invocar sink;
7. conservar result/report observable;
8. actualizar sample temporal.

Fuera de `RUNNING`:

```text
no sink invocation
```

Shutdown limpia sample history y referencias activas, preservando dependencies borrowed.

## 17. Factory propuesta

```text
HoverPointRuntimeFactory
```

Construct-only:

- Key y Configuration exactas;
- model y sink obligatorios;
- ownership `BORROWED`;
- Primary `HoverPointRuntimeUnit`;
- Host Objects vacío;
- no lifecycle;
- no force output;
- active release rechazado;
- CREATED/SHUTDOWN release permitido;
- idempotente.

## 18. Múltiples hover points

Una nave futura puede declarar:

```text
front_left_distance_sensor
→ front_left_hover_point

front_right_distance_sensor
→ front_right_hover_point

rear_left_distance_sensor
→ rear_left_hover_point

rear_right_distance_sensor
→ rear_right_hover_point
```

El binder filtra cada stream por Source ID y Topic.

Cada point mantiene únicamente su propia temporal history.

Pitch/roll balancing no vive dentro del point.

## 19. Stability policy test

Además de tests unitarios se requiere una simulación determinista 1D:

```text
mass point
+ gravity
+ fixed timestep
+ HoverSpringDamperModel
```

Debe demostrar con parámetros canónicos de test:

- valores finitos durante toda la simulación;
- fuerza siempre acotada;
- altura no cruza límites inseguros definidos por fixture;
- oscilación decreciente;
- convergencia a una banda alrededor del target;
- ausencia de crecimiento ilimitado.

Esto valida la policy matemática sin confundirla con Godot Physics o una nave final.

## 20. Full pipeline propuesto

```text
DistanceSensorRuntimeUnit de producción
→ DistanceMeasurement
→ DeviceBus
→ source-filtered connection
→ HoverPointRuntimeUnit
→ HoverSpringDamperModel
→ HoverForceSink determinista
```

Recorrido:

```text
Profiles
→ Catalog
→ SystemProfile
→ DeviceGraph
→ Factory Registry
→ CompositionPlan
→ CompositionRuntime
→ ACTIVE
→ measurement(s)
→ lift force
→ SHUTDOWN
```

Unit tests cubren timestamps deterministas y damping. La integración demuestra wiring con Distance Sensor real y primer-sample spring/equilibrium.

## 21. Seguridad

- Simulation-only;
- measurement finite y valid;
- timestamp monotónico;
- bounded sample interval;
- first sample explícito;
- invalid sample clears history;
- force finita y acotada;
- lift-only en 1.0;
- no stale force;
- sink rejection observable;
- recovery permitida;
- dependencies `BORROWED`;
- sin `RigidBody3D` en Core;
- sin singleton/autoload/service locator/thread;
- Hardware Runtime bloqueado.

## 22. Fuera de alcance

- RigidBody3D adapter;
- surface normal;
- multi-point balancing;
- pitch/roll controller;
- force allocation;
- mass distribution automation;
- active suspension;
- track geometry;
- propulsion;
- steering;
- camera;
- hardware.

## 23. Pruebas sucesoras previstas

```text
HoverSpringDamperModelTest
HoverStabilityPolicyTest
HoverPointProfileTest
HoverPointRuntimeUnitTest
HoverPointRuntimeFactoryTest
HoverPointRuntimePipelineIntegrationTest
```

Suite esperada:

```text
Hover
```

Conteos se fijan únicamente con Dashboard autoritativo.

## 24. Orden propuesto

1. HoverSpringDamperModel.
2. HoverStabilityPolicy test.
3. Builtin Hover Point Profile.
4. HoverPointRuntimeUnit.
5. HoverPointRuntimeFactory.
6. Full pipeline con Distance Sensor.
7. Hover Suite.
8. Runtime Suite.
9. Run All.
10. Refactor audit.
11. Baseline documental.

## 25. Gate de arquitectura

Decisión registrada:

```text
ALTERNATIVA E APROBADA
04/10/2026
```

Consecuencia:

1. redactar ADR-016;
2. redactar Hover Physics Slice Design 1.0;
3. revisar fórmula, nombres y políticas temporales;
4. preparar commit documental;
5. solo después comenzar implementación.


## 26. Resultado de implementación

```text
DistanceMeasurement
→ HoverPointRuntimeUnit
→ HoverSpringDamperModel
→ HoverForceSink
```

```text
Hover Suite: 7 tests / 151 checks PASS
Runtime Suite: 20 tests / 475 checks PASS
Run All: 98 tests / 2712 checks PASS
Refactor audit: PASS
```

Último commit del Slice:

```text
adca199 test(hover): add runtime pipeline integration
```
