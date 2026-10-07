# Playable Vertical Slice — Diseño de Producto

| Campo | Valor |
|---|---|
| Estado | OBJETIVO ACTIVO |
| Versión | 1.3 |
| Fecha | 03/10/2026 |
| Última revisión | 07/10/2026 |
| Alcance | Primera vuelta jugable completa |

## 1. Propósito

Crear una experiencia tangible que demuestre que la plataforma Velocity puede producir juego sobre su arquitectura modular.

## 2. Definición de terminado

```text
Una nave antigravitatoria
+
un circuito simple cerrado
+
input
+
propulsion
+
hover
+
camera
+
checkpoints
+
HUD mínimo
+
una vuelta completa
```

## 3. Experiencia objetivo

El jugador puede iniciar una sesión, acelerar, frenar o reducir impulso, girar, mantener hover estable, recorrer un circuito, atravesar checkpoints, completar una vuelta y reiniciar de forma segura.

## 4. Milestones requeridos

```text
Input Runtime Slice                 COMPLETED
Propulsion Runtime Slice            COMPLETED
Hover Physics Slice                 COMPLETED
Playable Vehicle Composition        ACTIVE
Simple Track Scene                  PLANNED
Chase Camera                        PLANNED
Checkpoint and Lap Loop             PLANNED
Minimal HUD                         PLANNED
```

## 5. Input Runtime Slice completado

```text
Godot Input
→ GodotInputIntentProvider
→ InputRuntimeUnit
→ VehicleControlCommand
→ DeviceBus
```

```text
Input Suite: 6 tests / 101 checks PASS
```

## 6. Propulsion Runtime Slice completado

```text
PropulsionCommand
→ PropulsionRuntimeUnit
→ LongitudinalPropulsionModel
→ PropulsionForceSink
```

```text
Propulsion Suite: 6 tests / 143 checks PASS
```

## 7. Hover Physics Slice completado

```text
DistanceSensorRuntimeUnit
→ DistanceMeasurement
→ HoverPointRuntimeUnit
→ HoverSpringDamperModel
→ HoverForceSink
```

Policy:

```text
equilibrium force
+ spring
- damping
bounded lift-only output
temporal safety
single-sample history
```

Baseline:

```text
Hover Suite:   7 tests / 151 checks
Runtime Suite: 20 tests / 475 checks
Run All:       98 tests / 2712 checks
RESULT: PASS
```

Último commit del Slice:

```text
adca199 test(hover): add runtime pipeline integration
```

Hover 1.0 demuestra estabilidad matemática 1D y pipeline Sensor-to-Hover. No aplica todavía fuerza a un `RigidBody3D` real.

## 8. Siguiente milestone de producto

```text
Playable Vehicle Composition 1.0
```

Debe componer las baselines existentes alrededor de un cuerpo explícito:

```text
Input Runtime
→ VehicleControlRouter
→ Propulsion Runtime
→ RigidBodyPropulsionForceSink

Distance Sensors
→ Hover Points
→ RigidBodyHoverForceSinks

→ RigidBody3D host
```

Debe decidir antes de implementar:

- ownership del cuerpo;
- frame local y ejes;
- puntos de aplicación;
- número inicial de hover points;
- routing de throttle/brake/steering;
- lifecycle de la composición;
- reset y spawn seguro.

## 9. Fuera de alcance del Vertical Slice 1.0

- arte final;
- IA;
- multiplayer;
- garage;
- progression;
- armas;
- campeonato;
- replay;
- hardware;
- cabinet;
- Raspberry Pi;
- telemetría persistente;
- optimización final.

## 10. Regla de prioridad

Cada milestone nuevo debe responder:

> ¿Acerca directamente a completar una vuelta jugable?

Si no y tampoco desbloquea un requisito, se difiere.

## 11. Estado actual

```text
Foundation técnica:                COMPLETA
Input Runtime Slice 1.0:           COMPLETADO
Propulsion Runtime Slice 1.0:      COMPLETADO
Hover Physics Slice 1.0:           COMPLETADO
Playable Vehicle Composition 1.0:  YOU ARE HERE
Target:                             PLAYABLE VERTICAL SLICE 1.0
```
