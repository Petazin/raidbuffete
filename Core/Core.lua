local addonName, addonTable = ...
local L = addonTable.L

-- Redirecciones para el Modo Test simulado (local a este archivo) con fallback robusto que preserva múltiples retornos
local IsInRaid = function()
    if addonTable.IsInRaid then return addonTable:IsInRaid() end
    return _G.IsInRaid()
end
local IsInGroup = function()
    if addonTable.IsInGroup then return addonTable:IsInGroup() end
    return _G.IsInGroup()
end
local GetNumGroupMembers = function()
    if addonTable.GetNumGroupMembers then return addonTable:GetNumGroupMembers() end
    return _G.GetNumGroupMembers()
end
local GetRaidRosterInfo = function(idx)
    if addonTable.GetRaidRosterInfo then return addonTable:GetRaidRosterInfo(idx) end
    return _G.GetRaidRosterInfo(idx)
end
local UnitName = function(unit)
    if addonTable.UnitName then return addonTable:UnitName(unit) end
    return _G.UnitName(unit)
end
local UnitClass = function(unit)
    if addonTable.UnitClass then return addonTable:UnitClass(unit) end
    return _G.UnitClass(unit)
end
local GetPartyAssignment = function(asg, unit)
    if addonTable.GetPartyAssignment then return addonTable:GetPartyAssignment(asg, unit) end
    if addonTable.Sync and addonTable.Sync.GetPartyAssignment then return addonTable.Sync.GetPartyAssignment(asg, unit) end
    return nil
end

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
frame:RegisterEvent("PLAYER_UPDATE_RESTING")

-- Configuración por defecto
local defaultDB = {
    ReagentThreshold = 20,
    ForceLang = "AUTO", -- "AUTO", "esES", "enUS"
    AnnounceChannel = "RAID",
    EnableFloatBtn = false,
    FloatVisibilityMode = "ALWAYS",
    FloatPosition = nil,
    TalentsCache = {},
    AnnounceLowReagents = false,
    AlertInCapital = true,
    ShowFloatHUD = true,
    TrackedReagents = {}
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
            
            if RaidBuffetDB.TrackedReagents == nil then
                RaidBuffetDB.TrackedReagents = {}
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
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateMyOwnTalentsInCache()
        addonTable.Core:ScanAllGroupTalents()
        
        -- Período de gracia de 5 segundos tras pantalla de carga para evitar alertas falsas por sincronización incompleta de bolsas
        isReagentsCheckReady = false
        if addonTable.reagentsTimer then
            addonTable.reagentsTimer:Cancel()
        end
        addonTable.reagentsTimer = C_Timer.NewTimer(5, function()
            isReagentsCheckReady = true
            addonTable.Core:CheckReagents()
        end)
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
    elseif event == "PLAYER_UPDATE_RESTING" then
        addonTable.Core:CheckReagents()
    end
end)

-- Sistema Inteligente de Alertas de Componentes (Reagents) y Druida (Semillas)
local lastWarnTime = 0       -- Cooldown para anuncio de chat de grupo (5 min)
local lastLocalPrintTime = 0  -- Cooldown para print local en consola (10 seg)
local capitalWarnTimer = nil
local isReagentsCheckReady = false

local capitals = {
    ["Shattrath City"] = true,
    ["Shattrath"] = true,
    ["Orgrimmar"] = true,
    ["Ironforge"] = true,
    ["Forjaz"] = true,
    ["Stormwind City"] = true,
    ["Stormwind"] = true,
    ["Ventormenta"] = true,
    ["Thunder Bluff"] = true,
    ["Cima del Trueno"] = true,
    ["Undercity"] = true,
    ["Entrañas"] = true,
    ["Darnassus"] = true,
    ["Silvermoon City"] = true,
    ["Ciudad de Lunargenta"] = true,
    ["The Exodar"] = true,
    ["El Éxodar"] = true
}

local function IsInCapitalOrResting()
    return IsResting() or capitals[GetRealZoneText()]
end

local function GetReagentName(id)
    local name = GetItemInfo(id)
    if name then return name end
    
    -- Fallback estático localizado si no está en la caché de Blizzard
    local lang = (RaidBuffetDB and RaidBuffetDB.ForceLang) or "AUTO"
    if lang == "AUTO" then
        lang = GetLocale()
    end
    
    local isSpanish = (lang == "esES" or lang == "esMX")
    local staticNames = isSpanish and {
        [21177] = "Símbolo de reyes",
        [17029] = "Vela sagrada",
        [17020] = "Polvo arcano",
        [22148] = "Videpluma salvaje",
        [17026] = "Raíz de espina salvaje",
        [22147] = "Semilla de silexia",
        [17038] = "Semilla de pino hierro",
        [17031] = "Runa de teletransportación",
        [17032] = "Runa de portales",
        [17028] = "Vela sagrada ligera"
    } or {
        [21177] = "Symbol of Kings",
        [17029] = "Sacred Candle",
        [17020] = "Arcane Powder",
        [22148] = "Wild Quillvine",
        [17026] = "Wild Spineleaf",
        [22147] = "Flintweed Seed",
        [17038] = "Ironwood Seed",
        [17031] = "Rune of Teleportation",
        [17032] = "Rune of Portals",
        [17028] = "Devout Candle"
    }
    
    return staticNames[id] or ("Item " .. id)
end
addonTable.GetReagentName = GetReagentName

local function StartCapitalWarningTimer()
    if capitalWarnTimer then return end
    capitalWarnTimer = C_Timer.NewTicker(30, function()
        if IsInCapitalOrResting() and RaidBuffetDB.AlertInCapital then
            local _, classFileName = UnitClass("player")
            local items = {}
            local mainR = addonTable.Constants.Reagents[classFileName]
            if mainR then table.insert(items, mainR) end
            local extraR = addonTable.Constants.ExtraReagents and addonTable.Constants.ExtraReagents[classFileName]
            if extraR then
                for _, id in ipairs(extraR) do table.insert(items, id) end
            end
            
            local threshold = RaidBuffetDB.ReagentThreshold or 20
            local lowItems = {}
            for _, id in ipairs(items) do
                -- Ignorar si está desmarcado en las opciones
                if RaidBuffetDB.TrackedReagents and RaidBuffetDB.TrackedReagents[id] == false then
                    -- Omitir
                else
                    local count = GetItemCount(id)
                    if count < threshold then
                        local name = GetReagentName(id)
                        table.insert(lowItems, name .. ": " .. count)
                    end
                end
            end
            
            if #lowItems > 0 then
                UIErrorsFrame:AddMessage("|cffff0000[RaidBuffet] ALERT: Reactivos bajos! Compra en el vendedor: " .. table.concat(lowItems, ", ") .. "|r", 1, 0, 0, 1, 5)
                PlaySound(8959) -- Sonido de error de Blizzard
            else
                if capitalWarnTimer then
                    capitalWarnTimer:Cancel()
                    capitalWarnTimer = nil
                end
            end
        else
            if capitalWarnTimer then
                capitalWarnTimer:Cancel()
                capitalWarnTimer = nil
            end
        end
    end)
end

function addonTable.Core:CheckReagents(force)
    if not isReagentsCheckReady and not force then return end
    local _, classFileName = UnitClass("player")
    local items = {}
    local mainR = addonTable.Constants.Reagents[classFileName]
    if mainR then table.insert(items, mainR) end
    local extraR = addonTable.Constants.ExtraReagents and addonTable.Constants.ExtraReagents[classFileName]
    if extraR then
        for _, id in ipairs(extraR) do table.insert(items, id) end
    end
    
    if #items == 0 then return end
    
    local threshold = RaidBuffetDB.ReagentThreshold or 20
    local hasAnyLow = false
    local lowItemsList = {}
    
    for _, id in ipairs(items) do
        -- Si el jugador desactivó el rastreo para este reactivo, lo ignoramos
        if RaidBuffetDB.TrackedReagents and RaidBuffetDB.TrackedReagents[id] == false then
            -- Omitir
        else
            local count = GetItemCount(id)
            if count < threshold then
                hasAnyLow = true
                local name = GetReagentName(id)
                table.insert(lowItemsList, { name = name, count = count })
            end
        end
    end
    
    if hasAnyLow then
        local now = GetTime()
        
        -- 1. Alerta local en consola de chat y pantalla estilo Raid Warning (cooldown parametrizado en la DB)
        local warnInterval = (RaidBuffetDB and RaidBuffetDB.ReagentWarnInterval) or 300
        if now - lastLocalPrintTime > warnInterval then
            for _, itemData in ipairs(lowItemsList) do
                -- Print en chat
                print("|cffff0000[RaidBuffet]|r " .. (L["REAGENTS_LOW"] or "Componentes Bajos!") .. " (" .. itemData.name .. ": " .. itemData.count .. ")")
                
                -- Alerta visual en el centro de la pantalla (Raid Warning local)
                RaidNotice_AddMessage(RaidWarningFrame, "|cffff0000[RaidBuffet] ALERT: ¡Componentes Bajos! (" .. itemData.name .. ": " .. itemData.count .. ")|r", ChatTypeInfo["RAID_WARNING"])
            end
            PlaySound(8959) -- Sonido de error nativo
            lastLocalPrintTime = now
        end
        
        -- 2. Anuncio en chat de grupo (cooldown estricto de 5 minutos para evitar spam a otros)
        if now - lastWarnTime > 300 then
            if RaidBuffetDB.AnnounceLowReagents and IsInGroup() then
                local channel = IsInRaid() and "RAID" or "PARTY"
                local itemsStrList = {}
                for _, itemData in ipairs(lowItemsList) do
                    table.insert(itemsStrList, itemData.name .. ": " .. itemData.count)
                end
                SendChatMessage("[RaidBuffet] Alerta: Me quedan pocos componentes de clase (" .. table.concat(itemsStrList, ", ") .. "). ¡Por favor, comerciadme si tenéis de sobra!", channel)
            end
            lastWarnTime = now
        end
        
        -- 3. Alerta visual en pantalla y sonora periódica si estamos en área de descanso o capital
        if IsInCapitalOrResting() and RaidBuffetDB.AlertInCapital then
            local textList = {}
            for _, itemData in ipairs(lowItemsList) do
                table.insert(textList, itemData.name .. " (" .. itemData.count .. ")")
            end
            UIErrorsFrame:AddMessage("|cffff0000[RaidBuffet] ALERT: Reactivos bajos! Compra en el vendedor: " .. table.concat(textList, ", ") .. "|r", 1, 0, 0, 1, 5)
            PlaySound(8959)
            StartCapitalWarningTimer()
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
    local _, classFileName = UnitClass("player")
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

