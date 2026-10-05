# Playable Vertical Slice — Diseño de Producto

| Campo | Valor |
|---|---|
| Estado | OBJETIVO ACTIVO |
| Versión | 1.1 |
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
Propulsion Runtime Slice            ACTIVE
Hover Physics Slice                 PLANNED
Playable Vehicle Composition        PLANNED
Simple Track Scene                  PLANNED
Chase Camera                        PLANNED
Checkpoint and Lap Loop             PLANNED
Minimal HUD                         PLANNED
```

## 5. Input Runtime Slice completado

Flujo disponible:

```text
Godot Input
→ GodotInputIntentProvider
→ InputRuntimeUnit
→ VehicleControlCommand
→ DeviceBus
```

Baseline:

```text
Input Suite:    6 tests / 101 checks
Runtime Suite: 20 tests / 475 checks
Run All:       85 tests / 2418 checks
RESULT: PASS
```

Último commit del Slice:

```text
80c5118 test(input): add runtime pipeline integration
```

## 6. Siguiente milestone de producto

```text
Propulsion Runtime Slice 1.0
```

Debe convertir intención de propulsion validada en una salida de fuerza controlada y acotada, sin mezclar todavía hover, steering físico, cámara o pista.

Su problema, alternativas, ADR y diseño deben cerrarse antes de implementar.

## 7. Fuera de alcance del Vertical Slice 1.0

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

## 8. Regla de prioridad

Cada milestone nuevo debe responder:

> ¿Acerca directamente a completar una vuelta jugable?

Si no y tampoco desbloquea un requisito, se difiere.

## 9. Estado actual

```text
Foundation técnica:       COMPLETA
Input Runtime Slice 1.0:  COMPLETADO
Propulsion Runtime Slice: YOU ARE HERE
Target:                    PLAYABLE VERTICAL SLICE 1.0
```
