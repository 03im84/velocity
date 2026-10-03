# ADR-013 — Distance Sensor Simulation Runtime Slice and Configuration Fidelity

| Campo | Valor |
|---|---|
| Estado | ACEPTADO — IMPLEMENTADO — VERIFICADO |
| Versión | 1.1 |
| Fecha | 03/10/2026 |
| Componentes | DistanceSensorRuntimeUnit, DistanceSensorRuntimeFactory, DistanceSensorDevice, Distance Provider, DeviceConfiguration |
| Alcance | Primer Device concreto activado mediante el pipeline runtime completo |

## 1. Contexto

Velocity ya implementa:

- CompositionRuntime 1.0;
- Managed Runtime Adapter Boundary 1.0;
- GodotNodeRuntimeHost;
- scoped dependency resolution;
- managed lifecycle;
- source-filtered communication.

Falta una Factory concreta que produzca un Device real.

## 2. Candidato

DistanceSensorDevice es el Device concreto más maduro.

Actualmente:

- es Node;
- compone Device lógico;
- recibe DeviceBus;
- recibe Distance Provider;
- publica BusMessage;
- expone lifecycle.

## 3. Discrepancia

Builtin Profile ideal declara:

```text
capabilities:
distance_measurement
health_reporting

publishes:
distance_measurement
health_report
```

DistanceSensorDevice solo implementa:

```text
distance_measurement
```

No publica HealthReport.

## 4. Decisión de fidelidad

Runtime Slice 1.0 soporta únicamente DeviceConfiguration efectiva:

```text
enabled capabilities:
- distance_measurement

enabled publishes:
- distance_measurement

enabled subscribes:
- none
```

Factory rechaza configuration que habilite `health_reporting` o `health_report`.

No se modifica el Profile canónico ni se finge soporte.

## 5. Contexto

Solo Simulation.

Hardware permanece bloqueado.

Factory Key exacta:

```text
velocity.distance_sensor.ideal
version 1
Simulation
```

## 6. Dependency

Dependency ID:

```text
distance_provider
```

Ownership 1.0:

```text
BORROWED
```

Provider debe exponer:

```gdscript
get_distance() -> float
is_valid() -> bool
```

Factory y RuntimeUnit no liberan Provider BORROWED.

## 7. Runtime Unit

Primary Runtime Object:

```text
DistanceSensorRuntimeUnit
```

Host Object:

```text
DistanceSensorDevice
```

Unit implementa managed lifecycle behaviors de ADR-012.

## 8. Factory

DistanceSensorRuntimeFactory es construct-only.

Build:

- valida Request exacto;
- valida configuration soportada;
- valida binding;
- crea DistanceSensorDevice sin inicializar;
- crea RuntimeUnit;
- crea Handle.

No adjunta, inicializa, inicia o suscribe.

## 9. Lifecycle

RuntimeUnit convierte bool de DistanceSensorDevice en ValidationReport.

Estados:

```text
CREATED
INITIALIZED
READY
RUNNING
SHUTDOWN
```

`publish_measurement()` solo delega durante RUNNING.

## 10. Initialize

`runtime_initialize(bus)` invoca:

```gdscript
sensor.initialize_sensor(
    configuration.device_id,
    bus,
    provider
)
```

Después verifica identidad y Manifest efectivo.

## 11. Shutdown

Debe ser best effort e idempotente para:

- CREATED;
- initialize parcial;
- INITIALIZED;
- READY;
- RUNNING;
- repeated cleanup.

Provider y Bus references se liberan por DistanceSensorDevice shutdown.

## 12. Endpoint behavior

Distance Sensor 1.0 no consume Ports.

```gdscript
get_runtime_input_endpoint(port_id) -> Callable
```

devuelve Callable inválida para todo Port ID.

No existen Connection Directives target para este slice.

## 13. Release

Factory release:

- exige Host Node detached;
- libera DistanceSensorDevice;
- no libera Provider BORROWED;
- es idempotente por Handle;
- registra Report si ownership no puede confirmarse.

## 14. Full pipeline

```text
Builtin DeviceProfile
→ DeviceCatalog
→ SystemProfile
→ DeviceGraphAssembler
→ DeviceGraphSnapshot
→ RuntimeFactoryRegistry
→ CompositionCompiler
→ CompositionPlan
→ CompositionRuntime
→ DistanceSensorRuntimeUnit
→ ACTIVE
→ publish BusMessage
→ SHUTDOWN
→ release
```

## 15. Alternativas rechazadas

### Habilitar health sin implementarlo

Rechazada por contrato falso.

### Quitar health del Profile en este milestone

Rechazada porque cambia definición canónica sin analizar versión sucesora.

### Factory modifica Manifest después de initialize

Rechazada por mutación engañosa.

### Factory ejecuta initialize

Rechazada por ADR-010.

### Provider global

Rechazado por service locator.

### TRANSFERRED Provider 1.0

No seleccionado. BORROWED demuestra integración sin introducir destrucción específica de Provider.

## 16. Seguridad

- Simulation-only;
- exact Key;
- exact config subset;
- exact dependency;
- no fallback;
- no Hardware;
- no active partial Handle;
- reverse cleanup;
- Provider preservado;
- Node detached before release.

## 17. Criterios de aceptación

1. RuntimeUnit managed behavior.
2. Factory construct-only.
3. Exact Profile ID/version/context.
4. Minimal effective config.
5. Unsupported health rejected.
6. Provider required.
7. Provider behavior validated.
8. Provider BORROWED.
9. Host Object Node explicit.
10. Initialize via CompositionRuntime.
11. Ready via CompositionRuntime.
12. Start via CompositionRuntime.
13. Publish only RUNNING.
14. BusMessage source identity.
15. DistanceMeasurement payload.
16. Shutdown idempotent.
17. Host detach before release.
18. Provider preserved.
19. Factory release idempotent.
20. Full pipeline integration PASS.
21. Runtime Suite PASS.
22. Run All PASS.

## 18. Fuera de alcance

- HealthReport publication;
- Profile version change;
- Hardware sensor;
- Physics Provider factory;
- Provider TRANSFERRED;
- calibration;
- polling scheduler;
- automatic measurement loop;
- Composition Root production;
- Supervisor;
- hot swap.

## 19. Estado

```text
ADR-013 1.1
ACEPTADO
IMPLEMENTADO
VERIFICADO
```

Baseline:

```text
Slice: 3 tests / 55 checks
Runtime Suite: 20 tests / 475 checks
Run All: 79 tests / 2317 checks
Failures: 0
Missing Metrics: 0
RESULT: PASS
```

Commit:

```text
53ffe1d feat(runtime): add distance sensor runtime slice
```
