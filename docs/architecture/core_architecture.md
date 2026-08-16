# Velocity — Arquitectura del Núcleo

| Campo | Valor |
|  ---  |  ---  |
| Estado | ACTIVO |
| Versión | 1.6 |
| Fecha inicial   | 2026-08-14 |
| Última revisión | 2026-08-15 |
| Alcance | Núcleo lógico de Velocity |

## 1. Propósito

Este documento describe cómo encajan los componentes principales del núcleo de Velocity y establece los límites que deben respetar sus implementaciones.

Los Architecture Decision Records, o ADR, explican por qué se tomó una decisión arquitectónica. Este documento explica cómo se relacionan entre sí las decisiones aceptadas y los componentes resultantes.

La Arquitectura del Núcleo es un documento vivo. Debe reflejar la arquitectura vigente del proyecto, no el historial de cómo fue construida.

Su propósito es permitir que cualquier componente del núcleo pueda ser:

- comprendido de forma independiente;
- probado de forma aislada;
- sustituido sin modificar consumidores ajenos;
- reutilizado por diferentes sistemas;
- extendido sin romper responsabilidades existentes.

Este documento no contiene código de implementación, resultados de experimentos, registros cronológicos ni soluciones temporales.

## 2. Definición del Core

El Core es el conjunto de contratos, mecanismos y reglas compartidas que permiten que los subsistemas de Velocity colaboren sin depender de implementaciones concretas.

El Core proporciona infraestructura común. No implementa comportamiento específico del vehículo, presentación visual ni integración con hardware.

Dentro del Core pueden existir conceptos como:

- Bus;
- Device;
- Provider;
- Measurement;
- Graph;
- contratos de estado;
- mecanismos de tiempo y comunicación.

La existencia de un concepto dentro del Core no significa que todos sus componentes deban conocerse entre sí.

Cada componente conserva una responsabilidad independiente.

Por ejemplo, DeviceBus pertenece al Core, pero no conoce Devices concretos, Providers, sensores, física ni telemetría.

## 3. Límites del Core

El Core no debe:

- leer directamente el input del jugador;
- ejecutar raycasts;
- aplicar fuerzas sobre la nave;
- acceder al árbol de escenas para descubrir dependencias;
- dibujar interfaces;
- controlar cámaras;
- reproducir efectos visuales;
- serializar telemetría;
- abrir conexiones de red;
- acceder a GPIO, I2C, SPI o puertos seriales;
- conocer dispositivos concretos;
- depender de una cabina física;
- depender de una representación visual.

Los sistemas externos pueden depender de contratos definidos por el Core.

El Core nunca debe depender de esos sistemas externos.

La dirección general de dependencia será:

```text
Presentación
Integraciones
Hardware
Telemetría
Herramientas
	  │
	  ▼
	 Core
```

El Core permanece en la parte interna de la arquitectura.

## 4. Relación con el juego

Velocity utiliza Godot Engine como host de ejecución, pero la arquitectura del núcleo no debe estar definida por escenas, interfaces visuales o herramientas del editor.

Los componentes específicos del juego permanecen separados:

Los componentes actuales del núcleo se organizan mediante:

```text
core/bus/
	Infraestructura de intercambio de mensajes.

core/device/
	Modelo común de Devices y sus especializaciones.

core/debug/
	Observación y herramientas de diagnóstico del Core.

profiles/
	Recursos de configuración y perfiles.

test/core/
	Pruebas nuevas e independientes de componentes del Core.
```

Los sistemas físicos pueden usar infraestructura del Core cuando necesiten intercambiar información con otros subsistemas.

El Core no debe absorber la lógica interna del vehículo únicamente para centralizarla.

Hover, sustentación, dirección, propulsión y frenado continúan perteneciendo a sus módulos específicos.

## 5. Mapa de componentes del Core

La arquitectura del núcleo utiliza un conjunto de roles claramente diferenciados.

No todos los roles tienen todavía una implementación definitiva.

| Componente o concepto | Responsabilidad | Estado arquitectónico |
|---|---|---|
| DeviceBus | Intercambiar mensajes entre productores y consumidores | ADR-001 y ADR-004 aceptados; diseño 1.1 activo; implementación aislada verificada; migración de consumidores pendiente |
| BusTopics | Proporcionar identidades canónicas para los topics internos | ADR-005 aceptado; implementación verificada |
| BusMessage | Representar un envelope de mensaje construido completamente y tratado como solo lectura | ADR-005 aceptado; diseño 1.0 activo; implementación pendiente |
| Device | Representar una unidad funcional capaz de interactuar con DeviceBus | Concepto definido; contrato pendiente |
| Provider | Producir datos desde una fuente concreta mediante un contrato de comportamiento | ADR-003 aceptado; diseño 1.0 activo; implementación pendiente |
| Measurement | Representar un dato producido por un sensor | Concepto definido; contrato pendiente |
| SubscriptionRegistry | Gestionar suscripciones fuera de DeviceBus cuando la complejidad lo requiera | Evolución prevista |
| DeviceGraph | Representar conexiones lógicas entre dispositivos | Evolución prevista; ADR pendiente |
| Ports | Definir puntos de conexión de un Device | Evolución prevista |
| Connections | Representar enlaces válidos entre Ports | Evolución prevista |

El estado “evolución prevista” no autoriza su implementación.

Un componente futuro solo se implementará cuando exista una necesidad verificable y se haya definido su responsabilidad.

## 6. Responsabilidades de los componentes

### 6.1 DeviceBus

DeviceBus gestiona el intercambio desacoplado de mensajes entre productores y consumidores.

DeviceBus puede:

- registrar suscriptores;
- eliminar suscriptores;
- publicar mensajes;
- consultar el estado de sus registros;
- limpiar sus registros.

DeviceBus no puede:

- crear Devices;
- descubrir Devices;
- almacenar estado funcional;
- interpretar mensajes;
- transformar mensajes;
- realizar cálculos físicos;
- conocer Providers;
- conocer sensores concretos;
- registrar logs;
- serializar datos;
- comunicarse por red;
- acceder a hardware.

DeviceBus transporta información sin conocer su significado.

### 6.2 Device

Un Device es una unidad funcional capaz de interactuar con DeviceBus.

Un Device puede actuar como:

- productor;
- consumidor;
- productor y consumidor.

Los Devices no se comunican directamente entre sí.

Un Device publica información o se suscribe a información mediante DeviceBus.

No todas las clases de Velocity son Devices.

Los componentes internos de una misma responsabilidad pueden colaborar mediante composición sin convertirse automáticamente en participantes del Bus.

### 6.3 Provider

Un Provider tiene una única responsabilidad:

> Producir datos desde una fuente concreta.

La fuente puede ser:

- el mundo físico de Godot;
- una simulación;
- una grabación;
- una prueba;
- una conexión externa;
- hardware futuro.

Un Provider no decide quién consume sus datos.

Un Provider no modifica el HUD, no controla la nave y no distribuye información a múltiples consumidores.

La relación concreta entre Provider y Device será definida en ADR-003.

### 6.4 Measurement

Una Measurement representa un dato producido por un Sensor.

Ejemplos conceptuales:

- distancia;
- orientación;
- velocidad;
- temperatura;
- energía;
- fuerza aplicada.

DeviceBus no conoce el tipo concreto ni el contenido de una Measurement.

La estructura, identidad, marca temporal y reglas de las Measurements deberán definirse antes de crear contratos definitivos.

### 6.5 DeviceGraph

DeviceGraph representará la topología lógica de Devices, Ports y Connections.

Su responsabilidad prevista es describir y validar conexiones.

DeviceGraph no debe:

- sustituir a DeviceBus;
- transportar mensajes;
- ejecutar comportamiento de Devices;
- acceder directamente al mundo físico;
- convertirse en propietario de toda la aplicación.

DeviceGraph no será implementado hasta que ADR-002 sea redactado y aceptado.

## 7. Reglas de dependencia

Las siguientes reglas se aplican a todos los componentes del núcleo:

1. DeviceBus no depende de Devices concretos.

2. Un productor no conoce a sus consumidores.

3. Un consumidor no necesita conocer la implementación del productor.

4. Un Provider no conoce los destinos finales de sus datos.

5. La presentación depende de datos estructurados; los datos no dependen de la presentación.

6. La telemetría depende del estado del juego; el juego no depende de la telemetría.

7. El hardware depende de datos enviados por la plataforma; el Core no depende del hardware.

8. Ningún componente crea otro componente si esa creación no forma parte de su responsabilidad.

9. Las dependencias deben entregarse explícitamente siempre que sea posible.

10. Añadir un consumidor no debe obligar a modificar el productor.

La dirección general de dependencia será hacia los contratos internos.

```text
Presentación
Integraciones
Hardware
Devices concretos
	  │
	  ▼
Contratos del Core
	  ▲
	  │
Componentes del Core
```

Los contratos internos forman la frontera compartida.

Las implementaciones concretas pueden depender de esos contratos. Los contratos no dependen de las implementaciones concretas.

## 8. Flujo conceptual de información

El flujo interno básico será:

```text
Fuente de datos
	  │
	  ▼
   Provider
	  │
	  ▼
Publisher Device
	  │
	  ▼
  DeviceBus
	  │
	  ▼
Consumer Device
	  │
	  ▼
Sistema consumidor
```

Cada bloque responde a una pregunta diferente:

```text
Provider
¿Qué dato puedo producir?

Publisher Device
¿Cuándo y bajo qué identidad publico ese dato?

DeviceBus
¿A qué suscriptores debo entregar el mensaje?

Consumer Device
¿Qué debo hacer cuando recibo el mensaje?

Sistema consumidor
¿Cómo utiliza el dominio esa información?
```

DeviceBus no responde ninguna de las otras preguntas.

## 9. Flujo futuro de telemetría

La integración futura de telemetría seguirá la misma dirección de dependencias.

```text
Estado del juego
	  │
	  ▼
Telemetry Bridge
	  │
	  ▼
Serialización
	  │
	  ▼
Transporte UDP
	  │
	  ▼
Raspberry Pi Zero 2 W
	  │
	  ▼
Módulos especializados
```

El estado del juego no conocerá:

- la dirección IP de la Raspberry Pi;
- el formato físico de una cabina;
- el tipo de indicador conectado;
- si el consumidor es analógico o digital;
- si la representación es retro, futurista o steampunk.

La Raspberry Pi actuará como Sim-Brain.

Será responsable de recibir los datos, procesarlos y distribuir a cada módulo únicamente la información directamente útil para su función.

Los módulos especializados no recibirán datos crudos que deban interpretar.

La apariencia de una cabina será independiente del significado y del formato interno de los datos.

## 10. Integración con Godot

Godot Engine 4.7.1 es el host de ejecución actual de Velocity.

El uso de Godot no debe convertir el árbol de escenas en la arquitectura del núcleo.

Las escenas y los Nodes pueden:

- representar objetos físicos;
- participar en el ciclo de vida de Godot;
- acceder al mundo 3D;
- recibir input;
- mostrar información;
- reproducir audio y efectos;
- adaptar datos del Core al engine.

Los componentes del Core no deben depender innecesariamente de:

- rutas concretas del árbol de escenas;
- búsquedas globales de Nodes;
- escenas específicas;
- componentes visuales;
- el editor de Godot;
- Signals como mecanismo principal entre subsistemas.

Las Signals pueden utilizarse dentro de una escena o componente cuando sean la herramienta adecuada.

No serán la columna vertebral de comunicación de la plataforma.

DeviceBus no será un EventBus global de Godot ni se añadirá como autoload por conveniencia.

Su propietario, creación y ciclo de vida deberán definirse explícitamente durante el diseño de su implementación.

### 10.1 Propiedad de DeviceBus

Cada contexto de ejecución tendrá una Composition Root explícita.

La Composition Root:

- crea DeviceBus;
- conserva la referencia principal;
- entrega la misma instancia a los participantes;
- coordina la inicialización;
- coordina el cierre;
- limpia el Bus al finalizar;
- libera su referencia.

DeviceBus no será:

- un Node hijo;
- un autoload;
- un singleton global;
- una dependencia descubierta mediante rutas.

Los participantes recibirán el Bus explícitamente.

Cada prueba, juego o herramienta puede utilizar una instancia independiente.

La Composition Root es un rol arquitectónico.

ADR-004 no obliga todavía a crear una clase concreta llamada `CompositionRoot` o `DeviceRuntime`.

## 11. Estado y representación

El estado de la simulación y su representación deben permanecer separados.

```text
Simulación
	│
	▼
Estado estructurado
	│
	├──► HUD
	├──► Debug
	├──► IA
	├──► Replay
	└──► Telemetría
```

El HUD no es propietario del estado.

La telemetría no es propietaria del estado.

Una cabina física no es propietaria del estado.

Cada consumidor puede transformar los datos para su representación, pero no debe modificar la verdad interna de la simulación.

Las unidades internas del motor seguirán el Sistema Internacional.

Las conversiones para presentación ocurrirán fuera del estado canónico.

## 12. Invariantes generales del Core

Las siguientes reglas deben mantenerse durante toda la evolución del proyecto:

1. Cada componente tiene una responsabilidad principal.

2. La arquitectura precede al código.

3. Una interfaz visual nunca define el modelo interno.

4. Los componentes concretos dependen de contratos estables.

5. Añadir un consumidor no obliga a modificar un productor.

6. Ningún componente conoce infraestructura que no necesita para cumplir su responsabilidad.

7. La telemetría es un consumidor, nunca una dependencia del juego.

8. Las pruebas aceptadas son baselines inmutables.

9. Una nueva integración requiere una nueva prueba de integración.

10. Una responsabilidad incorrecta se rediseña; no se parchea.

11. La composición se prefiere sobre la herencia cuando ambas soluciones sean posibles.

12. No se añade una abstracción sin una necesidad concreta.

13. La documentación arquitectónica forma parte del producto.

14. Toda decisión estructural importante debe quedar registrada.

## 13. Evolución del sistema de comunicación

La evolución prevista del sistema de comunicación será incremental.

### Etapa inicial

```text
Publisher
	│
	▼
DeviceBus
	│
	▼
Consumer
```

### Etapa de administración de suscripciones

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

### Etapa de topología

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

Cada etapa deberá resolver una necesidad real antes de ser implementada.

Las etapas futuras no deben aumentar anticipadamente la responsabilidad de DeviceBus.

DeviceBus debe permanecer reconocible y sustituible durante toda esta evolución.

## 14. Decisiones vigentes

Las siguientes decisiones forman parte de la arquitectura actual:

### VP-001 — La arquitectura precede al código

Toda característica importante seguirá este ciclo:

```text
Problema
	│
	▼
Análisis
	│
	▼
ADR
	│
	▼
Diseño del componente
	│
	▼
Implementación
	│
	▼
Pruebas unitarias
	│
	▼
Pruebas de integración
	│
	▼
Refactorización
```

### ADR-001 — DeviceBus

Velocity utilizará un Message Bus interno para gestionar el intercambio desacoplado de mensajes entre productores y consumidores.

DeviceBus permanecerá agnóstico respecto a Devices concretos, Providers, física, presentación, telemetría y hardware.

### ADR-003 — Provider System

Provider será un rol arquitectónico basado en comportamiento.

No existirá una clase base universal obligatoria.

Cada familia de Provider definirá su contrato.

Distance Provider utilizará:

```gdscript
get_distance() -> float```

### ADR-005 — Topic and Message Contract

Todos los topics internos utilizarán StringName.

BusTopics será el catálogo canónico de identidades.

BusMessage será un RefCounted construido completamente, sin setters públicos y con un payload Variant.

DeviceManifest utilizará Array[StringName] para los topics que publica y consume.

DeviceBus permanecerá agnóstico respecto a BusMessage y conservará la firma:

```gdscript
publish(
	topic: StringName,
	message: Variant
)```

## 15. Decisiones pendientes

DeviceBus, su propiedad y el contrato Topic/Message están definidos mediante:

```text
ADR-001 — DeviceBus

ADR-004 — DeviceBus Ownership and Composition

ADR-005 — Topic and Message Contract

docs/architecture/device_bus_design.md

docs/architecture/topic_message_contract_design.md```

## 16. Regla de evolución

Antes de modificar un componente importante no preguntaremos:

> ¿Qué código debemos cambiar?

Preguntaremos:

> ¿Sigue siendo correcta la responsabilidad de este componente?

Si la responsabilidad sigue siendo correcta, la implementación puede evolucionar dentro de sus límites.

Si la responsabilidad dejó de ser correcta, el componente se rediseña.

No se añadirá un parche para conservar una responsabilidad equivocada.

La meta del Core es que cada componente pueda ser comprendido, probado y reemplazado de forma independiente.
