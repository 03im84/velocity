# ADR-014 — Input Intent Sampling and Runtime Publication

| Campo | Valor |
|---|---|
| Estado | PROPUESTO PARA REVISIÓN |
| Versión | 1.0 |
| Fecha | 03/10/2026 |
| Alcance | Input Simulation, intención normalizada y publicación runtime |

## Contexto

El roadmap sitúa a Velocity en Input Runtime Slice 1.0. Core no debe consultar el singleton Godot `Input` ni depender de teclado o gamepad concretos.

## Decisión propuesta

```text
Godot Input
→ GodotInputIntentProvider
→ InputRuntimeUnit
→ VehicleControlCommand
→ DeviceBus
```

El Provider concreto vive fuera de Core. RuntimeUnit consume un behavior explícito y publica únicamente durante RUNNING.

## VehicleControlCommand

Snapshot inmutable con:

```text
throttle: float [-1, 1]
steering: float [-1, 1]
brake: float [0, 1]
timestamp: float >= 0
```

Valores no finitos se rechazan. No aplica fuerzas.

## Topic

Nuevo Topic canónico:

```text
vehicle_control_command
```

Input Slice no publica directamente `propulsion_command`, porque steering y brake pertenecen a intención del vehículo, no solo propulsion.

## Provider behavior

```gdscript
sample_intent() -> VehicleControlCommand
```

Provider concreto Godot:

- usa actions configurables;
- combina teclado y gamepad;
- aplica deadzone;
- clamp;
- neutraliza al perder foco cuando corresponda;
- no publica al Bus.

## Sampling

Un Host Object `Node` realiza sampling en `_physics_process` solo mientras RuntimeUnit está RUNNING.

El Node delega al RuntimeUnit; no posee DeviceBus global.

## RuntimeUnit

Primary Runtime Object administra:

- Device ID;
- Configuration;
- Provider BORROWED;
- sampler Node;
- DeviceBus durante lifecycle;
- secuencia de publicación.

Host Object:

```text
InputSamplingNode
```

## Factory

Construct-only. Produce RuntimeUnit + sampler Node + Provider Binding. No adjunta, inicializa, inicia o publica.

## Seguridad

- Simulation-only;
- valores acotados;
- neutral state válido;
- sin polling fuera de RUNNING;
- sin Input singleton en Core;
- sin autoload;
- sin service locator;
- shutdown detiene sampling antes de release.

## Alternativas rechazadas

- RuntimeUnit consulta `Input` directamente;
- UI publica commands;
- callback dentro de CompositionPlan;
- Input publica propulsion force;
- singleton Input Manager;
- sampling en thread.

## Criterios de aceptación

1. Command inmutable y validado.
2. Topic canónico.
3. Provider behavior sustituible.
4. Godot provider fuera de Core.
5. teclado y gamepad normalizados.
6. deadzone y clamp.
7. sampler Node explícito.
8. lifecycle administrado.
9. publicación solo RUNNING.
10. source identity en BusMessage.
11. Provider BORROWED.
12. Factory construct-only.
13. full pipeline integration.
14. Runtime Suite PASS.
15. Run All PASS.

## Fuera de alcance

Propulsion, steering physics, hover, RigidBody3D, camera, track, HUD, replay, IA y hardware input.

## Estado

```text
ADR-014 PROPUESTO
IMPLEMENTACIÓN BLOQUEADA HASTA REVISIÓN Y COMMIT DOCUMENTAL
```
