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
frame:RegisterEvent("INSPECT_READY")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

-- Configuración por defecto
local defaultDB = {
    ReagentThreshold = 20,
    ForceLang = "AUTO", -- "AUTO", "esES", "enUS"
    AnnounceChannel = "RAID",
    EnableFloatBtn = false,
    FloatVisibilityMode = "ALWAYS",
    FloatPosition = nil,
    TalentsCache = {}
}

frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local function UpdateMyOwnTalentsInCache()
    local name = UnitName("player")
    if name then
        local t = addonTable.Core:GetMyTalents()
        if t then
            -- Solo pisamos si la fuente no es manual (el líder prefiere forzarlo)
            local existing = addonTable.TalentsCache[name]
            if not existing or existing.source ~= "MANUAL" then
                addonTable.TalentsCache[name] = {
                    class = t.class,
                    spec = existing and existing.spec or "NONE",
                    talents = {
                        improvedWisdom = t.imprWisdom,
                        improvedMight = t.imprMight,
                        improvedSantuario = t.imprSant > 0,
                        improvedMark = t.imprMark,
                        improvedFort = t.imprFort,
                        improvedSpirit = t.imprSpirit
                    },
                    source = "LOCAL"
                }
            end
        end
    end
end

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
            
            -- Cargar caché local de talentos
            addonTable.TalentsCache = RaidBuffetDB.TalentsCache
            
            -- Guardar nuestros propios talentos locales en la caché de inmediato
            UpdateMyOwnTalentsInCache()
            
            local t = addonTable.Core:GetMyTalents()
            print(string.format("|cff00ff00RaidBuffet v1.6.3 Loaded!|r Talentos detectados: Wisdom=%d, Might=%d, Sant=%d, Mark=%d, Fort=%d, Spirit=%d", 
                t.imprWisdom, t.imprMight, t.imprSant, t.imprMark, t.imprFort, t.imprSpirit))
            
            -- Registrar prefijo de red para el canal P2P de Addons (TBC Classic)
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
                C_ChatInfo.RegisterAddonMessagePrefix("RaidBuffet")
            end
            
            -- Pedir Sync al líder si acabamos de loguear y estamos en grupo
            if addonTable.Sync and addonTable.Sync.RequestSync then
                addonTable.Sync:RequestSync()
            end
            
            addonTable.Core:CheckReagents()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateMyOwnTalentsInCache()
        addonTable.Core:ScanAllGroupTalents()
    elseif event == "BAG_UPDATE_DELAYED" then
        addonTable.Core:CheckReagents()
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Asegurar que nuestros talentos estén listos
        UpdateMyOwnTalentsInCache()
        -- Escanear la banda gradualmente
        addonTable.Core:ScanAllGroupTalents()
        -- Refrescar la UI cuando alguien entra o sale de la banda
        if addonTable.UI and addonTable.UI.UpdateGrid then
            addonTable.UI:UpdateGrid()
        end
    elseif event == "INSPECT_READY" then
        local guid = ...
        addonTable.Core:ProcessInspectResult(guid)
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitExists("target") and not UnitIsUnit("target", "player") and UnitInParty("target") then
            local _, class = UnitClass("target")
            if class == "PALADIN" or class == "PRIEST" or class == "DRUID" then
                addonTable.Core:QueueInspect("target")
            end
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if UnitExists("mouseover") and not UnitIsUnit("mouseover", "player") and UnitInParty("mouseover") then
            local _, class = UnitClass("mouseover")
            if class == "PALADIN" or class == "PRIEST" or class == "DRUID" then
                addonTable.Core:QueueInspect("mouseover")
            end
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

local function GetTalentRankBySpellID(tabIndex, spellID, isInspect)
    local targetName = GetSpellInfo(spellID)
    if not targetName then return 0 end
    
    local numTalents = GetNumTalents(tabIndex, isInspect) or 0
    for i = 1, numTalents do
        local name, _, _, _, rank = GetTalentInfo(tabIndex, i, isInspect)
        if name == targetName then
            return rank
        end
    end
    return 0
end

function addonTable.Core:GetMyTalents()
    local _, classFileName = UnitClassBase("player")
    local data = {
        class = classFileName,
        imprWisdom = 0,
        imprMight = 0,
        imprSant = 0,
        imprMark = 0,
        imprFort = 0,
        imprSpirit = 0
    }
    
    if classFileName == "PALADIN" then
        data.imprWisdom = GetTalentRankBySpellID(1, 20244, false)
        data.imprMight = GetTalentRankBySpellID(3, 20042, false)
        local hasSanctuary = GetTalentRankBySpellID(2, 20911, false)
        data.imprSant = (hasSanctuary > 0) and 1 or 0
    elseif classFileName == "DRUID" then
        data.imprMark = GetTalentRankBySpellID(3, 17050, false)
    elseif classFileName == "PRIEST" then
        data.imprFort = GetTalentRankBySpellID(1, 14767, false)
        data.imprSpirit = GetTalentRankBySpellID(1, 33141, false)
    end
    
    return data
end

-- ============================================================================
-- COLA ASÍNCRONA DE INSPECCIÓN AUTOMÁTICA
-- ============================================================================
local inspectQueue = {}
local lastInspectTime = 0
local inspectInterval = 1.5 -- Segundos de retraso entre peticiones para no saturar al cliente
local isWaitingForInspect = false

local function ProcessInspectQueue()
    local now = GetTime()
    if isWaitingForInspect and (now - lastInspectTime < 4) then
        return -- Esperar a que responda o expire el timeout de 4 segundos
    end
    
    if now - lastInspectTime < inspectInterval then return end
    
    if #inspectQueue == 0 then return end
    
    local unit = table.remove(inspectQueue, 1)
    if UnitExists(unit) and CanInspect(unit) and UnitIsConnected(unit) then
        lastInspectTime = now
        isWaitingForInspect = true
        NotifyInspect(unit)
    end
end

local tickerFrame = CreateFrame("Frame")
tickerFrame:SetScript("OnUpdate", function(self, elapsed)
    ProcessInspectQueue()
end)

function addonTable.Core:QueueInspect(unit)
    if not unit or unit == "player" then return end
    -- Evitar duplicados
    for _, queued in ipairs(inspectQueue) do
        if queued == unit then return end
    end
    table.insert(inspectQueue, unit)
end

function addonTable.Core:ScanAllGroupTalents()
    if not IsInGroup() then return end
    
    local prefix = IsInRaid() and "raid" or "party"
    local count = GetNumGroupMembers()
    
    for i = 1, count do
        local unit = prefix .. i
        if i == count and not IsInRaid() then unit = "player" end
        
        if UnitExists(unit) and UnitIsConnected(unit) and unit ~= "player" then
            local _, class = UnitClass(unit)
            if class == "PALADIN" or class == "PRIEST" or class == "DRUID" then
                if CanInspect(unit) then
                    addonTable.Core:QueueInspect(unit)
                end
            end
        end
    end
end

function addonTable.Core:ProcessInspectResult(guid)
    isWaitingForInspect = false -- Desbloquear cola
    
    -- Encontrar la unidad correspondiente
    local unit = nil
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local u = "raid" .. i
            if UnitGUID(u) == guid then unit = u; break end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local u = "party" .. i
            if UnitGUID(u) == guid then unit = u; break end
        end
    end
    
    if not unit then return end
    local name = UnitName(unit)
    if not name then return end
    name = string.match(name, "([^%-]+)")
    
    local _, class = UnitClass(unit)
    if class ~= "PALADIN" and class ~= "PRIEST" and class ~= "DRUID" then return end
    
    -- Ignorar si el líder ya forzó manualmente su especialidad
    local existing = addonTable.TalentsCache[name]
    if existing and existing.source == "MANUAL" then return end
    
    -- Leer talentos de la otra persona con isInspect = true
    local t = {
        imprWisdom = GetTalentRankBySpellID(1, 20244, true),
        imprMight = GetTalentRankBySpellID(3, 20042, true),
        imprSant = 0,
        imprMark = GetTalentRankBySpellID(3, 17050, true),
        imprFort = GetTalentRankBySpellID(1, 14767, true),
        imprSpirit = GetTalentRankBySpellID(1, 33141, true)
    }
    local hasSanctuary = GetTalentRankBySpellID(2, 20911, true)
    t.imprSant = (hasSanctuary > 0) and 1 or 0
    
    -- Deducir especialización automática por talentos
    local spec = "NONE"
    if class == "PALADIN" then
        if t.imprSant > 0 then spec = "PROT"
        elseif t.imprWisdom > 0 then spec = "HOLY"
        elseif t.imprMight > 0 then spec = "RETRI"
        end
    elseif class == "DRUID" then
        if t.imprMark > 0 then spec = "RESTO" end
    elseif class == "PRIEST" then
        if t.imprSpirit > 0 then spec = "DISC"
        elseif t.imprFort > 0 then spec = "HOLY"
        end
    end
    
    addonTable.TalentsCache[name] = {
        class = class,
        spec = spec,
        talents = {
            improvedWisdom = t.imprWisdom,
            improvedMight = t.imprMight,
            improvedSantuario = t.imprSant > 0,
            improvedMark = t.imprMark,
            improvedFort = t.imprFort,
            improvedSpirit = t.imprSpirit
        },
        source = "AUTO"
    }
    
    -- Refrescar la UI
    if addonTable.UI and addonTable.UI.UpdateGrid then
        addonTable.UI:UpdateGrid()
    end
end

