# Velocity Test Dashboard — Diseño

| Campo | Valor |
|---|---|
| Estado | APROBADO |
| Versión del documento | 1.4 |
| Versión del Dashboard | 0.4.0 |
| Fecha | 04/09/2026 |
| Estado de implementación | COMPLETO Y VERIFICADO |
| Última verificación | 04/09/2026 |
| Lenguaje | Python 3.13 |
| UI | Tkinter 8.6 |
| Backend | run_godot_tests.ps1 |
| Plataforma inicial | Windows |

## 1. Propósito

Velocity Test Dashboard proporciona una interfaz visual para descubrir, clasificar, seleccionar, ejecutar y observar las pruebas de Velocity.

Dashboard 0.4.0 implementa:

- métricas de checks;
- check failures;
- missing metrics;
- Runner Metrics Protocol;
- suites automáticas;
- clasificación por nombres y rutas;
- lógica independiente de Tkinter;
- pruebas unitarias Python;
- Results Table ampliada;
- summary live;
- summary final cuantificado.

PowerShell Runner permanece como autoridad de ejecución.

## 2. Problemas resueltos

Dashboard 0.3.2:

- no agregaba Checks;
- no agregaba Check Failures;
- no detectaba Missing Metrics;
- dependía de suites manuales;
- no conocía DeviceGraph;
- no conocía Composition;
- no conocía DeviceCatalog;
- no conocía Runtime;
- mezclaba parsing con UI;
- definía `copy_command()` dos veces.

Runner anterior no inicializaba explícitamente:

```powershell
$engineErrorDetected = $false
```

por cada attempt.

Dashboard 0.4.0 corrige estas limitaciones.

## 3. Responsabilidades

### PowerShell Runner

> Ejecutar tests, aplicar límites, detectar errores, extraer métricas y emitir resultado estructurado.

### Dashboard Logic

> Parsear Metrics Protocol y clasificar suites sin depender de Tkinter o subprocess.

### Dashboard UI

> Presentar tests, ejecutar planes y mostrar resultados.

### Configuración compartida

> Definir rutas, aliases, orden y overrides.

### Configuración local

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

Versionados:

```text
run_godot_tests.ps1

velocity_test_dashboard_logic.py

velocity_test_dashboard.py

test_velocity_test_dashboard_logic.py

test_dashboard.json

start_velocity_test_dashboard.bat
```

No versionado:

```text
test_dashboard.local.json
```

## 5. Configuración compartida

Archivo:

```text
test/tools/test_dashboard.json
```

Contenido canónico:

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

`All` es una suite implícita.

## 6. Configuración local

Archivo:

```text
test/tools/test_dashboard.local.json
```

Contenido conceptual:

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

No fue modificado durante Dashboard 0.4.0.

No se versiona.

Prioridad:

```text
1. GODOT_CONSOLE

2. test_dashboard.local.json

3. file picker
```

## 7. Descubrimiento

Dashboard descubre escenas:

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

Cada test conserva:

- name;
- resource path;
- filesystem path;
- relative path;
- suite.

La extensión define ejecutabilidad como escena Godot.

No define categoría.

## 8. Clasificación automática

Suite se infiere por nombre y ruta.

Prioridad:

```text
1. override exacto;

2. alias del primer directorio;

3. directorio humanizado;

4. nombre de escena humanizado;

5. Other.
```

Aliases:

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

## 9. Directorios desconocidos

Un directorio desconocido se humaniza.

Ejemplo:

```text
measurement_contract
→ Measurement Contract
```

También se soportan:

- snake_case;
- kebab-case;
- PascalCase.

Una escena directamente bajo test root utiliza su nombre sin sufijo `Test`.

## 10. Orden de suites

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

Resultado verificado:

```text
Tests descubiertos:
54

Suites de dominio:
10

Valores con All:
11

Tests en Other:
0
```

## 11. Dashboard Logic

Archivo:

```text
test/tools/velocity_test_dashboard_logic.py
```

No depende de:

- Tkinter;
- subprocess;
- Godot;
- red;
- archivos temporales de métricas.

Responsabilidades:

- normalizar paths;
- humanizar nombres;
- inferir suites;
- aplicar aliases;
- aplicar overrides;
- ordenar suites;
- parsear markers;
- agregar attempts;
- sumar checks;
- sumar check failures;
- contar missing metrics;
- detectar errores de protocolo.

## 12. Modelos lógicos

### RunnerAttemptMetrics

```text
version

scene

attempt

available

checks

check_failures
```

### RunnerMetricsSummary

```text
attempts

checks

check_failures

metrics_runs

missing_metrics

markers_found

protocol_errors
```

Ambos son dataclasses inmutables.

## 13. Runner Metrics Protocol

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

## 14. Extracción de métricas

Runner analiza stdout de Godot.

Patrones:

```regex
^\s*Checks:\s*(\d+)\s*$

^\s*Failures:\s*(\d+)\s*$
```

Utiliza la última coincidencia de cada campo dentro del attempt.

Metrics está disponible únicamente cuando ambos valores existen.

## 15. Marker por attempt

Runner emite un marker por cada attempt, incluyendo:

- PASS;
- FAIL;
- TIMEOUT;
- ENGINE_ERROR;
- proceso no confirmado;
- summary ausente.

Esto permite distinguir:

```text
metrics unavailable

de

protocol marker missing
```

## 16. Cross-check defensivo

Si:

```text
check_failures > 0
```

y Godot devuelve:

```text
ExitCode 0
```

Runner convierte el attempt en FAIL.

No existe PASS silencioso con assertions fallidas.

## 17. Missing Metrics

Si un test termina PASS sin summary:

```text
Status:
PASS

Metrics:
Missing N
```

Dashboard no redefine el estado del Runner.

Ausencia de métrica no significa cero checks.

## 18. Repeat

Cada attempt emite marker.

Dashboard agrega:

- Checks;
- Check Failures;
- Metrics Runs;
- Missing Metrics.

Verificación:

```text
RuntimeFactoryKeyTest

Repeat:
2

Checks por attempt:
24

Total Runs:
2

Total Checks:
48

Check Failures:
0

Missing Metrics:
0

RESULT:
PASS
```

## 19. Runner Result

Campos por attempt:

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

## 20. Runner Summary

```text
Total runs

Passed

Failed

Total checks

Check failures

Missing metrics

RESULT
```

## 21. Engine Error

Runner inicializa:

```powershell
$engineErrorDetected = $false
```

por attempt.

Detecta:

```text
SCRIPT ERROR:

ERROR:

Parse Error:

Invalid call.
```

Godot ExitCode cero con Engine Error produce:

```text
ExitCode 126

ENGINE_ERROR
```

## 22. Timeout

Timeout produce:

```text
ExitCode 124

TIMEOUT
```

Runner continúa emitiendo marker.

## 23. PlanResult

Campos de métricas:

```python
checks: int

check_failures: int

metrics_runs: int

missing_metrics: int

protocol_errors: int
```

`reset_for_resume()` limpia métricas del resultado reejecutado.

PASS anteriores conservan métricas.

## 24. Results Table

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

Cantidad:

```text
8
```

Metrics:

```text
OK

Missing N

Error N

—
```

## 25. Summary live

Durante ejecución muestra:

- Completed;
- Passed;
- Failed;
- Checks;
- Check Failures;
- Missing Metrics.

Solo agrega resultados completados.

## 26. Summary final

Muestra:

- Planned;
- Completed;
- Passed;
- Failed;
- Timeout;
- Engine Error;
- Not Run;
- Total Runs;
- Checks;
- Check Failures;
- Missing Metrics;
- Plan ExitCode;
- RESULT.

## 27. Run Selected verificado

Test:

```text
RuntimeFactoryKeyTest
```

Resultado:

```text
Planned: 1
Completed: 1
Passed: 1
Failed: 0
Total Runs: 1
Checks: 24
Check Failures: 0
Missing Metrics: 0
Plan ExitCode: 0
RESULT: PASS
```

## 28. Runtime Suite verificada

```text
Planned: 6
Completed: 6
Passed: 6
Failed: 0
Total Runs: 6
Checks: 173
Check Failures: 0
Missing Metrics: 0
Plan ExitCode: 0
RESULT: PASS
```

Todas las filas mostraron:

```text
Metrics:
OK
```

## 29. Run All verificado

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

## 30. Pause y Resume

Se mantiene un único botón:

```text
Pause

Pausing...

Resume
```

Verificado:

- pausa después del test actual;
- PASS no se repite;
- métricas se conservan;
- NOT_RUN se reanuda;
- checks no se duplican;
- summary correcto.

## 31. Stop y Resume

Verificado con Runtime Suite y Repeat 5.

Comportamiento:

- Stop termina árbol propio;
- STOPPED se reinicia;
- PASS no se repite;
- métricas detenidas se limpian;
- no se duplican checks;
- no quedan procesos huérfanos.

## 32. Process creation

Python utiliza:

```python
subprocess.Popen
```

con:

```python
shell=False
```

Windows:

```text
CREATE_NO_WINDOW

STARTF_USESHOWWINDOW

SW_HIDE
```

No aparecen ventanas PowerShell o Godot Console.

## 33. Threading

Tkinter permanece en main thread.

Worker ejecuta subprocess.

`queue.Queue` transporta eventos.

`root.after()` consume eventos.

Worker no modifica widgets.

## 34. Output capture

Dashboard headers y Runner output permanecen separados para parsing.

Solo Runner output entra al parser de métricas.

Clear Output durante ejecución no borra el buffer pendiente del test.

Marker JSON permanece visible para auditoría.

## 35. Estados visuales

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

Missing Metrics no cambia status.

## 36. Stop

Windows utiliza:

```text
taskkill /PID <pid> /T /F
```

solo para el proceso creado por Dashboard.

No detiene procesos ajenos.

## 37. Cierre seguro

Si existe plan activo, pregunta antes de detener.

Si existe plan pausado, pregunta antes de descartarlo.

No deja procesos hijos.

## 38. Seguridad

No utiliza:

```python
shell=True
```

No ejecuta texto libre.

Las escenas provienen de discovery.

Metrics se interpreta mediante:

```python
json.loads
```

No se evalúa código desde JSON.

Repeat y Timeout se validan.

## 39. Unittest

Archivo:

```text
test/tools/test_velocity_test_dashboard_logic.py
```

Framework:

```text
unittest
```

Resultado:

```text
Ran 17 tests
OK
```

Cobertura:

- paths Windows;
- paths POSIX;
- resource paths;
- humanización;
- aliases;
- overrides;
- unknown folders;
- root-level tests;
- suite order;
- marker válido;
- unavailable marker;
- missing marker;
- malformed marker;
- protocol mismatch;
- wrong scene;
- Repeat;
- duplicate attempt;
- attempt fuera de rango;
- invalid values.

## 40. Compatibilidad preservada

- GODOT_CONSOLE;
- local config;
- Run Selected;
- Run Suite;
- Run All;
- Repeat;
- Timeout;
- Pause/Resume;
- Stop;
- Refresh;
- Copy Command;
- Copy Output;
- Clear Output;
- safe close;
- cero paquetes externos.

## 41. Archivos implementados

Modificados:

```text
test/tools/run_godot_tests.ps1

test/tools/test_dashboard.json

test/tools/velocity_test_dashboard.py
```

Nuevos:

```text
test/tools/velocity_test_dashboard_logic.py

test/tools/test_velocity_test_dashboard_logic.py
```

No modificado:

```text
test/tools/test_dashboard.local.json
```

## 42. Defectos corregidos

```text
copy_command duplicado:
eliminado.

engineErrorDetected implícito:
inicializado por attempt.

suites desactualizadas:
clasificación automática.

checks invisibles:
Metrics Protocol.

parsing mezclado con UI:
módulo lógico separado.
```

## 43. Commits

Diseño:

```text
4d7e431
docs(tools):
define dashboard metrics and automatic suites
```

Implementación:

```text
db330c2
feat(tools):
add test metrics and automatic suites
```

## 44. Criterios de aceptación

1. Marker por attempt.

2. JSON seguro.

3. Protocol version uno.

4. Checks extraídos.

5. Check Failures extraídos.

6. Missing Metrics explícito.

7. Check Failures no permiten PASS silencioso.

8. Dashboard consume marker.

9. PlanResult conserva métricas.

10. Results muestra Checks.

11. Results muestra Check Failures.

12. Results muestra Metrics.

13. Summary live agrega checks.

14. Summary final agrega checks.

15. Repeat agrega attempts.

16. Resume no duplica métricas.

17. Suites automáticas.

18. Device y DeviceCore agrupados.

19. Unknown directory humanizado.

20. Overrides prioritarios.

21. All implícita.

22. Logic sin Tkinter.

23. Unittest OK.

24. Un solo copy_command.

25. engineErrorDetected inicializado.

26. Local config preservada.

27. Sin consolas visibles.

28. Pause/Resume con un botón.

29. Stop solo termina proceso propio.

30. Run All PASS.

31. Missing Metrics cero.

32. Checks totales registrados.

Estado:

```text
TODOS LOS CRITERIOS SATISFECHOS
```

## 45. Baseline

```text
VELOCITY TEST DASHBOARD 0.4.0

IMPLEMENTADO

VERIFICADO

BASELINE ACEPTADA
```

```text
54 tests

1569 checks

0 failures

0 missing metrics

0 tests en Other
```

## 46. Fuera de alcance

- gráficas;
- historial persistente;
- comparación de commits;
- exportación;
- base de datos;
- plugin de Godot;
- remote execution;
- CI externo;
- edición de tests;
- JSON por run;
- red;
- telemetría.

## 47. Regla de evolución

Una función nueva no debe:

- duplicar Runner;
- redefinir status autoritativo;
- bloquear Tkinter;
- ejecutar comandos arbitrarios;
- modificar tests;
- dejar procesos huérfanos;
- ocultar Missing Metrics.

Dashboard continúa siendo un adaptador visual de infraestructura de pruebas.

## 48. Estado

```text
VELOCITY TEST DASHBOARD 0.4.0
COMPLETADO Y VERIFICADO
```

Siguiente evolución:

```text
solo ante necesidad verificable
```
