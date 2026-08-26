# Velocity — Resume Prompt

| Campo | Valor |
|---|---|
| Estado | ACTIVO |
| Versión | 1.0 |
| Fecha | 25/08/2026 |
| Propósito | Reanudar Velocity en un chat nuevo sin perder arquitectura, metodología ni baselines |

## 1. Instrucciones de uso

Al comenzar un chat nuevo:

1. adjunta:

   ```text
   velocity_handoff.md
   velocity_resume_prompt.md
   ```

2. si es posible, adjunta también:

   - ADR del siguiente milestone;
   - diseño activo;
   - `git status -sb`;
   - enlace del repositorio.

3. copia y pega el bloque de la sección 2;

4. no permitas que el nuevo asistente escriba código antes de resumir el estado;

5. compara su resumen con el handoff antes de continuar.

## 2. Prompt listo para copiar

```text
Estoy continuando el desarrollo de Velocity.

Repositorio:
https://github.com/03im84/velocity

Engine:
Godot Engine 4.7.1 stable

He adjuntado:

- velocity_handoff.md
- velocity_resume_prompt.md

Antes de responder:

1. Lee completamente velocity_handoff.md.

2. No propongas código todavía.

3. No inventes APIs, clases, rutas, versiones o decisiones.

4. Respeta los ADR aceptados, los diseños activos y las pruebas registradas.

5. Considera las pruebas aceptadas como baselines inmutables.

6. Si una nueva arquitectura necesita otras pruebas, crea pruebas sucesoras.

7. Toda modificación debe entregarse como archivo completo consolidado.

8. No uses parches, diffs, inserciones parciales ni instrucciones quirúrgicas.

9. Si una prueba falla, solicita el primer error completo antes de modificar código.

10. La ejecución autoritativa utiliza Godot Console, headless y Velocity Test Runner.

11. No utilices Run Current Scene del editor como evidencia autoritativa.

12. No modifiques código durante problema, análisis, ADR o diseño.

13. Propón alternativas y tradeoffs. No aceptes automáticamente mis ideas ni las tuyas.

14. Mantén una responsabilidad principal por componente.

15. Prefiere composición sobre herencia.

16. No añadas singleton o autoload por comodidad.

17. Aplica siempre:

	La simulación puede fallar.
	El simulador no.

18. El usuario lee y reescribe manualmente cada archivo.

19. Indica siempre la ruta exacta de cualquier archivo.

20. Trabaja en español, de forma clara, didáctica, directa y honesta.

En tu primera respuesta debes entregar únicamente:

A. resumen de la visión del proyecto;

B. último milestone completado;

C. baseline global vigente;

D. estado de Git conocido;

E. siguiente milestone;

F. decisiones arquitectónicas ya aceptadas para ese milestone;

G. documentos y archivos que necesitas revisar;

H. riesgos o contradicciones que detectes.

No escribas implementación en la primera respuesta.

Si no puedes acceder al repositorio o a un archivo mencionado:

- indícalo explícitamente;
- solicita el archivo exacto;
- no reconstruyas su contenido por intuición.

Si existe conflicto entre fuentes, utiliza esta prioridad:

1. código versionado;

2. pruebas aceptadas;

3. ADR aceptados;

4. diseño activo;

5. Core Architecture;

6. Engineering Standards;

7. velocity_handoff.md;

8. journals históricos;

9. conversación previa.

Después de resumir, espera mi confirmación antes de avanzar.
```

## 3. Respuesta esperada del chat nuevo

Una respuesta correcta debe parecerse a:

```text
He leído el handoff.

Visión:
Velocity es una plataforma y juego modular
de carreras antigravitatorias.

Último milestone:
DeviceGraphAssembler 1.0.

Baseline:
48 tests.
1396 checks.
0 failures.

Git:
main sincronizada con origin/main
según el último estado registrado.

Siguiente milestone:
Runtime Construction Contract.

Decisiones aceptadas:
- factory construct-only;
- RuntimeDeviceHandle;
- construcción atómica;
- rollback inverso;
- dependencias pre-resueltas;
- BORROWED y TRANSFERRED;
- RuntimeHost;
- Factory Key exacta;
- CompositionPlan conserva key.

Antes de escribir código necesito:
- ADR-009;
- System Composition Pipeline Design;
- Engineering Standards;
- archivos actuales relacionados.

No implementaré hasta confirmar ADR-010
y Runtime Construction Contract Design.
```

La redacción exacta puede variar.

El contenido arquitectónico no.

## 4. Señales de que el contexto no fue comprendido

Detener el trabajo si el nuevo asistente:

- propone DeviceBus como autoload;
- propone un singleton global;
- mezcla DeviceCatalog con factories;
- hace que DeviceGraph transporte mensajes;
- utiliza SystemProfile como Resource mutable directo;
- propone `get_latest()` en DeviceCatalog;
- ignora Profile Version;
- propone `Callable` genérico sin contrato;
- adjunta Nodes al SceneTree desde una factory;
- devuelve Object genérico desde factory;
- hace que CompositionCompiler ejecute runtime;
- modifica una prueba aceptada para otra arquitectura;
- entrega parches parciales;
- empieza a escribir código sin ADR o diseño;
- usa Run Current Scene como prueba autoritativa;
- ignora el primer error;
- contradice VP-002.

Si aparece una de estas señales:

1. detener implementación;

2. volver a adjuntar el handoff;

3. pedir que repita el estado;

4. exigir reconciliación con ADR y tests.

## 5. Preguntas de control

Antes de continuar, el nuevo asistente debe poder responder:

### Arquitectura

```text
¿Quién transporta mensajes?

DeviceBus.
```

```text
¿Quién representa topología?

DeviceGraph.
```

```text
¿Quién representa composición?

SystemProfile.
```

```text
¿Quién resuelve DeviceProfiles?

DeviceProfileResolver,
implementado por DeviceCatalog.
```

```text
¿Quién convierte SystemProfile a Graph?

DeviceGraphAssembler.
```

```text
¿Quién creará Devices runtime?

CompositionRuntime mediante factories,
no CompositionCompiler.
```