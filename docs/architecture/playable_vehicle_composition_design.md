# Playable Vehicle Composition — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 07/10/2026 |
| ADR | ADR-017 — Scene-Owned Vehicle Body and Staged Physical Composition |
| Alcance | Routing, steering, active braking, body adapters y vehicle runtime root |
| Implementación | AUTORIZADA DESPUÉS DEL COMMIT DOCUMENTAL |

## 1. Propósito

Componer Input, Propulsion, Distance Sensors y Hover alrededor de un `RigidBody3D` scene-owned para producir la primera nave físicamente controlable.

## 2. Stages

```text
Stage 0 — Environment, aerodynamics, proximity lift and signal conditioning
Stage 1 — Commands and pure models
Stage 2 — VehicleControlRouter Runtime
Stage 3 — Steering Runtime
Stage 4 — Active Braking Runtime
Stage 5 — RigidBody adapters
Stage 6 — VehiclePhysicsCoordinator
Stage 7 — VehicleCompositionRoot and scene
Stage 8 — Full physical integration
```

## 3. Nuevos Topics

```gdscript
BusTopics.STEERING_COMMAND = &"steering_command"
BusTopics.BRAKE_COMMAND = &"brake_command"
```

No se reutilizan Topics con semántica diferente.

## 4. SteeringCommand

```text
normalized_yaw: float [-1, 1]
timestamp: float >= 0
```

Snapshot read-only, finite y sin física.

## 5. BrakeCommand

```text
normalized_brake: float [0, 1]
timestamp: float >= 0
```

Snapshot read-only, finite y sin body.

## 6. PropulsionIntentPolicy

Clase pura/stateless:

```gdscript
calculate_normalized_thrust(
    throttle: float,
    brake: float
) -> float
```

Fórmula:

```text
clamp(throttle, -1, 1) * (1 - clamp(brake, 0, 1))
```

Invalid input falla neutral.

No publica ni conoce DeviceBus.

## 7. VehicleControlRouter Profile

```text
profile_id: velocity.vehicle_control.router
version: 1
role: LOCAL_CONTROLLER
capability: vehicle_control_routing
publishes:
- propulsion_command
- steering_command
- brake_command
subscribes:
- vehicle_control_command
```

Dependency:

```text
propulsion_intent_policy / BORROWED
```

## 8. VehicleControlRouterRuntimeUnit

Endpoint:

```text
in.vehicle_control_command
```

Durante `RUNNING`:

1. valida BusMessage y VehicleControlCommand;
2. calcula effective thrust mediante policy;
3. crea PropulsionCommand;
4. crea SteeringCommand;
5. crea BrakeCommand;
6. publica los tres con mismo timestamp y source router;
7. conserva routing report observable.

Publicación usa DeviceBus owned por CompositionRuntime.

No aplica fuerza o torque.

## 9. Router Factory

```text
velocity.vehicle_control.router / 1 / Simulation
```

Construct-only, sin Host Objects, policy BORROWED, release `CREATED/SHUTDOWN` e idempotente.

## 10. YawSteeringModel

Parámetros:

```text
max_yaw_torque_newton_meters >= 0
yaw_damping_newton_meter_seconds >= 0
max_abs_yaw_rate_radians_per_second > 0
```

Input:

```text
normalized_yaw
yaw_rate
```

Policy:

- invalid input fail-neutral;
- damping siempre se opone a yaw rate;
- command que aumenta un yaw rate ya en límite se suprime;
- output clamp `[-max_torque, max_torque]`.

## 11. YawMotionSource behavior

```gdscript
get_yaw_rate_radians_per_second() -> float
```

Dependency `BORROWED`.

## 12. SteeringTorqueSink behavior

```gdscript
apply_yaw_torque(
    torque_newton_meters: float,
    timestamp: float
) -> bool
```

Dependency `BORROWED`.

## 13. Steering Profile y Runtime

```text
profile_id: velocity.steering.yaw
role: ACTUATOR
capability: bounded_yaw_torque
publishes: none
subscribes: steering_command
```

Dependencies:

```text
steering_model / BORROWED
yaw_motion_source / BORROWED
steering_torque_sink / BORROWED
```

Runtime valida, obtiene yaw rate, calcula torque, revalida bounds, invoca sink y conserva report.

## 14. Steering Factory

```text
velocity.steering.yaw / 1 / Simulation
```

Sin Host Objects; active release rechazado.

## 15. LongitudinalBrakeModel

Parámetros:

```text
max_brake_force_newtons >= 0
speed_deadzone_meters_per_second >= 0
```

Input:

```text
normalized_brake
signed longitudinal speed
```

Fórmula:

```text
if abs(speed) <= deadzone:
    force = 0
else:
    force = -sign(speed) * normalized_brake * max_force
```

Output clamp `[-max_force, max_force]`.

## 16. LongitudinalMotionSource behavior

```gdscript
get_longitudinal_speed_meters_per_second() -> float
```

Dependency `BORROWED`.

## 17. BrakeForceSink behavior

```gdscript
apply_brake_force(
    force_newtons: float,
    timestamp: float
) -> bool
```

Dependency `BORROWED`.

## 18. Brake Profile y Runtime

```text
profile_id: velocity.brake.longitudinal
role: ACTUATOR
capability: active_longitudinal_braking
publishes: none
subscribes: brake_command
```

Dependencies:

```text
brake_model / BORROWED
longitudinal_motion_source / BORROWED
brake_force_sink / BORROWED
```

Runtime nunca aplica force que acelere alejándose de reposo.

## 19. Brake Factory

```text
velocity.brake.longitudinal / 1 / Simulation
```

Construct-only, sin Hosts, release seguro/idempotente.

## 20. RigidBodyVehicleMotionSource

Adapter scene-owned `RefCounted` con body explícito.

```text
longitudinal speed = linear_velocity dot world_forward
yaw rate = angular_velocity dot world_up
```

Valida body y vectors finite.

No modifica el body.

También produce:

```text
VehicleMotionState
```

Snapshot read-only:

```text
local surge/sway/heave velocity
local surge/sway/heave acceleration
roll/pitch/yaw angular velocity
roll/pitch/yaw orientation
timestamp >= 0
```

Acceleration se deriva con timestamp monotónico y history de un sample, sin colas no acotadas.

Vehicle Composition no publica todavía hardware commands. El snapshot es un seam observable para telemetry, replay, camera y un futuro Motion Platform Runtime Slice.

## 21. RigidBodyPropulsionForceSink

```text
world_forward = -body.global_basis.z.normalized()
force_vector = world_forward * force_newtons
body.apply_central_force(force_vector)
```

Valida timestamp, force, body y basis.

## 22. RigidBodySteeringTorqueSink

```text
world_up = body.global_basis.y.normalized()
torque_vector = world_up * torque_newton_meters
body.apply_torque(torque_vector)
```

## 23. RigidBodyBrakeForceSink

Recibe force escalar firmado desde BrakeRuntime:

```text
world_forward = -body.global_basis.z.normalized()
body.apply_central_force(world_forward * force_newtons)
```

Model garantiza oposición a signed longitudinal speed.

## 24. RigidBodyHoverForceSink

Dependencias:

```text
body
application Marker3D
```

```text
world_up = body.global_basis.y.normalized()
offset = marker.global_position - body.global_position
body.apply_force(world_up * lift_force, offset)
```

Un sink por hover point.

## 25. VehiclePhysicsCoordinator

Node scene-owned con referencias explícitas a cuatro `DistanceSensorRuntimeUnit`.

Lifecycle propio:

```text
disabled
configured
running
disabled after shutdown
```

`_physics_process` publica exactamente una measurement por Unit mientras running.

No descubre Handles o Units mediante SceneTree.

## 26. VehicleCompositionRoot

Node3D scene-owned.

Responsabilidades:

- validar scene nodes;
- construir Profiles/Configurations/System;
- construir Factory Registry;
- construir models/providers/sinks;
- activar CompositionRuntime;
- resolver Handles exactos;
- configurar coordinator;
- controlar freeze/unfreeze;
- shutdown/reset;
- exponer operation result.

No calcula fuerzas, routing o models.

## 27. Scene

```text
VehicleCompositionRoot
├── RuntimeHost
└── CraftBody (RigidBody3D)
    ├── CollisionShape3D
    ├── FrontLeftPoint
    │   └── RayCast3D
    ├── FrontRightPoint
    │   └── RayCast3D
    ├── RearLeftPoint
    │   └── RayCast3D
    └── RearRightPoint
        └── RayCast3D
```

Initial Profile uses four points.

## 28. Composition graph

Devices:

```text
player_input
vehicle_control_router
propulsion_actuator
steering_actuator
brake_actuator
4 distance_sensors
4 hover_points
```

Connections:

```text
input → router
router → propulsion
router → steering
router → brake
sensor[i] → hover[i]
```

Total initial devices:

```text
12
```

Total connections:

```text
8
```

## 29. Dependencies

```text
input_intent_provider
propulsion_intent_policy
propulsion_model
propulsion_force_sink
steering_model
yaw_motion_source
steering_torque_sink
brake_model
longitudinal_motion_source
brake_force_sink
4 distance_providers
4 hover_models
4 hover_force_sinks
```

Todos scoped por Device ID y activation.

## 30. Safe activation

State del root:

```text
CREATED
ACTIVATING
ACTIVE
SHUTTING_DOWN
SHUTDOWN
FAILED
```

Activation solo desde CREATED.

Body frozen y coordinator disabled hasta Runtime ACTIVE y Handles validados.

Failure termina FAILED con body frozen.

## 31. Safe shutdown

Solo desde ACTIVE:

1. disable coordinator;
2. freeze body;
3. CompositionRuntime.shutdown;
4. zero velocities;
5. clear runtime references;
6. SHUTDOWN si report permite Simulation, de otro modo FAILED.

## 32. Reset

Solo en CREATED, SHUTDOWN o FAILED con body frozen.

Restaura spawn transform y velocidades cero.

No reactiva un CompositionRuntime terminal; se crea nueva root/runtime para nueva sesión si es necesario.

## 33. SimulationEnvironmentProfile

Snapshot reusable:

```text
gravity_meters_per_second_squared >= 0
atmospheric_density_kg_per_cubic_meter >= 0
```

Environment no vive en globals. Vehicle root construye models/sinks desde este Profile.

Hover equilibrium nominal por point deriva de mass, gravity y explicit weight shares.

## 34. Aerodynamic and lateral stability

`QuadraticAxisDragModel` reusable:

```text
force = -0.5 * density * coefficient * area * speed * abs(speed)
```

Instancias separadas para longitudinal, lateral y vertical axes.

Lateral drag alto produce drift controlado sin mezclarse con Steering torque.

`RigidBodyAerodynamicController` scene-owned aplica fuerzas una vez por physics tick mediante models acotados.

## 35. Proximity Lift

```text
DistanceMeasurement
→ ProximityLiftPointRuntimeUnit
→ ProximityLiftModel
→ bounded additional lift
→ point sink
```

Curve conceptual:

```text
proximity = clamp(1 - distance / influence_height, 0, 1)
force = max_force * pow(proximity, exponent)
```

Un actuator por point. HoverPoint 1.0 permanece intacto.

## 36. Noise and bounded latency

`DistanceNoiseModel` es un transform puro e inmutable configurado con
bias, maximum absolute noise y quantization step. Recibe un normalized
sample explícito por llamada; no posee ni consulta RNG global.

```text
NoiseSource.next_normalized_sample()
→ DistanceNoiseModel.condition_distance_meters(raw, sample)
→ finite non-negative conditioned distance
```

El sample se acota a `[-1, 1]`; después se aplica bias, noise acotado,
clamp no negativo y cuantización opcional al múltiplo más cercano. La
configuración cero preserva exactamente raw distance.

`ConditionedDistanceProvider` poseerá la fuente determinista/seedable y
envuelve PhysicsDistanceProvider:

```text
sample(timestamp)
→ noise/quantization
→ BoundedLatencyBuffer
→ matured get_distance/is_valid
```

Delayed sink adapters proporcionan actuator latency y se vacían mediante `flush(timestamp)` del coordinator.

Toda queue tiene capacity fija, monotonic timestamps y overflow report observable.

Zero-noise/zero-latency mode debe preservar baselines aceptadas.

## 37. Physics configuration

Body parameters serán explícitos en scene/design:

- mass;
- gravity scale;
- linear damping;
- angular damping;
- continuous collision mode si se requiere;
- axis locks solo si están justificadas.

No se ocultan como constantes dentro de sinks.

## 38. Test progression

### Stage 0

```text
SimulationEnvironmentProfileTest
QuadraticAxisDragModelTest
ProximityLiftModelTest
ProximityLiftPointRuntimeUnitTest
ProximityLiftPointRuntimeFactoryTest
DistanceNoiseModelTest
BoundedLatencyBufferTest
ConditionedDistanceProviderTest
DelayedScalarSinkTest
```

### Stage 1

```text
SteeringCommandTest
BrakeCommandTest
PropulsionIntentPolicyTest
```

### Stage 2

```text
YawSteeringModelTest
LongitudinalBrakeModelTest
```

### Stage 3

```text
VehicleControlRouterRuntimeUnitTest
VehicleControlRouterRuntimeFactoryTest
```

### Stage 4

```text
SteeringRuntimeUnitTest
SteeringRuntimeFactoryTest
BrakeRuntimeUnitTest
BrakeRuntimeFactoryTest
```

### Stage 5

```text
VehicleMotionStateTest
RigidBodyVehicleMotionSourceTest
RigidBodyPropulsionForceSinkTest
RigidBodySteeringTorqueSinkTest
RigidBodyBrakeForceSinkTest
RigidBodyHoverForceSinkTest
```

### Stage 6

```text
VehiclePhysicsCoordinatorTest
VehicleCompositionRootTest
```

### Stage 7

```text
PlayableVehiclePhysicsIntegrationTest
```

## 39. Physical integration acceptance

- compile/activation PASS;
- 12 Devices y 8 Connections;
- body frozen until ACTIVE;
- gravity and atmospheric density come from Environment Profile;
- atmosphere density changes drag predictably;
- vacuum produces zero aerodynamic drag;
- deterministic sensor noise and bounded latency active;
- proximity lift changes lift predictably with clearance;
- four rays/sensors/hover points active;
- all transforms/velocities finite;
- safe hover band;
- forward displacement under throttle;
- propulsion command attenuated by brake;
- active brake reduces signed speed;
- brake force zero in deadzone;
- hover lift unaffected by brake command;
- bounded yaw response;
- shutdown freezes body and zeros velocities;
- no post-shutdown forces;
- scene-owned dependencies survive.

## 40. No amalgamation rule

No archivo de producción puede contener simultáneamente fórmulas de:

- propulsion;
- steering;
- braking;
- hover;
- aerodynamics;
- proximity lift;
- signal conditioning.

Root coordina; specialized components calculan/aplican.

## 41. Fuera de alcance

- final track;
- camera;
- HUD;
- checkpoints/laps;
- art final;
- boost;
- ABS/regeneration/heat;
- surface-normal hover;
- attitude controller;
- MotionCueingRuntimeUnit;
- PlatformPoseCommand;
- StewartPlatformKinematics;
- hardware actuator sinks;
- hardware;
- multi-vehicle race.

## 42. Orden de implementación

```text
1. SimulationEnvironmentProfile
2. QuadraticAxisDragModel
3. ProximityLiftModel + Point Runtime
4. DistanceNoiseModel + BoundedLatencyBuffer
5. ConditionedDistanceProvider + delayed sink adapter
6. SteeringCommand + BrakeCommand + Topics
7. PropulsionIntentPolicy
8. YawSteeringModel
9. LongitudinalBrakeModel
10. VehicleControlRouter Unit/Factory
11. Steering Unit/Factory
12. Brake Unit/Factory
13. RigidBody motion source
14. physical force/torque/aerodynamic sinks
15. VehiclePhysicsCoordinator
16. VehicleCompositionRoot + scene
17. full physical integration
18. relevant Suites
19. Run All
20. refactor audit
21. baseline
```

## 43. Baseline de partida

```text
HEAD: 6079a2d
Input Suite: 6 / 101 PASS
Propulsion Suite: 6 / 143 PASS
Hover Suite: 7 / 151 PASS
Runtime Suite: 20 / 475 PASS
Run All: 98 / 2712 PASS
Tooling: 126 PASS
Workspace: 56 MB < 80 MB
```

## 44. Estado

```text
PLAYABLE VEHICLE COMPOSITION DESIGN 1.0
ACTIVO
SCENE-OWNED BODY APROBADO
STEERING Y ACTIVE BRAKING SEPARADOS
ENVIRONMENT, AERODYNAMICS, PROXIMITY LIFT, LATENCY Y NOISE APROBADOS
VEHICLE MOTION STATE SEAM APROBADO
IMPLEMENTACIÓN AUTORIZADA DESPUÉS DEL COMMIT DOCUMENTAL
```
