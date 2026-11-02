# HOGUERAS — Roadmap actual

Backlog vivo de trabajo pendiente. `ROADMAP_HISTORICO.md` conserva los tickets cerrados, el trabajo implementado pendiente de validación y el registro de decisiones. Al cerrar un ticket, se mueve su ficha y el resultado de validación al histórico; este archivo mantiene únicamente trabajo por hacer.

## Cómo usamos este archivo

- Cada ticket tiene ID estable, prioridad, estado, dependencias y criterio de aceptación.
- Estados: **Pendiente**, **En curso**, **Implementado · validar** y **Hecho**.
- No se marca **Hecho** hasta comprobar el criterio en Godot. Si el código está escrito pero falta probarlo, se usa **Implementado · validar**.
- Al terminar un ticket, registrar resultado y fecha en `ROADMAP_HISTORICO.md` y retirarlo de este archivo.
- El proyecto usa Godot 4.7.2 y construye su UI con controles nativos en `Scripts/Main.gd`; los ejemplos son GDScript aplicable al proyecto. HTML/CSS no se aplica directamente a esta interfaz.

## Dirección visual de la UI

### Concepto: terminal de fundición

Conservar la nave oscura, las vías y la iluminación cálida del juego; hacer que el HUD parezca una consola de operación industrial integrada en la escena. La UI debe priorizar la hoguera, mostrar los recursos de un vistazo y agrupar las acciones por intención.

| Uso | Color | Muestra |
|---|---|---|
| Fondo/panel | Carbón | `#17191A` |
| Panel elevado | Grafito | `#242525` |
| Divisores y texto secundario | Metal | `#77766F` |
| Acción activa y hollín | Ámbar | `#D88A36` |
| Brasas, hitos y recompensa | Ámbar claro | `#FFC56A` |
| Texto principal | Hueso | `#E4DED2` |

- Paneles translúcidos, con esquinas discretas, borde metálico fino y una marca ámbar para selección o prioridad.
- Tipografía sans legible para controles; cifras y etiquetas técnicas con una fuente condensada o monoespaciada si está disponible.
- El brillo se reserva para recompensa, fuego activo y acción principal. Mantener el contraste y el tamaño de texto configurables.
- Evitar cubrir el centro de la escena: el panel de control debe ser compacto y su contenido desplazable.

## Sprint 1 — HUD y lectura de recursos

**Objetivo:** reforzar la jerarquía del HUD existente sin repetir información ni ocultar la hoguera.

**Estado:** Implementado · validar.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-051 | Aplicar tema industrial a HUD y paneles | P1 | Implementado · validar | — | HUD, panel de control y controles comparten paleta, espaciado, bordes y estados legibles; contraste y tamaño de texto siguen funcionando. |
| HOG-052 | Jerarquizar contadores superiores | P1 | Implementado · validar | HOG-051 | Hollín y brasas se leen como indicadores separados con cifra destacada y etiqueta breve; no se solapan con los controles ni con la guía de teclas en resoluciones compatibles. |
| HOG-053 | Unificar feedback flotante de recursos | P2 | Implementado · validar | HOG-051 | Ganancias y recompensas muestran un popup breve, ascienden y se desvanecen; varias ganancias consecutivas no se amontonan de forma ilegible. |

### Ejemplo: estilo compartido de panel

```gdscript
func apply_industrial_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17191A")
	style.bg_color.a = 0.93
	style.border_color = Color("#75634E")
	style.border_color.a = 0.8
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
```

Aplicarlo después de crear `menu_panel` en `_build_hud()`:

```gdscript
apply_industrial_panel(menu_panel)
```

## Sprint 2 — Panel de control modular

**Objetivo:** convertir el flujo vertical de controles en secciones fáciles de recorrer.

**Estado:** Implementado · validar. Sprint 2 se ejecutó después de Sprint 1, respetando su dependencia de HOG-051.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-054 | Separar controles en pestañas funcionales | P1 | Implementado · validar | HOG-051 | Las acciones existentes se agrupan en Hoguera, Combustible y Mejoras; sus callbacks y estados siguen conectados y el panel no muestra todos los grupos a la vez. |
| HOG-055 | Ordenar información secundaria y avanzada | P2 | Implementado · validar | HOG-054 | Datos de jornada, automatización, instalaciones y tecnología quedan en secciones o pestañas secundarias; el contenido cabe mediante desplazamiento y conserva sus requisitos visibles. |
| HOG-056 | Ajustar panel a distintas resoluciones | P1 | Implementado · validar | HOG-054 | El panel conserva márgenes, ancho usable y accesibilidad al redimensionar la ventana; no tapa la hoguera más de lo necesario ni recorta acciones. |

### Ejemplo: contenedor de pestañas

```gdscript
var tabs := TabContainer.new()
tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
layout.add_child(tabs)

var fire_tab := VBoxContainer.new()
fire_tab.name = "Hoguera"
tabs.add_child(fire_tab)

var fuel_tab := VBoxContainer.new()
fuel_tab.name = "Combustible"
tabs.add_child(fuel_tab)

var upgrades_tab := VBoxContainer.new()
upgrades_tab.name = "Mejoras"
tabs.add_child(upgrades_tab)
```

Al construir el HUD, añadir cada control existente al contenedor correspondiente: estado y encendido a `fire_tab`; carga, compra e inventario a `fuel_tab`; mejoras y automatización a `upgrades_tab`. Mantener un `ScrollContainer` dentro de cada pestaña que pueda superar la altura disponible.

## Sprint 3 — Interacción y feedback de fuego

**Objetivo:** dar respuesta clara a hover, pulsación, carga de combustible y cambios de intensidad.

**Estado:** Implementado · validar.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-057 | Definir estados visuales de botones | P1 | Implementado · validar | HOG-051, HOG-054 | Acciones disponibles, bajo hover, pulsadas, activas y bloqueadas se distinguen con color/contraste y mantienen textos de requisito; no dependen solo del color. |
| HOG-058 | Añadir transiciones breves a acciones | P2 | Implementado · validar | HOG-057 | Hover y pulsación tienen transiciones sutiles y rápidas; la acción principal se reconoce sin efectos que distraigan o cambien el layout. |
| HOG-059 | Mostrar intensidad del fuego | P1 | Implementado · validar | HOG-051 | Una barra o medidor presenta calor/intensidad a partir del estado real de la hoguera y se actualiza sin saltos visuales; el valor numérico sigue accesible. |
| HOG-060 | Integrar feedback de carga, compra y avivado | P2 | Implementado · validar | HOG-053, HOG-057 | Cargar, comprar, encender y avivar confirman resultado con feedback inmediato y consistente; los errores y requisitos son distinguibles. |

### Ejemplo: pulso de acción

```gdscript
func pulse_button(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.04, 1.04), 0.07)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12)
```

### Ejemplo: medidor conectado a calor

```gdscript
var fire_intensity := ProgressBar.new()
fire_intensity.min_value = 0.0
fire_intensity.max_value = 1000.0
fire_intensity.show_percentage = false
fire_intensity.custom_minimum_size.y = 14.0
fire_tab.add_child(fire_intensity)

# En la actualización del HUD:
fire_intensity.value = clampf(fire.current_heat, 0.0, 1000.0)
```

El máximo de ejemplo debe alinearse con la escala real de `current_heat` y su presentación, no asumirse como límite de juego.

### Ejemplo: animación de popup existente

```gdscript
var tween := create_tween()
tween.set_parallel(true)
tween.tween_property(popup, "position:y", popup.position.y - 34.0, 0.65)
tween.tween_property(popup, "modulate:a", 0.0, 0.65)
tween.chain().tween_callback(popup.queue_free)
```

## Sprint 4 — Bucle de jornada para Early Access

**Estado:** Implementado · validar. El juego accesible sigue una sola hoguera, jornada activa de 4 minutos, descanso desde el minuto 2 y reloj congelado al cerrar la aplicación. Falta ejecutar la escena y la suite en Godot.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-061 | Aplicar el ciclo activo de 4 minutos | P0 | Implementado · validar | — | El descanso se habilita al segundo 120; el cierre automático ocurre al segundo 240; cerrar la app no hace avanzar el reloj. |
| HOG-062 | Liquidar ceniza y entregar combustible | P0 | Implementado · validar | HOG-061 | Todo el hollín generado como ceniza durante el día se vende una sola vez al cerrar; al iniciar el nuevo día se entrega stock de los combustibles ya desbloqueados. |
| HOG-063 | Mantener hitos únicos entre jornadas | P1 | Implementado · validar | HOG-061 | 100, 500 y 1.000 °C conceden una brasa cada uno y no vuelven a pagarse tras cargar la partida. |
| HOG-064 | Respaldar guardados del prototipo y persistir el fuego | P0 | Implementado · validar | HOG-061 | La migración a versión 6 crea copia `.legacy.bak` y comienza campaña limpia; se conservan ajustes de presentación y se restaura la pila, calor y tiempo de combustión guardados. |
| HOG-065 | Delimitar el flujo jugable de lanzamiento | P0 | Implementado · validar | HOG-061–064 | La UI ofrece una hoguera, combustibles hasta el día 3 y mejoras; prestigio, segunda estación, automatización, progreso offline y contenido tardío no aparecen como acciones disponibles. |
| HOG-066 | Hacer visible el estado de la jornada y agilizar la carga | P1 | Implementado · validar | HOG-061 | La pestaña Hoguera muestra el día, tiempo restante, ceniza y requisito de descanso; la pestaña Combustible permite cargar las existencias en el orden recomendado. El stock inicial cubre los 120 segundos mínimos antes del descanso. |

## Sprint 5 — Pulido y preparación de build

**Estado:** En curso. El pase de UI/escena está implementado para validar; perfilado, prueba prolongada, sesiones externas y exportación limpia siguen pendientes.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-067 | Reforzar la hoguera como foco visual | P1 | Implementado · validar | HOG-065 | Solo hay un hogar visible; llama, leña, materiales, luz y HUD comparten el acabado industrial carbón/ámbar y mantienen contraste legible. |
| HOG-068 | Perfil de rendimiento en PC Windows de referencia | P1 | Pendiente | HOG-067 | En 1080p el juego mantiene 60 FPS objetivo y no cae sostenidamente por debajo de 30 FPS durante el ciclo normal. |
| HOG-069 | Validar sesiones largas y guardados | P0 | Pendiente | HOG-064 | Una sesión de una hora no acumula errores o nodos sin límite; salir y volver conserva jornada y combustión. |
| HOG-070 | Validar exportación limpia de Windows | P0 | Pendiente | HOG-064, HOG-068 | La build arranca fuera del editor, guarda en el directorio de usuario y funciona con el preset Windows Desktop. |
| HOG-071 | Comprobar comprensión inicial del bucle | P1 | Pendiente | HOG-066 | Cinco personas fuera del equipo pueden iniciar la hoguera, encontrar la siguiente acción y explicar el descanso sin ayuda directa. |

## Registro de decisiones
- **2026-11-03:** Sprint 4 implementado para validar: reloj activo de 240 s, descanso desde 120 s, venta completa de ceniza, entrega al comenzar el siguiente día, migración de guardado versión 6 con copia de seguridad, restauración de la combustión y ocultación de sistemas fuera del alcance. Ajustado el suministro inicial a 120 s de combustión y añadido un botón para cargar todo el stock básico en orden. Añadida la escena `Tests/workday_acceptance.tscn`; falta ejecutarla en Godot.
- **2026-11-03:** el pase de UI prioriza temporizador, día y ceniza junto a la hoguera; el mundo muestra un solo hogar. El perfilado y la exportación limpia permanecen pendientes de validación en Windows.
- **2026-11-02:** Sprint 3 implementado para validar: estados normal/hover/pulsado/foco/bloqueado, pulso breve de botones, medidor suavizado de calor con escala visible hasta 1.000 °C y feedback inmediato de carga, compra, encendido y avivado. HOG-057–060 quedan **Implementado · validar** hasta revisar en Godot.
- **2026-11-02:** Sprints 1 y 2 implementados en serie en `Scripts/Main.gd`: tema industrial del HUD, tarjetas de hollín/brasas, popup común de recursos y panel con pestañas/scroll para Hoguera, Combustible y Mejoras; se añadió ajuste del panel y la guía al redimensionar. Pendiente validar visualmente en Godot; tickets HOG-051–056 permanecen **Implementado · validar**.

- **2026-11-02:** se crea este roadmap para mantener trabajo pendiente separado del histórico. Las propuestas de UI se organizan en tres sprints; no se consideran implementadas por estar descritas aquí.
- **2026-11-02:** dirección visual propuesta: terminal industrial de carbón y ámbar, con brillo reservado para acciones y recompensas. Los ejemplos son GDScript porque el proyecto actual está hecho en Godot.
