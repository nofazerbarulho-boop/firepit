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

**Estado:** Pendiente.

| ID | Ticket | Prioridad | Estado | Dependencias | Criterio de aceptación |
|---|---|---:|---|---|---|
| HOG-057 | Definir estados visuales de botones | P1 | Pendiente | HOG-051, HOG-054 | Acciones disponibles, bajo hover, pulsadas, activas y bloqueadas se distinguen con color/contraste y mantienen textos de requisito; no dependen solo del color. |
| HOG-058 | Añadir transiciones breves a acciones | P2 | Pendiente | HOG-057 | Hover y pulsación tienen transiciones sutiles y rápidas; la acción principal se reconoce sin efectos que distraigan o cambien el layout. |
| HOG-059 | Mostrar intensidad del fuego | P1 | Pendiente | HOG-051 | Una barra o medidor presenta calor/intensidad a partir del estado real de la hoguera y se actualiza sin saltos visuales; el valor numérico sigue accesible. |
| HOG-060 | Integrar feedback de carga, compra y avivado | P2 | Pendiente | HOG-053, HOG-057 | Cargar, comprar, encender y avivar confirman resultado con feedback inmediato y consistente; los errores y requisitos son distinguibles. |

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
fire_intensity.max_value = 100.0
fire_intensity.show_percentage = false
fire_intensity.custom_minimum_size.y = 14.0
fire_tab.add_child(fire_intensity)

# En la actualización del HUD:
fire_intensity.value = clampf(fire.current_heat, 0.0, 100.0)
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

## Registro de decisiones
- **2026-11-02:** Sprints 1 y 2 implementados en serie en `Scripts/Main.gd`: tema industrial del HUD, tarjetas de hollín/brasas, popup común de recursos y panel con pestañas/scroll para Hoguera, Combustible y Mejoras; se añadió ajuste del panel y la guía al redimensionar. Pendiente validar visualmente en Godot; tickets HOG-051–056 permanecen **Implementado · validar**.

- **2026-11-02:** se crea este roadmap para mantener trabajo pendiente separado del histórico. Las propuestas de UI se organizan en tres sprints; no se consideran implementadas por estar descritas aquí.
- **2026-11-02:** dirección visual propuesta: terminal industrial de carbón y ámbar, con brillo reservado para acciones y recompensas. Los ejemplos son GDScript porque el proyecto actual está hecho en Godot.
