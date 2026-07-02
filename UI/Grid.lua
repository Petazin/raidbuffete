local addonName, addonTable = ...
local L = addonTable.L
local Sync = addonTable.Sync
local Constants = addonTable.Constants
local Scanner = addonTable.Scanner

local Grid = CreateFrame("Frame", "RaidBuffetGridFrame", UIParent, "BackdropTemplate")
addonTable.UI = Grid

Grid:SetSize(520, 300)
Grid:SetPoint("CENTER", UIParent, "CENTER")
Grid:SetMovable(true)
Grid:EnableMouse(true)
Grid:RegisterForDrag("LeftButton")
Grid:SetScript("OnDragStart", Grid.StartMoving)
Grid:SetScript("OnDragStop", Grid.StopMovingOrSizing)
Grid:Hide()

Grid:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
Grid:SetBackdropColor(0.06, 0.06, 0.06, 0.94)
Grid:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

Grid.header = CreateFrame("Frame", nil, Grid, "BackdropTemplate")
Grid.header:SetSize(520, 24)
Grid.header:SetPoint("TOPLEFT", Grid, "TOPLEFT", 0, 0)
Grid.header:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
Grid.header:SetBackdropColor(0.12, 0.12, 0.12, 1)
Grid.header:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

Grid.header:EnableMouse(true)
Grid.header:RegisterForDrag("LeftButton")
Grid.header:SetScript("OnDragStart", function() Grid:StartMoving() end)
Grid.header:SetScript("OnDragStop", function() Grid:StopMovingOrSizing() end)

Grid.title = Grid.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
Grid.title:SetPoint("LEFT", 10, 0)
Grid.title:SetText("RaidBuffet - Asignaciones")
Grid.title:SetTextColor(0.8, 0.6, 0.2)

Grid.closeBtn = CreateFrame("Button", nil, Grid.header, "BackdropTemplate")
Grid.closeBtn:SetSize(16, 16)
Grid.closeBtn:SetPoint("RIGHT", -6, 0)
Grid.closeBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
Grid.closeBtn:SetBackdropColor(0.2, 0.1, 0.1, 1)
Grid.closeBtn:SetBackdropBorderColor(0.3, 0.15, 0.15, 1)
Grid.closeBtn.text = Grid.closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Grid.closeBtn.text:SetPoint("CENTER", 0, 0)
Grid.closeBtn.text:SetText("X")
Grid.closeBtn.text:SetTextColor(0.8, 0.3, 0.3)
Grid.closeBtn:SetScript("OnClick", function() Grid:Hide() end)
Grid.closeBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.4, 0.15, 0.15, 1)
end)
Grid.closeBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.2, 0.1, 0.1, 1)
end)

local showAllCheck = CreateFrame("CheckButton", "RaidBuffetShowAllCheck", Grid, "UICheckButtonTemplate")
showAllCheck:SetPoint("BOTTOMLEFT", 10, 5)
_G[showAllCheck:GetName() .. "Text"]:SetText("Mostrar todas las clases")
showAllCheck:SetScript("OnClick", function(self)
    if RaidBuffetDB then RaidBuffetDB.ShowAllClasses = self:GetChecked() end
    Grid:UpdateGrid()
end)

-- Botón para abrir la ventana flotante de reportes de faltantes
local reportBtn = CreateFrame("Button", "RaidBuffetReportBtn", Grid, "BackdropTemplate")
reportBtn:SetSize(80, 22)
reportBtn:SetPoint("BOTTOMLEFT", showAllCheck, "BOTTOMRIGHT", 140, 5)
reportBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
reportBtn:SetBackdropColor(0.14, 0.14, 0.14, 1)
reportBtn:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)

reportBtn.text = reportBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
reportBtn.text:SetPoint("CENTER", 0, 0)
reportBtn.text:SetText("Reporte")

reportBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.22, 0.22, 0.22, 1)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
end)
reportBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.14, 0.14, 0.14, 1)
    self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
end)
reportBtn:SetScript("OnClick", function()
    if RaidBuffetReportFrame then
        if RaidBuffetReportFrame:IsShown() then
            RaidBuffetReportFrame:Hide()
        else
            RaidBuffetReportFrame:Show()
        end
    end
end)

-- ============================================================================
-- BOTÓN MAESTRO DE AUTO-CAST Y SCROLL DE RATÓN
-- ============================================================================
-- Se crea el botón físico en la UI (puede estar oculto o visible)
local castBtn = addonTable.ClickCast:CreateSecureButton(Grid, "RaidBuffetUIBtn", 32, nil, nil)
castBtn:SetPoint("BOTTOMRIGHT", -10, 5)

local castLbl = Grid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
castLbl:SetPoint("RIGHT", castBtn, "LEFT", -10, 0)
castLbl:SetText("Cargando\nAuto-Cast...")
castLbl:SetJustifyH("RIGHT")
castLbl:SetTextColor(1, 0.8, 0)

-- Conectamos el botón al motor dinámico de ClickCast
addonTable.ClickCast:SetMasterButton(castBtn, castLbl)

-- Bindear la rueda del ratón sobre la ventana principal
-- Solo funciona fuera de combate por restricciones de Blizzard
Grid:EnableMouseWheel(true)
Grid:SetScript("OnMouseWheel", function(self, delta)
    if InCombatLockdown() then return end
    
    -- Simulamos un clic izquierdo en el botón seguro
    -- No podemos llamar a Click() directamente si está protegido, pero como estamos fuera de combate
    -- y propagamos el evento desde un frame inseguro a uno seguro, Blizzard a veces lo bloquea.
    -- Lo ideal para el MouseWheel es usar un binding nativo invisible (OverrideBindingClick) cuando el ratón entra.
end)

Grid:SetScript("OnEnter", function(self)
    if not InCombatLockdown() then
        -- Sobrescribir la rueda del ratón temporalmente
        SetOverrideBindingClick(self, true, "MOUSEWHEELUP", "RaidBuffetAutoCastBtn", "LeftButton")
        SetOverrideBindingClick(self, true, "MOUSEWHEELDOWN", "RaidBuffetAutoCastBtn", "LeftButton")
    end
end)

Grid:SetScript("OnLeave", function(self)
    if not InCombatLockdown() then
        -- Limpiar todos los bindings temporales de este frame
        ClearOverrideBindings(self)
    end
end)

Grid.rows = {}

-- Comprueba si el jugador actual tiene permisos de edición (Líder de grupo o Delegado)
local function HasEditPermissions()
    if not IsInGroup() then return true end
    if UnitIsGroupLeader("player") then return true end
    if addonTable.DelegateName and addonTable.DelegateName == UnitName("player") then return true end
    return false
end

-- ============================================================================
-- EVENTOS DE TOOLTIP EN CELDAS (CON IDENTIFICACIÓN DE TANQUES)
-- ============================================================================
local function OnCellEnter(self)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1) -- Hover Glow dorado suave
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    
    local displayName = self.targetID
    if string.find(self.targetID, "GROUP_") then
        local gNum = string.match(self.targetID, "GROUP_(%d+)")
        displayName = "Grupo " .. gNum
    else
        displayName = L:GetClassName(self.targetID) or self.targetID
    end
    
    local targetType = Constants.TargetTypes[self.casterClass]
    if targetType == "CLASS" then
        GameTooltip:AddLine("Miembros de la clase: " .. displayName, 1, 0.8, 0)
    else
        GameTooltip:AddLine("Miembros del " .. displayName, 1, 0.8, 0)
    end
    GameTooltip:AddLine(" ")
    
    -- Recopilar los jugadores asignados a esta clase/grupo
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup, _, _, classFileName = GetRaidRosterInfo(i)
            if name and classFileName then
                name = string.match(name, "([^%-]+)")
                if (targetType == "CLASS" and classFileName == self.targetID) or
                   (targetType == "GROUP" and "GROUP_" .. subgroup == self.targetID) then
                    table.insert(units, { name = name, class = classFileName, unit = "raid" .. i })
                end
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, classFileName = UnitClass(unit)
            if name and classFileName then
                name = string.match(name, "([^%-]+)")
                if (targetType == "CLASS" and classFileName == self.targetID) or
                   (targetType == "GROUP" and self.targetID == "GROUP_1") then
                    table.insert(units, { name = name, class = classFileName, unit = unit })
                end
            end
        end
        local name = UnitName("player")
        local _, classFileName = UnitClass("player")
        if name and classFileName then
            name = string.match(name, "([^%-]+)")
            if (targetType == "CLASS" and classFileName == self.targetID) or
               (targetType == "GROUP" and self.targetID == "GROUP_1") then
                table.insert(units, { name = name, class = classFileName, unit = "player" })
            end
        end
    else
        local name = UnitName("player")
        local _, classFileName = UnitClass("player")
        if name and classFileName then
            name = string.match(name, "([^%-]+)")
            if (targetType == "CLASS" and classFileName == self.targetID) or
               (targetType == "GROUP" and self.targetID == "GROUP_1") then
                table.insert(units, { name = name, class = classFileName, unit = "player" })
            end
        end
    end
    
    if #units == 0 then
        GameTooltip:AddLine("Ningún jugador en esta categoría.", 0.5, 0.5, 0.5)
    else
        for _, uData in ipairs(units) do
            local color = GetClassColorObj(uData.class)
            local mtName = GetPartyAssignment("MAINTANK", uData.unit)
            local isMT = (mtName ~= nil and mtName == uData.name)
            local dispName = uData.name
            if isMT then
                dispName = "|cff00ffff[T]|r " .. dispName
            end
            GameTooltip:AddDoubleLine(dispName, isMT and "|cff00ffffTanque Principal|r" or "", color.r, color.g, color.b, 0, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function OnCellLeave(self)
    local assignedSpell = nil
    if addonTable.Assignments[self.casterClass] and addonTable.Assignments[self.casterClass][self.casterName] then
        assignedSpell = addonTable.Assignments[self.casterClass][self.casterName][self.targetID]
    end
    if assignedSpell then
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    else
        self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
    GameTooltip:Hide()
end

local function GetNextViableSpell(casterClass, targetClass, currentSpell)
    local spellList = Constants.BuffDB[casterClass]
    if not spellList then return "CLEAR" end
    
    local options = { "CLEAR" }
    for _, sID in ipairs(spellList) do
        local viability = Constants.ClassViability[sID]
        -- Si no hay viabilidad definida (no es Paladín) o si la clase destino es viable o si es un subgrupo (GROUP_X)
        if not viability or viability[targetClass] or string.find(targetClass, "GROUP_") then
            table.insert(options, sID)
        end
    end
    
    local curIdx = 1
    local lookupVal = currentSpell or "CLEAR"
    for i, opt in ipairs(options) do
        if opt == lookupVal then
            curIdx = i
            break
        end
    end
    
    local nextIdx = curIdx + 1
    if nextIdx > #options then nextIdx = 1 end
    return options[nextIdx]
end

local function OnCellClick(self, button)
    if not HasEditPermissions() then
        print("|cffff0000[RaidBuffet]|r No tienes permisos de edición. Solo el Líder o el Co-Asignador Delegado pueden modificar asignaciones.")
        return
    end

    local spellList = Constants.BuffDB[self.casterClass]
    if not spellList then return end

    if not addonTable.Assignments[self.casterClass] then addonTable.Assignments[self.casterClass] = {} end
    if not addonTable.Assignments[self.casterClass][self.casterName] then addonTable.Assignments[self.casterClass][self.casterName] = {} end

    if button == "RightButton" then
        if IsShiftKeyDown() then
            for targetID, _ in pairs(addonTable.Assignments[self.casterClass][self.casterName]) do
                addonTable.Assignments[self.casterClass][self.casterName][targetID] = nil
                Sync:SendAssignment(self.casterClass, self.casterName, targetID, "CLEAR")
            end
        else
            addonTable.Assignments[self.casterClass][self.casterName][self.targetID] = nil
            Sync:SendAssignment(self.casterClass, self.casterName, self.targetID, "CLEAR")
        end
        Grid:UpdateGrid()
    elseif button == "LeftButton" then
        local currentSpell = addonTable.Assignments[self.casterClass][self.casterName][self.targetID]
        local nextVal = GetNextViableSpell(self.casterClass, self.targetID, currentSpell)
        
        if IsShiftKeyDown() and self.casterClass == "PALADIN" then
            if nextVal == "CLEAR" then
                for targetID, _ in pairs(addonTable.Assignments[self.casterClass][self.casterName]) do
                    addonTable.Assignments[self.casterClass][self.casterName][targetID] = nil
                    Sync:SendAssignment(self.casterClass, self.casterName, targetID, "CLEAR")
                end
            else
                local viability = Constants.ClassViability[nextVal]
                if viability then
                    for _, targetClass in ipairs(Constants.ClassOrder) do
                        if viability[targetClass] then
                            addonTable.Assignments[self.casterClass][self.casterName][targetClass] = nextVal
                            Sync:SendAssignment(self.casterClass, self.casterName, targetClass, nextVal)
                        end
                    end
                end
            end
            Grid:UpdateGrid()
            return
        else
            if nextVal == "CLEAR" then
                addonTable.Assignments[self.casterClass][self.casterName][self.targetID] = nil
                Sync:SendAssignment(self.casterClass, self.casterName, self.targetID, "CLEAR")
            else
                addonTable.Assignments[self.casterClass][self.casterName][self.targetID] = nextVal
                Sync:SendAssignment(self.casterClass, self.casterName, self.targetID, nextVal)
            end
            Grid:UpdateGrid()
        end
    end
end

local function OnCellMouseWheel(self, delta)
    if not HasEditPermissions() then return end

    local spellList = Constants.BuffDB[self.casterClass]
    if not spellList then return end

    if not addonTable.Assignments[self.casterClass] then addonTable.Assignments[self.casterClass] = {} end
    if not addonTable.Assignments[self.casterClass][self.casterName] then addonTable.Assignments[self.casterClass][self.casterName] = {} end

    local currentSpell = addonTable.Assignments[self.casterClass][self.casterName][self.targetID]
    
    local options = { "CLEAR" }
    for _, sID in ipairs(spellList) do
        table.insert(options, sID)
    end
    
    local curIdx = 1
    local lookupVal = currentSpell or "CLEAR"
    for i, opt in ipairs(options) do
        if opt == lookupVal then
            curIdx = i
            break
        end
    end
    
    if delta > 0 then
        curIdx = curIdx + 1
        if curIdx > #options then curIdx = 1 end
    else
        curIdx = curIdx - 1
        if curIdx < 1 then curIdx = #options end
    end
    
    local nextVal = options[curIdx]
    if nextVal == "CLEAR" then
        addonTable.Assignments[self.casterClass][self.casterName][self.targetID] = nil
        Sync:SendAssignment(self.casterClass, self.casterName, self.targetID, "CLEAR")
    else
        addonTable.Assignments[self.casterClass][self.casterName][self.targetID] = nextVal
        Sync:SendAssignment(self.casterClass, self.casterName, self.targetID, nextVal)
    end
    
    Grid:UpdateGrid()
end

-- Función segura para obtener el color de clase (Compatibilidad TBC/Anniversary/Modern)
function GetClassColorObj(classFileName)
    if C_ClassColor and C_ClassColor.GetClassColor then
        return C_ClassColor.GetClassColor(classFileName)
    elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFileName] then
        return RAID_CLASS_COLORS[classFileName]
    end
    return {r = 1, g = 1, b = 1} -- Fallback blanco
end

local function GetClassColorHex(classFileName)
    local color = GetClassColorObj(classFileName)
    return string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end

-- ============================================================================
-- ELEMENTOS DE LA CASILLA DE DELEGADO (CO-ASIGNADOR CON AUTOCOMPLETADO)
-- ============================================================================
local delegateContainer = CreateFrame("Frame", "RaidBuffetDelegateContainer", Grid)
delegateContainer:SetSize(150, 24)

local delegateLbl = delegateContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
delegateLbl:SetPoint("LEFT", 0, 0)
delegateLbl:SetText("Co-Asig:")

local delegateEdit = CreateFrame("EditBox", "RaidBuffetDelegateEdit", delegateContainer, "InputBoxTemplate")
delegateEdit:SetSize(75, 20)
delegateEdit:SetPoint("LEFT", delegateLbl, "RIGHT", 5, 0)
delegateEdit:SetAutoFocus(false)
delegateEdit:SetMaxLetters(12)

-- Obtiene el listado de asistentes y líderes de la raid actual
local function GetRaidAssistants()
    local names = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name and (rank == 1 or rank == 2) then -- 1 = Asistente, 2 = Líder
                name = string.match(name, "([^%-]+)")
                table.insert(names, name)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local name = UnitName("party" .. i)
            if name then
                table.insert(names, name)
            end
        end
        table.insert(names, UnitName("player"))
    else
        table.insert(names, UnitName("player"))
    end
    return names
end

delegateEdit:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then return end
    local text = self:GetText()
    if text == "" then return end
    
    local textLower = string.lower(text)
    local candidates = GetRaidAssistants()
    for _, name in ipairs(candidates) do
        if string.sub(string.lower(name), 1, string.len(text)) == textLower then
            self:SetText(name)
            self:HighlightText(string.len(text), string.len(name))
            break
        end
    end
end)

delegateEdit:SetScript("OnEnterPressed", function(self)
    local name = self:GetText()
    name = string.gsub(name, "%s+", "")
    if name == "" then name = nil end
    
    addonTable.DelegateName = name
    Sync:SendDelegate(name)
    self:ClearFocus()
    Grid:UpdateGrid()
end)

delegateEdit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    Grid:UpdateGrid()
end)

function Grid:UpdateGrid()
    local success, err = pcall(function()
        local showAll = showAllCheck:GetChecked()
        local _, myClass = UnitClass("player")
        
        if not Grid.headers then Grid.headers = {} end
        if not Grid.playerRows then Grid.playerRows = {} end
        
        for _, header in ipairs(Grid.headers) do header:Hide() end
        for _, row in ipairs(Grid.playerRows) do row:Hide() end
        
        local yOffset = -35
        local headerIndex = 1
        local playerRowIndex = 1
        
        local classesToDraw = {}
        if showAll then
            classesToDraw = {"PALADIN", "PRIEST", "MAGE", "DRUID"}
        else
            table.insert(classesToDraw, myClass)
        end
        
        -- 1. Construir el Roster actual
        local roster = {}
        local isMTMap = {} -- Mapa rápido para ver si el caster es Tanque Principal
        
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                local name, _, _, _, _, classFileName = GetRaidRosterInfo(i)
                if name and classFileName then
                    name = string.match(name, "([^%-]+)")
                    if not roster[classFileName] then roster[classFileName] = {} end
                    table.insert(roster[classFileName], name)
                    
                    local mtName = GetPartyAssignment("MAINTANK", "raid" .. i)
                    if mtName and mtName == name then
                        isMTMap[name] = true
                    end
                end
            end
        elseif IsInGroup() then
            for i = 1, GetNumSubgroupMembers() do
                local unit = "party" .. i
                local name = UnitName(unit)
                local _, classFileName = UnitClass(unit)
                if name and classFileName then
                    name = string.match(name, "([^%-]+)")
                    if not roster[classFileName] then roster[classFileName] = {} end
                    table.insert(roster[classFileName], name)
                    
                    local mtName = GetPartyAssignment("MAINTANK", unit)
                    if mtName and mtName == name then
                        isMTMap[name] = true
                    end
                end
            end
            local name = UnitName("player")
            local _, classFileName = UnitClass("player")
            if name and classFileName then
                name = string.match(name, "([^%-]+)")
                if not roster[classFileName] then roster[classFileName] = {} end
                table.insert(roster[classFileName], name)
                
                local mtName = GetPartyAssignment("MAINTANK", "player")
                if mtName and mtName == name then
                    isMTMap[name] = true
                end
            end
        else
            local name = UnitName("player")
            local _, classFileName = UnitClass("player")
            if name and classFileName then
                name = string.match(name, "([^%-]+)")
                if not roster[classFileName] then roster[classFileName] = {} end
                table.insert(roster[classFileName], name)
            end
        end
        
        Grid.lastDebugRoster = roster
        Grid.lastDebugClasses = classesToDraw
        
        -- 2. Calcular número máximo de subgrupos reales activos en la banda (Mínimo 5, Máximo 8)
        local maxRaidGroups = 5
        if IsInRaid() then
            local maxSub = 1
            for i = 1, GetNumGroupMembers() do
                local _, _, subgroup = GetRaidRosterInfo(i)
                if subgroup and subgroup > maxSub then
                    maxSub = subgroup
                end
            end
            maxRaidGroups = math.max(5, maxSub)
        end
        
        -- 3. Renderizar Cabeceras y Filas
        for _, classType in ipairs(classesToDraw) do
            local playersOfClass = roster[classType]
            
            if Constants.BuffDB[classType] and playersOfClass and #playersOfClass > 0 then
                local header = Grid.headers[headerIndex]
                if not header then
                    header = CreateFrame("Frame", nil, Grid)
                    header:SetSize(430, 20)
                    
                    header.name = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    header.name:SetPoint("LEFT", 10, 0)
                    header.name:SetWidth(80)
                    header.name:SetJustifyH("LEFT")
                    
                    header.labels = {}
                    for i = 1, 9 do
                        local btn = CreateFrame("Button", nil, header)
                        btn:SetSize(28, 20)
                        btn:SetPoint("LEFT", header.name, "RIGHT", (i-1)*34, 0)
                        
                        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        btn.text:SetPoint("CENTER", 0, 0)
                        
                        btn:RegisterForClicks("RightButtonUp")
                        
                        header.labels[i] = btn
                    end
                    Grid.headers[headerIndex] = header
                end
                
                header:SetPoint("TOPLEFT", Grid, "TOPLEFT", 0, yOffset)
                header.name:SetText(L:GetClassName(classType))
                
                local targetType = Constants.TargetTypes[classType]
                local maxCols = (targetType == "CLASS") and 9 or maxRaidGroups
                
                for i = 1, 9 do
                    local btn = header.labels[i]
                    if i <= maxCols then
                        local targetID
                        if targetType == "CLASS" then
                            targetID = Constants.ClassOrder[i]
                            local locClass = L:GetClassName(targetID)
                            btn.text:SetText(string.sub(locClass, 1, 3))
                            local color = GetClassColorObj(targetID)
                            btn.text:SetTextColor(color.r, color.g, color.b)
                        else
                            targetID = "GROUP_" .. i
                            btn.text:SetText("G" .. i)
                            btn.text:SetTextColor(1, 0.8, 0)
                        end
                        
                        btn:SetScript("OnClick", function(self, button)
                            if button == "RightButton" then
                                Grid:OpenSubAssignFrame(self, classType, targetID)
                            end
                        end)
                        btn:Show()
                    else
                        btn:Hide()
                    end
                end
                header:Show()
                
                yOffset = yOffset - 20
                headerIndex = headerIndex + 1
                
                for _, casterName in ipairs(playersOfClass) do
                    local row = Grid.playerRows[playerRowIndex]
                    if not row then
                        row = CreateFrame("Frame", nil, Grid)
                        row:SetSize(430, 30)
                        
                        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        row.name:SetPoint("LEFT", 10, 0)
                        row.name:SetWidth(80)
                        row.name:SetJustifyH("LEFT")
                        
                        row.cells = {}
                        for i = 1, 9 do
                            local cell = CreateFrame("Button", nil, row, "BackdropTemplate")
                            cell:SetSize(28, 28)
                            cell:SetPoint("LEFT", row.name, "RIGHT", (i-1)*34, 0)
                            
                            cell:SetBackdrop({
                                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                                edgeFile = "Interface\\Buttons\\WHITE8X8",
                                tile = true, tileSize = 16, edgeSize = 1,
                                insets = { left = 0, right = 0, top = 0, bottom = 0 }
                            })
                            cell:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
                            cell:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                            
                            cell.icon = cell:CreateTexture(nil, "ARTWORK")
                            cell.icon:SetAllPoints(cell)
                            
                            cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                            cell:SetScript("OnClick", OnCellClick)
                            cell:SetScript("OnEnter", OnCellEnter)
                            cell:SetScript("OnLeave", OnCellLeave)
                            cell:EnableMouseWheel(true)
                            cell:SetScript("OnMouseWheel", OnCellMouseWheel)
                            
                            row.cells[i] = cell
                        end
                        Grid.playerRows[playerRowIndex] = row
                    end
                    
                    row:SetPoint("TOPLEFT", Grid, "TOPLEFT", 0, yOffset)
                    
                    local colorHex = GetClassColorHex(classType)
                    local displayName = casterName
                    if isMTMap[casterName] then
                        displayName = "[T]" .. displayName -- Prefijo de tanque principal
                    end
                    row.name:SetText("|c" .. colorHex .. displayName .. "|r")
                    
                    for i = 1, 9 do
                        local cell = row.cells[i]
                        if i <= maxCols then
                            cell.casterClass = classType
                            cell.casterName = casterName
                            
                            local targetID
                            if targetType == "CLASS" then targetID = Constants.ClassOrder[i] else targetID = "GROUP_" .. i end
                            cell.targetID = targetID
                            
                            local assignedSpell = nil
                            if addonTable.Assignments[classType] and addonTable.Assignments[classType][casterName] then
                                assignedSpell = addonTable.Assignments[classType][casterName][targetID]
                            end
                            
                            if assignedSpell then
                                local _, icon = L:GetSpellInfo(assignedSpell)
                                cell.icon:SetTexture(icon)
                                cell.icon:SetAlpha(1.0)
                                cell:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
                                cell:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                            else
                                cell.icon:SetTexture(nil)
                                cell:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
                                cell:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                            end
                            cell:Show()
                        else
                            cell:Hide()
                        end
                    end
                    
                    row:Show()
                    yOffset = yOffset - 35
                    playerRowIndex = playerRowIndex + 1
                end
            end
        end
        Grid:SetHeight(math.abs(yOffset) + 45)
        
        -- 4. Actualizar estado y visibilidad de los controles inferiores con posiciones fijas para evitar solapamientos
        showAllCheck:SetPoint("BOTTOMLEFT", 10, 6)
        reportBtn:SetPoint("BOTTOMLEFT", 175, 8)
        
        -- Anclar la casilla de delegado
        delegateContainer:SetPoint("BOTTOMLEFT", 260, 8)
        delegateContainer:Show()
        
        if UnitIsGroupLeader("player") or not IsInGroup() then
            delegateEdit:SetEnabled(true)
            delegateEdit:SetTextColor(1, 1, 1)
        else
            delegateEdit:SetEnabled(false)
            delegateEdit:SetTextColor(0.6, 0.6, 0.6)
        end
        
        local activeDel = addonTable.DelegateName or ""
        if not delegateEdit:HasFocus() then
            delegateEdit:SetText(activeDel)
        end
    end)
    if not success then
        print("|cffff0000[RaidBuffet] Error en UpdateGrid:|r", err)
    end
end

-- ============================================================================
-- VENTANA DE SUB-ASIGNACIONES INDIVIDUALES (MOCKUP v1.3.0)
-- ============================================================================
local SubFrame = CreateFrame("Frame", "RaidBuffetSubAssignFrame", UIParent, "BackdropTemplate")
SubFrame:SetSize(440, 240)
SubFrame:SetPoint("CENTER", UIParent, "CENTER", 100, 0)
SubFrame:SetMovable(true)
SubFrame:EnableMouse(true)
SubFrame:RegisterForDrag("LeftButton")
SubFrame:SetScript("OnDragStart", SubFrame.StartMoving)
SubFrame:SetScript("OnDragStop", SubFrame.StopMovingOrSizing)
SubFrame:Hide()

SubFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
SubFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.94)
SubFrame:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

SubFrame.header = CreateFrame("Frame", nil, SubFrame, "BackdropTemplate")
SubFrame.header:SetSize(440, 24)
SubFrame.header:SetPoint("TOPLEFT", SubFrame, "TOPLEFT", 0, 0)
SubFrame.header:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
SubFrame.header:SetBackdropColor(0.12, 0.12, 0.12, 1)
SubFrame.header:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

SubFrame.header:EnableMouse(true)
SubFrame.header:RegisterForDrag("LeftButton")
SubFrame.header:SetScript("OnDragStart", function() SubFrame:StartMoving() end)
SubFrame.header:SetScript("OnDragStop", function() SubFrame:StopMovingOrSizing() end)

SubFrame.title = SubFrame.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
SubFrame.title:SetPoint("LEFT", 10, 0)
SubFrame.title:SetTextColor(0.8, 0.6, 0.2)

SubFrame.closeBtn = CreateFrame("Button", nil, SubFrame.header, "BackdropTemplate")
SubFrame.closeBtn:SetSize(16, 16)
SubFrame.closeBtn:SetPoint("RIGHT", -6, 0)
SubFrame.closeBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
SubFrame.closeBtn:SetBackdropColor(0.2, 0.1, 0.1, 1)
SubFrame.closeBtn:SetBackdropBorderColor(0.3, 0.15, 0.15, 1)
SubFrame.closeBtn.text = SubFrame.closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
SubFrame.closeBtn.text:SetPoint("CENTER", 0, 0)
SubFrame.closeBtn.text:SetText("X")
SubFrame.closeBtn.text:SetTextColor(0.8, 0.3, 0.3)
SubFrame.closeBtn:SetScript("OnClick", function() SubFrame:Hide() end)
SubFrame.closeBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.4, 0.15, 0.15, 1)
end)
SubFrame.closeBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.2, 0.1, 0.1, 1)
end)

local SubScrollFrame = CreateFrame("ScrollFrame", "RaidBuffetSubAssignScrollFrame", SubFrame, "UIPanelScrollFrameTemplate")
SubScrollFrame:SetPoint("TOPLEFT", 10, -50)
SubScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

if _G["RaidBuffetSubAssignScrollFrameScrollBar"] then
    _G["RaidBuffetSubAssignScrollFrameScrollBar"]:SetAlpha(0)
    _G["RaidBuffetSubAssignScrollFrameScrollBarScrollUpButton"]:SetAlpha(0)
    _G["RaidBuffetSubAssignScrollFrameScrollBarScrollDownButton"]:SetAlpha(0)
end

SubFrame.casterLabel = SubFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
SubFrame.casterLabel:SetPoint("TOPLEFT", 15, -32)
SubFrame.casterLabel:SetText("Caster (Bufa)")
SubFrame.casterLabel:SetTextColor(0.6, 0.6, 0.6)

SubFrame.targetLabel = SubFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
SubFrame.targetLabel:SetPoint("TOPLEFT", 115, -32)
SubFrame.targetLabel:SetText("Objetivos (Reciben)")
SubFrame.targetLabel:SetTextColor(0.6, 0.6, 0.6)

local SubScrollChild = CreateFrame("Frame", "RaidBuffetSubAssignScrollChild", SubScrollFrame)
SubScrollChild:SetSize(380, 1)
SubScrollFrame:SetScrollChild(SubScrollChild)

SubFrame.rows = {}
SubFrame.headers = {}

-- Menú de contexto personalizado para asignaciones individuales
local contextMenu
local okMenu, errMenu = pcall(function()
    contextMenu = CreateFrame("Frame", "RaidBuffetSubAssignContextMenu", UIParent, "BackdropTemplate")
end)
if not okMenu then
    contextMenu = CreateFrame("Frame", "RaidBuffetSubAssignContextMenu", UIParent)
end
contextMenu:SetSize(160, 150)
contextMenu:SetFrameStrata("DIALOG")
if contextMenu.SetBackdrop then
    contextMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    contextMenu:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    contextMenu:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
end
contextMenu:Hide()
contextMenu.buttons = {}

-- Cerrar el menú de contexto si hacemos clic fuera o cerramos el frame principal
SubFrame:HookScript("OnHide", function() contextMenu:Hide() end)

local function IsSpellInSpellbook(spellID)
    local targetName = L:GetSpellInfo(spellID)
    if not targetName then return false end
    
    -- Limpiar el rango en caso de que lo traiga
    targetName = string.gsub(targetName, " Rango %d+", "")
    
    local tabIndex = 1
    while true do
        local name, texture, offset, numSlots = GetSpellTabInfo(tabIndex)
        if not name then break end
        for i = offset + 1, offset + numSlots do
            local spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            if spellName then
                spellName = string.gsub(spellName, " Rango %d+", "")
                if spellName == targetName then
                    return true
                end
            end
        end
        tabIndex = tabIndex + 1
    end
    return false
end

local function OpenAssignMenu(anchorBtn, casterName, targetName, targetClass)
    -- Limpiar botones anteriores
    for _, btn in ipairs(contextMenu.buttons) do btn:Hide() end
    
    -- Hechizos individuales pequeños de paladín
    local spells = {
        { id = 20217, sup = 25898 }, -- Reyes
        { id = 19977, sup = 25890 }, -- Luz
        { id = 19740, sup = 27141 }, -- Poderío
        { id = 1038,  sup = 25895 }, -- Salvación
        { id = 19742, sup = 27143 }, -- Sabiduría
        { id = 20911, sup = 25899 }  -- Santuario
    }
    
    -- Recopilar bendiciones superiores asignadas por todos los paladines de la raid a esta clase
    local activeSuperiors = {}
    for pName, targets in pairs(addonTable.Assignments["PALADIN"] or {}) do
        for tID, sID in pairs(targets) do
            if tID == targetClass then
                activeSuperiors[sID] = true
            end
        end
    end
    
    local index = 1
    
    -- Botón de Heredar de Clase
    local clearBtn = contextMenu.buttons[index]
    if not clearBtn then
        clearBtn = CreateFrame("Button", nil, contextMenu)
        clearBtn:SetSize(150, 20)
        clearBtn.text = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        clearBtn.text:SetPoint("LEFT", 5, 0)
        contextMenu.buttons[index] = clearBtn
    end
    clearBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 5, -5)
    clearBtn.text:SetText("|cffaaaaaaHeredar clase|r")
    clearBtn:SetScript("OnClick", function()
        if addonTable.Assignments["PALADIN"] and addonTable.Assignments["PALADIN"][casterName] then
            addonTable.Assignments["PALADIN"][casterName][targetName] = nil
            Sync:SendAssignment("PALADIN", casterName, targetName, "CLEAR")
            Grid:UpdateGrid()
            SubFrame:RefreshList()
        end
        contextMenu:Hide()
    end)
    clearBtn:Show()
    index = index + 1
    
    -- Botón de Ninguno (No bufar)
    local noneBtn = contextMenu.buttons[index]
    if not noneBtn then
        noneBtn = CreateFrame("Button", nil, contextMenu)
        noneBtn:SetSize(150, 20)
        noneBtn.text = noneBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noneBtn.text:SetPoint("LEFT", 5, 0)
        contextMenu.buttons[index] = noneBtn
    end
    noneBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 5, -5 - (index-1)*20)
    noneBtn.text:SetText("|cffff5555Ninguno (No bufar)|r")
    noneBtn:SetScript("OnClick", function()
        if not addonTable.Assignments["PALADIN"] then addonTable.Assignments["PALADIN"] = {} end
        if not addonTable.Assignments["PALADIN"][casterName] then addonTable.Assignments["PALADIN"][casterName] = {} end
        
        addonTable.Assignments["PALADIN"][casterName][targetName] = "CLEAR"
        Sync:SendAssignment("PALADIN", casterName, targetName, "CLEAR")
        Grid:UpdateGrid()
        SubFrame:RefreshList()
        contextMenu:Hide()
    end)
    noneBtn:Show()
    index = index + 1
    
    -- Añadir bendiciones
    for _, sData in ipairs(spells) do
        local isCasterPlayer = (casterName == UnitName("player"))
        local isKnown = true
        if isCasterPlayer then
            isKnown = IsSpellInSpellbook(sData.id)
        end
        
        if isKnown then
            local btn = contextMenu.buttons[index]
            if not btn then
                btn = CreateFrame("Button", nil, contextMenu)
                btn:SetSize(150, 20)
                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.text:SetPoint("LEFT", 5, 0)
                contextMenu.buttons[index] = btn
            end
            btn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 5, -5 - (index-1)*20)
            
            local sName = L:GetSpellInfo(sData.id)
            if sName then
                sName = string.gsub(sName, " Rango %d+", "")
                
                -- Ayuda de no-colisión (texto verde con asterisco si no colisiona con superiors)
                local collides = activeSuperiors[sData.sup] ~= nil
                local displayName = sName
                if not collides then
                    displayName = "|cff00ff00* " .. sName .. "|r"
                else
                    displayName = "|cffaaaaaa" .. sName .. "|r"
                end
                
                btn.text:SetText(displayName)
                btn:SetScript("OnClick", function()
                    if not addonTable.Assignments["PALADIN"] then addonTable.Assignments["PALADIN"] = {} end
                    if not addonTable.Assignments["PALADIN"][casterName] then addonTable.Assignments["PALADIN"][casterName] = {} end
                    
                    addonTable.Assignments["PALADIN"][casterName][targetName] = sData.id
                    Sync:SendAssignment("PALADIN", casterName, targetName, sData.id)
                    Grid:UpdateGrid()
                    SubFrame:RefreshList()
                    contextMenu:Hide()
                end)
                btn:Show()
                index = index + 1
            end
        end
    end
    
    contextMenu:SetSize(160, (index-1)*20 + 10)
    contextMenu:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, 0)
    contextMenu:Show()
end

function SubFrame:RefreshList()
    -- Ocultar filas y cabeceras anteriores
    for _, row in ipairs(SubFrame.rows) do row:Hide() end
    for _, h in ipairs(SubFrame.headers) do h:Hide() end
    
    local targetClass = SubFrame.targetClass
    if not targetClass then return end
    
    -- 1. Recopilar jugadores reales de la clase (objetivos)
    local players = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup, _, _, classFileName = GetRaidRosterInfo(i)
            if name and classFileName == targetClass then
                name = string.match(name, "([^%-]+)")
                table.insert(players, { name = name, class = classFileName, unit = "raid" .. i })
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, classFileName = UnitClass(unit)
            if name and classFileName == targetClass then
                name = string.match(name, "([^%-]+)")
                table.insert(players, { name = name, class = classFileName, unit = unit })
            end
        end
        local name = UnitName("player")
        local _, classFileName = UnitClass("player")
        if name and classFileName == targetClass then
            name = string.match(name, "([^%-]+)")
            table.insert(players, { name = name, class = classFileName, unit = "player" })
        end
    else
        local name = UnitName("player")
        local _, classFileName = UnitClass("player")
        if name and classFileName == targetClass then
            name = string.match(name, "([^%-]+)")
            table.insert(players, { name = name, class = classFileName, unit = "player" })
        end
    end
    
    -- 2. Recopilar paladines activos (casters)
    local paladins = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, classFileName = GetRaidRosterInfo(i)
            if name and classFileName == "PALADIN" then
                name = string.match(name, "([^%-]+)")
                table.insert(paladins, name)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, classFileName = UnitClass(unit)
            if name and classFileName == "PALADIN" then
                name = string.match(name, "([^%-]+)")
                table.insert(paladins, name)
            end
        end
        local name = UnitName("player")
        local _, classFileName = UnitClass("player")
        if name and classFileName == "PALADIN" then
            name = string.match(name, "([^%-]+)")
            table.insert(paladins, name)
        end
    else
        local name = UnitName("player")
        local _, classFileName = UnitClass("player")
        if name and classFileName == "PALADIN" then
            name = string.match(name, "([^%-]+)")
            table.insert(paladins, name)
        end
    end
    
    if #players == 0 or #paladins == 0 then
        local row = SubFrame.rows[1]
        if not row then
            row = CreateFrame("Frame", nil, SubScrollChild)
            row:SetSize(380, 24)
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetPoint("CENTER", row, "CENTER", 0, 0)
            SubFrame.rows[1] = row
        end
        row.name:SetText("|cffaaaaaaNo hay jugadores o paladines activos|r")
        row.name:Show()
        row:SetPoint("TOPLEFT", SubScrollChild, "TOPLEFT", 0, -5)
        row:Show()
        SubScrollChild:SetHeight(30)
        return
    end
    
    -- 3. Dibujar cabeceras de columnas (Jugadores destino)
    for i, pData in ipairs(players) do
        if i <= 8 then
            local h = SubFrame.headers[i]
            if not h then
                h = CreateFrame("Button", nil, SubScrollChild)
                h:SetSize(36, 16)
                h.text = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                h.text:SetPoint("CENTER", 0, 0)
                SubFrame.headers[i] = h
            end
            h:SetPoint("TOPLEFT", SubScrollChild, "TOPLEFT", 100 + (i-1)*40, -5)
            h.text:SetText(string.sub(pData.name, 1, 4))
            
            local color = GetClassColorObj(pData.class)
            h.text:SetTextColor(color.r, color.g, color.b)
            
            -- Tooltip con nombre completo
            local isMT = Scanner:IsMainTank(pData.unit)
            h:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:ClearLines()
                local titleName = pData.name
                if isMT then
                    titleName = "|cff00ffff[T]|r " .. titleName
                end
                GameTooltip:AddDoubleLine(titleName, isMT and "|cff00ffffTanque Principal|r" or "", color.r, color.g, color.b, 0, 1, 1)
                GameTooltip:Show()
            end)
            h:SetScript("OnLeave", function() GameTooltip:Hide() end)
            h:Show()
        end
    end
    
    -- 4. Dibujar filas de paladines (Casters)
    local yOffset = 25
    for rowIndex, palName in ipairs(paladins) do
        local row = SubFrame.rows[rowIndex]
        if not row then
            row = CreateFrame("Frame", nil, SubScrollChild)
            row:SetSize(380, 24)
            
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.name:SetPoint("LEFT", 5, 0)
            row.name:SetWidth(90)
            row.name:SetJustifyH("LEFT")
            
            row.buttons = {}
            for pIdx = 1, 8 do
                local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
                btn:SetSize(20, 20)
                btn:SetPoint("LEFT", row.name, "RIGHT", (pIdx-1)*40 + 8, 0)
                
                btn:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = true, tileSize = 16, edgeSize = 1,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 }
                })
                btn:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
                btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                
                btn.icon = btn:CreateTexture(nil, "ARTWORK")
                btn.icon:SetAllPoints(btn)
                
                row.buttons[pIdx] = btn
            end
            SubFrame.rows[rowIndex] = row
        end
        row:SetPoint("TOPLEFT", SubScrollChild, "TOPLEFT", 0, -yOffset)
        
        row.name:SetText(palName)
        row.name:SetTextColor(0.96, 0.55, 0.73) -- Rosa paladín
        
        -- Configurar botones para cada jugador destino
        for pIdx = 1, 8 do
            local btn = row.buttons[pIdx]
            if pIdx <= #players then
                local pData = players[pIdx]
                
                local assignedSpell = nil
                local isIndividual = false
                if addonTable.Assignments["PALADIN"] and addonTable.Assignments["PALADIN"][palName] then
                    assignedSpell = addonTable.Assignments["PALADIN"][palName][pData.name]
                    if assignedSpell then
                        isIndividual = true
                    else
                        assignedSpell = addonTable.Assignments["PALADIN"][palName][targetClass]
                    end
                end
                
                if assignedSpell and assignedSpell ~= "CLEAR" and assignedSpell ~= 0 then
                    local _, icon = L:GetSpellInfo(assignedSpell)
                    btn.icon:SetTexture(icon)
                    if isIndividual then
                        btn.icon:SetAlpha(1.0)
                        btn:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
                        btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                    else
                        btn.icon:SetAlpha(0.35)
                        btn:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
                        btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                    end
                else
                    btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    btn.icon:SetAlpha(0.12)
                    btn:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
                    btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                end
                
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:SetScript("OnClick", function(self, button)
                    if not HasEditPermissions() then
                        print("|cffff0000[RaidBuffet]|r No tienes permisos de edición.")
                        return
                    end
                    if button == "RightButton" then
                        if addonTable.Assignments["PALADIN"] and addonTable.Assignments["PALADIN"][palName] then
                            addonTable.Assignments["PALADIN"][palName][pData.name] = nil
                            Sync:SendAssignment("PALADIN", palName, pData.name, "CLEAR")
                            Grid:UpdateGrid()
                            SubFrame:RefreshList()
                        end
                    else
                        OpenAssignMenu(btn, palName, pData.name, targetClass)
                    end
                end)
                
                btn:EnableMouseWheel(true)
                btn:SetScript("OnMouseWheel", function(self, delta)
                    if not HasEditPermissions() then return end
                    
                    local spells = {
                        { id = 20217, sup = 25898 }, -- Reyes
                        { id = 19977, sup = 25890 }, -- Luz
                        { id = 19740, sup = 27141 }, -- Poderío
                        { id = 1038,  sup = 25895 }, -- Salvación
                        { id = 19742, sup = 27143 }, -- Sabiduría
                        { id = 20911, sup = 25899 }  -- Santuario
                    }
                    
                    local isCasterPlayer = (palName == UnitName("player"))
                    local options = { "CLEAR" }
                    for _, sData in ipairs(spells) do
                        local isKnown = true
                        if isCasterPlayer then
                            isKnown = IsSpellInSpellbook(sData.id)
                        end
                        if isKnown then
                            table.insert(options, sData.id)
                        end
                    end
                    
                    local currentSpell = nil
                    if addonTable.Assignments["PALADIN"] and addonTable.Assignments["PALADIN"][palName] then
                        currentSpell = addonTable.Assignments["PALADIN"][palName][pData.name]
                    end
                    
                    local curIdx = 1
                    local lookupVal = currentSpell or "CLEAR"
                    for i, opt in ipairs(options) do
                        if opt == lookupVal then
                            curIdx = i
                            break
                        end
                    end
                    
                    if delta > 0 then
                        curIdx = curIdx + 1
                        if curIdx > #options then curIdx = 1 end
                    else
                        curIdx = curIdx - 1
                        if curIdx < 1 then curIdx = #options end
                    end
                    
                    local nextVal = options[curIdx]
                    if not addonTable.Assignments["PALADIN"] then addonTable.Assignments["PALADIN"] = {} end
                    if not addonTable.Assignments["PALADIN"][palName] then addonTable.Assignments["PALADIN"][palName] = {} end
                    
                    if nextVal == "CLEAR" then
                        addonTable.Assignments["PALADIN"][palName][pData.name] = nil
                        Sync:SendAssignment("PALADIN", palName, pData.name, "CLEAR")
                    else
                        addonTable.Assignments["PALADIN"][palName][pData.name] = nextVal
                        Sync:SendAssignment("PALADIN", palName, pData.name, nextVal)
                    end
                    
                    Grid:UpdateGrid()
                    SubFrame:RefreshList()
                end)
                
                btn:SetScript("OnEnter", function(self)
                    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1) -- Hover Glow dorado suave
                end)
                
                btn:SetScript("OnLeave", function(self)
                    local assignedSpell = nil
                    if addonTable.Assignments["PALADIN"] and addonTable.Assignments["PALADIN"][palName] then
                        assignedSpell = addonTable.Assignments["PALADIN"][palName][pData.name]
                    end
                    if assignedSpell then
                        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                    else
                        self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                    end
                end)
                
                btn:Show()
            else
                btn:Hide()
            end
        end
        row:Show()
        yOffset = yOffset + 24
    end
    SubScrollChild:SetHeight(yOffset + 10)
end

function Grid:OpenSubAssignFrame(anchorFrame, classType, targetClass)
    if classType ~= "PALADIN" then
        print("|cffff0000[RaidBuffet]|r Las asignaciones individuales de bendiciones pequeñas solo son aplicables para la clase Paladín.")
        return
    end
    
    SubFrame.targetClass = targetClass
    SubFrame.title:SetText("Asignación Individual: " .. (L:GetClassName(targetClass) or targetClass))
    SubFrame:ClearAllPoints()
    SubFrame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", -50, -5)
    SubFrame:RefreshList()
    SubFrame:Show()
end

showAllCheck:SetScript("OnShow", function(self) if RaidBuffetDB then self:SetChecked(RaidBuffetDB.ShowAllClasses) end end)
Grid:SetScript("OnShow", function(self) self:UpdateGrid() end)

-- ============================================================================
-- COMANDOS DE CHAT (SLASH COMMANDS)
-- ============================================================================
SLASH_RAIDBUFFET1 = "/rb"
SLASH_RAIDBUFFET2 = "/raidbuffet"

SlashCmdList["RAIDBUFFET"] = function(msg)
    if msg == "debug" then
        print("|cffffff00[RaidBuffet Debug]|r")
        if Grid.lastDebugClasses then
            print("Classes to Draw:", table.concat(Grid.lastDebugClasses, ", "))
        end
        if Grid.lastDebugRoster then
            for classFileName, players in pairs(Grid.lastDebugRoster) do
                print(classFileName .. ": " .. table.concat(players, ", "))
            end
        else
            print("Roster is empty/nil.")
        end
        return
    end

    if Grid:IsShown() then
        Grid:Hide()
    else
        Grid:Show()
    end
end
