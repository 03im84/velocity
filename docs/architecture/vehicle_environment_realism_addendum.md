# Vehicle Composition 1.0 — Environment and Realism Addendum

| Campo | Valor |
|---|---|
| Estado | REQUISITO APROBADO DURANTE REVIEW |
| Fecha | 07/10/2026 |
| Parent | ADR-017 / Playable Vehicle Composition Design 1.0 |

## 1. Propósito

Hacer que Vehicle Composition sea reusable entre planetas, atmósferas y estilos de simulación sin reescribir Input, Propulsion, Steering, Brake o Hover.

## 2. SimulationEnvironmentProfile

Snapshot inmutable:

```text
gravity_meters_per_second_squared >= 0
atmospheric_density_kg_per_cubic_meter >= 0
```

Dirección gravity pertenece al world/scene adapter; magnitude pertenece al Profile.

Ejemplos de fixtures, no presets finales:

```text
Earth-like: rho ≈ 1.225, g ≈ 9.81
Mars-like: lower rho, lower g
Vacuum: rho = 0
```

Los tests usarán valores explícitos; no dependerán de constantes globales del proyecto.

## 3. QuadraticAxisDragModel

Modelo escalar reusable por eje:

```text
force = -0.5 * density * drag_coefficient * area * speed * abs(speed)
```

Parámetros:

```text
drag_coefficient >= 0
reference_area_square_meters >= 0
max_abs_drag_force_newtons >= 0
```

Instancias separadas permiten:

```text
longitudinal drag: bajo/moderado
lateral drag: alto para controlar side-slip
vertical drag: configurable
yaw rotational drag: model separado
```

Densidad cero produce force cero: una nave en vacío conserva drift salvo otros actuators.

## 4. Lateral stability

No se usa steering para eliminar side-slip.

```text
local lateral speed
→ QuadraticAxisDragModel
→ bounded lateral force
→ RigidBodyLateralForceSink
```

Esto permite drift controlado sin amalgamar yaw torque y aerodynamic stability.

## 5. ProximityLiftModel

Modelo aproximado, explícitamente no científico de antigravedad:

```text
normalized_proximity =
clamp(1 - distance / influence_height, 0, 1)

ground_effect_force =
max_ground_effect_force
* pow(normalized_proximity, response_exponent)
```

Parámetros:

```text
influence_height_meters > 0
max_ground_effect_force_newtons >= 0
response_exponent > 0
```

Output:

```text
finite
0 <= force <= max_ground_effect_force
```

Un `ProximityLiftPointRuntimeUnit` puede consumir el mismo DistanceMeasurement que HoverPoint y aplicar fuerza adicional mediante sink separado o compatible.

No se modifica HoverPoint 1.0.

## 6. Track implications

Proximity Lift aproximado hace físicamente relevantes:

- cambios de altura;
- crestas y valles;
- banking;
- túneles con distancia reducida;
- secciones donde se pierde proximidad;
- superficies interrumpidas;
- transiciones rápidas de clearance.

Source filtering mantiene cada ProximityLiftPoint asociado a su sensor exacto.

## 7. Sensor noise

`DistanceNoiseModel` es un snapshot inmutable y sin estado RNG:

```text
max_abs_noise_meters >= 0
quantization_step_meters >= 0
bias_meters finite
```

La fuente de noise permanece como dependencia explícita y seedable del
futuro `ConditionedDistanceProvider`:

```text
next_normalized_sample() -> float [-1,1]
```

El model recibe el sample escalar, no guarda la fuente y no utiliza RNG
global:

```text
condition_distance_meters(
    raw_distance_meters,
    normalized_noise_sample
)
```

Pipeline matemático:

```text
bounded_sample = clamp(normalized_noise_sample, -1, 1)
bounded_noise = bounded_sample * max_abs_noise_meters
conditioned = max(0, raw_distance + bias_meters + bounded_noise)
```

Si `quantization_step_meters > 0`, `conditioned` se redondea al múltiplo
más cercano del step. La cuantización ocurre después del clamp no
negativo y su resultado vuelve a validarse como finito y no negativo.

Un raw distance negativo/no finito, un sample no finito o una
configuración inválida falla neutral a `0.0`. Un sample finito fuera de
`[-1, 1]` se acota antes de escalarlo, de modo que noise nunca supera
`max_abs_noise_meters`.

Modo baseline:

```text
max_abs_noise_meters = 0
quantization_step_meters = 0
bias_meters = 0
→ output == raw_distance_meters
```

Tests usan una sequence source determinista externa y demuestran que dos
fuentes con la misma secuencia producen exactamente los mismos outputs.

## 8. Latency

Toda latencia utiliza cola acotada.

```text
BoundedLatencyBuffer
max_entries > 0
delay_seconds >= 0
monotonic timestamps
```

Ante capacity:

- no crecimiento ilimitado;
- policy explícita de rechazo/drop;
- report observable.

## 9. ConditionedDistanceProvider

Adapter stateful, scene-owned por composición, que conserva el contrato
existente de Distance Provider:

```text
get_distance()
is_valid()
```

`is_valid()` describe únicamente la lectura madura actual. La validez de
dependencias se consulta por separado:

```text
is_configuration_valid()
```

Dependencias explícitas:

```text
raw Distance Provider
DistanceNoiseModel
optional NoiseSource
bounded dedicated BoundedLatencyBuffer
```

`NoiseSource` puede ser `null` solo cuando
`max_abs_noise_meters == 0`. En ese modo no se consume estado de source.

API para coordinator:

```text
sample(capture_timestamp) -> bool
```

Pipeline:

```text
release previously matured entries
→ capture raw distance + raw validity
→ obtain explicit noise sample only for valid raw readings
→ DistanceNoiseModel
→ enqueue distance + validity snapshot
→ release entries mature at capture_timestamp
→ expose latest matured reading
→ DistanceSensorRuntimeUnit.publish_measurement
```

`sample()` devuelve `false` ante configuración/timestamp inválido,
timestamp regresivo o overflow. El pending count y capacity son
observables. La cola rechaza newest y no crece.

Invalidity también atraviesa latency. Cuando una lectura inválida madura,
`is_valid()` cambia a `false`, pero `get_distance()` conserva Last Known
Good. Una lectura válida posterior reemplaza distance y restaura validity.

Antes de encolar se liberan entries ya maduras, evitando rechazar una
captura por capacity ocupada por señales que ya vencieron. Después de
encolar se libera otra vez para que zero-delay madure en la misma llamada.
El drain usa un budget máximo igual a capacity.

`clear()` vacía la cola, reinicia la epoch monotónica y elimina current
validity/Last Known Good.

El coordinator llama `sample(timestamp)` antes de `publish_measurement()`.
`DistanceSensorRuntimeUnit`, `DistanceSensorDevice` y los providers raw no
se modifican.

## 10. Actuator latency

`DelayedScalarSinkAdapter` es una foundation genérica, sin semántica de
force/torque, configurada con:

```text
target_callable(value, application_timestamp) -> bool
BoundedLatencyBuffer
```

API:

```text
submit_scalar(value, capture_timestamp) -> bool
flush(current_timestamp) -> bool
clear()
```

Pipeline:

```text
RuntimeUnit output
→ actuator-specific wrapper
→ submit_scalar(value, command timestamp)
→ bounded latency buffer
→ coordinator flush(timestamp)
→ target Callable(value, capture timestamp + configured delay)
→ physical RigidBody sink
```

El conceptual application timestamp es independiente de la cadencia de
`flush`: siempre es `capture + delay`. `submit_scalar` acepta escalares
firmados finitos y nunca llama al target directamente, incluso con delay
cero. Zero-delay preserva baseline mediante `submit` seguido de `flush`
en el mismo physics tick.

Capture timestamps y flush timestamps son monotónicos no decrecientes.
La cola rechaza newest al alcanzar capacity. Pending count, capacity,
delay, last flush count y total applied count son observables.

`flush()` drena FIFO con budget máximo igual a capacity. Si el target
retorna `false` o un valor no booleano, el comando actual se descarta, el
flush retorna `false` y comandos posteriores permanecen pendientes. No se
reintenta un comando cuyo efecto físico es desconocido.

`clear()` vacía queue y reinicia capture/flush epochs y counters.

Wrappers específicos implementarán `apply_propulsion_force`,
`apply_hover_force`, `apply_steering_torque` o `apply_brake_force` y
delegarán a esta foundation. No forman parte de Stage 0.

Coordinator ejecuta `flush(timestamp)` una vez por physics tick.
Propulsion, Steering, Brake y Hover RuntimeUnits no cambian.

Initial Vehicle Composition debe demostrar al menos:

- configurable control/actuator delay;
- configurable distance sensor delay;
- deterministic distance noise;
- bounded pending entries;
- zero-delay/no-noise mode equivalent to baseline.

## 11. Gravity integration

VehicleCompositionRoot configura gravity explícita a través del scene/world adapter.

Hover equilibrium por point se deriva de configuración:

```text
supported_weight_share = mass * gravity / point_count
```

El valor resultante construye HoverSpringDamperModel; Hover 1.0 no se modifica.

Mass distribution no uniforme queda fuera de Initial Composition o se declara por point mediante shares explícitos.

## 12. Acceptance

- environment values finite and validated;
- atmosphere density changes drag predictably;
- vacuum removes aerodynamic drag;
- lower gravity changes required hover equilibrium;
- lateral drag reduces side-slip without steering torque;
- proximity lift bounded and distance-dependent;
- noise deterministic under explicit sequence/seed;
- latency queue bounded;
- zero-noise/zero-latency preserves accepted behavior;
- no existing Slice modified to host environment concerns.


## 13. Aerodynamic Ground Effect futuro

`ProximityLiftModel` representa acoplamiento ficticio superficie-craft y puede funcionar en vacío.

Un futuro `AerodynamicGroundEffectModel` dependerá de atmósfera, velocidad, geometría sustentadora, angle of attack y surface normal. No bloquea Vehicle Composition 1.0.
