# ADR-017 — Scene-Owned Vehicle Body and Staged Physical Composition

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.0 |
| Fecha | 07/10/2026 |
| Alcance | Vehicle Control routing, steering, braking, physical sinks y body composition |
| Decisión previa | Composición escalonada con body scene-owned — aprobada |

## 1. Contexto

Velocity dispone de Input, Propulsion, Distance Sensor y Hover Slices verificados, pero todavía no existe una nave física integrada.

`VehicleControlCommand` contiene throttle, steering y brake. Propulsion consume `PropulsionCommand`; no existen SteeringCommand, BrakeCommand, sus actuators o adapters de body.

Distance Sensor y Hover requieren scheduling físico y puntos de aplicación explícitos.

## 2. Decisión

Playable Vehicle Composition 1.0 utilizará:

```text
scene-owned RigidBody3D
managed VehicleControlRouter
managed Steering Runtime
managed Active Braking Runtime
existing Propulsion Runtime
four Distance Sensor + Hover Point pairs
explicit RigidBody adapters
scene-owned VehiclePhysicsCoordinator
read-only VehicleMotionState seam
SimulationEnvironmentProfile
axis-specific aerodynamic drag
per-point Proximity Lift
deterministic sensor noise
bounded sensor/actuator latency
```

La implementación será escalonada y cada boundary tendrá tests propios.

Environment, aerodynamics, proximity lift y signal conditioning viven en componentes separados. Ningún Slice aceptado se modifica para alojar estas responsabilidades.

## 3. Body ownership

`VehicleCompositionRoot` será owner de:

- `RigidBody3D`;
- `CollisionShape3D`;
- hover markers y raycasts;
- providers físicos;
- motion source;
- physical sinks;
- model snapshots;
- CompositionRuntime;
- spawn transform;
- physics coordinator.

RuntimeFactories no crean ni liberan el body.

Adapters que referencian body son dependencies `BORROWED`.

## 4. Coordinate convention

```text
forward = local -Z
up      = local +Y
right   = local +X
```

Aplicaciones:

- propulsion central sobre forward;
- steering torque sobre up;
- brake opuesto al movimiento longitudinal;
- hover lift sobre up en cuatro application points;
- raycasts sobre local -Y.

La convención se valida; no se infiere de nombres.

## 5. VehicleControl routing

Se añade `VehicleControlRouterRuntimeUnit`:

```text
vehicle_control_command
→ propulsion_command
→ steering_command
→ brake_command
```

El router valida y publica. No aplica fuerzas.

`PropulsionIntentPolicy` calcula:

```text
effective_thrust = throttle * (1 - brake)
```

El router publica:

```text
PropulsionCommand(effective_thrust)
SteeringCommand(steering)
BrakeCommand(brake)
```

## 6. Steering boundary

```text
SteeringCommand
→ SteeringRuntimeUnit
→ YawSteeringModel
→ YawMotionSource
→ SteeringTorqueSink
```

Steering es independiente de routing, propulsion, braking y hover.

El model produce yaw torque finito y acotado con damping explícito.

## 7. Active braking boundary

```text
BrakeCommand
→ BrakeRuntimeUnit
→ LongitudinalBrakeModel
→ LongitudinalMotionSource
→ BrakeForceSink
```

Invariantes:

- normalized brake `[0,1]`;
- force opuesta a signed longitudinal speed;
- deadzone cerca de reposo;
- force cero en reposo;
- no reverse acceleration al detenerse;
- force finita y acotada;
- no modifica Hover command/model/sink.

## 8. Motion source

Un adapter scene-owned puede implementar:

```text
get_longitudinal_speed_meters_per_second()
get_yaw_rate_radians_per_second()
```

El adapter conoce `RigidBody3D` y coordinate convention.

RuntimeUnits solo conocen behaviors.

El mismo adapter expone un snapshot read-only:

```text
VehicleMotionState
local linear velocity: surge/sway/heave
local linear acceleration: surge/sway/heave
angular velocity: roll/pitch/yaw
orientation: roll/pitch/yaw
timestamp
```

Consumidores futuros pueden observarlo sin acceso mutable al body:

- telemetry;
- replay;
- camera;
- debug;
- Motion Platform Runtime.

Motion Cueing, PlatformPoseCommand, inverse kinematics y hardware sinks quedan fuera de Vehicle Composition 1.0.

## 9. Physical sinks

Adapters explícitos:

```text
RigidBodyPropulsionForceSink
RigidBodySteeringTorqueSink
RigidBodyBrakeForceSink
RigidBodyHoverForceSink
```

Cada adapter tiene una responsabilidad y valida body, input y timestamp.

No existe un sink genérico con switches de modo.

## 10. Four hover points

Topología inicial:

```text
front_left
front_right
rear_left
rear_right
```

Cada point usa:

```text
RayCast3D
PhysicsDistanceProvider
DistanceSensorRuntimeUnit
HoverPointRuntimeUnit
RigidBodyHoverForceSink
```

No hay controller central de pitch/roll en 1.0.

## 11. Physics coordinator

`VehiclePhysicsCoordinator` invoca exactamente una publicación por DistanceSensorRuntimeUnit por physics tick mientras Runtime está ACTIVE.

No calcula fuerzas, no consulta Input y no descubre Units en SceneTree.

Units se inyectan explícitamente después de activation.

## 12. Safe activation

```text
freeze body
zero velocities
disable coordinator
compile composition
activate runtime
resolve required handles
validate physical adapters
enable coordinator
unfreeze body
```

Failure mantiene body frozen, coordinator disabled y ejecuta runtime rollback.

## 13. Safe shutdown

```text
disable coordinator
freeze body
runtime.shutdown
zero velocities
preserve scene-owned body
```

No se aplica fuerza después de shutdown.

## 14. Safe reset

Reset solo con body frozen y coordinator disabled:

```text
restore spawn transform
zero linear velocity
zero angular velocity
```

Reset durante ACTIVE se rechaza.

## 15. Scene structure

```text
VehicleCompositionRoot
├── RuntimeHost
└── CraftBody (RigidBody3D)
    ├── CollisionShape3D
    ├── FrontLeftPoint (Marker3D + RayCast3D)
    ├── FrontRightPoint (Marker3D + RayCast3D)
    ├── RearLeftPoint (Marker3D + RayCast3D)
    └── RearRightPoint (Marker3D + RayCast3D)
```

Body y physical nodes son authorable en editor y permiten múltiples vehicle instances.

## 16. Passive damping

Body damping puede existir como parámetro físico explícito, pero:

- no reemplaza Brake Runtime;
- no se usa como evidencia de active braking;
- debe estar declarado y testeado;
- no se modifica desde Hover.

## 17. Environment, aerodynamics and signal conditioning

`SimulationEnvironmentProfile` declara gravity magnitude y atmospheric density.

Aerodynamic drag usa modelos cuadráticos por eje:

```text
-0.5 * density * coefficient * area * speed * abs(speed)
```

Lateral stability es una fuerza aerodinámica separada de Steering.

Proximity Lift aproximado usa un `ProximityLiftModel` acotado por distancia y un actuator por point; no modifica HoverPoint 1.0.

Distance Sensors pueden usar `ConditionedDistanceProvider` con noise determinista y bounded latency.

Actuator latency se implementa mediante delayed sink adapters con colas acotadas y `flush(timestamp)` explícito.

Vacuum, lower-density atmosphere y alternate gravity se obtienen cambiando Profile/model configuration, no reescribiendo Slices.

## 18. Staged delivery

Subfases:

```text
1. commands and pure models
2. VehicleControlRouter Runtime
3. Steering Runtime
4. Brake Runtime
5. RigidBody adapters
6. Physics coordinator
7. VehicleCompositionRoot and scene
8. full physical integration
```

Cada subfase usa successor tests y Delivery separada.

## 19. Physical integration fixture

Se utilizará un piso simple de prueba, no el track final.

Acceptance:

- activation y unfreeze seguros;
- cuatro streams Hover activos;
- body finito y sobre piso;
- altura entra en banda segura;
- throttle aumenta desplazamiento forward;
- brake corta propulsion y reduce velocidad activamente;
- brake no reduce lift command;
- steering cambia yaw con angular rate acotado;
- shutdown congela y limpia velocidades;
- dependencies scene-owned sobreviven.

## 20. Seguridad

- Simulation-only;
- body explícito;
- no SceneTree discovery;
- no singleton/autoload;
- no force antes de ACTIVE;
- no force después de shutdown;
- bounded force/torque;
- brake deadzone;
- body frozen on failure;
- explicit spawn/reset;
- best-effort runtime cleanup;
- Hardware Runtime bloqueado.

## 21. Alternativas rechazadas

- monolithic VehicleController;
- body creado por RuntimeFactory;
- body autoload/global;
- root interpretando commands;
- Input publicando specialized commands;
- router aplicando steering/brake directamente;
- composición sin steering;
- braking basado solo en passive damping.

## 22. Consecuencias

Positivas:

- ownership claro;
- boundaries sustituibles;
- multi-vehicle posible;
- editor-friendly scene;
- accepted Slices reutilizados;
- physical failures observables;
- steering y brake no amalgamados.

Costes:

- milestone grande;
- nuevos Commands/Topics/Factories;
- tuning físico explícito;
- tests Godot Physics con tolerancias;
- más dependencies scene-owned.

## 23. Fuera de alcance

- final track;
- chase camera;
- HUD;
- checkpoints/laps;
- final art;
- boost;
- ABS/regenerative braking/brake heat;
- surface-normal hover;
- active attitude controller;
- hardware;
- multi-vehicle race.

## 24. Estado

```text
ADR-017 1.0
ACEPTADO
COMPOSICIÓN ESCALONADA Y BODY SCENE-OWNED APROBADOS
STEERING Y ACTIVE BRAKING SEPARADOS
ENVIRONMENT, AERODYNAMICS, PROXIMITY LIFT, LATENCY Y NOISE REQUERIDOS
VEHICLE MOTION STATE SEAM APROBADO
IMPLEMENTACIÓN AUTORIZADA DESPUÉS DEL COMMIT DOCUMENTAL
```
