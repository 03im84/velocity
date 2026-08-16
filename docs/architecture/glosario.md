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
