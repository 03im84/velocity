# Velocity Submit Tool — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO — COMPLETO Y VERIFICADO |
| Versión del documento | 1.5 |
| Versión objetivo de la herramienta | 1.1.1 |
| Fecha | 07/10/2026 |
| Plataforma inicial | Windows |
| Entrada principal | BAT guided launcher |
| Selector | Diálogo nativo mediante Tkinter |
| Motor | Python 3.13 compatible |
| Alcance | Instalación transaccional de paquetes externos y submit Git manifest-driven |
| Impacto en Core | Ninguno |

## 1. Propósito

Velocity Submit Tool reduce la carga repetitiva de aplicar y someter entregas sin reducir seguridad.

Responsabilidad:

> Validar, instalar y someter una entrega externa declarada por manifiesto.

`Submit` conserva su significado:

```text
staging
+
commit
+
push
```

La herramienta añade una fase anterior:

```text
install
```

## 2. Problema revisado

El diseño 1.0 automatizaba Git después de que el usuario copiara manualmente `repository_files/`.

Eso dejaba sin resolver:

- extracción del paquete;
- posicionamiento de archivos;
- confirmaciones de reemplazo;
- omisiones al copiar;
- riesgo de copiar README, SHA, manifest o ZIP;
- diferencia entre paquete recibido y working tree instalado.

El JSON ya describe rutas y hashes.

Por tanto, la misma herramienta puede aplicar la entrega de forma más segura que la copia manual.

## 3. Insight aceptado

El paquete permanece fuera de Velocity.

La herramienta recibe directamente su ruta.

Flujo:

```text
External ZIP
↓
Validate package
↓
Install repository_files transactionally
↓
Run authoritative tests
↓
Revalidate installed delivery
↓
Explicit staging
↓
Commit
↓
Push
```

La instalación y el submit son dos operaciones separadas porque las pruebas deben ejecutarse entre ambas.

## 4. Decisión

Se implementará:

```text
tools/git/velocity_submit.ps1
tools/git/velocity_submit.py
tools/git/velocity_submit.bat
test/tools/test_velocity_submit.py
```

Arquitectura:

```text
PowerShell guided launcher
+
Python engine
+
native ZIP file picker
+
external ZIP
+
SUBMIT_MANIFEST.json
+
local installation receipt
```

No se requiere ADR porque no cambia Core, dominio, runtime o hardware.

## 5. Package contract

Cada entrega futura es un ZIP externo:

```text
package-name/
├── repository_files/
├── README.txt
├── SHA256SUMS.txt
└── SUBMIT_MANIFEST.json
```

Solo el contenido lógico de `repository_files/` puede instalarse en Velocity.

Los otros artefactos permanecen fuera.

El usuario no necesita extraer el ZIP.

## 6. Invocación guiada

Comando ordinario recomendado:

```powershell
.\tools\git\velocity_submit.bat
```

También puede ejecutarse mediante doble clic.

BAT inicia PowerShell con:

```text
-NoProfile
-ExecutionPolicy Bypass
```

El bypass aplica únicamente al proceso temporal y no modifica políticas de usuario o sistema.

Si no existe receipt activo:

```text
Open native file picker
→ user selects one .zip
→ validate package
→ Install
```

El selector utiliza Tkinter, ya disponible por Velocity Test Dashboard.

Cancelar el diálogo produce `CANCELLED` sin modificar el repositorio.

PowerShell directo permanece disponible para diagnóstico:

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File ".\tools\git\velocity_submit.ps1"
```

Invocación explícita preservada:

```powershell
.\tools\git\velocity_submit.bat `
    "C:\Downloads\package-name.zip" `
    install
```

## 7. Frontera de pruebas

Después de Install, el usuario ejecuta:

- Godot Dashboard;
- Run All;
- unittest Python;
- otra evidencia indicada por la entrega.

La herramienta muestra `verification_summary`, pero no lo interpreta como evidencia automática.

El usuario confirma el PASS al ejecutar Submit.

No se ejecutan command strings desde JSON.

## 8. Segunda invocación — Submit

Después de las pruebas, el usuario ejecuta nuevamente:

```powershell
.\tools\git\velocity_submit.bat
```

La herramienta detecta receipt `installed` y reutiliza el package path seleccionado.

Si el ZIP todavía existe y su digest coincide, continúa sin abrir selector.

Si fue movido o renombrado:

1. abre file picker;
2. solicita el ZIP correspondiente;
3. exige mismo package SHA-256 y manifest SHA-256;
4. rechaza otro paquete.

Submit:

1. revalida paquete;
2. revalida receipt;
3. revalida HEAD, branch y remote;
4. revalida hashes instalados;
5. incorpora `.gd.uid` derivados;
6. rechaza cambios inesperados;
7. ejecuta diff checks;
8. realiza staging explícito;
9. muestra auditoría;
10. solicita `SUBMIT`;
11. crea commit;
12. ejecuta push;
13. verifica sincronización;
14. elimina receipt después de éxito.

Invocación explícita preservada:

```powershell
.\tools\git\velocity_submit.ps1 `
    -Package "C:\Downloads\package-name.zip" `
    -Submit
```

## 9. Modos explícitos y guided mode

Validación sin instalación:

```powershell
.\tools\git\velocity_submit.ps1 `
    -Package "C:\Downloads\package-name.zip" `
    -ValidatePackage
```

Modos explícitos mutuamente excluyentes:

```text
-ValidatePackage
-Install
-Submit
-Rollback
```

Guided mode no recibe switches.

`Rollback` nunca participa del guided mode: revertir una delivery instalada es siempre una decisión explícita.

State selection:

```text
no receipt
→ select ZIP
→ Install

receipt installed
→ use remembered ZIP
→ Submit

receipt installing
→ block and report recovery required

receipt local_commit_only
→ offer push retry path; never create another commit
```

No existe modo que instale y haga commit sin frontera de pruebas.

## 10. Manifest schema

Identidad:

```text
velocity-submit-manifest/v1
```

Forma:

```json
{
  "schema": "velocity-submit-manifest/v1",
  "delivery_id": "velocity-example-031026",
  "project": "velocity",
  "expected_branch": "main",
  "expected_head": "1334675",
  "remote": "origin",
  "commit_message": "feat(scope): description",
  "godot_uid_policy": "required_for_new_gd",
  "verification_summary": [
    "Selected test: PASS",
    "Run All: PASS"
  ],
  "files": [
    {
      "path": "core/example.gd",
      "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      "action": "add"
    }
  ]
}
```

## 11. File actions

Acciones 1.0:

```text
add
replace
```

### add

Exige:

- target no existe;
- target no está tracked;
- source existe dentro de `repository_files/`.

### replace

Exige:

- target existe;
- target es tracked;
- target no es symlink;
- repository estaba limpio antes de Install.

Fuera de alcance 1.0:

```text
delete
rename
copy
```

## 12. Package validation

Antes de extraer contenido, la herramienta exige:

- ZIP regular, no symlink;
- exactamente un package root;
- exactamente un `SUBMIT_MANIFEST.json` en root;
- exactamente un `repository_files/`;
- ningún path absoluto;
- ningún drive letter;
- ningún `..`;
- ningún path duplicado por case-folding;
- ningún symlink dentro del ZIP;
- ningún entry cifrado;
- máximo 10 000 entries;
- máximo 128 MiB sin comprimir;
- manifest UTF-8 JSON válido.

Esto bloquea Zip Slip y paquetes no acotados.

## 13. Archive allowlist

Entries permitidos:

```text
package-root/repository_files/<manifest paths>
package-root/README.txt
package-root/SHA256SUMS.txt
package-root/SUBMIT_MANIFEST.json
directories necesarias
```

Un archivo adicional no declarado se rechaza.

Los `.gd.uid` no vienen dentro del ZIP.

Godot los genera después de Install.

## 14. Manifest identity

Campos obligatorios:

```text
schema
delivery_id
project
expected_branch
expected_head
remote
commit_message
godot_uid_policy
files
```

`verification_summary` es opcional.

Campos desconocidos se rechazan.

No existe fallback de schema.

## 15. Delivery ID

Formato:

```text
^[a-z0-9][a-z0-9-]{2,79}$
```

Se usa para receipt, logs y observabilidad.

No se ejecuta.

## 16. Baseline

`expected_head` contiene hash Git lowercase de 7 a 40 caracteres.

Install y Submit exigen:

```text
HEAD == expected_head
```

Antes de Install se ejecuta fetch y se exige:

```text
HEAD == remote/branch
```

Esto evita aplicar un paquete sobre otra baseline.

## 17. Commit message

El mensaje viene declarado.

Debe cumplir Conventional Commit aceptado:

```text
feat
fix
docs
test
refactor
chore
build
ci
perf
revert
```

No se concatena en shell.

## 18. Path validation

Cada target path debe:

- ser relativo;
- usar `/`;
- no contener NUL;
- no contener empty segment;
- no contener `.` o `..`;
- no entrar a `.git`;
- no ser absoluto;
- no contener drive letter;
- no duplicarse;
- no colisionar por case-folding;
- resolver dentro de repository root.

No existe globbing.

## 19. Source hash

Cada file contiene SHA-256 de los bytes dentro del ZIP.

Antes de Install:

```text
hash(extracted source) == manifest sha256
```

Después de Install:

```text
hash(repository target) == manifest sha256
```

Antes de Submit se comprueba nuevamente.

## 20. Repository precondition for Install

Install requiere:

- repository Git válido;
- project.godot de Velocity;
- branch esperada;
- HEAD esperada;
- remote sincronizado;
- sin merge, rebase, cherry-pick, revert o bisect;
- index vacío;
- working tree completamente limpio.

Los ignored files no bloquean.

Cualquier untracked no ignorado bloquea.

## 21. Installation receipt

Estado local:

```text
.git/velocity-submit/active_delivery.json
```

Backups:

```text
.git/velocity-submit/backups/<delivery_id>/
```

Receipt contiene:

- schema interno;
- delivery ID;
- manifest SHA-256;
- package SHA-256;
- selected external package path;
- base commit;
- branch;
- remote;
- files y actions;
- hashes previos de replacements;
- estado `installing` o `installed`.

No se versiona.

No modifica `.git/config`.

## 22. Transactional installation

Secuencia:

```text
Validate everything
↓
Create receipt state=installing
↓
Backup every replace target
↓
Prepare source copies under .git/velocity-submit
↓
Apply add/replace targets
↓
Verify all target hashes
↓
Set receipt state=installed
↓
Report PASS
```

No copia un archivo antes de validar todos.

## 23. Install rollback on error

Si una excepción controlada ocurre durante Install:

- replacements aplicados se restauran desde backups;
- adds aplicados se eliminan;
- working tree vuelve al estado previo;
- receipt se elimina si rollback completa;
- no se ejecuta Git staging.

Si el proceso se interrumpe abruptamente y receipt queda `installing`, la siguiente ejecución no continúa automáticamente.

Reporta recovery requerido.

No sobrescribe una instalación incompleta.

## 24. Repeated Install

Si existe receipt `installed` para el mismo manifest y package:

- no vuelve a copiar;
- verifica targets;
- reporta `ALREADY_INSTALLED`.

Si receipt pertenece a otra entrega, aborta.

Si targets cambiaron, aborta.

## 25. Submit preflight

Submit requiere:

- receipt `installed`;
- mismo ZIP;
- mismo manifest digest;
- mismo package digest;
- mismo HEAD base;
- misma branch;
- remote sincronizado;
- manifest targets con hashes exactos;
- cambios Git exactamente iguales a manifest targets más UID sidecars válidos;
- ningún staging previo;
- ningún cambio inesperado.

## 26. Godot UID policy

Valor:

```text
required_for_new_gd
```

Reglas:

1. Todo `.gd` con action `add` requiere `<path>.uid` antes de Submit.
2. UID debe contener `uid://[a-z0-9]+`.
3. UID válido se deriva a la allowlist.
4. `.gd` reemplazado incluye UID solo si cambió.
5. UID inesperado bloquea.
6. UID no aparece en el manifest porque Godot lo genera localmente.

Install no exige UID.

Submit sí.

## 27. Staging

Solo después de Submit preflight:

```text
git add -- <explicit allowlist>
```

Prohibido:

```text
git add .
git add -A
git commit -a
```

Staged paths deben coincidir exactamente con allowlist.

## 28. Cached audit

```text
git diff --cached --name-status
git diff --cached --check
```

Mismatch o whitespace error aborta.

Antes de commit, la herramienta retira únicamente su staging si cancela o falla auditoría.

Working files instalados permanecen para diagnóstico.

## 29. Confirmation

Muestra:

- delivery ID;
- package;
- base;
- branch;
- remote;
- commit message;
- verification summary;
- staged name-status;
- file count;
- UID count.

Solicita:

```text
Type SUBMIT to confirm tests passed, commit and push:
```

Otra entrada cancela commit y push.

## 30. Commit

```text
git commit -m <manifest commit_message>
```

Verifica:

- exit code;
- HEAD cambió;
- subject exacto;
- working tree limpio.

Si commit falla:

- no push;
- no reset;
- staging se conserva;
- receipt se conserva.

## 31. Push

```text
git push <remote> <branch>
```

No usa:

- `--force`;
- `--force-with-lease`;
- otra ref;
- amend;
- rebase.

## 32. Push failure

Si push falla:

- commit local se conserva;
- receipt se conserva;
- no reset;
- resultado `LOCAL_COMMIT_ONLY`;
- exit no cero;
- se indica reintentar push después de analizar causa.

## 33. Success cleanup

Después de push verificado:

- HEAD coincide con remote branch;
- working tree está limpio;
- receipt se elimina;
- backups se eliminan;
- ZIP externo no se modifica.

Salida:

```text
VELOCITY SUBMIT RESULT: PASS
Delivery: <delivery_id>
Commit: <hash> <subject>
Files: <count>
Remote: synchronized
Status: ## main...origin/main
```

## 34. File picker safety

El selector:

- se abre solo en guided mode cuando necesita package;
- permite seleccionar un archivo;
- no escanea Downloads u otras carpetas;
- no concede paths adicionales;
- no copia antes de validar;
- no ejecuta el ZIP;
- no recuerda path fuera del receipt local;
- no versiona información de la máquina.

Si Tkinter o display no están disponibles:

- guided mode falla de forma clara;
- no modifica el repositorio;
- indica usar `-Package` explícito.

El path elegido se normaliza y debe apuntar a un ZIP regular, no symlink.

## 35. Error categories

```text
PACKAGE_ERROR
MANIFEST_ERROR
REPOSITORY_ERROR
BASELINE_ERROR
INSTALL_STATE_ERROR
INSTALL_ERROR
WORKTREE_ERROR
HASH_ERROR
UID_ERROR
STAGING_ERROR
COMMIT_ERROR
PUSH_ERROR
FINAL_STATE_ERROR
CANCELLED
```

Cada error incluye acción segura.

No imprime stack trace por defecto.

## 36. Subprocess safety

Python usa:

```text
subprocess.run([...], shell=False)
```

No usa:

- `shell=True`;
- eval;
- exec;
- Invoke-Expression;
- command strings desde manifest.

## 37. Zip safety

Python usa `zipfile` únicamente después de validar metadata de todos los entries.

Rechaza:

- Zip Slip;
- symlink entries;
- encrypted entries;
- case collisions;
- duplicate entries;
- límites excedidos.

Extrae a temporary directory fuera del repository root.

## 38. Authentication

Hereda autenticación Git existente.

No lee, solicita o almacena tokens propios.

No modifica credential helper.

## 39. Network

Operaciones permitidas:

```text
git fetch
git push
```

Solo contra remote declarado.

No realiza HTTP directo.

## 40. Test strategy — Package

Verifica:

- ZIP faltante;
- ZIP inválido;
- varios roots;
- manifest faltante;
- repository_files faltante;
- Zip Slip;
- absolute path;
- drive path;
- duplicate path;
- case collision;
- symlink entry;
- encrypted entry;
- file count limit;
- uncompressed size limit;
- extra archive file;
- source hash mismatch;
- picker cancel;
- picker selects non-ZIP;
- moved ZIP with matching digest;
- moved ZIP with different digest.

## 41. Test strategy — Install

Verifica:

- clean add;
- clean replace;
- wrong action;
- add target existente;
- replace target faltante;
- untracked collision;
- dirty repository;
- pre-staged state;
- baseline mismatch;
- remote ahead;
- backup creation;
- rollback after partial error;
- installed target hashes;
- receipt installed;
- repeated install;
- conflicting receipt.

## 42. Test strategy — Submit

Verifica:

- receipt faltante;
- package mismatch;
- manifest mismatch;
- target drift;
- unexpected change;
- UID handling;
- exact staging;
- cancellation;
- commit success;
- push success;
- push failure;
- receipt cleanup;
- remote sync.

## 43. Test repositories

Pruebas de integración utilizan:

```text
temporary working repository
+
local bare remote
+
temporary external ZIP
```

Nunca utilizan GitHub.

## 44. Windows launchers y UX

BAT es la entrada principal:

```powershell
.\tools\git\velocity_submit.bat
```

Razón:

Windows puede bloquear scripts `.ps1` descargados o no firmados mediante Execution Policy.

BAT ejecuta el wrapper PowerShell con bypass de proceso, sin modificar:

- LocalMachine;
- CurrentUser;
- registry;
- políticas persistentes.

PowerShell wrapper permanece como adapter interno y fallback explícito.

Python discovery:

```text
python.exe
py.exe -3
```

File picker:

```text
tkinter.filedialog.askopenfilename
```

El launcher no depende de current working directory.

El primer bootstrap verificó exitosamente:

- Python 3.10 en Windows;
- PowerShell con process-scoped Bypass;
- Tkinter native picker;
- external ZIP selection;
- package validation.

## 45. Bootstrap

La herramienta aún no puede instalarse a sí misma desde un ZIP porque no existe en la baseline actual.

Su implementación inicial requiere:

1. copiar manualmente una última vez;
2. ejecutar tests;
3. ejecutar `-ValidatePackage` o tests del motor;
4. realizar último submit manual;
5. registrar baseline.

Después de ese commit, ningún paquete ordinario requiere copia manual.

## 46. Alternatives revisadas

### Copia manual + submit automático

Rechazada después de revisión del usuario.

Automatizaba solo Git y conservaba carga operativa evitable.

### Install y commit inmediatos

Rechazada.

Eliminaría la frontera autoritativa de pruebas.

### Ejecutar comandos de test desde JSON

Rechazada 1.0.

Convertiría manifest en superficie de ejecución.

### Extraer o escribir path manualmente

No seleccionado como flujo ordinario.

Guided mode usa selector nativo y la herramienta valida y extrae con mayor seguridad.

`-Package` permanece como fallback explícito.

### Git alias o GUI

Insuficientes para package hashes, instalación transaccional y receipt.

## 47. Criterios de aceptación

1. ZIP permanece externo.
2. Guided mode abre selector nativo.
3. Usuario no escribe path en flujo ordinario.
4. Usuario no extrae manualmente.
5. Package layout exacto.
6. Zip Slip bloqueado.
7. Límites de archive.
8. Manifest schema exacto.
9. Branch explícita.
10. HEAD explícita.
11. Remote explícito.
12. Commit message explícito.
13. Paths explícitos.
14. Actions add/replace.
15. SHA-256 source y target.
16. Clean repository antes de Install.
17. Transactional install.
18. Backups para replace.
19. Rollback de install error.
20. Receipt local con package path y digest.
21. Frontera manual de pruebas.
22. Segunda invocación detecta Submit.
23. ZIP movido se re-selecciona y valida por digest.
24. Submit revalida package y receipt.
25. UID sidecars derivados.
26. Cambios inesperados bloqueados.
27. Staging explícito.
28. Cached audit.
29. Confirmación `SUBMIT`.
30. Commit exacto.
31. Push sin force.
32. Push failure conserva commit.
33. Receipt cleanup solo en éxito.
34. Sync final.
35. Fallback `-Package` explícito.
36. Unittest PASS.
37. Temp Git integration PASS.
38. Windows launcher y picker PASS.
39. Bootstrap manual documentado.
40. Rollback explícito, nunca guided.
41. Rollback exige receipt installed exacto.
42. Rollback valida hashes y allowlist antes de tocar archivos.
43. Rollback preserva evidencia ante cualquier discrepancia.
44. Rollback elimina state solo con working tree limpio.
45. Rollback confirmado con `ROLLBACK` textual.
46. Rollback nunca deshace commits.

## 48. Fuera de alcance

- ejecutar Godot;
- interpretar Dashboard;
- command strings desde manifest;
- deletion como action de manifest;
- rename;
- force push;
- amend;
- rebase;
- merge;
- tag;
- GitHub release;
- conflict resolution;
- cleanup de archivos ajenos;
- modificación de `.git/config`;
- credenciales propias;
- UI gráfica completa de gestión;
- install-and-submit sin test boundary.

## 49. Delivery rollback command — 1.1.0

La versión 1.1.0 añade el comando público `rollback` para el escenario:

```text
delivery instalada
→ pruebas fallan
→ todavía no existe commit
```

Responsabilidad:

> Restaurar exactamente la baseline declarada por el receipt activo y limpiar el estado de la delivery, sin tocar nada fuera de ella.

Entrada:

```powershell
.\tools\git\velocity_submit.ps1 -Rollback
```

```text
python velocity_submit.py --rollback
```

```text
Web VTD → Delivery → rollback
```

Preconditions obligatorias:

- receipt activo con `state = installed`;
- `installing` se rechaza: recovery manual requerido;
- `local_commit_only` se rechaza: rollback no deshace commits;
- rama actual igual a `receipt.branch`;
- `HEAD` igual a `receipt.base_commit`;
- índice Git vacío: staging previo se rechaza;
- cambios reales del working tree contenidos en la allowlist:
  paths del receipt más sidecars `.gd.uid` derivados;
- cada target instalado conserva el SHA-256 del receipt;
- cada backup de replace conserva `previous_sha256`;
- sidecars `.gd.uid` derivados solo se eliminan si:
  no están tracked,
  contienen un UID Godot válido,
  y derivan exactamente de un `.gd` declarado como add.

Cualquier incumplimiento aborta antes de modificar archivos y preserva receipt y backups como evidencia.

Confirmación destructiva:

```text
Type ROLLBACK to restore baseline <head> and discard delivery <id>:
```

Ejecución en orden inverso del receipt:

- replace: restaurar desde backup con copia atómica y verificar `previous_sha256`;
- add: eliminar target exacto y su sidecar UID derivado;
- directorios creados por adds se podan solo si quedan vacíos.

Post-condición:

- `git status` limpio; si no, `FINAL_STATE_ERROR` y evidencia preservada;
- `.git/velocity-submit/` se elimina solo después de verificar working tree limpio.

Resultado:

```text
VELOCITY DELIVERY ROLLBACK: PASS
Delivery: <id>
Baseline restored: <head>
Replacements restored: N
Additions removed: N
UID sidecars removed: N
State: receipt and backups cleared
```

No existe rollback de:

- install interrumpido (`installing`): recovery manual;
- commit local (`local_commit_only`): Retry Push;
- commit publicado: nuevo commit o `git revert` aprobado.

## 50. Estado

```text
VELOCITY SUBMIT TOOL 1.1.0
DELIVERY ROLLBACK COMMAND IMPLEMENTADO
VERIFICADO LOCALMENTE Y EN WINDOWS
END-TO-END SELF-ROLLBACK PASS
```

Componentes:

```text
velocity_submit_contract.py
velocity_submit_git.py
velocity_submit.py
velocity_submit_rollback.py
velocity_submit.ps1
velocity_submit.bat
test_velocity_submit.py
```

Baseline propia 1.0.0 preservada:

```text
Ran 44 tests
OK
skipped=1 esperado por restricción de symlink en Windows
```

Baseline propia 1.1.0:

```text
Ran 62 tests
OK
```

Tooling regression 1.1.0:

```text
Velocity Submit Tool: 62
Dashboard Web:        47
Dashboard Logic:      17
Total:               126
RESULT: OK
RollbackTests Repeat 5: 18 tests por run PASS
Web VTD Repeat 5:        47 tests por run PASS
```

Defensas añadidas durante auditoría del backup:

- addition faltante se rechaza como drift;
- receipt `installing` se rechaza;
- branch mismatch se rechaza;
- UID sidecar tracked se rechaza;
- prompt Web `ROLLBACK` recibe entrada textual real;
- Web VTD Reload Safety 0.5.1 se preserva.

Acceptance Windows ejecutada:

```text
Validation delivery installed: PASS
Windows tooling: 125 tests OK (skipped=1 symlink)
Rollback button enabled: PASS
Textual ROLLBACK: PASS
Replacements restored: 13
Additions removed: 2
UID sidecars removed: 0
Baseline restored: d36c7ee
Git status: clean
Receipt cleared: PASS
```

La Delivery final añadió únicamente presentación Environment/alineación sobre el core ya aceptado y ejecutó 126 tooling tests en Windows antes de Submit.

No se reutilizó ni instaló la Factory histórica preservada en el backup.

Entrada principal:

```text
tools\git\velocity_submit.bat
```

Feature commit:

```text
b219462 feat(tools): add delivery rollback command
```

```text
Final Windows tooling: 126 tests OK (skipped=1 symlink)
Remote: synchronized
RESULT: PASS
```

El milestone queda cerrado.

## 51. Rejected package cleanup after rollback — 1.1.1

Problema:

Un rollback exitoso restauraba el repositorio y eliminaba receipt y
backups, pero conservaba el ZIP de una entrega ya rechazada. El usuario
debía recordar y localizar manualmente ese paquete obsoleto.

Decisión aprobada el 07/10/2026:

> Un rollback exitoso elimina automáticamente el ZIP rechazado usando
> exclusivamente la última ubicación y el SHA-256 registrados en el
> receipt activo.

Autoridad:

```text
receipt.package_path
+
receipt.package_sha256
```

Secuencia:

```text
validate rollback preconditions
→ textual ROLLBACK confirmation
→ restore exact repository baseline
→ verify clean working tree
→ clear receipt and backups
→ inspect only the last known package path
→ delete only when path and SHA-256 still match
```

Defensas:

- no búsqueda recursiva;
- no globbing;
- no selección de otro archivo con el mismo nombre;
- symlinks rechazados;
- el target debe ser un archivo regular `.zip`;
- el ZIP debe permanecer fuera del repositorio;
- SHA-256 debe coincidir con el receipt;
- una ruta ausente o movida se reporta como `skipped`;
- un hash distinto se reporta como warning y el archivo se preserva;
- un fallo de filesystem es best-effort y no invalida un rollback del
  repositorio ya completado.

La confirmación destructiva informa también la eliminación:

```text
Type ROLLBACK to restore baseline <head>, discard delivery <id>, and delete its verified source ZIP:
```

Resultado nominal:

```text
VELOCITY DELIVERY ROLLBACK: PASS
Delivery: <id>
Baseline restored: <head>
Replacements restored: N
Additions removed: N
UID sidecars removed: N
State: receipt and backups cleared
Package cleanup: original ZIP deleted
```

Fallback seguro si el ZIP fue movido:

```text
Package cleanup: skipped — original ZIP was not found at its last known path
```

Fallback seguro si su identidad cambió:

```text
PACKAGE CLEANUP: WARNING — package SHA-256 changed
```

La eliminación posterior a `Submit PASS` reutiliza el mismo primitivo
de validación de path, tipo, ubicación y hash. Su confirmación separada
permanece vigente.

Regresión local 1.1.1:

```text
Velocity Submit Tool: 65 tests PASS
New rollback cleanup cases: 3 tests PASS
Canonical Tooling: 136 tests PASS
Canonical Repeat 5: PASS
Package E2E self-rollback: PASS
Resource warnings: 0
Static checks: PASS
Failures: 0
Errors: 0
```

Windows esperado:

```text
TestsRun: 136
Failures: 0
Errors: 0
Skipped: 1
ExitCode: 0
RESULT: PASS
```

El skip esperado sigue siendo la restricción condicional de symlink de
Windows; no pertenece a la nueva lógica de cleanup.
