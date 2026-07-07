local addonName, addonTable = ...

-- Base de datos estática de Buffs y Componentes
addonTable.Constants = {
    -- Diccionario de componentes masivos por clase (Item IDs)
    Reagents = {
        ["PALADIN"] = 21177, -- Símbolo de reyes (Symbol of Kings)
        ["PRIEST"]  = 17029, -- Vela sagrada (Sacred Candle)
        ["MAGE"]    = 17020, -- Polvo arcano (Arcane Powder)
        ["DRUID"]   = 22148  -- Videpluma salvaje (Wild Quillvine)
    },
    
    -- Reactivos adicionales por clase a monitorizar (ej: Semillas de Druida, Runas de Mago, Velas menores de Priest)
    ExtraReagents = {
        ["DRUID"] = {
            17026, -- Raíz de espina salvaje (Don de lo salvaje R2)
            22147, -- Semilla de silexia (Flintweed Seed - Renacer R6)
            17038  -- Semilla de pino hierro (Ironwood Seed - Renacer R5)
        },
        ["MAGE"] = {
            17031, -- Runa de teletransportación (Rune of Teleportation)
            17032  -- Runa de portales (Rune of Portals)
        },
        ["PRIEST"] = {
            17028  -- Vela sagrada ligera (Devout Candle - Rezos menores)
        }
    },
    
    -- Hechizos asignables (>10 min), agrupados por clase
    -- Usamos el SpellID del Rango Máximo de TBC. (GetSpellInfo obtendrá el nombre dinámico)
    BuffDB = {
        ["PALADIN"] = {
            25898, -- Bendición de reyes superior
            25890, -- Bendición de luz superior
            27141, -- Bendición de poderío superior
            25895, -- Bendición de salvación superior
            27143, -- Bendición de sabiduría superior
            25899  -- Bendición de santuario superior
        },
        ["PRIEST"] = {
            25389, -- Palabra de poder: entereza (Individual)
            25392, -- Rezo de entereza (Grupo)
            25433, -- Protección contra las Sombras (Individual)
            39362, -- Rezo de protección contra las Sombras (Grupo)
            25312, -- Espíritu divino (Individual)
            32999  -- Rezo de espíritu (Grupo)
        },
        ["MAGE"] = {
            27126, -- Intelecto arcano (Individual)
            27127  -- Luminosidad arcana (Grupo)
        },
        ["DRUID"] = {
            26990, -- Marca de lo Salvaje (Individual)
            26991  -- Don de lo Salvaje (Grupo)
        }
    },
    
    -- Mapeo de bendiciones superiores a bendiciones individuales (Rango 1/Base para IsSpellKnown)
    AlternativeSmallBlessings = {
        [25898] = 20217, -- Reyes superior -> Reyes pequeña
        [25890] = 19977, -- Luz superior -> Luz pequeña
        [27141] = 19740, -- Poderío superior -> Poderío pequeña
        [25895] = 1038,  -- Salvación superior -> Salvación pequeña
        [27143] = 19742, -- Sabiduría superior -> Sabiduría pequeña
        [25899] = 20911  -- Santuario superior -> Santuario pequeña
    },
    
    -- Viabilidad de buffs de paladín por clase para la propagación rápida (Shift-Clic)
    ClassViability = {
        [27141] = { -- Poderío superior (Física)
            ["WARRIOR"] = true, ["ROGUE"] = true, ["HUNTER"] = true, 
            ["PALADIN"] = true, ["SHAMAN"] = true, ["DRUID"] = true
        },
        [27143] = { -- Sabiduría superior (Mana)
            ["MAGE"] = true, ["PRIEST"] = true, ["WARLOCK"] = true, 
            ["DRUID"] = true, ["SHAMAN"] = true, ["PALADIN"] = true, ["HUNTER"] = true
        },
        [25898] = { -- Reyes superior (Universal)
            ["WARRIOR"] = true, ["ROGUE"] = true, ["HUNTER"] = true, ["MAGE"] = true, 
            ["WARLOCK"] = true, ["PRIEST"] = true, ["DRUID"] = true, ["SHAMAN"] = true, ["PALADIN"] = true
        },
        [25890] = { -- Luz superior (Universal)
            ["WARRIOR"] = true, ["ROGUE"] = true, ["HUNTER"] = true, ["MAGE"] = true, 
            ["WARLOCK"] = true, ["PRIEST"] = true, ["DRUID"] = true, ["SHAMAN"] = true, ["PALADIN"] = true
        },
        [25895] = { -- Salvación superior (Universal)
            ["WARRIOR"] = true, ["ROGUE"] = true, ["HUNTER"] = true, ["MAGE"] = true, 
            ["WARLOCK"] = true, ["PRIEST"] = true, ["DRUID"] = true, ["SHAMAN"] = true, ["PALADIN"] = true
        },
        [25899] = { -- Santuario superior (Universal)
            ["WARRIOR"] = true, ["ROGUE"] = true, ["HUNTER"] = true, ["MAGE"] = true, 
            ["WARLOCK"] = true, ["PRIEST"] = true, ["DRUID"] = true, ["SHAMAN"] = true, ["PALADIN"] = true
        }
    },
    
    -- Determina el comportamiento del objetivo en la grilla visual
    TargetTypes = {
        ["PALADIN"] = "CLASS", -- Paladines buffean a una clase entera (Ej: Todos los Guerreros)
        ["PRIEST"]  = "GROUP", -- Sacerdotes buffean a un Grupo (1-8)
        ["MAGE"]    = "GROUP", -- Magos buffean a un Grupo (1-8)
        ["DRUID"]   = "GROUP"  -- Druidas buffean a un Grupo (1-8)
    },

    -- Orden de visualización de clases en la Grilla para los Paladines
    ClassOrder = {
        "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN", "PALADIN"
    },

    -- Canales de anuncios de chat soportados
    AnnounceChannels = {
        { code = "RAID",          name = "Banda (/raid)" },
        { code = "PARTY",         name = "Grupo (/party)" },
        { code = "RAID_WARNING",  name = "Alerta de Banda (/rw)" },
        { code = "LOCAL",         name = "Consola de Chat (Solo Tú)" },
    },

    -- Mapeo estático de Especializaciones a Talentos (para el selector manual)
    SpecializationTalents = {
        ["PALADIN"] = {
            ["HOLY"]  = { improvedWisdom = 5, improvedMight = 0, improvedSantuario = false },
            ["PROT"]  = { improvedWisdom = 0, improvedMight = 0, improvedSantuario = true },
            ["RETRI"] = { improvedWisdom = 0, improvedMight = 5, improvedSantuario = false },
            ["NONE"]  = { improvedWisdom = 0, improvedMight = 0, improvedSantuario = false }
        },
        ["DRUID"] = {
            ["RESTO"]   = { improvedMark = 5 },
            ["FERAL"]   = { improvedMark = 0 },
            ["BALANCE"] = { improvedMark = 0 },
            ["NONE"]    = { improvedMark = 0 }
        },
        ["PRIEST"] = {
            ["DISC"]   = { improvedFort = 2, improvedSpirit = 2 },
            ["HOLY"]   = { improvedFort = 2, improvedSpirit = 0 },
            ["SHADOW"] = { improvedFort = 0, improvedSpirit = 0 },
            ["NONE"]   = { improvedFort = 0, improvedSpirit = 0 }
        }
    }
}
