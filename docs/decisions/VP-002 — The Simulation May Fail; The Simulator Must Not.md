# VP-002 — Historical Title Redirect

| Campo | Valor |
|---|---|
| Estado | SUPERSEDED |
| Versión histórica | 1.0 |
| Fecha original | 2026-08-15 |
| Sustituido | 02/10/2026 |

Este path se conserva para compatibilidad con journals y referencias históricas.

La decisión canónica vigente es:

```text
docs/decisions/
VP-002 — The User or Environment May Err; The Simulator Must Remain Safe.md
```

Título anterior:

```text
The Simulation May Fail;
The Simulator Must Not
```

Motivo de la revisión:

La formulación anterior atribuía de forma ambigua el fallo a la simulación.

La revisión distingue:

- error de usuario o entorno;
- operación rechazada o abortada;
- resultado adverso modelado;
- integridad del simulador.

Lema corto vigente:

> El usuario puede fallar. El simulador no.

Git conserva el contenido completo de la versión 1.0.
