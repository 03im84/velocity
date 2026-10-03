# Velocity Tooling Dashboard Web — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO — IMPLEMENTADO Y VERIFICADO |
| Versión | 1.1 |
| Producto objetivo | Velocity Tooling Dashboard 0.5.0 |
| Fecha | 03/10/2026 |
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
Velocity Tooling Dashboard 0.5.0
successor candidate
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
VELOCITY TOOLING DASHBOARD 0.5.0
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
VTD Web:         35
Submit Tool:     44
Dashboard Logic: 17
Total tooling:   96
RESULT: OK
```

Godot regression:

```text
76 tests
2262 checks
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
