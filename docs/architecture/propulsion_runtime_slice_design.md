# Propulsion Runtime Slice — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 04/10/2026 |
| ADR | ADR-015 — Propulsion Command Actuation and Force Sink Boundary |
| Alternativa | D — Actuator especializado con modelo y sink explícitos |
| Alcance | PropulsionCommand hasta fuerza longitudinal acotada |
| Implementación | AUTORIZADA DESPUÉS DEL COMMIT DOCUMENTAL |

## 1. Propósito

Construir el primer actuator longitudinal de Velocity:

```text
PropulsionCommand
→ fuerza longitudinal finita y acotada
→ PropulsionForceSink
```

El Slice valida actuation. No implementa todavía un vehículo físico completo.

## 2. Componentes previstos

```text
core/propulsion/propulsion_command.gd
core/propulsion/longitudinal_propulsion_model.gd

core/profile/builtin_device_profiles.gd

integration/godot/propulsion/propulsion_runtime_unit.gd
integration/godot/propulsion/propulsion_runtime_factory.gd
```

Tests:

```text
test/core/propulsion/PropulsionCommandTest.tscn
test/core/propulsion/LongitudinalPropulsionModelTest.tscn
test/core/propulsion/PropulsionRuntimeUnitTest.tscn
test/core/propulsion/PropulsionRuntimeFactoryTest.tscn
test/core/propulsion/PropulsionRuntimePipelineIntegrationTest.tscn
```

Fixtures auxiliares permanecerán bajo `test/core/propulsion/`.

## 3. Flujo

```text
PropulsionCommand Source
→ BusTopics.PROPULSION_COMMAND
→ DeviceBus
→ ManagedRuntimeCommunicationBinder
→ RuntimeSourceFilteredSubscription
→ PropulsionRuntimeUnit
→ LongitudinalPropulsionModel
→ PropulsionForceSink
```

## 4. PropulsionCommand

Ruta:

```text
core/propulsion/propulsion_command.gd
```

Clase:

```gdscript
class_name PropulsionCommand
```

Constructor conceptual:

```gdscript
PropulsionCommand.new(
    normalized_thrust: float,
    timestamp: float
)
```

API:

```gdscript
get_normalized_thrust() -> float
get_timestamp() -> float
is_valid() -> bool
```

Validación:

```text
normalized_thrust finite
-1.0 <= normalized_thrust <= 1.0
timestamp finite
timestamp >= 0.0
```

No tendrá setters públicos.

## 5. LongitudinalPropulsionModel

Ruta:

```text
core/propulsion/longitudinal_propulsion_model.gd
```

Clase:

```gdscript
class_name LongitudinalPropulsionModel
```

Constructor conceptual:

```gdscript
LongitudinalPropulsionModel.new(
    max_forward_force_newtons: float,
    max_reverse_force_newtons: float
)
```

API:

```gdscript
get_max_forward_force_newtons() -> float
get_max_reverse_force_newtons() -> float
calculate_force_newtons(normalized_thrust: float) -> float
is_force_within_limits(force_newtons: float) -> bool
is_valid() -> bool
```

Validación:

```text
limits finite
limits >= 0.0
```

Cálculo:

```text
positive → thrust * forward max
negative → thrust * reverse max
zero → 0.0
invalid input → 0.0 fail-neutral
```

RuntimeUnit nunca llama al modelo con command inválido.

### Geometría longitudinal 1.0

El modelo produce un escalar firmado en Newtons:

```text
positivo → forward longitudinal
negativo → reverse longitudinal
```

La transferencia es lineal; no existe dispersión radial.

El modelo no decide axis `Vector3`, origen, punto de aplicación, número de toberas o torque. El futuro sink físico convierte el escalar en una resultante sobre el eje local del vehículo.

## 6. PropulsionForceSink

Behavior requerido:

```gdscript
apply_propulsion_force(
    force_newtons: float,
    timestamp: float
) -> bool
```

No se crea una clase base abstracta por conveniencia.

Factory y RuntimeUnit validan behavior mediante método explícito.

Ownership:

```text
BORROWED
```

Fixture determinista:

```text
PropulsionTestForceSink
last_force_newtons
last_timestamp
apply_count
accepts_force
```

## 7. Builtin DeviceProfile

Se añade constructor canónico:

```gdscript
BuiltinDeviceProfiles.create_longitudinal_propulsion_actuator()
```

Profile:

```text
profile_id: velocity.propulsion.longitudinal
profile_version: 1
display_name: Linear Propulsion Actuator
primary_role: actuator
capabilities: [longitudinal_propulsion_force]
publishes: []
subscribes: [propulsion_command]
canonical: true
```

El Profile no contiene límites de fuerza activos. El modelo llega como dependencia runtime explícita.

## 8. Effective DeviceConfiguration

Configuration 1.0 soportada exactamente:

```text
profile_id: velocity.propulsion.longitudinal
profile_version: 1
activation_context: Simulation
enabled_capabilities: [longitudinal_propulsion_force]
enabled_publishes: []
enabled_subscribes: [propulsion_command]
```

Cualquier capability o Topic adicional se rechaza en Factory 1.0.

## 9. Factory Key

```text
velocity.propulsion.longitudinal / 1 / Simulation
```

No existe fallback, latest ni Hardware key.

## 10. Runtime dependencies

```text
propulsion_model / BORROWED
propulsion_force_sink / BORROWED
```

`propulsion_model` debe ser `LongitudinalPropulsionModel` válido.

`propulsion_force_sink` debe ser Object válido con:

```text
apply_propulsion_force
```

Ambos bindings se preservan en `RuntimeDeviceHandle`.

## 11. PropulsionRuntimeUnit

Ruta:

```text
integration/godot/propulsion/propulsion_runtime_unit.gd
```

Clase:

```gdscript
class_name PropulsionRuntimeUnit
```

Estado:

```text
CREATED
INITIALIZED
READY
RUNNING
SHUTDOWN
```

Constructor conceptual:

```gdscript
PropulsionRuntimeUnit.new(
    device_id,
    configuration,
    model,
    force_sink
)
```

## 12. Lifecycle

### initialize

```text
CREATED required
unit valid
DeviceBus non-null
→ INITIALIZED
```

El Bus se acepta por consistencia managed, pero el Unit no publica.

### set_ready

```text
INITIALIZED → READY
```

### start

```text
READY → RUNNING
```

### shutdown

```text
any non-terminal state → SHUTDOWN
SHUTDOWN → valid no-op
```

Shutdown:

- impide output futuro;
- limpia referencias activas cuando sea seguro;
- no libera model;
- no libera sink.

## 13. Runtime input endpoint

Port exacto:

```text
in.propulsion_command
```

API:

```gdscript
get_runtime_input_endpoint(
    port_id: StringName
) -> Callable
```

Comportamiento:

```text
exact port → Callable válido
unknown/empty port → Callable vacío
```

El endpoint permanece estructuralmente disponible para bind antes de initialize.

La actuation exige estado `RUNNING`.

## 14. Message validation

El endpoint valida defensivamente:

```text
BusMessage type
message.is_valid()
message.topic == propulsion_command
message timestamp finite and >= 0
payload is PropulsionCommand
payload.is_valid()
payload timestamp == message timestamp
```

Source ID se filtra mediante `RuntimeSourceFilteredSubscription` según la ConnectionDirective.

El Unit no implementa un segundo registro de Sources.

## 15. Force calculation

Solo después de validar el command:

```text
force_newtons = model.calculate_force_newtons(
    command.normalized_thrust
)
```

Luego revalida:

```text
force finite
model.is_force_within_limits(force)
```

Neutral:

```text
command 0.0
→ sink recibe force 0.0
```

Esto preserva estado explícito del actuator.

## 16. Sink invocation

```gdscript
var accepted: Variant = force_sink.call(
    &"apply_propulsion_force",
    force_newtons,
    timestamp
)
```

Éxito requiere:

```text
typeof(accepted) == TYPE_BOOL
accepted == true
```

Cualquier otro resultado produce Issue observable y no termina el Runtime.

## 17. Actuation result observable

Estado previsto:

```text
_has_actuation_result: bool
_last_force_newtons: float
_last_actuation_report: ValidationReport
```

API:

```gdscript
has_actuation_result() -> bool
get_last_force_newtons() -> float
get_last_actuation_report() -> ValidationReport
```

Cada mensaje reemplaza el resultado anterior.

Success:

```text
has result = true
last force = bounded force
report empty
```

Failure:

```text
has result = true
last force = 0.0
report contains exact Issue
```

Un mensaje válido posterior puede recuperar el estado observable.

## 18. Issue codes previstos

```text
propulsion_runtime_state_invalid
propulsion_runtime_message_invalid
propulsion_runtime_topic_mismatch
propulsion_runtime_timestamp_invalid
propulsion_runtime_payload_invalid
propulsion_runtime_timestamp_mismatch
propulsion_runtime_force_invalid
propulsion_runtime_force_out_of_bounds
propulsion_runtime_sink_rejected
propulsion_runtime_sink_result_invalid
```

Factory:

```text
propulsion_factory_request_missing
propulsion_factory_request_invalid
propulsion_factory_key_mismatch
propulsion_factory_configuration_unsupported
propulsion_factory_model_missing
propulsion_factory_model_invalid
propulsion_factory_model_ownership_invalid
propulsion_factory_sink_missing
propulsion_factory_sink_invalid
propulsion_factory_sink_ownership_invalid
propulsion_factory_handle_invalid
propulsion_factory_primary_mismatch
propulsion_factory_host_mismatch
propulsion_factory_release_active
```

Los nombres definitivos se congelan con los tests unitarios.

## 19. PropulsionRuntimeFactory

Ruta:

```text
integration/godot/propulsion/propulsion_runtime_factory.gd
```

Clase:

```gdscript
class_name PropulsionRuntimeFactory
```

Constantes:

```text
PROFILE_ID = velocity.propulsion.longitudinal
PROFILE_VERSION = 1
MODEL_DEPENDENCY_ID = propulsion_model
SINK_DEPENDENCY_ID = propulsion_force_sink
```

Build produce:

```text
Primary: PropulsionRuntimeUnit
Host Objects: []
Bindings: model + sink BORROWED
State: CREATED
```

Build no:

- configura Bus;
- hace bind;
- initialize;
- ready;
- start;
- aplica fuerza;
- crea Node;
- toca SceneTree.

## 20. Release

Release acepta:

```text
Unit CREATED
Unit SHUTDOWN
```

Release rechaza:

```text
INITIALIZED
READY
RUNNING
```

No existen Host Objects owned.

Release:

- valida Handle y Primary exactos;
- exige Host Objects vacío;
- no libera dependencies;
- marca Handle como liberado;
- repeated release es no-op válido.

## 21. Full pipeline fixture

Se utilizará una fuente de prueba declarativa que publique `PropulsionCommand`.

Topología:

```text
propulsion_command_source
out.propulsion_command
→
linear_propulsion_actuator
in.propulsion_command
```

Registry:

```text
Test source factory
PropulsionRuntimeFactory production
```

Dependencies target:

```text
LongitudinalPropulsionModel
PropulsionTestForceSink
```

## 22. Full pipeline assertions

Debe comprobar:

1. Profile canónico válido.
2. Catalog compila.
3. SystemProfile compila.
4. Graph ensambla una Connection.
5. Registry compila.
6. Plan contiene dos Devices y una Directive.
7. CompositionRuntime activa.
8. binder crea source-filtered subscription.
9. Unit target queda `RUNNING`.
10. forward command produce fuerza exacta.
11. reverse command respeta reverse max.
12. neutral command produce `0.0` explícito.
13. source identity incorrecta no llega al sink.
14. sink rejection queda observable.
15. command posterior recupera.
16. shutdown limpia binding/runtime.
17. borrowed model y sink sobreviven.
18. release no destruye dependencias.

## 23. Unit tests previstos

### PropulsionCommandTest

- construcción;
- boundaries;
- non-finite;
- timestamp;
- API de solo lectura;
- Topic canónico preservado.

### LongitudinalPropulsionModelTest

- limits válidos;
- invalid limits;
- forward mapping;
- reverse mapping;
- reverse disabled;
- neutral;
- bounds;
- no Godot physics API.

### PropulsionRuntimeUnitTest

- validation;
- lifecycle;
- endpoint exacto;
- no output antes de RUNNING;
- valid forward/reverse/neutral;
- invalid envelope/payload/timestamps;
- force revalidation;
- sink false;
- sink non-bool;
- recovery;
- shutdown idempotente;
- borrowed dependencies preserved.

### PropulsionRuntimeFactoryTest

- null/invalid Request;
- incorrect Key;
- unsupported Configuration;
- missing dependencies;
- invalid model/sink;
- incorrect ownership;
- Handle shape;
- Host Objects vacío;
- Unit `CREATED`;
- build sin lifecycle/output;
- active release rejected;
- CREATED/SHUTDOWN release accepted;
- dependencies preserved;
- repeated release idempotent.

### PropulsionRuntimePipelineIntegrationTest

- declarative pipeline completo;
- source filtering;
- bounded force output;
- sink failure recovery;
- shutdown;
- release;
- borrowed preservation.

## 24. Orden de implementación

```text
1. PropulsionCommand.
2. LongitudinalPropulsionModel.
3. Builtin Propulsion Profile.
4. PropulsionRuntimeUnit.
5. PropulsionRuntimeFactory.
6. Full pipeline integration.
7. Propulsion Suite.
8. Runtime Suite.
9. Run All.
10. Refactor audit.
11. Baseline documentation.
```

Cada incremento usa una Delivery completa y un commit separado cuando corresponda.

## 25. Evolución hacia C

Playable Vehicle Composition añadirá:

```text
VehicleControlRouterRuntimeUnit
```

Flujo futuro:

```text
InputRuntimeUnit
→ VehicleControlCommand
→ VehicleControlRouterRuntimeUnit
→ PropulsionCommand
→ PropulsionRuntimeUnit 1.0
→ RigidBodyPropulsionForceSink
→ RigidBody3D
```

No se modifica Propulsion Runtime 1.0 para añadir routing.

## 26. Fuera de alcance

- VehicleControlRouter;
- brake force;
- steering force/torque;
- transmission;
- traction;
- boost;
- energy;
- drag;
- hover;
- `RigidBody3D` adapter;
- vehículo compuesto;
- pista;
- cámara;
- HUD;
- hardware.

## 27. Seguridad

```text
El usuario puede fallar.
El simulador no.
```

Aplicado como:

- fail before force;
- fail-neutral model;
- finite validation;
- explicit bounds;
- no force before RUNNING;
- no ownership ambiguity;
- sink rejection observable;
- recoverable next command;
- Hardware blocked;
- no global state.

## 28. Baseline de partida

```text
HEAD: 3a1f7de
Input Suite: 6 tests / 101 checks PASS
Runtime Suite: 20 tests / 475 checks PASS
Run All: 85 tests / 2418 checks PASS
Tooling: 126 tests PASS
```

Los conteos nuevos se fijarán únicamente mediante Dashboard autoritativo.

## 29. Estado

```text
PROPULSION RUNTIME SLICE DESIGN 1.0
ACTIVO
ALTERNATIVA D APROBADA
IMPLEMENTACIÓN AUTORIZADA DESPUÉS DEL COMMIT DOCUMENTAL
```
