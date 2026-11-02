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
- No se marcan pruebas como ejecutadas por el mero hecho de añadir instrumentación; el primer log se generará al correr la escena de regresión en Godot.

## Sprint 8 — Metaprogresion

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptacion |
|---|---|---:|---|---|---|
| HOG-032 | Separar el arbol permanente en una pantalla de mejoras | P1 | Implementado · validar | HOG-014–017 | El juego ofrece un menu propio con dos ramas visuales, nodos conectados, costes, prerequisitos, bloqueos y compra persistente; se puede volver al juego sin perder estado. |

- 2026-11-02 — HOG-032 implementado: menu de mejoras permanente separado del HUD, dos ramas de nodos con conectores y estado de compra, tema visual de carbon y brasa.
