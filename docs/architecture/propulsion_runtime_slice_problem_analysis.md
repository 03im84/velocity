# Propulsion Runtime Slice 1.0 — Problema, análisis y alternativas

| Campo | Valor |
|---|---|
| Estado | ALTERNATIVA D IMPLEMENTADA Y VERIFICADA |
| Fecha | 04/10/2026 |
| Baseline | 3a1f7de — docs(tools): record delivery rollback baseline |
| Target | Playable Vertical Slice 1.0 |
| Siguiente fase | ADR-015 y Propulsion Runtime Slice Design 1.0 |

## 1. Punto de partida

Velocity dispone de:

```text
Input Runtime Slice 1.0
→ VehicleControlCommand
→ vehicle_control_command
→ DeviceBus
```

También dispone del topic canónico histórico:

```text
propulsion_command
```

Todavía no existe:

- payload `PropulsionCommand`;
- modelo de conversión a fuerza;
- Propulsion RuntimeUnit;
- Propulsion RuntimeFactory;
- sink de fuerza;
- integración completa de propulsión;
- `RigidBody3D` de producto;
- router que descomponga `VehicleControlCommand` en comandos especializados.

## 2. Problema

El siguiente milestone debe convertir una orden especializada de propulsión en una salida longitudinal de fuerza:

```text
PropulsionCommand
→ validación
→ limitación
→ fuerza longitudinal
→ PropulsionForceSink
```

Debe hacerlo sin:

- permitir fuerza no acotada;
- acoplar Core a `RigidBody3D`;
- trasladar física a Input;
- interpretar steering;
- inventar braking físico sin velocidad o masa;
- descubrir SceneTree;
- crear singleton o autoload;
- introducir Hardware Runtime;
- mezclar hover con propulsión longitudinal.

## 3. Restricciones ya aceptadas

### ADR-014

Input produce intención completa:

```text
VehicleControlCommand
throttle
steering
brake
```

Input no debe:

- aplicar fuerzas;
- publicar fuerza de propulsion;
- conocer el cuerpo del vehículo.

### Runtime Construction

- Factory construct-only;
- dependencias explícitas;
- lifecycle administrado;
- Factory no adjunta ni inicia;
- ownership declarado;
- Simulation-only.

### Managed Runtime Boundary

- target runtime expone endpoint mediante `get_runtime_input_endpoint()`;
- binder filtra por Source ID y Topic;
- publicación y recepción pasan por DeviceBus;
- Host no descubre SceneTree.

### Product Roadmap

Propulsion Runtime Slice debe entregar:

- Propulsion Profile;
- RuntimeUnit;
- Factory;
- bounded command;
- force output;
- full pipeline.

## 4. Ambigüedad que debe resolverse

`VehicleControlCommand` no es igual a `PropulsionCommand`.

El primero contiene intención total del vehículo. El segundo debe representar exclusivamente una orden longitudinal para un actuador.

```text
VehicleControlCommand
├── throttle
├── steering
└── brake

PropulsionCommand
└── normalized_thrust
```

La traducción futura debe decidir cómo interactúan throttle, brake, modo de marcha, ayudas y políticas del vehículo. Esa responsabilidad no pertenece al actuador de propulsión.

## 5. Alternativa A — Input aplica fuerza directamente

```text
InputRuntimeUnit
→ RigidBody3D.apply_central_force
```

### Ventaja

- mínimo número de componentes.

### Costes

- viola ADR-014;
- acopla Input a física;
- impide sustituir input humano por IA o replay;
- mezcla intención y actuation;
- no utiliza composición runtime.

### Decisión

```text
RECHAZADA
```

## 6. Alternativa B — Propulsion consume VehicleControlCommand directamente

```text
vehicle_control_command
→ PropulsionRuntimeUnit
→ force sink
```

### Ventajas

- pipeline jugable corto;
- una sola conexión desde Input.

### Costes

- Propulsion debe conocer steering y brake aunque no le pertenecen;
- fija prematuramente la política throttle/brake;
- dificulta añadir transmission, traction, boost, AI o replay;
- deja `propulsion_command` sin responsabilidad real;
- convierte al actuator en router de vehículo.

### Decisión

```text
NO RECOMENDADA PARA 1.0
```

## 7. Alternativa C — Controller y Actuator completos en el mismo Slice

```text
VehicleControlCommand
→ VehicleControlRouterRuntimeUnit
→ PropulsionCommand
→ PropulsionRuntimeUnit
→ ForceSink
```

### Ventajas

- integración Input-to-force completa inmediatamente;
- responsabilidades separadas;
- usa el topic canónico.

### Costes

- duplica el alcance del milestone;
- exige resolver ahora braking, routing y futuras salidas de steering;
- introduce dos Profiles, dos RuntimeUnits y dos Factories;
- adelanta responsabilidad de Playable Vehicle Composition.

### Decisión

```text
VÁLIDA, PERO SOBREDIMENSIONADA PARA PROPULSION 1.0
```

## 8. Alternativa D — Actuator especializado con modelo y sink explícitos

```text
PropulsionCommand
→ PropulsionRuntimeUnit
→ LongitudinalPropulsionModel
→ bounded force_newtons
→ PropulsionForceSink
```

El command llega mediante:

```text
BusTopics.PROPULSION_COMMAND
```

El router `VehicleControlCommand → PropulsionCommand` queda para Playable Vehicle Composition.

### Ventajas

- una responsabilidad primaria: actuation longitudinal;
- respeta ADR-014;
- usa el topic canónico existente;
- Profile, RuntimeUnit y Factory singulares;
- fuerza determinista y acotada;
- testable sin `RigidBody3D`;
- sink concreto puede sustituirse;
- IA, replay o controller pueden producir el mismo command;
- no adelanta steering ni braking.

### Costes

- todavía no mueve una nave por sí solo;
- requiere un router futuro;
- introduce dos dependencias explícitas;
- `RigidBody3D` adapter queda fuera de este Slice.

### Decisión recomendada

```text
SELECCIONAR ALTERNATIVA D
```

## 9. Contrato propuesto de PropulsionCommand

Snapshot tratado como inmutable:

```text
normalized_thrust: float [-1, 1]
timestamp: float >= 0
```

Invariantes:

- valores finitos;
- rango cerrado;
- neutral `0.0` válido;
- positivo = forward;
- negativo = reverse si el modelo lo permite;
- no contiene Vector3;
- no contiene body, Node, bus o callbacks;
- no contiene steering o brake.

Topic:

```text
BusTopics.PROPULSION_COMMAND
```

## 10. Modelo lineal propuesto

Snapshot explícito:

```text
LongitudinalPropulsionModel
max_forward_force_newtons: float >= 0
max_reverse_force_newtons: float >= 0
```

Mapeo:

```text
thrust >= 0
→ thrust * max_forward_force_newtons

thrust < 0
→ thrust * max_reverse_force_newtons
```

Resultado:

```text
force_newtons dentro de
[-max_reverse_force_newtons, max_forward_force_newtons]
```

El modelo no:

- consulta velocidad;
- simula drag;
- aplica torque;
- decide brake;
- conoce orientation;
- conoce `RigidBody3D`.

Geometría 1.0:

```text
una fuerza escalar firmada
→ una resultante sobre el eje longitudinal futuro
```

No existe dispersión radial, cono de fuerza, reparto entre toberas, punto de aplicación o vectoring. La función de transferencia command-to-force es lineal; la geometría del actuator es longitudinal.

Un modelo con reverse máximo `0.0` neutraliza órdenes negativas de forma segura.

## 11. PropulsionForceSink behavior

Dependencia runtime explícita:

```text
propulsion_force_sink / BORROWED
```

Behavior propuesto:

```gdscript
apply_propulsion_force(
    force_newtons: float,
    timestamp: float
) -> bool
```

Responsabilidad:

> Recibir una fuerza longitudinal finita, acotada y timestamped.

El sink concreto futuro decide:

- eje local forward;
- punto de aplicación;
- llamada Godot Physics;
- relación con `RigidBody3D`.

El Slice 1.0 utilizará un sink determinista de prueba. El adapter de cuerpo pertenece a Playable Vehicle Composition.

## 12. Dependencias propuestas

```text
propulsion_model / BORROWED
propulsion_force_sink / BORROWED
```

Ambas sobreviven shutdown y release.

La Factory no crea ni libera dependencias borrowed.

## 13. Profile y Configuration propuestos

Factory Key:

```text
velocity.propulsion.longitudinal / 1 / Simulation
```

Role:

```text
DeviceRoles.ACTUATOR
```

Effective Configuration:

```text
capability: longitudinal_propulsion_force
publishes: none
subscribes: propulsion_command
```

Un actuator no publica `propulsion_command`; lo consume.

## 14. RuntimeUnit propuesto

Lifecycle:

```text
CREATED → INITIALIZED → READY → RUNNING → SHUTDOWN
```

Target endpoint:

```text
in.propulsion_command
```

Comportamiento durante RUNNING:

1. recibir `BusMessage` ya filtrado por source/topic;
2. validar payload `PropulsionCommand`;
3. validar timestamp;
4. calcular fuerza mediante modelo;
5. verificar finitud y bounds nuevamente;
6. llamar sink;
7. conservar resultado observable de la última actuation.

Fuera de RUNNING:

```text
no force output
```

Shutdown:

- no aplica fuerza nueva;
- elimina referencias runtime activas cuando corresponda;
- preserva model y sink borrowed;
- es idempotente.

## 15. Factory propuesta

`PropulsionRuntimeFactory`:

- valida Request exacto;
- valida Key y Configuration;
- exige ambas dependencias BORROWED;
- valida behavior del sink;
- valida modelo;
- construye RuntimeUnit en CREATED;
- produce Handle sin Host Objects;
- no adjunta;
- no ejecuta lifecycle;
- no aplica fuerza;
- release idempotente;
- no libera model o sink.

## 16. Full pipeline propuesto

```text
Test Propulsion Command Source
→ DeviceBus
→ source-filtered connection
→ PropulsionRuntimeUnit endpoint
→ LongitudinalPropulsionModel
→ PropulsionForceSink
→ observed bounded force
```

Pipeline declarativo completo:

```text
Profiles
→ Catalog
→ SystemProfile
→ DeviceGraph
→ Factory Registry
→ CompositionPlan
→ CompositionRuntime
→ ACTIVE
→ command
→ force output
→ SHUTDOWN
```

La fuente de prueba será reemplazada en Playable Vehicle Composition por un router real de control del vehículo.

## 17. Seguridad

- Simulation-only;
- command acotado;
- modelo explícito;
- output acotado;
- doble validación antes del sink;
- neutral command válido;
- no output fuera de RUNNING;
- sink failure observable;
- sin `RigidBody3D` en Core;
- sin autoload;
- sin singleton;
- sin service locator;
- sin thread;
- sin hardware activation;
- dependencies borrowed preservadas.

## 18. Fuera de alcance

- `VehicleControlCommand → PropulsionCommand` router;
- braking físico;
- steering;
- traction;
- transmission;
- boost;
- energy/fuel;
- drag;
- hover;
- torque;
- wheel/contact model;
- `RigidBody3D` adapter;
- vehicle body;
- camera;
- track;
- HUD;
- Hardware Runtime.

## 19. Pruebas sucesoras previstas

```text
PropulsionCommandTest
LongitudinalPropulsionModelTest
PropulsionRuntimeUnitTest
PropulsionRuntimeFactoryTest
PropulsionRuntimePipelineIntegrationTest
```

Integración debe comprobar:

- conexión source-to-actuator;
- source filtering;
- ACTIVE;
- fuerza forward;
- fuerza reverse limitada;
- neutral force;
- no output antes de RUNNING;
- sink rejection observable;
- shutdown;
- dependencies BORROWED preservadas;
- release idempotente.

## 20. Tradeoff aceptado si se selecciona D

Propulsion Runtime Slice 1.0 no produce todavía movimiento jugable completo.

Entrega un actuator seguro y componible. El wiring desde intención de jugador se completa en Playable Vehicle Composition mediante un router especializado.

Esto evita usar Input como controller físico y evita adelantar políticas de brake/steering antes de su diseño.

## 21. Gate de arquitectura

Decisión registrada:

```text
ALTERNATIVA D APROBADA
IMPLEMENTADA Y VERIFICADA
04/10/2026
```

Consecuencia:

1. redactar ADR-015;
2. redactar Propulsion Runtime Slice Design 1.0;
3. revisar nombres y contratos;
4. preparar commit documental;
5. solo después comenzar implementación.


## 22. Resultado de implementación

```text
PropulsionCommand
→ PropulsionRuntimeUnit
→ LongitudinalPropulsionModel
→ PropulsionForceSink
```

```text
Propulsion Suite: 6 tests / 143 checks PASS
Runtime Suite: 20 tests / 475 checks PASS
Run All: 91 tests / 2561 checks PASS
Refactor audit: PASS
```

Último commit del Slice:

```text
bc838d8 test(propulsion): add runtime pipeline integration
```
