# ADR-001 — DeviceBus

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.0 |
| Fecha | 2026-08-14 |
| Componente | DeviceBus |
| Alcance | Comunicación interna del Core |

## 1. Contexto

Velocity está diseñado como una plataforma modular compuesta por dispositivos y subsistemas independientes.

Entre los consumidores y productores futuros pueden existir:

- DistanceSensor;
- IMUSensor;
- MotorController;
- HUD;
- AIController;
- Replay;
- TelemetryBridge;
- RaspberryPiBridge;
- herramientas de depuración;
- herramientas de edición.

Estos componentes:

- no deben conocerse directamente;
- no deben depender de implementaciones concretas;
- deben poder añadirse o eliminarse sin modificar el resto del sistema;
- deben poder probarse y reemplazarse de forma independiente.

Velocity necesita un mecanismo común para intercambiar información sin crear dependencias directas entre productores y consumidores.

## 2. Problema

Sin un mecanismo de comunicación desacoplado, un productor podría terminar manteniendo referencias directas a todos sus consumidores.

Ejemplo:

```text
Sensor
  │
  ├──► HUD
  ├──► AI
  ├──► Logger
  ├──► Suspension
  └──► Telemetry
```

En este modelo, cada nuevo consumidor obliga a modificar el productor.

El productor también necesita conocer:

- qué consumidores existen;
- cómo encontrarlos;
- cuándo fueron creados;
- qué métodos exponen;
- cómo reaccionar si alguno desaparece.

Esto produce fuerte acoplamiento y viola el principio de inversión de dependencias.

También dificulta:

- sustituir componentes;
- ejecutar pruebas aisladas;
- añadir replay;
- añadir telemetría;
- conectar herramientas;
- utilizar datos simulados;
- integrar hardware futuro.

## 3. Decisión

Velocity utilizará un Message Bus interno llamado:

```text
DeviceBus
```

Los Devices podrán:

```text
publicar
```

o:

```text
suscribirse
```

Los Devices no utilizarán referencias directas entre sí como mecanismo principal para intercambiar mensajes de la plataforma.

La comunicación conceptual será:

```text
Publisher
	│
	▼
DeviceBus
	│
	▼
Consumer
```

## 4. Responsabilidad

DeviceBus tiene una única responsabilidad:

> Gestionar el intercambio desacoplado de mensajes entre productores y consumidores.

DeviceBus recibe una solicitud de publicación y entrega el mensaje a los suscriptores registrados para el canal correspondiente.

DeviceBus no necesita conocer el significado del mensaje.

## 5. Capacidades

DeviceBus debe poder:

- registrar suscriptores;
- eliminar suscriptores;
- publicar mensajes;
- consultar el estado de sus registros;
- limpiar sus registros.

Estas capacidades forman el límite funcional del componente.

Una capacidad adicional deberá demostrar que pertenece a esta misma responsabilidad antes de añadirse.

## 6. API pública conceptual

La API pública aprobada está formada únicamente por:

```text
subscribe()

unsubscribe()

publish()

clear()

has_subscribers()

get_subscriber_count()

get_topics()
```

Este ADR aprueba la existencia y la intención de estas operaciones.

No define todavía:

- sus parámetros;
- sus tipos de retorno;
- su representación interna;
- su comportamiento detallado ante cada error.

Esos elementos deberán establecerse en el diseño del componente antes de su implementación.

## 7. Invariantes

Las siguientes reglas nunca deberán romperse.

### 7.1 DeviceBus no modifica mensajes

Un mensaje entra y sale del Bus sin ser interpretado ni transformado.

```text
Mensaje original
	  │
	  ▼
  DeviceBus
	  │
	  ▼
Mismo mensaje
```

DeviceBus no:

- añade información;
- elimina información;
- cambia unidades;
- realiza conversiones;
- normaliza valores;
- serializa el contenido.

### 7.2 El orden de entrega es determinista

Si los suscriptores fueron registrados en el orden:

```text
A
B
C
```

la entrega debe producirse en un orden definido y reproducible:

```text
A
│
▼
B
│
▼
C
```

La implementación deberá especificar formalmente qué orden utiliza.

### 7.3 El fallo de un suscriptor no detiene el Bus

Ejemplo:

```text
Publisher
	│
	▼
DeviceBus
	│
	├──► HUD
	├──► Logger
	└──► Telemetry
```

Si `Logger` falla:

```text
HUD        ✔
Logger     ✘
Telemetry  ✔
```

DeviceBus debe continuar intentando la entrega a los demás suscriptores.

El mecanismo técnico para cumplir este invariante será definido durante el diseño de implementación.

### 7.4 DeviceBus nunca crea Devices

DeviceBus nunca debe ejecutar una operación equivalente a:

```text
new Sensor()
new HUD()
new TelemetryBridge()
```

La creación y el ciclo de vida de los Devices pertenecen a otro componente o nivel de la aplicación.

### 7.5 DeviceBus no conoce tipos concretos

DeviceBus debe poder transportar conceptos como:

```text
DistanceMeasurement
IMUMeasurement
ImageFrame
MotorCommand
TelemetryPacket
```

sin conocer su contenido ni incluir dependencias hacia esos tipos concretos.

### 7.6 DeviceBus no almacena estado funcional

DeviceBus puede conservar la información mínima necesaria para administrar sus registros.

No debe convertirse en propietario del estado de:

- sensores;
- actuadores;
- vehículo;
- carrera;
- HUD;
- IA;
- telemetría;
- hardware.

## 8. No responsabilidades

DeviceBus no debe:

- almacenar estados funcionales;
- interpretar mensajes;
- transformar mensajes;
- realizar conversiones;
- validar datos de dominio;
- arbitrar comandos;
- calcular física;
- acceder al mundo 3D;
- descubrir Devices;
- crear Devices;
- controlar el ciclo de vida de Devices;
- registrar logs;
- guardar historial;
- persistir información;
- serializar;
- comunicarse por red;
- acceder a hardware;
- filtrar contenido complejo;
- representar conexiones visuales;
- sustituir a DeviceGraph.

Si DeviceBus comienza a realizar alguna de estas funciones, su responsabilidad deberá revisarse antes de continuar.

## 9. Modelo conceptual

```text
Publisher
	│
	▼
DeviceBus
	│
	▼
Topic
	│
	▼
Subscriptions
	│
	▼
Consumer
```

El modelo conceptual no obliga todavía a utilizar clases independientes para `Topic` o `Subscriptions`.

La representación concreta será definida durante el diseño del componente.

## 10. Evolución prevista

### 10.1 Etapa inicial

```text
Publisher
	│
	▼
DeviceBus
	│
	▼
Consumer
```

### 10.2 Administración de suscripciones

```text
Publisher
	│
	▼
DeviceBus
	│
	▼
SubscriptionRegistry
	│
	▼
Subscriptions
	│
	▼
Consumer
```

### 10.3 Topología de dispositivos

```text
Publisher
	│
	▼
DeviceGraph
	│
	▼
Ports
	│
	▼
Connections
	│
	▼
DeviceBus
	│
	▼
Consumer
```

DeviceBus debe permanecer prácticamente igual durante esta evolución.

El crecimiento ocurrirá alrededor del Bus, no dentro de él.

## 11. Alternativas descartadas

### 11.1 Comunicación directa

Descartada como mecanismo principal entre Devices.

Produce acoplamiento entre productores y consumidores.

Cada nuevo consumidor obliga a modificar o configurar directamente al productor.

### 11.2 EventBus global de Godot

Descartado.

Un EventBus global:

- oculta dependencias;
- dificulta aislar pruebas;
- liga el ciclo de vida al árbol de escenas;
- favorece el uso de un singleton como solución universal;
- dificulta ejecutar múltiples contextos independientes.

DeviceBus no será añadido como autoload por conveniencia.

### 11.3 Signals de Godot como columna vertebral

Descartadas como mecanismo principal entre subsistemas.

Las Signals pueden utilizarse localmente dentro de escenas o componentes cuando sean apropiadas.

No serán la columna vertebral de comunicación de Velocity.

Esta separación permitirá que partes del núcleo puedan utilizarse posteriormente en herramientas, simulaciones o procesos externos al árbol de escenas principal.

### 11.4 Integrar logging, serialización o networking

Descartado.

Logging, serialización y networking son responsabilidades diferentes.

Estas capacidades deberán implementarse como consumidores, adaptadores o componentes externos al Bus.

## 12. Consecuencias

### 12.1 Consecuencias positivas

- menor acoplamiento;
- mayor capacidad de sustitución;
- pruebas aisladas;
- consumidores independientes;
- soporte futuro para replay;
- soporte futuro para IA;
- soporte futuro para telemetría;
- soporte futuro para networking;
- soporte futuro para herramientas;
- crecimiento modular;
- integración con hardware sin modificar productores.

### 12.2 Consecuencias negativas

- mayor cantidad de objetos;
- mayor cantidad de mensajes;
- mayor disciplina en la definición de contratos;
- necesidad de identificar claramente los topics;
- mayor dificultad para seguir manualmente el recorrido de un mensaje;
- riesgo de utilizar el Bus en lugares donde una colaboración directa sería más simple.

Estas consecuencias son aceptadas porque mejoran la capacidad de evolución del proyecto.

## 13. Riesgo de uso excesivo

DeviceBus no debe sustituir todas las llamadas entre objetos.

No todas las clases de Velocity son Devices.

Los objetos que pertenecen a una misma responsabilidad pueden colaborar directamente mediante composición.

DeviceBus se utilizará cuando sea necesario desacoplar productores y consumidores o cruzar límites entre subsistemas.

La existencia del Bus no justifica convertir cada cálculo, fuerza física o valor temporal en un mensaje.

## 14. Decisiones no incluidas

Este ADR no decide:

- la clase base de DeviceBus;
- si la publicación será síncrona o diferida;
- los tipos concretos de los parámetros;
- los tipos concretos de retorno;
- la representación de los topics;
- la representación de los suscriptores;
- el contrato de los mensajes;
- el tratamiento de suscripciones duplicadas;
- el comportamiento ante altas o bajas durante una publicación;
- el propietario de DeviceBus;
- el ciclo de vida de DeviceBus;
- el mecanismo técnico de aislamiento de fallos;
- la implementación de SubscriptionRegistry;
- la implementación de DeviceGraph;
- la estrategia de concurrencia.

Estas decisiones pertenecen al diseño de implementación o a ADR futuros.

## 15. Criterios de aceptación

Una implementación satisface ADR-001 si:

1. conserva la responsabilidad única definida;

2. expone únicamente las capacidades aprobadas;

3. no conoce Devices concretos;

4. no interpreta mensajes;

5. no crea Devices;

6. mantiene un orden de entrega determinista;

7. continúa la entrega cuando un suscriptor no puede procesar un mensaje;

8. puede probarse sin cargar el juego completo;

9. no depende de HUD, física, telemetría, red o hardware;

10. puede reemplazarse sin modificar productores y consumidores ajenos a su contrato.

## 16. Regla de evolución

Antes de añadir una capacidad a DeviceBus se preguntará:

> ¿Esta capacidad pertenece al intercambio de mensajes entre productores y consumidores?

Si la respuesta es no, la capacidad deberá implementarse en otro componente.

Si una nueva necesidad cambia la responsabilidad fundamental del Bus, ADR-001 deberá revisarse antes de modificar el código.

DeviceBus debe seguir siendo pequeño, comprensible, comprobable y reemplazable.
