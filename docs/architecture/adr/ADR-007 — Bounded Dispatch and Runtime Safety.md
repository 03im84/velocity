# ADR-007 — Bounded Dispatch and Runtime Safety

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.0 |
| Fecha | 16/08/2026 |
| Componentes | DeviceBus, Composition Runtime, Runtime Safety |
| Alcance | Dispatch limitado, ownership de datos y protección del runtime |

## 1. Contexto

ADR-001 define DeviceBus como el mecanismo interno de intercambio desacoplado de mensajes.

DeviceBus 1.0 utiliza publicación:

- síncrona;
- inmediata;
- reentrante;
- depth-first;
- sin límites de profundidad;
- sin presupuesto de mensajes;
- sin presupuesto de callbacks.

VP-002 establece:

> La simulación puede fallar. El simulador no.

La auditoría EN006 determinó que la publicación reentrante sin límites puede producir:

- stack overflow;
- zero-delay cycles;
- message storms;
- congelamiento;
- pérdida del control del proceso principal.

Velocity necesita conservar comunicación desacoplada y feedback loops sin permitir ejecución ilimitada.

## 2. Problema

El siguiente ciclo puede crecer dentro del mismo call stack:

```text
Device A recibe topic_x.

Device A publica topic_y.

Device B recibe topic_y.

Device B publica topic_x.

Device A vuelve a recibir topic_x.

...
```

La implementación actual no limita:

- profundidad;
- publicaciones;
- callbacks;
- queue;
- duración;
- fan-out.

Un Graph o Configuration creado mediante herramientas soportadas no debe poder comprometer la plataforma.

## 3. Decisión general

DeviceBus evolucionará desde dispatch recursivo depth-first hacia:

```text
bounded iterative FIFO dispatch
```

Las publicaciones reentrantes no iniciarán una nueva cadena recursiva.

Serán añadidas a una queue temporal perteneciente al Dispatch Cycle actual.

DeviceBus procesará esa queue iterativamente.

## 4. Dispatch Cycle

Un Dispatch Cycle comienza cuando `publish()` es llamado y DeviceBus no se encuentra despachando.

La primera publicación será la publicación raíz.

El ciclo incluye:

- la publicación raíz;
- publicaciones generadas por sus callbacks;
- publicaciones generadas por esas publicaciones;
- todos los callbacks ejecutados;
- la queue temporal.

El ciclo termina cuando:

```text
la queue queda vacía;
```

o:

```text
se alcanza un límite de seguridad.
```

Una publicación posterior crea un Dispatch Cycle nuevo.

## 5. Queue FIFO

La queue conservará el orden de aceptación de publicaciones.

Ejemplo:

```text
Queue:

Message A

Message B

Message C
```

Orden:

```text
A

B

C
```

Cada mensaje conservará el orden de suscriptores establecido por DeviceBus.

La queue es estado temporal de infraestructura.

No representa estado funcional de Devices.

## 6. Publicación reentrante

Cuando un callback ejecuta `publish()` durante un Dispatch Cycle:

1. DeviceBus valida los límites del ciclo;

2. añade la publicación a la queue;

3. no inicia una llamada recursiva de dispatch;

4. devuelve control al callback;

5. el ciclo actual procesa el mensaje posteriormente.

Ejemplo anterior:

```text
A:outer

A publica inner

B:outer

A:inner

B:inner
```

Orden FIFO esperado:

```text
A:outer

B:outer

A:inner

B:inner
```

El call stack no crece por publicaciones reentrantes.

## 7. Presupuestos obligatorios

Cada Dispatch Cycle tendrá presupuestos.

### 7.1 Publication Budget

Cantidad máxima de publicaciones aceptadas durante un ciclo.

Protege frente a crecimiento ilimitado de mensajes.

### 7.2 Callback Budget

Cantidad máxima de callbacks invocados durante un ciclo.

Protege frente a fan-out excesivo.

### 7.3 Queue Size Limit

Cantidad máxima de publicaciones pendientes.

Protege frente a crecimiento de memoria.

### 7.4 Dispatch Time Budget

Tiempo máximo permitido o recomendado para el ciclo.

Puede detener trabajo posterior cuando un callback devuelve control.

No puede interrumpir de forma segura un callback que nunca termina dentro del mismo hilo.

### 7.5 Hard Maximum

Los presupuestos configurables tendrán un hard maximum que no podrá desactivarse.

```text
Configured Budget
<=
Hard Maximum
```

Simulation Mode podrá utilizar valores diferentes dentro de límites permitidos.

No podrá utilizar un presupuesto ilimitado.

## 8. Presupuesto excedido

Cuando DeviceBus alcanza un límite:

1. marca el Dispatch Cycle como abortado;

2. deja de aceptar publicaciones dentro del ciclo;

3. detiene la entrega restante de forma controlada;

4. elimina la queue pendiente del ciclo;

5. conserva las suscripciones permanentes;

6. conserva DeviceBus utilizable para un ciclo posterior;

7. produce un resultado observable;

8. devuelve control al proceso principal.

DeviceBus no decide:

- pausar la nave;
- cambiar Health;
- detener una carrera;
- restaurar un Profile;
- apagar hardware.

Estas decisiones pertenecen a Runtime Safety y Composition Runtime.

## 9. Observabilidad

Alcanzar un límite no puede ser silencioso.

DeviceBus proporcionará un resultado o reporte de infraestructura.

El diseño concreto podrá utilizar conceptos como:

```text
DeviceBusDispatchResult

DeviceBusDispatchReport

RuntimeSafetyObserver
```

El reporte deberá poder expresar:

- estado final;
- publicaciones aceptadas;
- publicaciones entregadas;
- callbacks invocados;
- publicaciones descartadas;
- límite alcanzado;
- topic relacionado;
- duración observada;
- si el ciclo fue abortado.

DeviceBus no interpretará payloads.

DeviceBus no se convertirá en Logger.

## 10. Evolución de `publish()`

La firma actual es:

```gdscript
publish(
	topic: StringName,
	message: Variant
) -> void
```

La implementación podrá evolucionar hacia un resultado de infraestructura.

Forma conceptual:

```gdscript
publish(
	topic: StringName,
	message: Variant
) -> DeviceBusDispatchResult
```

La firma exacta será definida en el diseño del componente.

Los productores podrán ignorar el resultado cuando no necesiten inspección.

Composition Runtime y Runtime Safety podrán utilizarlo.

El resultado no expondrá consumidores concretos.

## 11. Single Semantic Owner

Cada dato tendrá un propietario semántico.

Ejemplo:

```text
Topic:
distance_measurement

Source ID:
front_left_distance_sensor
```

El propietario autorizado es:

```text
FrontLeftDistanceSensorDevice
```

No existirán dos productores autorizados para la misma combinación:

```text
Topic + Source ID
```

Múltiples Sources pueden publicar el mismo Topic.

Ejemplo:

```text
distance_measurement
+
front_left_distance_sensor

distance_measurement
+
front_right_distance_sensor
```

Representan streams diferentes.

## 12. Single Publication

El propietario publica un dato una sola vez.

DeviceBus realiza fan-out hacia todos los consumidores.

Ejemplo:

```text
DistanceSensorDevice
		│
		│ una publicación
		▼
	DeviceBus
		│
		├──► HoverMCU
		├──► Debug
		├──► Telemetry
		├──► Replay
		└──► CockpitBridge
```

DeviceBus entrega la misma referencia inmutable.

No crea una publicación independiente por consumidor.

## 13. No republishing sin transformación

Un consumidor no republicará un mensaje sin cambios.

Incorrecto:

```text
DistanceSensor
	↓ DistanceMeasurement
HoverMCU
	↓ misma DistanceMeasurement
FCC
```

Correcto:

```text
DistanceSensor
	↓ DistanceMeasurement
HoverMCU
	↓ HoverControlResult
FCC
	↓ FlightControlState
```

Cada publicación derivada debe representar información semánticamente nueva.

## 14. Derived Output

Un Device puede publicar cuando produce un contrato nuevo.

Ejemplos:

```text
Sensor:
DistanceMeasurement

MCU:
HoverControlResult

FCC:
FlightControlState

Fault Management:
AggregatedFaultReport
```

Cada contrato tiene su propio propietario.

Los resultados derivados no se presentan como Measurements originales.

## 15. Provenance

Un resultado derivado conservará información suficiente para identificar sus entradas cuando sea necesario.

Ejemplos conceptuales:

- Source IDs;
- Message IDs;
- Measurement IDs;
- Frame ID;
- sequence;
- input timestamp;
- lista de Sources utilizadas;
- inputs faltantes;
- modo estimado o degradado.

Provenance no implica conservar una referencia al Device productor.

Podrá utilizar:

```text
referencia a snapshot inmutable
```

o:

```text
identidad serializable
```

según el contexto.

El contrato concreto pertenece al futuro diseño de Measurement, Snapshot y Data Flow.

## 16. Shared Reference

Dentro de un mismo proceso, múltiples consumidores pueden recibir la misma referencia inmutable.

DeviceBus no copiará automáticamente:

- BusMessage;
- payload;
- Measurement;
- State Snapshot.

Los consumidores tratarán los datos como solo lectura.

La política de lifetime y retención se definirá para snapshots futuros.

## 17. Coalescing

DeviceBus no implementará coalescing en esta versión.

No utilizará:

```text
LATEST_ONLY

LATEST_PER_SOURCE

generic equality

timestamp replacement
```

DeviceBus no:

- compara payloads;
- elimina publicaciones repetidas;
- modifica timestamps;
- sustituye pending messages por igualdad semántica.

Política:

```text
DELIVER_ALL
```

La reducción de tráfico se logra mediante:

- ownership correcto;
- publicación única;
- fan-out;
- contratos derivados;
- provenance;
- presupuestos runtime.

## 18. Message Storms

Single Publication reduce tráfico redundante, pero no elimina todos los message storms.

Un Device defectuoso todavía podría:

- publicar sin límite;
- producir fan-out;
- crear un zero-delay cycle;
- generar topics diferentes;
- producir mensajes grandes.

Por tanto, los budgets continúan siendo obligatorios.

## 19. Control loops

Los loops físicos y de control están permitidos.

Ejemplo válido:

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

Existe una frontera temporal.

Un zero-delay cycle no debe ejecutarse sin límites.

Ejemplo:

```text
A publica X.

B recibe X y publica Y.

A recibe Y y publica X.
```

La queue evita stack overflow.

Los budgets detienen la repetición.

DeviceGraph y CompositionCompiler deberán añadir validación preventiva.

## 20. Temporal Boundaries

Las fronteras temporales iniciales podrán incluir:

- Physics Frame;
- Process Frame;
- Timer;
- Scheduler Tick;
- hardware sample;
- input externo.

DeviceGraph podrá representar feedback loops.

CompositionCompiler deberá distinguir loops temporales de zero-delay cycles.

DeviceBus no interpretará DeviceGraph.

## 21. Callbacks no terminantes

Una queue no puede interrumpir un callback que nunca devuelve control en el mismo hilo.

La protección inicial se basará en:

- Devices canónicos confiables;
- pruebas;
- revisión;
- prohibición de código arbitrario desde GraphEditor;
- medición de tiempo después del callback;
- watchdog futuro;
- aislamiento por proceso futuro para código no confiable.

ADR-007 no promete aislamiento imposible dentro del mismo hilo.

## 22. Relación con DeviceGraph

DeviceGraph representará:

- Source Device;
- OutputPort;
- TopicChannel;
- Target Device;
- InputPort.

Toda comunicación runtime utilizará DeviceBus.

DeviceGraph no transportará mensajes.

DeviceGraph podrá detectar:

- ownership duplicado;
- zero-delay cycles;
- Connections inválidas;
- falta de temporal boundaries;
- topologías con riesgo de message storm.

La implementación de estas validaciones pertenece a ADR-002 y su diseño.

## 23. Relación con Composition Runtime

Composition Runtime:

- configura budgets;
- inicia Dispatch Cycles mediante Devices;
- observa resultados;
- recibe Safety Reports;
- pausa o detiene contextos;
- preserva Last Known Good;
- coordina shutdown.

DeviceBus aplica límites.

Composition Runtime decide la respuesta del sistema.

## 24. Simulation Mode

Simulation Mode permite:

- control inestable;
- fallos simulados;
- message rates elevadas dentro de límites;
- degradación;
- daño simulado.

No permite:

- queue ilimitada;
- dispatch ilimitado;
- recursión ilimitada;
- pérdida del proceso principal.

## 25. Hardware Mode

Hardware Mode utilizará presupuestos iguales o más restrictivos.

Además:

- Hardware Bridge aplicará rate limits;
- comandos tendrán rangos;
- mensajes vencidos podrán descartarse;
- firmware tendrá watchdog;
- hardware tendrá protecciones independientes.

DeviceBus no será la única protección.

## 26. Alternativas descartadas

### 26.1 Recursión depth-first sin límites

Descartada porque puede provocar stack overflow.

### 26.2 Solo límite de profundidad

Descartado como única protección porque no limita fan-out ni message storms.

### 26.3 Solo validación de DeviceGraph

Descartada como única protección porque no cubre defectos runtime.

### 26.4 Coalescing genérico

Descartado porque DeviceBus no conoce igualdad semántica y los mensajes repetidos pueden ser significativos.

### 26.5 Process Isolation inmediata

Pospuesta por complejidad.

Podrá utilizarse para código no confiable en el futuro.

## 27. Baselines afectados

DeviceBusPublishTest protege actualmente reentrada depth-first.

Ese comportamiento será sustituido por FIFO.

La prueba anterior será declarada SUPERADA.

Se crearán pruebas nuevas para:

- FIFO reentrante;
- stack constante;
- Publication Budget;
- Callback Budget;
- Queue Size Limit;
- aborto controlado;
- Dispatch Report;
- suscripciones durante dispatch;
- unsubscribe durante dispatch;
- clear durante dispatch;
- zero-delay cycle limitado;
- recuperación en ciclo posterior;
- Single Publication;
- fan-out;
- ausencia de coalescing.

Las pruebas anteriores no serán modificadas para aparentar equivalencia.

## 28. Consecuencias positivas

- stack bounded;
- dispatch determinista;
- message storms limitables;
- observabilidad;
- protección del proceso;
- soporte para Graph;
- control loops seguros;
- menor tráfico redundante;
- ownership claro;
- provenance;
- base para Runtime Safety.

## 29. Consecuencias negativas

- cambia el orden reentrante;
- requiere queue temporal;
- requiere budgets;
- requiere reportes;
- añade estado de infraestructura;
- sustituye pruebas anteriores;
- aumenta disciplina de contratos;
- no puede interrumpir callbacks infinitos en el mismo hilo.

Estas consecuencias son aceptadas.

## 30. Invariantes

1. Reentrant publish no aumenta el call stack.

2. Dispatch utiliza queue FIFO.

3. Cada Dispatch Cycle tiene budgets.

4. Los budgets tienen hard maximum.

5. Los hard maximum no pueden desactivarse.

6. Exceder un límite aborta de forma controlada.

7. Las suscripciones permanentes permanecen intactas.

8. El ciclo abortado produce un resultado observable.

9. DeviceBus no interpreta payloads.

10. DeviceBus no conoce Devices.

11. DeviceGraph no transporta mensajes.

12. Control loops requieren temporal boundaries.

13. Zero-delay cycles tienen defensa en profundidad.

14. DELIVER_ALL es la política de entrega.

15. DeviceBus no implementa coalescing genérico.

16. Cada stream tiene un propietario semántico.

17. Los consumidores no republican datos sin cambios.

18. DeviceBus realiza fan-out.

19. Los resultados derivados utilizan contratos nuevos.

20. Provenance identifica las entradas utilizadas.

21. Las referencias apuntan a datos, no a Devices.

22. Simulation Mode continúa limitado.

23. Hardware Mode utiliza límites adicionales.

## 31. Criterios de aceptación

La implementación satisface ADR-007 cuando:

1. utiliza una queue FIFO;

2. la reentrada no crea recursión de dispatch;

3. existen hard budgets;

4. los budgets son verificables;

5. un límite aborta el ciclo sin cerrar el proceso;

6. las suscripciones permanecen utilizables;

7. un ciclo posterior puede ejecutarse;

8. existe un resultado observable;

9. DeviceBus continúa agnóstico;

10. el orden FIFO está probado;

11. un zero-delay cycle se detiene;

12. fan-out utiliza una sola publicación;

13. no existe coalescing genérico;

14. los baselines sucesores terminan correctamente;

15. la regresión completa termina correctamente.

## 32. Fuera de alcance

ADR-007 no implementará:

- DeviceGraph;
- CompositionCompiler;
- RuntimeSafety completo;
- Measurement Identity;
- Snapshot Repository;
- Provenance serialization;
- Process Isolation;
- Hardware Bridge;
- watchdog físico;
- Profile System.

Estos componentes utilizarán los contratos definidos por esta decisión.

## 33. Regla de evolución

Una nueva optimización de dispatch deberá demostrar:

- que no interpreta payloads;
- que conserva ownership;
- que no oculta errores;
- que no elimina datos semánticamente relevantes;
- que mantiene presupuestos;
- que no compromete System Integrity.

DeviceBus debe seguir siendo infraestructura de intercambio, no un sistema de dominio.
