# Velocity Test Dashboard — Diseño

| Campo | Valor |
|---|---|
| Estado | APROBADO |
| Versión | 1.2 |
| Fecha | 17/08/2026 |
| Estado de implementación | COMPLETO |
| Última verificación | 18/08/2026 |
| Lenguaje | Python 3.13 |
| UI | Tkinter 8.6 |
| Backend | run_godot_tests.ps1 |
| Plataforma inicial | Windows |

## 1. Propósito

Velocity Test Dashboard proporciona una interfaz visual para descubrir, seleccionar, ejecutar y observar las pruebas de Velocity.

La herramienta evita escribir manualmente comandos PowerShell repetitivos.

El Dashboard permanece abierto durante la sesión de desarrollo.

Cada prueba continúa ejecutándose en un proceso Godot Console independiente.

## 2. Alcance del MVP

La primera versión permitirá:

- cargar configuración JSON;
- localizar la raíz del proyecto;
- localizar PowerShell runner;
- localizar Godot Console;
- descubrir escenas de prueba;
- filtrar por nombre;
- agrupar por suites;
- ejecutar una escena;
- ejecutar una suite;
- ejecutar todas;
- configurar Repeat;
- configurar Timeout;
- mostrar output;
- mostrar estado;
- detener procesos;
- refrescar tests;
- conservar configuración local;
- copiar comando equivalente;
- cerrar de forma segura.

## 3. Fuera de alcance inicial

La primera versión no incluirá:

- gráficas;
- historial avanzado;
- comparación de runs;
- exportación PDF;
- actualización automática;
- instalación de dependencias;
- empaquetado `.exe`;
- integración como plugin de Godot;
- ejecución remota;
- CI externo;
- edición de tests.

## 4. Archivos

```text
test/tools/
├── run_godot_tests.ps1
├── velocity_test_dashboard.py
├── test_dashboard.json
└── test_dashboard.local.json
```

El archivo local no será versionado.

## 5. Configuración compartida

Archivo:

```text
test/tools/test_dashboard.json
```

Contendrá:

- raíz relativa del proyecto;
- ruta relativa del runner;
- carpetas de tests;
- patrones de inclusión;
- patrones de exclusión;
- timeout por defecto;
- repeat por defecto;
- suites.

Será versionado en Git.

## 6. Configuración local

Archivo:

```text
test/tools/test_dashboard.local.json
```

Contendrá:

- ruta local de Godot Console;
- tamaño de ventana;
- última escena seleccionada;
- última suite;
- timeout utilizado;
- repeat utilizado;
- auto-scroll.

No será versionado.

La variable de entorno `GODOT_CONSOLE` tiene prioridad sobre la ruta guardada.

Orden:

```text
1. GODOT_CONSOLE

2. test_dashboard.local.json

3. file picker
```

## 7. Project Root

La aplicación se encuentra en:

```text
test/tools/
```

La raíz se calcula mediante:

```text
../..
```

Debe existir:

```text
project.godot
```

Si no existe, la aplicación muestra error y no permite ejecutar.

## 8. Descubrimiento de tests

La aplicación escanea las carpetas configuradas.

Busca:

```text
*.tscn
```

que coincidan con patrones de test.

Excluye:

```text
test/infrastructure/

device_bus_failure_isolation_test.tscn
```

Cada test conserva:

```text
display name;

resource path;

filesystem path;

suite;

folder.
```

Si dos escenas tienen el mismo nombre, la UI muestra también su ruta relativa.

## 9. Refresh

El Dashboard tendrá:

```text
Refresh Tests
```

La operación:

- vuelve a leer configuración compartida;
- escanea carpetas;
- actualiza suites;
- conserva selección cuando sea posible;
- informa cantidad de tests.

También se ejecuta automáticamente:

- al iniciar;
- antes de Run Suite;
- antes de Run All.

## 10. Suites

Suites iniciales:

```text
All

DeviceBus

DeviceCore

Providers

Profiles

Message Contracts

Debug
```

Una suite puede contener una o más carpetas.

Las suites no duplican escenas.

## 11. Ejecución

La UI no invoca Godot directamente.

Invoca:

```text
run_godot_tests.ps1
```

Ejemplo:

```text
powershell.exe

-NoProfile

-ExecutionPolicy Bypass

-File run_godot_tests.ps1

-Scene res://...

-Repeat 1

-TimeoutSeconds 10
```

Para todas:

```text
-All
```

El runner continúa siendo la autoridad.

## 12. GODOT_CONSOLE

El Dashboard pasa la ruta al runner mediante:

```text
-GodotPath
```

o conserva la variable de entorno.

La ruta debe:

- existir;
- ser archivo;
- terminar en `.exe`;
- preferiblemente incluir `_console`.

Si la variable de sistema ya existe, se utiliza automáticamente.

## 13. Proceso

Python utilizará:

```python
subprocess.Popen
```

con:

```python
shell=False
```

y argumentos como lista.

Se utilizará:

```text
CREATE_NEW_PROCESS_GROUP
```

en Windows.

Esto permite terminar el árbol específico iniciado por el Dashboard.

## 14. Threading

Tkinter permanece en el main thread.

El runner se ejecuta en un worker thread.

Modelo:

```text
Tkinter Main Thread
		│
		├── UI
		├── event loop
		└── output rendering

Worker Thread
		│
		└── subprocess PowerShell

queue.Queue
		│
		└── output hacia UI
```

El worker no modifica widgets directamente.

La UI consulta la queue mediante:

```python
root.after()
```

## 15. Output

stdout y stderr serán combinados para mostrar orden de ejecución.

La vista tendrá:

- fuente monoespaciada;
- scroll vertical;
- auto-scroll opcional;
- botón Clear;
- botón Copy Output.

La primera versión puede aplicar un color general por estado final.

No necesita interpretar colores ANSI.

## 16. Estados visuales

```text
IDLE

RUNNING

PASS

FAIL

TIMEOUT

ENGINE_ERROR

STOPPED

CONFIG_ERROR
```

Colores recomendados:

```text
IDLE:
gris

RUNNING:
azul

PASS:
verde

FAIL:
rojo

TIMEOUT:
amarillo

ENGINE_ERROR:
rojo oscuro

STOPPED:
naranja

CONFIG_ERROR:
rojo
```

## 17. Parsing de resultado

La autoridad principal es el ExitCode del runner.

Además se analizará output para mostrar:

```text
Tests

Total runs

Passed

Failed

RESULT

TIMEOUT

ENGINE_ERROR
```

Reglas:

```text
Exit 0:
PASS

Exit distinto de 0:
FAIL o estado más específico

Output contiene TIMEOUT:
TIMEOUT

Output contiene ENGINE_ERROR:
ENGINE_ERROR
```

El parser visual no cambia la semántica del runner.

## 18. Controles

Controles MVP:

```text
Search

Suite selector

Test list

Repeat

Timeout

Run Selected

Run Suite

Run All

Stop

Refresh Tests

Clear Output

Copy Command

Copy Output
```

## 19. Estado de controles

Mientras ejecuta:

```text
Run Selected:
disabled

Run Suite:
disabled

Run All:
disabled

Refresh:
disabled

Test selection:
disabled

Stop:
enabled
```

Al terminar se invierten.

No se permiten dos runners simultáneos.

## 20. Stop

Stop termina el árbol iniciado por el Dashboard.

En Windows podrá utilizar:

```text
taskkill /PID <pid> /T /F
```

solo para el PID de PowerShell creado por Python.

No debe detener:

- Godot Editor;
- otro Dashboard;
- procesos ajenos.

Después muestra:

```text
STOPPED
```

## 21. Cierre seguro

Si la ventana se cierra durante ejecución:

```text
A test is currently running.

Stop the test and exit?
```

Opciones:

```text
Cancel

Stop and Exit
```

La aplicación no se cierra dejando procesos hijos.

## 22. UI Layout

Estructura:

```text
Main Window
│
├── Toolbar
│   ├── Refresh
│   ├── Run Selected
│   ├── Run Suite
│   ├── Run All
│   └── Stop
│
├── Horizontal Paned Window
│   │
│   ├── Left Panel
│   │   ├── Search
│   │   ├── Suite selector
│   │   └── Test list
│   │
│   └── Right Panel
│       ├── Selected test
│       ├── Repeat
│       ├── Timeout
│       ├── Status
│       ├── Summary
│       └── Output
│
└── Status Bar
```

## 23. Búsqueda

La búsqueda no distingue mayúsculas.

Busca dentro de:

- nombre de escena;
- ruta;
- suite.

La lista se actualiza mientras se escribe.

## 24. Test seleccionado

El panel muestra:

```text
Display Name

Resource Path

Filesystem Path

Suite
```

Run Selected permanece desactivado si no hay selección válida.

## 25. Persistencia local

Al cerrar se guardarán:

- geometry;
- última selección;
- suite;
- repeat;
- timeout;
- auto-scroll.

Un archivo local inválido se ignora y se reemplaza con defaults seguros.

## 26. Errores de configuración

El Dashboard debe detectar:

- project.godot ausente;
- runner ausente;
- Godot Console ausente;
- JSON inválido;
- carpeta de tests ausente;
- escena eliminada;
- Repeat inválido;
- Timeout inválido.

La interfaz permanece abierta y muestra el error.

## 27. Seguridad

No se utiliza:

```python
shell=True
```

No se ejecuta texto escrito libremente como comando.

La escena siempre proviene del catálogo descubierto.

Repeat y Timeout se convierten a enteros y se validan.

Los paths se resuelven antes de ejecutar.

## 28. Configuración compartida inicial

```json
{
  "project_root": "../..",
  "runner": "test/tools/run_godot_tests.ps1",
  "test_roots": [
    "test/core"
  ],
  "include_patterns": [
	"*Test.tscn",
    "*_test.tscn"
  ],
  "exclude_patterns": [
	"test/infrastructure",
    "device_bus_failure_isolation_test.tscn"
  ],
  "default_timeout_seconds": 10,
  "default_repeat": 1,
  "suites": {
	"All": [
      "test/core"
	],
	"DeviceBus": [
      "test/core/device_bus"
	],
	"DeviceCore": [
	  "test/core/device_core",
      "test/core/device"
	],
	"Providers": [
      "test/core/provider"
	],
	"Profiles": [
      "test/core/profile"
	],
	"Message Contracts": [
      "test/core/message_contract"
	],
	"Debug": [
      "test/core/debug"
	]
  }
}
```

## 29. Configuración local inicial

```json
{
  "godot_console": "",
  "window_geometry": "1280x800",
  "last_selected_test": "",
  "last_suite": "All",
  "repeat": 1,
  "timeout_seconds": 10,
  "auto_scroll": true
}
```

## 30. Git Ignore

Debe añadirse:

```text
test/tools/test_dashboard.local.json

test/tools/.test_dashboard/
```

La configuración compartida sí se versiona.

## 31. Fases de implementación

### Fase 1

```text
Configuración.

Descubrimiento.

Lista.

Búsqueda.

Selección.
```

### Fase 2

```text
Run Selected.

Worker thread.

Output live.

Status.

Stop.
```

### Fase 3

```text
Suites.

Run All.

Repeat.

Timeout.

Summary.
```

### Fase 4

```text
Persistencia local.

Copy Command.

Copy Output.

Cierre seguro.
```

## 32. Pruebas de la herramienta

La herramienta se verificará mediante:

- carga de JSON válido;
- rechazo de JSON inválido;
- descubrimiento de tests;
- filtros;
- selección;
- ejecución PASS;
- ejecución FAIL;
- timeout;
- Stop;
- cierre durante ejecución;
- ruta GODOT_CONSOLE;
- ausencia de GODOT_CONSOLE.

No se utilizarán tests de Godot para probar la UI Python.

Podrán utilizarse pruebas unitarias Python futuras.

## 33. Criterios de aceptación del MVP

1. Inicia con Python 3.13.

2. Utiliza Tkinter 8.6.

3. Detecta GODOT_CONSOLE.

4. Descubre tests.

5. Filtra por nombre.

6. Ejecuta una escena.

7. Ejecuta una suite.

8. Ejecuta todas.

9. Muestra output.

10. Muestra estado.

11. Captura ExitCode.

12. Stop termina el árbol.

13. UI no se congela.

14. Configuración local se guarda.

15. No requiere paquetes externos.

16. Runner PowerShell permanece autoritativo.

## 34. Regla de evolución

Una función nueva no debe:

- duplicar el runner;
- ejecutar comandos arbitrarios;
- bloquear Tkinter;
- modificar tests;
- modificar Core;
- ocultar ExitCodes;
- dejar procesos huérfanos.

La herramienta debe continuar siendo un adaptador visual de infraestructura de pruebas.

## 35. Estado de implementación

Velocity Test Dashboard fue implementado mediante:

```text
Python 3.13

Tkinter 8.6

PowerShell runner

Godot Console headless```

## 36. Pause y Resume

Velocity Test Dashboard utiliza un único botón dinámico:

```text
Pause / Resume```
