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

`DistanceNoiseModel` inmutable:

```text
max_abs_noise_meters >= 0
quantization_step_meters >= 0
bias_meters finite
```

Noise source explícito y seedable:

```text
next_normalized_sample() -> float [-1,1]
```

No se utiliza RNG global.

Output conditioned:

```text
max(0, raw_distance + bias + bounded_noise)
then optional quantization
```

Tests usan sequence source determinista.

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

Adapter scene-owned que preserva behavior actual:

```text
get_distance()
is_valid()
```

API adicional explícita para coordinator:

```text
sample(timestamp)
```

Pipeline:

```text
PhysicsDistanceProvider
→ sample raw distance
→ DistanceNoiseModel
→ bounded latency buffer
→ matured conditioned value
→ DistanceSensorRuntimeUnit.publish_measurement
```

El coordinator llama `sample(timestamp)` antes de `publish_measurement()`.

## 10. Actuator latency

Sinks físicos pueden envolverse con delayed scalar adapters:

```text
RuntimeUnit output
→ bounded delayed scalar sink
→ matured force/torque
→ RigidBody sink
```

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
