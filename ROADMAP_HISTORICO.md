# HOGUERAS — Sprints y tickets

Backlog vivo del proyecto. Cada sprint es una unidad de entrega; no se fijan fechas hasta acordar duración y disponibilidad del equipo.

## Cómo usamos este archivo

- Cada ticket tiene ID estable, estado, prioridad, dependencias y criterio de aceptación.
- Estados: **Implementado · validar** (el código está, falta validarlo en Godot), **Pendiente**, **En curso**, **Hecho** (aceptación verificada).
- Un sprint se cierra cuando todos sus tickets están en **Hecho** y el proyecto abre desde `project.godot` sin errores.
- Actualizar estado y criterios aquí al empezar o cerrar cada ticket. No marcar como hecho solo porque el código exista.
- Para repetir el smoke de regresión, abre `Tests/sprint0_smoke.tscn` en Godot y ejecuta la escena actual (F6).
- Para jugar, abre `Scenes/main.tscn` y ejecuta la escena actual (F6), o pulsa F5 para arrancar el proyecto. El viewport del editor muestra el escenario; el HUD y las acciones aparecen al ejecutar.

## Vocabulario y economía acordados

- **Hollín**: moneda temporal de la run; se genera al quemar combustible, se gasta en mejoras y compras, y se reinicia al hacer prestigio.
- **Brasas**: progreso permanente entre runs; cada 100 de hollín generado concede una brasa y cada brasa suma 0,1 al multiplicador base.
- El nombre **All-in** queda retirado del juego y del código.
- Valores actuales de prototipo: producción de hollín = calor × multiplicador × 0,015; mejora inicial de 25 de hollín, coste siguiente ×1,6, +0,25 al multiplicador por mejora; tienda de combustible a 4/9/14 de hollín.
- Los valores de la primera run se validaron en HOG-006; el balance podrá revisarse con datos de nuevas pruebas.

## Sprint 0 — Primer prototipo jugable

Estado: **Cerrado**. Proyecto y ciclo validados con Godot 4.7.2 headless y `Tests/sprint0_smoke.tscn`.
Nota del entorno de validación: Godot muestra un aviso de almacén de certificados raíz de Windows; la carga de escenas y la prueba terminan correctamente.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-001 | Crear proyecto Godot, escena 3D inicial y HUD | P0 | Hecho | — | `project.godot` abre la escena principal y muestra la hoguera, cámara y HUD sin errores. |
| HOG-002 | Combustibles como recursos y combustión secuencial | P0 | Hecho | HOG-001 | Hojarasca, leña y tronco conservan sus valores; se consumen en orden y el calor decae al acabar la pila. |
| HOG-003 | Economía temporal de hollín y mejoras | P0 | Hecho | HOG-002 | El fuego genera hollín; una mejora descuenta su coste y actualiza el multiplicador y el precio siguiente. |
| HOG-004 | Tienda de combustible basada en datos | P1 | Hecho | HOG-003 | Comprar un combustible descuenta hollín y aumenta el stock; el precio procede del recurso del combustible. |
| HOG-005 | Prestigio y guardado de brasas | P0 | Hecho | HOG-003 | Con 100 de hollín generado se puede reiniciar, recibir brasas, reponer el stock y conservar las brasas al reabrir. |
| HOG-006 | Validar y equilibrar la primera run | P0 | Hecho | HOG-001–005 | En la validación de balance previa a Sprint 2, el stock inicial consumía 60 s simulados y producía 119,88 de hollín; también se validaron compra de tronco (14), mejora (25 → 40), prestigio, reposición y guardado. |

## Sprint 1 — Fiabilidad y lectura del ciclo

Estado: **Cerrado**. Regresión Godot 4.7.2 ejecutada correctamente; el test restaura el guardado de progreso al terminar.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-007 | Separar responsabilidades de economía, inventario y run | P1 | Hecho | HOG-006 | `GameManager` coordina `EconomyManager`, `InventoryManager` y `RunProgressManager`; el HUD y la combustión usan getters y acciones públicas. El inventario devuelve una copia de su stock. |
| HOG-008 | Añadir pruebas de reglas económicas y de combustible | P1 | Hecho | HOG-007 | Regresión Godot cubre orden de consumo, stock, compra fallida, coste creciente, enfriamiento, varias brasas por prestigio y reposición. |
| HOG-009 | Mejorar feedback de acciones y estados vacíos | P2 | Hecho | HOG-006 | El HUD explica pila vacía/lista, muestra una guía contextual y cada acción deshabilitada expone el requisito en su tooltip. |

## Sprint 2 — Estrategia de combustión

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-010 | Calcular calidad de la hoguera según composición y orden | P0 | Implementado · validar | HOG-008 | Hojarasca→leña y leña→tronco suman 12% por transición; variedad suma 4% por tipo nuevo y repetición resta 2%. La calidad altera el ritmo de calor y, con él, la producción de hollín; HUD muestra el porcentaje. |
| HOG-011 | Introducir fases de encendido y mantenimiento | P1 | Implementado · validar | HOG-010 | Hojarasca suma 20% de calor y muestra fase de encendido; leña muestra mantenimiento y los troncos combustión larga según su duración de datos. |
| HOG-012 | Convertir calor residual en brasas recuperables | P1 | Implementado · validar | HOG-010 | Al terminar la pila, 20% del calor acumulado se guarda hasta un máximo de 12; el prestigio lo reserva para la run siguiente y el primer encendido lo consume. Persiste en el guardado. |
| HOG-013 | Añadir intervención activa durante la quema | P2 | Implementado · validar | HOG-011 | `Avivar` cuesta 15 de hollín y multiplica por 1,5 la producción durante 12 s; requiere fuego activo y el HUD comunica duración y requisitos. |

## Sprint 3 — Progresión permanente

Estado: Implementado · validar. Pendiente validar las cuatro tareas en Godot antes de cerrar el sprint.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-014 | Arbol permanente de combustion | P0 | Implementado · validar | HOG-012 | Tres nodos persistentes de calor con coste, prerequisitos y efectos visibles antes de comprar. |
| HOG-015 | Arbol permanente de produccion de hollin | P0 | Implementado · validar | HOG-014 | Tres nodos economicos persistentes modifican la produccion de hollin. |
| HOG-016 | Desbloqueos estructurales por brasas | P1 | Implementado · validar | HOG-014 | Ganar cinco brasas desbloquea los nodos avanzados; el HUD muestra requisito y progreso. |
| HOG-017 | Guardado y migracion de progresion | P1 | Implementado · validar | HOG-014 | El guardado version 2 migra version 1, conserva nodos y brasas disponibles; archivos ausentes o ilegibles inician progreso limpio. |

## Sprint 4 — Instalaciones y mundo

Estado: Implementado · validar. Pendiente validar las cuatro tareas en Godot antes de cerrar el sprint.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-018 | Añadir una segunda hoguera independiente | P0 | Implementado · validar | HOG-016 | Cada hoguera tiene pila, calor, mejoras y producción propios; la producción global suma ambas sin mezclar inventarios. |
| HOG-019 | Añadir mapas y biomas iniciales | P1 | Implementado · validar | HOG-018 | Hay al menos dos biomas con presentación y reglas diferenciadas, desbloqueados por progreso permanente. |
| HOG-020 | Ampliar combustibles por datos, no por lógica duplicada | P1 | Implementado · validar | HOG-010 | Se puede añadir un combustible nuevo con recurso y configuración; tienda, inventario, HUD y combustión lo reconocen. |
| HOG-021 | Implementar entregas y reposición de combustible | P2 | Implementado · validar | HOG-020 | Cada run recibe una cantidad de combustible definida por el sistema de entregas y el jugador ve cuándo llegará la siguiente. |

## Sprint 5 - Automatizacion e inactividad

Estado: Implementado · validar. Automatizacion por hoguera, prioridades configurables y progreso offline limitado a 8 horas y al combustible disponible al guardar.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptacion |
|---|---|---:|---|---|---|
| HOG-022 | Automatizar alimentacion y encendido | P1 | Implementado · validar | HOG-018 | Desbloqueo temporal por hoguera (80/160 de hollin); carga y encendido automaticos, pausa individual y ajustes guardados al cerrar. |
| HOG-023 | Anadir produccion pasiva y progreso sin sesion | P1 | Implementado · validar | HOG-022 | Al volver calcula la produccion estimada, limitada a 8 h y a la duracion del combustible disponible; muestra resumen, conserva el hollin de run y reclama el premio una sola vez. |
| HOG-024 | Crear politicas de automatizacion por combustible | P2 | Implementado · validar | HOG-022 | Se rota la prioridad por hoguera; la carga consulta el stock local y no consume combustible inexistente. |

## Sprint 6 — Identidad visual y presentación

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-025 | Crear tiers visuales de fuego | P1 | Implementado · validar | HOG-016 | Los tiers convencional, fatuo, valyrio y negro tienen efectos distinguibles y desbloqueos visibles. |
| HOG-026 | Separar cosméticos de bonificaciones | P1 | Implementado · validar | HOG-025 | Cada variante indica si es estética o funcional; cambiar una skin estética no altera producción ni costes. |
| HOG-027 | Pulir efectos de combustión y recompensas | P2 | Implementado · validar | HOG-025 | Llama, iluminación, partículas y feedback de hollín reaccionan a estado e intensidad sin ocultar información. |
| HOG-028 | Añadir audio y controles de accesibilidad | P2 | Implementado · validar | HOG-027 | Audio con volumen ajustable, controles legibles y opciones básicas de contraste y tamaño de texto. |

## Sprint 7 — Preparación de entrega

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-029 | Balancear economía y duración de runs | P0 | Implementado · validar | HOG-023 | Se prueban runs cortas y largas; costes, premios y progresión no producen bloqueos ni crecimiento sin decisiones. |
| HOG-030 | Revisar rendimiento y errores de sesión larga | P1 | Implementado · validar | HOG-027 | Una sesión prolongada no acumula nodos, efectos o señales sin límite y no presenta errores relevantes. |
| HOG-031 | Preparar exportación y guía de inicio | P0 | Implementado · validar | HOG-029–030 | La build exportada arranca en una instalación limpia y una guía explica controles, guardado y ciclo principal. |

Sprint 6 implementa tiers visuales (0/5/10/20 brasas), skins estéticas independientes, partículas, audio procedural con volumen y ajustes de contraste/tamaño guardados en user://presentation.cfg. Pendiente validar ejecución en Godot.

## Registro de decisiones
- 2026-11-02 - Sprint 5 implementado para validar: automatizacion por instalacion, prioridades ciclicas, progreso offline limitado a 8 h y guardado version 3 con hollin de run persistente.

- **2026-11-02** — Moneda de run: Hollín. La moneda permanente se denomina Brasas.
- **2026-11-02** — El tablero vive en este archivo Markdown; no se añade una dependencia de servicio externo.
- **2026-11-02** — La conversión calor→hollín se escala por 0,015; la pila inicial genera 119,88 en 60 s simulados en el orden hojarasca → leña → troncos.
- **2026-11-02** — Sprint 0 cerrado tras validar escena y ciclo con Godot 4.7.2; smoke test reusable en `Tests/sprint0_smoke.tscn`.
- **2026-11-02** — Sprint 2 implementado para validación: calidad de secuencia, fases de combustible, reserva térmica limitada entre runs y acción de avivar. El orden inicial hojarasca→leña→troncos queda por encima de su inversión.

- 2026-11-02 - Sprint 3 implemented: permanent combustion and soot branches, spendable ember wallet, five-ember advanced unlock, versioned save migration.

- **2026-11-02** — Sprint 4 implementado para validación: segunda hoguera con almacén y mejora local, biomas con desbloqueo por brasas, catálogo de combustible basado en recursos y entregas temporizadas.






## Registro de validación

- La regresión automatizada `Tests/sprint0_smoke.tscn` escribe un archivo por ejecución con el resultado de cada comprobación en `Tests/Logs/`; imprime la ruta completa en la consola. Las demás validaciones manuales se anotan aquí con fecha, pasos y resultado al ejecutarlas.
- **2026-11-02** — Ampliada la regresión para cubrir calidad de mezcla, fases/calor, reserva recuperable y acción Avivar (HOG-010–013), además de los checks previos de Sprints 0 y 1. No ejecutada: no se encontró Godot en `PATH` ni en las ubicaciones locales inspeccionadas. Sprint 2 permanece **Implementado · validar** hasta poder correr la escena y revisar el HUD en Godot.
- **2026-11-02** — Ampliada la regresión para HOG-014–024: ramas permanentes y migración de guardado, hogueras e inventarios independientes, biomas, combustible por datos, entregas, automatización por estación, prioridades y premios offline. Revisión de ejecutable sin resultado: Godot no está en `PATH` ni en las ubicaciones comunes inspeccionadas. No se generó log ni se pudo revisar la escena/HUD en el editor; Sprint 3, 4 y 5 siguen **Implementado · validar** y sus criterios no se consideran verificados.
- No se marcan pruebas como ejecutadas por el mero hecho de añadir instrumentación; el primer log se generará al correr la escena de regresión en Godot.

## Sprint 8 — Metaprogresion

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptacion |
|---|---|---:|---|---|---|
| HOG-032 | Separar el arbol permanente en una pantalla de mejoras | P1 | Implementado · validar | HOG-014–017 | El juego ofrece un menu propio con dos ramas visuales, nodos conectados, costes, prerequisitos, bloqueos y compra persistente; se puede volver al juego sin perder estado. |

- 2026-11-02 — HOG-032 implementado: menu de mejoras permanente separado del HUD, dos ramas de nodos con conectores y estado de compra, tema visual de carbon y brasa.

## Sprint 9 — Definición del bucle y alcance inicial

Estado: **Cerrado**. Decisiones seleccionadas y alcance inicial documentados en `ROADMAP.md`. Esto define la dirección futura y no reemplaza de inmediato los sistemas del prototipo actual. Los Sprints 10 y 11 preparan la primera entrega alineada; las reglas de los Sprints 12 y 13 están seleccionadas, pero su implementación espera al cierre y validación de los prerequisitos.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-033 | Definir la jornada, el descanso y los hitos de temperatura | P0 | Hecho | — | IDEA-001/002/008 seleccionadas: jornada de 12 minutos reales; acciones de compra, carga y avivado no adelantan el reloj; descanso permitido desde el minuto 2; al minuto 12 el día se cierra automáticamente sin bonificación. Hitos de 100/500/1.000 °C conceden una brasa cada uno, una sola vez y se conservan entre jornadas. |
| HOG-034 | Definir reinicios y progresión entre jornadas y runs | P0 | Hecho | HOG-033 | En el bucle alineado no hay reinicio de campaña ni prestigio. Hollín financia compras; dinero, mejoras y excedente de combustible persisten entre jornadas. Las brasas se ganan por hitos y se gastan en mejoras permanentes, que persisten. Prestigio pagado y reinicio por saturación quedan aplazados. El prototipo conserva sus reglas actuales durante la validación. |
| HOG-035 | Definir economía diaria, combustible y gestión de ceniza | P0 | Hecho | HOG-033 | La ceniza se vende automáticamente al cierre de jornada por hollín; se recibe combustible al inicio del día, se puede comprar más durante la jornada con hollín y el excedente se conserva. Se seleccionan combustibles básicos. No hay puntos de llama, límite de ceniza ni coste de recogida en el alcance inicial. Cantidades y precios quedan para balance de implementación. |
| HOG-036 | Seleccionar el alcance de la primera entrega alineada | P1 | Hecho | HOG-033–035 | `ROADMAP.md` delimita una hoguera y una nave con jornada/descanso, hitos, combustibles básicos, ceniza por hollín y suministro diario. IDEA-001/002/004/005/006/008 quedan seleccionadas para la primera entrega. Las ideas 003/007/009/010/011/012 se seleccionan para etapas posteriores en Sprints 12–13, con implementación condicionada al cierre de Sprints 10–11. |

Sprints 10 y 11 se seleccionan para implementar la primera entrega alineada. Las reglas de IDEA-003/007/009/010/011/012 y la progresión tardía de carbón y combustible líquido quedan seleccionadas para Sprints 12 y 13; su implementación no empieza hasta cerrar y validar los Sprints 10 y 11. Las demás ideas no seleccionadas siguen como candidatas y requieren una decisión posterior.

- **2026-11-02** — Sprint 9 cerrado tras aceptar el paquete de diseño: jornada de 12 minutos, descanso desde el minuto 2, cierre automático al minuto 12, hitos permanentes de temperatura con brasas, hollín como dinero, suministro diario acumulable y primera entrega de una sola hoguera sin prestigio, daño por calor ni límite de ceniza.

## Sprint 10 — Jornada, descanso y progresión

Estado: **Implementado · validar**. HOG-039 se mantiene sin peligro ni penalización, según el alcance seleccionado.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-037 | Implementar el ciclo de jornada y descanso | P0 | Implementado · validar | HOG-036 | Jornada de 12 minutos reales, descanso desde el minuto 2, cierre automático al minuto 12 sin penalización, persistencia del día y reloj visible en HUD. (IDEA-001) |
| HOG-038 | Añadir hitos de temperatura | P1 | Implementado · validar | HOG-036–037 | Los umbrales de 100/500/1.000 °C conceden una brasa única y persistente; el HUD muestra el siguiente hito. (IDEA-002) |
| HOG-039 | Confirmar que no hay daño ni penalización | P1 | Hecho | HOG-036–037 | En el alcance inicial, el calor no daña y el cierre automático no penaliza. (IDEA-008) |

## Sprint 11 — Economía diaria y combustibles

Estado: **Implementado · validar**. HOG-042 se reserva para Sprint 12; los tickets de este sprint cubren ceniza diaria, suministro y progresión de combustibles básicos.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-040 | Cerrar la jornada y liquidar ceniza | P0 | Implementado · validar | HOG-036–037 | La ceniza acumulada se vende por hollín al descansar o al cerrar el día; no se generan puntos de llama. (IDEA-005) |
| HOG-041 | Gestionar suministro y presupuesto diario de combustible | P0 | Implementado · validar | HOG-036–037 | Cada día entrega las cantidades base de combustibles ya desbloqueados; el excedente se conserva, la compra usa hollín y el HUD muestra existencias y tiempo restante. (IDEA-006) |
| HOG-043 | Incorporar la progresión de combustibles | P1 | Implementado · validar | HOG-036, HOG-041 | Combustibles básicos desbloqueados en secuencia: hojarasca y leña desde el día 1, tronco desde el día 2 y turba desde el día 3; la tienda, carga y automatización respetan los desbloqueos. (IDEA-004) |

## Sprint 12 — Crecimiento de la nave y automatización

Estado: **Implementado · validar**. Instalaciones, silo, recogida de ceniza y logística integradas; pendiente ejecutar el proyecto y validar regresión.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-042 | Ampliar capacidad y recoger ceniza | P1 | Implementado · validar | HOG-036, HOG-040 | El silo inicial admite 300 unidades; cada mejora añade 150, hasta tres mejoras. La ceniza que no cabe o no llega al silo pierde su valor; llenar el silo no detiene la hoguera ni reinicia la campaña. No se cobra por recogerla. (IDEA-007) |
| HOG-044 | Ampliar la nave mediante mejoras | P1 | Implementado · validar | HOG-036, HOG-037, HOG-041, HOG-042 | La jornada sigue en 12 minutos. El almacén admite 20 unidades y cada mejora añade 5, hasta tres; el silo sigue las reglas de HOG-042. Las mejoras de almacén, silo, taller y garaje cuestan 50 de hollín iniciales, con coste ×1,5 por nivel de cada mejora. Los cambios estructurales se reflejan visualmente y en la capacidad visible. La mejora del taller habilita viajes automáticos de vagoneta. (IDEA-003) |
| HOG-045 | Transportar ceniza con vagonetas | P2 | Implementado · validar | HOG-036, HOG-042, HOG-044 | Un botón despacha un viaje por una ruta fija entre la hoguera y el silo, con capacidad de hasta 50 unidades y 10 segundos de recorrido. La mejora del taller habilita viajes automáticos cuando hay ceniza y espacio libre. Al cerrar la jornada, la ceniza del silo se vende a 1 hollín por unidad y la no recogida se pierde. (IDEA-009) |
| HOG-046 | Añadir garaje y llamadas de camiones | P2 | Implementado · validar | HOG-036, HOG-041, HOG-044 | Un pedido cuesta 25 de hollín, tarda 60 segundos y entrega una unidad de cada combustible desbloqueado; solo puede haber uno pendiente. Cada mejora añade una unidad por combustible y reduce la espera 15 segundos, hasta un mínimo de 30. La espera no baja de ese mínimo; pedido y temporizador son visibles. (IDEA-010) |

## Sprint 13 — Combustión crítica y tecnología experimental

Estado: **Implementado · validar**. Combustibles tardíos, evento crítico y tecnologías integrados; pendiente ejecutar el proyecto y validar regresión.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-047 | Añadir combustiones críticas y explosiones | P2 | Implementado · validar | HOG-037, HOG-038, HOG-043, HOG-049 | Al añadir combustible líquido a una combustión que contiene carbón, con temperatura de al menos 100 °C, se hace una tirada oculta del 5%. La interfaz indica inestabilidad sin revelar el porcentaje. Si ocurre, suma 100 °C y cierra el día; se pierde la ceniza no depositada, pero se conservan hollín, combustible, mejoras, brasas e hitos. No hay daño físico ni reinicio de campaña. (IDEA-011) |
| HOG-048 | Desbloquear tecnología experimental avanzada | P2 | Implementado · validar | HOG-038, HOG-047 | En orden, 100/500/1.000 °C desbloquean inyección de gas, tritio y asistencia láser, pagando una brasa por etapa. Gas: 25 hollín por uso, +50% calor durante 10 s. Tritio: 25 hollín por unidad, 12 s al doble de calor base. Láser: 50 hollín por uso, +50% calor durante 10 s. Los estados y efectos se explican en el juego. (IDEA-012) |
| HOG-049 | Añadir carbón y combustible líquido | P1 | Implementado · validar | HOG-043 | Tras los combustibles básicos, carbón se desbloquea el día 4 y combustible líquido el día 5; cada uno usa sus datos de precio, calor, duración y suministro diario. Tienda, inventario, entregas y HUD respetan el desbloqueo. La mezcla carbón→combustible líquido puede satisfacer el requisito de HOG-047. (IDEA-004/011) |
| HOG-050 | Persistir instalaciones, logística y tecnología | P1 | Implementado · validar | HOG-042, HOG-044–049 | Una migración versionada conserva hollín, combustible, brasas, hitos y mejoras existentes, y guarda niveles de almacén/silo/taller, automatización, pedido de camión pendiente, estado de vagoneta y tecnologías desbloqueadas. Un guardado ausente o ilegible inicia una partida limpia sin estado parcial. |

- **2026-11-02** — Sprints 10 y 11 implementados para validación: jornadas y descanso, hitos persistentes, liquidación de ceniza, suministro diario acumulable y desbloqueos básicos por día. Sin ejecución de Godot; no marcar como Hecho hasta validar el proyecto y la regresión.

- **2026-11-02** — Sprints 12 y 13 implementados para validación: mejoras y capacidades de instalaciones, recogida y venta de ceniza por vagoneta, pedidos de camión, combustibles de días 4/5, combustión crítica, tecnologías experimentales y migración versionada del guardado. Godot no está disponible en el entorno; no marcar como Hecho hasta validar proyecto y regresión.

- **2026-11-02** — Tras Sprint 9 se seleccionan Sprints 10 y 11 en serie para implementar el bucle diario, los hitos, la venta de ceniza y los combustibles básicos. Los desbloqueos diarios siguen el orden hojarasca/leña, tronco y turba; Sprint 12 y 13 quedan como trabajo futuro sujeto al cierre y validación de sus prerequisitos.

- **2026-11-02** — Se seleccionan para contenido posterior las reglas de IDEA-003/007/009/010/011/012: mejoras de almacén y silo con hollín, transporte de ceniza, camiones de carga mixta, combustión crítica con pérdida limitada al día y tecnología experimental por hitos/brasas. HOG-049 añade carbón (día 4) y combustible líquido (día 5) como prerequisito de la mezcla crítica. Sprints 12–13 no se implementan hasta cerrar y validar 10–11.
