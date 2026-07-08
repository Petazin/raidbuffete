local addonName, addonTable = ...
local L = addonTable.L
local Constants = addonTable.Constants

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

local Scanner = {}
addonTable.Scanner = Scanner

local buffEquivalences = nil

local function InitBuffEquivalences()
    buffEquivalences = {}
    
    -- Mapeo de Paladín: Superior -> Pequeña
    local palMapping = {
        [25898] = 20217, -- Reyes superior -> Reyes pequeña
        [25890] = 19977, -- Luz superior -> Luz pequeña
        [27141] = 19740, -- Poderío superior -> Poderío pequeña
        [25895] = 1038,  -- Salvación superior -> Salvación pequeña
        [27143] = 19742, -- Sabiduría superior -> Sabiduría pequeña
        [25899] = 20911  -- Santuario superior -> Santuario pequeña
    }
    for supID, smallID in pairs(palMapping) do
        local supName = GetSpellInfo(supID)
        local smallName = GetSpellInfo(smallID)
        if supName and smallName then
            buffEquivalences[supName] = smallName
        end
    end

    -- Mapeo de Sacerdote: Rezo -> Individual
    local priestMapping = {
        [25392] = 25389, -- Rezo de entereza -> Palabra de poder: entereza
        [39362] = 25433, -- Rezo de protección contra las Sombras -> Protección contra las Sombras
        [32999] = 25312  -- Rezo de espíritu -> Espíritu divino
    }
    for groupID, indID in pairs(priestMapping) do
        local groupName = GetSpellInfo(groupID)
        local indName = GetSpellInfo(indID)
        if groupName and indName then
            buffEquivalences[groupName] = indName
        end
    end

    -- Mapeo cruzado de Mago: Luminosidad <-> Intelecto
    local mageLumi = GetSpellInfo(27127) -- Luminosidad arcana
    local mageIntel = GetSpellInfo(27126) -- Intelecto arcano
    if mageLumi and mageIntel then
        buffEquivalences[mageLumi] = mageIntel
        buffEquivalences[mageIntel] = mageLumi
    end

    -- Mapeo cruzado de Druida: Don <-> Marca
    local druidDon = GetSpellInfo(26991) -- Don de lo Salvaje
    local druidMarca = GetSpellInfo(26990) -- Marca de lo Salvaje
    if druidDon and druidMarca then
        buffEquivalences[druidDon] = druidMarca
        buffEquivalences[druidMarca] = druidDon
    end
end

-- Busca un buff por nombre y comprueba si tiene tiempo de duración suficiente (>= 25%)
local function UnitHasBuff(unit, spellName)
    if not buffEquivalences then
        InitBuffEquivalences()
    end
    
    local altName = buffEquivalences[spellName]
    local name, duration, expirationTime
    
    if AuraUtil and AuraUtil.FindAuraByName then
        local bName, _, _, _, bDuration, bExpirationTime = AuraUtil.FindAuraByName(spellName, unit, "HELPFUL")
        if not bName and altName then
            bName, _, _, _, bDuration, bExpirationTime = AuraUtil.FindAuraByName(altName, unit, "HELPFUL")
        end
        name = bName
        duration = bDuration
        expirationTime = bExpirationTime
    else
        -- Fallback para versiones más antiguas
        local checkSpell = function(bName)
            return bName == spellName or (altName and bName == altName)
        end
        for i = 1, 40 do
            local bName, _, _, _, bDuration, bExpirationTime = UnitBuff(unit, i)
            if not bName then break end
            if checkSpell(bName) then
                name = bName
                duration = bDuration
                expirationTime = bExpirationTime
                break
            end
        end
    end
    
    if not name then
        return false -- No tiene el buff
    end
    
    -- Si tiene duración y le queda menos del 25% del tiempo total, se considera que necesita renovación (devolvemos false)
    if duration and duration > 0 and expirationTime then
        local timeLeft = expirationTime - GetTime()
        if timeLeft / duration < 0.25 then
            return false -- Necesita renovación
        end
    end
    
    return true -- Tiene el buff activo y con tiempo suficiente
end

-- Comprueba si una unidad es Tanque Principal de la raid
function Scanner:IsMainTank(unit)
    -- 1. Doble validación: Comprobar asignación de party nativa
    local mtVal = GetPartyAssignment("MAINTANK", unit)
    if mtVal == true or mtVal == 1 then
        return true
    elseif type(mtVal) == "string" then
        local uName = UnitName(unit)
        if uName then
            local mtClean = string.match(mtVal, "([^%-]+)")
            local uClean = string.match(uName, "([^%-]+)")
            if mtClean == uClean then return true end
        end
    end
    
    -- 2. Doble validación: Comprobar rol de roster de banda si aplica
    if IsInRaid() and string.sub(unit, 1, 4) == "raid" then
        local index = tonumber(string.sub(unit, 5))
        if index then
            local _, _, _, _, _, _, _, _, _, role = GetRaidRosterInfo(index)
            if role == "MAINTANK" then return true end
        end
    end
    
    return false
end

local lastWhisperTimes = {}  -- Cooldown de 60 segundos para evitar spam por tanque
local pendingWhispers = {}   -- Registro de tanques detectados con Salvación { [name] = detectTime }
local GRACE_PERIOD = 10      -- Período de gracia de 10 segundos antes de enviar el susurro
local WHISPER_COOLDOWN = 60  -- Cooldown de 60 segundos entre susurros al mismo tanque

-- Escanea la raid buscando tanques con la Bendición de Salvación activa y les susurra tras un período de gracia
function Scanner:CheckTankSalvationAlerts()
    if not IsInGroup() then
        if next(pendingWhispers) then pendingWhispers = {} end
        return
    end
    
    local _, myClass = UnitClass("player")
    if myClass ~= "PALADIN" then return end
    
    local myName = UnitName("player")
    local assignments = addonTable.Assignments["PALADIN"] and addonTable.Assignments["PALADIN"][myName]
    if not assignments then return end
    
    -- Recopilar todas las unidades de la raid
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, classFileName = GetRaidRosterInfo(i)
            if name and classFileName then
                name = string.match(name, "([^%-]+)")
                table.insert(units, { unit = "raid" .. i, name = name, class = classFileName })
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, classFileName = UnitClass(unit)
            if name and classFileName then
                name = string.match(name, "([^%-]+)")
                table.insert(units, { unit = unit, name = name, class = classFileName })
            end
        end
        local name = UnitName("player")
        local _, classFileName = UnitClass("player")
        if name and classFileName then
            name = string.match(name, "([^%-]+)")
            table.insert(units, { unit = "player", name = name, class = classFileName })
        end
    end
    
    local now = GetTime()
    
    for _, uData in ipairs(units) do
        if Scanner:IsMainTank(uData.unit) then
            -- Solo avisa si este paladín local le tiene asignado algún buff a su clase o a él individualmente
            local hasAssignment = assignments[uData.class] ~= nil or assignments[uData.name] ~= nil
            if hasAssignment then
                local spellSalvationLarge = L:GetSpellInfo(25895)
                local spellSalvationSmall = L:GetSpellInfo(1038)
                
                local hasSalv = (spellSalvationLarge and UnitHasBuff(uData.unit, spellSalvationLarge)) or 
                               (spellSalvationSmall and UnitHasBuff(uData.unit, spellSalvationSmall))
                               
                if hasSalv then
                    if not pendingWhispers[uData.name] then
                        -- Registrar la detección inicial
                        pendingWhispers[uData.name] = now
                    else
                        -- Ya estaba registrado, comprobar si se cumplió el período de gracia
                        local elapsed = now - pendingWhispers[uData.name]
                        if elapsed >= GRACE_PERIOD then
                            local lastTime = lastWhisperTimes[uData.name] or 0
                            if now - lastTime > WHISPER_COOLDOWN then
                                SendChatMessage("[RaidBuffet]: Eres Tanque Principal y tienes activa la Bendición de Salvación. Por favor, cancélala (/cancelaura Bendición de salvación).", "WHISPER", nil, uData.name)
                                lastWhisperTimes[uData.name] = now
                                -- Reiniciar el tiempo de detección para evitar spam en el siguiente ciclo de cooldown
                                pendingWhispers[uData.name] = now
                            end
                        end
                    end
                else
                    -- Si ya no tiene Salvación, limpiar el registro pendiente inmediatamente
                    pendingWhispers[uData.name] = nil
                end
            end
        end
    end
end

-- Escanea el grupo o banda y devuelve {unit, spellName, playerName} del primer jugador que necesite un buff asignado
function Scanner:GetNextBuffTarget()
    -- Ejecutar alerta de salvación en tanques en segundo plano
    Scanner:CheckTankSalvationAlerts()

    local _, myClass = UnitClass("player")
    local myName = UnitName("player")
    
    local assignments = addonTable.Assignments[myClass] and addonTable.Assignments[myClass][myName]
    if not assignments then return nil end -- No hay nada asignado a este jugador
    
    local targetType = Constants.TargetTypes[myClass]
    
    -- Recopilar unidades
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name then
                table.insert(units, {unit = "raid" .. i, subgroup = subgroup})
            end
        end
    elseif IsInGroup() then
        table.insert(units, {unit = "player", subgroup = 1})
        for i = 1, GetNumSubgroupMembers() do
            table.insert(units, {unit = "party" .. i, subgroup = 1})
        end
    else
        table.insert(units, {unit = "player", subgroup = 1})
    end
    
    for _, data in ipairs(units) do
        local unit = data.unit
        local _, classFileName = UnitClass(unit)
        local isDeadOrGhost = UnitIsDeadOrGhost(unit)
        local isConnected = UnitIsConnected(unit)
        
        if classFileName and isConnected and not isDeadOrGhost then
            local targetID
            if targetType == "CLASS" then
                targetID = classFileName
            else
                targetID = "GROUP_" .. data.subgroup
            end
            
            -- Prioridad de buff individual sobre el de la clase
            local spellID = assignments[targetID]
            local pName = UnitName(unit)
            if pName then
                pName = string.match(pName, "([^%-]+)")
                if myClass == "PALADIN" and assignments[pName] then
                    spellID = assignments[pName]
                end
            end
            
            if spellID and spellID ~= "CLEAR" and spellID ~= 0 then
                local spellName = L:GetSpellInfo(spellID)
                if spellName then
                    local hasBuff = UnitHasBuff(unit, spellName)
                    if not hasBuff then
                        local finalUnit = UnitIsUnit(unit, "player") and "player" or unit
                        local playerName = UnitName(unit)
                        return finalUnit, spellName, playerName
                    end
                end
            end
        end
    end
    
    return nil -- Todos tienen sus buffs
end

-- Obtiene un reporte de buffs pendientes para todos los personajes de la raid según asignaciones
function Scanner:GetMissingBuffsReport()
    local report = {}
    
    -- 1. Recopilar la lista de todas las unidades reales en el grupo/banda
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup, _, _, classFileName = GetRaidRosterInfo(i)
            if name and classFileName then
                name = string.match(name, "([^%-]+)") -- Quitar nombre del reino
                table.insert(units, { unit = "raid" .. i, name = name, class = classFileName, subgroup = subgroup })
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, classFileName = UnitClass(unit)
            if name and classFileName then
                name = string.match(name, "([^%-]+)")
                table.insert(units, { unit = unit, name = name, class = classFileName, subgroup = 1 })
            end
        end
        local name = UnitName("player")
        local _, classFileName = UnitClass("player")
        if name and classFileName then
            name = string.match(name, "([^%-]+)")
            table.insert(units, { unit = "player", name = name, class = classFileName, subgroup = 1 })
        end
    else
        local name = UnitName("player")
        local _, classFileName = UnitClass("player")
        if name and classFileName then
            name = string.match(name, "([^%-]+)")
            table.insert(units, { unit = "player", name = name, class = classFileName, subgroup = 1 })
        end
    end

    -- 2. Recorrer la tabla de asignaciones globales
    for casterClass, casters in pairs(addonTable.Assignments) do
        for casterName, targets in pairs(casters) do
            local casterExists = false
            for _, uData in ipairs(units) do
                if uData.name == casterName then
                    casterExists = true
                    break
                end
            end
            
            if not IsInGroup() and casterName == UnitName("player") then
                casterExists = true
            end
            
            if casterExists then
                for targetID, spellID in pairs(targets) do
                    local spellName = L:GetSpellInfo(spellID)
                    if spellName and spellID ~= "CLEAR" and spellID ~= 0 then
                        local targetClass = nil
                        local targetGroup = nil
                        local targetPlayer = nil
                        
                        local isClass = false
                        for _, c in ipairs(Constants.ClassOrder) do
                            if c == targetID then
                                isClass = true
                                break
                            end
                        end
                        
                        if string.find(targetID, "GROUP_") then
                            targetGroup = tonumber(string.match(targetID, "GROUP_(%d+)"))
                          elseif isClass then
                              targetClass = targetID
                          else
                              targetPlayer = targetID
                          end
                        
                        local missingPlayers = {}
                        
                        for _, uData in ipairs(units) do
                            local match = false
                            if targetPlayer and uData.name == targetPlayer then
                                match = true
                            elseif targetClass and uData.class == targetClass then
                                -- Si hay asignación individual para este jugador por este caster, ignoramos la regla de clase
                                local hasIndividual = targets[uData.name] ~= nil
                                if not hasIndividual then
                                    match = true
                                end
                            elseif targetGroup and uData.subgroup == targetGroup then
                                match = true
                            end
                            
                            if match then
                                local isDeadOrGhost = UnitIsDeadOrGhost(uData.unit)
                                local isConnected = UnitIsConnected(uData.unit)
                                
                                if isConnected and not isDeadOrGhost then
                                    local hasBuff = UnitHasBuff(uData.unit, spellName)
                                    if not hasBuff then
                                        local isMT = Scanner:IsMainTank(uData.unit)
                                        local isSalv = (spellID == 25895 or spellID == 1038)
                                        if isMT and isSalv then
                                            table.insert(missingPlayers, uData.name .. " (¡Tanque con Salvación!)")
                                        else
                                            table.insert(missingPlayers, uData.name)
                                        end
                                    end
                                end
                            end
                        end
                        
                        if #missingPlayers > 0 then
                            table.insert(report, {
                                casterClass = casterClass,
                                casterName = casterName,
                                spellID = spellID,
                                spellName = spellName,
                                targetID = targetID,
                                missingPlayers = missingPlayers
                            })
                        end
                    end
                end
            end
        end
    end
    
    return report
end

-- Comprueba si hay peligro de que un tanque reciba Salvación de clase
function Scanner:HasSalvationTankHazard(casterName, targetClass)
    if not addonTable.Assignments["PALADIN"] or not addonTable.Assignments["PALADIN"][casterName] then
        return false
    end
    local spell = addonTable.Assignments["PALADIN"][casterName][targetClass]
    if spell ~= 25895 then
        return false
    end
    
    -- Recopilar jugadores de esa clase
    local roster = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            if name and class == targetClass then
                name = string.match(name, "([^%-]+)")
                table.insert(roster, { name = name, unit = "raid" .. i })
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            if name and class == targetClass then
                name = string.match(name, "([^%-]+)")
                table.insert(roster, { name = name, unit = unit })
            end
        end
        local name = UnitName("player")
        local _, class = UnitClass("player")
        if name and class == targetClass then
            name = string.match(name, "([^%-]+)")
            table.insert(roster, { name = name, unit = "player" })
        end
    else
        local name = UnitName("player")
        local _, class = UnitClass("player")
        if name and class == targetClass then
            name = string.match(name, "([^%-]+)")
            table.insert(roster, { name = name, unit = "player" })
        end
    end
    
    for _, pData in ipairs(roster) do
        if Scanner:IsMainTank(pData.unit) then
            local indSpell = addonTable.Assignments["PALADIN"][casterName][pData.name]
            -- Si no tiene individual, o la individual es Salvación (1038 / 25895 / CLEAR que significa sin bendición pero no anula la de clase si el paladín vuelve a tirar clase)
            if not indSpell or indSpell == 25895 or indSpell == 1038 or indSpell == "CLEAR" then
                return true, pData.name
            end
        end
    end
    return false
end
