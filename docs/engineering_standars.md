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

Safe Simulation and System Integrity

Documento canónico:

docs/decisions/
VP-002 — The Simulation May Fail;
The Simulator Must Not.md

Regla:

La simulación puede fallar.

El simulador no.

Clasificación:

Structural Error

No puede activarse.

----------------------

Platform Safety Error

No puede ejecutarse.

----------------------

Simulation Hazard

Puede ejecutarse únicamente en
Simulation Mode.

Puede producir daño o fallo simulado.

----------------------

Hardware Safety Error

Puede simularse.

No puede activarse en Hardware Mode.

Estados de configuración:

Draft

Active Simulation

Active Hardware

Reglas:

Las definiciones canónicas son inmutables.

Las modificaciones utilizan Save As
o nuevas versiones.

Los cambios son transaccionales.

Un fallo conserva Last Known Good.

Los snapshots activos son inmutables.

Los recursos runtime tienen límites.

El usuario siempre puede detener
y recuperar la simulación.

Una prueba física peligrosa puede permitirse
en simulación sin permitirse en hardware.

No existe una operación genérica:

Ignore all errors.

DeviceBus Runtime Safety

Modelo:

Bounded FIFO Dispatch

Reentrant publish:

Enqueue.

No recursive dispatch.

Budgets obligatorios:

Default Publications:
1024

Default Callbacks:
8192

Default Pending:
512

Default Time:
50000 usec

Hard Publications:
16384

Hard Callbacks:
131072

Hard Pending:
8192

Hard Time:
500000 usec

Reglas:

No existe configuración unlimited.

DeviceBus utiliza DELIVER_ALL.

DeviceBus no implementa coalescing.

Cada dato tiene un propietario semántico.

DeviceBus realiza fan-out.

Consumers no republican mensajes sin cambios.

Derived Outputs utilizan contratos nuevos.

Un budget excedido aborta el Dispatch Cycle.

Las suscripciones permanentes sobreviven.

Un nuevo ciclo puede comenzar.

DeviceBus no es thread-safe.

Los callbacks deben ejecutarse en el thread
propietario.

Time Budget es protección de plataforma,
no resultado determinista de simulación.

GDScript Member Access

El operador de acceso a miembros no comenzará
una línea nueva.

Incorrecto:

object
	.property = value

object
	.method()

Correcto:

object.property = (
	value
)

object.method(
	argument
)

El identificador del objeto y el miembro
permanecerán en la misma línea:

object.property

ClassName.CONSTANT

instance.method()

Los argumentos y valores pueden dividirse
dentro de paréntesis.

Regla estricta:

El carácter "." nunca comenzará una línea
y nunca quedará separado del objeto
o clase al que pertenece.

Las cadenas de acceso permanecen en una
misma línea física.

Si la expresión resulta demasiado larga,
se crean variables intermedias.

Incorrecto:

object
	.method()

object
	.property

Correcto:

object.method()

object.property

Correcto con variable intermedia:

var result := object.method()

result.execute()

Velocity Test Dashboard

Launcher:

test/tools/
start_velocity_test_dashboard.bat

Aplicación:

test/tools/
velocity_test_dashboard.py

Configuración compartida:

test/tools/
test_dashboard.json

Configuración local:

test/tools/
test_dashboard.local.json

Backend:

test/tools/
run_godot_tests.ps1

La aplicación permanece abierta durante
la sesión de desarrollo.

Cada test utiliza un proceso Godot Console
independiente.

El PowerShell runner continúa siendo
la autoridad del resultado.

Operaciones verificadas:

- Run Selected
- Run Suite
- Run All
- Repeat
- Timeout
- Stop
- Refresh
- Search
- Copy Command
- Copy Output
- Safe Close

La aplicación no modifica tests ni Core.

Velocity Test Dashboard Pause and Resume

Versión:

0.3.2

La interfaz utiliza un único botón dinámico:

Pause / Resume

RUNNING:

Pause solicita detener el plan después
de finalizar el test actual.

PAUSED:

Resume continúa con el primer test NOT_RUN.

STOPPED:

Resume vuelve a ejecutar desde el principio
el test interrumpido y continúa el plan.

Los tests PASS anteriores no se repiten.

El Dashboard no intenta restaurar un proceso
Godot parcialmente ejecutado.

Pause y Resume operan sobre Execution Plan,
no sobre SceneTree.

Device Profile and Configuration

Modelo:

Draft
→ Compiler
→ ValidationReport
→ Snapshot

Reglas:

Draft es editable.

Draft no se ejecuta.

Snapshot no expone setters.

Runtime utiliza snapshots.

Canonical Profiles son inmutables.

Namespace velocity está reservado.

Save As produce Draft.

Configuration referencia una versión exacta
de DeviceProfile.

DeviceManifest se construye desde snapshots.

Profile requirements no pueden eliminarse.

Additional requirements se unen
sin duplicados.

Simulation Hazard permite Simulation Mode.

Simulation Hazard bloquea Hardware Mode.

Generic Profile está prohibido.

Utilizar nombres explícitos:

DeviceProfile

DeviceConfiguration

SystemProfile

DeviceGraph

Responsabilidad:

Representar y validar topología lógica.

DeviceGraph no:

- transporta mensajes;
- crea Devices runtime;
- controla Lifecycle;
- modifica Health;
- guarda archivos;
- dibuja UI;
- ejecuta Graph.

Toda comunicación utiliza DeviceBus.

Modelo:

DeviceGraphNode

OutputPort

TopicChannel

InputPort

DeviceGraphNode

Connections son lógicas.

No crean referencias directas entre Devices.

DeviceGraph Draft:

editable mediante API.

DeviceGraph Snapshot:

inmutable y no ejecutable.

Runtime requiere CompositionCompiler.

Connection ID:

source_device
|
source_port
|
target_device
|
target_port

El carácter `|` está reservado.

IDs de Device y Port no pueden contenerlo.

Ports derivan de DeviceManifest efectivo.

Semantic Kind puede ser UNSPECIFIED
durante la primera versión.

Feedback loops están permitidos.

Cycles requieren validación runtime futura.

Mutaciones son transaccionales.

Una operación fallida no modifica Graph.

GDScript Typed Collections

El tipo contenido dentro de Array[] o
Dictionary[] permanecerá en la misma línea
que los corchetes.

Incorrecto:

Array[
	DeviceGraphInputPort
]

Dictionary[
	String,
	DeviceGraphNode
]

Correcto:

Array[DeviceGraphInputPort]

Dictionary[String, DeviceGraphNode]

Los valores de la colección pueden dividirse
en varias líneas.

Solo la declaración del tipo permanece
en una misma línea.

Godot Object Method Names

Las clases que heredan de Object,
RefCounted, Resource o Node no declararán
métodos públicos que oculten métodos
incorporados de Godot con firmas distintas.

Antes de elegir nombres públicos se revisará
la API de Object.

Nombres reservados encontrados:

connect()

disconnect()

emit_signal()

call()

free()

get()

set()

Para DeviceGraph se utilizará:

connect_ports()

disconnect_ports()

No se sobrescribirá Object.connect()
ni Object.disconnect().
