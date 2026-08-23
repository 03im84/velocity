# ADR-008 — Device Definitions, Profiles and Configuration

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.0 |
| Fecha | 16/08/2026 |
| Componentes | DeviceProfile, DeviceConfiguration, DeviceManifest, SystemProfile |
| Alcance | Definiciones, configuración nominal y composición persistente |

## 1. Contexto

Velocity necesita representar:

- tipos de Devices;
- capacidades;
- límites;
- configuraciones de instancias;
- interfaces efectivas;
- sistemas ensamblados;
- topologías editables;
- perfiles guardados;
- snapshots activos.

La implementación actual contiene:

```text
profiles/profile.gd
```

con:

```gdscript
extends Resource
class_name Profile
```

La clase no tiene contrato ni responsabilidad definida.

El nombre `Profile` puede representar conceptos diferentes y favorece el crecimiento de un componente monolítico.

VP-002 también exige:

- definiciones canónicas inmutables;
- Save As;
- versionado;
- Draft;
- Active Simulation;
- Active Hardware;
- validación transaccional;
- Last Known Good.

DeviceGraph necesita contratos claros antes de representar Devices y Ports.

## 2. Problema

Mezclar en una sola clase:

- datasheet;
- configuración;
- manifest;
- sistema ensamblado;
- estado runtime;
- calibración;
- adaptación;

produciría:

- campos opcionales sin relación;
- validación ambigua;
- datos persistentes mezclados con runtime;
- Profiles sobrescribibles;
- DeviceGraph monolítico;
- dificultad para crear un editor visual;
- incompatibilidad con VP-002.

Velocity necesita conceptos separados y una fuente de verdad clara.

## 3. Decisión general

Se utilizarán cuatro conceptos principales:

```text
DeviceProfile

DeviceConfiguration

DeviceManifest

SystemProfile
```

Responsabilidades:

```text
DeviceProfile:
describe un modelo.

DeviceConfiguration:
describe una instancia configurada.

DeviceManifest:
describe la interfaz efectiva.

SystemProfile:
describe un sistema ensamblado.
```

DeviceGraph utilizará estos contratos sin asumir sus responsabilidades.

## 4. DeviceProfile

DeviceProfile representa las características posibles de un modelo de Device.

Equivale a un datasheet lógico.

Información común:

- profile ID;
- profile version;
- display name;
- description;
- primary role;
- capabilities;
- topics soportados;
- requisitos;
- estado canónico;
- referencia de derivación.

DeviceProfile no contiene:

- Device ID de una instancia;
- Connections concretas;
- estado runtime;
- Health actual;
- posición dentro de una nave;
- Calibration de una unidad;
- RuntimeAllocation.

## 5. Identidad de DeviceProfile

Cada DeviceProfile tendrá:

```text
profile_id

profile_version
```

La combinación será única.

Formato conceptual del ID:

```text
namespace.device_name.variant
```

Ejemplos:

```text
velocity.distance_sensor.ideal

velocity.hover_thruster.ideal

velocity.hover_mcu.ideal

velocity.fcc.ideal
```

Ejemplo versionado:

```text
velocity.hover_mcu.ideal@1
```

DeviceProfile identifica el modelo.

No identifica una instancia runtime.

## 6. Primary Role

Cada DeviceProfile tendrá un único rol principal.

Roles iniciales:

```text
SENSOR

ACTUATOR

LOCAL_CONTROLLER

SUPERVISORY_CONTROLLER
```

El rol expresa la responsabilidad y autoridad principal.

Las capacidades complementarias se declaran mediante capabilities.

Primary Role no obliga a utilizar una jerarquía de clases.

La representación concreta utilizará una identidad extensible, como StringName y un catálogo canónico.

## 7. Canonical DeviceProfile

Los DeviceProfiles incluidos con Velocity serán canónicos.

Reglas:

- solo lectura mediante herramientas;
- no sobrescribibles;
- no eliminables desde la interfaz;
- versionados;
- derivables;
- validables al cargar.

Una definición canónica modificada fuera de las herramientas soportadas será tratada como:

```text
untrusted

tampered

invalid
```

según las capacidades futuras de integridad.

La primera versión no requiere firmas criptográficas.

## 8. Derivación y Save As

Una modificación de un DeviceProfile canónico crea una nueva definición.

La definición derivada tendrá:

- nuevo profile ID;
- nueva version;
- `canonical = false`;
- referencia `based_on`.

Ejemplo:

```text
profile_id:
user.hover_mcu.custom_01

based_on:
velocity.hover_mcu.ideal@1
```

El original permanece intacto.

## 9. DeviceConfiguration

DeviceConfiguration representa cómo se utiliza una instancia concreta de un DeviceProfile.

Información común:

- configuration ID;
- configuration version;
- Device ID;
- Profile ID;
- Profile version;
- estado de configuración;
- datos especializados;
- referencia de derivación.

DeviceConfiguration no redefine las capacidades máximas del Profile.

Selecciona opciones dentro de lo permitido.

## 10. Configuración especializada

No existirá una configuración universal con todos los campos posibles.

Se permitirán configuraciones especializadas.

Ejemplos:

```text
DistanceSensorConfiguration

HoverThrusterConfiguration

HoverMCUConfiguration

FlightControlConfiguration
```

Cada configuración especializada contendrá únicamente los datos que necesita.

Todas compartirán un contrato mínimo de identidad, versión, referencia a Profile, estado y validación.

## 11. Estados de DeviceConfiguration

Se utilizarán conceptualmente:

```text
DRAFT

ACTIVE_SIMULATION

ACTIVE_HARDWARE
```

### DRAFT

Editable.

Puede estar incompleto.

No es utilizado directamente por runtime.

### ACTIVE_SIMULATION

Snapshot inmutable validado para simulación.

Puede contener Simulation Hazards.

### ACTIVE_HARDWARE

Snapshot inmutable validado para hardware real.

No puede contener Hardware Safety Errors.

La activación produce un snapshot.

No convierte el Draft mutable en estado runtime compartido.

## 12. DeviceManifest

DeviceManifest representa la interfaz efectiva de una instancia después de aplicar su configuración.

Contiene:

- capabilities activas;
- topics publicados;
- topics consumidos;
- requirements efectivos.

Relación:

```text
DeviceProfile
	  │
	  ▼
DeviceConfiguration
	  │
	  ▼
Manifest Builder / Compiler
	  │
	  ▼
DeviceManifest
```

DeviceGraph utiliza DeviceManifest.

DeviceManifest no sustituye DeviceProfile.

## 13. Manifest Builder

La construcción del Manifest efectivo no pertenecerá a DeviceGraph.

Una responsabilidad externa deberá:

- validar Profile;
- validar Configuration;
- seleccionar capabilities;
- seleccionar Ports;
- construir Manifest;
- producir ValidationReport.

Nombre futuro posible:

```text
DeviceManifestBuilder

DeviceConfigurationCompiler
```

La decisión concreta se realizará en el diseño.

## 14. SystemProfile

SystemProfile representa un sistema o nave completa.

Información conceptual:

- SystemProfile ID;
- version;
- display name;
- Device instances;
- referencias a DeviceProfiles;
- referencias a DeviceConfigurations;
- topología;
- Connections;
- metadata.

SystemProfile no ejecuta Devices.

Se utiliza para construir:

- DeviceGraph;
- Composition Plan;
- Runtime Context;
- herramientas;
- documentación.

## 15. Source of Truth

SystemProfile será la representación persistente canónica de una composición.

DeviceGraph será el modelo lógico en memoria durante edición, validación o compilación.

Flujo de carga:

```text
SystemProfile
	  │
	  ▼
DeviceGraph
```

Flujo de guardado:

```text
DeviceGraph validado
	  │
	  ▼
nuevo SystemProfile snapshot
```

DeviceGraph no abrirá ni guardará archivos directamente.

Un componente externo realizará serialización.

## 16. DeviceCatalog

DeviceCatalog proporcionará los DeviceProfiles disponibles.

Responsabilidades conceptuales:

- listar;
- buscar;
- identificar;
- entregar Profiles;
- distinguir canonical y derived;
- detectar IDs duplicados.

DeviceCatalog no:

- ejecuta Devices;
- configura instancias;
- crea Connections;
- controla DeviceBus;
- compila runtime.

La implementación de DeviceCatalog no es obligatoria durante el primer paso si un catálogo mínimo de prueba es suficiente.

## 17. GraphEditor

GraphEditor permitirá:

1. seleccionar DeviceProfile;

2. crear una instancia;

3. crear DeviceConfiguration Draft;

4. construir Manifest efectivo;

5. crear DeviceNode;

6. crear Ports;

7. conectar TopicChannels;

8. validar;

9. producir SystemProfile.

GraphEditor depende del modelo.

El modelo no depende del editor.

## 18. ValidationReport

Toda validación producirá resultados estructurados.

Severidades iniciales:

```text
INFO

WARNING

SIMULATION_HAZARD

STRUCTURAL_ERROR

PLATFORM_SAFETY_ERROR

HARDWARE_SAFETY_ERROR
```

Un resultado podrá contener:

- code;
- severity;
- message;
- related object ID;
- related field;
- suggested action.

ValidationReport no modifica Profile ni Configuration.

## 19. Activación transaccional

Flujo:

```text
DeviceConfiguration Draft

↓

ValidationReport

↓

Manifest efectivo

↓

DeviceGraph validado

↓

Composition Plan

↓

Immutable Snapshot

↓

Activation
```

Si una etapa falla:

```text
Last Known Good continúa activo.
```

No se aplica una configuración parcial.

## 20. Devices ideales

La primera versión trabajará con Devices ideales o prototipo.

Información inicial:

- ID;
- version;
- display name;
- primary role;
- capabilities;
- topics soportados;
- requirements;
- configuración lógica mínima.

No incluirá todavía:

- voltaje;
- corriente;
- potencia;
- temperatura;
- firmware;
- hardware identity;
- calibración;
- desgaste;
- fallos aleatorios;
- RuntimeAllocation;
- hardware detallado.

Esta limitación reduce complejidad sin impedir evolución.

## 21. DeviceCalibration

DeviceCalibration es un concepto reconocido, pero su implementación queda pospuesta.

Responsabilidad futura:

> Conservar correcciones medidas de una instancia física.

No será un campo obligatorio de todas las configuraciones.

## 22. AdaptationPolicy

AdaptationPolicy es un concepto reconocido, pero su implementación queda pospuesta.

Responsabilidad futura:

> Definir adaptaciones autónomas permitidas para un controlador local.

No será parte obligatoria de DeviceConfiguration base.

## 23. RuntimeAllocation

RuntimeAllocation es un concepto reconocido, pero su implementación queda pospuesta.

Responsabilidad futura:

> Representar la asignación efectiva de recursos durante runtime.

No modificará automáticamente la configuración nominal.

## 24. DeviceIdentity

DeviceIdentity identifica una instancia runtime.

DeviceConfiguration contiene el Device ID esperado.

Debe cumplirse:

```text
DeviceIdentity.device_id
==
DeviceConfiguration.device_id
```

DeviceProfile identifica un modelo.

DeviceIdentity identifica una instancia.

No son intercambiables.

## 25. DeviceHealth y DeviceState

Profile y Configuration describen intención y capacidad.

Health y State describen runtime.

Ejemplo:

```text
Profile:
4 inputs soportados.

Configuration:
4 inputs configurados.

Graph:
4 inputs conectados.

Health:
1 input FAILED.

State:
dato inválido.
```

Un fallo runtime no reescribe automáticamente DeviceConfiguration.

## 26. DeviceGraph

DeviceGraph recibirá:

- DeviceIdentity;
- DeviceManifest efectivo;
- referencia a DeviceProfile;
- referencia a DeviceConfiguration;
- Primary Role;
- Ports;
- Connections.

DeviceGraph no:

- modifica Profiles;
- modifica Configurations;
- construye Manifests;
- persiste SystemProfiles;
- activa runtime.

## 27. VP-002

Todo el sistema deberá cumplir:

- canonical definitions inmutables;
- Save As;
- versionado;
- Draft;
- Active Simulation;
- Active Hardware;
- validación transaccional;
- snapshots;
- Last Known Good;
- fail closed;
- Simulation Hazards permitidos;
- Hardware Safety Errors bloqueados.

## 28. Sustitución de Profile genérico

La clase:

```text
profiles/profile.gd
```

será declarada superada.

No será ampliada gradualmente.

Se retirará después de crear contratos y pruebas sucesoras.

Permanecerá disponible mediante Git.

## 29. Estructura física

La implementación deberá separar:

- clases del Core;
- definiciones canónicas;
- definiciones derivadas;
- DeviceConfigurations;
- SystemProfiles;
- snapshots generados.

La estructura definitiva de carpetas se decidirá en el diseño de implementación.

No se moverán archivos durante ADR-008.

## 30. Alternativas descartadas

### Profile universal

Descartado por ambigüedad y crecimiento monolítico.

### Configuration dentro de DeviceGraph

Descartada porque mezcla configuración y topología.

### DeviceManifest como datasheet

Descartado porque Manifest representa interfaz efectiva.

### Modificar definiciones canónicas

Descartado por VP-002.

### Calibration inmediata

Pospuesta durante Devices ideales.

### AdaptationPolicy inmediata

Pospuesta hasta diseñar MCU y fault management.

### RuntimeAllocation inmediata

Pospuesta hasta existir recursos físicos configurables.

## 31. Consecuencias positivas

- responsabilidades claras;
- definiciones inmutables;
- configuración especializada;
- Graph pequeño;
- editor visual viable;
- versionado;
- rollback;
- modularidad;
- soporte futuro para hardware;
- composición reproducible.

## 32. Consecuencias negativas

- más contratos;
- más validación;
- necesidad de versionado;
- compilación de Manifest;
- separación Draft/Snapshot;
- herramientas adicionales;
- migración de Profile genérico.

Estas consecuencias son aceptadas.

## 33. Invariantes

1. DeviceProfile describe un modelo.

2. DeviceConfiguration describe una instancia.

3. DeviceManifest describe interfaz efectiva.

4. SystemProfile describe un sistema.

5. Canonical Profiles son inmutables.

6. Save As crea una identidad nueva.

7. Configuration se valida contra Profile.

8. DeviceGraph consume Manifest efectivo.

9. DeviceGraph no genera Manifest.

10. DeviceGraph no persiste SystemProfile.

11. Draft no ejecuta.

12. Active snapshots son inmutables.

13. Last Known Good se preserva.

14. DeviceIdentity identifica instancia.

15. DeviceProfile identifica modelo.

16. Devices ideales son el alcance inicial.

17. Calibration permanece futura.

18. AdaptationPolicy permanece futura.

19. RuntimeAllocation permanece futura.

20. Profile genérico será retirado.

## 34. Criterios de aceptación

La implementación inicial satisface ADR-008 cuando:

1. existe DeviceProfile;

2. existe identidad y versión de Profile;

3. existe Primary Role;

4. existen Profiles canónicos de prueba;

5. las definiciones canónicas no se sobrescriben mediante la API;

6. existe DeviceConfiguration;

7. Configuration referencia Profile;

8. existe estado DRAFT;

9. existe validación mínima;

10. existe ValidationReport;

11. se puede construir un Manifest efectivo;

12. Profile y Configuration permanecen separados;

13. existe una representación mínima de SystemProfile o su diseño concreto;

14. Profile genérico tiene una sucesora;

15. las pruebas terminan correctamente.

## 35. Fuera de alcance

ADR-008 no implementará todavía:

- hardware catalog real;
- DeviceCalibration;
- AdaptationPolicy;
- RuntimeAllocation;
- firmas criptográficas;
- ConfigurationEditor;
- GraphEditor;
- CompositionCompiler completo;
- persistencia completa;
- Hardware Mode real.

## 36. Regla de evolución

Una capacidad nueva deberá colocarse según su responsabilidad.

```text
Capacidad del modelo:
DeviceProfile.

Valor elegido para instancia:
DeviceConfiguration.

Interfaz expuesta:
DeviceManifest.

Composición del sistema:
SystemProfile.

Topología en memoria:
DeviceGraph.

Estado actual:
DeviceState o DeviceHealth.

Asignación runtime:
RuntimeAllocation futuro.
```

Ninguno de estos componentes debe absorber las responsabilidades de los demás.