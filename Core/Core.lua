local addonName, addonTable = ...
local L = addonTable.L

-- Estado Global de Asignaciones
-- Estructura: Assignments[ClaseQueLanza][NombreJugador][ClaseOGrupoObjetivo] = spellID
addonTable.Assignments = {
    ["PALADIN"] = {},
    ["PRIEST"]  = {},
    ["MAGE"]    = {},
    ["DRUID"]   = {}
}

local frame = CreateFrame("Frame")
addonTable.Core = frame

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- Configuración por defecto
local defaultDB = {
    ReagentThreshold = 20,
    ForceLang = "AUTO", -- "AUTO", "esES", "enUS"
    AnnounceChannel = "RAID",
    EnableFloatBtn = false,
    FloatVisibilityMode = "ALWAYS",
    FloatPosition = nil
}

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            -- Inicializar SavedVariables
            RaidBuffetDB = RaidBuffetDB or defaultDB
            
            -- Aplicar variables por defecto que falten
            for k, v in pairs(defaultDB) do
                if RaidBuffetDB[k] == nil then
                    RaidBuffetDB[k] = v
                end
            end
            
            print("|cff00ff00RaidBuffet v1.0.0 Loaded!|r")
            
            -- Registrar prefijo de red para el canal P2P de Addons (TBC Classic)
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
                C_ChatInfo.RegisterAddonMessagePrefix("RBUFFET")
            end
            
            -- Pedir Sync al líder si acabamos de loguear y estamos en grupo
            if addonTable.Sync and addonTable.Sync.RequestSync then
                addonTable.Sync:RequestSync()
            end
            
            addonTable.Core:CheckReagents()
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        addonTable.Core:CheckReagents()
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Refrescar la UI cuando alguien entra o sale de la banda
        if addonTable.UI and addonTable.UI.UpdateGrid then
            addonTable.UI:UpdateGrid()
        end
    end
end)

-- Sistema Inteligente de Alertas de Componentes (Reagents)
local lastWarnTime = 0
function addonTable.Core:CheckReagents()
    local _, classFileName = UnitClassBase("player")
    local reagentID = addonTable.Constants.Reagents[classFileName]
    
    if not reagentID then return end -- La clase no usa componentes de buff masivos
    
    local count = GetItemCount(reagentID)
    local threshold = RaidBuffetDB.ReagentThreshold or 20
    
    if count < threshold then
        -- Evitar spam: avisar una vez cada 5 minutos como máximo
        if GetTime() - lastWarnTime > 300 then
            local itemName = GetItemInfo(reagentID) or ("Reagent " .. reagentID)
            print("|cffff0000[RaidBuffet]|r " .. (L["REAGENTS_LOW"] or "Reagents Low!") .. " (" .. itemName .. ": " .. count .. ")")
            lastWarnTime = GetTime()
        end
    end
end
