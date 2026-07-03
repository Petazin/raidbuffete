local addonName, addonTable = ...
local L = addonTable.L
local Constants = addonTable.Constants
local Scanner = addonTable.Scanner
local Sync = addonTable.Sync

local Proposal = {}
addonTable.Proposal = Proposal

-- Helper para obtener la lista de jugadores de una clase y rol
local function GetRaidRoster()
    local roster = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
            if name and class then
                name = string.match(name, "([^%-]+)")
                table.insert(roster, { name = name, class = class, unit = "raid" .. i, subgroup = subgroup })
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            if name and class then
                name = string.match(name, "([^%-]+)")
                table.insert(roster, { name = name, class = class, unit = unit, subgroup = 1 })
            end
        end
        local name = UnitName("player")
        local _, class = UnitClass("player")
        if name and class then
            name = string.match(name, "([^%-]+)")
            table.insert(roster, { name = name, class = class, unit = "player", subgroup = 1 })
        end
    else
        local name = UnitName("player")
        local _, class = UnitClass("player")
        if name and class then
            name = string.match(name, "([^%-]+)")
            table.insert(roster, { name = name, class = class, unit = "player", subgroup = 1 })
        end
    end
    return roster
end

-- Genera la propuesta óptima de buffs basada en el roster y talentos cached
function Proposal:GenerateProposal()
    local proposal = {
        assignments = {},
        summary = {}
    }
    
    local roster = GetRaidRoster()
    
    -- 1. Identificar casters (Paladines, Sacerdotes, Druidas, Magos)
    local paladins = {}
    local priests = {}
    local druids = {}
    local mages = {}
    local tanks = {}
    
    for _, pData in ipairs(roster) do
        local isMT = Scanner:IsMainTank(pData.unit)
        if isMT then
            table.insert(tanks, pData.name)
        end
        
        if pData.class == "PALADIN" then
            table.insert(paladins, pData.name)
        elseif pData.class == "PRIEST" then
            table.insert(priests, pData.name)
        elseif pData.class == "DRUID" then
            table.insert(druids, pData.name)
        elseif pData.class == "MAGE" then
            table.insert(mages, pData.name)
        end
    end
    
    -- Identificar qué subgrupos de raid tienen jugadores activos y ordenarlos
    local activeGroups = {}
    for _, pData in ipairs(roster) do
        if pData.subgroup then
            activeGroups[pData.subgroup] = true
        end
    end
    -- Si no hay grupos activos (ej: fuera de grupo), por defecto activar el grupo 1
    if not next(activeGroups) then
        activeGroups[1] = true
    end
    
    local sortedGroups = {}
    for gNum, _ in pairs(activeGroups) do
        table.insert(sortedGroups, gNum)
    end
    table.sort(sortedGroups)
    
    -- ========================================================================
    -- PROPUESTA DRUIDAS, SACERDOTES Y MAGOS (REPARTO EQUITATIVO)
    -- ========================================================================
    -- Druidas: Don de lo Salvaje (Grupo)
    if #druids > 0 then
        if not proposal.assignments["DRUID"] then proposal.assignments["DRUID"] = {} end
        for _, dName in ipairs(druids) do
            proposal.assignments["DRUID"][dName] = {}
        end
        
        -- Buscar el mejor druida para el summary
        local bestDruid = druids[1]
        for _, dName in ipairs(druids) do
            local cached = addonTable.TalentsCache[dName]
            if cached and cached.talents and cached.talents.improvedMark then
                bestDruid = dName
                break
            end
        end
        
        -- Repartir equitativamente los grupos activos (Round-Robin)
        for idx, gNum in ipairs(sortedGroups) do
            local dIdx = ((idx - 1) % #druids) + 1
            local dName = druids[dIdx]
            proposal.assignments["DRUID"][dName]["GROUP_" .. gNum] = 26991 -- Don de lo Salvaje (Grupo)
        end
        
        if #druids == 1 then
            table.insert(proposal.summary, string.format("|cffffee00Druida|r: |cffddaa77%s|r asignado a Don de lo Salvaje (Grupo).", bestDruid))
        else
            table.insert(proposal.summary, string.format("|cffffee00Druidas|r: Repartidos %d grupos entre %d druidas.", #sortedGroups, #druids))
        end
    end
    
    -- Sacerdotes: Rezo de Entereza y Espíritu Divino Mejorado (Grupo)
    if #priests > 0 then
        if not proposal.assignments["PRIEST"] then proposal.assignments["PRIEST"] = {} end
        for _, pName in ipairs(priests) do
            proposal.assignments["PRIEST"][pName] = {}
        end
        
        if #priests == 1 then
            local pName = priests[1]
            for _, gNum in ipairs(sortedGroups) do
                proposal.assignments["PRIEST"][pName]["GROUP_" .. gNum] = 25392 -- Rezo de Entereza (Grupo)
            end
            
            -- Asignar Espíritu Divino (Individual) a casters/healers
            for _, pData in ipairs(roster) do
                local c = pData.class
                local isCaster = (c == "MAGE" or c == "WARLOCK" or c == "PRIEST")
                if not isCaster and c == "DRUID" then
                    local cachedD = addonTable.TalentsCache and addonTable.TalentsCache[pData.name]
                    if cachedD and (cachedD.spec == "RESTO" or cachedD.spec == "BALANCE") then
                        isCaster = true
                    end
                elseif not isCaster and c == "SHAMAN" then
                    local isTank = Scanner:IsMainTank(pData.unit)
                    if not isTank then
                        isCaster = true
                    end
                end
                
                if isCaster then
                    proposal.assignments["PRIEST"][pName][pData.name] = 25312 -- Espíritu Divino (Individual)
                end
            end
            
            table.insert(proposal.summary, string.format("|cffffffffSacerdote|r: |cffddddff%s|r asignado a Rezo de Entereza y Espíritu Divino individual a casters.", pName))
        elseif #priests == 2 then
            local pA = priests[1]
            local pB = priests[2]
            for _, gNum in ipairs(sortedGroups) do
                proposal.assignments["PRIEST"][pA]["GROUP_" .. gNum] = 25392 -- Entereza
                proposal.assignments["PRIEST"][pB]["GROUP_" .. gNum] = 32999 -- Espíritu
            end
            table.insert(proposal.summary, string.format("|cffffffffSacerdotes|r: |cffddddff%s|r (Entereza) y |cffddddff%s|r (Espíritu).", pA, pB))
        else
            -- 3 o más sacerdotes:
            -- Repartir Entereza entre los N-1 sacerdotes
            local fortPriests = {}
            for i = 1, #priests - 1 do
                table.insert(fortPriests, priests[i])
            end
            local spiritPriest = priests[#priests]
            
            -- Repartir Entereza
            for idx, gNum in ipairs(sortedGroups) do
                local pIdx = ((idx - 1) % #fortPriests) + 1
                local pName = fortPriests[pIdx]
                proposal.assignments["PRIEST"][pName]["GROUP_" .. gNum] = 25392
            end
            
            -- El último sacerdote bufa Espíritu a todos los grupos
            for _, gNum in ipairs(sortedGroups) do
                proposal.assignments["PRIEST"][spiritPriest]["GROUP_" .. gNum] = 32999
            end
            
            table.insert(proposal.summary, string.format("|cffffffffSacerdotes|r: %d asignados a Entereza, |cffddddff%s|r a Espíritu.", #fortPriests, spiritPriest))
        end
    end
    
    -- Magos: Luminosidad Arcana (Grupo)
    if #mages > 0 then
        if not proposal.assignments["MAGE"] then proposal.assignments["MAGE"] = {} end
        for _, mName in ipairs(mages) do
            proposal.assignments["MAGE"][mName] = {}
        end
        
        -- Repartir equitativamente los grupos activos (Round-Robin)
        for idx, gNum in ipairs(sortedGroups) do
            local mIdx = ((idx - 1) % #mages) + 1
            local mName = mages[mIdx]
            proposal.assignments["MAGE"][mName]["GROUP_" .. gNum] = 27127 -- Luminosidad Arcana (Grupo)
        end
        
        if #mages == 1 then
            table.insert(proposal.summary, string.format("|cff69ccf0Mago|r: |cff69ccf0%s|r asignado a Luminosidad Arcana.", mages[1]))
        else
            table.insert(proposal.summary, string.format("|cff69ccf0Magos|r: Repartidos %d grupos entre %d magos.", #sortedGroups, #mages))
        end
    end
    
    -- ========================================================================
    -- PROPUESTA DE PALADINES (NÚCLEO COMBINATORIO)
    -- ========================================================================
    if #paladins > 0 then
        if not proposal.assignments["PALADIN"] then proposal.assignments["PALADIN"] = {} end
        
        -- Clasificar paladines según especialidad manual de talentos
        local holyPals = {}
        local protPals = {}
        local retriPals = {}
        local otherPals = {}
        
        for _, palName in ipairs(paladins) do
            local cached = addonTable.TalentsCache[palName]
            local spec = cached and cached.spec or "NONE"
            
            if spec == "HOLY" then table.insert(holyPals, palName)
            elseif spec == "PROT" then table.insert(protPals, palName)
            elseif spec == "RETRI" then table.insert(retriPals, palName)
            else table.insert(otherPals, palName)
            end
        end
        
        -- Unificar en una lista ordenada por especialidad para prioridades
        local sortedPals = {}
        for _, p in ipairs(holyPals) do table.insert(sortedPals, { name = p, spec = "HOLY" }) end
        for _, p in ipairs(protPals) do table.insert(sortedPals, { name = p, spec = "PROT" }) end
        for _, p in ipairs(retriPals) do table.insert(sortedPals, { name = p, spec = "RETRI" }) end
        for _, p in ipairs(otherPals) do table.insert(sortedPals, { name = p, spec = "NONE" }) end
        
        -- Spells IDs:
        -- Kings (Reyes) = 20217, sup = 25898
        -- Light (Luz) = 19977, sup = 25890
        -- Might (Poderío) = 19740, sup = 27141
        -- Salvation (Salvación) = 1038, sup = 25895
        -- Wisdom (Sabiduría) = 19742, sup = 27143
        -- Sanctuary (Santuario) = 20911, sup = 25899
        
        -- Definir qué clases son Casters o Físicos
        local casterClasses = { ["MAGE"] = true, ["PRIEST"] = true, ["WARLOCK"] = true, ["DRUID"] = true }
        local meleeClasses = { ["WARRIOR"] = true, ["ROGUE"] = true, ["HUNTER"] = true, ["SHAMAN"] = true, ["PALADIN"] = true }
        
        local numPals = #sortedPals
        
        -- Spells IDs (Superiores de clase en TBC):
        -- Kings (Reyes) = 25898
        -- Light (Luz) = 25890
        -- Might (Poderío) = 27141
        -- Salvation (Salvación) = 25895
        -- Wisdom (Sabiduría) = 27143
        -- Sanctuary (Santuario) = 25899
        
        -- Definir qué clases son Casters o Físicos
        local casterClasses = { ["MAGE"] = true, ["PRIEST"] = true, ["WARLOCK"] = true, ["DRUID"] = true }
        local meleeClasses = { ["WARRIOR"] = true, ["ROGUE"] = true, ["HUNTER"] = true, ["SHAMAN"] = true, ["PALADIN"] = true }
        
        -- Clases que se benefician de Salvación de clase completa (DPS puros / Casters y Chamanes)
        local salvationClasses = { ["MAGE"] = true, ["WARLOCK"] = true, ["PRIEST"] = true, ["SHAMAN"] = true, ["ROGUE"] = true, ["HUNTER"] = true }
        
        local numPals = #sortedPals
        
        if numPals == 1 then
            -- 1 Paladín
            local pal = sortedPals[1]
            proposal.assignments["PALADIN"][pal.name] = {}
            local t = proposal.assignments["PALADIN"][pal.name]
            
            -- Por defecto, un solo paladín prioriza Sabiduría a casters, Poderío a melees y Kings a tanques
            for _, class in ipairs(Constants.ClassOrder) do
                if casterClasses[class] then
                    t[class] = (pal.spec == "HOLY") and 27143 or 25898 -- Sabiduría superior si es Holy, si no Reyes superior
                else
                    t[class] = (pal.spec == "RETRI") and 27141 or 25898 -- Poderío superior si es Retri, si no Reyes superior
                end
            end
            
            -- Tanques individuales: Santuario si es Prot
            if pal.spec == "PROT" then
                for _, tName in ipairs(tanks) do
                    t[tName] = 20911 -- Santuario individual (pequeño)
                end
            end
            
            table.insert(proposal.summary, string.format("|cfff58cbaPaladín|r: |cffddaa77%s|r (%s) asignado a bendiciones superiores.", pal.name, pal.spec))
            
        elseif numPals == 2 then
            -- 2 Paladines
            local palA = sortedPals[1] -- Holy/Prot preferido
            local palB = sortedPals[2] -- Retri/Other preferido
            
            proposal.assignments["PALADIN"][palA.name] = {}
            proposal.assignments["PALADIN"][palB.name] = {}
            local tA = proposal.assignments["PALADIN"][palA.name]
            local tB = proposal.assignments["PALADIN"][palB.name]
            
            -- Distribución:
            -- A (Casters -> Wisdom, Melees -> Kings)
            -- B (Todos -> Salvación Superior)
            for _, class in ipairs(Constants.ClassOrder) do
                if casterClasses[class] then
                    tA[class] = 27143 -- Sabiduría Superior
                else
                    tA[class] = 25898 -- Reyes Superior
                end
                
                tB[class] = 25895 -- Salvación Superior (Todos los DPS/Healers híbridos la reciben de clase)
            end
            
            -- Tanques individuales: Reyes de A y Santuario/Luz de B (Pisa la Salvación de clase de B)
            for _, tName in ipairs(tanks) do
                tA[tName] = 20217 -- Reyes pequeña
                tB[tName] = (palB.spec == "PROT" or palA.spec == "PROT") and 20911 or 19977 -- Santuario o Luz pequeña
            end
            
            table.insert(proposal.summary, string.format("|cfff58cbaPaladines|r: |cffddaa77%s|r (Wisdom/Kings sup) y |cffddaa77%s|r (Salvation sup).", palA.name, palB.name))
            
        else
            -- 3 o más Paladines
            local palA = sortedPals[1] -- Holy
            local palB = sortedPals[2] -- Prot
            local palC = sortedPals[3] -- Retri
            
            proposal.assignments["PALADIN"][palA.name] = {}
            proposal.assignments["PALADIN"][palB.name] = {}
            proposal.assignments["PALADIN"][palC.name] = {}
            local tA = proposal.assignments["PALADIN"][palA.name]
            local tB = proposal.assignments["PALADIN"][palB.name]
            local tC = proposal.assignments["PALADIN"][palC.name]
            
            -- A bufa: Casters -> Wisdom Superior, Melees -> Kings Superior
            -- B bufa: Casters -> Kings Superior, Melees -> Might Superior
            -- C bufa: Todos -> Salvation Superior
            for _, class in ipairs(Constants.ClassOrder) do
                if casterClasses[class] then
                    tA[class] = 27143 -- Sabiduría Superior
                    tB[class] = 25898 -- Reyes Superior
                else
                    tA[class] = 25898 -- Reyes Superior
                    tB[class] = 27141 -- Poderío Superior
                end
                
                tC[class] = 25895 -- Salvación Superior (Para todos los DPS/Healers de clase)
            end
            
            -- Tanques individuales: Luz de A, Santuario de B y Reyes de C (Pisa la Salvación de C)
            for _, tName in ipairs(tanks) do
                tA[tName] = 19977 -- Luz pequeña
                tB[tName] = 20911 -- Santuario pequeña
                tC[tName] = 20217 -- Reyes pequeña
            end
            
            table.insert(proposal.summary, string.format("|cfff58cbaPaladines|r: |cffddaa77%s|r (Wisdom), |cffddaa77%s|r (Kings/Might), |cffddaa77%s|r (Salvation) sup.", palA.name, palB.name, palC.name))
            
            -- Paladines extra bufan Luz Superior a todos
            if numPals > 3 then
                for idx = 4, numPals do
                    local palX = sortedPals[idx]
                    proposal.assignments["PALADIN"][palX.name] = {}
                    local tX = proposal.assignments["PALADIN"][palX.name]
                    for _, class in ipairs(Constants.ClassOrder) do
                        tX[class] = 25890 -- Luz Superior
                    end
                end
                table.insert(proposal.summary, string.format("|cffaaaaaaPaladines extra bufan Luz Superior.|r"))
            end
        end
    end
    
    return proposal
end

-- Aplica la propuesta sobrescribiendo las asignaciones del addon y enviándolas por P2P
function Proposal:ApplyProposal(proposal)
    if not proposal or not proposal.assignments then return end
    
    -- Reemplazar asignaciones locales
    for class, casters in pairs(proposal.assignments) do
        addonTable.Assignments[class] = {}
        for casterName, targets in pairs(casters) do
            addonTable.Assignments[class][casterName] = {}
            for targetID, spellID in pairs(targets) do
                addonTable.Assignments[class][casterName][targetID] = spellID
                
                -- Depuración local en chat (desactivada en producción)
                -- print(string.format("|cff00ffff[RaidBuffet Debug]|r Guardado local: [%s][%s][%s] = %s", tostring(class), tostring(casterName), tostring(targetID), tostring(spellID)))
                
                -- Enviar por P2P a la raid de forma síncrona
                Sync:SendAssignment(class, casterName, targetID, spellID)
            end
        end
    end
    
    print("|cff00ff00[RaidBuffet]|r Propuesta de asignación aplicada y sincronizada con la raid.")
end
