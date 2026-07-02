# Changelog

All notable changes to this project will be documented in this file.

## [1.5.3] - 2026-07-02

### Changed
- **Interacción de Ventanas (Toplevel)**: Habilitada la propiedad nativa de Blizzard `SetToplevel(true)` en las ventanas de Asignaciones (`Grid`), Sub-Asignación Individual (`SubFrame`) y Reporte de Faltantes (`ReportFrame`). Esto permite que al hacer clic en cualquiera de ellas, se traiga dinámicamente al frente de la pantalla, evitando colisiones visuales y superposiciones molestas.

## [1.5.2] - 2026-07-02

### Fixed
- **Robustez de Frames (`attempt to index field 'buttons'`)**: Corregida la inicialización de los botones individuales en el sub-panel para garantizar que se creen y mapeen de forma segura, incluso si las filas principales persistían en memoria de versiones anteriores tras un `/reload`.

## [1.5.1] - 2026-07-02

### Added
- **Guía de Ayuda Rápida (`Grid.helpBtn`)**: Añadido un botón dorado minimalista `"?"` en la barra superior al lado del botón de cerrar. Al pasar el cursor, muestra una guía de controles estructurada e intuitiva.
- **Instructivos de Descubrimiento de UX**: Enriquecidos los tooltips de los encabezados de columna (`Gue`, `Pí`, etc.) para listar dinámicamente los miembros de la raid y mostrar la instrucción explícita `"Clic Derecho: Abrir Asignación Individual"`.

## [1.5.0] - 2026-07-02

### Changed
- **Rediseño Visual Premium (Estilo Minimalista Flat)**:
  - Removidos por completo los marcos metálicos rústicos y dorados de Blizzard (`BasicFrameTemplateWithInset`) en la ventana principal (`Grid`), el panel de sub-asignación (`SubFrame`) y la ventana de reporte (`RaidBuffetReportFrame`).
  - Implementado un diseño plano y moderno mediante `BackdropTemplate` con bordes sólidos de **1 píxel** y fondos gris mate semi-transparentes (`RGBA: 15, 15, 15, 0.94`).
  - Añadida una barra de cabecera superior y botón de cerrar ("X") minimalistas y limpios de color gris oscuro y dorado suave.
  - Ocultas visualmente las barras de scroll nativas de Blizzard en los contenedores de scroll para un acabado 100% plano, conservando el scroll táctil de rueda de ratón.
  - Rediseñados los botones de control inferiores (en la ventana principal y del reporte) para remover la textura roja clásica, reemplazándola por botones planos oscuros con bordes dorados suaves que se iluminan al pasar el ratón.
- **Efectos de Brillo en Hover (Glow)**:
  - Las celdas de buffs de la grilla principal e individual ahora tienen un contorno plateado fino y reaccionan dinámicamente: al pasar el ratón (`OnEnter`), su borde experimenta un efecto de brillo (Glow) dorado suave para dar feedback visual premium al instante.

### Added
- **Refinamiento de UX e Inteligencia de Ciclado**:
  - **Filtro de Viabilidad de Clase (`GetNextViableSpell`)**: Ciclado de clic izquierdo inteligente por columna de clase que descarta automáticamente buffs incompatibles para evitar atascamientos (ej: Guerreros/Pícaros con Sabiduría, Magos con Santuario).
  - **Atajo de Clic Derecho (Borrado Masivo)**: Shift + Clic Derecho sobre cualquier celda de la fila de un paladín limpia al instante todas sus asignaciones asignadas en el grid.
  - **Sub-Asignación Individual y Ejes**: Añadida la opción `"Ninguno (No bufar)"` al menú contextual, soporte de Clic Derecho para limpiar asignaciones individuales a "Heredar", y agregadas etiquetas visuales estáticas `"Caster (Bufa)"` y `"Objetivos (Reciben)"`.
  - **Autorefresco del Reporte**: Registrados eventos `UNIT_AURA` y `GROUP_ROSTER_UPDATE` para actualizar el reporte de faltantes en tiempo real sin requerir interacción manual.

## [1.4.0] - 2026-07-01

### Added
- **Asignación Ultra-Rápida con Rueda de Ratón (Scroll / Mouse Wheel)**:
  - Implementado el soporte para cambiar asignaciones deslizando la rueda del ratón sobre cualquier celda de buff.
  - **Grilla Principal**: Rodar el scroll arriba/abajo cicla de forma instantánea entre los buffs superiores de la clase caster, incluyendo la opción de limpiar la asignación (vacío).
  - **Sub-Asignación Individual**: Rodar el scroll sobre el buff de un jugador cicla dinámicamente las bendiciones pequeñas del paladín. Para el paladín local, se filtran en tiempo real solo las bendiciones conocidas en su libro de hechizos, e incluye la opción "Heredar clase" (vacío) para una limpieza instantánea.

## [1.3.4] - 2026-07-01

### Changed
- **Consistencia Visual en Sub-Asignaciones (Ejes Invertidos)**: Se invirtieron las dimensiones del panel flotante `RaidBuffetSubAssignFrame` para lograr consistencia visual total con la ventana principal. Ahora, **a la izquierda (filas)** se listan siempre los Paladines que deben bufar (casters) pintados en rosa, y **arriba (columnas)** se listan los jugadores individuales de la clase destino que recibirán el buff (objetivos) coloreados en base a su clase de personaje. Al pasar el ratón por encima de los nombres abreviados de las columnas superiores, un tooltip inteligente desplegará su nombre completo y su rol (ej: Tanque Principal).

## [1.3.3] - 2026-06-30

### Changed
- **Rediseño del Pie de Página (Evitar Solapamientos)**: Ensanchado el ancho del panel principal `Grid` de 460px a 520px y redistribuidas las coordenadas del pie de página (`showAllCheck`, `reportBtn`, `delegateContainer` y Auto-Cast). Esto proporciona un espacio horizontal holgado que elimina cualquier colisión o amontonamiento visual entre la caja del Co-Asignador y el botón de Auto-Cast.
- **Optimización del Menú Contextual de Sub-Asignaciones**: Aumentado el ancho del menú contextual de 120px a 160px y el tamaño de sus botones a 150x20px con un espaciado vertical homogéneo de 20px. Esto garantiza que las cadenas de texto largas (como `"Bendición de sabiduría"` o `"Bendición de salvación"`) quepan holgadamente dentro del panel sin salirse por los bordes ni superponerse verticalmente.

## [1.3.2] - 2026-06-30

### Fixed
- **Detección de Buffs con Múltiples Rangos**: Corregido el problema donde las bendiciones que disponen de rangos progresivos (como Poderío, Sabiduría, Luz y Santuario) no aparecían en el menú de sub-asignación individual del paladín local. Dado que la API `IsSpellKnown` de Blizzard exige el SpellID del rango exacto aprendido, se implementó un escáner recursivo por nombre de hechizo localizado en el libro de hechizos del personaje local, detectando correctamente la presencia del hechizo base independientemente del rango máximo aprendido.

## [1.3.1] - 2026-06-30

### Fixed
- **Error Lua en Sub-Asignaciones**: Solucionado el error `attempt to index global 'Scanner' (a nil value)` en `UI/Grid.lua` que ocurría al hacer clic derecho en las cabeceras para desplegar el panel flotante interactivo de sub-asignación individual, importando localmente el módulo `Scanner` en la cabecera del archivo de UI.

## [1.3.0] - 2026-06-30

### Added
- **Asignaciones Individuales (Excepciones por Jugador)**: Implementado el panel flotante interactivo `RaidBuffetSubAssignFrame` que se despliega al hacer **Clic Derecho** sobre los encabezados de columna abreviados de clase/grupo (ej: `Cha`, `Gue`, `G1`). Permite asignar de forma manual y explícita bendiciones individuales pequeñas (Poderío, Sabiduría, Reyes, Santuario, Luz, o Ninguno) a jugadores concretos de la raid (ej: para solventar chamanes melee vs chamanes caster/healer).
- **Control de Seguridad de Tanques con Susurro Automático**:
  - Detección reactiva de Tanques Principales (`MAINTANK`) que conserven el buff de *Bendición de Salvación* activa.
  - El addon envía automáticamente un susurro de alerta al tanque (`[RaidBuffet]: Eres Tanque Principal y tienes activa la Bendición de Salvación. Por favor, cancélala (/cancelaura Bendición de salvación)`) con un temporizador de cooldown interno de 60 segundos por tanque para evitar spam.
- **Sincronización P2P Avanzada**: Actualizado el canal de red para propagar y sincronizar las asignaciones individuales por nombre de jugador de manera síncrona en toda la raid.
- **Visualizador de Ayuda de No-Colisión**: En el menú de sub-asignación individual, se resaltan en color verde claro con un asterisco `*` las bendiciones pequeñas que están "libres de colisión" (cuyas versiones superiores correspondientes no están siendo asignadas por ningún paladín de la raid a esa clase), guiando al asignador de forma inteligente.

### Changed
- **Desactivado Cálculo Automático de Tanques**: Removida la lógica automática anterior que forzaba bendiciones alternativas de forma rígida en tanques con Salvación. Ahora el motor de Auto-Cast respetará de forma transparente y síncrona tanto las bendiciones grandes generales de clase como las pequeñas individuales configuradas manualmente en el nuevo panel.

## [1.2.1] - 2026-06-30

### Fixed
- **Error Lua al abrir Reporte de Faltantes**: Corregido el error de WoW `attempt to index field 'iconCaster' (a nil value)` en `UI/Report.lua` que ocurría al reabrir la ventana de reporte cuando el grupo pasaba del estado "todos buffeados" a tener buffs faltantes. Se implementó un elemento de texto de estado dedicado en la ventana en lugar de reutilizar celdas de datos dinámicas.

## [1.2.0] - 2026-06-30

### Added
- **Asignación Rápida con Shift-Clic (Paladín)**: Implementada la propagación automática inteligente de un buff asignado a todas las clases viables haciendo Shift-Clic en cualquier celda de paladín (ej. propagar Poderío automáticamente a Guerreros, Pícaros, Cazadores, Druidas, Chamanes y Paladines, dejando vacíos a los casters).
- **Control Inteligente de Salvación en Tanques Principales**: Detección dinámica de personajes marcados con el rol de **Tanque Principal** (`MAINTANK`) mediante la API oficial de Blizzard. El addon permite bufar primero a toda la clase con Salvación Superior y seguidamente el Auto-Cast cambia para sugerir lanzar una bendición pequeña individual alternativa (Santuario, Reyes, Poderío, Sabiduría o Luz) para pisar y eliminar su Salvación. Si no hay alternativas aprendidas o disponibles que no colisionen, alerta sutilmente en el chat local y reporte.
- **Grupos Dinámicos en TBC**: Ocultación automática de columnas de subgrupos no activos en la banda (ej. limitándose a los subgrupos 1 a 5 reales en raids de 25 personas), optimizando el espacio visual de la interfaz.
- **Delegación de Asignaciones**: El Raid Leader puede delegar de manera explícita la edición de la grilla en un ayudante (Co-Asignador) escribiendo su nombre en una casilla interactiva. Se sincroniza por red P2P (`RBUFFET`) y bloquea el control de asignaciones al resto de la banda para evitar sobrescrituras accidentales.
- **Botón de Auto-Cast Flotante Independiente**: Se creó un botón seguro flotante en pantalla (`RaidBuffetFloatCastBtn`) arrastrable (Shift+Arrastrar) que funciona de manera síncrona con el Auto-Cast maestro. Incluye configuraciones de visibilidad: siempre visible o únicamente cuando falten buffs por colocar.

### Fixed
- **Falsos Positivos de Tanques en Tooltip y Grilla**: Corregido un comportamiento particular de la API de Blizzard `GetPartyAssignment` (que devuelve el nombre del Main Tank general de la raid para unidades no consultadas en raids con personajes desconectados) añadiendo una validación que compara que el nombre devuelto coincida exactamente con la unidad consultada.
- **Solapamiento Visual Inferior**: Ajustadas las coordenadas X de forma absoluta en el pie de página de `/rb` para evitar el solapamiento entre "Mostrar todas las clases", el botón "Reporte" y el editBox "Co-Asig".
- **Autocompletado de Co-Asignador**: Añadido un script en tiempo real en la casilla de edición que autocompleta con los nombres de los asistentes o líder de la raid actual para evitar errores por tildes o caracteres especiales.
- **Traducción de Grupo en Tooltip**: Corregido el título del tooltip de grupos que mostraba `"GROUP_X"` en vez de `"Grupo X"`.

## [1.1.1] - 2026-06-30

### Fixed
- **Error de Tabla Nil en Opciones**: Corregido un fallo crítico al abrir el panel de opciones de la interfaz nativo de Blizzard (`bad argument #1 to 'ipairs' (table expected, got nil)`) al importar correctamente la variable local `Constants` en [Options.lua](file:///d:/BLIZZARD/World%20of%20Warcraft/_anniversary_/Interface/AddOns/RaidBuffet/UI/Options.lua).
- **Códigos de Escape de Chat Inválidos**: Corregido el fallo de Blizzard en `SendChatMessage` (`Invalid escape code in chat message`) al eliminar el uso del separador pipe (`|`) en el anuncio de asignaciones, reemplazándolo por comas (`", "`). En WoW, el pipe es un carácter de escape protegido y su uso público genera bloqueos seguros.
- **Exceso de Límite de Longitud de Chat (Límite 255)**: Corregida la desconexión por exceso de caracteres de chat (`Chat message limits exceeded`). 
  1. Se implementó una función de fragmentación inteligente (`SendChatMessageSafe`) que divide de forma segura líneas de más de 240 caracteres usando las comas del formato como límites y enviando múltiples mensajes consecutivos.
  2. Se optimizó el formato de anuncios de asignación en `UI/Report.lua` para agrupar objetivos por hechizo (ej. `"Bendición a G1/G2/G3"`), reduciendo drásticamente el tamaño del string proyectado.

## [1.1.0] - 2026-06-19

### Added
- **Ventana Flotante de Reportes (Faltantes)**: Creada una nueva interfaz flotante dedicada (`RaidBuffetReportFrame`) accesible mediante el botón "Reporte" de la grilla principal. Muestra en tiempo real la lista estructurada de casters y los hechizos que tienen asignados y pendientes de lanzar, con detalles de los jugadores faltantes y sus iconos de clase.
- **Sistema de Anuncios Configurable**: Implementados botones para anunciar las asignaciones de tareas ("Quién buffea qué") y los buffs pendientes ("Quién no ha bufeado según asignación" con nombres de los destinatarios que carecen del buff).
- **Selector de Canales en Opciones**: Añadidos controles de Radio Buttons en el menú de configuración de RaidBuffet para seleccionar el canal de salida de los avisos (`/raid`, `/party`, `/rw` o `/local` por consola).
- **Renovación Anticipada (Menos del 25%)**: Modificado el escáner de auras para marcar como faltantes los buffs activos a los que les reste menos del 25% de su duración total, permitiendo su renovación proactiva antes de que expiren en combate.

## [1.0.3] - 2026-06-19

### Fixed
- **Limpieza de Consola (Debug Print)**: Eliminado el mensaje de depuración `[RaidBuffet PreClick]` que se imprimía en el chat del juego durante el casteo para un canal de chat limpio.
- **UI de Asignaciones (Remoción de Ejemplos)**: Eliminadas las filas ficticias de `"Ejemplo"` de la grilla de asignaciones. El addon ahora dibuja de forma precisa únicamente las clases y jugadores reales pertenecientes a la party/raid o al propio jugador en solitario, evitando elementos visuales falsos.

## [1.0.2] - 2026-06-19

### Fixed
- **Estabilidad de Auto-Cast (Modelo Síncrono de PallyPower)**: Refactorizado el sistema de casteo seguro para imitar fielmente el modelo robusto de `PallyPower`. Los botones seguro `RaidBuffetAutoCastBtn` y `RaidBuffetUIBtn` ahora registran clics completos de tipo Down y Up (`"LeftButtonDown"`, `"RightButtonDown"`, `"AnyUp"`, `"AnyDown"`). Esto asegura que el lanzamiento de buffs funcione correctamente independientemente de la configuración global de WoW "Cast on Key Down" (Lanzar hechizos al presionar una tecla).
- **Atributos de Casteo Estáticos**: Movidos los atributos `"type"` y `"type1"` de casteo a un estado estático permanente en `"spell"` durante la creación de los botones seguros. En `PreClick` y `PostClick` solo se manipulan síncronamente `"spell"`, `"spell1"`, `"unit"` y `"unit1"`, eliminando sobrecargas y previniendo bloqueos del motor de WoW en la transición del clic.

## [1.0.1] - 2026-06-16

### Fixed
- Corregido el problema de tokens de unidad no válidos (el uso de nombres propios como `"Petazin"` en el atributo `unit` causaba fallos en el motor seguro de WoW moderno y la API de auras), restableciendo el uso de tokens nativos de Blizzard (`"player"`, `"raid1"`, etc.).
- Implementada la traducción proactiva a `"player"` cuando el objetivo del casteo es el propio jugador para máxima estabilidad de casteo seguro.
- Migrado el motor de auto-cast de macros de texto (`type="macro"`) a lanzamiento directo de hechizos nativo (`type="spell"`), resolviendo bloqueos e incompatibilidades del intérprete de chat en clientes en español.
- Corregido el registro de clics simultáneos (MouseDown y MouseUp) en los botones seguros (uiBtn y macroBtn) que causaban una interrupción instantánea del casteo.
- Eliminada la herencia de la plantilla `ActionButtonTemplate` nativa de Blizzard en `uiBtn` para prevenir colisiones o sobreescritura de los scripts y atributos de casteo seguro por parte del motor del juego.
- Reubicado el botón invisible `RaidBuffetAutoCastBtn` de coordenadas fuera de límites (`-10000, 10000`) al centro de la pantalla (`CENTER, 0, 0`) con transparencia total (`alpha = 0`) para evadir el bloqueo de clics en el cliente moderno.

### Added
- Depuración inteligente de auras activas en el script `PostClick` para diagnosticar en tiempo real las auras aplicadas sobre el personaje y sus SpellIDs.
- Soporte para buffs individuales (Marca de lo Salvaje, Palabra de poder: entereza, Intelecto arcano, etc.) en la base de datos `BuffDB` de `Constants.lua`, permitiendo asignar hechizos individuales que no consumen reagentes.

## [1.0.0-prep] - 2026-06-15

### Added
- Estructura y scaffolding inicial del proyecto.
- Configuración de `RaidBuffet.toc`.
- Documentación inicial (`README.md`, `CHANGELOG.md`, `GEMINI.md`, `ROADMAP.md`).
- Implementación de la matriz visual, red P2P de sincronización y escáner de buffs.
