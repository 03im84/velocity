# Velocity Submit Tool — Diseño

| Campo | Valor |
|---|---|
| Estado | ACTIVO — APROBADO PARA IMPLEMENTACIÓN DESPUÉS DEL COMMIT DOCUMENTAL |
| Versión del documento | 1.0 |
| Versión de la herramienta | 1.0.0 |
| Fecha | 03/10/2026 |
| Plataforma inicial | Windows |
| Entrada principal | PowerShell |
| Motor | Python 3.13 compatible |
| Alcance | Validación de entrega, staging explícito, commit, push y verificación Git |
| Impacto en Core | Ninguno |

## 1. Propósito

Velocity Submit Tool reduce la carga repetitiva y propensa a errores del submit sin eliminar las protecciones del flujo Git.

Responsabilidad:

> Validar y someter una entrega declarada por manifiesto mediante staging explícito, commit, push y verificación final.

`Submit` conserva su significado canónico:

```text
staging
+
commit
+
push
```

La herramienta automatiza operación Git.

No acepta arquitectura, implementación o pruebas en nombre del usuario.

## 2. Problema

El flujo actual exige repetir manualmente:

```text
git status --short
git diff --check
staging explícito
git diff --cached --name-status
git diff --cached --check
git commit
git log -1 --oneline
git status --short
git push origin main
git status -sb
```

Este flujo es seguro, pero produce:

- carga operativa alta;
- listas de staging extensas;
- riesgo de omitir `.gd.uid`;
- riesgo de incluir artefactos accidentales;
- mensajes repetitivos entre usuario y asistente;
- posibilidad de ejecutar push después de un commit fallido;
- fatiga durante milestones grandes.

La repetición no añade valor arquitectónico.

## 3. Restricciones

La automatización no puede:

- utilizar `git add .`;
- aceptar archivos no declarados;
- borrar archivos inesperados;
- ejecutar código contenido en un manifiesto;
- ocultar errores Git;
- inventar un mensaje de commit;
- asumir que las pruebas pasaron;
- hacer force push;
- resetear commits;
- almacenar credenciales;
- modificar `.git/config`;
- sustituir revisión arquitectónica;
- sustituir Dashboard o Godot.

## 4. Decisión

Se implementará una herramienta manifest-driven con:

```text
tools/git/velocity_submit.ps1
```

como entrada Windows y:

```text
tools/git/velocity_submit.py
```

como motor verificable.

Launcher opcional:

```text
tools/git/velocity_submit.bat
```

Pruebas:

```text
test/tools/test_velocity_submit.py
```

Cada paquete futuro incluirá fuera de `repository_files/`:

```text
README.txt
SHA256SUMS.txt
SUBMIT_MANIFEST.json
```

`SUBMIT_MANIFEST.json` nunca entra al repositorio.

## 5. Razón de PowerShell + Python

PowerShell conserva una invocación natural en Windows.

Python se selecciona como motor porque:

- ya es dependencia del Dashboard canónico;
- existe Python 3.13 en el entorno del proyecto;
- permite parsing JSON estricto;
- permite path validation portable;
- permite subprocess sin shell interpolation;
- permite pruebas unitarias e integración con `unittest`;
- permite crear repositorios Git temporales;
- evita depender de Pester;
- reduce complejidad del launcher PowerShell.

PowerShell no contiene lógica Git compleja.

## 6. Invocación

Comando principal:

```powershell
.\tools\git\velocity_submit.ps1 `
    -Manifest "C:\ruta\al\paquete\SUBMIT_MANIFEST.json"
```

Validación sin staging:

```powershell
.\tools\git\velocity_submit.ps1 `
    -Manifest "C:\ruta\al\paquete\SUBMIT_MANIFEST.json" `
    -ValidateOnly
```

Launcher alternativo:

```powershell
tools\git\velocity_submit.bat `
    "C:\ruta\al\paquete\SUBMIT_MANIFEST.json"
```

## 7. Flujo de usuario

```text
1. Extraer paquete fuera de Velocity.

2. Copiar únicamente repository_files/.

3. Refrescar Godot cuando corresponda.

4. Ejecutar pruebas autoritativas.

5. Ejecutar Velocity Submit Tool.

6. Revisar resumen.

7. Escribir SUBMIT una vez.

8. Copiar resultado final al asistente.
```

## 8. Manifest schema

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
  "expected_head": "38a5ea7",
  "remote": "origin",
  "commit_message": "docs(tools): example delivery",
  "godot_uid_policy": "required_for_new_gd",
  "verification_summary": [
    "Selected test: PASS",
    "Run All: PASS"
  ],
  "files": [
    {
      "path": "docs/example.md",
      "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      "action": "upsert"
    }
  ]
}
```

## 9. Campos obligatorios

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

`verification_summary` puede estar vacío.

No concede evidencia automática.

Solo muestra las pruebas que el usuario debe haber ejecutado antes de confirmar.

## 10. Schema

Valor exacto:

```text
velocity-submit-manifest/v1
```

Otro valor se rechaza.

No existe fallback a versiones desconocidas.

## 11. Delivery ID

Formato:

```text
lowercase letters
numbers
hyphen
```

Regex conceptual:

```text
^[a-z0-9][a-z0-9-]{2,79}$
```

Se utiliza para observabilidad.

No se ejecuta.

## 12. Project

Valor 1.0:

```text
velocity
```

La herramienta verifica:

- repositorio Git válido;
- `project.godot` presente;
- `config/name="velocity"` presente.

## 13. Expected branch

Valor ordinario:

```text
main
```

La herramienta rechaza:

- detached HEAD;
- branch distinta;
- branch vacía.

## 14. Expected HEAD

`expected_head` contiene un hash Git hexadecimal de 7 a 40 caracteres.

La herramienta:

1. resuelve el hash mediante Git;
2. exige que sea commit;
3. exige que coincida con HEAD actual.

Esto evita aplicar una entrega sobre una baseline inesperada.

## 15. Remote

Valor ordinario:

```text
origin
```

La herramienta exige que el remote exista.

Antes de commit:

```text
git fetch <remote> <branch>
```

Después exige:

```text
HEAD == <remote>/<branch>
```

Si remote está ahead, behind o diverged, aborta antes de staging.

## 16. Commit message

Debe ser explícito en el manifiesto.

Formato Conventional Commit aceptado:

```text
feat(scope): description
fix(scope): description
docs(scope): description
test(scope): description
refactor(scope): description
chore(scope): description
build(scope): description
ci(scope): description
perf(scope): description
revert(scope): description
```

Descripción no vacía.

No se interpola en shell.

## 17. File entries

Cada Entry 1.0 contiene:

```text
path
sha256
action
```

Action 1.0 única:

```text
upsert
```

Deletion, rename y copy quedan fuera de alcance 1.0.

Una operación destructiva requiere diseño y confirmación separada.

## 18. Path validation

Cada path debe:

- ser relativo al repository root;
- usar `/`;
- no comenzar con `/`;
- no contener drive letter;
- no contener `.` o `..` como componente;
- no contener NUL;
- no entrar en `.git`;
- no ser duplicado;
- no colisionar por case-folding;
- resolver dentro del repository root;
- apuntar a archivo regular;
- no ser symlink;
- no ser directory.

La herramienta no usa globbing.

## 19. SHA-256

Formato:

```text
64 caracteres hexadecimales lowercase
```

La herramienta calcula SHA-256 de bytes del working file.

Mismatch produce abort antes de staging.

Esto verifica que `repository_files/` fue copiado completamente y sin edición accidental.

## 20. Godot UID policy

Valor 1.0:

```text
required_for_new_gd
```

Reglas:

1. Por cada `.gd` nuevo declarado, `<path>.uid` debe existir.
2. El sidecar debe estar nuevo o modificado.
3. Contenido debe coincidir con:

```text
uid://[a-z0-9]+
```

4. Sidecar válido se añade a la allowlist de staging.
5. Para `.gd` existente modificado, sidecar solo se incluye si cambió.
6. Sidecar inesperado fuera de un `.gd` declarado bloquea submit.
7. Sidecar no aparece en el manifiesto porque Godot lo genera localmente.

## 21. Working tree policy

Al iniciar:

- no puede existir staging previo;
- no puede existir merge;
- no puede existir rebase;
- no puede existir cherry-pick;
- no puede existir revert;
- no puede existir bisect activo.

Los cambios permitidos son exactamente:

```text
manifest files
+
Godot UID sidecars derivados
```

Cualquier cambio adicional aborta.

Ejemplos:

```text
--help
ZIP dentro del repo
README de entrega
vtd no ignorado
archivo local accidental
cambio de código ajeno
```

La herramienta no los elimina.

## 22. Preflight sequence

```text
Load Manifest
↓
Validate Schema
↓
Discover Repository Root
↓
Validate Project Marker
↓
Validate Git Operation State
↓
Validate Branch
↓
Validate HEAD
↓
Validate Remote
↓
Fetch Remote Branch
↓
Require Local/Remote Synchronization
↓
Validate Paths
↓
Validate Hashes
↓
Discover Allowed UID Sidecars
↓
Read Git Status
↓
Reject Pre-staged Changes
↓
Reject Unexpected Changes
↓
Require Every Manifest File Changed
↓
Run git diff --check
```

No staging ocurre antes de completar preflight.

## 23. Validate-only

`-ValidateOnly` ejecuta todo preflight posible.

No ejecuta:

- git add;
- commit;
- push.

Resultado:

```text
VELOCITY SUBMIT VALIDATION: PASS
```

o:

```text
VELOCITY SUBMIT VALIDATION: FAIL
```

## 24. Staging

La herramienta ejecuta staging únicamente sobre paths validados.

Conceptualmente:

```text
git add -- <explicit paths>
```

No utiliza:

```text
git add .
git add -A
git commit -a
```

Después exige que staged paths sean exactamente la allowlist.

## 25. Cached audit

Después de staging:

```text
git diff --cached --name-status
git diff --cached --check
```

Cualquier mismatch o whitespace error aborta.

Si la herramienta todavía no creó commit, revierte únicamente su propio staging:

```text
git restore --staged -- <explicit paths>
```

Working files no se modifican.

## 26. Confirmation

La herramienta muestra:

- delivery ID;
- branch;
- base commit;
- remote;
- commit message;
- verification summary;
- staged name-status;
- cantidad de files;
- UID sidecars derivados.

Después solicita:

```text
Escribe SUBMIT para commit y push:
```

Cualquier otra entrada cancela.

Cancelación:

- no crea commit;
- no ejecuta push;
- retira únicamente staging creado por la herramienta;
- conserva working files.

## 27. Commit

Después de confirmación exacta:

```text
git commit -m <manifest commit_message>
```

No usa shell string interpolation.

Después verifica:

- Git devolvió éxito;
- HEAD cambió;
- subject coincide con manifest;
- working tree no contiene cambios.

Si commit falla:

- no ejecuta push;
- no resetea;
- conserva staging para diagnóstico;
- devuelve error completo.

## 28. Push

Después de commit verificado:

```text
git push <remote> <branch>
```

Prohibido:

- `--force`;
- `--force-with-lease`;
- push de otra ref;
- push silencioso después de commit fallido.

## 29. Push failure

Si push falla:

- commit local se conserva;
- no se ejecuta reset;
- no se crea segundo commit;
- resultado es parcial;
- exit code es no cero;
- se muestran HEAD y status;
- se indica reintentar únicamente `git push` después de analizar causa.

Resultado:

```text
VELOCITY SUBMIT RESULT: LOCAL_COMMIT_ONLY
```

## 30. Success verification

Después de push:

- fetch no es necesario si push actualizó tracking ref;
- HEAD debe coincidir con remote branch;
- working tree debe estar limpio;
- branch debe permanecer correcta.

Salida canónica:

```text
VELOCITY SUBMIT RESULT: PASS
Delivery: <delivery_id>
Commit: <hash> <subject>
Files: <count>
Remote: synchronized
Status: ## main...origin/main
```

Este bloque es suficiente para continuar colaboración.

## 31. Error model

Categorías:

```text
MANIFEST_ERROR
REPOSITORY_ERROR
BASELINE_ERROR
WORKTREE_ERROR
HASH_ERROR
UID_ERROR
STAGING_ERROR
COMMIT_ERROR
PUSH_ERROR
FINAL_STATE_ERROR
CANCELLED
```

Cada error incluye:

- categoría;
- mensaje;
- contexto mínimo;
- siguiente acción segura.

No imprime stack trace por defecto.

Modo test puede conservar excepción original.

## 32. Exit codes

```text
0  PASS o VALIDATION PASS
2  MANIFEST_ERROR
3  REPOSITORY_ERROR
4  BASELINE_ERROR
5  WORKTREE_ERROR
6  HASH_ERROR
7  UID_ERROR
8  STAGING_ERROR
9  COMMIT_ERROR
10 PUSH_ERROR
11 FINAL_STATE_ERROR
12 CANCELLED
```

## 33. Subprocess safety

Python utiliza:

```text
subprocess.run([...], shell=False)
```

Cada argumento Git se entrega por separado.

No utiliza:

- `shell=True`;
- `eval`;
- `exec`;
- `Invoke-Expression`;
- command strings desde JSON.

## 34. Encoding

Manifest:

```text
UTF-8
```

Paths Git se procesan mediante `-z` cuando la salida contiene nombres.

La herramienta debe soportar:

- espacios;
- guion largo;
- nombres Unicode válidos.

## 35. Authentication

La herramienta hereda autenticación Git existente.

No:

- solicita token propio;
- lee credenciales;
- guarda secretos;
- modifica credential helper.

## 36. Network

Operaciones de red permitidas:

```text
git fetch
git push
```

Solo contra remote declarado.

No realiza HTTP directo.

## 37. Test strategy — manifest

Verifica:

- JSON inválido;
- schema desconocido;
- campo faltante;
- delivery ID inválido;
- project inválido;
- branch inválida;
- HEAD inválido;
- commit message inválido;
- files vacío;
- action desconocida;
- SHA inválido;
- path duplicado;
- path case-fold duplicate;
- path traversal;
- `.git` path;
- backslash path;
- absolute path.

## 38. Test strategy — files

Verifica:

- archivo faltante;
- directory;
- symlink;
- hash mismatch;
- archivo unchanged;
- cambio inesperado;
- staging previo;
- whitespace error;
- UTF-8 y path con espacios;
- path con guion largo.

## 39. Test strategy — Godot UID

Verifica:

- `.gd` nuevo con UID válido;
- `.gd` nuevo sin UID;
- UID inválido;
- UID extra inesperado;
- `.gd` existente con UID unchanged;
- `.gd` existente con UID modificado.

## 40. Test strategy — Git integration

Repositorios temporales:

```text
working repository
+
local bare remote
```

Verifica:

- branch incorrecta;
- HEAD mismatch;
- remote ahead;
- successful validation-only;
- cancellation sin commit;
- staging exacto;
- commit exacto;
- push a bare remote;
- sync final;
- push failure conserva commit local.

Las pruebas nunca usan GitHub.

## 41. Test command

```powershell
python -m unittest `
    test/tools/test_velocity_submit.py
```

Resultado esperado se definirá después de implementar la suite.

No se hardcodea conteo antes de crear las pruebas.

## 42. Bootstrap

Velocity Submit Tool no puede automatizar su propia instalación inicial.

El milestone requiere un último submit manual:

```text
tooling implementation
+
tests
+
documentation baseline
```

Después de ese commit, paquetes ordinarios utilizarán manifest.

## 43. Package contract futuro

Cada ZIP generado por el asistente contendrá:

```text
nombre-del-paquete/
├── repository_files/
├── README.txt
├── SHA256SUMS.txt
└── SUBMIT_MANIFEST.json
```

Solo `repository_files/` entra al repositorio.

README, SHA, manifest, carpeta y ZIP permanecen externos.

## 44. Alternatives

### Git alias

Rechazado como solución principal.

No valida hashes, baseline, unexpected files o UID sidecars.

### `git add .`

Rechazado.

Puede incluir artefactos y cambios ajenos.

### Git hooks solamente

Rechazado como solución completa.

No resuelve staging, manifest, commit o push.

Hooks locales tampoco son portables por defecto.

### Git GUI

Rechazado como contrato canónico.

Reduce comandos pero no verifica una entrega reproducible.

### PowerShell monolítico

No seleccionado.

Es viable, pero reduce testabilidad en el entorno actual y requeriría Pester o integración manual extensa.

### Python directo sin launcher

No seleccionado como UX principal.

Permanece disponible para diagnóstico, pero PowerShell conserva la interfaz Windows acordada.

### Submit completamente no interactivo

Rechazado.

Commit y push requieren una confirmación humana explícita.

## 45. Criterios de aceptación

1. Manifest schema exacto.
2. Base commit explícita.
3. Branch explícita.
4. Remote explícito.
5. Commit message explícito.
6. File paths explícitos.
7. SHA-256 por file.
8. No path traversal.
9. No `.git` access.
10. No symlink files.
11. No pre-staged changes.
12. No unexpected changes.
13. Godot UID sidecars controlados.
14. `git diff --check`.
15. Staging explícito.
16. Cached path equality.
17. `git diff --cached --check`.
18. Una confirmación `SUBMIT`.
19. Cancelación limpia.
20. Commit subject exacto.
21. Push sin force.
22. Push failure conserva commit.
23. Working tree limpio en éxito.
24. Local y remote sincronizados.
25. Salida canónica.
26. Sin credenciales propias.
27. Sin shell execution.
28. Pruebas unitarias PASS.
29. Integración con bare remote PASS.
30. Bootstrap manual documentado.

## 46. Fuera de alcance

- ejecutar Godot;
- interpretar Dashboard;
- decidir si pruebas son suficientes;
- generar código;
- generar manifest dentro del repositorio;
- deletion;
- rename;
- copy;
- force push;
- amend;
- squash;
- rebase;
- merge;
- tag;
- release GitHub;
- pull automático;
- resolver conflictos;
- limpiar archivos inesperados;
- modificar `.git/config`;
- almacenar credenciales;
- operación no interactiva de producción;
- UI gráfica.

## 47. Estado

```text
VELOCITY SUBMIT TOOL DESIGN 1.0
ACTIVO
```

Decisión:

```text
APROBADA
```

Implementación:

```text
NO INICIADA
```

Siguiente paso:

```text
Commit documental
↓
Implementar Python engine
↓
Implementar PowerShell launcher
↓
Implementar BAT launcher
↓
Crear unittest e integración temporal
↓
Ejecutar bootstrap submit manual
↓
Usar manifest en entregas futuras
```
