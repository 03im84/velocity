# Input Runtime Slice — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO — IMPLEMENTADO — VERIFICADO |
| Versión | 1.1 |
| Fecha | 03/10/2026 |
| Fecha de baseline | 04/10/2026 |
| ADR | ADR-014 — Input Intent Sampling and Runtime Publication 1.1 |
| Alcance | Input Simulation desde action strengths hasta VehicleControlCommand publicado |
| Implementación | COMPLETA Y VERIFICADA |

## 1. Propósito

Convertir intención de teclado o gamepad en `VehicleControlCommand` validado y publicarlo mediante `DeviceBus` dentro del pipeline runtime completo.

Este Slice entrega intención. No aplica fuerzas ni controla un vehículo.

## 2. Componentes implementados

```text
core/input/vehicle_control_command.gd
core/bus/bus_topics.gd

integration/godot/input/godot_input_source.gd
integration/godot/input/godot_input_intent_provider.gd
integration/godot/input/input_sampling_node.gd
integration/godot/input/input_runtime_unit.gd
integration/godot/input/input_runtime_factory.gd
```

No se crearon autoloads, singletons ni servicios globales.

## 3. Flujo

```text
Godot Input
→ GodotInputSource
→ GodotInputIntentProvider
→ InputSamplingNode
→ InputRuntimeUnit
→ VehicleControlCommand
→ BusMessage
→ DeviceBus
```

## 4. Input actions

Action names de producto:

```text
velocity_throttle_positive
velocity_throttle_negative
velocity_steer_left
velocity_steer_right
velocity_brake
```

El Provider recibe action names explícitos. No los descubre y no define bindings de proyecto.

## 5. VehicleControlCommand

Campos:

```text
throttle: [-1, 1]
steering: [-1, 1]
brake: [0, 1]
timestamp: >= 0
```

Invariantes:

- valores finitos;
- rangos acotados;
- getters sin setters públicos;
- neutral command válido;
- sin fuerzas;
- sin referencia a Godot Input o DeviceBus.

Topic:

```text
vehicle_control_command
```

## 6. GodotInputSource

Responsabilidad única:

```text
Input.get_action_strength(action)
→ finite clamp [0, 1]
```

Una action vacía devuelve `0.0`.

Core no depende de este componente.

## 7. GodotInputIntentProvider

Constructor recibe:

- input source;
- throttle positive;
- throttle negative;
- steer left;
- steer right;
- brake;
- deadzone.

`sample_intent()`:

- combina ejes;
- aplica deadzone;
- reescala;
- clamp;
- neutraliza strengths inválidos;
- genera un command válido;
- no publica al Bus.

## 8. InputSamplingNode

Host Object owned por la Factory.

`_physics_process` delega:

```text
runtime_unit.sample_and_publish(timestamp)
```

Solo delega cuando sampling está habilitado.

El Node se construye detached y disabled. RuntimeUnit lo configura durante initialize, lo habilita durante start y lo deshabilita durante shutdown.

## 9. InputRuntimeUnit

Lifecycle:

```text
CREATED → INITIALIZED → READY → RUNNING → SHUTDOWN
```

Primary Runtime Object administra:

- Device ID;
- Configuration;
- Provider `BORROWED`;
- Sampler;
- DeviceBus solo durante lifecycle activo;
- publicación con source identity.

`sample_and_publish(timestamp)`:

1. exige `RUNNING`;
2. valida Bus, Provider y timestamp;
3. obtiene intención;
4. valida `VehicleControlCommand`;
5. reconstruye command con timestamp runtime;
6. crea `BusMessage`;
7. publica en `vehicle_control_command`.

Fuera de `RUNNING` es no-op seguro.

## 10. InputRuntimeFactory

Factory Key:

```text
velocity.input.player / 1 / Simulation
```

Dependency:

```text
input_intent_provider / BORROWED
```

Effective Configuration:

```text
capability: vehicle_control_input
publishes: vehicle_control_command
subscribes: none
```

Build:

- validación exacta;
- `InputRuntimeUnit` en `CREATED`;
- un `InputSamplingNode` detached y disabled;
- Binding preservado;
- sin attach;
- sin lifecycle;
- sin publicación;
- sin DeviceBus almacenado.

Release:

- requiere Sampler detached;
- libera solo el Sampler;
- preserva Provider;
- idempotente por Handle.

## 11. Integración completa

La prueba sucesora utiliza componentes de producción:

```text
DeviceProfile
→ DeviceCatalog
→ SystemProfile
→ DeviceGraphAssembler
→ DeviceGraphSnapshot
→ InputRuntimeFactory Registry
→ CompositionCompiler
→ CompositionPlan
→ CompositionRuntime
→ GodotNodeRuntimeHost
→ Managed lifecycle
→ ACTIVE
→ physics tick
→ DeviceBus
→ SHUTDOWN
→ detach
→ release
```

La fuente de strengths es determinista para no depender de hardware o foco de ventana durante tests.

El Provider usado es `GodotInputIntentProvider` real.

## 12. Source-only INFO

Input publica pero no consume topics en este Slice.

Por contrato de `DeviceGraphValidator`, su OutputPort sin conexión produce:

```text
output_port_unconnected
Severity: INFO
```

La integración lo acepta y verifica explícitamente. No es un error ni un warning de seguridad.

## 13. Pruebas aceptadas

```text
VehicleControlCommandTest
GodotInputIntentProviderTest
InputSamplingNodeTest
InputRuntimeUnitTest
InputRuntimeFactoryTest
InputRuntimePipelineIntegrationTest
```

Conteos:

```text
VehicleControlCommandTest:                   12 checks
GodotInputIntentProviderTest:                17 checks
InputSamplingNodeTest:                       10 checks
InputRuntimeUnitTest:                        18 checks
InputRuntimeFactoryTest:                     21 checks
InputRuntimePipelineIntegrationTest:         23 checks
                                                ---
Input Suite:                         6 tests / 101 checks
```

Regresión:

```text
Runtime Suite:                      20 tests / 475 checks
Run All:                            85 tests / 2418 checks
Failures:                           0
Timeout:                            0
Engine Error:                       0
Missing Metrics:                    0
Plan ExitCode:                      0
RESULT:                             PASS
```

La integración pasó Repeat 5 en Godot Engine 4.7.1 stable.

## 14. Refactor audit

Revisado:

- responsabilidad;
- límites Core/Godot;
- ownership;
- lifecycle;
- determinismo;
- naming;
- alcance de package;
- hashes;
- estabilidad Repeat 5.

Resultado:

```text
PASS
SIN CAMBIO OBLIGATORIO
```

Modificar producción después de las regresiones no ofrecía beneficio demostrado y añadía riesgo.

## 15. Commits

```text
f06d76a docs(input): define input runtime slice
5522583 feat(input): add vehicle control command
bd3098f feat(input): add godot input intent provider
393e878 feat(input): add input sampling node
f4345cb feat(input): add input runtime unit
0b0b233 feat(input): add input runtime factory
80c5118 test(input): add runtime pipeline integration
```

## 16. Fuera de alcance

- propulsion;
- steering physics;
- hover;
- vehicle movement;
- `RigidBody3D`;
- track;
- camera;
- HUD;
- replay;
- IA;
- hardware input.

## 17. Estado

```text
INPUT RUNTIME SLICE 1.0
IMPLEMENTADO
VERIFICADO
BASELINE ACEPTADA

Input Suite: 6 / 101
Runtime Suite: 20 / 475
Run All: 85 / 2418
RESULT: PASS
```
