# ADR-016 — Per-Point Hover Spring-Damper and Temporal Safety

| Campo | Valor |
|---|---|
| Estado | ACEPTADO — IMPLEMENTADO — VERIFICADO |
| Versión | 1.1 |
| Fecha | 04/10/2026 |
| Fecha de verificación | 07/10/2026 |
| Alcance | Hover Simulation por punto, spring-damper y seguridad temporal |
| Decisión previa | Hover Physics Slice Alternative E — aprobada |

## 1. Contexto

Distance Sensor Runtime Slice 1.0 publica `DistanceMeasurement` mediante:

```text
distance_measurement
```

Cada measurement contiene:

```text
distance
valid
timestamp
```

Velocity necesita transformar ese stream en una fuerza de sustentación estable y acotada sin acoplar todavía Core o RuntimeUnit a `RigidBody3D`, topología completa de nave o control central de pitch/roll.

## 2. Decisión

Hover Physics Slice 1.0 utilizará un actuator independiente por hover point:

```text
DistanceMeasurement
→ HoverPointRuntimeUnit
→ HoverSpringDamperModel
→ HoverForceSink
```

El RuntimeUnit mantendrá únicamente el sample temporal anterior de su propio stream.

El model y el sink serán dependencias explícitas `BORROWED`.

## 3. Per-point composition

Cada point es un Device independiente.

Una nave futura podrá declarar múltiples pares:

```text
Distance Sensor
→ Hover Point
```

El `ManagedRuntimeCommunicationBinder` asociará cada point con un Source ID exacto.

HoverPointRuntimeUnit no conoce:

- otros points;
- posición relativa en la nave;
- pitch;
- roll;
- center of mass;
- allocation global.

## 4. HoverSpringDamperModel

Snapshot inmutable por contrato con:

```text
target_height_meters > 0
equilibrium_force_newtons >= 0
spring_stiffness_newtons_per_meter >= 0
damping_newton_seconds_per_meter >= 0
max_lift_force_newtons >= equilibrium_force_newtons
max_sample_interval_seconds > 0
```

Fórmula:

```text
height_error = target_height - distance

raw_lift =
equilibrium_force
+ spring_stiffness * height_error
- damping * distance_rate

lift = clamp(raw_lift, 0, max_lift_force)
```

Output:

```text
finite
0 <= lift <= max_lift_force
```

## 5. Equilibrium force

La fuerza de equilibrio evita que el target produzca lift cero bajo gravedad.

En target y rate cero:

```text
lift = equilibrium_force
```

En una composición futura, la suma de equilibrium forces representa la fracción de peso soportada por los points.

Hover 1.0 no calcula automáticamente masa, gravedad o distribución de peso.

## 6. Lift-only

HoverPoint 1.0 no aplica fuerza hacia el suelo.

```text
minimum lift = 0
```

Si el cálculo spring-damper resulta negativo, se acota a cero.

Un actuator bidireccional requeriría otro Profile o versión.

## 7. Distance derivative

El damping utiliza velocidad de separación derivada:

```text
distance_rate =
(current_distance - previous_distance)
/ delta_time
```

Semántica:

- rate positivo: separación creciente;
- rate negativo: separación decreciente.

Por eso:

```text
-damping * distance_rate
```

disminuye lift al subir y aumenta lift al caer.

## 8. Primer sample

El primer sample válido no tiene derivative anterior.

Política:

```text
distance_rate = 0
```

Se calcula spring + equilibrium y se conserva el sample como baseline temporal.

## 9. Temporal safety

Para samples posteriores:

```text
current_timestamp > previous_timestamp
delta_time <= max_sample_interval_seconds
```

Timestamp no monotónico:

- no sink invocation;
- Issue observable;
- current sample reemplaza temporal baseline.

Gap excesivo:

- no sink invocation;
- Issue observable;
- current sample reemplaza temporal baseline.

El siguiente sample compatible puede recuperar operación.

## 10. Invalid measurement safety

Se rechaza:

- message no `BusMessage`;
- Topic incorrecto;
- payload no `DistanceMeasurement`;
- `valid == false`;
- distance no finita;
- distance negativa;
- timestamp no finito o negativo;
- mismatch payload/envelope timestamp.

Consecuencia:

```text
no sink invocation
clear temporal sample
last force observable = 0
Issue observable
```

No se conserva fuerza stale.

## 11. HoverForceSink

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

El RuntimeUnit valida finitud y bounds antes de invocarlo.

El sink físico futuro decide:

- dirección de lift;
- punto de aplicación;
- frame local;
- `RigidBody3D.apply_force()`.

No existe surface normal en `DistanceMeasurement` 1.0. Hover no inventa una.

## 12. Profile y Factory Key

Profile:

```text
velocity.hover.spring_damper_point
version 1
role ACTUATOR
capability hover_lift_force
publishes none
subscribes distance_measurement
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

## 13. HoverPointRuntimeUnit

Managed lifecycle:

```text
CREATED → INITIALIZED → READY → RUNNING → SHUTDOWN
```

Endpoint exacto:

```text
in.distance_measurement
```

Durante `RUNNING`:

1. validar message y measurement;
2. validar coherencia temporal;
3. calcular rate o first-sample zero rate;
4. calcular lift mediante model;
5. revalidar force;
6. invocar sink;
7. conservar actuation report;
8. actualizar temporal sample.

Fuera de `RUNNING` no invoca sink.

Shutdown limpia temporal history y Bus activo, pero no libera dependencias borrowed.

## 14. Sink failure

Si el sink devuelve `false` o un valor no booleano:

- Issue observable;
- last force observable vuelve a cero;
- Runtime permanece `RUNNING`;
- measurement temporal válido se conserva;
- un sample posterior puede recuperar.

Conservar el sample evita distorsionar el derivative por un fallo del actuator externo.

## 15. HoverPointRuntimeFactory

Construct-only.

Build:

- Request/Key/Configuration exactos;
- model y sink obligatorios;
- ownership `BORROWED`;
- Unit en `CREATED`;
- Handle sin Host Objects;
- no lifecycle;
- no force output;
- no DeviceBus almacenado.

Release:

- `CREATED` o `SHUTDOWN` permitido;
- estados activos rechazados;
- dependencies preservadas;
- idempotente.

## 16. Stability policy

La fórmula no se acepta solo por unit tests puntuales.

Debe existir una simulación determinista 1D:

```text
mass
height
vertical velocity
gravity
fixed delta
model lift
```

Con parámetros canónicos de test debe comprobar:

- estado finito en cada step;
- force acotada;
- ausencia de crecimiento ilimitado;
- oscilación decreciente;
- convergencia a una banda alrededor del target;
- límites seguros definidos por fixture.

Esta prueba valida la policy matemática, no Godot Physics.

## 17. Full pipeline integration

```text
DistanceSensorRuntimeUnit de producción
→ DistanceMeasurement
→ DeviceBus
→ source-filtered subscription
→ HoverPointRuntimeUnit
→ HoverSpringDamperModel
→ HoverForceSink determinista
```

La integración recorre:

```text
Profiles
→ Catalog
→ SystemProfile
→ DeviceGraph
→ RuntimeFactoryRegistry
→ CompositionPlan
→ CompositionRuntime
→ ACTIVE
→ measurement
→ lift
→ SHUTDOWN
```

## 18. Seguridad

- Simulation-only;
- finite measurements;
- non-negative distance;
- timestamp monotónico;
- sample gap acotado;
- first sample explícito;
- invalid sample clears history;
- force finita y acotada;
- lift-only;
- no stale force;
- sink failure observable;
- recovery permitida;
- source filtering;
- dependencies `BORROWED`;
- sin `RigidBody3D` en Core;
- sin singleton/autoload/service locator/thread;
- Hardware Runtime bloqueado.

## 19. Alternativas rechazadas o diferidas

### RayCast + RigidBody monolítico

Rechazado por mezclar sensor, policy, body y lifecycle.

### Spring sin damping

Rechazado por oscilación persistente.

### Body velocity como dependencia

Diferido a un Profile sucesor con body explícito.

### Controller central multi-point

Diferido a Playable Vehicle Composition.

## 20. Evolución

HoverPoint 1.0 permanece reusable.

Playable Vehicle Composition podrá añadir:

```text
multiple DistanceSensor/ HoverPoint pairs
RigidBodyHoverForceSink por point
hover allocation o attitude controller
```

Eso se compone alrededor del point; no se altera silenciosamente su baseline.

## 21. Fuera de alcance

- `RigidBody3D` adapter;
- surface normal;
- multi-point balancing;
- pitch/roll controller;
- mass distribution automation;
- active suspension;
- propulsion;
- steering;
- track;
- camera;
- hardware.

## 22. Criterios de aceptación

1. Model inmutable y validado.
2. equilibrium force explícita.
3. spring term correcto.
4. damping sign correcto.
5. force acotada `[0, max]`.
6. first sample policy.
7. timestamp monotónico.
8. max sample gap.
9. invalid measurement clears history.
10. sink behavior sustituible.
11. sink `BORROWED`.
12. model `BORROWED`.
13. Unit managed lifecycle.
14. endpoint exacto.
15. no output fuera de `RUNNING`.
16. failures observables y recuperables.
17. Factory construct-only.
18. Handle sin Host Objects.
19. stability simulation PASS.
20. Distance Sensor full pipeline PASS.
21. Hover Suite PASS.
22. Runtime Suite preservada.
23. Run All PASS.
24. refactor audit PASS.

## 23. Consecuencias

Positivas:

- per-point modularity;
- Distance Sensor reutilizado;
- policy testeable;
- force bounds explícitos;
- multi-point escalable;
- no body coupling prematuro.

Costes:

- derivative sensible a samples;
- tuning depende del futuro body;
- no demuestra aún pitch/roll;
- no mueve una nave real por sí solo;
- requiere sink físico posterior.

## 24. Baseline

```text
HoverSpringDamperModelTest:               31 checks
HoverStabilityPolicyTest:                 12 checks
HoverPointProfileTest:                    12 checks
HoverSampleIntervalPrecisionTest:          6 checks
HoverPointRuntimeUnitTest:                42 checks
HoverPointRuntimeFactoryTest:             25 checks
HoverPointRuntimePipelineIntegrationTest: 23 checks

Hover Suite:                      7 tests / 151 checks
Runtime Suite:                   20 tests / 475 checks
Run All:                         98 tests / 2712 checks
Failures:                        0
Timeout:                         0
Engine Error:                    0
Missing Metrics:                 0
Plan ExitCode:                   0
RESULT:                          PASS
```

Commits:

```text
2d3e940 feat(hover): add hover spring damper model
c74fff7 test(hover): add hover stability policy
a29fab5 feat(hover): add spring damper hover profile
7752657 fix(hover): tolerate sample interval precision
fd5af35 feat(hover): add hover point runtime unit
ee1e0d2 feat(hover): add hover point runtime factory
adca199 test(hover): add runtime pipeline integration
```

## 25. Estado

```text
ADR-016 1.1
ACEPTADO
IMPLEMENTADO
VERIFICADO
BASELINE REGISTRADA
```
