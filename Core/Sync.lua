local addonName, addonTable = ...
local Sync = {}
addonTable.Sync = Sync

-- Nombre del delegado activo en el grupo
addonTable.DelegateName = nil

-- Embeber AceComm-3.0 y AceSerializer-3.0
LibStub("AceComm-3.0"):Embed(Sync)
local AceSerializer = LibStub("AceSerializer-3.0")

local COMM_PREFIX = "RaidBuffet"

-- Helper para limpiar nombre de reino
local function GetCleanName(name)
    if not name then return nil end
    return string.match(name, "([^%-]+)")
end

-- Helper local para verificar permisos
local function SenderHasPermissions(sender)
    if addonTable.TestModeActive then return true end
    if not IsInGroup() then return true end
    local cleanSender = GetCleanName(sender)
    
    if addonTable.DelegateName and cleanSender == addonTable.DelegateName then
        return true
    end
    
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name then
                local cleanName = GetCleanName(name)
                if cleanName == cleanSender then
                    if rank == 1 or rank == 2 then
                        return true
                    end
                    break
                end
            end
        end
    elseif IsInGroup() then
        local leaderName = nil
        if UnitIsGroupLeader("player") then
            leaderName = UnitName("player")
        else
            local numSub = GetNumSubgroupMembers() or 0
            for i = 1, numSub do
                if UnitIsGroupLeader("party" .. i) then
                    leaderName = UnitName("party" .. i)
                    break
                end
            end
        end
        if leaderName and cleanSender == GetCleanName(leaderName) then
            return true
        end
    end
    
    return false
end

-- Genera la tabla de estado completo
local function GetFullStateData()
    local manualSpecs = {}
    for name, data in pairs(addonTable.TalentsCache) do
        if data.source == "MANUAL" then
            manualSpecs[name] = data.spec
        end
    end
    return {
        assignments = addonTable.Assignments,
        delegate = addonTable.DelegateName or "",
        manualSpecs = manualSpecs
    }
end

-- Recibe la configuración de red
function Sync:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX or sender == UnitName("player") then return end
    
    local cleanSender = GetCleanName(sender)

    -- Peticiones de sincronización (SYNC_REQ) o envío de talentos (TALENTS)
    if message == "SYNC_REQ" then
        if UnitIsGroupLeader("player") or (addonTable.DelegateName and UnitName("player") == addonTable.DelegateName) then
            Sync:SendFullSync(sender)
        end
        Sync:SendMyTalents()
        return
    end

    if string.match(message, "^TALENTS:") then
        local parts = { strsplit(":", message) }
        local class = parts[2]
        local existing = addonTable.TalentsCache[cleanSender]
        if not existing or existing.source ~= "MANUAL" then
            addonTable.TalentsCache[cleanSender] = {
                class = class,
                spec = "NONE",
                talents = {
                    improvedWisdom = tonumber(parts[3]) or 0,
                    improvedMight = tonumber(parts[4]) or 0,
                    improvedSantuario = (tonumber(parts[5]) or 0) > 0,
                    improvedMark = tonumber(parts[6]) or 0,
                    improvedFort = tonumber(parts[7]) or 0,
                    improvedSpirit = tonumber(parts[8]) or 0
                },
                source = "P2P"
            }
            if addonTable.UI and addonTable.UI.UpdateGrid then
                addonTable.UI:UpdateGrid()
            end
        end
        return
    end

    -- Validar que el emisor de modificaciones tenga permisos
    if not SenderHasPermissions(sender) then return end
    
    -- Deserializar el estado completo
    local success, data = AceSerializer:Deserialize(message)
    if success and type(data) == "table" then
        if data.assignments then
            addonTable.Assignments = data.assignments
        end
        if data.delegate then
            if data.delegate == "NONE" or data.delegate == "" then
                addonTable.DelegateName = nil
            else
                addonTable.DelegateName = data.delegate
            end
        end
        if data.manualSpecs then
            for name, spec in pairs(data.manualSpecs) do
                local class = nil
                if spec == "HOLY" or spec == "PROT" or spec == "RETRI" then
                    class = "PALADIN"
                elseif spec == "RESTO" or spec == "FERAL" or spec == "BALANCE" then
                    class = "DRUID"
                elseif spec == "DISC" or spec == "HOLY" or spec == "SHADOW" then
                    class = "PRIEST"
                end
                
                if class then
                    local talents = {}
                    local defaultTalents = addonTable.Constants.SpecializationTalents[class] and addonTable.Constants.SpecializationTalents[class][spec]
                    if defaultTalents then
                        for k, v in pairs(defaultTalents) do talents[k] = v end
                    end
                    
                    addonTable.TalentsCache[name] = {
                        class = class,
                        spec = spec,
                        talents = talents,
                        source = "MANUAL"
                    }
                end
            end
        end
        
        if addonTable.UI and addonTable.UI.UpdateGrid then
            addonTable.UI:UpdateGrid()
        end
    end
end

-- Registrar canal de AceComm al iniciar
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    Sync:RegisterComm(COMM_PREFIX, function(...) Sync:OnCommReceived(...) end)
end)

-- API Pública de Sincronización

-- Envía la configuración completa (Full State) a toda la raid
function Sync:PushConfiguration()
    if not IsInGroup() then return end
    
    local state = GetFullStateData()
    local serialized = AceSerializer:Serialize(state)
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    Sync:SendCommMessage(COMM_PREFIX, serialized, channel)
end

-- Transmite un cambio individual (en el modelo unificado esto simplemente gatilla un PushConfiguration)
function Sync:SendAssignment(casterClass, casterName, target, spellID)
    if not IsInGroup() then return end
    
    if not addonTable.Assignments[casterClass] then addonTable.Assignments[casterClass] = {} end
    if not addonTable.Assignments[casterClass][casterName] then addonTable.Assignments[casterClass][casterName] = {} end
    
    if spellID == "CLEAR" then
        addonTable.Assignments[casterClass][casterName][target] = nil
    else
        addonTable.Assignments[casterClass][casterName][target] = tonumber(spellID)
    end
    
    Sync:PushConfiguration()
end

-- Transmite la delegación de edición
function Sync:SendDelegate(delegateName)
    if not IsInGroup() then return end
    
    local val = (delegateName and delegateName ~= "") and delegateName or "NONE"
    if val == "NONE" then
        addonTable.DelegateName = nil
    else
        addonTable.DelegateName = val
    end
    
    Sync:PushConfiguration()
end

-- Pide la tabla completa al ingresar al grupo
function Sync:RequestSync()
    if not IsInGroup() then return end
    Sync:SendCommMessage(COMM_PREFIX, "SYNC_REQ", IsInRaid() and "RAID" or "PARTY")
end

-- Envía los propios talentos
function Sync:SendMyTalents()
    if not IsInGroup() then return end
    
    local t = addonTable.Core:GetMyTalents()
    if not t then return end
    
    local msg = string.format("TALENTS:%s:%d:%d:%d:%d:%d:%d", 
        t.class, t.imprWisdom, t.imprMight, t.imprSant, t.imprMark, t.imprFort, t.imprSpirit)
        
    Sync:SendCommMessage(COMM_PREFIX, msg, IsInRaid() and "RAID" or "PARTY")
end

-- Transmite la especialidad establecida manualmente (gatilla un Push de estado completo)
function Sync:SendSetTalents(casterName, spec)
    if not IsInGroup() then return end
    
    local class = nil
    if spec == "HOLY" or spec == "PROT" or spec == "RETRI" then
        class = "PALADIN"
    elseif spec == "RESTO" or spec == "FERAL" or spec == "BALANCE" then
        class = "DRUID"
    elseif spec == "DISC" or spec == "HOLY" or spec == "SHADOW" then
        class = "PRIEST"
    end
    
    if class then
        local talents = {}
        local defaultTalents = addonTable.Constants.SpecializationTalents[class] and addonTable.Constants.SpecializationTalents[class][spec]
        if defaultTalents then
            for k, v in pairs(defaultTalents) do talents[k] = v end
        end
        
        addonTable.TalentsCache[casterName] = {
            class = class,
            spec = spec,
            talents = talents,
            source = "MANUAL"
        }
    end
    
    Sync:PushConfiguration()
end

-- Envía el estado completo por susurro a un jugador
function Sync:SendFullSync(targetPlayer)
    local state = GetFullStateData()
    local serialized = AceSerializer:Serialize(state)
    Sync:SendCommMessage(COMM_PREFIX, serialized, "WHISPER", targetPlayer)
end
