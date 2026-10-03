# Input Runtime Slice — Diseño

| Campo | Valor |
|---|---|
| Estado | PROPUESTO PARA REVISIÓN |
| Versión | 1.0 |
| Fecha | 03/10/2026 |
| ADR | ADR-014 — Input Intent Sampling and Runtime Publication |

## Propósito

Convertir intención de teclado/gamepad en `VehicleControlCommand` validado y publicarlo mediante DeviceBus dentro del pipeline runtime completo.

## Componentes previstos

```text
core/input/vehicle_control_command.gd
integration/godot/input/godot_input_intent_provider.gd
integration/godot/input/input_sampling_node.gd
integration/godot/input/input_runtime_unit.gd
integration/godot/input/input_runtime_factory.gd
```

## Input actions

```text
velocity_throttle_positive
velocity_throttle_negative
velocity_steer_left
velocity_steer_right
velocity_brake
```

No se crean autoloads.

## Provider

Constructor recibe action names y deadzone. `sample_intent()` devuelve command neutral o acotado. No conoce DeviceBus.

## Sampling Node

`_physics_process` llama `runtime_unit.sample_and_publish(timestamp)` cuando está habilitado. RuntimeUnit habilita/deshabilita el sampler durante start/shutdown.

## RuntimeUnit lifecycle

```text
CREATED → INITIALIZED → READY → RUNNING → SHUTDOWN
```

Managed methods devuelven ValidationReport. Shutdown es idempotente.

## Factory Key

```text
velocity.input.player / 1 / Simulation
```

Dependency:

```text
input_intent_provider / BORROWED
```

## Effective Configuration

```text
capability: vehicle_control_input
publishes: vehicle_control_command
subscribes: none
```

## Publicación

```text
BusMessage
source_id = Device ID
topic = vehicle_control_command
payload = VehicleControlCommand
```

Una publicación por physics tick mientras RUNNING. Neutral command puede publicarse para preservar estado explícito.

## Pruebas previstas

```text
VehicleControlCommandTest
GodotInputIntentProviderTest
InputRuntimeUnitTest
InputRuntimeFactoryTest
InputRuntimePipelineIntegrationTest
```

Integración verifica Profile → Catalog → Graph → Compiler → Runtime → ACTIVE → command → SHUTDOWN.

## Orden

1. Command y Topic.
2. Provider.
3. Sampling Node.
4. RuntimeUnit.
5. Factory.
6. Full pipeline.
7. Runtime Suite.
8. Run All.
9. Refactor y baseline.

## Fuera de alcance

Fuerzas, propulsion, hover, vehicle movement, track, camera y HUD.

## Estado

```text
INPUT RUNTIME SLICE DESIGN 1.0
PROPUESTO
IMPLEMENTACIÓN BLOQUEADA PENDIENTE DE REVISIÓN
```
