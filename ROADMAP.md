# HOGUERAS — Visión e ideas

Documento vivo para definir el diseño futuro del juego. Las ideas aquí reunidas todavía no son compromisos de implementación ni tickets de sprint. `ROADMAP_HISTORICO.md` conserva el backlog anterior del prototipo y los sprints nuevos basados en este roadmap; `Ideas.xlsx` permanece como fuente original del concepto.

## Cómo usaremos este roadmap

- Refinaremos las ideas por áreas, comenzando por **Bucle y progresión**.
- Las nuevas propuestas se registran en fichas breves con ID estable `IDEA-001`, `IDEA-002` y siguientes.
- Estados: **Borrador**, **Definida**, **Seleccionada** o **Descartada**.
- Todas las ideas quedan mapeadas a sprints tentativos en `ROADMAP_HISTORICO.md`; una idea solo pasa a implementación después de discutirla y seleccionarla.
- Los conflictos del material de origen permanecen como alternativas hasta tomar una decisión.

## Visión acordada

**Nombre provisional:** HOGUERAS. `FlareUp` aparece como nombre alternativo en el documento original; el nombre final sigue abierto.

**Fantasía central:** Ramiro, fascinado desde niño por el Sol, compra una nave industrial en las afueras y se propone alcanzar con su hoguera la temperatura de nuestra estrella.

**Dirección visual:** estética toon. La escena de referencia muestra una nave industrial amplia, una hoguera central rodeada de piedras, vías curvas que transportan combustible y medidores destacados de temperatura y recursos. La imagen fija la composición de referencia; la adaptación del prototipo queda para una etapa futura.

**Espacios principales:**

- **Nave de trabajo:** gran espacio inicialmente vacío que crece alrededor de la hoguera, el combustible, las vías y los sistemas de producción.
- **Habitación:** espacio más humilde para dormir y comprar mejoras. El descanso conecta con el cierre de la jornada y la preparación del día siguiente.

**Objetivo a largo plazo:** alcanzar hitos cada vez mayores de temperatura hasta llegar a la temperatura del Sol.

## Ideas por área

### Bucle y progresión

#### IDEA-001 — Jornada de trabajo y descanso

- **Fantasía:** gestionar una jornada junto a la hoguera y decidir cuándo parar para dormir.
- **Regla seleccionada:** la jornada dura 12 minutos reales. Comprar, cargar combustible y avivar no adelanta el reloj. Se puede descansar después de 2 minutos; descansar liquida la ceniza y comienza el día siguiente.
- **Si no se descansa:** al acabar los 12 minutos, el día se cierra automáticamente y continúa el siguiente, sin bonificación de descanso.
- **Persistencia diaria:** el dinero, las mejoras y el combustible sobrante se conservan; la ceniza se vende al cierre.
- **Estado:** Seleccionada para la primera entrega alineada.

#### IDEA-002 — Hitos de temperatura solar

- **Fantasía:** acercarse paso a paso a una escala de calor imposible.
- **Regla seleccionada:** los hitos son 100 °C, 500 °C y 1.000 °C. Cada uno concede 1 brasa una sola vez y queda registrado permanentemente entre jornadas.
- **Estado:** Seleccionada para la primera entrega alineada.

#### IDEA-003 — Crecimiento de la nave y de la operación

- **Fantasía:** convertir una nave vacía en una instalación dedicada a una hoguera cada vez mayor.
- **Regla seleccionada para una etapa posterior:** las mejoras pagadas con hollín amplían el almacén, el silo de ceniza y el taller. La jornada se mantiene fija en 12 minutos.
- **Estado:** Seleccionada para Sprint 12, después de la primera entrega alineada.

### Combustibles y economía

#### IDEA-004 — Escalera de combustibles

- **Fantasía:** pasar de encender con restos modestos a dominar combustibles industriales y experimentales.
- **Regla seleccionada:** los combustibles básicos se desbloquean por día: hojarasca y leña el día 1, tronco el día 2 y turba el día 3. Para contenido posterior, se añade carbón el día 4 y combustible líquido el día 5.
- **Estado:** Seleccionada para la primera entrega alineada en su tramo básico; la progresión de carbón y combustible líquido queda seleccionada para Sprint 13.

#### IDEA-005 — Ceniza, dinero y presupuesto diario

- **Fantasía:** transformar lo quemado en un ingreso tangible al final de cada jornada.
- **Regla seleccionada:** la ceniza se vende automáticamente al cerrar cada jornada y entrega hollín, que funciona como dinero de la jornada para compras y mejoras. No hay puntos de llama en la primera entrega.
- **Estado:** Seleccionada para la primera entrega alineada.

#### IDEA-006 — Suministro diario de combustible

- **Fantasía:** gestionar una entrega industrial limitada y decidir cómo aprovecharla.
- **Regla seleccionada:** al comenzar cada jornada se recibe una asignación de combustible; el excedente se conserva. Se puede comprar combustible adicional con hollín durante la jornada. Para la primera entrega, hojarasca y leña están disponibles desde el día 1, tronco desde el día 2 y turba desde el día 3; cada entrega usa el stock base definido en los datos del combustible. La progresión posterior añadirá carbón desde el día 4 y combustible líquido desde el día 5 para las combustiones críticas.
- **Estado:** Seleccionada para la primera entrega alineada en su tramo básico; carbón y combustible líquido quedan seleccionados para una etapa posterior (Sprint 13).

### Riesgos y límites

#### IDEA-007 — Capacidad de ceniza y coste de recogida

- **Fantasía:** mantener la operación limpia antes de que el residuo ahogue el taller.
- **Regla seleccionada para una etapa posterior:** el silo tiene capacidad limitada y puede ampliarse. La ceniza que no cabe o que no llega al silo antes del cierre pierde su valor; llenar el silo no detiene la hoguera ni reinicia la campaña.
- **Estado:** Seleccionada para Sprint 12. Queda fuera de la primera entrega alineada.

#### IDEA-008 — Calor peligroso y hora de dormir

- **Fantasía:** empujar la jornada más allá de lo prudente y arriesgarse a las consecuencias.
- **Regla seleccionada:** el calor no daña a Ramiro en la primera entrega. No dormir a tiempo cierra automáticamente el día al terminar los 12 minutos, sin bonificación de descanso; el progreso y los recursos se conservan.
- **Estado:** Seleccionada para la primera entrega alineada, con riesgo físico aplazado.

### Automatización y mundo

#### IDEA-009 — Vagonetas para la ceniza

- **Fantasía:** observar cómo la fábrica empieza a trabajar por sí sola.
- **Regla seleccionada para una etapa posterior:** el jugador despacha la vagoneta con un botón. Un viaje lleva hasta 50 unidades de ceniza y tarda 10 segundos. Una mejora del taller habilita viajes automáticos cuando hay ceniza y espacio en el silo.
- **Estado:** Seleccionada para Sprint 12. Queda fuera de la primera entrega alineada.

#### IDEA-010 — Garaje y camiones de suministro

- **Fantasía:** llamar a la puerta del garaje para recibir combustible en la nave.
- **Regla seleccionada para una etapa posterior:** un pedido cuesta 25 de hollín, llega en 60 segundos y entrega una unidad de cada combustible desbloqueado. Solo puede haber un pedido pendiente. Cada mejora del garaje añade una unidad por combustible y reduce la espera en 15 segundos, hasta un mínimo de 30.
- **Estado:** Seleccionada para Sprint 12. Queda fuera de la primera entrega alineada.

### Hitos y contenido tardío

#### IDEA-011 — Combustiones críticas y explosiones

- **Fantasía:** provocar una subida espectacular de temperatura al añadir el combustible adecuado.
- **Regla seleccionada para contenido tardío:** al añadir combustible líquido a una combustión que contiene carbón, con temperatura de al menos 100 °C, se realiza una tirada oculta del 5%. La interfaz comunica señales de inestabilidad sin revelar el porcentaje. Si ocurre, la temperatura sube 100 °C y el día termina; se pierde la ceniza que no esté en el silo, pero se conservan hollín disponible, combustible, mejoras, brasas e hitos. No hay daño a Ramiro ni reinicio de campaña.
- **Estado:** Seleccionada para Sprint 13, después de la primera entrega alineada.

#### IDEA-012 — Tecnología experimental

- **Fantasía:** llevar el experimento hacia una ciencia ficción industrial cada vez más extrema.
- **Reglas seleccionadas para contenido tardío:** las tecnologías se desbloquean en orden al alcanzar 100, 500 y 1.000 °C, pagando una brasa por etapa. La inyección de gas cuesta 25 de hollín por uso y aumenta el calor un 50% durante 10 segundos; el tritio cuesta 25 por unidad y arde 12 segundos al doble del calor base; la asistencia láser cuesta 50 por uso y aumenta el calor un 50% durante 10 segundos.
- **Estado:** Seleccionada para Sprint 13, después de la primera entrega alineada.

### Reglas de instalaciones y contenido tardío (Sprints 12–13)

- La jornada conserva su duración fija de 12 minutos. Las ampliaciones se pagan con hollín: el almacén parte con capacidad total de 20 unidades y cada mejora añade 5, hasta tres mejoras; el silo parte con capacidad de 300 unidades de ceniza y cada mejora añade 150, hasta tres mejoras. Cada mejora cuesta 50 de hollín, con coste ×1,5 por nivel.
- El hollín pendiente de liquidación se representa como ceniza. La ceniza depositada en el silo se vende al cierre a razón de 1 hollín por unidad. La ceniza aún sin recoger y cualquier excedente que no quepa en el silo pierden su valor al cerrar el día.
- Las mejoras del taller automatizan viajes de vagoneta; las mejoras del garaje amplían las cargas y reducen la espera de los camiones. Los pedidos pendientes y el estado de instalaciones deberán persistir en el guardado.
- Estas reglas son contenido posterior a la primera entrega: no activan prestigio, reinicio de campaña ni daño físico por calor. La explosión solo termina la jornada y hace perder la ceniza no depositada.
- Las cantidades son valores iniciales de balance; se pueden ajustar mediante pruebas sin alterar estas reglas.

## Decisiones de diseño seleccionadas

### Reinicios y moneda permanente

El prestigio pagado y el reinicio por saturación quedan aplazados y no forman parte del bucle alineado inicial. La primera entrega no introduce reinicio de campaña: se avanza de jornada en jornada y se conserva el dinero, las mejoras y el combustible sobrante. Las brasas se obtienen exclusivamente al alcanzar los tres hitos de temperatura (una por hito) y sirven para comprar mejoras permanentes. El código heredado de prestigio puede permanecer para pruebas internas, pero no forma parte del ciclo accesible implementado en los Sprints 10 y 11.

### Alcance de la primera entrega alineada

Incluye una hoguera en una nave, jornadas de 12 minutos, descanso desde el minuto 2, liquidación diaria de ceniza, asignación diaria de combustible con excedente acumulable, combustibles básicos, mejoras pagadas con hollín e hitos de 100/500/1.000 °C que otorgan brasas. No incluye daño por calor, límite/recogida de ceniza, puntos de llama, prestigio, biomas, segunda hoguera, vagonetas, camiones, explosiones ni tecnología experimental. Los sistemas aplazados seleccionados se implementarán en etapas posteriores según el backlog.

## Decisiones abiertas

### Reinicio y moneda permanente

El documento fuente plantea dos enfoques aplazados para una etapa futura; no forman parte de la primera entrega alineada:

1. **Prestigio pagado:** pagar una cantidad de dinero que aumenta en cada reinicio para recibir ventajas permanentes.
2. **Reinicio por saturación:** la ceniza u otros residuos se acumulan; no poder pagar su recogida puede forzar el reinicio.

También quedan aplazadas dos formas alternativas de obtener la moneda permanente, sustituidas en el alcance inicial por los hitos de temperatura:

- **Por actividad del fuego:** ganar chispas continuamente mientras arde, con mayor ritmo a temperaturas más altas.
- **Por combustible consumido:** obtener la moneda al quemar la cuota o los recursos diarios.

El documento original usa tanto **chispas** como **brasas**. Se selecciona **brasas** para los hitos de temperatura; las alternativas originales se conservan como referencia, no como reglas activas.

## Estado del prototipo actual

El prototipo jugable existente conserva su función de validar mecánicas. Sus sistemas actuales —combustibles, hollín, brasas, prestigio, automatización y dos hogueras— no se consideran todavía la definición final del juego. Las ideas de este documento describen la dirección que iremos decidiendo; no implican reemplazar de inmediato lo que ya se puede jugar.

## Registro de decisiones

- **2026-11-02:** el nuevo roadmap de diseño queda separado del historial de sprints.
- **2026-11-02:** estética toon y nave industrial de la imagen compartida como dirección visual acordada.
- **2026-11-02:** la temperatura del Sol queda como aspiración a largo plazo; las reglas de jornadas, economía y reinicio de la primera entrega se concretan en Sprint 9.
- **2026-11-02:** Sprint 9 selecciona la jornada de 12 minutos, descanso desde el minuto 2, cierre automático sin bonificación, hitos de 100/500/1.000 °C con una brasa cada uno, liquidación de ceniza por hollín y asignación diaria de combustible acumulable. La primera entrega alineada excluye prestigio, peligro físico, límite de ceniza y sistemas tardíos.
- **2026-11-02:** se seleccionan para etapas posteriores IDEA-003/007/009/010/011/012: mejoras de instalaciones, ceniza limitada con vagonetas, camiones, combustión crítica de carbón y combustible líquido, y tecnología experimental desbloqueada por hitos y brasas.

- **2026-11-02:** Sprints 10 y 11 implementan en serie la jornada, los hitos, la liquidación diaria y la progresión de combustibles básicos descrita en este documento.
