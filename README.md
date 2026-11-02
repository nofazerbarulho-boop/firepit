# HOGUERAS

Juego incremental 3D en Godot 4.7.2. Gestiona una hoguera en una nave industrial: prepara combustible, genera ceniza, la vende al final de la jornada y reinvierte el hollín en mejoras.

## Empezar a jugar

1. Abre `project.godot` con Godot 4.7.2.
2. Pulsa **F5** para iniciar `Scenes/main.tscn`.
3. Carga combustible, enciende la hoguera y sigue el temporizador de jornada en la pestaña **Hoguera**.

La jornada dura 4 minutos activos. Se puede descansar después de 2 minutos; si no, el día se cierra automáticamente. El juego guarda el tiempo restante y la pila de combustión, y congela el reloj cuando se cierra la aplicación.

## Bucle y controles

- **Cargar** añade combustible a la pila; el orden afecta a la calidad de la mezcla.
- **Encender** inicia la combustión. La temperatura genera ceniza, que se convierte en hollín al cierre de la jornada.
- **Combustible** permite comprar unidades con hollín. Se conservan las existencias y se recibe suministro al comenzar cada día.
- **Mejoras** aumenta la producción y permite gastar las brasas permanentes que conceden los hitos de 100, 500 y 1.000 °C.
- La UI incluye ajustes de volumen, contraste y tamaño de texto.

El juego usa una hoguera y los combustibles básicos de los días 1–3. Prestigio, segunda hoguera, progreso offline, instalaciones, automatización y combustibles tardíos no están disponibles en el flujo de Early Access.

El progreso se guarda en `user://hogueras_save.cfg`; audio, presentación y accesibilidad se guardan en `user://presentation.cfg`. Al pasar desde un guardado del prototipo, la campaña empieza limpia; el guardado anterior se conserva como `hogueras_save.cfg.legacy.bak` y los ajustes de presentación se mantienen.

## Exportar para Windows

El proyecto incluye el preset **Windows Desktop** en `export_presets.cfg`. Instala las plantillas de exportación de Godot 4.7.2 y elige **Project > Export > Windows Desktop > Export Project**. La salida está configurada en `build/Hogueras.exe`; distribuye el `.exe` junto al `.pck`.

La exportación en una instalación limpia y la prueba de rendimiento en un PC de referencia siguen pendientes de validación en Godot.

## Pruebas

Ejecuta `Tests/workday_acceptance.tscn` para comprobar los límites de la jornada, el suministro, las compras sin saldo o sin capacidad, las recompensas únicas por hitos y la reanudación de la combustión guardada. `Tests/sprint0_smoke.tscn` conserva regresiones de sistemas anteriores del prototipo.
