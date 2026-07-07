local addonName, addonTable = ...
local L = addonTable.L
local Constants = addonTable.Constants
local Scanner = addonTable.Scanner
local Sync = addonTable.Sync

-- Redirecciones para el Modo Test simulado (local a este archivo)
local IsInRaid = function() return addonTable:IsInRaid() end
local IsInGroup = function() return addonTable:IsInGroup() end
local GetNumGroupMembers = function() return addonTable:GetNumGroupMembers() end
local GetRaidRosterInfo = function(idx) return addonTable:GetRaidRosterInfo(idx) end
local UnitName = function(unit) return addonTable:UnitName(unit) end
local UnitClass = function(unit) return addonTable:UnitClass(unit) end

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
            table.insert(tanks, { name = pData.name, class = pData.class })
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
            
            local isTank = false
            for _, tData in ipairs(tanks) do
                if tData.name == palName then
                    isTank = true
                    break
                end
            end
            
            local palData = { name = palName, spec = spec, isTank = isTank }
            
            if spec == "HOLY" then table.insert(holyPals, palData)
            elseif spec == "PROT" then table.insert(protPals, palData)
            elseif spec == "RETRI" then table.insert(retriPals, palData)
            else table.insert(otherPals, palData)
            end
        end
        
        -- Unificar en una lista ordenada por especialidad para prioridades
        local sortedPals = {}
        for _, p in ipairs(holyPals) do table.insert(sortedPals, p) end
        for _, p in ipairs(protPals) do table.insert(sortedPals, p) end
        for _, p in ipairs(retriPals) do table.insert(sortedPals, p) end
        for _, p in ipairs(otherPals) do table.insert(sortedPals, p) end
        
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
            
            table.insert(proposal.summary, string.format("|cfff58cbaPaladín|r: |cffddaa77%s|r (%s) asignado a bendiciones superiores.", pal.name, pal.spec))
            
        elseif numPals == 2 then
            -- 2 Paladines
            local palA = sortedPals[1] -- Holy/Prot preferido
            local palB = sortedPals[2] -- Retri/Other preferido
            
            -- SI existe un paladín tanque, que sea el que tira Salvación (palB)
            if palA.isTank and not palB.isTank then
                palA, palB = palB, palA
            end
            
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
            
            table.insert(proposal.summary, string.format("|cfff58cbaPaladines|r: |cffddaa77%s|r (Wisdom/Kings sup) y |cffddaa77%s|r (Salvation sup).", palA.name, palB.name))
            
        else
            -- 3 o más Paladines
            local palA = sortedPals[1] -- Holy
            local palB = sortedPals[2] -- Prot
            local palC = sortedPals[3] -- Retri
            
            -- SI existe un paladín tanque, que sea el que tira Salvación (palC)
            if palA.isTank and not palC.isTank then
                palA, palC = palC, palA
            elseif palB.isTank and not palC.isTank then
                palB, palC = palC, palB
            end
            
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
        
        -- ========================================================================
        -- POST-PROCESADOR DINÁMICO DE TANQUES E HÍBRIDOS (PALADINES)
        -- ========================================================================
        for palName, assignments in pairs(proposal.assignments["PALADIN"]) do
            -- Obtener la especialidad de este paladín
            local palSpec = "NONE"
            for _, pData in ipairs(sortedPals) do
                if pData.name == palName then
                    palSpec = pData.spec
                    break
                end
            end
            
            for _, pData in ipairs(roster) do
                local pName = pData.name
                local pClass = pData.class
                local pUnit = pData.unit
                local assignedClassSpell = assignments[pClass]
                
                -- Determinar rol del personaje individual
                local isCaster = (pClass == "MAGE" or pClass == "WARLOCK" or pClass == "PRIEST")
                local isMelee = (pClass == "WARRIOR" or pClass == "ROGUE" or pClass == "HUNTER")
                local pSpec = addonTable.TalentsCache[pName] and addonTable.TalentsCache[pName].spec or "NONE"
                
                if pClass == "DRUID" then
                    if pSpec == "FERAL" then isMelee = true else isCaster = true end
                elseif pClass == "SHAMAN" then
                    if pSpec == "ENHANCEMENT" then isMelee = true else isCaster = true end
                elseif pClass == "PALADIN" then
                    if pSpec == "PROT" or pSpec == "RETRI" then isMelee = true else isCaster = true end
                end
                
                local isTank = Scanner:IsMainTank(pUnit)
                
                if isTank then
                    -- ============================================================
                    -- REGLA 1: EL TANQUE NUNCA RECIBE SALVACIÓN
                    -- ============================================================
                    if assignedClassSpell == 25895 then -- Greater Blessing of Salvation
                        -- Identificar bendiciones superiores (Greater) excluidas
                        local excludedSpells = {}
                        for otherPalName, otherAssignments in pairs(proposal.assignments["PALADIN"]) do
                            if otherPalName ~= palName then
                                local otherSpell = otherAssignments[pClass]
                                if otherSpell then
                                    if otherSpell == 25898 then excludedSpells[20217] = true
                                    elseif otherSpell == 27141 then excludedSpells[19740] = true
                                    elseif otherSpell == 27143 then excludedSpells[19742] = true
                                    elseif otherSpell == 25899 then excludedSpells[20911] = true
                                    elseif otherSpell == 25890 then excludedSpells[19977] = true
                                    end
                                end
                            end
                        end
                        
                        -- Seleccionar el mejor reemplazo individual
                        local selectedSpell = nil
                        if palSpec == "PROT" and not excludedSpells[20911] then selectedSpell = 20911
                        elseif not excludedSpells[19977] then selectedSpell = 19977
                        elseif not excludedSpells[20217] then selectedSpell = 20217
                        elseif not excludedSpells[19742] and (pClass == "DRUID" or pClass == "PALADIN") then selectedSpell = 19742
                        elseif not excludedSpells[19740] then selectedSpell = 19740
                        end
                        
                        if not selectedSpell then
                            selectedSpell = (palSpec == "PROT") and 20911 or 20217
                        end
                        assignments[pName] = selectedSpell
                    else
                        assignments[pName] = nil
                    end
                    
                elseif isCaster and assignedClassSpell == 27141 then
                    -- ============================================================
                    -- REGLA 2: CASTER HÍBRIDO RECIBE PODERÍO SUPERIOR (INÚTIL)
                    -- ============================================================
                    local excludedSpells = {}
                    for otherPalName, otherAssignments in pairs(proposal.assignments["PALADIN"]) do
                        if otherPalName ~= palName then
                            local otherSpell = otherAssignments[pClass]
                            if otherSpell then
                                if otherSpell == 25898 then excludedSpells[20217] = true
                                elseif otherSpell == 27141 then excludedSpells[19740] = true
                                elseif otherSpell == 27143 then excludedSpells[19742] = true
                                elseif otherSpell == 25899 then excludedSpells[20911] = true
                                elseif otherSpell == 25890 then excludedSpells[19977] = true
                                end
                            end
                        end
                    end
                    
                    local selectedSpell = nil
                    if not excludedSpells[19742] then selectedSpell = 19742
                    elseif not excludedSpells[20217] then selectedSpell = 20217
                    elseif not excludedSpells[19977] then selectedSpell = 19977
                    end
                    
                    if selectedSpell then
                        assignments[pName] = selectedSpell
                    else
                        assignments[pName] = nil
                    end
                    
                elseif isMelee and assignedClassSpell == 27143 then
                    -- ============================================================
                    -- REGLA 3: MELEE HÍBRIDO RECIBE SABIDURÍA SUPERIOR (INÚTIL)
                    -- ============================================================
                    local excludedSpells = {}
                    for otherPalName, otherAssignments in pairs(proposal.assignments["PALADIN"]) do
                        if otherPalName ~= palName then
                            local otherSpell = otherAssignments[pClass]
                            if otherSpell then
                                if otherSpell == 25898 then excludedSpells[20217] = true
                                elseif otherSpell == 27141 then excludedSpells[19740] = true
                                elseif otherSpell == 27143 then excludedSpells[19742] = true
                                elseif otherSpell == 25899 then excludedSpells[20911] = true
                                elseif otherSpell == 25890 then excludedSpells[19977] = true
                                end
                            end
                        end
                    end
                    
                    local selectedSpell = nil
                    if not excludedSpells[19740] then selectedSpell = 19740
                    elseif not excludedSpells[20217] then selectedSpell = 20217
                    elseif not excludedSpells[19977] then selectedSpell = 19977
                    end
                    
                    if selectedSpell then
                        assignments[pName] = selectedSpell
                    else
                        assignments[pName] = nil
                    end
                else
                    assignments[pName] = nil
                end
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
