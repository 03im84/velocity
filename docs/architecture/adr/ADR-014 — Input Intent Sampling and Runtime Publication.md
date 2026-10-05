# ADR-014 — Input Intent Sampling and Runtime Publication

| Campo | Valor |
|---|---|
| Estado | ACEPTADO — IMPLEMENTADO — VERIFICADO |
| Versión | 1.1 |
| Fecha | 03/10/2026 |
| Fecha de verificación | 04/10/2026 |
| Alcance | Input Simulation, intención normalizada y publicación runtime |

## 1. Contexto

Input Runtime Slice 1.0 convierte intención de jugador en mensajes runtime validados para el Playable Vertical Slice.

Core no debe consultar el singleton Godot `Input`, depender de teclado o gamepad concretos, aplicar fuerzas ni publicar comandos de propulsión directamente.

## 2. Decisión

```text
Godot Input
→ GodotInputSource
→ GodotInputIntentProvider
→ InputSamplingNode
→ InputRuntimeUnit
→ VehicleControlCommand
→ DeviceBus
```

La integración concreta con Godot vive fuera de Core. `InputRuntimeUnit` consume un Provider behavior explícito y publica únicamente durante `RUNNING`.

No se introduce autoload, singleton, service locator, thread ni dependencia implícita del `SceneTree`.

## 3. VehicleControlCommand

Snapshot tratado como inmutable con:

```text
throttle: float [-1, 1]
steering: float [-1, 1]
brake: float [0, 1]
timestamp: float >= 0
```

Los valores no finitos o fuera de rango son inválidos.

El command representa intención normalizada. No aplica fuerzas y no conoce propulsion, hover, vehículo o pista.

## 4. Topic

Topic canónico:

```text
vehicle_control_command
```

Input Runtime no publica directamente `propulsion_command`, porque steering y brake pertenecen a intención completa del vehículo, no solo a propulsión.

## 5. Input Source y Provider

`GodotInputSource` es el único componente de este Slice que consulta `Input.get_action_strength()`.

Provider behavior:

```gdscript
sample_intent() -> VehicleControlCommand
```

`GodotInputIntentProvider`:

- recibe una fuente explícita;
- usa action names configurables;
- combina ejes positivo y negativo;
- aplica deadzone;
- reescala después de deadzone;
- acota strengths y commands;
- neutraliza valores no finitos;
- produce estado neutral válido;
- no conoce ni publica al DeviceBus.

## 6. Sampling

`InputSamplingNode` es el único Host Object owned del Slice.

Durante `_physics_process`:

```text
sampling disabled → no-op
sampling enabled  → runtime_unit.sample_and_publish(timestamp)
```

El Node:

- no descubre RuntimeUnit;
- no descubre DeviceBus;
- no conserva servicios globales;
- se habilita al iniciar;
- se deshabilita durante shutdown;
- se libera solo después de detach.

## 7. InputRuntimeUnit

Primary Runtime Object con lifecycle:

```text
CREATED → INITIALIZED → READY → RUNNING → SHUTDOWN
```

Administra:

- Device ID;
- DeviceConfiguration;
- Provider `BORROWED`;
- InputSamplingNode;
- DeviceBus durante lifecycle;
- reconstrucción del timestamp runtime;
- publicación de `BusMessage`.

Publicación:

```text
source_id = Device ID
topic = vehicle_control_command
payload = VehicleControlCommand
```

Fuera de `RUNNING`, sampling y publicación son no-op seguros.

Shutdown es idempotente, detiene sampling, elimina referencias runtime y no libera el Provider.

## 8. InputRuntimeFactory

Factory Key exacta:

```text
velocity.input.player / 1 / Simulation
```

Dependencia exacta:

```text
input_intent_provider / BORROWED
```

Configuración efectiva:

```text
capability: vehicle_control_input
publishes: vehicle_control_command
subscribes: none
```

La Factory es construct-only:

- valida Request, Key, Configuration y Binding;
- valida el behavior `sample_intent()`;
- construye `InputRuntimeUnit` en `CREATED`;
- construye un `InputSamplingNode` detached y disabled;
- preserva el Binding `BORROWED` en el Handle;
- no adjunta;
- no ejecuta lifecycle;
- no publica;
- no almacena DeviceBus.

Release:

- rechaza un Sampler todavía adjunto;
- libera solo el Sampler owned;
- preserva el Provider;
- es idempotente por Handle.

## 9. Pipeline verificado

```text
DeviceProfile
→ DeviceCatalog
→ SystemProfile
→ DeviceGraphSnapshot
→ RuntimeFactoryRegistry
→ CompositionPlan
→ CompositionRuntime
→ ACTIVE
→ physics tick
→ VehicleControlCommand
→ SHUTDOWN
```

Un Input Device source-only produce por contrato:

```text
output_port_unconnected / INFO
```

Ese INFO es esperado, no bloquea Simulation y se verifica explícitamente.

## 10. Seguridad

- Simulation-only;
- valores acotados;
- estado neutral válido;
- sin polling fuera de `RUNNING`;
- sin singleton Godot Input en Core;
- sin autoload;
- sin service locator;
- sin sampling thread;
- Provider `BORROWED` preservado;
- shutdown detiene sampling antes de release;
- Host detach precede Factory release.

## 11. Alternativas rechazadas

- RuntimeUnit consulta `Input` directamente;
- UI publica commands;
- callback dentro de CompositionPlan;
- Input publica fuerza de propulsion;
- singleton Input Manager;
- sampling en thread;
- Factory inicia lifecycle;
- Factory adjunta Nodes;
- Provider owned por la Factory.

## 12. Criterios de aceptación

1. Command validado y tratado como inmutable.
2. Topic canónico.
3. Provider behavior sustituible.
4. Integración Godot fuera de Core.
5. teclado y gamepad normalizados mediante actions.
6. deadzone y clamp.
7. sampler Node explícito.
8. lifecycle administrado.
9. publicación solo `RUNNING`.
10. source identity en `BusMessage`.
11. Provider `BORROWED`.
12. Factory construct-only.
13. full pipeline integration.
14. Input Suite PASS.
15. Runtime Suite preservada.
16. Run All PASS.
17. refactor audit PASS.

Todos los criterios están verificados.

## 13. Baseline

```text
VehicleControlCommandTest:                   12 checks
GodotInputIntentProviderTest:                17 checks
InputSamplingNodeTest:                       10 checks
InputRuntimeUnitTest:                        18 checks
InputRuntimeFactoryTest:                     21 checks
InputRuntimePipelineIntegrationTest:         23 checks

Input Suite:                         6 tests / 101 checks
Runtime Suite:                      20 tests / 475 checks
Run All:                            85 tests / 2418 checks
Failures:                           0
Timeout:                            0
Engine Error:                       0
Missing Metrics:                    0
Plan ExitCode:                      0
RESULT:                             PASS
```

`InputRuntimePipelineIntegrationTest` también pasó Repeat 5 en Godot Engine 4.7.1 stable.

## 14. Commits de implementación

```text
5522583 feat(input): add vehicle control command
bd3098f feat(input): add godot input intent provider
393e878 feat(input): add input sampling node
f4345cb feat(input): add input runtime unit
0b0b233 feat(input): add input runtime factory
80c5118 test(input): add runtime pipeline integration
```

## 15. Fuera de alcance

Propulsion, steering physics, hover, `RigidBody3D`, vehicle movement, track, camera, HUD, replay, IA y hardware input.

## 16. Estado

```text
ADR-014 1.1
ACEPTADO
IMPLEMENTADO
VERIFICADO
BASELINE REGISTRADA
```
