# ADR-010 — Runtime Construction and Factory Binding

| Campo | Valor |
|---|---|
| Estado | ACEPTADO |
| Versión | 1.1 |
| Fecha de decisión | 04/09/2026 |
| Restauración documental | 02/10/2026 |
| Componentes | RuntimeFactoryKey, RuntimeDependencyBinding, RuntimeConstructionRequest, RuntimeDeviceHandle, RuntimeFactoryBuildResult, RuntimeFactory behavior, RuntimeHost behavior |
| Alcance | Identidad de factory, construcción atómica, ownership, host attachment y rollback |
| Estado de implementación | COMPLETO Y VERIFICADO |

## 1. Contexto

Velocity necesita convertir definiciones lógicas de Device en objetos runtime concretos.

La topología y configuración no deben contener implementación ejecutable.

El sistema debe soportar:

- múltiples Profiles;
- múltiples versiones;
- Simulation;
- Hardware futuro;
- factories concretas;
- dependencias runtime;
- objetos que necesitan host;
- construcción transaccional;
- rollback;
- cleanup explícito.

La construcción runtime no puede depender de:

- búsquedas en SceneTree;
- autoloads por comodidad;
- singletons globales;
- filesystem;
- latest;
- fallback silencioso;
- Callables almacenados en CompositionPlan.

## 2. Problema

Antes de esta decisión no existía un contrato canónico para responder:

```text
¿Qué factory corresponde a una configuración exacta?

¿Qué dependencias necesita?

¿Quién posee esas dependencias?

¿Qué objeto representa el resultado construido?

¿Qué objetos deben adjuntarse al host?

¿Quién libera recursos?

¿Qué ocurre ante fallo parcial?
```

Sin ese contrato, cada Device concreto podría inventar su propio lifecycle, ownership y cleanup.

## 3. Decisión

Velocity utilizará un Runtime Construction Contract explícito compuesto por:

```text
RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult
```

Behaviors requeridos:

```text
RuntimeFactory

RuntimeHost
```

## 4. RuntimeFactoryKey

Identidad exacta:

```text
Profile ID

+

Profile Version

+

Activation Context
```

No contiene:

- host target;
- filesystem path;
- script path;
- factory Object;
- Callable;
- priority;
- compatibility range.

No existe:

- latest;
- fallback;
- nearest;
- compatible enough;
- sustitución automática de versión;
- sustitución automática de contexto.

## 5. Razón del Activation Context

Una misma definición lógica puede requerir factories diferentes para:

- Simulation;
- Hardware.

El contexto forma parte de la identidad de construcción.

No es una preferencia posterior.

## 6. host_target excluido

`host_target` no forma parte de RuntimeFactoryKey 1.0.

Razones:

- todavía no existe taxonomía estable de hosts;
- RuntimeHost recibe el Handle completo;
- introducir host target ahora crearía identidad prematura;
- una factory puede producir varios Host Objects.

La decisión podrá revisarse si aparecen múltiples host implementations incompatibles.

## 7. RuntimeDependencyBinding

Representa una dependencia runtime ya resuelta.

Estado:

```text
Dependency ID

Object

Ownership
```

No descubre la dependencia.

No funciona como service locator.

## 8. Ownership

Valores canónicos:

```text
BORROWED

TRANSFERRED
```

### BORROWED

- owner original permanece;
- Request y Handle conservan referencia;
- factory no libera el Object;
- factory release no cambia ownership original.

### TRANSFERRED

- transferencia comienza al invocar `build()`;
- caller no ejecuta cleanup paralelo;
- en éxito, Handle asume ownership;
- en fallo, factory limpia la dependencia;
- no existe segundo cleanup por el caller.

## 9. Inicio de transacción

Construir `RuntimeConstructionRequest` no transfiere ownership.

La transacción comienza cuando se invoca:

```gdscript
factory.build(
	request
)
```

Esta frontera evita transferencia implícita durante configuración o compilación.

## 10. RuntimeConstructionRequest

Contiene:

- Device ID;
- DeviceConfiguration;
- RuntimeFactoryKey;
- RuntimeDependencyBindings pre-resueltos.

No contiene:

- SceneTree;
- Node paths;
- service locator;
- autoload lookup;
- filesystem;
- active DeviceBus global;
- RuntimeHost.

## 11. Identidad coherente

Request válido requiere coincidencia entre:

```text
Device ID

Configuration Device ID

Configuration Profile ID

Factory Key Profile ID

Configuration Profile Version

Factory Key Profile Version

Configuration Activation Context

Factory Key Activation Context
```

No se permite construir con identidad aproximada.

## 12. RuntimeDeviceHandle

Representa una unidad runtime construida y su ownership asociado.

Contiene:

- Device ID;
- DeviceConfiguration;
- RuntimeFactoryKey;
- Primary Runtime Object;
- Host Objects;
- Dependency Bindings.

Primary Runtime Object utiliza:

```gdscript
Object
```

Host Objects utilizan:

```gdscript
Array[Object]
```

## 13. Handle no coordina sistema

RuntimeDeviceHandle no:

- posee CompositionRuntime;
- posee DeviceBus global;
- ejecuta lifecycle global;
- resuelve otras factories;
- adjunta por sí mismo;
- libera por sí mismo.

Representa una sola unidad construida.

## 14. RuntimeFactoryBuildResult

Contiene:

```text
RuntimeDeviceHandle

ValidationReport
```

Success requiere:

- Handle no null;
- Report no null;
- Handle válido;
- Report válido para Activation Context.

No ejecuta cleanup.

No sustituye factory release.

## 15. RuntimeFactory behavior

Contrato:

```gdscript
build(
	request: RuntimeConstructionRequest
) -> RuntimeFactoryBuildResult
```

```gdscript
release(
	handle: RuntimeDeviceHandle
) -> ValidationReport
```

GDScript verifica behavior mediante presencia de métodos y pruebas de integración.

## 16. Factory construct-only

RuntimeFactory:

- valida Request;
- adquiere recursos;
- construye Primary Runtime Object;
- construye Host Objects;
- produce Handle;
- limpia parciales en fallo;
- libera su producto cuando Runtime lo solicita.

RuntimeFactory no:

- inicializa Device lifecycle;
- ejecuta `set_ready`;
- ejecuta `start`;
- adjunta Host Objects;
- crea DeviceBus global;
- descubre dependencias;
- consulta service locator;
- activa Hardware.

## 17. Estado inicial

El producto exitoso de factory equivale conceptualmente a:

```text
CREATED
```

CompositionRuntime futuro coordinará:

```text
attach

initialize

set_ready

start
```

## 18. Construcción atómica

Éxito:

```text
Request válido
		│
		▼
Factory build
		│
		▼
Handle válido
+
Report válido
```

Fallo:

```text
Factory limpia recursos parciales

Factory limpia TRANSFERRED

Factory preserva BORROWED

Handle null

ValidationReport
```

No se expone Handle parcial.

## 19. RuntimeHost behavior

Contrato:

```gdscript
attach(
	handle: RuntimeDeviceHandle
) -> ValidationReport
```

```gdscript
detach(
	handle: RuntimeDeviceHandle
) -> ValidationReport
```

RuntimeHost recibe el Handle completo.

No recibe Host Objects dispersos sin identidad de unidad.

## 20. Host transaccional

RuntimeHost debe:

- evitar attach duplicado;
- revertir attach parcial;
- tolerar detach repetido;
- procesar Host Objects en orden estable;
- no sustituir factory release.

Attach y release son responsabilidades diferentes.

## 21. Rollback global

CompositionRuntime futuro coordinará rollback en orden inverso a adquisición.

Si build falla:

```text
release Handles anteriores
en orden inverso
```

Si attach falla:

```text
detach

↓

release
```

Si lifecycle falla:

```text
shutdown

↓

detach

↓

release
```

## 22. Last Known Good

Una construcción o activación fallida no sustituye runtime activo.

Flujo:

```text
Construir candidato

Validar candidato

Adjuntar candidato

Completar lifecycle

Commit completo

Sustituir Last Known Good
```

Antes del commit completo, Last Known Good permanece intacto.

## 23. DeviceBus ownership

DeviceBus pertenece a CompositionRuntime futuro.

Factory no crea Bus global.

Factory no usa autoload.

DeviceBus se entrega durante initialize coordinado.

## 24. Registry separado

RuntimeFactory binding se resolverá fuera de RuntimeFactory.

RuntimeFactoryRegistry:

```text
RuntimeFactoryKey

→

RuntimeFactoryDescriptor

→

RuntimeFactory
```

DeviceCatalog no contiene factories.

CompositionPlan conserva Key, no factory.

## 25. Dependencias pre-resueltas

RuntimeConstructionRequest recibe Bindings ya resueltos.

Factory no busca:

- services;
- Nodes;
- Providers;
- hardware;
- filesystem;
- global state.

Esto hace construcción reproducible y testeable.

## 26. No Callable genérico

Factory no se modela como Callable anónimo almacenado en Plan.

Razones:

- identidad pobre;
- behavior incompleto;
- release no explícito;
- difícil validación;
- ownership opaco;
- debugging débil.

Se utiliza Object con behavior explícito.

## 27. Alternativas consideradas

### Factory devuelve Device directamente

Rechazada.

No representa Host Objects, ownership o cleanup.

### Factory inicia lifecycle

Rechazada.

Mezcla construcción con coordinación global.

### Factory adjunta Nodes

Rechazada.

Acopla construcción al host.

### DeviceCatalog contiene factories

Rechazada.

Mezcla definición lógica con construcción runtime.

### Service locator

Rechazada.

Oculta dependencias y ownership.

### host_target dentro de Key 1.0

Rechazada por falta de necesidad concreta.

## 28. Seguridad

Esta decisión aplica VP-002 vigente:

> El usuario o el entorno pueden equivocarse. Una operación puede ser rechazada o abortada. El simulador debe permanecer seguro, consistente y recuperable.

Ante error:

- construcción se aborta;
- recursos parciales se limpian;
- Handle no se publica;
- Last Known Good permanece;
- Hardware no se activa.

## 29. Consecuencias positivas

- identidad exacta;
- dependencias explícitas;
- ownership explícito;
- construcción atómica;
- cleanup verificable;
- host desacoplado;
- lifecycle coordinable;
- factories sustituibles;
- pruebas aisladas;
- rollback global posible.

## 30. Consecuencias negativas

- más componentes;
- factory signature se verifica por comportamiento;
- caller debe preparar Bindings;
- CompositionRuntime debe coordinar fases;
- TRANSFERRED requiere disciplina estricta;
- no existe plugin discovery automático.

Estas consecuencias son aceptadas.

## 31. Criterios de aceptación

1. RuntimeFactoryKey exacta.

2. Sin latest o fallback.

3. Activation Context en Key.

4. host_target excluido de Key 1.0.

5. Bindings pre-resueltos.

6. BORROWED preservado.

7. TRANSFERRED explícito.

8. Transferencia comienza en build.

9. Request inmutable por contrato.

10. Handle representa una unidad.

11. Primary Runtime Object usa Object.

12. Host Objects tipados.

13. Build Result defensivo.

14. Factory construct-only.

15. Factory no inicia lifecycle.

16. Factory no adjunta.

17. Factory limpia parciales.

18. Factory release explícito.

19. RuntimeHost attach/detach explícito.

20. Rollback inverso.

21. No service locator.

22. No DeviceBus global.

23. Last Known Good preservado.

24. Pruebas unitarias PASS.

25. Prueba de integración PASS.

26. Run All PASS.

## 32. Implementación aceptada

Componentes:

```text
RuntimeFactoryKey

RuntimeDependencyBinding

RuntimeConstructionRequest

RuntimeDeviceHandle

RuntimeFactoryBuildResult
```

Behaviors verificados:

```text
RuntimeFactory

RuntimeHost
```

Implementación:

```text
4147ec4
feat(runtime): add runtime construction contracts
```

Cierre documental:

```text
659c3c3
docs(runtime): close runtime construction contract 1.0
```

Baseline Runtime Construction:

```text
Tests: 6
Checks: 173
Failures: 0
RESULT: PASS
```

## 33. Estado

```text
ADR-010
ACEPTADO
IMPLEMENTADO
VERIFICADO
RESTAURADO DOCUMENTALMENTE
```

La restauración no cambia la decisión implementada.

Corrige un archivo cuyo contenido inicial era una copia accidental de Resume Prompt.

Git conserva la versión histórica errónea.
