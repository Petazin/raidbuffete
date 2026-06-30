# Roadmap de RaidBuffet

## Fase 1: Estructura Base (Completada)
- [x] Scaffolding: Creación de directorios, TOC y archivos Markdown.
- [x] Generar base LUA: Creación de archivos de Core, UI y Locales.

## Fase 2: Lógica Estática y Datos (Completada)
- [x] Mapeo de la base de datos `BuffDB` en `Constants.lua` (SpellIDs de hechizos >10 min y ReagentIDs).
- [x] Implementación de `Localization.lua` utilizando `GetSpellInfo`.

## Fase 3: Sincronización y Core (Completada)
- [x] Inicialización del Addon y gestión de perfiles (`SavedVariables`).
- [x] Sincronización P2P (`SendAddonMessage`) para compartir asignaciones en la raid.
- [x] Lógica de monitoreo de mochila para los Reagents.

## Fase 4: Interfaz de Usuario y Auto-Cast (Completada)
- [x] Renderizado de la grilla principal inspirada en PallyPower (`UI/Grid.lua`).
- [x] Integración de `SecureActionButtonTemplate` para la funcionalidad Click-to-Cast.
- [x] Panel de Opciones y selector de Umbral de Reagents (`UI/Options.lua`).

## Fase 5: Reporte de Faltantes, Anuncios y Mejoras de Usabilidad (v1.2.0 - Completada)
- [x] Ventana flotante deslizable de reporte de buffs faltantes con filtros de clases/grupos.
- [x] Anuncios dinámicos divididos en chat de WoW sin límite de caracteres (límite 255).
- [x] Asignación rápida con Shift-Clic para paladines filtrada por clase viable.
- [x] Detección de Tanques Principales y flujo de sobrescritura de Salvación con buffs alternativos.
- [x] Grupos dinámicos en TBC en base al subgrupo real activo en la banda (de 8 a 5).
- [x] Delegación del líder (Co-Asignador) mediante canal P2P seguro.
- [x] Botón seguro flotante independiente con visibilidad condicional.

## Futuras Mejoras
- Animaciones de carga y destellos sutiles al realizar asignaciones.
- Sincronización avanzada con otros addons de gestión PVE y auditoría.
