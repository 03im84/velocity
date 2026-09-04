# Velocity Test Dashboard — Diseño

| Campo | Valor |
|---|---|
| Estado | APROBADO |
| Versión del documento | 1.3 |
| Versión objetivo del Dashboard | 0.4.0 |
| Fecha | 04/09/2026 |
| Estado de implementación | PENDIENTE |
| Última versión verificada | 0.3.2 |
| Lenguaje | Python 3.13 |
| UI | Tkinter 8.6 |
| Backend | run_godot_tests.ps1 |
| Plataforma inicial | Windows |

## 1. Propósito

Velocity Test Dashboard proporciona una interfaz visual para descubrir, clasificar, seleccionar, ejecutar y observar las pruebas de Velocity.

Dashboard 0.4.0 añade:

- métricas de checks;
- métricas de check failures;
- detección de métricas ausentes;
- contrato estructurado Runner–Dashboard;
- suites automáticas;
- categorías derivadas de nombres y rutas;
- módulo lógico Python independiente de Tkinter;
- pruebas unitarias de parsing y clasificación.

Cada prueba continúa ejecutándose mediante PowerShell Runner y un proceso Godot Console independiente.

PowerShell Runner permanece como autoridad.

## 2. Problemas que resuelve 0.4.0

### 2.1 Checks no agregados

Cada test emite:

```text
Checks: N

Failures: N
```

Runner 0.3.2 muestra esas líneas, pero no las convierte en datos estructurados.

Dashboard 0.3.2 solo interpreta:

```text
Total runs

Passed

Failed
```

No puede calcular automáticamente:

- total de checks;
- check failures;
- tests sin métricas;
- checks por test;
- checks por Repeat.

### 2.2 Suites manuales desactualizadas

La configuración compartida declara manualmente:

```text
DeviceBus

DeviceCore

Providers

Profiles

Message Contracts

Debug
```

No contiene:

```text
DeviceGraph

Composition

DeviceCatalog

Runtime
```

Cada nuevo directorio exige editar configuración.

### 2.3 Lógica mezclada con UI

`velocity_test_dashboard.py` contiene:

- UI;
- discovery;
- suite inference;
- parsing;
- plan execution;
- process control;
- persistence;
- summary.

Añadir más parsing dentro del mismo archivo aumentaría el acoplamiento.

### 2.4 Método duplicado

Dashboard 0.3.2 define dos veces:

```python
def copy_command(self) -> None:
```

Python conserva únicamente la última definición.

Dashboard 0.4.0 tendrá una sola implementación.

### 2.5 Variable defensiva del Runner

`Invoke-GodotTest` debe inicializar en cada attempt:

```powershell
$engineErrorDetected = $false
```

No dependerá de estado implícito.

## 3. Responsabilidades

### PowerShell Runner

Responsabilidad:

> Ejecutar tests, aplicar límites, detectar errores y emitir resultado estructurado.

### Dashboard Logic

Responsabilidad:

> Interpretar métricas y clasificar suites sin depender de Tkinter o subprocess.

### Dashboard UI

Responsabilidad:

> Presentar tests, ejecutar planes y renderizar resultados.

### Configuración compartida

Responsabilidad:

> Definir paths, aliases, orden y overrides.

### Configuración local

Responsabilidad:

> Conservar preferencias de una máquina.

## 4. Archivos

```text
test/tools/
├── run_godot_tests.ps1
├── velocity_test_dashboard_logic.py
├── velocity_test_dashboard.py
├── test_velocity_test_dashboard_logic.py
├── test_dashboard.json
├── test_dashboard.local.json
└── start_velocity_test_dashboard.bat
```

Archivos versionados:

```text
run_godot_tests.ps1

velocity_test_dashboard_logic.py

velocity_test_dashboard.py

test_velocity_test_dashboard_logic.py

test_dashboard.json

start_velocity_test_dashboard.bat
```

Archivo no versionado:

```text
test_dashboard.local.json
```

## 5. Fuera de alcance

Dashboard 0.4.0 no incluye:

- gráficas;
- historial persistente de ejecuciones;
- comparación entre commits;
- exportación PDF;
- base de datos;
- actualización automática;
- instalación de dependencias;
- empaquetado `.exe`;
- plugin de Godot;
- ejecución remota;
- CI externo;
- edición de tests;
- red;
- archivos JSON por run;
- telemetría.

## 6. Configuración compartida

Archivo:

```text
test/tools/test_dashboard.json
```

Contiene:

- project root;
- runner;
- test roots;
- patrones de inclusión;
- patrones de exclusión;
- timeout;
- repeat;
- automatic suites;
- suite aliases;
- suite order;
- suite overrides.

Es versionado.

## 7. Configuración local

Archivo:

```text
test/tools/test_dashboard.local.json
```

Contiene:

- Godot Console local;
- window geometry;
- última selección;
- última suite;
- repeat;
- timeout;
- auto-scroll.

No se modifica para 0.4.0.

No se versiona.

Prioridad de Godot executable:

```text
1. GODOT_CONSOLE

2. test_dashboard.local.json

3. file picker
```

## 8. Project Root

Dashboard se encuentra en:

```text
test/tools/
```

Project root:

```text
../..
```

Debe existir:

```text
project.godot
```

Si falta, ejecución queda deshabilitada.

## 9. Descubrimiento

Dashboard escanea `test_roots`.

Descubre escenas:

```text
*.tscn
```

que coincidan con:

```text
*Test.tscn

*_test.tscn
```

Excluye:

```text
test/infrastructure/

device_bus_failure_isolation_test.tscn
```

Cada TestScene conserva:

```text
name

resource_path

filesystem_path

relative_path

suite
```

La extensión `.tscn` define ejecutabilidad como escena Godot.

No define categoría.

## 10. Clasificación automática de suites

Suite se infiere por:

```text
nombre

y

ruta
```

No por extensión.

Prioridad:

```text
1. suite override exacto;

2. alias del primer directorio bajo test root;

3. nombre humanizado del directorio;

4. nombre humanizado de escena;

5. Other.
```

## 11. Aliases iniciales

```text
device_bus
→ DeviceBus

device_core
→ DeviceCore

device
→ DeviceCore

provider
→ Providers

profile
→ Profiles

message_contract
→ Message Contracts

device_graph
→ DeviceGraph

composition
→ Composition

catalog
→ DeviceCatalog

runtime
→ Runtime

debug
→ Debug
```

## 12. Directorios desconocidos

Ejemplo:

```text
test/core/measurement_contract/
```

Suite automática:

```text
Measurement Contract
```

Transformación:

```text
measurement_contract
→ measurement contract
→ Measurement Contract
```

Otro ejemplo:

```text
runtime-safety
→ Runtime Safety
```

## 13. Escenas directamente bajo test root

Si una escena se encuentra directamente bajo:

```text
test/core/
```

se utiliza su nombre sin sufijo Test.

Ejemplo:

```text
MeasurementIdentityTest.tscn
→ Measurement Identity
```

Si no puede inferirse un nombre:

```text
Other
```

## 14. Suite All

`All` es implícita.

No necesita declararse como root manual.

Incluye todos los tests descubiertos después de aplicar exclusiones.

No duplica escenas.

## 15. Orden de suites

Orden inicial:

```text
All

DeviceBus

DeviceCore

Providers

Profiles

Message Contracts

DeviceGraph

Composition

DeviceCatalog

Runtime

Debug
```

Suites desconocidas aparecen después en orden alfabético.

## 16. Overrides

Configuración puede forzar una suite por resource path o relative path.

Ejemplo conceptual:

```json
{
  "test/core/special/LegacyTest.tscn": "Legacy"
}
```

Overrides tienen prioridad sobre aliases.

No se utilizan para mantener categorías normales.

## 17. Dashboard Logic Module

Archivo:

```text
test/tools/velocity_test_dashboard_logic.py
```

No importa:

- tkinter;
- subprocess;
- threading;
- filesystem de ejecución;
- Godot.

Puede importar:

- dataclasses;
- json;
- pathlib;
- re;
- typing.

## 18. Responsabilidades de Dashboard Logic

Funciones o clases puras para:

- humanizar suite names;
- normalizar paths;
- inferir suite;
- interpretar metrics marker;
- agregar markers;
- calcular missing metrics.

Modelos previstos:

```text
RunnerAttemptMetrics

RunnerMetricsSummary
```

No modifica UI.

No inicia procesos.

## 19. Runner Metrics Protocol

Versión:

```text
1
```

Prefix:

```text
VELOCITY_TEST_METRICS_JSON:
```

Marker disponible:

```text
VELOCITY_TEST_METRICS_JSON:{"version":1,"scene":"res://test/core/runtime/RuntimeFactoryKeyTest.tscn","attempt":1,"available":true,"checks":24,"check_failures":0}
```

Marker no disponible:

```text
VELOCITY_TEST_METRICS_JSON:{"version":1,"scene":"res://test/core/runtime/RuntimeFactoryKeyTest.tscn","attempt":1,"available":false,"checks":null,"check_failures":null}
```

## 20. Campos del marker

```text
version:
versión del protocolo.

scene:
resource path.

attempt:
número de intento.

available:
si Checks y Failures fueron encontrados.

checks:
cantidad de checks o null.

check_failures:
cantidad de failures o null.
```

## 21. Extracción en PowerShell

Runner analiza stdout del proceso Godot.

Patrones:

```regex
^\s*Checks:\s*(\d+)\s*$

^\s*Failures:\s*(\d+)\s*$
```

Si existen varias coincidencias, utiliza la última de cada campo dentro del attempt.

Metrics available es true únicamente cuando ambos campos existen.

## 22. Marker obligatorio por attempt

Runner emite exactamente un marker por attempt, incluso cuando:

- PASS;
- FAIL;
- TIMEOUT;
- ENGINE_ERROR;
- proceso no confirmado;
- summary ausente.

Esto permite distinguir:

```text
marker ausente por error de protocolo

de

metrics available false
```

## 23. Test failures y ExitCode

Si:

```text
check_failures > 0
```

y Godot devuelve ExitCode cero, Runner convierte el attempt en FAIL.

ExitCode agregado del Runner será distinto de cero.

Esto evita que un test con assertions fallidas sea declarado PASS por error de propagación.

## 24. Missing Metrics

Si un attempt termina PASS pero no emite summary:

```text
Status:
PASS

Metrics:
MISSING
```

Dashboard no redefine el estado autoritativo.

Plan summary incrementa:

```text
Missing Metrics
```

No asume checks cero.

## 25. Repeat

Con:

```text
Repeat: 3
```

Runner emite tres markers.

Dashboard agrega:

```text
Checks:
suma de attempts disponibles.

Check Failures:
suma de attempts disponibles.

Metrics Runs:
cantidad de markers available true.

Missing Metrics:
cantidad de markers available false
o markers esperados ausentes.
```

## 26. Runner Result

Cada resultado PowerShell añade:

```text
Checks

CheckFailures

MetricsAvailable
```

La tabla humana muestra:

```text
Scene

Attempt

ExitCode

Status

EngineError

Checks

CheckFailures

MetricsAvailable
```

## 27. Runner Summary

Runner imprime:

```text
Total runs

Passed

Failed

Total checks

Check failures

Missing metrics

RESULT
```

Estos valores son humanos.

El Dashboard utiliza markers estructurados para métricas por attempt.

## 28. PlanResult

Dashboard 0.4.0 añade:

```python
checks: int = 0

check_failures: int = 0

metrics_runs: int = 0

missing_metrics: int = 0
```

`reset_for_resume()` reinicia esos campos cuando un test STOPPED o NOT_RUN se vuelve a ejecutar.

Resultados PASS ya completados conservan métricas.

## 29. Results Table

Columnas:

```text
Test

Status

Exit

Runs

Checks

Check Failures

Metrics

Seconds
```

### Checks

```text
número agregado

o

vacío mientras PENDING
```

### Check Failures

```text
número agregado
```

### Metrics

```text
OK

Missing N

—
```

## 30. Summary live

Durante ejecución:

```text
All Tests
Completed: 20 / 54
Passed: 20
Failed: 0
Checks: 640
Check Failures: 0
Missing Metrics: 0
```

Solo suma resultados completados.

## 31. Summary final

```text
All Tests
Planned: 54
Completed: 54
Passed: 54
Failed: 0
Timeout: 0
Engine Error: 0
Not Run: 0
Total Runs: 54
Checks: 1569
Check Failures: 0
Missing Metrics: 0
Plan ExitCode: 0
RESULT: PASS
```

`1569` es expectativa inicial.

El valor real será determinado por Runner Metrics Protocol.

## 32. Estado de un test con métricas faltantes

Ejemplo:

```text
Status:
PASS

Checks:
0 mostrado como vacío o —

Check Failures:
—

Metrics:
Missing 1
```

El summary muestra:

```text
Passed: 1

Missing Metrics: 1
```

## 33. Status visuales

```text
IDLE

RUNNING

PAUSE_REQUESTED

PAUSED

PASS

FAIL

TIMEOUT

ENGINE_ERROR

STOPPED

CONFIG_ERROR
```

Métrica faltante no añade un nuevo status de test.

Se muestra en columna Metrics.

## 34. UI Layout

```text
Main Window
│
├── Toolbar
│   ├── Refresh
│   ├── Run Selected
│   ├── Run Suite
│   ├── Run All
│   ├── Pause / Resume
│   ├── Stop
│   ├── Select Godot
│   ├── Copy Command
│   ├── Copy Output
│   └── Clear Output
│
├── Horizontal Paned Window
│   │
│   ├── Test Browser
│   │   ├── Search
│   │   ├── Suite selector
│   │   └── Test list
│   │
│   └── Execution Panel
│       ├── Selected test
│       ├── Repeat
│       ├── Timeout
│       ├── Status
│       ├── Summary
│       ├── Results Table
│       ├── Configuration
│       └── Output
│
└── Status Bar
```

## 35. Pause y Resume

Se conserva un único botón dinámico:

```text
Pause

Pausing...

Resume
```

No se crean botones separados.

Pause ocurre después del test actual.

PASS anteriores no se repiten.

STOPPED y NOT_RUN se reinician al Resume.

Sus métricas se reinician antes de volver a ejecutar.

## 36. Stop

Stop termina únicamente el árbol iniciado por Dashboard.

Windows:

```text
taskkill /PID <pid> /T /F
```

No detiene:

- Godot Editor;
- otro Dashboard;
- procesos ajenos.

## 37. Process creation

Python utiliza:

```python
subprocess.Popen
```

con:

```python
shell=False
```

En Windows:

```text
CREATE_NO_WINDOW

STARTF_USESHOWWINDOW

SW_HIDE
```

No aparecen ventanas PowerShell o Godot Console.

## 38. Threading

Tkinter permanece en main thread.

Worker ejecuta subprocess.

`queue.Queue` transporta eventos.

`root.after()` procesa eventos.

Worker no modifica widgets.

## 39. Output

stdout y stderr se combinan.

La vista mantiene:

- fuente monoespaciada;
- scroll vertical;
- scroll horizontal;
- auto-scroll;
- Clear Output;
- Copy Output.

Metrics marker permanece visible en output para auditoría.

## 40. Status y ExitCode

Runner decide ExitCode.

Dashboard determina representación:

```text
Exit 0:
PASS

Output TIMEOUT
o Exit 124:
TIMEOUT

Output ENGINE_ERROR
o Exit 126:
ENGINE_ERROR

Otro Exit:
FAIL
```

Metrics no convierte PASS en FAIL dentro del Dashboard.

Runner realiza cualquier cross-check.

## 41. Engine Error

Runner inicializa por attempt:

```powershell
$engineErrorDetected = $false
```

Detecta:

```text
SCRIPT ERROR:

ERROR:

Parse Error:

Invalid call.
```

Godot ExitCode cero con Engine Error se convierte en:

```text
126

ENGINE_ERROR
```

## 42. Runner timeout

Timeout configurable:

```text
1 a 3600 segundos
```

Timeout produce:

```text
ExitCode 124

TIMEOUT

Metrics available false
```

salvo que el test haya emitido summary antes del timeout.

## 43. Configuración compartida 0.4.0

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
  "automatic_suites": true,
  "suite_aliases": {
	"device_bus": "DeviceBus",
	"device_core": "DeviceCore",
	"device": "DeviceCore",
	"provider": "Providers",
	"profile": "Profiles",
	"message_contract": "Message Contracts",
	"device_graph": "DeviceGraph",
	"composition": "Composition",
	"catalog": "DeviceCatalog",
	"runtime": "Runtime",
	"debug": "Debug"
  },
  "suite_order": [
	"DeviceBus",
	"DeviceCore",
	"Providers",
	"Profiles",
	"Message Contracts",
	"DeviceGraph",
	"Composition",
	"DeviceCatalog",
	"Runtime",
    "Debug"
  ],
  "suite_overrides": {}
}
```

`All` es implícita.

## 44. Configuración local

Sin cambios:

```json
{
  "godot_console": "",
  "window_geometry": "1440x900",
  "last_selected_test": "",
  "last_suite": "All",
  "repeat": 1,
  "timeout_seconds": 10,
  "auto_scroll": true
}
```

No se modifica el archivo local del usuario.

## 45. Refresh

Refresh:

- relee configuración compartida;
- descubre tests;
- infiere suites;
- actualiza Combo;
- conserva selección;
- conserva suite cuando existe;
- vuelve a All si suite desaparece;
- informa cantidad.

Se ejecuta:

- al iniciar;
- manualmente;
- antes de Run Suite;
- antes de Run All.

## 46. Suite selector

Valores se construyen desde:

```text
All

+

suite_order presente

+

suites descubiertas adicionales
```

No muestra suites configuradas sin tests, salvo decisión futura.

## 47. Search

Busca sin distinguir mayúsculas dentro de:

- nombre;
- resource path;
- suite.

Actualiza mientras se escribe.

## 48. Duplicated names

Si dos escenas comparten stem, Dashboard muestra ruta relativa junto al nombre.

La identidad interna sigue siendo resource path.

## 49. Seguridad

No se utiliza:

```python
shell=True
```

No se ejecuta texto libre.

Escenas provienen de discovery.

Repeat y Timeout se validan.

Paths se resuelven.

Metrics JSON se interpreta con `json.loads`.

No se evalúa código desde marker.

## 50. Duplicación de copy_command

Dashboard 0.4.0 conserva exactamente una implementación:

```python
def copy_command(self) -> None:
```

La definición duplicada se elimina en el archivo completo consolidado.

## 51. Pruebas del módulo lógico

Archivo:

```text
test/tools/test_velocity_test_dashboard_logic.py
```

Framework:

```text
unittest
```

Sin dependencias externas.

Casos:

- humanize snake_case;
- humanize kebab-case;
- suite alias;
- suite override;
- unknown folder;
- root-level test;
- Windows path;
- POSIX path;
- marker válido;
- marker unavailable;
- marker malformado;
- protocol version inválida;
- markers repetidos;
- suma de checks;
- suma de failures;
- missing metrics;
- marker ausente.

## 52. Ejecución de unittest

Desde project root:

```powershell
python `
	-m unittest `
	test.tools.test_velocity_test_dashboard_logic
```

Resultado esperado:

```text
OK
```

No requiere Tkinter display ni Godot.

## 53. Pruebas del Runner

### Positive

Ejecutar una escena PASS.

Verificar:

- marker version 1;
- available true;
- Checks correcto;
- CheckFailures cero;
- ExitCode cero.

### Repeat

Ejecutar Repeat mayor que uno.

Verificar un marker por attempt.

### Failure

Ejecutar test controlado con failure.

Verificar:

- CheckFailures mayor que cero cuando summary existe;
- ExitCode no cero;
- Status FAIL.

### Timeout

Verificar:

- Exit 124;
- marker emitido;
- Missing Metrics contabilizable.

### Engine Error

Verificar:

- Exit 126;
- ENGINE_ERROR;
- marker emitido.

## 54. Pruebas del Dashboard

Verificación manual:

- discovery de 54 tests;
- suites automáticas;
- Runtime visible;
- DeviceCatalog visible;
- Composition visible;
- DeviceGraph visible;
- no categorías nuevas en Other;
- Run Selected;
- Run Suite;
- Run All;
- columnas de metrics;
- summary live;
- summary final;
- Pause;
- Resume;
- Stop;
- output;
- safe close.

## 55. Baseline objetivo

Run All esperado:

```text
Planned: 54
Completed: 54
Passed: 54
Failed: 0
Timeout: 0
Engine Error: 0
Not Run: 0
Total Runs: 54
Checks: 1569
Check Failures: 0
Missing Metrics: 0
Plan ExitCode: 0
RESULT: PASS
```

El número real de checks se aceptará únicamente después de ejecución con Metrics Protocol.

## 56. Compatibilidad

Se conserva:

- test scene discovery;
- shared config path;
- local config path;
- GODOT_CONSOLE;
- Run Selected;
- Run Suite;
- Run All;
- Repeat;
- Timeout;
- Pause/Resume;
- Stop;
- Copy Command;
- Copy Output;
- safe close;
- no console windows.

## 57. Migración desde suites manuales

La configuración `suites` de 0.3.2 deja de ser fuente principal.

Dashboard 0.4.0 utiliza:

```text
automatic_suites

suite_aliases

suite_order

suite_overrides
```

No se necesita migrar `test_dashboard.local.json`.

Si `last_suite` no existe después de discovery:

```text
All
```

## 58. Orden de implementación

```text
1. Crear journal de diseño.
   COMPLETADO.

2. Reemplazar este diseño.
   COMPLETADO.

3. Commit de diseño.
   SIGUIENTE.

4. Implementar
   velocity_test_dashboard_logic.py.

5. Implementar unittest.

6. Ejecutar unittest.

7. Reemplazar Runner completo.

8. Probar Runner aislado.

9. Reemplazar test_dashboard.json completo.

10. Reemplazar Dashboard completo.

11. Verificar UI.

12. Ejecutar Run Selected.

13. Ejecutar Run Suite.

14. Ejecutar Pause/Resume.

15. Ejecutar Stop.

16. Ejecutar Run All.

17. Confirmar checks reales.

18. Registrar baseline.

19. Actualizar Project Handoff.

20. Cerrar Dashboard 0.4.0.
```

## 59. Criterios de aceptación

1. Runner emite marker por attempt.

2. Marker utiliza JSON seguro.

3. Protocol version es uno.

4. Checks se extraen correctamente.

5. Check Failures se extraen correctamente.

6. Missing Metrics no se confunde con cero.

7. Check Failures positivos no permiten PASS silencioso.

8. Dashboard consume marker.

9. PlanResult conserva métricas.

10. Results muestra Checks.

11. Results muestra Check Failures.

12. Results muestra Metrics.

13. Summary live agrega checks.

14. Summary final agrega checks.

15. Repeat agrega attempts.

16. Resume no duplica métricas.

17. Suites se infieren automáticamente.

18. Aliases agrupan device y device_core.

19. Directorio desconocido se humaniza.

20. Overrides tienen prioridad.

21. `All` es implícita.

22. Módulo lógico no depende de Tkinter.

23. unittest termina OK.

24. Existe una sola definición de copy_command.

25. engineErrorDetected se inicializa por attempt.

26. Local config no se modifica.

27. No aparecen consolas.

28. Pause/Resume conserva un botón.

29. Stop termina únicamente proceso propio.

30. Run All termina PASS.

31. Missing Metrics es cero para baseline actual.

32. Total de checks queda registrado.

## 60. Consecuencias positivas

- checks visibles;
- baseline cuantificada;
- suites sin mantenimiento manual;
- nuevas carpetas se clasifican solas;
- parsing testeable;
- UI menos acoplada;
- Runner mantiene autoridad;
- métricas faltantes explícitas;
- Repeat auditable;
- mejor diagnóstico.

## 61. Consecuencias negativas

- nuevo módulo Python;
- nuevo unittest;
- Runner contract adicional;
- más columnas;
- configuración compartida cambia;
- output incluye marker JSON;
- implementación completa del Dashboard debe reemplazarse.

Estas consecuencias son aceptadas.

## 62. Estado

```text
VELOCITY TEST DASHBOARD 0.4.0

DISEÑO APROBADO

IMPLEMENTACIÓN PENDIENTE
```

Siguiente paso:

```text
Commit de diseño
```

Después:

```text
velocity_test_dashboard_logic.py
```
