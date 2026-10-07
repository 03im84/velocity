# Velocity Tooling Dashboard Web — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO — IMPLEMENTADO Y VERIFICADO |
| Versión | 1.6 |
| Producto objetivo | Velocity Tooling Dashboard 0.6.0 |
| Fecha | 04/10/2026 |
| Backend | Python 3.10+ standard library |
| Frontend | HTML, CSS y JavaScript vanilla |
| Transporte | HTTP local + Server-Sent Events |
| Host | 127.0.0.1 solamente |
| Predecesor | Velocity Test Dashboard 0.4.0 Tkinter |
| Estado de implementación | COMPLETO Y VERIFICADO |

## 1. Propósito

Portar VTD a una interfaz web local manteniendo Python como autoridad operacional.

Responsabilidad:

> Presentar tests, deliveries, progreso, historial y configuración desde una sola interfaz local sin trasladar lógica de seguridad al navegador.

## 2. Nombre

El producto pasa conceptualmente de:

```text
Velocity Test Dashboard
```

a:

```text
Velocity Tooling Dashboard
```

Conserva el acrónimo:

```text
VTD
```

## 3. Motivo

VTD ahora debe integrar:

- test discovery;
- execution plans;
- live output;
- metrics;
- Delivery Install;
- Submit;
- receipt state;
- Git status;
- themes;
- browser selection;
- server lifecycle.

Tkinter 0.4.0 mezcla estas responsabilidades en un archivo de 2041 líneas.

La tecnología web permite separar backend, estado y presentación.

## 4. Last Known Good

Tkinter 0.4.0 permanece versionado y ejecutable durante toda la transición.

No se retira hasta que Web 0.5.0 demuestre paridad mediante pruebas sucesoras.

## 5. Arquitectura

```text
Browser UI
HTML + CSS + JavaScript
        │
        ├── HTTP JSON
        └── SSE
        ▼
Python Local Backend
        ├── Test Application Service
        ├── Delivery Application Service
        ├── Configuration Service
        ├── Event Broker
        ├── Browser Launcher
        └── Server Lifecycle
                │
                ├── Godot Runner
                └── Velocity Submit Tool
```

## 6. Dependencias

Versión 0.5.0 utiliza Python standard library.

No requiere:

- Flask;
- FastAPI;
- Django;
- Node.js;
- npm;
- React;
- Vue;
- CDN;
- recursos web externos.

## 7. Backend previsto

```text
test/tools/velocity_dashboard_service.py
test/tools/velocity_dashboard_web.py
```

Launcher:

```text
test/tools/start_velocity_dashboard_web.bat
```

## 8. Frontend previsto

```text
test/tools/web/
├── index.html
├── styles.css
└── app.js
```

Todos los assets son locales.

## 9. Test service

Responsabilidades:

- cargar configuración;
- descubrir escenas;
- inferir Suites;
- crear planes;
- ejecutar runner;
- stream de output;
- pause after current;
- resume;
- stop;
- parse Metrics Protocol;
- summary final.

Reutiliza:

```text
velocity_test_dashboard_logic.py
run_godot_tests.ps1
```

## 10. Delivery service

Responsabilidades UI:

- seleccionar ZIP;
- iniciar Install;
- mostrar receipt;
- refrescar tests después de Install;
- preparar Submit;
- mostrar exact staged preview;
- solicitar confirmación textual;
- commit y push;
- retry push;
- preguntar cleanup del ZIP.

La autoridad permanece en Velocity Submit Tool.

## 11. Delivery execution

El backend importa la API Python de Submit Tool.

No duplica:

- ZIP validation;
- manifest parsing;
- receipt;
- hashes;
- install;
- Git gates;
- commit;
- push.

Input prompts se adaptan a eventos UI y respuestas HTTP.

## 12. UI layout

```text
Header navigation
├── Tests
├── Delivery
├── History
└── Settings

Main terminal/output

Right sidebar
├── Plan
├── Progress
└── Environment

Bottom command bar
```

Estética inspirada en terminal moderna oscura.

## 13. Temas

Temas obligatorios:

```text
light
dark
reading
```

Implementados mediante CSS variables:

```css
:root[data-theme="light"]
:root[data-theme="dark"]
:root[data-theme="reading"]
```

Default:

```text
dark
```

## 14. Tema lectura

Tema cálido con:

- fondo sepia;
- saturación reducida;
- mayor line-height;
- fuente ligeramente mayor;
- menor densidad visual;
- animación reducida.

## 15. Persistencia visual

Tema se conserva en:

- localStorage para aplicación inmediata;
- `test_dashboard.local.json` como configuración canónica local.

No se versiona.

## 16. Browser select

Settings utiliza un elemento HTML:

```html
<select id="browser-select">
```

Opciones:

```text
system_default
edge
chrome
firefox
custom
```

Al seleccionar `custom` aparecen:

- path read-only;
- Browse;
- Test Browser;
- Reset.

## 17. Browser path

El path se elige mediante helper nativo Python.

No se introduce manualmente en flujo normal.

Persistencia:

```json
{
  "browser": {
    "mode": "system_default",
    "executable": "",
    "window_mode": "tab"
  }
}
```

## 18. Browser launch safety

Backend utiliza:

```text
subprocess.Popen([...], shell=False)
```

No acepta argument strings arbitrarios desde frontend o JSON.

Custom executable debe ser archivo `.exe` válido en Windows.

## 19. Browser window modes

```text
tab
application
```

`application` usa `--app=<url>` únicamente con Edge o Chrome reconocidos.

Firefox y custom desconocido utilizan tab mode.

No se termina el proceso completo del navegador al apagar VTD.

## 20. Server config

```json
{
  "server": {
    "host": "127.0.0.1",
    "port": 0,
    "shutdown_delay_ms": 750
  }
}
```

Host no es editable.

Port:

```text
0 = automático
1024–65535 = explícito
```

## 21. Port conflict

Puerto explícito ocupado produce error.

No existe fallback silencioso a otro puerto.

Puerto 0 permite asignación del sistema operativo.

Cambiar puerto requiere server restart.

## 22. Single instance

Estado local:

```text
test/tools/.test_dashboard/server.json
```

Contiene:

- PID;
- host;
- port;
- session ID;
- start time.

Launcher detecta instancia activa y abre la URL existente.

State stale se elimina después de validación.

## 23. HTTP security

Servidor escucha únicamente:

```text
127.0.0.1
```

Obligatorio:

- session token aleatorio;
- cookie HttpOnly;
- SameSite=Strict;
- CSRF token;
- Origin validation;
- Content Security Policy;
- no directory listing;
- assets allowlist;
- no arbitrary filesystem endpoint;
- no command endpoint.

## 24. API inicial

```text
GET  /api/bootstrap
GET  /api/state
GET  /api/tests
GET  /api/events
POST /api/tests/refresh
POST /api/run
POST /api/run/pause
POST /api/run/resume
POST /api/run/stop
POST /api/delivery/select
POST /api/delivery/install
POST /api/delivery/prepare-submit
POST /api/delivery/confirm-submit
GET  /api/settings
POST /api/settings
POST /api/browser/select
POST /api/browser/test
POST /api/shutdown/request
```

## 25. SSE

Server-Sent Events transporta:

- log lines;
- plan progress;
- test result;
- summaries;
- delivery state;
- Git output;
- shutdown state.

SSE reconnect utiliza event IDs.

No se requiere WebSocket 0.5.0.

## 26. Operation exclusivity

No se ejecutan simultáneamente:

- test plan;
- Delivery Install;
- staging/commit/push;
- server restart.

UI deshabilita acciones incompatibles.

Backend también valida; no confía solo en botones.

## 27. Shutdown button

Header incluye:

```text
Apagar
```

Flujo técnico:

```text
POST shutdown request
→ validate operation state
→ return 202
→ frontend attempts window close
→ delay
→ close SSE
→ flush config/history
→ remove server state
→ server.shutdown
```

La señal precede al cierre para no perder el request.

Visualmente la ventana cierra antes del server.

## 28. Shutdown restrictions

Test activo:

- requiere confirmación Stop + Shutdown;
- espera runner exit.

Install, commit o push activo:

- Shutdown deshabilitado.

Local commit only:

- shutdown permitido;
- receipt preservado.

## 29. Browser close limitation

Normal tabs pueden bloquear `window.close()`.

Tab mode hace best effort y muestra fallback.

Application mode ofrece ventana dedicada para Edge/Chrome.

Nunca se mata un browser process compartido.

## 30. Local config

`test_dashboard.local.json` se amplía sin invalidar keys existentes.

Escritura atómica.

Defaults nuevos se mezclan con configuración anterior.

## 31. Migration

Fase 1:

```text
extract application service
```

Fase 2:

```text
HTTP API + SSE
```

Fase 3:

```text
web UI + themes
```

Fase 4:

```text
Delivery integration
```

Fase 5:

```text
parity tests
```

Tkinter se conserva hasta Fase 5 PASS.

## 32. Test strategy

Backend tests:

- config merge;
- browser select validation;
- port validation;
- test discovery;
- plan state;
- operation exclusion;
- security headers;
- session authentication;
- CSRF;
- API routing;
- SSE event serialization;
- shutdown scheduling.

Frontend static contract tests:

- required tabs;
- browser select;
- three themes;
- shutdown button;
- no external assets;
- CSP compatibility.

Integration:

- local server start;
- API bootstrap;
- test run;
- event stream;
- delivery state;
- shutdown.

## 33. Versioning

```text
Velocity Test Dashboard 0.4.0
LKG
```

```text
Velocity Tooling Dashboard 0.5.1
accepted web successor
```

## 34. Criterios de aceptación

1. Python backend.
2. HTML/CSS/JS vanilla.
3. no external web dependency.
4. localhost only.
5. authenticated local session.
6. CSRF protection.
7. SSE live output.
8. test discovery parity.
9. Runner parity.
10. pause/resume/stop parity.
11. metrics parity.
12. Delivery integrated.
13. staged preview before Submit.
14. textual Submit confirmation.
15. browser `<select>`.
16. custom browser path.
17. browser config persisted.
18. port configurable.
19. port config persisted.
20. shutdown button.
21. delayed server stop.
22. light theme.
23. dark theme.
24. reading theme.
25. local theme persistence.
26. no UI freeze.
27. Tkinter LKG preserved.
28. BAT fallback preserved.
29. tests PASS.
30. Windows candidate preview accepted.

## 35. Fuera de alcance

- remote network access;
- multi-user server;
- cloud dashboard;
- arbitrary command terminal;
- IDE features;
- editing game data;
- browser credential storage;
- external telemetry;
- mobile support;
- removing Tkinter before parity;
- frontend frameworks;
- npm build.

## 36. Estado

```text
VELOCITY TOOLING DASHBOARD 0.5.1
IMPLEMENTADO
VERIFICADO
ACEPTADO COMO INTERFAZ RECOMENDADA
```

Componentes:

```text
velocity_dashboard_service.py
velocity_dashboard_delivery.py
velocity_dashboard_web.py
velocity_native_picker.py
index.html
styles.css
app.js
start_velocity_dashboard_web.bat
```

Pruebas:

```text
VTD Web:         43
Submit Tool:     44
Dashboard Logic: 17
Total tooling:   104
RESULT: OK
```

Godot regression:

```text
85 tests
2418 checks
0 failures
0 missing metrics
RESULT: PASS
```

Windows UX:

```text
Dark/Light/Reading themes: PASS
Browser select:            PASS
Custom path:               PASS
Configurable port:         PASS
Run All responsive:        PASS
Deterministic summary:     PASS
Clear controls:            PASS
Delivery integration:      PASS
No CLI flashes:            PASS
Shutdown:                  PASS
ZIP cleanup:               PASS
```

Feature commit:

```text
314a7a7
feat(tools): add web tooling dashboard candidate
```

Tkinter 0.4.0 permanece versionado como fallback Last Known Good.

Web launcher recomendado:

```text
test/tools/start_velocity_dashboard_web.bat
```

## 37. Product Roadmap and Gantt

VTD 0.5.1 includes a read-only Roadmap tab backed by:

```text
docs/project_state/velocity_roadmap.json
```

It displays relative phases, dependencies, progress, current milestone and Playable Vertical Slice target. No calendar dates are invented.

Candidate baseline:

```text
VTD Web: 39 tests PASS
Tooling total: 100 tests PASS
```

## 38. Reload Safety 0.5.1

Problemas observados en Windows:

1. un reload del navegador reejecutaba prompts históricos de Submit;
2. un Install que reemplazaba el roadmap no actualizaba la vista hasta reiniciar el servidor.

Causa del prompt:

```text
EventBroker history
+
fresh EventSource without Last-Event-ID
+
server default cursor 0
=
full historical replay
```

Un `delivery_prompt` histórico volvía a ejecutar `window.prompt()` aunque la operación ya hubiera finalizado.

Solución:

```text
bootstrap captures current event cursor
→ frontend connects /api/events?after=<cursor>
→ fresh page skips old history
→ SSE reconnect still uses Last-Event-ID
```

Defensa adicional:

Antes de mostrar un prompt, el frontend consulta `/api/state` y exige que `pending_prompt` siga coincidiendo exactamente.

Si una página se recarga mientras existe un prompt genuinamente pendiente, bootstrap lo restaura una sola vez.

Roadmap:

```text
successful Install
→ refresh tests
→ reload roadmap from disk
→ publish roadmap_updated
→ renderRoadmap
```

No se requiere reiniciar VTD después de instalar una entrega que actualice `velocity_roadmap.json`.

## 39. Baseline 0.5.1

```text
VTD Web:         43 tests PASS
Submit Tool:     44 tests PASS
Dashboard Logic: 17 tests PASS
Total tooling:   104 tests PASS
Python compile:  PASS
JavaScript parse: PASS
```

Regresiones específicas:

- fresh cursor skips historical `delivery_prompt`;
- live events después del cursor permanecen disponibles;
- Last-Event-ID y query cursor se resuelven sin retroceso;
- Install recarga y publica roadmap;
- bootstrap expone event cursor;
- frontend restaura solo un prompt actualmente pendiente.

Estado:

```text
VELOCITY TOOLING DASHBOARD 0.5.1
RELOAD SAFETY IMPLEMENTADA Y VERIFICADA
```

## 40. Delivery Rollback Integration 0.5.2

Web VTD expone el comando seguro de Velocity Submit Tool 1.1.0 mediante:

```text
POST /api/delivery/rollback
```

Control:

```text
rollback button enabled
↔ receipt_state == installed
and no test or Delivery operation is active
```

Flujo:

```text
user selects rollback
→ backend starts rollback worker
→ tool validates receipt, branch, HEAD, index, allowlist and hashes
→ delivery_prompt requests textual ROLLBACK
→ frontend verifies prompt against /api/state
→ user confirms
→ exact baseline restored
→ receipt/backups cleared only after clean status
```

Reload Safety 0.5.1 permanece vigente:

- fresh browser page no reproduce prompts históricos;
- pending prompt real se restaura una vez;
- `ROLLBACK` se trata como entrada textual explícita;
- SSE reconnect conserva `Last-Event-ID`;
- Install recarga tests y roadmap.

Estados no aptos:

```text
receipt none              → rollback disabled
receipt installing        → backend rejects
receipt local_commit_only → backend rejects
operation busy            → rollback disabled
```

## 41. Baseline 0.5.2

```text
VTD Web:         47 tests PASS
Submit Tool:     62 tests PASS
Dashboard Logic: 17 tests PASS
Total tooling:   126 tests PASS
Web Repeat 5:    47 tests per run PASS
Rollback Repeat 5: 18 tests per run PASS
Windows E2E self-rollback: PASS
```

Estado:

```text
VELOCITY TOOLING DASHBOARD 0.5.2
ROLLBACK INTEGRATION IMPLEMENTADA
LOCAL VERIFICATION PASS
WINDOWS END-TO-END SELF-ROLLBACK PASS
```

Presentación final:

- versión VTD visible en Environment;
- Delivery ID completo disponible como tooltip;
- cuatro acciones Delivery alineadas en una sola fila.

Windows final:

```text
126 tooling tests OK (skipped=1 symlink)
visual version/alignment PASS
Submit PASS
Remote synchronized
```

Feature commit:

```text
b219462 feat(tools): add delivery rollback command
```

## 42. Local Commit Retry Routing 0.5.3

Problema observado:

```text
Submit local commit created
→ GitHub push returns remote 500
→ receipt state local_commit_only
→ Web Prepare Submit invoked explicit submit mode
→ normal baseline preflight rejected moved HEAD
```

CLI guided mode ya resolvía correctamente:

```text
installed receipt         → submit
local_commit_only receipt → retry-push
```

Decisión:

`DeliveryService.start_submit()` invoca `guided` en lugar de `submit` explícito.

El backend mantiene la autoridad de state routing. Frontend no interpreta receipt para decidir operation mode.

Prompt esperado para preserved local commit:

```text
Type PUSH to retry the preserved local commit:
```

El usuario confirma `PUSH`, no `SUBMIT`.

Preconditions de `retry_push_preflight` permanecen:

- receipt `local_commit_only`;
- commit_hash presente;
- HEAD igual al commit preservado;
- branch exacta;
- working tree limpio;
- remote disponible;
- package exacto.

Regression:

```text
start_submit passes mode guided
normal submit prompt remains supported
rollback routing remains explicit
```

Baseline:

```text
Web VTD:         48 tests PASS
Web Repeat 5:    PASS
Submit Tool:     62 tests PASS
Dashboard Logic: 17 tests PASS
Total tooling:  127 tests PASS
Python compile:  PASS
```

Estado:

```text
WEB VTD 0.5.3
LOCAL_COMMIT_ONLY ROUTING CORREGIDO
VERIFICACIÓN LOCAL PASS
```

## 43. Canonical Tooling Test Runner 0.6.0

Authority:

```text
tools/testing/velocity_tooling_tests.py
```

Canonical modules:

```text
test/tools/test_velocity_submit.py
test/tools/test_velocity_dashboard_web.py
test/tools/test_velocity_test_dashboard_logic.py
```

Entradas:

```text
Web VTD → Tooling tab → Run Tooling
velocity_tooling_tests.bat
velocity_tooling_tests.ps1
python tools/testing/velocity_tooling_tests.py
```

Web y CLI ejecutan el mismo runner; JavaScript no duplica lógica unittest.

`ToolingTestService`:

- worker thread;
- child process shell-free;
- stdout/stderr live por SSE;
- Run/Stop;
- process-tree termination;
- status/exit/duration observable;
- pipe cleanup explícito;
- mutual exclusion con Godot plans, Delivery, Settings y Shutdown.

CLI permanece disponible si Web VTD no arranca, el puerto falla o frontend/SSE están indisponibles.

Summary:

```text
VELOCITY TOOLING TEST SUMMARY
Modules: 3
DurationSeconds: N
ExitCode: N
RESULT: PASS|FAIL
```

Baseline:

```text
Canonical tooling tests: 132 PASS
Canonical runner Repeat 5: PASS
Python compile: PASS
JavaScript parse: PASS
Resource warnings: 0
```

Estado:

```text
WEB VTD 0.6.0
CANONICAL TOOLING RUNNER IMPLEMENTADO
CLI FALLBACK IMPLEMENTADO
VERIFICACIÓN LOCAL PASS
WINDOWS ACCEPTANCE PENDIENTE
```

## 44. Python 3.10 Path-Independent Loader — Runner 1.0.1

Windows acceptance de candidate 1.0.0 falló antes de ejecutar tests:

```text
Python 3.10 unittest path arguments
→ test/tools/file.py convertido a test.tools.file
→ ModuleNotFoundError: No module named test.tools
```

Python 3.13 local aceptaba los mismos paths, ocultando la incompatibilidad.

Corrección r1:

```text
insert explicit test/tools in sys.path
import modules by filename stem
load tests with unittest.TestLoader
aggregate unittest.TestSuite
run in-process with TextTestRunner
```

No existe conversión path-to-module dependiente de versión.

Summary ampliado:

```text
TestsRun
Failures
Errors
Skipped
DurationSeconds
ExitCode
RESULT
```

Baseline r1:

```text
132 tests PASS
Repeat 5 PASS
Python compile PASS
Resource warnings 0
```

Estado:

```text
CANONICAL TOOLING RUNNER 1.0.1
PATH-INDEPENDENT LOADER IMPLEMENTADO
WINDOWS REVALIDATION PENDIENTE
```

## 45. Windows Live Progress and Hidden Child Processes — Runner 1.0.2

Windows r1 loaded modules correctly but exposed two UX defects:

```text
unittest verbosity 1
→ progress emitted as dots without newline
→ line-based SSE showed no live progress
```

and:

```text
test fixture Git subprocesses without hidden flags
→ transient console windows flashed repeatedly
```

Corrections:

- `TOOLING_TEST_VERBOSITY = 2` emits one line per test;
- `test_velocity_submit.run_command()` uses `hidden_subprocess_options()`;
- static regression requires hidden subprocess options;
- runner summary preserves TestsRun/Failures/Errors/Skipped.

Baseline r2:

```text
133 tests PASS
Repeat 5 PASS
Python compile PASS
JavaScript parse PASS
Resource warnings 0
```

Estado:

```text
CANONICAL TOOLING RUNNER 1.0.2
WINDOWS LIVE PROGRESS IMPLEMENTED
WINDOWS CHILD CONSOLES HIDDEN
WINDOWS ACCEPTANCE PASS — 133 TESTS, SKIPPED 1
```

## 46. Rollback rejected-package cleanup — Submit Tool 1.1.1

Web VTD conserva el endpoint y la exclusión de operaciones de 0.5.2.
No incorpora lógica de filesystem en JavaScript. La autoridad permanece
en Velocity Submit Tool.

Flujo ampliado:

```text
user confirms textual ROLLBACK
→ tool restores and verifies exact baseline
→ tool clears receipt and backups
→ tool checks receipt.package_path only
→ matching external regular ZIP + matching SHA-256
   → original ZIP deleted
→ absent/moved/mismatched package
   → skipped or warning; no search and no substitute deletion
→ complete result streams through existing Delivery SSE
```

El prompt informa que el ZIP verificado será eliminado. El frontend
continúa transportando texto y no interpreta path, hash ni política de
cleanup.

Resultado Web nominal adicional:

```text
Package cleanup: original ZIP deleted
```

La operación sigue siendo `PASS` cuando el cleanup best-effort emite un
warning después de restaurar correctamente el repositorio. Esto evita
presentar como fallido o reversible un rollback que ya alcanzó su
post-condición autoritativa.
