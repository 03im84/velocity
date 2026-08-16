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
	
Estados estándar de Device

Lifecycle y Health son conceptos separados.

Lifecycle

Lifecycle responde:

¿En qué etapa operacional se encuentra el Device?

Estados:

CREATED

INITIALIZED

READY

RUNNING

SHUTDOWN

Secuencia normal:

CREATED
	↓
INITIALIZED
	↓
READY
	↓
RUNNING
	↓
SHUTDOWN

Health

Health responde:

¿En qué condición operacional se encuentra
el Device?

Estados:

HEALTHY

DEGRADED

CRITICAL

FAILED

Diagnósticos

Warnings y Faults son diagnósticos.

No son estados de Lifecycle.

Añadir un Warning o Fault no cambia
automáticamente Health.

La política responsable debe utilizar:

set_status()

Ejemplo válido:

Lifecycle:
RUNNING

Health:
DEGRADED

Warnings:
["temperature_near_limit"]
	
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


Configuración del panel Output para pruebas

Godot Editor:

Editor
→ Editor Settings
→ Run
→ Output
→ Always Clear Output on Play

Valor requerido durante pruebas manuales:

OFF

Aclaración:

Desactivar la limpieza automática mejora
la visibilidad de Output, pero no garantiza
que Run Current Scene inicie correctamente
la escena en todos los intentos.

Para verificaciones definitivas se preferirá
ejecución directa desde línea de comandos
en modo headless.

Run Current Scene puede utilizarse durante
desarrollo interactivo, pero una ejecución
STARTED_EMPTY no se considera resultado
de prueba.

Antes de ejecutar cada escena de prueba:

Limpiar manualmente el panel Output.

Razón:

La limpieza automática puede ocurrir después
de que una escena rápida haya comenzado a imprimir,
produciendo salida vacía o parcial.

No se añadirán esperas artificiales al código
de pruebas para compensar una configuración
del editor.

Ejecución autoritativa de pruebas

Las escenas pueden ejecutarse desde el editor
durante desarrollo interactivo.

Sin embargo, la aprobación final de un baseline
se realizará mediante Godot Console en modo headless.

Formato:

Godot_v4.7.1-stable_win64_console.exe
--headless
--path "."
"res://ruta/de/la/prueba.tscn"

Una prueba se considera aprobada únicamente cuando:

1. La salida contiene:

RESULT: PASS

2. El código de salida es:

0

Un código diferente de cero representa fallo.

PowerShell:

Después de ejecutar la prueba:

$LASTEXITCODE

debe devolver:

0

Run Current Scene no será utilizado como única
evidencia de aprobación porque se observaron
ejecuciones STARTED_EMPTY de forma intermitente.

Configuración recomendada del editor:

Always Clear Output on Play:
OFF

Esta configuración mejora la observación manual,
pero no sustituye la ejecución headless.

Velocity PowerShell Test Runner

Archivo:

test/tools/run_godot_tests.ps1

Variable de entorno recomendada:

GODOT_CONSOLE

Ejemplo:

$env:GODOT_CONSOLE =
"C:\Path\Godot_v4.7.1-stable_win64_console.exe"

Ejecutar una prueba:

.\test\tools\run_godot_tests.ps1
-Scene "res://ruta/Test.tscn"

Repetir una prueba:

.\test\tools\run_godot_tests.ps1
-Scene "res://ruta/Test.tscn"
-Repeat 5

Ejecutar todas las pruebas descubiertas:

.\test\tools\run_godot_tests.ps1
-All

Criterio de aprobación:

Salida de escena:

RESULT: PASS

Exit code de escena:

0

Resultado del runner:

RESULT: PASS

Exit code del runner:

0

Criterio de fallo:

Una escena devuelve un código distinto de cero.

El runner registra:

Status:
FAIL

El runner termina con:

Exit code:
1

Exclusiones automáticas:

test/infrastructure/

device_bus_failure_isolation_test.tscn

Las verificaciones que producen errores
intencionales no forman parte de la regresión
regular.

Estado del Velocity PowerShell Test Runner:

COMPLETAMENTE VERIFICADO

Última regresión:

Escenas descubiertas:
19

Passed:
19

Failed:
0

Resultado:
PASS

Exit code:
0