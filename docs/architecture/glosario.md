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
