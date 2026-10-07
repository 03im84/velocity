# Hover Physics Slice — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO — IMPLEMENTADO — VERIFICADO |
| Versión | 1.1 |
| Fecha | 04/10/2026 |
| Fecha de baseline | 07/10/2026 |
| ADR | ADR-016 — Per-Point Hover Spring-Damper and Temporal Safety |
| Alternativa | E — Hover point independiente con derivative de distancia |
| Alcance | DistanceMeasurement hasta lift force acotada por punto |
| Implementación | COMPLETA Y VERIFICADA |

## 1. Propósito

Construir un actuator de hover por punto:

```text
DistanceMeasurement
→ spring-damper policy
→ lift force finita y acotada
→ HoverForceSink
```

El Slice prueba policy y runtime composition. No aplica todavía fuerza a un cuerpo Godot real.

## 2. Componentes previstos

```text
core/hover/hover_spring_damper_model.gd
core/profile/builtin_device_profiles.gd
integration/godot/hover/hover_point_runtime_unit.gd
integration/godot/hover/hover_point_runtime_factory.gd
```

Tests:

```text
test/core/hover/HoverSpringDamperModelTest.tscn
test/core/hover/HoverStabilityPolicyTest.tscn
test/core/hover/HoverPointProfileTest.tscn
test/core/hover/HoverPointRuntimeUnitTest.tscn
test/core/hover/HoverPointRuntimeFactoryTest.tscn
test/core/hover/HoverPointRuntimePipelineIntegrationTest.tscn
```

## 3. Flujo

```text
DistanceSensorRuntimeUnit
→ BusTopics.DISTANCE_MEASUREMENT
→ DeviceBus
→ RuntimeSourceFilteredSubscription
→ HoverPointRuntimeUnit
→ HoverSpringDamperModel
→ HoverForceSink
```

## 4. HoverSpringDamperModel

Clase:

```gdscript
class_name HoverSpringDamperModel
```

Constructor conceptual:

```gdscript
HoverSpringDamperModel.new(
    target_height_meters,
    equilibrium_force_newtons,
    spring_stiffness_newtons_per_meter,
    damping_newton_seconds_per_meter,
    max_lift_force_newtons,
    max_sample_interval_seconds
)
```

Validación:

```text
target height finite and > 0
equilibrium force finite and >= 0
stiffness finite and >= 0
damping finite and >= 0
max lift finite and >= equilibrium force
max sample interval finite and > 0
```

## 5. Model API

```gdscript
get_target_height_meters() -> float
get_equilibrium_force_newtons() -> float
get_spring_stiffness_newtons_per_meter() -> float
get_damping_newton_seconds_per_meter() -> float
get_max_lift_force_newtons() -> float
get_max_sample_interval_seconds() -> float

calculate_lift_force_newtons(
    distance_meters: float,
    distance_rate_meters_per_second: float
) -> float

is_force_within_limits(force_newtons: float) -> bool
is_sample_interval_valid(delta_seconds: float) -> bool
is_valid() -> bool
```

Invalid model o invalid calculate input retorna `0.0` fail-neutral.

## 6. Force formula

```text
height_error = target_height - distance

raw_lift =
equilibrium_force
+ spring_stiffness * height_error
- damping * distance_rate

lift = clamp(raw_lift, 0, max_lift_force)
```

El model es stateless y no contiene temporal history.

## 7. Builtin Hover Point Profile

Constructor:

```gdscript
BuiltinDeviceProfiles.create_spring_damper_hover_point()
```

Profile:

```text
profile_id: velocity.hover.spring_damper_point
profile_version: 1
display_name: Spring-Damper Hover Point
primary_role: actuator
capabilities: [hover_lift_force]
publishes: []
subscribes: [distance_measurement]
canonical: true
```

Los parámetros físicos llegan como dependency runtime, no dentro del Profile.

## 8. Effective Configuration y Key

```text
profile_id: velocity.hover.spring_damper_point
profile_version: 1
activation_context: Simulation
enabled_capabilities: [hover_lift_force]
enabled_publishes: []
enabled_subscribes: [distance_measurement]
```

Factory Key:

```text
velocity.hover.spring_damper_point / 1 / Simulation
```

## 9. Dependencies

```text
hover_model / BORROWED
hover_force_sink / BORROWED
```

Sink behavior:

```gdscript
apply_hover_force(
    force_newtons: float,
    timestamp: float
) -> bool
```

No se crea una clase abstracta por conveniencia.

## 10. HoverPointRuntimeUnit

Clase:

```gdscript
class_name HoverPointRuntimeUnit
```

Lifecycle:

```text
CREATED → INITIALIZED → READY → RUNNING → SHUTDOWN
```

Endpoint exacto:

```text
in.distance_measurement
```

El endpoint está disponible antes de initialize para permitir bind, pero solo actúa durante `RUNNING`.

## 11. Temporal state acotado

```text
_has_previous_sample: bool
_previous_distance_meters: float
_previous_timestamp: float
```

Solo existe un sample anterior. No hay cola ni history creciente.

Reset ante measurement inválido y shutdown:

```text
has_previous = false
previous values = 0
```

## 12. Message validation

```text
BusMessage type
message.is_valid()
message.topic == distance_measurement
envelope timestamp finite and >= 0
payload is DistanceMeasurement
payload.valid == true
payload.distance finite and >= 0
payload.timestamp finite and >= 0
payload.timestamp == envelope timestamp
```

Source ID se valida mediante binder source filtering.

## 13. First sample

```text
distance_rate = 0
force = model.calculate_lift_force(distance, 0)
validate force
invoke sink
store sample
```

Si sink rechaza, el sample válido se conserva.

## 14. Subsequent sample

```text
delta_time = current_timestamp - previous_timestamp
```

Caso válido:

```text
delta_time > 0
delta_time <= max_sample_interval
rate = distance_delta / delta_time
calculate, validate, sink, store current sample
```

Timestamp no monotónico:

```text
no sink
Issue hover_runtime_timestamp_non_monotonic
current sample becomes new temporal baseline
last force = 0
```

Gap excesivo:

```text
no sink
Issue hover_runtime_sample_gap_exceeded
current sample becomes new temporal baseline
last force = 0
```

El siguiente sample compatible puede recuperar.

## 15. Invalid measurement

Issue families:

```text
hover_runtime_message_invalid
hover_runtime_topic_mismatch
hover_runtime_timestamp_invalid
hover_runtime_payload_invalid
hover_runtime_measurement_invalid
hover_runtime_timestamp_mismatch
```

Consecuencia:

- no sink call;
- clear temporal sample;
- last force `0.0`;
- report observable.

## 16. Force y sink validation

Después del model:

```text
force finite
model.is_force_within_limits(force)
```

Issues:

```text
hover_runtime_force_invalid
hover_runtime_force_out_of_bounds
hover_runtime_sink_rejected
hover_runtime_sink_result_invalid
```

Sink failure conserva sample válido y permite recovery posterior.

## 17. Observable result

```text
_has_actuation_result
_last_force_newtons
_last_distance_rate_meters_per_second
_last_actuation_report
```

API:

```gdscript
has_actuation_result() -> bool
get_last_force_newtons() -> float
get_last_distance_rate_meters_per_second() -> float
get_last_actuation_report() -> ValidationReport
has_previous_sample() -> bool
```

Cada message reemplaza el report anterior.

## 18. Lifecycle details

Initialize requiere Unit válido y DeviceBus no nulo.

Ready y Start usan transiciones exactas.

Shutdown:

- idempotente;
- limpia DeviceBus;
- limpia temporal sample;
- entra en `SHUTDOWN`;
- preserva model y sink `BORROWED`.

## 19. HoverPointRuntimeFactory

Constantes:

```text
PROFILE_ID = velocity.hover.spring_damper_point
PROFILE_VERSION = 1
MODEL_DEPENDENCY_ID = hover_model
SINK_DEPENDENCY_ID = hover_force_sink
```

Build:

```text
Primary: HoverPointRuntimeUnit
Host Objects: []
Bindings: model + sink BORROWED
State: CREATED
```

No ejecuta lifecycle, bind, force o SceneTree.

Release permite `CREATED` y `SHUTDOWN`, rechaza estados activos, preserva dependencias y es idempotente.

## 20. Stability simulation fixture

Parámetros iniciales:

```text
mass = 1000 kg
gravity = 9.81 m/s²
target = 2.0 m
equilibrium force = 9810 N
spring stiffness = 20000 N/m
damping = 8000 N·s/m
max lift = 30000 N
delta = 1/120 s
duration = 10 s
initial height = 0.5 m
initial velocity = 0 m/s
```

Integración:

```text
acceleration = (lift / mass) - gravity
velocity += acceleration * delta
height += velocity * delta
```

Acceptance final se fija por observación antes de congelar thresholds:

- all finite;
- force always bounded;
- height never negative;
- peak bounded;
- final error lower than initial error;
- final state in safe target band;
- no unbounded oscillation.

## 21. Full pipeline topology

```text
distance_sensor
out.distance_measurement
→
hover_point
in.distance_measurement
```

Factories de producción:

```text
DistanceSensorRuntimeFactory
HoverPointRuntimeFactory
```

Dependencies:

```text
distance_provider / BORROWED
hover_model / BORROWED
hover_force_sink / BORROWED
```

La integración demuestra first-sample lift con Distance Sensor real. Unit tests cubren derivative y timing determinista.

## 22. Múltiples points futuros

```text
front_left_sensor  → front_left_hover_point
front_right_sensor → front_right_hover_point
rear_left_sensor   → rear_left_hover_point
rear_right_sensor  → rear_right_hover_point
```

Cada stream se filtra por Source ID y Topic.

Pitch/roll balancing permanece fuera de cada point.

## 23. Tests previstos

```text
HoverSpringDamperModelTest
HoverStabilityPolicyTest
HoverPointProfileTest
HoverPointRuntimeUnitTest
HoverPointRuntimeFactoryTest
HoverPointRuntimePipelineIntegrationTest
```

La Suite automática será `Hover`.

## 24. Orden de implementación

```text
1. HoverSpringDamperModel
2. HoverStabilityPolicyTest
3. Builtin Hover Point Profile
4. HoverPointRuntimeUnit
5. HoverPointRuntimeFactory
6. Full pipeline integration
7. Hover Suite
8. Runtime Suite
9. Run All
10. Refactor audit
11. Baseline documentation
```

## 25. Evolución hacia Vehicle Composition

```text
multiple DistanceSensor + HoverPoint pairs
→ RigidBodyHoverForceSink per point
→ optional attitude/allocation controller
→ RigidBody3D
```

HoverPoint 1.0 permanece sin conocer la nave completa.

## 26. Fuera de alcance

- RigidBody3D adapter;
- surface normals;
- central multi-point controller;
- pitch/roll balancing;
- force allocation;
- automatic mass distribution;
- propulsion integration;
- steering;
- track;
- camera;
- HUD;
- hardware.

## 27. Seguridad

- finite measurement validation;
- temporal monotonicity;
- bounded sample gap;
- first sample explícito;
- bounded lift-only output;
- no stale history after invalid data;
- sink failure observable;
- next-sample recovery;
- no unbounded history;
- explicit BORROWED ownership;
- Simulation-only;
- Hardware blocked.

## 28. Baseline de partida

```text
HEAD: 9b677c5
Propulsion Suite: 6 tests / 143 checks PASS
Runtime Suite: 20 tests / 475 checks PASS
Run All: 91 tests / 2561 checks PASS
Tooling: 126 tests PASS
```

Conteos nuevos se fijan solo mediante Dashboard autoritativo.

## 29. Baseline aceptada

```text
HoverSpringDamperModelTest:               31 checks
HoverStabilityPolicyTest:                 12 checks
HoverPointProfileTest:                    12 checks
HoverSampleIntervalPrecisionTest:          6 checks
HoverPointRuntimeUnitTest:                42 checks
HoverPointRuntimeFactoryTest:             25 checks
HoverPointRuntimePipelineIntegrationTest: 23 checks
                                               ---
Hover Suite:                      7 tests / 151 checks
Runtime Suite:                   20 tests / 475 checks
Run All:                         98 tests / 2712 checks
RESULT:                          PASS
```

Refactor audit:

```text
PASS
SIN CAMBIO OBLIGATORIO
```

Commits:

```text
aa29d80 docs(hover): define hover physics slice
2d3e940 feat(hover): add hover spring damper model
c74fff7 test(hover): add hover stability policy
a29fab5 feat(hover): add spring damper hover profile
7752657 fix(hover): tolerate sample interval precision
fd5af35 feat(hover): add hover point runtime unit
ee1e0d2 feat(hover): add hover point runtime factory
adca199 test(hover): add runtime pipeline integration
```

## 30. Estado

```text
HOVER PHYSICS SLICE 1.0
IMPLEMENTADO
VERIFICADO
BASELINE ACEPTADA
```
