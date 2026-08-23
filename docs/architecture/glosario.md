Provider

Objeto cuya única responsabilidad
es producir datos.

----------------------

Device

Unidad funcional capaz de
interactuar con el DeviceBus.

----------------------

Measurement

Dato producido por un Sensor.

----------------------

Bus

Infraestructura de intercambio
de mensajes.

----------------------

Graph

Representación lógica de conexiones
entre dispositivos.

----------------------

Provider nulo:
No existe una instancia.

----------------------

Provider sin contrato:
Existe una instancia, pero no implementa
ningún método requerido.

----------------------

Provider con contrato incompleto:
Existe una instancia, pero falta uno
de los métodos requeridos.

----------------------

Provider válido:
Existe una instancia e implementa
get_distance() e is_valid().

----------------------

DeviceLifecycle

Componente que representa la etapa operacional
de un Device.

Estados actuales:

CREATED
INITIALIZED
READY
RUNNING
SHUTDOWN

----------------------

DeviceHealth

Componente que representa la condición operacional
y los diagnósticos de un Device.

Estados actuales:

HEALTHY
DEGRADED
CRITICAL
FAILED

----------------------

DeviceState

Componente que representa la validez y el timestamp
de los datos de un Device.

----------------------

Composition Root

Punto donde se crean, conectan, inicializan
y cierran las dependencias de un contexto.

No es necesariamente una clase concreta.

Draft

Configuración editable que todavía no puede
ser utilizada por un runtime.

Puede estar incompleta o contener errores.

----------------------

Active Simulation

Snapshot validado para ejecución exclusivamente
dentro de la simulación.

Puede contener Simulation Hazards.

----------------------

Active Hardware

Snapshot validado para controlar hardware real.

No puede contener Hardware Safety Errors.

----------------------

Simulation Hazard

Condición capaz de producir degradación,
inestabilidad o daño dentro de la simulación
sin comprometer la plataforma.

----------------------

Platform Safety Error

Condición capaz de comprometer el Core,
el proceso principal, la memoria, el stack
o la capacidad de recuperar control.

Siempre es bloqueante.

----------------------

Hardware Safety Error

Condición que puede comprometer hardware real.

No puede activarse en Hardware Mode.

----------------------

Last Known Good

Último snapshot validado y activado correctamente.

Permanece disponible cuando un Draft o una
activación posterior falla.

----------------------

Canonical Definition

Definición oficial, versionada e inmutable.

Solo puede consultarse, utilizarse o derivarse
mediante Save As.

DeviceProfileDraft

Definición editable de un modelo de Device.

No puede utilizarse directamente por runtime.

----------------------

DeviceProfile

Snapshot validado e inmutable de un modelo
de Device.

Describe lo que el modelo puede hacer.

----------------------

DeviceConfigurationDraft

Configuración editable de una instancia.

No puede utilizarse directamente por runtime.

----------------------

DeviceConfiguration

Snapshot validado e inmutable de configuración
para una instancia concreta.

----------------------

DeviceManifest

Interfaz efectiva expuesta por una instancia
después de aplicar su configuración.

----------------------

SystemProfile

Descripción persistente de un sistema o nave
ensamblada.

----------------------

ValidationIssue

Resultado individual de una validación.

Contiene código, severidad, mensaje
y objeto relacionado.

----------------------

ValidationReport

Conjunto estructurado de ValidationIssues.

Permite determinar si una operación es válida
para Simulation Mode o Hardware Mode.

----------------------

DeviceGraph

Modelo lógico que representa y valida
la topología de Devices, Ports,
TopicChannels y Connections.

No transporta mensajes.

----------------------

DeviceGraphNode

Representación lógica e inmutable de una
instancia dentro de DeviceGraph.

No es un Node de Godot.

----------------------

InputPort

Entrada lógica que representa un Topic
consumido por un Device.

----------------------

OutputPort

Salida lógica que representa un Topic
publicado por un Device.

----------------------

TopicChannel

Representación lógica de un Topic
de DeviceBus.

No almacena ni transporta mensajes.

----------------------

Connection

Relación lógica entre:

Source OutputPort

TopicChannel

Target InputPort

No representa una referencia directa
entre Devices.

----------------------

DeviceGraphDraft

Topología editable mediante API controlada.

No puede utilizarse directamente por runtime.

----------------------

DeviceGraphSnapshot

Topología validada e inmutable.

No es ejecutable.

Requiere CompositionCompiler antes
de construir runtime.

----------------------

PortSemanticKind

Identidad que describe el significado
de un flujo.

Valores iniciales:

UNSPECIFIED

MEASUREMENT

COMMAND

SETPOINT

RESULT

STATE

HEALTH

EVENT

----------------------
