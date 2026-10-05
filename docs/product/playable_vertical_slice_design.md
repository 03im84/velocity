# Playable Vertical Slice — Diseño de Producto

| Campo | Valor |
|---|---|
| Estado | OBJETIVO ACTIVO |
| Versión | 1.2 |
| Fecha | 03/10/2026 |
| Última revisión | 04/10/2026 |
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

El jugador puede:

1. iniciar una sesión de conducción;
2. acelerar;
3. frenar o reducir impulso;
4. girar;
5. mantener hover estable;
6. recorrer un circuito;
7. atravesar checkpoints válidos;
8. completar una vuelta;
9. reiniciar de forma segura.

## 4. Milestones requeridos

```text
Input Runtime Slice                 COMPLETED
Propulsion Runtime Slice            COMPLETED
Hover Physics Slice                 ACTIVE
Playable Vehicle Composition        PLANNED
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

Contrato físico:

```text
resultante longitudinal escalar
transferencia lineal
sin dispersión radial
```

Baseline:

```text
Propulsion Suite: 6 tests / 143 checks
Runtime Suite:   20 tests / 475 checks
Run All:         91 tests / 2561 checks
RESULT: PASS
```

Último commit del Slice:

```text
bc838d8 test(propulsion): add runtime pipeline integration
```

Tradeoff preservado:

Propulsion 1.0 entrega un actuator seguro, no un `RigidBody3D` móvil. Playable Vehicle Composition añadirá el router y el sink físico alrededor de esta baseline.

## 7. Siguiente milestone de producto

```text
Hover Physics Slice 1.0
```

Debe mantener altura antigravitatoria estable mediante fuerzas acotadas y una política spring-damper segura, reutilizando Distance Sensor Runtime sin mezclar todavía vehicle composition, cámara o pista final.

Su problema, alternativas, ADR y diseño deben cerrarse antes de implementar.

## 8. Fuera de alcance del Vertical Slice 1.0

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

## 9. Regla de prioridad

Cada milestone nuevo debe responder:

> ¿Acerca directamente a completar una vuelta jugable?

Si no y tampoco desbloquea un requisito, se difiere.

## 10. Estado actual

```text
Foundation técnica:          COMPLETA
Input Runtime Slice 1.0:     COMPLETADO
Propulsion Runtime Slice 1.0: COMPLETADO
Hover Physics Slice 1.0:     YOU ARE HERE
Target:                       PLAYABLE VERTICAL SLICE 1.0
```
