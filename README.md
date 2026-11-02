# HOGUERAS

Prototipo 3D en Godot 4.7.2. El ciclo principal consiste en preparar la mezcla, encender una o ambas hogueras, invertir hollín en mejoras y obtener brasas al prestigiar.

## Empezar a jugar

1. Abre `project.godot` con Godot 4.7.2.
2. Pulsa **F6** para ejecutar la escena abierta o **F5** para iniciar `Scenes/main.tscn`.
3. Usa el panel desplazable de la izquierda para cargar combustible, encender, comprar y mejorar. El HUD muestra el calor, la producción y el progreso a la siguiente brasa.

El progreso de juego se guarda en `user://hogueras_save.cfg`; presentación y accesibilidad se guardan en `user://presentation.cfg`. Los datos viven fuera de la carpeta del proyecto, en el directorio de usuario que Godot reserva para la aplicación.

## Ciclo y controles

- **Cargar** añade una unidad a la pila en el orden elegido. La mezcla afecta a la calidad.
- **Encender** inicia la pila; el calor genera hollín. Si el fuego se apaga, el calor residual se enfría.
- **Tienda** compra combustible con hollín. Las entregas periódicas reponen el almacén hasta 99 unidades por tipo.
- **Mejoras** aumentan producción. Las ramas de brasas persisten entre runs.
- **Prestigio** reinicia la economía temporal y entrega una brasa por cada 100 de hollín generado.
- **Hoguera II** tiene almacén y mejora local; la automatización se desbloquea y configura por separado.
- Las opciones de tiers, skins, volumen, contraste y tamaño de texto están en **Mundo y entregas**.

El progreso offline estima la producción y está limitado a ocho horas. Revisa el resumen al volver; el valor se calcula con la tasa media estimada del combustible disponible al guardar.

## Exportar para Windows

El proyecto incluye `export_presets.cfg` con el preset **Windows Desktop**. En Godot, instala las plantillas de exportación de la misma versión desde **Editor > Manage Export Templates** y elige **Project > Export > Windows Desktop > Export Project**. La salida está configurada en `build/Hogueras.exe`; el preset genera también el archivo `.pck` junto al ejecutable. Mantén ambos archivos en la misma carpeta al distribuir.

Para exportar en limpio, abre el proyecto, espera a que termine la importación, ejecuta la escena principal y luego exporta. Prueba la carpeta exportada en una máquina sin Godot y confirma que guarda progreso en el directorio de usuario. Esta comprobación de distribución sigue pendiente.

## Límites conocidos del prototipo

- El cálculo offline es aproximado y no simula cada transición de fuego.
- Los recursos y costes son valores de prototipo; hacen falta pruebas de runs cortas y largas para cerrar el balance.
- La versión se considera validada solo después de abrirla y jugarla en Godot y comprobar la exportación en una instalación limpia.

## Logs de pruebas

La regresión automatizada `Tests/sprint0_smoke.tscn` crea un log nuevo en cada ejecución en `Tests/Logs/`. Cada comprobación registra hora, resultado y descripción; el archivo termina con un resumen de aprobadas y fallidas. La ruta absoluta aparece también en la consola de Godot.
