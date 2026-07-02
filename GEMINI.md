# Registro de Actividad de Gemini - RaidBuffet

Este archivo registra las decisiones arquitectónicas y el estado del proyecto generado por la IA en el addon RaidBuffet.

## [02/07/2026] v1.5.0 - Lavado de Cara Visual Completo: Diseño Minimalista Flat (Estilo ElvUI) y Pulido de UX

- **Eliminación de Elementos Clásicos**:
  - Removido el frame rústico por defecto `"BasicFrameTemplateWithInset"` en la ventana de asignaciones principal (`Grid`), el listado individual (`SubFrame`) y el reporte de faltantes (`RaidBuffetReportFrame`).
  - Implementada la estética minimalista plana usando `BackdropTemplate` con fondos de color gris mate profundo translúcidos (`RGBA: 0.06, 0.06, 0.06, 0.94`) y bordes sólidos de **1 píxel** (`RGBA: 0.18, 0.18, 0.18, 1`), reduciendo al mínimo la ocupación visual en pantalla.
  - Diseñada una barra de cabecera customizada arrastrable (`header`) en todas las ventanas con el título del addon en color dorado suave y un botón de cerrar ("X") minimalista que cambia de color al hover.
  - Ocultas visualmente las barras de scroll nativas grises de Blizzard (`ScrollBar` y botones de flecha) en los scroll containers del reporte y de la sub-asignación individual, manteniendo la rueda del ratón operativa para un acabado plano impecable.
- **Efectos de Brillo en Hover (Glow)**:
  - Vinculada la interacción `OnEnter` y `OnLeave` en todas las celdas principales y botones individuales de sub-asignación.
  - Al pasar el ratón, el borde de la celda experimenta un efecto de brillo (Glow) en color dorado suave (`RGBA: 0.85, 0.7, 0.3, 1`) para indicar foco de forma fluida. Al retirar el cursor, el borde regresa suavemente a su estado base (gris claro si está asignado, o gris oscuro si está vacío).
- **Botones de Control Estilizados**:
  - Reemplazada la textura roja clásica de Blizzard en los botones inferiores (del panel principal y del reporte de faltantes) por botones planos customizados de fondo gris mate y bordes de 1 píxel de color dorado que responden de forma visual e iluminan sus bordes al hover.
- **Optimizaciones de Ciclado y Control de UX (Atajos de Shift)**:
  - **Evitación de Atascamiento**: Introducida la función auxiliar `GetNextViableSpell` para filtrar de forma dinámica e inteligente los buffs viables por columna de clase, previniendo atascos en la rotación (como Guerreros/Pícaros con Sabiduría, o Magos con Santuario). El ciclado ahora incluye siempre el estado vacío (`CLEAR`).
  - **Propagación y Borrado Masivo**: Shift + Clic Izquierdo permite propagar masivamente buffs (y vaciar) a clases viables. Shift + Clic Derecho sobre celdas del panel principal realiza un borrado masivo de toda la fila de asignación de ese caster al instante.
  - **Sub-Asignación Individual mejorada**: Añadida la opción `"Ninguno (No bufar)"` al menú contextual del clic izquierdo, y programado el clic derecho en las celdas de jugadores individuales para limpiar de inmediato a "Heredar clase".
  - **Claridad de Ejes**: Incorporadas etiquetas fijas `"Caster (Bufa)"` y `"Objetivos (Reciben)"` en el panel de sub-asignación individual para guiar la UX.
- **Refresco Automático de Reportes**:
  - Registrados los eventos nativos `UNIT_AURA` y `GROUP_ROSTER_UPDATE` en el reporte de faltantes, logrando que el listado se actualice síncronamente y en tiempo real sin necesidad de refrescar de forma manual.

## [01/07/2026] v1.4.0 - Asignación Dinámica con Scroll de Rueda de Ratón (MouseWheel)

- **Ciclado por Rueda de Ratón (MouseWheel)**:
  - **Grilla Principal**: Vinculados los eventos `EnableMouseWheel` y `OnMouseWheel` sobre todas las celdas de asignación. Al rodar scroll arriba/abajo, cicla en tiempo real por los buffs superiores de la clase caster. Se incluye el estado `"CLEAR"` para permitir desasignar limpiamente el buff.
  - **Panel de Sub-Asignaciones**: Vinculado scroll de ratón en las celdas individuales por jugador. Rueda arriba/abajo cicla por las bendiciones pequeñas de ese paladín. Al ser el paladín local, se valida con `IsSpellInSpellbook` para listar solo las que realmente conoce, y se añade la opción `"CLEAR"` (Heredar clase) al ciclo para limpieza rápida.
  - **Redibujado e Hilos Síncronos**: Los cambios se guardan localmente en la base de datos de asignaciones, se propagan de inmediato vía P2P por red con `Sync:SendAssignment` y se redibujan síncronamente en ambos paneles (`Grid:UpdateGrid` y `SubFrame:RefreshList`), logrando una experiencia de usuario ultra-ágil sin esperas.

## [01/07/2026] v1.3.4 - Inversión de Dimensiones y Consistencia Total de Ejes en Ventana de Sub-Asignación

- **Inversión de Ejes en Sub-Asignaciones**: Modificada la lógica de la función `SubFrame:RefreshList()` en `UI/Grid.lua` para lograr simetría absoluta con la disposición espacial del grid principal:
  - **Eje Y (Filas - Izquierda)**: Pasa a representar a los Paladines de la raid que deben bufar (casters), con sus nombres pintados en rosa de clase.
  - **Eje X (Columnas - Arriba)**: Pasa a representar a los jugadores destino individuales de la clase/grupo destino que recibirán el buff (objetivos), mostrados con nombres abreviados a 4 letras.
  - **Ayudas contextuales**: Los encabezados superiores de los objetivos se colorean en base al color de su clase de personaje y un tooltip en hover muestra su nombre de unidad completo y rol de raid (ej. Tanque Principal).
  - **Dimensiones**: Se ensanchó el frame de sub-asignación `SubFrame` a 440px para acomodar cómodamente hasta 8 columnas de objetivos de forma holgada sin comprometer el área visual.

## [30/06/2026] v1.3.3 - Rediseño del Pie de Página y Pulido del Menú Contextual de Sub-Asignaciones

- **Rediseño del Pie de Página**: Ensanchada la ventana principal `Grid` de 460px a 520px de ancho para proporcionar mayor holgura horizontal. Se reubicaron las coordenadas X absolutas en `UpdateGrid()` (`showAllCheck` en 10, `reportBtn` en 175 y `delegateContainer` en 260), alejándolos de la esquina derecha para eliminar por completo la superposición y colisión visual del botón de Auto-Cast y su texto de estado con el cuadro de Co-Asignador.
- **Pulido del Menú Contextual**: Modificado el tamaño base de `contextMenu` a 160px de ancho (estaba en 120px) y el tamaño de sus botones de acción a 150x20px con un paso vertical de 20px (en lugar de 18px). Esto asegura que todas las bendiciones largas localizadas al español (como `"Bendición de sabiduría"`) entren cómodamente dentro del marco del menú y elimina cualquier pisado o colisión visual de texto entre filas consecutivas.

## [30/06/2026] v1.3.2 - Corrección de Detección de Rangos de Hechizos en Libro de Hechizos Local

- **Detección Dinámica de Hechizos por Libro**: Solucionado el problema que impedía que las bendiciones con múltiples rangos de leveo (Poderío, Sabiduría, Luz y Santuario) se mostraran en el menú flotante del paladín local. Dado que la API `IsSpellKnown` exige el SpellID del rango específico actualmente aprendido por el personaje y puede dar falsos negativos con el ID base (Rango 1), se implementó la función auxiliar `IsSpellInSpellbook(spellID)`. Esta realiza una búsqueda por el nombre localizado limpio del hechizo recorriendo dinámicamente las pestañas y ranuras del libro de hechizos del personaje local.

## [30/06/2026] v1.3.1 - Corrección de Ámbito de Scanner en UI

- **Hotfix de UI/Grid.lua**: Corregido el fallo `attempt to index global 'Scanner' (a nil value)` que ocurría al procesar el listado dinámico del panel de sub-asignación individual `RefreshList` al intentar comprobar si un jugador es Tanque Principal, mediante la importación local del módulo `Scanner` en la cabecera de `UI/Grid.lua`.

## [30/06/2026] v1.3.0 - Asignación Individual Contextual (Alt+Clic -> Clic Derecho en Encabezado), Tanques Manuales y Alertas de Salvación

- **Asignación Individual Contextual (Clic Derecho en Encabezado)**:
  - Rediseñados los encabezados de columna abreviados de las clases (`Gue`, `Pí`, `Cha`, etc.) para que actúen como botones interactivos y capturen el clic derecho del ratón.
  - Al hacer **Clic Derecho** en el encabezado de clase de la fila de un paladín, se despliega la ventana flotante `RaidBuffetSubAssignFrame`.
  - Esta ventana lista de forma síncrona a todos los miembros reales de esa clase en la raid, mostrando las columnas de paladines activos y sus correspondientes asignaciones para cada jugador.
  - Al hacer clic en el botón de buff de cada jugador, se abre un submenú contextual para elegir una bendición pequeña. Las bendiciones libres de colisión se resaltan visualmente en verde con un asterisco (`*`) de ayuda inteligente.
- **Control de Seguridad de Tanques (Susurro Automático)**:
  - Implementado un escáner periódico reactivo en `Scanner:CheckTankSalvationAlerts()`.
  - Si un Tanque Principal (`MAINTANK`) conserva el buff de *Bendición de Salvación* activa, el addon le envía un susurro automático: `"[RaidBuffet]: Eres Tanque Principal y tienes activa la Bendición de Salvación. Por favor, cancélala (/cancelaura Bendición de salvación)."`
  - Se implementó un cooldown de 60 segundos por tanque para prevenir el spam del canal.
- **Auto-Cast Síncrono Completo**:
  - Modificado `Scanner:GetNextBuffTarget()` y `Scanner:GetMissingBuffsReport()` para priorizar las asignaciones individuales indexadas por nombre de jugador (`assignments[playerName] = spellID`) por sobre la regla de la clase.
  - Desactivada la lógica automática "mágica" anterior. Ahora el motor de Auto-Cast del botón visual y flotante integrará y sugerirá de forma secuencial y transparente tanto las bendiciones grandes generales de clase como las pequeñas individuales configuradas manualmente en el panel de sub-asignación.
- **Sincronización P2P Síncrona**: Actualizado el serializador de sincronización en `Sync.lua` para transmitir de forma nativa los nombres de los jugadores individuales como `target`, manteniendo la grilla individual al día para toda la raid.

## [30/06/2026] v1.2.1 - Corrección de Error Lua en Reporte

- **Hotfix de UI/Report.lua**: Solucionado el error `attempt to index field 'iconCaster' (a nil value)` que se presentaba al abrir el reporte de faltantes cuando la raid pasaba de estar completamente buffeada (estado vacío con texto centralizado) a tener buffs faltantes. Ahora se usa un elemento `noMissingText` dedicado en lugar de mutar la fila 1 de datos.

## [30/06/2026] v1.2.0 - Shift-Clic, Control de Tanques, Delegación, Grupos Dinámicos y Botón Flotante

- **Asignación Rápida con Shift-Clic**: Programada la propagación automática inteligente de asignaciones de paladín a todas las clases viables de su fila (ej. Shift-Clic en Poderío lo asigna a melés/híbridos, omitiendo a los casters).
- **Evitar Salvación en Tanques Principales**:
  - Detección precisa de Main Tanks asignados en la raid mediante la API nativa `GetPartyAssignment("MAINTANK", unit)`.
  - Sobrescritura inteligente: Se permite bufar primero a toda la clase con Salvación Superior y luego el escáner detecta que el Tanque tiene Salvación activa, redefiniendo el Auto-Cast para sugerir una bendición individual pequeña (Santuario, Reyes, etc.) que el paladín conozca y que no esté ya asignada de forma superior por otro paladín de la raid.
  - Alertas visuales y locales: Si no hay alternativas viables que no colisionen, se avisa sutilmente en el chat y en la lista de reportes indicando `(Pisar Salvación con: [Buff])` o `(¡Pisar Salvación!)`.
  - **Corrección de QA (Falsos Positivos de Tanques)**: Corregido un comportamiento inusual de `GetPartyAssignment` (que devuelve el Main Tank de la raid para cualquier consulta no coincidente de una unidad offline o nula) comparando que el nombre devuelto coincida exactamente con la unidad consultada.
- **Grupos Dinámicos**: En `Grid:UpdateGrid()`, se calcula el subgrupo máximo activo en la raid y se ocultan dinámicamente las columnas de los subgrupos superiores inactivos, reduciendo de 8 a 5 columnas por defecto. Corregida también la traducción de títulos de tooltip (`"GROUP_X"` -> `"Grupo X"`).
- **Delegación de Asignaciones**: Añadido un EditBox interactivo en el panel principal que permite al líder asignar a un ayudante como co-asignador. Se sincroniza vía red P2P (`DELEGATE:[Nombre]`) y bloquea los permisos de edición al resto del roster.
  - **Corrección de QA (Solapamientos y Autocompletado)**: 
    1. Ajustados los elementos inferiores en una línea de 24px de alto con coordenadas absolutas estáticas (`showAllCheck` en x=10, `reportBtn` en x=185 y `delegateContainer` en x=275) previniendo solapamientos.
    2. Implementado autocompletado en tiempo real en la casilla de co-asignador que sugiere los asistentes del grupo al escribir.
- **Botón Flotante Seguro**: Creada una interfaz flotante independiente (`RaidBuffetFloatCastBtn`) arrastrable (Shift+Arrastrar) que funciona de forma síncrona con el Auto-Cast master. Se integra en opciones con modos de visualización: siempre visible o visible solo si faltan buffs.

## [30/06/2026] v1.1.1 - Parches de Compatibilidad de Chat y UI de Opciones

- **Solución de la Tabla Nil en Opciones**: Importada la variable `Constants` en el archivo `UI/Options.lua` para resolver el error de WoW `bad argument #1 to 'ipairs' (table expected, got nil)` que impedía cargar los radio buttons de los canales de anuncio.
- **Remoción del Carácter Pipe (|) en Chat**: Eliminados los separadores pipe (`|`) en el texto de anuncios seguros de tareas (`AnnounceAssignments`), sustituyéndolos por comas. El pipe es un carácter reservado de escape por la API del chat seguro de Blizzard y causaba el bloqueo `Invalid escape code in chat message`.
- **Prevención de Límite de Longitud (Exceso de Límite 255)**:
  - Diseñada la función de envío seguro `SendChatMessageSafe` en `UI/Report.lua` que intercepta mensajes largos que exceden los 240 caracteres y los subdivide de forma automática e inteligente en bloques más pequeños respetando los límites físicos de Blizzard.
  - Optimizada la recopilación de anuncios para agrupar múltiples objetivos del mismo buff bajo el mismo caster (ej. `Mago buffea Luminosidad Arcana a G1/G2/G3`), reduciendo un 60% la longitud del mensaje.

## [19/06/2026] v1.1.0 - Panel de Reportes y Anuncios de Canal

- **Ventana de Reporte de Faltantes (`UI/Report.lua`)**: Implementado un frame flotante deslizable (`RaidBuffetReportFrame`) con scrollbar integrado para listar detalladamente quién falta por lanzar qué hechizos asignados en la raid. Cada fila muestra iconos de clase del caster, el hechizo correspondiente, la clase o grupo objetivo, y los nombres específicos de los jugadores a los que les falta el buff.
- **Lógica de Anuncios por Chat**: Creadas las funciones para anunciar las tareas distribuidas ("Anunciar Tareas") y quién tiene pendiente bufar a quién ("Anunciar Faltantes", implementando la Opción A del formato de aviso).
- **Selector de Canales en Opciones**: Añadido en `Options.lua` un conjunto de radio buttons que permite al líder o jugador alternar la salida de los anuncios entre `/raid`, `/party`, `/rw` y `/local` (consola local silenciosa para pruebas).
- **Renovación Proactiva al 25%**: Modificada la función `UnitHasBuff` en `Scanner.lua` para considerar como faltante un buff cuando le reste menos de una cuarta parte de su tiempo total de duración, integrando así una renovación proactiva que también retroalimenta al botón de Auto-Cast.

## [19/06/2026] v1.0.3 - Depuración y Limpieza Visual

- **Remoción de Mensajes de Depuración del Chat**: Eliminado el `print` del chat en `ClickCast.lua` que informaba sobre la asignación del clic en el evento `PreClick`, proporcionando ahora una experiencia limpia y libre de spam en la ventana de chat.
- **UI Limpia sin Jugadores Ficticios**: Eliminada la adición automática de filas de `"Ejemplo"` en la grilla visual de `Grid.lua`. Ahora la matriz visual dibuja únicamente clases y personajes reales detectados en el roster actual de la party/raid, o al propio jugador en solitario, sin rellenar artificialmente otras clases.

## [19/06/2026] v1.0.2 - Modelo Síncrono de Casteo (Estilo PallyPower)

- **Registro de Clics Completo (Down & Up)**: Modificados `RaidBuffetAutoCastBtn` y `RaidBuffetUIBtn` para registrar clics en los estados Down y Up (`"LeftButtonDown"`, `"RightButtonDown"`, `"AnyUp"`, `"AnyDown"`). Esto previene que el casteo seguro falle silenciosamente en clientes de WoW que tienen habilitada la opción de "Cast on Key Down".
- **Optimización de Atributos de Casteo**: Establecidos de forma estática permanente `"type" = "spell"` y `"type1" = "spell"` al crear los botones seguros, de manera que solo se manipulen `"spell"`, `"spell1"`, `"unit"` y `"unit1"` en los hooks de `PreClick` y `PostClick`. Esto asegura transiciones instantáneas y libres de bloqueos en el motor seguro de Blizzard.

## [16/06/2026] v1.0.1 - Bugfix de Auto-Cast Seguro y Buffs Individuales

- **Normalización de Tokens de Unidad (unit = "player" / "raidN")**: Se identificó que las funciones del sistema moderno de WoW y los atributos de casteo seguro (`type="spell"`) devuelven nil o fallan si se les pasa el nombre propio del jugador (ej. `"Petazin"`) en lugar de un token de unidad nativo (como `"player"`, `"raid1"`, etc.). Se corrigió para que el escáner devuelva siempre tokens de unidad válidos, traduciendo de forma proactiva a `"player"` cuando el objetivo es el propio jugador para máxima estabilidad.
- **Migración a Lanzamiento Directo (type="spell")**: Para resolver la incompatibilidad y el bloqueo de macros seguras en el chat, se migró el motor de auto-cast del uso de macros de texto (`type="macro"`) al uso de casteo seguro nativo directo de hechizos (`type="spell"`). El addon ahora utiliza los atributos seguros `spell`, `spell1`, `unit` y `unit1` de Blizzard, lo que garantiza un casteo 100% libre de interferencias del chat, de la localización de idiomas o de tildes.
- **Depuración Inteligente de Auras**: Se incorporó un escaneo de auras activas en el script `PostClick` de depuración. Al hacer clic físico o mediante la macro, el addon listará en el chat del juego todas las auras que el cliente de WoW detecta sobre la unidad objetivo y sus SpellIDs, facilitando la identificación de discrepancias.
- **Estabilidad de Auto-Cast (Secure Action)**: Corregido un fallo crítico donde el lanzamiento fallaba silenciosamente debido al uso de `RegisterForClicks("AnyUp", "AnyDown")`, lo que hacía que el motor de WoW ejecutara la acción dos veces en el mismo instante, colisionando e interrumpiendo el casteo. Se restringió a únicamente `RegisterForClicks("AnyUp")`.
- **Limpieza de UI de Clic Seguro (uiBtn)**: Se eliminó la herencia de la plantilla compleja `ActionButtonTemplate` nativa de Blizzard en `uiBtn` (se reemplazó por la creación manual de texturas de icono y fondo) para prevenir colisiones o sobreescritura de los scripts y atributos.
- **Reubicación de macroBtn**: Se movió el botón invisible `RaidBuffetAutoCastBtn` del espacio fuera de límites al centro de la pantalla (`CENTER, 0, 0`) con tamaño `1x1` y transparencia total (`alpha = 0`) para evadir el bloqueo de clics en el cliente.
- **Soporte de Buffs Individuales**: Se añadieron los buffs individuales de druida (Marca de lo Salvaje), sacerdote (Palabra de poder: entereza, protección contra las Sombras, espíritu divino) y mago (Intelecto arcano) a la lista `BuffDB` de `Constants.lua`.

## [16/06/2026] v1.0.0-prep - Matriz Visual y Controles
- **Matriz de Asignaciones**: Se reemplazó el texto estático de `Grid.lua` por el motor de renderizado matemático. Dibuja filas por cada clase, y celdas para los objetivos (9 clases para Paladines, 8 Grupos para el resto).
- **Control de Asignación**: 
  - *Clic Izquierdo* rota de forma circular sobre el pool de hechizos disponibles (>10min) de esa clase y lo asigna.
  - *Clic Derecho* limpia la asignación de esa celda (`CLEAR`).
  - Los clics de asignación disparan un `SendAddonMessage` por la red y actualizan la grilla de todos.
- **Filtro de Visibilidad**: Añadido un `CheckButton` en la esquina inferior para mostrar la banda entera o filtrar y ver únicamente a tu propia clase.
- **Auto-Cast (Scaffolding)**: Se inicializó el Botón Seguro de Auto-Lanzamiento anclado a la grilla.

## [15/06/2026] v1.0.0-prep - Fase 3: Core y Sincronización
- **Eventos Core**: `Core.lua` captura `ADDON_LOADED`, `BAG_UPDATE_DELAYED` y `GROUP_ROSTER_UPDATE`. Se ha implementado el inicio de `RaidBuffetDB`.
- **Alerta de Componentes**: Desarrollada la función `CheckReagents`.
- **Red P2P (Sync)**: Creada la matriz global `Assignments`. Implementado el P2P usando `C_ChatInfo.SendAddonMessage("RBUFFET")`.

## [15/06/2026] v1.0.0-prep - Fase 2: Lógica Estática
- **Base de Datos de Hechizos**: Implementado `Constants.lua` con los IDs de los hechizos superiores a 10 minutos.
- **Mapeo de Reagents**: Mapeados los Item IDs de los componentes masivos.
- **Gestión de Traducciones**: Implementadas funciones auxiliares en `Localization.lua` (`GetSpellInfo`).

## [15/06/2026] v1.0.0-prep - Scaffolding y Arquitectura
- **Proyecto Inicializado**: Se definió la estructura base del addon.
