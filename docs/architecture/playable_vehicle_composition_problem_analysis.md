# Playable Vehicle Composition 1.0 — Problema, análisis y alternativas

| Campo | Valor |
|---|---|
| Estado | COMPOSICIÓN ESCALONADA APROBADA |
| Fecha | 07/10/2026 |
| Baseline | 6079a2d — docs(hover): record hover physics baseline |
| Target | Primera nave antigravitatoria físicamente controlable |

## 1. Punto de partida

Velocity dispone de Slices aceptados:

```text
Input Runtime Slice 1.0
Propulsion Runtime Slice 1.0
Distance Sensor Runtime Slice 1.0
Hover Physics Slice 1.0
```

Flujos disponibles:

```text
Godot Input
→ VehicleControlCommand
```

```text
PropulsionCommand
→ bounded longitudinal force sink
```

```text
DistanceMeasurement
→ bounded hover lift sink
```

Todavía no existe:

- VehicleControlRouter;
- SteeringCommand;
- steering actuator;
- body force sinks;
- RigidBody3D owner;
- vehicle scene/root;
- physics coordinator;
- automatic Distance Sensor sampling;
- safe spawn/reset;
- full craft integration.

## 2. Problema

Playable Vehicle Composition debe convertir baselines lógicas en una nave física real:

```text
Input
→ routing
→ propulsion + steering

Distance Sensors
→ Hover Points

all forces
→ one explicit RigidBody3D
```

Debe hacerlo sin:

- convertir UI o SceneTree en service locator;
- hacer que Factories descubran el body;
- permitir ownership ambiguo;
- mezclar todas las fuerzas en un monolito;
- depender de un track final todavía inexistente;
- activar body antes de completar Runtime activation;
- dejar fuerzas activas después de shutdown;
- introducir orden de physics tick no observable;
- reescribir Propulsion o Hover aceptados.

## 3. Brecha de routing

`VehicleControlCommand` contiene:

```text
throttle
steering
brake
```

Propulsion consume:

```text
PropulsionCommand
```

Falta:

```text
VehicleControlCommand
→ PropulsionCommand
```

La policy mínima propuesta:

```text
effective_thrust = throttle * (1 - brake)
```

### Semántica exacta de brake en 1.0

`brake` cumple dos funciones coordinadas pero separadas:

```text
1. interlock de propulsion
2. command para actuator de braking activo
```

Routing:

```text
effective_thrust = throttle * (1 - brake)
normalized_brake = brake
```

Esto evita que propulsion y brake soliciten fuerzas longitudinales opuestas al mismo tiempo.

### Relación con el closed loop de Hover

El lazo cerrado de Hover regula:

```text
altura
velocidad de separación vertical
lift por point
```

No regula:

```text
velocidad longitudinal
set-point de velocidad forward
momentum sobre -Z
```

Braking activo no modifica:

- equilibrium force;
- spring;
- damping vertical;
- max lift;
- hover sinks.

La estabilización vertical no se utilizará como mecanismo de braking longitudinal.

### Boundary de braking activo

```text
BrakeCommand
→ BrakeRuntimeUnit
→ LongitudinalBrakeModel
→ LongitudinalMotionSource
→ BrakeForceSink
```

`BrakeCommand` propuesto:

```text
normalized_brake: [0, 1]
timestamp >= 0
```

`LongitudinalMotionSource` es una dependencia `BORROWED` que expone velocidad longitudinal firmada del body sin entregar el body completo al RuntimeUnit.

Modelo conceptual:

```text
if abs(longitudinal_speed) <= speed_deadzone:
    brake_force = 0
else:
    magnitude = normalized_brake * max_brake_force
    brake_force = -sign(longitudinal_speed) * magnitude
```

Invariantes:

- fuerza finita y acotada;
- fuerza siempre opuesta al movimiento longitudinal;
- fuerza cero cerca de reposo;
- no reverse acceleration al detenerse;
- no componente de Hover intencional;
- sink físico separado.

El body puede conservar damping pasivo explícito, pero la aceptación de brake se basará en BrakeRuntime y no en damping accidental.

## 4. Brecha de steering

No existe Topic, payload, model o actuator para steering.

La aceptación de Vehicle Composition exige `steer`; no puede declararse completa omitiéndolo.

Contrato mínimo necesario:

```text
SteeringCommand
normalized_yaw [-1, 1]
timestamp >= 0
```

Topic nuevo:

```text
steering_command
```

Actuator mínimo:

```text
SteeringCommand
→ SteeringRuntimeUnit
→ YawSteeringModel
→ SteeringTorqueSink
```

El model debe limitar torque y damping de yaw. El sink físico futuro conoce body y eje local `+Y`.

## 5. Frame físico propuesto

Convención Godot inicial:

```text
forward: -Z local
up:      +Y local
right:   +X local
```

Aplicaciones:

```text
propulsion force:
body local -Z
central

steering torque:
body local +Y

hover rays:
body local -Y

hover lift:
body local +Y
aplicado en cada hover point
```

La convención debe fijarse en ADR y tests. No se infiere por nombres de Nodes.

## 6. Cuatro hover points iniciales

Topología propuesta:

```text
front_left
front_right
rear_left
rear_right
```

Cada point contiene o referencia:

```text
Marker3D application point
RayCast3D distance source
PhysicsDistanceProvider
DistanceSensorRuntimeUnit
HoverPointRuntimeUnit
RigidBodyHoverForceSink
```

No existe controller central de balancing en 1.0. Pitch/roll emergen de las cuatro fuerzas spring-damper aplicadas en posiciones distintas.

Un attitude controller puede añadirse después mediante composición.

## 7. Ownership del body

Alternativas:

### A. RigidBody creado por RuntimeFactory

Ventaja:

- body dentro del Handle.

Costes:

- Factory debe conocer escena física;
- ownership y respawn se mezclan con Device lifecycle;
- release podría destruir representación de producto;
- dificulta editor y authoring visual.

Decisión:

```text
RECHAZADA
```

### B. RigidBody autoload/global

Costes:

- service locator;
- singleton de conveniencia;
- múltiples vehículos imposibles;
- tests acoplados.

Decisión:

```text
RECHAZADA
```

### C. Scene-owned RigidBody explícito

```text
VehicleCompositionRoot
owns
RigidBody3D + Collision + Markers + RayCasts
```

Runtime dependencies reciben adapters `BORROWED` que apuntan al body explícito.

Ventajas:

- ownership claro;
- editor-friendly;
- múltiples instancias posibles;
- Runtime no libera body;
- reset/spawn pertenece al root;
- sinks sustituibles en tests.

Decisión recomendada:

```text
SELECCIONAR C
```

## 8. Composition Runtime ownership

```text
VehicleCompositionRoot
owns
CompositionRuntime
```

CompositionRuntime posee:

- DeviceBus;
- RuntimeDeviceHandles;
- bindings;
- managed lifecycle.

VehicleCompositionRoot posee:

- body;
- physical child Nodes;
- providers;
- physical sinks;
- runtime models;
- CompositionRuntime instance;
- activation/shutdown orchestration;
- spawn transform.

## 9. Safe activation

Secuencia propuesta:

```text
body.freeze = true
coordinator disabled
build immutable Profiles/Configurations/System
compile Graph/Registry/Plan
create dependency resolver
activate CompositionRuntime
resolve required Handles
validate physical dependencies
coordinator enabled
body velocities = zero
body.freeze = false
ACTIVE
```

Si cualquier paso falla:

```text
body remains frozen
coordinator remains disabled
runtime rollback executes
failure report remains observable
```

## 10. Safe shutdown

```text
coordinator disabled
body.freeze = true
CompositionRuntime.shutdown()
zero linear velocity
zero angular velocity
preserve scene-owned body
terminal SHUTDOWN
```

No se libera el body desde RuntimeFactory.

## 11. Reset

Reset permitido solo con coordinator disabled y body frozen.

```text
body.global_transform = spawn_transform
body.linear_velocity = Vector3.ZERO
body.angular_velocity = Vector3.ZERO
```

Reset durante ACTIVE se rechaza o exige shutdown previo.

## 12. Physics coordinator

Distance Sensor Runtime no publica automáticamente por physics tick.

Se requiere un coordinator explícito scene-owned:

```text
VehiclePhysicsCoordinator
```

Responsabilidad:

> Invocar publish_measurement() de los cuatro DistanceSensorRuntimeUnits una vez por physics tick mientras la composición está ACTIVE.

No:

- calcula hover;
- aplica fuerzas;
- consulta Input;
- descubre Units en SceneTree;
- posee DeviceBus.

Los Units se inyectan explícitamente después de activation.

## 13. Scheduling

Dentro de cada physics tick:

```text
InputSamplingNode publica control
VehicleControlRouter publica specialized commands
Propulsion/Steering sinks aplican fuerzas
VehiclePhysicsCoordinator publica measurements
Hover sinks aplican fuerzas
Godot integra body
```

DeviceBus dispatch es síncrono e iterativo.

Todas las fuerzas se aplican antes de la integración física del frame. El orden entre propulsion y hover no cambia su suma, pero debe permanecer observable y sin doble sampling.

Process priority se fijará explícitamente si los tests demuestran necesidad; no se dependerá de orden accidental del SceneTree.

## 14. VehicleControlRouter alternativas

### A. Root interpreta VehicleControlCommand

Costes:

- lógica de routing fuera de Runtime;
- difícil de sustituir por IA/replay;
- root se vuelve controller.

Rechazada.

### B. Input publica specialized commands

Viola ADR-014.

Rechazada.

### C. Managed VehicleControlRouterRuntimeUnit

```text
vehicle_control_command
→ router
→ propulsion_command
→ steering_command
```

El router no contendrá fórmulas físicas. Delegará longitudinal intent a una policy pura:

```text
PropulsionIntentPolicy
inputs: throttle, brake
output: normalized_thrust

normalized_thrust = throttle * (1 - brake)
```

Steering seguirá una ruta especializada:

```text
steering
→ SteeringCommand
→ SteeringRuntimeUnit
```

Responsabilidades:

```text
VehicleControlRouterRuntimeUnit
- validar VehicleControlCommand
- delegar mapping a policies
- publicar commands especializados

PropulsionIntentPolicy
- combinar throttle y brake
- no conocer DeviceBus o body

Steering Runtime
- modelar y aplicar yaw torque acotado

Hover Runtime
- regular altura de manera independiente
```

Ventajas:

- source filtering;
- lifecycle;
- policies testeables;
- sustituible;
- IA/replay compatible;
- root no interpreta intención;
- throttle/brake no se amalgaman con steering o hover.

Recomendada.

## 15. Steering boundary alternativas

### A. Router aplica torque directo

Mezcla routing y actuation.

No recomendada.

### B. SteeringRuntimeUnit especializado

```text
SteeringCommand
→ YawSteeringModel
→ SteeringRuntimeUnit
→ SteeringTorqueSink
```

Ventajas:

- paralela a Propulsion/Hover;
- bounds explícitos;
- sink sustituible;
- torque físico fuera de Core;
- pruebas aisladas.

Recomendada.

Aunque Steering permanezca agrupado dentro del milestone Playable Vehicle Composition, su implementación será independiente:

```text
core/steering/
integration/godot/steering/
test/core/steering/
```

Braking activo tendrá la misma separación:

```text
core/braking/
integration/godot/braking/
test/core/braking/
```

Steering y Braking tendrán commands, models, RuntimeUnits, Factories, sinks, tests y baselines propios. `VehicleCompositionRoot` solo realizará wiring/orchestration; no contendrá fórmulas de steering/braking ni aplicará torque/fuerza por cuenta propia.

## 16. YawSteeringModel mínimo

Parámetros propuestos:

```text
max_yaw_torque_newton_meters >= 0
yaw_damping_newton_meter_seconds >= 0
max_abs_yaw_rate_radians_per_second > 0
```

Input del model:

```text
normalized_yaw
yaw_rate
```

Fórmula conceptual:

```text
command_torque = normalized_yaw * max_yaw_torque
damping_torque = -yaw_rate * yaw_damping
raw = command_torque + damping_torque
bounded torque = clamp(raw, -max, max)
```

El sink físico obtiene yaw rate del body y entrega el escalar/model result al torque adapter. La frontera exacta requiere revisión en ADR.

## 17. Propulsion sink físico

```text
RigidBodyPropulsionForceSink
```

Dependencias explícitas:

- scene-owned RigidBody3D;
- forward convention.

Behavior existente:

```text
apply_propulsion_force(force_newtons, timestamp) -> bool
```

Implementación conceptual:

```text
world_forward = -body.global_basis.z.normalized()
body.apply_central_force(world_forward * force_newtons)
```

Valida body, force y timestamp antes de aplicar.

## 18. Hover sink físico

```text
RigidBodyHoverForceSink
```

Dependencias:

- scene-owned RigidBody3D;
- explicit Marker3D application point;
- explicit local lift axis convention.

Concepto:

```text
world_up = body.global_basis.y.normalized()
world_offset = marker.global_position - body.global_position
body.apply_force(world_up * lift_force, world_offset)
```

No usa surface normal porque DistanceMeasurement 1.0 no la contiene.

## 19. Distance providers físicos

Cada hover point usa:

```text
RayCast3D
→ PhysicsDistanceProvider
→ DistanceSensorRuntimeUnit
```

RayCast:

- child del body o point Node;
- target direction local -Y;
- explicit collision mask;
- no autoconfiguración global.

Provider y RayCast son scene-owned y llegan como dependencies `BORROWED`.

## 20. Alternativa monolítica de composición

```text
VehicleController.gd
reads Input
casts rays
calculates hover
applies propulsion
applies steering
```

Ventaja:

- pocas líneas iniciales.

Costes:

- destruye boundaries aceptados;
- imposible probar por Slice;
- duplica lógica;
- hace inútil CompositionRuntime;
- difícil multi-vehicle/hardware/replay.

Decisión:

```text
RECHAZADA
```

## 21. Alternativa sin steering

Componer solo Input, Propulsion y Hover.

Resultado:

- acelera;
- flota;
- no gira.

No cumple acceptance de Vehicle Composition ni Vertical Slice.

Decisión:

```text
RECHAZADA
```

## 22. Alternativa recomendada — composición escalonada

Mantener un solo milestone de producto con subfases explícitas:

```text
Stage 0 — Environment, atmosphere and signal conditioning
Stage 1 — Vehicle Control Routing
Stage 2 — Steering Runtime Boundary
Stage 3 — Active Braking Runtime Boundary
Stage 4 — Aerodynamic and ground-effect boundaries
Stage 5 — RigidBody force/torque sinks
Stage 6 — Vehicle scene and physics coordinator
Stage 7 — Full physical integration
```

Esto hace visible el trabajo faltante sin insertar lógica oculta ni cambiar el target del Gantt.

## 23. Scene inicial propuesta

```text
VehicleCompositionRoot (Node3D)
├── RuntimeHost (Node)
└── CraftBody (RigidBody3D)
    ├── CollisionShape3D
    ├── FrontLeftPoint (Marker3D)
    │   └── RayCast3D
    ├── FrontRightPoint (Marker3D)
    │   └── RayCast3D
    ├── RearLeftPoint (Marker3D)
    │   └── RayCast3D
    └── RearRightPoint (Marker3D)
        └── RayCast3D
```

No se añade mesh final; una representación debug simple es suficiente.

## 24. Physical integration test

Fixture independiente del track final:

```text
StaticBody3D floor
VehicleCompositionRoot
fixed spawn transform
fixed physics duration
```

Acceptance mínima:

- activation PASS;
- body unfreezes only after ACTIVE;
- four sensor/hover streams active;
- body remains finite;
- body does not fall through floor;
- hover height enters safe band;
- forward input increases forward displacement;
- brake input reduces routed thrust to zero without reducing hover lift;
- active brake force opposes longitudinal motion and does not reverse the craft at rest;
- braking decreases longitudinal speed faster than passive coasting;
- steering input changes yaw with bounded angular velocity;
- shutdown freezes and clears velocities;
- no forces after shutdown;
- borrowed body/providers/sinks remain alive.

## 25. Riesgos

### Physics determinism

Jolt integration puede variar levemente por plataforma. Tests deben usar bandas y propiedades, no igualdad exacta de transforms.

### Coordinate mistakes

Ejes y offsets deben probarse con fixtures explícitos.

### Force tuning

Valores físicos son configuración/modelos, no constantes ocultas del root.

### Scheduling

No asumir ordering accidental de Nodes.

### Scope growth

No incluir camera, track final, HUD, checkpoints o arte.

## 26. Fuera de alcance

- final track;
- chase camera;
- HUD;
- checkpoint/lap;
- visual art;
- boost;
- regenerative braking, ABS or brake heat;
- surface normals;
- active attitude controller;
- hardware;
- multi-vehicle race.

## 27. Tests previstos

```text
SteeringCommandTest
BrakeCommandTest
PropulsionIntentPolicyTest
YawSteeringModelTest
LongitudinalBrakeModelTest
VehicleControlRouterRuntimeUnitTest
VehicleControlRouterRuntimeFactoryTest
SteeringRuntimeUnitTest
SteeringRuntimeFactoryTest
BrakeRuntimeUnitTest
BrakeRuntimeFactoryTest
RigidBodyMotionSourceTest
RigidBodyPropulsionForceSinkTest
RigidBodySteeringTorqueSinkTest
RigidBodyBrakeForceSinkTest
RigidBodyHoverForceSinkTest
VehiclePhysicsCoordinatorTest
VehicleCompositionRootTest
PlayableVehiclePhysicsIntegrationTest
```

La lista puede dividirse por subfase, pero ninguna baseline aceptada se modifica para ocultar una responsabilidad nueva.

## 28. Orden recomendado

```text
1. SteeringCommand + BrakeCommand + Topics
2. PropulsionIntentPolicy
3. YawSteeringModel + LongitudinalBrakeModel
4. VehicleControlRouter RuntimeUnit/Factory
5. Steering RuntimeUnit/Factory
6. Brake RuntimeUnit/Factory
7. RigidBody motion source
8. RigidBody propulsion/steering/brake/hover sinks
9. VehiclePhysicsCoordinator
10. VehicleCompositionRoot + scene
11. full physical integration
12. relevant Suites
13. Run All
14. refactor audit
15. baseline
```

## 29. Decisión recomendada

```text
Scene-owned RigidBody3D
+
managed VehicleControlRouter
+
specialized Steering Runtime
+
specialized Active Braking Runtime
+
four independent Hover Points
+
explicit physical sinks
+
scene-owned physics coordinator
```

No insertar un milestone separado en el Gantt por ahora; usar subfases visibles dentro de Playable Vehicle Composition 1.0.

## 30. Gate de arquitectura

Decisión registrada:

```text
COMPOSICIÓN ESCALONADA APROBADA
BODY SCENE-OWNED APROBADO
STEERING RUNTIME SEPARADO APROBADO
ACTIVE BRAKING RUNTIME SEPARADO APROBADO
07/10/2026
```

Consecuencia:

1. redactar ADR-017;
2. redactar Playable Vehicle Composition Design 1.0;
3. congelar steering/braking models, ownership y safe activation;
4. preparar commit documental;
5. solo después comenzar implementación.

## 31. Environment and realism requirements

Requisitos aprobados durante review:

```text
SimulationEnvironmentProfile
configurable gravity
configurable atmospheric density
quadratic per-axis drag
lateral stability separate from steering
per-point Proximity Lift
deterministic distance noise
bounded sensor latency
bounded actuator latency
```

El mismo vehicle scaffold debe cambiar de planeta o atmósfera mediante Profiles/models, no reescribiendo Input, Propulsion, Steering, Brake o Hover.

Proximity Lift se compone como actuator adicional por point y no modifica HoverPoint 1.0.

Latency usa queues con capacity fija; noise usa source explícito seedable o sequence-driven. No se permiten RNG global o memoria no acotada.

Detalles canónicos se registran en:

```text
environment_realism_addendum.md
```
