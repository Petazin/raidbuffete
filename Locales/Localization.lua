local addonName, addonTable = ...
addonTable.L = addonTable.L or {}
local L = addonTable.L

-- ============================================================================
-- FUNCIONES DE LOCALIZACIÓN NATIVA
-- ============================================================================

-- Extrae el nombre y el ícono de un hechizo directamente del cliente (100% exacto)
function L:GetSpellInfo(spellID)
    local name, _, icon = GetSpellInfo(spellID)
    if not name then
        return "Unknown Spell (" .. tostring(spellID) .. ")", "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    return name, icon
end

-- Extrae el nombre y el ícono de un objeto/componente (Reagent)
function L:GetItemInfo(itemID)
    local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    if not name then
        -- En caso de que el cliente no lo tenga cacheado al loguear, GetItemInfo() puede devolver nil.
        -- Se puede usar C_Item.RequestLoadItemDataByID, pero como fallback visual:
        return "Reagent ("..itemID..")", "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    return name, icon
end

-- Devuelve el nombre localizado de la clase (Ej: WARRIOR -> Guerrero)
function L:GetClassName(classFileName)
    -- LOCALIZED_CLASS_NAMES_MALE es una global nativa de Blizzard
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFileName] then
        return LOCALIZED_CLASS_NAMES_MALE[classFileName]
    end
    return classFileName
end
