local addonName, addonTable = ...
local L = addonTable.L
local Constants = addonTable.Constants

local Scanner = {}
addonTable.Scanner = Scanner

-- Busca un buff por nombre y comprueba si tiene tiempo de duración suficiente (>= 25%)
local function UnitHasBuff(unit, spellName)
    local name, duration, expirationTime
    if AuraUtil and AuraUtil.FindAuraByName then
        local bName, _, _, _, bDuration, bExpirationTime = AuraUtil.FindAuraByName(spellName, unit, "HELPFUL")
        name = bName
        duration = bDuration
        expirationTime = bExpirationTime
    else
        -- Fallback para versiones más antiguas
        for i = 1, 40 do
            local bName, _, _, _, bDuration, bExpirationTime = UnitBuff(unit, i)
            if not bName then break end
            if bName == spellName then
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
    local mtName = GetPartyAssignment("MAINTANK", unit)
    local uName = UnitName(unit)
    return mtName and uName and mtName == uName
end

-- Busca una bendición pequeña alternativa aprendida por el paladín que no colisione con las superiores de la clase
function Scanner:GetAlternativeBlessingForTank(casterClass, casterName, targetClass)
    if casterClass ~= "PALADIN" then return nil end
    
    -- Obtener bendiciones superiores asignadas por toda la raid a esta clase de tanques
    local activeSpells = {}
    for pName, targets in pairs(addonTable.Assignments["PALADIN"] or {}) do
        for tID, sID in pairs(targets) do
            if tID == targetClass then
                local sName = L:GetSpellInfo(sID)
                if sName then
                    activeSpells[sName] = true
                end
            end
        end
    end
    
    -- Lista de candidatos pequeños (SpellID base para IsSpellKnown)
    -- 20911 (Santuario), 20217 (Reyes), 19740 (Poderío), 19742 (Sabiduría), 19977 (Luz)
    local candidates = { 20911, 20217, 19740, 19742, 19977 }
    for _, altID in ipairs(candidates) do
        if IsSpellKnown(altID) then
            local altName = L:GetSpellInfo(altID)
            if altName then
                -- Comprobar si el nombre del buff (tanto individual como superior) está asignado a la clase
                -- Limpiar el término "superior" / "Superior" para evitar colisión por nombre parcial
                local cleanAltName = string.gsub(altName, " [sS]uperior", "")
                
                local collides = false
                for activeName, _ in pairs(activeSpells) do
                    local cleanActive = string.gsub(activeName, " [sS]uperior", "")
                    if cleanActive == cleanAltName then
                        collides = true
                        break
                    end
                end
                
                if not collides then
                    return altID
                end
            end
        end
    end
    return nil
end

-- Escanea el grupo o banda y devuelve {unit, spellName, playerName} del primer jugador que necesite un buff asignado
function Scanner:GetNextBuffTarget()
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
            
            local spellID = assignments[targetID]
            if spellID then
                local spellName = L:GetSpellInfo(spellID)
                if spellName then
                    -- Comprobar si es la Bendición de Salvación en un Tanque Principal
                    if spellID == 25895 and Scanner:IsMainTank(unit) then
                        -- 1. Primero se bufea la clase con Salvación Superior de forma normal
                        local hasSalv = UnitHasBuff(unit, L:GetSpellInfo(25895)) or UnitHasBuff(unit, L:GetSpellInfo(1038))
                        if not hasSalv then
                            -- Si aún no la tiene, se castea de forma normal
                            local finalUnit = UnitIsUnit(unit, "player") and "player" or unit
                            local playerName = UnitName(unit)
                            return finalUnit, spellName, playerName
                        else
                            -- 2. Si ya tiene Salvación Superior activa, se busca sobrescribirla con la pequeña alternativa
                            local altSpellID = Scanner:GetAlternativeBlessingForTank(myClass, myName, classFileName)
                            if altSpellID then
                                local altSpellName = L:GetSpellInfo(altSpellID)
                                if altSpellName and not UnitHasBuff(unit, altSpellName) then
                                    local finalUnit = UnitIsUnit(unit, "player") and "player" or unit
                                    local playerName = UnitName(unit)
                                    return finalUnit, altSpellName, playerName
                                end
                            end
                        end
                    else
                        -- Comportamiento normal para no-tanques o buffs ordinarios
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
                    if spellName then
                        local targetClass = nil
                        local targetGroup = nil
                        
                        if string.find(targetID, "GROUP_") then
                            targetGroup = tonumber(string.match(targetID, "GROUP_(%d+)"))
                        else
                            targetClass = targetID
                        end
                        
                        local missingPlayers = {}
                        
                        for _, uData in ipairs(units) do
                            local match = false
                            if targetClass and uData.class == targetClass then
                                match = true
                            elseif targetGroup and uData.subgroup == targetGroup then
                                match = true
                            end
                            
                            if match then
                                local isDeadOrGhost = UnitIsDeadOrGhost(uData.unit)
                                local isConnected = UnitIsConnected(uData.unit)
                                
                                if isConnected and not isDeadOrGhost then
                                    -- Caso especial: Salvación en un Tanque Principal
                                    if spellID == 25895 and Scanner:IsMainTank(uData.unit) then
                                        local hasSalv = UnitHasBuff(uData.unit, L:GetSpellInfo(25895)) or UnitHasBuff(uData.unit, L:GetSpellInfo(1038))
                                        if not hasSalv then
                                            -- Aún no tiene la Salvación Superior masiva
                                            table.insert(missingPlayers, uData.name)
                                        else
                                            -- Ya tiene la Salvación Superior masiva. Falta el alternativo para pisarla
                                            local altSpellID = Scanner:GetAlternativeBlessingForTank(casterClass, casterName, uData.class)
                                            if altSpellID then
                                                local altSpellName = L:GetSpellInfo(altSpellID)
                                                if altSpellName and not UnitHasBuff(uData.unit, altSpellName) then
                                                    table.insert(missingPlayers, uData.name .. " (Pisar Salvación con: " .. altSpellName .. ")")
                                                end
                                            else
                                                -- Si no tiene alternativas configurables
                                                table.insert(missingPlayers, uData.name .. " (¡Pisar Salvación!)")
                                            end
                                        end
                                    else
                                        -- Caso normal
                                        local hasBuff = UnitHasBuff(uData.unit, spellName)
                                        if not hasBuff then
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
