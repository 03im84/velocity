# VP-002 — The Simulation May Fail; The Simulator Must Not

| Campo | Valor |
|---|---|
| Estado | APROBADO |
| Versión | 1.0 |
| Fecha | 2026-08-15 |
| Alcance | Todo el proyecto Velocity |
| Tipo | Project Decision |

## 1. Propósito

Esta decisión establece la política transversal de seguridad, experimentación e integridad de Velocity.

Velocity debe permitir que el usuario aprenda mediante:

- experimentación;
- configuraciones imperfectas;
- incompatibilidades simuladas;
- fallos;
- degradación;
- pérdida de control;
- daño dentro de la simulación.

Al mismo tiempo, ninguna configuración o ejecución podrá comprometer:

- el Core;
- el editor;
- el proceso principal;
- los datos persistentes;
- las definiciones canónicas;
- el control del usuario sobre la aplicación;
- el hardware real conectado.

La regla central es:

> La simulación puede fallar. El simulador no.

## 2. Regla fundamental

Velocity permitirá configuraciones experimentales capaces de producir:

- inestabilidad;
- degradación;
- comportamiento incorrecto;
- sobrecarga;
- daño;
- fallo parcial;
- fallo catastrófico;

si esos resultados permanecen dentro del dominio simulado.

Velocity no permitirá que esos experimentos produzcan:

- stack overflow;
- recursión ilimitada;
- agotamiento de memoria sin límites;
- bloqueo permanente del hilo principal;
- corrupción de archivos;
- pérdida del último estado válido;
- ejecución incontrolable;
- comandos peligrosos hacia hardware real;
- pérdida de la capacidad de detener o recuperar el sistema.

## 3. System Integrity

System Integrity protege la plataforma.

Incluye:

```text
Godot Engine

Velocity Core

DeviceBus

DeviceGraph

Composition Runtime

Profile System

Configuration System

Editor

archivos

snapshots

memoria

threads

stack

hardware real
```

System Integrity no puede ignorarse desde una interfaz de usuario.

Una violación de System Integrity siempre será bloqueante.

## 4. Simulated Safety

Simulated Safety describe la condición de los elementos dentro de la simulación.

Incluye:

- nave;
- Sensors;
- Actuators;
- Controllers;
- energía;
- temperatura;
- estructuras;
- motores;
- Thrusters;
- control loops;
- subsistemas;
- misión.

Una violación de Simulated Safety puede formar parte de un experimento válido.

Ejemplos:

```text
La nave no despega.

El controlador entra en saturación.

Un Thruster simulado se sobrecalienta.

El vehículo oscila.

Un Sensor falla.

La nave pierde estabilidad.

La nave colisiona.

El módulo de Hover deja de funcionar.
```

Estos resultados pueden permitirse en Simulation Mode.

## 5. Hardware Safety

Hardware Safety protege componentes físicos reales.

Incluye:

- voltaje;
- corriente;
- potencia;
- temperatura;
- frecuencia;
- polaridad;
- protocolos;
- firmware;
- aislamiento;
- límites mecánicos;
- límites térmicos;
- dispositivos conectados.

Una configuración puede ser:

```text
válida para simulación;

inválida para hardware.
```

Un Hardware Safety Error nunca podrá activarse en Hardware Mode.

## 6. Clasificación de validaciones

### 6.1 Structural Error

Ejemplos:

```text
Duplicate Device ID.

Broken reference.

Unknown schema.

Missing required field.

Invalid Port type.

Unknown Topic contract.

Corrupted canonical definition.

Graph cannot compile.
```

Resultado:

```text
No puede activarse.
```

### 6.2 Platform Safety Error

Ejemplos:

```text
Unbounded recursion.

Zero-delay execution cycle.

Unbounded message generation.

Unbounded memory allocation.

Callback that never yields.

Invalid runtime plan.

Stack overflow risk.

No mechanism to stop execution.
```

Resultado:

```text
No puede ejecutarse.
```

### 6.3 Simulation Hazard

Ejemplos:

```text
Controller insuficiente.

Control gains inestables.

Energía insuficiente.

Redundancia incompleta.

Temperatura simulada elevada.

Thruster fuera de su rango recomendado.

Nave físicamente inestable.
```

Resultado:

```text
Puede ejecutarse en Simulation Mode.

Debe producir warnings.

Puede provocar daño o fallo simulado.
```

### 6.4 Hardware Safety Error

Ejemplos:

```text
Voltaje físico incompatible.

Corriente real sobre límite.

Current limit inseguro.

Firmware incompatible.

Hardware identity no verificada.

Protección térmica ausente.

Comando fuera del rango físico permitido.
```

Resultado:

```text
Puede modelarse en simulación.

No puede activarse en Hardware Mode.
```

## 7. Modos de configuración

### 7.1 Draft

Una configuración Draft puede estar:

- incompleta;
- desconectada;
- en edición;
- sin validar;
- físicamente riesgosa;
- estructuralmente incorrecta.

Un Draft no se ejecuta.

### 7.2 Active Simulation

Una configuración puede convertirse en Active Simulation cuando supera:

- Structural Validation;
- Platform Safety Validation;
- compilación del plan runtime;
- validación de límites del simulador.

Puede contener Simulation Hazards.

### 7.3 Active Hardware

Una configuración puede convertirse en Active Hardware cuando supera:

- Structural Validation;
- Platform Safety Validation;
- Hardware Safety Validation;
- validación de identidad física;
- validación de firmware;
- validación de interlocks;
- compilación del plan runtime.

No puede contener Hardware Safety Errors.

## 8. Experimentación permitida

El usuario podrá ejecutar en Simulation Mode configuraciones que:

- no alcancen el objetivo;
- produzcan rendimiento insuficiente;
- sobrecarguen componentes simulados;
- produzcan control inestable;
- operen sin redundancia;
- utilicen asignaciones ineficientes;
- causen degradación;
- provoquen daño simulado.

La interfaz debe informar claramente:

```text
Esta configuración puede dañar o desestabilizar
el vehículo simulado.

Simulation Mode:
permitido.

Hardware Mode:
prohibido.
```

No existirá una operación genérica:

```text
Ignore all errors.
```

Los riesgos solo podrán aceptarse dentro del contexto autorizado.

## 9. Definiciones canónicas

Las definiciones canónicas incluidas con Velocity serán inmutables.

Ejemplos:

```text
DistanceSensorIdeal

HoverThrusterIdeal

HoverMCUIdeal

FlightControlComputerIdeal
```

Operaciones permitidas:

- consultar;
- utilizar;
- clonar;
- derivar;
- Save As;
- crear nueva versión.

Operaciones no permitidas:

- sobrescribir;
- alterar el ID canónico;
- modificar hard limits;
- eliminar desde la interfaz;
- sustituir contratos internos;
- modificar Ports canónicos.

## 10. Save As y derivación

Modificar una definición canónica creará una nueva definición.

Ejemplo:

```text
Original:

velocity.hover_mcu.ideal
Version:
1.0
Read Only:
true
```

```text
Derived:

user.hover_mcu.custom_01
Based On:
velocity.hover_mcu.ideal@1.0
Version:
1.0
Read Only:
false
```

La definición original permanece intacta.

## 11. Versionado

Una definición utilizada por un SystemProfile estable no deberá sobrescribirse destructivamente.

Una modificación producirá:

- una nueva versión;
- una nueva revisión;
- o una nueva definición derivada.

Esto permitirá:

- rollback;
- reproducción;
- comparación;
- auditoría;
- apertura de proyectos anteriores;
- migración controlada.

## 12. Cambios transaccionales

Las modificaciones se realizarán sobre un Draft.

Flujo:

```text
Edit Draft
	│
	▼
Validate
	│
	├── Structural Error
	│       └── Reject
	│
	├── Platform Safety Error
	│       └── Reject
	│
	├── Simulation Hazard
	│       └── Allow only in Simulation Mode
	│
	└── Valid
			│
			▼
Compile Composition Plan
			│
			▼
Validate Runtime Plan
			│
			▼
Commit Immutable Snapshot
			│
			▼
Activate
```

Una modificación nunca sustituirá parcialmente el runtime activo.

## 13. Last Known Good

Si un Draft no puede validarse o activarse:

- el último snapshot válido continúa activo;
- el runtime no cambia;
- la definición canónica no cambia;
- la configuración inválida permanece como Draft;
- el usuario puede corregirla o descartarla.

Una activación fallida nunca destruye el último estado conocido como válido.

## 14. Snapshots activos

Las configuraciones activas serán snapshots inmutables.

Un runtime no leerá directamente estructuras que el editor esté modificando.

Modelo:

```text
Editable Draft

		│ validate + compile

		▼

Immutable Active Snapshot

		│

		▼

Runtime
```

Esto evita que una edición parcial afecte una ejecución activa.

## 15. Validación debajo de la interfaz

Las reglas de seguridad no existirán únicamente en botones o controles visuales.

Se ejecutarán durante:

- edición;
- conexión;
- guardado;
- carga;
- compilación;
- activación;
- creación del runtime;
- conexión con hardware.

Una interfaz puede ayudar a prevenir errores.

El Core debe impedir que se activen.

## 16. Hard Limits

Los hard limits pertenecen a definiciones confiables como DeviceProfile.

Ejemplos:

- maximum voltage;
- maximum current;
- maximum power;
- maximum temperature;
- maximum frequency;
- supported parallelization;
- protocol compatibility.

DeviceConfiguration podrá seleccionar valores dentro del rango.

No podrá modificar los límites absolutos.

## 17. Effective Limits

El límite efectivo será el más restrictivo.

```text
Effective Limit =
minimum(
	Profile hard limit,
	Configuration limit,
	Runtime safety limit,
	Connected Device limit
)
```

El runtime nunca utilizará el límite más permisivo cuando exista uno más seguro.

## 18. Recursos limitados

Toda ejecución tendrá presupuestos.

Ejemplos:

- publicaciones máximas por tick;
- profundidad máxima de publicación;
- pasos máximos de evaluación;
- memoria máxima por contexto;
- tiempo máximo de callbacks;
- iteraciones máximas de control;
- entidades máximas;
- magnitudes numéricas admitidas.

Al superar un presupuesto:

- la ejecución se pausa o detiene;
- se genera un RuntimeSafetyReport;
- el editor conserva control;
- el último snapshot permanece intacto;
- el proceso principal continúa respondiendo.

## 19. Control loops

Los loops físicos y de control están permitidos.

Ejemplo:

```text
Physics Tick N:

Sensor
	↓
MCU
	↓
Actuator
	↓
Physics

Physics Tick N+1:

Sensor
	↓
...
```

El loop contiene una frontera temporal.

Los ciclos recursivos sin avance temporal no están permitidos.

Ejemplo inválido:

```text
A publica X.

B recibe X y publica Y.

A recibe Y y publica X.

Repetición dentro del mismo call stack.
```

DeviceGraph podrá representar feedback loops.

CompositionCompiler y Runtime Safety deberán impedir recursión síncrona ilimitada.

## 20. Relación con DeviceBus

DeviceBus continuará limitado al intercambio de mensajes.

VP-002 requiere revisar posteriormente:

- publication depth;
- zero-delay cycles;
- dispatch budgets;
- callbacks que no terminan;
- control del contexto de ejecución.

Estas protecciones no se añadirán como un parche inmediato.

Requerirán una decisión y diseño propios.

## 21. Hardware Mode

Cuando exista hardware real, la seguridad utilizará defensa en profundidad.

Capas previstas:

```text
Configuration Validator

DeviceGraph Validator

Composition Compiler

Runtime Safety Layer

Telemetry/Hardware Bridge

MCU Firmware

Drivers

Physical Protection
```

Ninguna capa será la única protección.

## 22. Fail Closed

Datos desconocidos, corruptos o manipulados no se activarán automáticamente.

Se validarán:

- schema version;
- canonical ID;
- content hash;
- required fields;
- compatibility;
- hard limits;
- origin cuando corresponda.

Ante incertidumbre:

```text
Reject

Quarantine

Load as untrusted Draft

Restore known definition
```

Nunca:

```text
Activate silently
```

## 23. Threat Model

Velocity protegerá los flujos soportados frente a:

- errores de usuario;
- desconocimiento;
- configuraciones incompatibles;
- archivos corruptos;
- manipulación de datos;
- fallos parciales;
- operaciones incompletas.

Velocity no puede garantizar seguridad absoluta frente a una persona que:

- modifica el código fuente;
- recompila el proyecto eliminando protecciones;
- obtiene control administrativo total;
- modifica físicamente el hardware;
- retira protecciones eléctricas.

El hardware real requerirá protecciones independientes del software.

## 24. Principios derivados

1. Canonical definitions are immutable.

2. Structural errors never become active.

3. Platform integrity is non-negotiable.

4. Simulation hazards are allowed in Simulation Mode.

5. Hardware hazards are blocked in Hardware Mode.

6. The simulation may fail; the simulator must not.

7. Changes are transactional.

8. Active states are immutable snapshots.

9. Runtime execution has bounded resources.

10. Control loops require temporal boundaries.

11. Unknown data fails closed.

12. Hardware uses defense in depth.

13. The user can always stop and recover the simulation.

14. Experimental failure is a valid learning outcome.

## 25. Consecuencias positivas

- experimentación segura;
- definiciones reproducibles;
- rollback;
- protección del runtime;
- protección de hardware;
- menor corrupción;
- mejor depuración;
- proyectos antiguos reproducibles;
- separación entre simulación y hardware;
- aprendizaje mediante fallo simulado.

## 26. Consecuencias negativas

- más validaciones;
- versionado obligatorio;
- snapshots adicionales;
- compilación antes de activación;
- mayor disciplina;
- necesidad de límites runtime;
- mayor cantidad de estados;
- imposibilidad de ignorar ciertos errores.

Estas consecuencias son aceptadas.

## 27. Criterios de aceptación

Una característica cumple VP-002 cuando:

1. distingue Draft y Active;

2. no sobrescribe definiciones canónicas;

3. valida antes de activar;

4. preserva Last Known Good;

5. diferencia Simulation Mode y Hardware Mode;

6. permite Simulation Hazards controlados;

7. bloquea Platform Safety Errors;

8. bloquea Hardware Safety Errors en hardware;

9. limita recursos runtime;

10. conserva control del proceso principal;

11. puede detenerse y recuperarse;

12. no activa datos desconocidos silenciosamente;

13. utiliza cambios transaccionales;

14. no convierte un fallo simulado en fallo de plataforma.

## 28. Regla de evolución

Toda nueva herramienta, Device, Graph, Profile, Configuration, Bridge o Runtime deberá responder:

```text
¿Qué puede fallar dentro de la simulación?

¿Qué nunca puede comprometer al sistema?

¿Qué límites son hard limits?

¿Qué riesgos son Simulation Hazards?

¿Qué se bloquea en Hardware Mode?

¿Cómo se conserva Last Known Good?

¿Cómo se detiene la ejecución?

¿Cómo se recupera el usuario?
```

Una característica que no pueda responder estas preguntas no está lista para activarse.