Misión del proyecto

Diseñar y desarrollar un módulo de propulsión antigravitatoria completamente autónomo, 
desacoplado y reutilizable, capaz de operar de forma independiente mediante sensores, 
control local (MCU), actuadores y telemetría, para posteriormente integrarse sin 
modificaciones en el proyecto Velocity.

Filosofía

No programamos nodos. Programamos dispositivos.

Dispositivo
↓
Electrónica
↓
Firmware
↓
Interfaz de comunicación
↓
Representación en Godot

La primera decisión arquitectónica - capas del sistema.

Mundo físico
		│
		▼
Sensores
		│
		▼
Bus interno
		│
		▼
MCU
		│
		▼
Bus interno
		│
		▼
Actuadores
		│
		▼
Resultado físico

Y por encima de todo esto:

Telemetría

que observa absolutamente todo sin intervenir.

El orden de construcción

	Estándares del proyecto (la constitución).
	Arquitectura del dispositivo genérico (qué es un dispositivo).
	Arquitectura del sensor genérico.
	Bus interno (nuestra abstracción inspirada en I²C/CAN).
	Sistema de telemetría.
	Sensor de distancia (primer dispositivo real).
	IMU.
	Sensor de temperatura.
	MCU del Hover Module.
	Actuador del propulsor.
	Hover Module completo.
	Pruebas y ajuste hasta validarlo.
	
		Ningún dispositivo puede acceder directamente al estado interno de otro dispositivo.
		Toda comunicación debe realizarse exclusivamente a través del bus de comunicación.
	
¿Qué es un dispositivo?
	Un dispositivo es cualquier elemento del sistema capaz de:

		+ poseer un estado
		+ recibir información
		+ producir información
		+ ejecutar una función
		+ reportar su estado
		+ fallar

Es decir, un sensor y una computadora solo se diferencian por lo que hacen, 
no por cómo existen dentro del sistema.

Estados estándar
	todos los dispositivos deberían compartir exactamente los mismos estados.
	
	- OFFLINE
	- BOOTING
	- INITIALIZING
	- READY
	- RUNNING
	- WARNING
	- DEGRADED
	- FAULT
	- SHUTDOWN
	
Capacidades
Salud del dispositivo (Health)
Diagnósticos

Estrcutura

Velocity
└── Hover Module
	├── Sensores
	├── Actuadores
	├── MCU
	├── Bus interno
	├── AGCS
	├── Telemetría
	└── Gestión de fallos
	
Nivel 0 - Dispositivo

No "sensor".

No "raycast".

No "acelerómetro".

Más abajo todavía.

Todo componente electrónico debería compartir el mismo modelo mental.

Un dispositivo posee:

identidad
estado
capacidades
interfaz de comunicación
telemetría
diagnóstico

Device !

aparecen las especializaciones
Device
│
├── Sensor
│
├── Actuator
│
├── Controller
│
└── PowerDevice

Y de ahí:

Sensor
│
├── Distance Sensor
├── Temperature Sensor
├── Gyroscope
├── Accelerometer
├── Pressure Sensor
└── ...
