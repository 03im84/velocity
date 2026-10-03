# Playable Vertical Slice — Diseño de Producto

| Campo | Valor |
|---|---|
| Estado | OBJETIVO ACTIVO |
| Versión | 1.0 |
| Fecha | 03/10/2026 |
| Alcance | Primera vuelta jugable completa |

## Propósito

Crear una experiencia tangible que demuestre que la plataforma Velocity puede producir juego.

## Definición de terminado

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

## Experiencia objetivo

El jugador puede:

1. iniciar sesión de conducción;
2. acelerar;
3. frenar o reducir impulso;
4. girar;
5. mantener hover estable;
6. recorrer un circuito;
7. atravesar checkpoints válidos;
8. completar una vuelta;
9. reiniciar de forma segura.

## Milestones requeridos

```text
Input Runtime Slice
Propulsion Runtime Slice
Hover Physics Slice
Playable Vehicle Composition
Simple Track Scene
Chase Camera
Checkpoint and Lap Loop
Minimal HUD
```

## Fuera de alcance

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

## Regla de prioridad

Cada milestone nuevo debe responder:

> ¿Acerca directamente a completar una vuelta jugable?

Si no y tampoco desbloquea un requisito, se difiere.

## Estado actual

Foundation técnica completa.

Siguiente milestone:

```text
Input Runtime Slice 1.0
```
