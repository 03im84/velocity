# ADR-015 — Propulsion Command Actuation and Force Sink Boundary

| Campo | Valor |
|---|---|
| Estado | ACEPTADO — IMPLEMENTADO — VERIFICADO |
| Versión | 1.1 |
| Fecha | 04/10/2026 |
| Fecha de verificación | 04/10/2026 |
| Alcance | Propulsion Simulation, command especializado y salida longitudinal de fuerza |
| Decisión previa | Propulsion Runtime Slice Alternative D — aprobada |

## 1. Contexto

Input Runtime Slice 1.0 publica intención completa mediante:

```text
VehicleControlCommand
throttle
steering
brake
```

ADR-014 establece que Input no aplica fuerzas ni publica comandos especializados de propulsión.

El catálogo de Topics ya contiene:

```text
propulsion_command
```

Velocity necesita un actuator de propulsión longitudinal que convierta un command especializado en una salida de fuerza finita y acotada, sin depender todavía de un `RigidBody3D` de producto.

## 2. Decisión

Propulsion Runtime Slice 1.0 utilizará:

```text
PropulsionCommand
→ PropulsionRuntimeUnit
→ LongitudinalPropulsionModel
→ PropulsionForceSink
```

El command se recibe por:

```text
BusTopics.PROPULSION_COMMAND
```

El RuntimeUnit será un target managed sin Host Objects.

El modelo y el sink serán dependencias explícitas `BORROWED`.

## 3. Frontera con Input

Propulsion RuntimeUnit no consume `VehicleControlCommand`.

La traducción:

```text
VehicleControlCommand
→ PropulsionCommand
```

pertenece a un futuro `VehicleControlRouterRuntimeUnit` dentro de Playable Vehicle Composition.

Consecuencia:

```text
Alternativa C futura
=
VehicleControlRouter nuevo
+
Actuator de Alternativa D sin modificar
```

Input, IA y replay podrán alimentar el mismo router sin acoplarse al actuator.

## 4. PropulsionCommand

Snapshot tratado como inmutable:

```text
normalized_thrust: float [-1, 1]
timestamp: float >= 0
```

Semántica:

- `0.0`: neutral;
- positivo: forward;
- negativo: reverse si el modelo lo permite;
- no finito: inválido;
- fuera de rango: inválido.

No contiene:

- steering;
- brake;
- `Vector3`;
- fuerza ya aplicada;
- body;
- Bus;
- callback;
- referencia runtime.

## 5. Topic

Se reutiliza el Topic canónico:

```text
BusTopics.PROPULSION_COMMAND
&"propulsion_command"
```

No se crea un alias ni un segundo Topic para el mismo command.

El payload canónico será `PropulsionCommand`.

## 6. LongitudinalPropulsionModel

Snapshot inmutable por contrato:

```text
max_forward_force_newtons: float >= 0
max_reverse_force_newtons: float >= 0
```

Mapeo:

```text
normalized_thrust >= 0
→ normalized_thrust * max_forward_force_newtons

normalized_thrust < 0
→ normalized_thrust * max_reverse_force_newtons
```

Output válido:

```text
[-max_reverse_force_newtons,
  max_forward_force_newtons]
```

Un reverse máximo `0.0` neutraliza commands negativos de manera segura.

El modelo no conoce:

- velocidad;
- masa;
- orientación;
- drag;
- brake;
- transmission;
- traction;
- `RigidBody3D`.

### Geometría y respuesta

`Longitudinal` define la geometría conceptual:

```text
una resultante firmada sobre el eje longitudinal del vehículo
```

La relación entre `normalized_thrust` y el límite correspondiente es lineal.

No se modelan:

- dispersión radial;
- cono de escape;
- distribución entre múltiples propulsores;
- thrust vectoring;
- punto de aplicación;
- torque.

Estas decisiones pertenecen al adapter físico o a un Profile sucesor.

## 7. PropulsionForceSink behavior

Dependencia:

```text
propulsion_force_sink / BORROWED
```

Behavior:

```gdscript
apply_propulsion_force(
    force_newtons: float,
    timestamp: float
) -> bool
```

El RuntimeUnit valida antes de invocarlo:

- force finita;
- force dentro del modelo;
- timestamp finito y no negativo;
- lifecycle `RUNNING`.

El sink decide cómo materializar la fuerza.

Un adapter futuro podrá elegir:

- eje local forward;
- punto de aplicación;
- `RigidBody3D.apply_central_force()`;
- integración con Physics Server.

Ese adapter no pertenece a Core ni a este Slice 1.0.

## 8. Dependencies

```text
propulsion_model / BORROWED
propulsion_force_sink / BORROWED
```

Ambas dependencias:

- son exactas;
- se resuelven antes de build;
- se conservan en el Handle;
- sobreviven shutdown;
- sobreviven release;
- nunca son liberadas por la Factory.

## 9. Profile y Factory Key

Profile:

```text
velocity.propulsion.longitudinal
version 1
role ACTUATOR
```

Factory Key:

```text
velocity.propulsion.longitudinal / 1 / Simulation
```

Effective Configuration:

```text
capability: longitudinal_propulsion_force
publishes: none
subscribes: propulsion_command
```

Hardware permanece bloqueado.

## 10. PropulsionRuntimeUnit

Primary Runtime Object con lifecycle:

```text
CREATED → INITIALIZED → READY → RUNNING → SHUTDOWN
```

Endpoint exacto:

```text
in.propulsion_command
```

`get_runtime_input_endpoint(port_id)` devuelve Callable válido solo para ese port.

Durante `RUNNING`:

1. recibe `BusMessage` filtrado por binder;
2. valida envelope, Topic y timestamp;
3. valida payload `PropulsionCommand`;
4. exige coherencia de timestamps;
5. calcula fuerza mediante modelo;
6. revalida finitud y bounds;
7. invoca sink;
8. conserva resultado observable de la última actuation.

Fuera de `RUNNING` no invoca el sink.

## 11. Observabilidad

La recepción por DeviceBus es void desde la perspectiva del binder.

PropulsionRuntimeUnit debe conservar:

```text
last_actuation_report
last_force_newtons
has_actuation_result
```

Un command inválido o sink rejection:

- no lanza excepción;
- no aplica fuerza adicional;
- produce Issue observable;
- preserva el Runtime.

Un command posterior válido puede recuperar la operación.

## 12. PropulsionRuntimeFactory

Construct-only.

Build:

- valida Request;
- valida Key exacta;
- valida Configuration efectiva;
- exige ambas dependencias;
- exige ownership `BORROWED`;
- valida modelo;
- valida behavior del sink;
- construye RuntimeUnit en `CREATED`;
- construye Handle válido;
- Host Objects vacío;
- preserva bindings;
- no inicializa;
- no hace ready/start;
- no aplica fuerza;
- no almacena DeviceBus.

Release:

- rechaza estados lifecycle activos;
- permite Handle en `CREATED` o Unit en `SHUTDOWN`;
- no libera model;
- no libera sink;
- no libera objetos ajenos;
- es idempotente por Handle.

## 13. Pipeline de integración

```text
Propulsion Command Source de prueba
→ BusMessage
→ DeviceBus
→ source-filtered subscription
→ PropulsionRuntimeUnit endpoint
→ LongitudinalPropulsionModel
→ PropulsionForceSink determinista
→ bounded force observable
```

El test recorrerá:

```text
DeviceProfiles
→ DeviceCatalog
→ SystemProfile
→ DeviceGraphAssembler
→ DeviceGraphSnapshot
→ RuntimeFactoryRegistry
→ CompositionCompiler
→ CompositionPlan
→ CompositionRuntime
→ ACTIVE
→ command
→ force output
→ SHUTDOWN
```

## 14. Seguridad

- Simulation-only;
- command finito y acotado;
- modelo finito y no negativo;
- fuerza revalidada antes del sink;
- neutral command explícito;
- no output fuera de `RUNNING`;
- sink rejection observable;
- target endpoint exacto;
- source filtering por binder;
- sin `RigidBody3D` en Core;
- sin singleton;
- sin autoload;
- sin service locator;
- sin thread;
- dependencies `BORROWED` preservadas;
- Hardware Runtime bloqueado.

## 15. Alternativas rechazadas

### Input aplica fuerza

Rechazada por violar ADR-014 y mezclar intención con física.

### Propulsion consume VehicleControlCommand

No seleccionada porque convierte al actuator en router de steering/brake y deja sin frontera al Topic especializado.

### Controller y Actuator completos ahora

Válida pero diferida: duplica el alcance y adelanta políticas de vehículo.

### Publicar fuerza sin sink

Rechazada: producir otro mensaje no demuestra actuation ni sink rejection.

### RuntimeUnit acoplado a RigidBody3D

Rechazada: adelanta cuerpo, orientación y SceneTree antes de Playable Vehicle Composition.

## 16. Evolución hacia Alternativa C

Cuando corresponda:

```text
VehicleControlCommand
→ VehicleControlRouterRuntimeUnit
→ PropulsionCommand
→ PropulsionRuntimeUnit 1.0
→ LongitudinalPropulsionModel
→ RigidBodyPropulsionForceSink
→ RigidBody3D
```

El actuator D permanece sin modificaciones.

Si el command necesita un cambio incompatible, se crea una versión nueva; no se altera silenciosamente la baseline 1.0.

## 17. Fuera de alcance

- VehicleControlRouter;
- braking físico;
- steering;
- transmission;
- traction;
- boost;
- energy/fuel;
- drag;
- hover;
- torque;
- vector/punto de fuerza;
- adapter `RigidBody3D`;
- cuerpo del vehículo;
- pista;
- cámara;
- HUD;
- hardware.

## 18. Criterios de aceptación

1. `PropulsionCommand` válido y acotado.
2. Topic canónico reutilizado.
3. modelo lineal explícito y validado.
4. force output finito y acotado.
5. reverse limit configurable.
6. neutral force explícita.
7. sink behavior sustituible.
8. sink `BORROWED`.
9. model `BORROWED`.
10. RuntimeUnit managed lifecycle.
11. endpoint exacto.
12. no output fuera de `RUNNING`.
13. failures observables y recuperables.
14. Factory construct-only.
15. Handle sin Host Objects.
16. release idempotente y seguro.
17. full pipeline integration.
18. Propulsion Suite PASS.
19. Runtime Suite preservada.
20. Run All PASS.
21. refactor audit PASS.

## 19. Consecuencias

Positivas:

- actuator reusable;
- límite Input/Physics claro;
- fuerza verificable sin cuerpo;
- evolución hacia C por composición;
- no se bloquea IA o replay;
- no se adelanta braking.

Costes:

- todavía no hay nave móvil;
- se requiere router futuro;
- se requieren dos dependencias runtime;
- adapter de física queda para otro milestone.

## 20. Baseline

```text
PropulsionCommandTest:                    18 checks
LongitudinalPropulsionModelTest:          28 checks
LongitudinalPropulsionProfileTest:        12 checks
PropulsionRuntimeUnitTest:                35 checks
PropulsionRuntimeFactoryTest:             25 checks
PropulsionRuntimePipelineIntegrationTest: 25 checks

Propulsion Suite:                 6 tests / 143 checks
Runtime Suite:                   20 tests / 475 checks
Run All:                         91 tests / 2561 checks
Failures:                        0
Timeout:                         0
Engine Error:                    0
Missing Metrics:                 0
Plan ExitCode:                   0
RESULT:                          PASS
```

Commits:

```text
8d34b66 feat(propulsion): add propulsion command
8502861 feat(propulsion): add longitudinal propulsion model
62eaf8a feat(propulsion): add longitudinal propulsion profile
7945181 feat(propulsion): add propulsion runtime unit
7b9fa3f feat(propulsion): add propulsion runtime factory
bc838d8 test(propulsion): add runtime pipeline integration
```

## 21. Estado

```text
ADR-015 1.1
ACEPTADO
IMPLEMENTADO
VERIFICADO
BASELINE REGISTRADA
```
