# Distance Sensor Runtime Slice — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.1 |
| Fecha | 03/10/2026 |
| ADR | ADR-013 — Distance Sensor Simulation Runtime Slice and Configuration Fidelity |
| Alcance | RuntimeUnit, Factory y full pipeline de Distance Sensor Simulation |
| Implementación | COMPLETA Y VERIFICADA |

## 1. Propósito

Activar el primer Device concreto mediante CompositionRuntime y adapters de producción.

## 2. Archivos previstos

```text
integration/godot/devices/distance_sensor/
├── distance_sensor_runtime_unit.gd
└── distance_sensor_runtime_factory.gd
```

```text
test/core/runtime/
├── DistanceSensorRuntimeUnitTest.tscn
├── DistanceSensorRuntimeFactoryTest.tscn
└── DistanceSensorRuntimePipelineIntegrationTest.tscn
```

## 3. Runtime Unit constructor

```gdscript
DistanceSensorRuntimeUnit.new(
    device_id: String,
    configuration: DeviceConfiguration,
    sensor: DistanceSensorDevice,
    provider: Object
)
```

## 4. Unit API

```gdscript
runtime_initialize(bus) -> ValidationReport
runtime_set_ready() -> ValidationReport
runtime_start() -> ValidationReport
runtime_shutdown() -> ValidationReport
get_runtime_input_endpoint(port_id) -> Callable
publish_measurement() -> ValidationReport
get_sensor() -> DistanceSensorDevice
get_state() -> State
```

## 5. Unit state

```text
CREATED
INITIALIZED
READY
RUNNING
SHUTDOWN
```

Invalid transition devuelve Structural Error sin cambiar estado.

Shutdown es idempotente y válido desde cualquier estado.

## 6. Unit validation

Constructor state válido requiere:

- Device ID no vacío;
- Configuration válida;
- Configuration Device ID coincide;
- Sensor no null y vivo;
- Provider no null y vivo;
- Provider behavior completo.

## 7. Configuration subset

Soportado exactamente:

```text
capabilities = [distance_measurement]
publishes = [distance_measurement]
subscribes = []
```

Additional requirements no cambian runtime 1.0.

## 8. Unit error codes

```text
distance_sensor_runtime_identity_invalid
distance_sensor_runtime_configuration_invalid
distance_sensor_runtime_sensor_invalid
distance_sensor_runtime_provider_invalid
distance_sensor_runtime_bus_missing
distance_sensor_runtime_state_invalid
distance_sensor_runtime_initialize_failed
distance_sensor_runtime_manifest_mismatch
distance_sensor_runtime_ready_failed
distance_sensor_runtime_start_failed
distance_sensor_runtime_shutdown_failed
distance_sensor_runtime_publish_not_running
```

## 9. Factory constructor

```gdscript
DistanceSensorRuntimeFactory.new()
```

Stateless para build; conserva released Handle IDs para idempotencia de release por instancia scoped.

## 10. Factory constants

```text
PROFILE_ID = velocity.distance_sensor.ideal
PROFILE_VERSION = 1
DEPENDENCY_ID = distance_provider
CONTEXT = Simulation
```

## 11. Factory build

Secuencia:

```text
validate Request
→ validate exact Key
→ validate supported Configuration
→ resolve exact Binding
→ require BORROWED
→ validate Provider behavior
→ create DistanceSensorDevice
→ create DistanceSensorRuntimeUnit
→ create RuntimeDeviceHandle
→ return BuildResult
```

## 12. Handle

```text
Primary Runtime Object:
DistanceSensorRuntimeUnit

Host Objects:
[DistanceSensorDevice]

Dependency Bindings:
[distance_provider BORROWED]
```

## 13. Factory release

Secuencia:

```text
validate Handle
→ validate exact Key
→ obtain Unit/Sensor
→ require Sensor detached
→ free Sensor
→ mark Handle released
```

Repeated release devuelve Report válido sin double free.

## 14. Factory error codes

```text
distance_sensor_factory_request_missing
distance_sensor_factory_request_invalid
distance_sensor_factory_key_mismatch
distance_sensor_factory_configuration_unsupported
distance_sensor_factory_provider_missing
distance_sensor_factory_provider_invalid
distance_sensor_factory_provider_ownership_invalid
distance_sensor_factory_handle_invalid
distance_sensor_factory_primary_mismatch
distance_sensor_factory_host_mismatch
distance_sensor_factory_release_still_attached
distance_sensor_factory_release_failed
```

## 15. Registry descriptor

Integration crea:

```text
RuntimeFactoryDescriptor
Key:
velocity.distance_sensor.ideal / 1 / Simulation

Dependency Specs:
distance_provider / BORROWED
```

## 16. Effective Configuration fixture

```text
device_id:
runtime_distance_sensor

profile:
velocity.distance_sensor.ideal / 1

context:
Simulation

capabilities:
distance_measurement

publishes:
distance_measurement

subscribes:
none
```

## 17. Full integration

Provider:

```text
ManualDistanceProvider
BORROWED
```

Lifecycle:

```text
CompositionRuntime activate
→ Factory build CREATED
→ Godot Host attach Sensor
→ Unit initialize
→ ready
→ start
→ ACTIVE
```

Test subscribes observer to active Bus and calls:

```gdscript
unit.publish_measurement()
```

Verifica:

- BusMessage;
- source ID;
- topic;
- DistanceMeasurement;
- distance;
- valid;
- timestamp.

## 18. Shutdown integration

```text
runtime shutdown
→ Unit shutdown
→ Host detach
→ Factory release
→ SHUTDOWN
```

Verifica:

- Sensor Node freed;
- Provider permanece vivo;
- Bus reference cleared;
- release once;
- no active Handles.

## 19. Tests previstos

### RuntimeUnitTest

- constructor validation;
- lifecycle transitions;
- Reports;
- publish gate;
- endpoint invalid;
- shutdown idempotent;
- Provider preserved.

### RuntimeFactoryTest

- Request validation;
- exact Key;
- config subset;
- health rejection;
- missing Provider;
- invalid behavior;
- BORROWED requirement;
- Handle shape;
- no lifecycle in build;
- release detached;
- attached release rejection;
- idempotency.

### PipelineIntegrationTest

- canonical Profile;
- Catalog;
- SystemProfile;
- Graph;
- Registry;
- Compiler;
- Plan;
- Runtime;
- real adapters;
- real factory;
- Manual Provider;
- publish;
- shutdown;
- release.

## 20. Implementation order

```text
1. RuntimeUnit.
2. RuntimeUnitTest.
3. RuntimeFactory.
4. RuntimeFactoryTest.
5. Full pipeline integration.
6. Runtime Suite.
7. Run All.
8. Refactor audit.
9. Baseline documentation.
```

## 21. Baselines preservadas

No se modifica:

- DistanceSensorInitializationTest;
- DistanceSensorLifecycleV2Test;
- DistanceSensorMessageTest;
- Managed Runtime Adapter tests;
- CompositionRuntime tests.

Se crean pruebas sucesoras.

## 22. Criterios de aceptación

Los 22 criterios ADR-013 son obligatorios.

Conteos se fijan después de implementar pruebas.

## 23. Estado

```text
DISTANCE SENSOR RUNTIME SLICE 1.0
IMPLEMENTADO
VERIFICADO
BASELINE ACEPTADA
```

```text
DistanceSensorRuntimeUnitTest: 20 checks
DistanceSensorRuntimeFactoryTest: 16 checks
DistanceSensorRuntimePipelineIntegrationTest: 19 checks
Total: 3 tests / 55 checks
Runtime Suite: 20 / 475
Run All: 79 / 2317
RESULT: PASS
```

Commit:

```text
53ffe1d feat(runtime): add distance sensor runtime slice
```
