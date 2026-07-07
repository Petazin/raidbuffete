local addonName, addonTable = ...
local Sync = {}
addonTable.Sync = Sync

-- Nombre del delegado activo en el grupo
addonTable.DelegateName = nil

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")

-- Helper para limpiar nombre de reino
local function GetCleanName(name)
    if not name then return nil end
    return string.match(name, "([^%-]+)")
end

-- Comprueba si el emisor de un mensaje de red tiene permisos de edición (Líder o Delegado)
local function SenderHasPermissions(sender)
    if addonTable.TestModeActive then return true end
    if not IsInGroup() then return true end
    local cleanSender = GetCleanName(sender)
    
    -- Si el emisor es el delegado activo
    if addonTable.DelegateName and cleanSender == addonTable.DelegateName then
        return true
    end
    
    -- Buscar el rango del emisor en el roster de la raid
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name then
                local cleanName = GetCleanName(name)
                if cleanName == cleanSender then
                    -- rank 1 es Asistente (Raid Officer), rank 2 es Líder
                    if rank == 1 or rank == 2 then
                        return true
                    end
                    break
                end
            end
        end
    elseif IsInGroup() then
        -- En grupo normal de 5 personas (party), solo el líder de grupo tiene permisos
        local leaderName = nil
        if UnitIsGroupLeader("player") then
            leaderName = UnitName("player")
        else
            for i = 1, GetNumSubgroupMembers() do
                if UnitIsGroupLeader("party" .. i) then
                    leaderName = UnitName("party" .. i)
                    break
                end
            end
        end
        if cleanSender == leaderName then
            return true
        end
    end
    
    return false
end

frame:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
    if prefix ~= "RaidBuffet" then return end
    
    -- Ignorar nuestros propios ecos
    if GetCleanName(sender) == UnitName("player") then return end
    
    local textParts = { strsplit(":", text) }
    local cmd = textParts[1]
    
    -- Validar permisos de emisor antes de procesar cualquier comando de modificación
    if (cmd == "ASSIGN" or cmd == "DELEGATE" or cmd == "SET_TALENTS") and not SenderHasPermissions(sender) then
        return
    end
    
    if cmd == "ASSIGN" then
        local casterClass = textParts[2]
        local casterName = textParts[3]
        local target = textParts[4]
        local spellID = textParts[5]
        
        if not addonTable.Assignments[casterClass] then addonTable.Assignments[casterClass] = {} end
        if not addonTable.Assignments[casterClass][casterName] then addonTable.Assignments[casterClass][casterName] = {} end
        
        if spellID == "CLEAR" then
            addonTable.Assignments[casterClass][casterName][target] = nil
        else
            addonTable.Assignments[casterClass][casterName][target] = tonumber(spellID)
        end
        
        if addonTable.UI and addonTable.UI.UpdateGrid then
            addonTable.UI:UpdateGrid()
        end
        
    elseif cmd == "SYNC_REQ" then
        -- Respondemos únicamente si somos los líderes para no saturar la red con respuestas múltiples
        if UnitIsGroupLeader("player") then
            Sync:SendFullSync(sender)
        end
        -- Enviar también nuestros propios talentos en respuesta
        Sync:SendMyTalents()
        
    elseif cmd == "DELEGATE" then
        local delegateName = textParts[2]
        if delegateName == "NONE" or delegateName == "" then
            addonTable.DelegateName = nil
        else
            addonTable.DelegateName = delegateName
        end
        
        if addonTable.UI and addonTable.UI.UpdateGrid then
            addonTable.UI:UpdateGrid()
        end
        
    elseif cmd == "TALENTS" then
        local senderName = GetCleanName(sender)
        local class = textParts[2]
        
        -- Evitamos sobreescribir si la fuente de datos local ya es MANUAL (preferimos la decisión del líder)
        local existing = addonTable.TalentsCache[senderName]
        if not existing or existing.source ~= "MANUAL" then
            addonTable.TalentsCache[senderName] = {
                class = class,
                spec = "NONE",
                talents = {
                    improvedWisdom = tonumber(textParts[3]) or 0,
                    improvedMight = tonumber(textParts[4]) or 0,
                    improvedSantuario = (tonumber(textParts[5]) or 0) > 0,
                    improvedMark = tonumber(textParts[6]) or 0,
                    improvedFort = tonumber(textParts[7]) or 0,
                    improvedSpirit = tonumber(textParts[8]) or 0
                },
                source = "P2P"
            }
            if addonTable.UI and addonTable.UI.UpdateGrid then
                addonTable.UI:UpdateGrid()
            end
        end
        
    elseif cmd == "SET_TALENTS" then
        local casterName = textParts[2]
        local spec = textParts[3]
        
        local class = nil
        if addonTable.TalentsCache[casterName] then
            class = addonTable.TalentsCache[casterName].class
        else
            if spec == "HOLY" or spec == "PROT" or spec == "RETRI" then
                class = "PALADIN"
            elseif spec == "RESTO" or spec == "FERAL" or spec == "BALANCE" then
                class = "DRUID"
            elseif spec == "DISC" or spec == "HOLY" or spec == "SHADOW" then
                -- Para discernir sacerdote Holy de paladín Holy
                class = "PRIEST"
            end
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
            if addonTable.UI and addonTable.UI.UpdateGrid then
                addonTable.UI:UpdateGrid()
            end
        end
    end
end)

-- API Pública de Sincronización

-- Transmite un cambio de buff a toda la raid
function Sync:SendAssignment(casterClass, casterName, target, spellID)
    if not IsInGroup() then return end
    
    local val = spellID or "CLEAR"
    local msg = string.format("ASSIGN:%s:%s:%s:%s", casterClass, casterName, target, tostring(val))
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage("RaidBuffet", msg, channel)
end

-- Transmite la delegación de edición de asignaciones
function Sync:SendDelegate(delegateName)
    if not IsInGroup() then return end
    
    local val = (delegateName and delegateName ~= "") and delegateName or "NONE"
    local msg = "DELEGATE:" .. val
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage("RaidBuffet", msg, channel)
end

-- Pide la tabla completa al líder cuando recién ingresas a la raid
function Sync:RequestSync()
    if not IsInGroup() then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage("RaidBuffet", "SYNC_REQ:1", channel)
    
    -- Al solicitar sync, también enviamos nuestros propios talentos para que los demás nos conozcan
    Sync:SendMyTalents()
end

-- Envía nuestros propios talentos a toda la raid/grupo
function Sync:SendMyTalents()
    if not IsInGroup() then return end
    
    local t = addonTable.Core:GetMyTalents()
    if not t then return end
    
    local msg = string.format("TALENTS:%s:%d:%d:%d:%d:%d:%d", 
        t.class, t.imprWisdom, t.imprMight, t.imprSant, t.imprMark, t.imprFort, t.imprSpirit)
        
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage("RaidBuffet", msg, channel)
end

-- Transmite la especialidad establecida manualmente por el líder
function Sync:SendSetTalents(casterName, spec)
    if not IsInGroup() then return end
    
    local msg = string.format("SET_TALENTS:%s:%s", casterName, spec)
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage("RaidBuffet", msg, channel)
end

-- El líder envía el estado completo (Full Sync) al jugador que lo solicitó
function Sync:SendFullSync(targetPlayer)
    -- Enviar asignaciones
    for cClass, casters in pairs(addonTable.Assignments) do
        for cName, targets in pairs(casters) do
            for tgt, sID in pairs(targets) do
                local msg = string.format("ASSIGN:%s:%s:%s:%s", cClass, cName, tgt, tostring(sID))
                C_ChatInfo.SendAddonMessage("RaidBuffet", msg, "WHISPER", targetPlayer)
            end
        end
    end
    
    -- Enviar delegado actual
    local delegateMsg = "DELEGATE:" .. (addonTable.DelegateName or "NONE")
    C_ChatInfo.SendAddonMessage("RaidBuffet", delegateMsg, "WHISPER", targetPlayer)
    
    -- Enviar especialidades manuales configuradas de la caché
    for name, data in pairs(addonTable.TalentsCache) do
        if data.source == "MANUAL" then
            local msg = string.format("SET_TALENTS:%s:%s", name, data.spec)
            C_ChatInfo.SendAddonMessage("RaidBuffet", msg, "WHISPER", targetPlayer)
        end
    end
end
