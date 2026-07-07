local addonName, addonTable = ...
local L = addonTable.L

addonTable.TestModeActive = false
addonTable.TestRoster = {}

-- Wrappers locales seguros en addonTable (evitamos desviar _G para no interferir con ElvUI/otros)
function addonTable:IsInRaid()
    if addonTable.TestModeActive then return true end
    return _G.IsInRaid()
end

function addonTable:IsInGroup()
    if addonTable.TestModeActive then return true end
    return _G.IsInGroup()
end

function addonTable:GetNumGroupMembers()
    if addonTable.TestModeActive then
        return #addonTable.TestRoster
    end
    return _G.GetNumGroupMembers()
end

function addonTable:GetRaidRosterInfo(idx)
    if addonTable.TestModeActive then
        local data = addonTable.TestRoster[idx]
        if data then
            return data.name, data.rank, data.subgroup, data.level, data.class, data.fileName, data.zone, data.online, data.isDead, data.role, data.isML
        end
        return nil
    end
    return _G.GetRaidRosterInfo(idx)
end

function addonTable:UnitName(unit)
    if addonTable.TestModeActive then
        if unit == "player" then
            return addonTable.TestRoster[1] and addonTable.TestRoster[1].name or _G.UnitName("player")
        end
        local num = string.match(unit, "^raid(%d+)$")
        if num then
            local idx = tonumber(num)
            return addonTable.TestRoster[idx] and addonTable.TestRoster[idx].name or nil
        end
    end
    return _G.UnitName(unit)
end

function addonTable:UnitClass(unit)
    if addonTable.TestModeActive then
        if unit == "player" then
            return _G.UnitClass("player") -- la clase real
        end
        local num = string.match(unit, "^raid(%d+)$")
        if num then
            local idx = tonumber(num)
            if addonTable.TestRoster[idx] then
                -- Retorna nombre localizado y nombre en inglés en mayúsculas
                local englishClass = addonTable.TestRoster[idx].class
                local localizedClass = L:GetClassName(englishClass) or englishClass
                return localizedClass, englishClass
            end
        end
    end
    return _G.UnitClass(unit)
end

-- Estructuras de Roster Virtuales
local testRosters = {
    [10] = {
        { class = "PALADIN", subgroup = 1, role = "none", spec = "wisdom" },
        { class = "PRIEST", subgroup = 1, role = "none", spec = "fort" },
        { class = "MAGE", subgroup = 1, role = "none" },
        { class = "WARRIOR", subgroup = 1, role = "MAINTANK" },
        { class = "DRUID", subgroup = 1, role = "none", spec = "mark" },
        { class = "ROGUE", subgroup = 2, role = "none" },
        { class = "HUNTER", subgroup = 2, role = "none" },
        { class = "WARLOCK", subgroup = 2, role = "none" },
        { class = "SHAMAN", subgroup = 2, role = "none" }
    },
    [25] = {
        { class = "PALADIN", subgroup = 1, role = "none", spec = "wisdom" },
        { class = "PALADIN", subgroup = 1, role = "MAINTANK", spec = "might" },
        { class = "PRIEST", subgroup = 1, role = "none", spec = "fort" },
        { class = "PRIEST", subgroup = 1, role = "none", spec = "spirit" },
        { class = "MAGE", subgroup = 1, role = "none" },
        { class = "MAGE", subgroup = 2, role = "none" },
        { class = "WARRIOR", subgroup = 2, role = "MAINTANK" },
        { class = "DRUID", subgroup = 2, role = "none", spec = "mark" },
        { class = "DRUID", subgroup = 2, role = "none" },
        { class = "ROGUE", subgroup = 2, role = "none" },
        { class = "ROGUE", subgroup = 3, role = "none" },
        { class = "HUNTER", subgroup = 3, role = "none" },
        { class = "HUNTER", subgroup = 3, role = "none" },
        { class = "WARLOCK", subgroup = 3, role = "none" },
        { class = "WARLOCK", subgroup = 3, role = "none" },
        { class = "SHAMAN", subgroup = 4, role = "none" },
        { class = "SHAMAN", subgroup = 4, role = "none" },
        { class = "WARRIOR", subgroup = 4, role = "none" },
        { class = "PALADIN", subgroup = 4, role = "none", spec = "sant" },
        { class = "PRIEST", subgroup = 5, role = "none" },
        { class = "DRUID", subgroup = 5, role = "none" },
        { class = "SHAMAN", subgroup = 5, role = "none" },
        { class = "MAGE", subgroup = 5, role = "none" },
        { class = "WARLOCK", subgroup = 5, role = "none" }
    }
}

-- Caché local de talentos simulada para el test
addonTable.TalentsCache = {}

function addonTable.Core:StartTestMode(size)
    if size ~= 10 and size ~= 25 then size = 10 end
    
    addonTable.TestModeActive = true
    addonTable.TestRoster = {}
    
    -- El primer miembro de la raid de prueba siempre es el jugador real
    local myRealName = UnitName("player")
    local _, myRealClass = UnitClass("player")
    
    table.insert(addonTable.TestRoster, {
        name = myRealName,
        rank = 0,
        subgroup = 1,
        level = 70,
        class = myRealClass,
        fileName = myRealClass,
        zone = "Ciudad de Shattrath",
        online = true,
        isDead = false,
        role = "none",
        isML = false
    })
    
    -- Añadir talentos del propio jugador local si es aplicable
    addonTable.TalentsCache[myRealName] = {
        class = myRealClass,
        talents = {
            imprWisdom = (myRealClass == "PALADIN") and 5 or 0,
            imprMight = (myRealClass == "PALADIN") and 5 or 0,
            imprSant = (myRealClass == "PALADIN") and 1 or 0,
            imprMark = (myRealClass == "DRUID") and 5 or 0,
            imprFort = (myRealClass == "PRIEST") and 2 or 0,
            imprSpirit = (myRealClass == "PRIEST") and 2 or 0
        }
    }
    
    -- Poblar el roster simulado con la plantilla elegida
    local template = testRosters[size]
    for i, member in ipairs(template) do
        local virtualName = "Test" .. member.class .. i
        table.insert(addonTable.TestRoster, {
            name = virtualName,
            rank = 0,
            subgroup = member.subgroup,
            level = 70,
            class = member.class,
            fileName = member.class,
            zone = "Ciudad de Shattrath",
            online = true,
            isDead = false,
            role = member.role,
            isML = false
        })
        
        -- Cargar talentos en la caché simulada si los define la plantilla
        if member.spec then
            addonTable.TalentsCache[virtualName] = {
                class = member.class,
                talents = {
                    imprWisdom = (member.spec == "wisdom") and 5 or 0,
                    imprMight = (member.spec == "might") and 5 or 0,
                    imprSant = (member.spec == "sant") and 1 or 0,
                    imprMark = (member.spec == "mark") and 5 or 0,
                    imprFort = (member.spec == "fort") and 2 or 0,
                    imprSpirit = (member.spec == "spirit") and 2 or 0
                }
            }
        else
            addonTable.TalentsCache[virtualName] = {
                class = member.class,
                talents = {
                    imprWisdom = 0, imprMight = 0, imprSant = 0,
                    imprMark = 0, imprFort = 0, imprSpirit = 0
                }
            }
        end
    end
    
    print("|cff00ff00[RaidBuffet]|r Modo Test habilitado: Raid " .. size .. " simulada creada.")
    
    if addonTable.UI and addonTable.UI.UpdateGrid then
        addonTable.UI:UpdateGrid()
    end
end

function addonTable.Core:StopTestMode()
    addonTable.TestModeActive = false
    addonTable.TestRoster = {}
    addonTable.TalentsCache = {}
    
    print("|cff00ff00[RaidBuffet]|r Modo Test deshabilitado. Retornando a tu grupo real.")
    
    if addonTable.UI and addonTable.UI.UpdateGrid then
        addonTable.UI:UpdateGrid()
    end
end

function addonTable.Core:ClearTestRoster()
    if not addonTable.TestModeActive then
        print("|cffff0000[RaidBuffet]|r El modo test no está activo.")
        return
    end
    
    local myRealName = UnitName("player")
    local _, myRealClass = UnitClass("player")
    
    addonTable.TestRoster = {
        {
            name = myRealName,
            rank = 0,
            subgroup = 1,
            level = 70,
            class = myRealClass,
            fileName = myRealClass,
            zone = "Ciudad de Shattrath",
            online = true,
            isDead = false,
            role = "none",
            isML = false
        }
    }
    addonTable.TalentsCache = {}
    addonTable.TalentsCache[myRealName] = {
        class = myRealClass,
        talents = {
            imprWisdom = 0, imprMight = 0, imprSant = 0,
            imprMark = 0, imprFort = 0, imprSpirit = 0
        }
    }
    
    print("|cff00ff00[RaidBuffet]|r Roster simulado vaciado. Solo quedas tú en el roster de test.")
    
    if addonTable.UI and addonTable.UI.UpdateGrid then
        addonTable.UI:UpdateGrid()
    end
end

function addonTable.Core:AddTestMember(name, class, subgroup, role, spec)
    if not addonTable.TestModeActive then
        print("|cffff0000[RaidBuffet]|r Activa primero el modo test con /rb test 10 o 25.")
        return
    end
    
    if not name or name == "" then return end
    class = string.upper(class or "WARRIOR")
    subgroup = tonumber(subgroup) or 1
    role = (role == "tank" or role == "t" or role == "MAINTANK") and "MAINTANK" or "none"
    
    table.insert(addonTable.TestRoster, {
        name = name,
        rank = 0,
        subgroup = subgroup,
        level = 70,
        class = class,
        fileName = class,
        zone = "Ciudad de Shattrath",
        online = true,
        isDead = false,
        role = role,
        isML = false
    })
    
    addonTable.TalentsCache[name] = {
        class = class,
        talents = {
            imprWisdom = (spec == "wisdom") and 5 or 0,
            imprMight = (spec == "might") and 5 or 0,
            imprSant = (spec == "sant") and 1 or 0,
            imprMark = (spec == "mark") and 5 or 0,
            imprFort = (spec == "fort") and 2 or 0,
            imprSpirit = (spec == "spirit") and 2 or 0
        }
    }
    
    print("|cff00ff00[RaidBuffet]|r Añadido miembro simulado: " .. name .. " (" .. class .. ") al G" .. subgroup)
    
    if addonTable.UI and addonTable.UI.UpdateGrid then
        addonTable.UI:UpdateGrid()
    end
end

function addonTable.Core:ListTestRoster()
    if not addonTable.TestModeActive then
        print("|cffff0000[RaidBuffet]|r Modo Test inactivo.")
        return
    end
    
    print("Roster de Test Simulado (" .. #addonTable.TestRoster .. " miembros):")
    for i, data in ipairs(addonTable.TestRoster) do
        local talents = addonTable.TalentsCache[data.name] and addonTable.TalentsCache[data.name].talents
        local specStr = ""
        if talents then
            if (talents.imprWisdom or 0) > 0 then specStr = specStr .. " Wisdom" end
            if (talents.imprMight or 0) > 0 then specStr = specStr .. " Might" end
            if (talents.imprSant or 0) > 0 then specStr = specStr .. " Sanctuary" end
            if (talents.imprMark or 0) > 0 then specStr = specStr .. " Mark" end
            if (talents.imprFort or 0) > 0 then specStr = specStr .. " Fortitude" end
            if (talents.imprSpirit or 0) > 0 then specStr = specStr .. " Spirit" end
        end
        print(string.format("  [%d] %s (Clase: %s, Grupo: %d, Rol: %s)%s", 
            i, data.name, data.class, data.subgroup, data.role, specStr ~= "" and (" - Specs:" .. specStr) or ""))
    end
end
