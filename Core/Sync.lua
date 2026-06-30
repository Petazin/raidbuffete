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
    if not IsInGroup() then return true end
    local cleanSender = GetCleanName(sender)
    
    -- Obtener el nombre del líder de la banda/grupo
    local leaderName = nil
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name and rank == 2 then -- Rank 2 es Líder
                leaderName = GetCleanName(name)
                break
            end
        end
    elseif IsInGroup() then
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
    end
    
    if cleanSender == leaderName then
        return true
    end
    
    -- Si el emisor es el delegado activo
    if addonTable.DelegateName and cleanSender == addonTable.DelegateName then
        return true
    end
    
    return false
end

frame:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
    if prefix ~= "RBUFFET" then return end
    
    -- Ignorar nuestros propios ecos
    if GetCleanName(sender) == UnitName("player") then return end
    
    local textParts = { strsplit(":", text) }
    local cmd = textParts[1]
    
    -- Validar permisos de emisor antes de procesar cualquier comando de modificación
    if (cmd == "ASSIGN" or cmd == "DELEGATE") and not SenderHasPermissions(sender) then
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
    end
end)

-- API Pública de Sincronización

-- Transmite un cambio de buff a toda la raid
function Sync:SendAssignment(casterClass, casterName, target, spellID)
    if not IsInGroup() then return end
    
    local val = spellID or "CLEAR"
    local msg = string.format("ASSIGN:%s:%s:%s:%s", casterClass, casterName, target, tostring(val))
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage("RBUFFET", msg, channel)
end

-- Transmite la delegación de edición de asignaciones
function Sync:SendDelegate(delegateName)
    if not IsInGroup() then return end
    
    local val = (delegateName and delegateName ~= "") and delegateName or "NONE"
    local msg = "DELEGATE:" .. val
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage("RBUFFET", msg, channel)
end

-- Pide la tabla completa al líder cuando recién ingresas a la raid
function Sync:RequestSync()
    if not IsInGroup() then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage("RBUFFET", "SYNC_REQ:1", channel)
end

-- El líder envía el estado completo (Full Sync) al jugador que lo solicitó
function Sync:SendFullSync(targetPlayer)
    -- Enviar asignaciones
    for cClass, casters in pairs(addonTable.Assignments) do
        for cName, targets in pairs(casters) do
            for tgt, sID in pairs(targets) do
                local msg = string.format("ASSIGN:%s:%s:%s:%s", cClass, cName, tgt, tostring(sID))
                C_ChatInfo.SendAddonMessage("RBUFFET", msg, "WHISPER", targetPlayer)
            end
        end
    end
    
    -- Enviar delegado actual
    local delegateMsg = "DELEGATE:" .. (addonTable.DelegateName or "NONE")
    C_ChatInfo.SendAddonMessage("RBUFFET", delegateMsg, "WHISPER", targetPlayer)
end
