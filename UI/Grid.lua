local addonName, addonTable = ...
local L = addonTable.L
local Sync = addonTable.Sync
local Constants = addonTable.Constants
local Scanner = addonTable.Scanner

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
local UnitIsGroupLeader = function(unit)
    if addonTable.UnitIsGroupLeader then return addonTable:UnitIsGroupLeader(unit) end
    return _G.UnitIsGroupLeader(unit)
end

local ReportPanel, SubFrame, ProposalPanel

local Grid = CreateFrame("Frame", "RaidBuffetGridFrame", UIParent, "BackdropTemplate")
Grid:SetToplevel(true)
addonTable.UI = Grid

-- Frame para menús contextuales de especialidades (API nativa de Blizzard DropDown)
local specMenuFrame = CreateFrame("Frame", "RaidBuffetSpecMenuFrame", UIParent, "UIDropDownMenuTemplate")

local function HasEditPermissions()
    if addonTable.TestModeActive then return true end
    if not IsInGroup() then return true end
    
    local myName = UnitName("player")
    if addonTable.DelegateName and myName == addonTable.DelegateName then
        return true
    end
    
    if UnitIsGroupLeader("player") then
        return true
    end
    
    -- Verificar si somos asistentes de la raid
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name then
                name = string.match(name, "([^%-]+)")
                if name == myName then
                    if rank == 1 or rank == 2 then
                        return true
                    end
                    break
                end
            end
        end
    end
    
    return false
end

function Grid:OpenSpecMenu(anchorFrame, casterName, classType)
    if not HasEditPermissions() then
        print("|cffff0000[RaidBuffet]|r No tienes permisos de edición. Solo el Líder o el Co-Asignador Delegado pueden modificar asignaciones.")
        return
    end
    
    local menuTable = {}
    
    table.insert(menuTable, {
        text = "Especialidad de " .. casterName,
        isTitle = true,
        notCheckable = true
    })
    
    local specs = {}
    if classType == "PALADIN" then
        specs = {
            { text = "Sagrado (Sabiduría/Reyes)", value = "HOLY" },
            { text = "Protección (Santuario/Reyes)", value = "PROT" },
            { text = "Reprensión (Poderío)", value = "RETRI" },
            { text = "Ninguno (Estándar)", value = "NONE" }
        }
    elseif classType == "DRUID" then
        specs = {
            { text = "Restauración (Marca Mejorada)", value = "RESTO" },
            { text = "Feral (Marca Estándar)", value = "FERAL" },
            { text = "Equilibrio (Marca Estándar)", value = "BALANCE" },
            { text = "Ninguno (Estándar)", value = "NONE" }
        }
    elseif classType == "PRIEST" then
        specs = {
            { text = "Disciplina (Espíritu/Entereza Mejorados)", value = "DISC" },
            { text = "Sagrado (Entereza Mejorada)", value = "HOLY" },
            { text = "Sombra (Entereza Estándar)", value = "SHADOW" },
            { text = "Ninguno (Estándar)", value = "NONE" }
        }
    else
        return -- No tiene especialidades mapeables de buffs
    end
    
    local currentSpec = addonTable.TalentsCache[casterName] and addonTable.TalentsCache[casterName].spec or "NONE"
    
    for _, s in ipairs(specs) do
        table.insert(menuTable, {
            text = s.text,
            checked = (currentSpec == s.value),
            func = function()
                -- 1. Cargar talentos por especialidad
                local talents = {}
                local defaultTalents = addonTable.Constants.SpecializationTalents[classType][s.value]
                if defaultTalents then
                    for k, v in pairs(defaultTalents) do talents[k] = v end
                end
                
                addonTable.TalentsCache[casterName] = {
                    class = classType,
                    spec = s.value,
                    talents = talents,
                    source = "MANUAL"
                }
                
                -- 2. Transmitir actualización de especialidad
                Sync:SendSetTalents(casterName, s.value)
                
                -- 3. Actualizar la UI local
                Grid:UpdateGrid()
            end
        })
    end
    
    local function InitializeMenu(self, level)
        for _, item in ipairs(menuTable) do
            UIDropDownMenu_AddButton(item, level)
        end
    end
    UIDropDownMenu_Initialize(specMenuFrame, InitializeMenu, "MENU")
    ToggleDropDownMenu(1, nil, specMenuFrame, anchorFrame, 0, 0)
end

Grid:SetSize(600, 300)
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
Grid.header:SetSize(600, 24)
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

Grid.helpBtn = CreateFrame("Button", nil, Grid.header, "BackdropTemplate")
Grid.helpBtn:SetSize(16, 16)
Grid.helpBtn:SetPoint("RIGHT", Grid.closeBtn, "LEFT", -4, 0)
Grid.helpBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
Grid.helpBtn:SetBackdropColor(0.12, 0.12, 0.12, 1)
Grid.helpBtn:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
Grid.helpBtn.text = Grid.helpBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Grid.helpBtn.text:SetPoint("CENTER", 0, 0)
Grid.helpBtn.text:SetText("?")
Grid.helpBtn.text:SetTextColor(0.7, 0.5, 0.2)
Grid.helpBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.2, 0.2, 0.2, 1)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Guía Rápida de Controles:", 1, 0.8, 0)
    GameTooltip:AddLine("|cff00ffffClic Izq (Celda)|r: Asignar / Ciclar buff de clase")
    GameTooltip:AddLine("|cff00ffffClic Der (Celda)|r: Borrar asignación")
    GameTooltip:AddLine("|cff00ffffRueda Ratón (Celda)|r: Ciclar buffs cómodamente")
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff00ff00Atajos de Paladín (Shift):|r", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cff00ffffShift + Clic Izq|r: Propagar buff a clases viables")
    GameTooltip:AddLine("|cff00ffffShift + Clic Der|r: Limpiar todas las tareas del paladín")
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff00ff00Asignación por Jugador (Individual):|r", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cff00ffffClic Derecho en Cabecera|r (ej. Gue, Pí):")
    GameTooltip:AddLine("  Abre el panel para asignar bendiciones individuales.")
    GameTooltip:Show()
end)
Grid.helpBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.12, 0.12, 0.12, 1)
    self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
    GameTooltip:Hide()
end)

local showAllCheck = CreateFrame("CheckButton", "RaidBuffetShowAllCheck", Grid, "UICheckButtonTemplate")
showAllCheck:SetPoint("BOTTOMLEFT", 10, 7)
local showAllText = _G[showAllCheck:GetName() .. "Text"]
showAllText:SetText("Mostrar todas las clases")
showAllText:ClearAllPoints()
showAllText:SetPoint("LEFT", showAllCheck, "RIGHT", 4, 1)
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
    if ReportPanel then
        if ReportPanel:IsShown() then
            ReportPanel:Hide()
        else
            ReportPanel:Show()
        end
    end
end)

-- Botón de la Varita Mágica para propuesta de buffs inteligente
local proposalBtn = CreateFrame("Button", "RaidBuffetProposalBtn", Grid, "BackdropTemplate")
proposalBtn:SetSize(80, 22)
proposalBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
proposalBtn:SetBackdropColor(0.14, 0.14, 0.14, 1)
proposalBtn:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
proposalBtn:SetFrameLevel(Grid:GetFrameLevel() + 5)

proposalBtn.text = proposalBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
proposalBtn.text:SetPoint("CENTER", 0, 0)
proposalBtn.text:SetText("Varita")

proposalBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.22, 0.22, 0.22, 1)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Varita Mágica (Propuesta de Asignación)", 1, 0.8, 0)
    GameTooltip:AddLine("Calcula una asignación de buffs óptima para la raid.", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Toma en cuenta las especialidades y buffs mejorados.", 0.9, 0.9, 0.9)
    GameTooltip:Show()
end)
proposalBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.14, 0.14, 0.14, 1)
    self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
    GameTooltip:Hide()
end)
proposalBtn:SetScript("OnClick", function()
    if ProposalPanel then
        if ProposalPanel:IsShown() then
            ProposalPanel:Hide()
        else
            ProposalPanel:ShowPreview()
        end
    end
end)

-- ============================================================================
-- BOTÓN MAESTRO DE AUTO-CAST Y SCROLL DE RATÓN
-- ============================================================================
-- Se crea el botón físico en la UI (puede estar oculto o visible)
local castBtn = addonTable.ClickCast:CreateSecureButton(Grid, "RaidBuffetUIBtn", 32, nil, nil)
castBtn:SetPoint("BOTTOMRIGHT", -10, 4)

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

-- Comprueba si el jugador actual tiene permisos de edición (Líder de grupo, Asistente de Raid o Delegado)
local function HasEditPermissions()
    if addonTable.TestModeActive then return true end
    if not IsInGroup() then return true end
    if UnitIsGroupLeader("player") then return true end
    if IsInRaid() and UnitIsRaidOfficer("player") then return true end
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
    
    -- Alerta Crítica si hay un tanque que va a recibir salvación de clase
    if self.casterClass == "PALADIN" then
        local isHazard, tankName = Scanner:HasSalvationTankHazard(self.casterName, self.targetID)
        if isHazard then
            GameTooltip:AddLine("|cffff0000¡ALERTA CRÍTICA DE TANQUE!|r", 1, 0, 0)
            GameTooltip:AddLine(string.format("|cffffffff%s|r es Tanque y recibirá Salvación.", tankName), 1, 1, 1)
            GameTooltip:AddLine("Asigna otra bendición individualmente\npara anular la bendición de clase.", 0.9, 0.9, 0)
            GameTooltip:AddLine(" ")
        end
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
    local isHazard = false
    if self.casterClass == "PALADIN" then
        isHazard = Scanner:HasSalvationTankHazard(self.casterName, self.targetID)
    end
    
    if isHazard then
        self:SetBackdropBorderColor(1.0, 0.1, 0.1, 1)
    else
        local assignedSpell = nil
        if addonTable.Assignments[self.casterClass] and addonTable.Assignments[self.casterClass][self.casterName] then
            assignedSpell = addonTable.Assignments[self.casterClass][self.casterName][self.targetID]
        end
        if assignedSpell then
            self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        else
            self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        end
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
local delegateLbl = Grid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
delegateLbl:SetText("Co-Asig:")

local delegateEdit = CreateFrame("EditBox", "RaidBuffetDelegateEdit", Grid, "InputBoxTemplate")
delegateEdit:SetSize(65, 20)
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
        local classHasMT = {}
        local groupHasMT = {}
        
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                local name, _, subgroup, _, _, classFileName = GetRaidRosterInfo(i)
                if name and classFileName then
                    name = string.match(name, "([^%-]+)")
                    if not roster[classFileName] then roster[classFileName] = {} end
                    table.insert(roster[classFileName], name)
                    
                    local isMT = Scanner:IsMainTank("raid" .. i)
                    if isMT then
                        isMTMap[name] = true
                        classHasMT[classFileName] = true
                        if subgroup then
                            groupHasMT[subgroup] = true
                        end
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
                    
                    local isMT = Scanner:IsMainTank(unit)
                    if isMT then
                        isMTMap[name] = true
                        classHasMT[classFileName] = true
                        groupHasMT[1] = true
                    end
                end
            end
            local name = UnitName("player")
            local _, classFileName = UnitClass("player")
            if name and classFileName then
                name = string.match(name, "([^%-]+)")
                if not roster[classFileName] then roster[classFileName] = {} end
                table.insert(roster[classFileName], name)
                
                local isMT = Scanner:IsMainTank("player")
                if isMT then
                    isMTMap[name] = true
                    classHasMT[classFileName] = true
                    groupHasMT[1] = true
                end
            end
        else
            local name = UnitName("player")
            local _, classFileName = UnitClass("player")
            if name and classFileName then
                name = string.match(name, "([^%-]+)")
                if not roster[classFileName] then roster[classFileName] = {} end
                table.insert(roster[classFileName], name)
                
                local isMT = Scanner:IsMainTank("player")
                if isMT then
                    isMTMap[name] = true
                    classHasMT[classFileName] = true
                    groupHasMT[1] = true
                end
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
                            if classHasMT[targetID] then
                                btn.text:SetText(string.sub(locClass, 1, 3) .. " |cff00ffff[T]|r")
                            else
                                btn.text:SetText(string.sub(locClass, 1, 3))
                            end
                            local color = GetClassColorObj(targetID)
                            btn.text:SetTextColor(color.r, color.g, color.b)
                        else
                            targetID = "GROUP_" .. i
                            if groupHasMT[i] then
                                btn.text:SetText("G" .. i .. " |cff00ffff[T]|r")
                            else
                                btn.text:SetText("G" .. i)
                            end
                            btn.text:SetTextColor(1, 0.8, 0)
                        end
                        
                        btn:SetScript("OnClick", function(self, button)
                            if button == "RightButton" then
                                Grid:OpenSubAssignFrame(self, classType, targetID)
                            end
                        end)
                        btn:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_TOP")
                            GameTooltip:ClearLines()
                            
                            local displayName
                            if targetType == "CLASS" then
                                displayName = L:GetClassName(targetID) or targetID
                            else
                                displayName = "Grupo " .. string.match(targetID, "GROUP_(%d+)")
                            end
                            
                            GameTooltip:AddLine(displayName, 1, 0.8, 0)
                            
                            local members = {}
                            if IsInRaid() then
                                for rIdx = 1, GetNumGroupMembers() do
                                    local name, _, subgroup, _, _, classFileName = GetRaidRosterInfo(rIdx)
                                    if name then
                                        name = string.match(name, "([^%-]+)")
                                        if targetType == "CLASS" then
                                            if classFileName == targetID then
                                                table.insert(members, name)
                                            end
                                        else
                                            if tostring(subgroup) == string.match(targetID, "GROUP_(%d+)") then
                                                table.insert(members, name)
                                            end
                                        end
                                    end
                                end
                            elseif IsInGroup() then
                                for pIdx = 1, GetNumSubgroupMembers() do
                                    local unit = "party" .. pIdx
                                    local name = UnitName(unit)
                                    local _, classFileName = UnitClass(unit)
                                    if name then
                                        name = string.match(name, "([^%-]+)")
                                        if targetType == "CLASS" and classFileName == targetID then
                                            table.insert(members, name)
                                        end
                                    end
                                end
                                local pName = UnitName("player")
                                local _, pClass = UnitClass("player")
                                if pName then
                                    pName = string.match(pName, "([^%-]+)")
                                    if targetType == "CLASS" and pClass == targetID then
                                        table.insert(members, pName)
                                    end
                                end
                            else
                                local pName = UnitName("player")
                                local _, pClass = UnitClass("player")
                                if pName then
                                    pName = string.match(pName, "([^%-]+)")
                                    if targetType == "CLASS" and pClass == targetID then
                                        table.insert(members, pName)
                                    end
                                end
                            end
                            
                            if #members > 0 then
                                GameTooltip:AddLine("Miembros: |cffffffff" .. table.concat(members, ", ") .. "|r", 0.9, 0.9, 0.9)
                            else
                                GameTooltip:AddLine("Ningún jugador activo.", 0.5, 0.5, 0.5)
                            end
                            
                            GameTooltip:AddLine(" ")
                            if classType == "PALADIN" then
                                GameTooltip:AddLine("|cff00ffffClic Derecho|r: Abrir Asignación Individual", 0.2, 1, 0.2)
                            else
                                GameTooltip:AddLine("Los otros casters bufean por clase completa.", 0.6, 0.6, 0.6)
                            end
                            GameTooltip:Show()
                        end)
                        btn:SetScript("OnLeave", function(self)
                            GameTooltip:Hide()
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
                        
                        -- Botón invisible interactivo sobre el nombre
                        row.nameBtn = CreateFrame("Button", nil, row)
                        row.nameBtn:SetAllPoints(row.name)
                        row.nameBtn:RegisterForClicks("RightButtonUp")
                        
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
                    
                    -- Vincular el menú contextual de talentos al clic derecho del nombre
                    row.nameBtn:SetScript("OnClick", function(self, button)
                        if button == "RightButton" then
                            Grid:OpenSpecMenu(self, casterName, classType)
                        end
                    end)
                    row.nameBtn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_TOP")
                        GameTooltip:ClearLines()
                        GameTooltip:AddLine(casterName, 1, 1, 1)
                        if HasEditPermissions() then
                            GameTooltip:AddLine("|cff00ffffClic Derecho|r: Cambiar Especialidad de Buffs", 0.2, 1, 0.2)
                        end
                        GameTooltip:Show()
                    end)
                    row.nameBtn:SetScript("OnLeave", function(self)
                        GameTooltip:Hide()
                    end)
                    
                    -- Calcular sufijo de la especialidad manual
                    local specSuffix = ""
                    local talentsSuffix = ""
                    -- Detección pasiva por buffs activos
                    local cached = addonTable.TalentsCache and addonTable.TalentsCache[casterName]
                    if not cached or not cached.spec or cached.spec == "NONE" then
                        local unit = nil
                        if casterName == UnitName("player") then
                            unit = "player"
                        elseif IsInRaid() then
                            for j = 1, GetNumGroupMembers() do
                                if UnitName("raid" .. j) == casterName then
                                    unit = "raid" .. j
                                    break
                                end
                            end
                        elseif IsInGroup() then
                            for j = 1, GetNumSubgroupMembers() do
                                if UnitName("party" .. j) == casterName then
                                    unit = "party" .. j
                                    break
                                end
                            end
                        end
                        
                        if unit then
                            local detectedSpec = nil
                            for bIdx = 1, 40 do
                                local _, _, _, _, _, _, _, _, _, spellID = UnitBuff(unit, bIdx)
                                if not spellID then break end
                                
                                if spellID == 33891 then -- Forma de Árbol de Vida (Druida Resto)
                                    detectedSpec = "RESTO"
                                elseif spellID == 24858 then -- Forma de Lechúcico Lunar (Druida Equilibrio)
                                    detectedSpec = "BALANCE"
                                elseif spellID == 15473 then -- Forma de Sombra (Priest Shadow)
                                    detectedSpec = "SHADOW"
                                elseif spellID == 25780 then -- Furia Recta (Paladín Prot)
                                    detectedSpec = "PROT"
                                end
                            end
                            
                            if detectedSpec then
                                local talents = {}
                                local defaultTalents = addonTable.Constants.SpecializationTalents[classType] and addonTable.Constants.SpecializationTalents[classType][detectedSpec]
                                if defaultTalents then
                                    for k, v in pairs(defaultTalents) do talents[k] = v end
                                end
                                addonTable.TalentsCache[casterName] = {
                                    class = classType,
                                    spec = detectedSpec,
                                    talents = talents,
                                    source = "BUFF_DETECT"
                                }
                                cached = addonTable.TalentsCache[casterName]
                            end
                        end
                    end
                    
                    if cached then
                        if cached.spec and cached.spec ~= "NONE" then
                            if classType == "PALADIN" then
                                if cached.spec == "HOLY" then specSuffix = " |cffffdd57(Sag)|r"
                                elseif cached.spec == "PROT" then specSuffix = " |cff00ffff(Prot)|r"
                                elseif cached.spec == "RETRI" then specSuffix = " |cffff5757(Rep)|r"
                                end
                            elseif classType == "DRUID" then
                                if cached.spec == "RESTO" then specSuffix = " |cff80ff80(Rest)|r"
                                elseif cached.spec == "FERAL" then specSuffix = " |cffddaa77(Fer)|r"
                                elseif cached.spec == "BALANCE" then specSuffix = " |cff99aaff(Equi)|r"
                                end
                            elseif classType == "PRIEST" then
                                if cached.spec == "DISC" then specSuffix = " |cffddddff(Dis)|r"
                                elseif cached.spec == "HOLY" then specSuffix = " |cffffdd57(Sag)|r"
                                elseif cached.spec == "SHADOW" then specSuffix = " |cffa335ee(Som)|r"
                                end
                            end
                        end
                        
                        -- Generar sufijo de talentos mejorados
                        if cached.talents then
                            local tList = {}
                            if classType == "PALADIN" then
                                if cached.talents.improvedWisdom and cached.talents.improvedWisdom > 0 then
                                    table.insert(tList, "Sab")
                                end
                                if cached.talents.improvedMight and cached.talents.improvedMight > 0 then
                                    table.insert(tList, "Pod")
                                end
                                if cached.talents.improvedSantuario then
                                    table.insert(tList, "San")
                                end
                            elseif classType == "DRUID" then
                                if cached.talents.improvedMark and cached.talents.improvedMark > 0 then
                                    table.insert(tList, "Mar")
                                end
                            elseif classType == "PRIEST" then
                                if cached.talents.improvedFort and cached.talents.improvedFort > 0 then
                                    table.insert(tList, "Ent")
                                end
                                if cached.talents.improvedSpirit and cached.talents.improvedSpirit > 0 then
                                    table.insert(tList, "Esp")
                                end
                            end
                            
                            if #tList > 0 then
                                talentsSuffix = " |cff00ff00[" .. table.concat(tList, ",") .. "]|r"
                            end
                        end
                    end
                    
                    row.name:SetText("|c" .. colorHex .. displayName .. "|r" .. specSuffix .. talentsSuffix)
                    
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
                            
                            local isHazard = false
                            if classType == "PALADIN" then
                                isHazard = Scanner:HasSalvationTankHazard(casterName, targetID)
                            end
                            
                            if assignedSpell then
                                local _, icon = L:GetSpellInfo(assignedSpell)
                                cell.icon:SetTexture(icon)
                                cell.icon:SetAlpha(1.0)
                                if isHazard then
                                    cell:SetBackdropColor(0.35, 0.05, 0.05, 0.95)
                                    cell:SetBackdropBorderColor(1.0, 0.1, 0.1, 1) -- Borde rojo brillante de peligro
                                else
                                    cell:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
                                    cell:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                                end
                            else
                                cell.icon:SetTexture(nil)
                                if isHazard then
                                    cell:SetBackdropColor(0.35, 0.05, 0.05, 0.95)
                                    cell:SetBackdropBorderColor(1.0, 0.1, 0.1, 1)
                                else
                                    cell:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
                                    cell:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                                end
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
        showAllCheck:SetPoint("BOTTOMLEFT", 10, 7)
        reportBtn:SetPoint("BOTTOMLEFT", 160, 9)
        
        -- Botón de propuesta (Varita Mágica)
        proposalBtn:SetPoint("BOTTOMLEFT", 245, 9)
        proposalBtn:Show()
        
        -- Anclar la casilla de delegado
        delegateLbl:SetPoint("BOTTOMLEFT", 330, 13)
        delegateLbl:Show()
        
        delegateEdit:SetPoint("BOTTOMLEFT", 380, 10)
        delegateEdit:Show()
        
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
    
    if SubFrame and SubFrame:IsShown() then
        SubFrame:RefreshList()
    end
    if ReportPanel and ReportPanel:IsShown() then
        ReportPanel:UpdateReport()
    end
end

-- ============================================================================
-- VENTANA DE SUB-ASIGNACIONES INDIVIDUALES (MOCKUP v1.3.0)
-- ============================================================================
SubFrame = CreateFrame("Frame", "RaidBuffetSubAssignFrame", Grid, "BackdropTemplate")
SubFrame:SetSize(440, 300)
SubFrame:SetPoint("TOPLEFT", Grid, "TOPRIGHT", 2, 0)
SubFrame:EnableMouse(true)
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

-- ============================================================================
-- BARRA SUPERIOR DE SELECTOR DE CLASE (UI PREMIUM)
-- ============================================================================
local CLASS_ICON_COORDS = {
    ["WARRIOR"] = {0, 0.25, 0, 0.25},
    ["MAGE"]    = {0.25, 0.5, 0, 0.25},
    ["ROGUE"]   = {0.5, 0.75, 0, 0.25},
    ["DRUID"]   = {0.75, 1, 0, 0.25},
    ["HUNTER"]  = {0, 0.25, 0.25, 0.5},
    ["SHAMAN"]  = {0.25, 0.5, 0.25, 0.5},
    ["PRIEST"]  = {0.5, 0.75, 0.25, 0.5},
    ["WARLOCK"] = {0.75, 1, 0.25, 0.5},
    ["PALADIN"] = {0, 0.25, 0.5, 0.75}
}

local classList = {
    "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN", "PALADIN"
}

SubFrame.classButtons = {}
for i, className in ipairs(classList) do
    local btn = CreateFrame("Button", nil, SubFrame, "BackdropTemplate")
    btn:SetSize(22, 22)
    btn:SetPoint("TOPLEFT", SubFrame, "TOPLEFT", 73 + (i-1)*34, -30) -- Centrado horizontal en 440px
    
    -- Icono de clase de Blizzard redondo nativo
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    icon:SetTexCoord(unpack(CLASS_ICON_COORDS[className]))
    icon:SetAllPoints(btn)
    btn.icon = icon
    
    -- Borde brillante dorado para el botón seleccionado
    local selectGlow = btn:CreateTexture(nil, "OVERLAY")
    selectGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    selectGlow:SetBlendMode("ADD")
    selectGlow:SetAllPoints(btn)
    selectGlow:Hide()
    btn.selectGlow = selectGlow
    
    btn:SetScript("OnClick", function()
        SubFrame.targetClass = className
        SubFrame.title:SetText("Asignación Individual: " .. (L:GetClassName(className) or className))
        SubFrame:RefreshList()
    end)
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        local color = GetClassColorObj(className)
        GameTooltip:AddLine(L:GetClassName(className) or className, color.r, color.g, color.b)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    SubFrame.classButtons[className] = btn
end

function SubFrame:UpdateSelectorGlow()
    for cName, btn in pairs(SubFrame.classButtons) do
        if SubFrame.targetClass == cName then
            btn.selectGlow:Show()
            btn.icon:SetAlpha(1.0)
        else
            btn.selectGlow:Hide()
            btn.icon:SetAlpha(0.4)
        end
    end
end

local SubScrollFrame = CreateFrame("ScrollFrame", "RaidBuffetSubAssignScrollFrame", SubFrame, "UIPanelScrollFrameTemplate")
SubScrollFrame:SetPoint("TOPLEFT", 10, -85)  -- Ajustado para dar espacio a la barra de clase
SubScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

if _G["RaidBuffetSubAssignScrollFrameScrollBar"] then
    _G["RaidBuffetSubAssignScrollFrameScrollBar"]:SetAlpha(0)
    _G["RaidBuffetSubAssignScrollFrameScrollBarScrollUpButton"]:SetAlpha(0)
    _G["RaidBuffetSubAssignScrollFrameScrollBarScrollDownButton"]:SetAlpha(0)
end

SubFrame.casterLabel = SubFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
SubFrame.casterLabel:SetPoint("TOPLEFT", 15, -65)  -- Ajustado para las etiquetas
SubFrame.casterLabel:SetText("Caster (Bufa)")
SubFrame.casterLabel:SetTextColor(0.6, 0.6, 0.6)

SubFrame.targetLabel = SubFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
SubFrame.targetLabel:SetPoint("TOPLEFT", 115, -65) -- Ajustado para las etiquetas
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

local function GetUnitRole(unit, name, class)
    if Scanner:IsMainTank(unit) then
        return "TANK"
    end
    
    if UnitGroupRolesAssigned then
        local role = UnitGroupRolesAssigned(unit)
        if role and role ~= "NONE" then
            return role
        end
    end
    
    -- Inferir a partir de la caché de especialidad manual
    local specCache = addonTable.TalentsCache and addonTable.TalentsCache[name]
    if specCache and specCache.spec then
        local spec = specCache.spec
        if spec == "Sagrado" or spec == "Restauración" or spec == "Disciplina" then
            return "HEALER"
        elseif spec == "Protección" then
            return "TANK"
        elseif spec == "Feral" then
            return "TANK"
        end
    end
    
    -- Inferir por clases puras
    if class == "MAGE" or class == "ROGUE" or class == "HUNTER" or class == "WARLOCK" then
        return "DAMAGER"
    elseif class == "PRIEST" then
        return "HEALER"
    end
    
    return "DAMAGER"
end

function SubFrame:RefreshList()

    -- Actualizar el brillo dorado del selector superior de clase
    SubFrame:UpdateSelectorGlow()

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
            SubFrame.rows[1] = row
        end
        row.name:ClearAllPoints()
        row.name:SetPoint("CENTER", row, "CENTER", 0, 0)
        row.name:SetText("|cffaaaaaaNo hay jugadores o paladines activos|r")
        row.name:Show()
        
        -- Ocultar los botones de bendición de esta fila si ya existían para evitar iconos fantasma
        if row.buttons then
            for _, btn in ipairs(row.buttons) do
                btn:Hide()
            end
        end
        
        row:ClearAllPoints()
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
                h:SetSize(36, 26) -- Mayor tamaño para dos líneas de texto
                h.text = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                h.text:SetPoint("CENTER", 0, 0)
                SubFrame.headers[i] = h
            end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", SubScrollChild, "TOPLEFT", 100 + (i-1)*40, -10)
            
            -- Detectar rol e icono visual
            local role = GetUnitRole(pData.unit, pData.name, pData.class)
            local roleText = "|cffff5555DPS|r"
            if role == "TANK" then
                roleText = "|cff00ffffTNK|r"
            elseif role == "HEALER" then
                roleText = "|cff00ff00HEL|r"
            end
            
            local isMT = Scanner:IsMainTank(pData.unit)
            local displayName
            if isMT then
                displayName = roleText .. "\n|cff00ffff" .. string.sub(pData.name, 1, 4) .. "|r"
                if not h.shieldIcon then
                    h.shieldIcon = h:CreateTexture(nil, "OVERLAY")
                    h.shieldIcon:SetSize(12, 12)
                    h.shieldIcon:SetTexture("Interface\\GroupFrame\\UI-Group-MainTankIcon")
                    h.shieldIcon:SetPoint("TOPRIGHT", h, "TOPRIGHT", 2, 2)
                end
                h.shieldIcon:Show()
            else
                displayName = roleText .. "\n" .. string.sub(pData.name, 1, 4)
                if h.shieldIcon then h.shieldIcon:Hide() end
            end
            h.text:SetText(displayName)
            
            local color = GetClassColorObj(pData.class)
            h.text:SetTextColor(color.r, color.g, color.b)
            
            -- Tooltip con nombre completo y rol
            h:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:ClearLines()
                local titleName = pData.name
                if isMT then
                    titleName = "|cff00ffff[T]|r " .. titleName
                end
                
                local roleDesc = "Daño (DPS)"
                if role == "TANK" then 
                    roleDesc = "Tanque Principal"
                elseif role == "HEALER" then 
                    roleDesc = "Sanador (Healer)" 
                end
                
                GameTooltip:AddDoubleLine(titleName, "|cffffd100" .. roleDesc .. "|r", color.r, color.g, color.b, 1, 0.82, 0)
                if isMT then
                    GameTooltip:AddLine("|cffff0000* TANQUE PRINCIPAL *|r", 1, 0, 0)
                end
                GameTooltip:Show()
            end)
            h:SetScript("OnLeave", function() GameTooltip:Hide() end)
            h:Show()
        end
    end
    
    -- 4. Dibujar filas de paladines (Casters)
    local yOffset = 45 -- Mayor separación vertical para cabeceras de 2 líneas
    for rowIndex, palName in ipairs(paladins) do
        local row = SubFrame.rows[rowIndex]
        if not row then
            row = CreateFrame("Frame", nil, SubScrollChild)
            row:SetSize(380, 24)
            
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.name:SetWidth(90)
            row.name:SetJustifyH("LEFT")
            
            SubFrame.rows[rowIndex] = row
        end
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row, "LEFT", 5, 0)
        
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", SubScrollChild, "TOPLEFT", 0, -yOffset)
        
        if not row.buttons then
            row.buttons = {}
        end
        
        for pIdx = 1, 8 do
            local btn = row.buttons[pIdx]
            if not btn then
                btn = CreateFrame("Button", nil, row, "BackdropTemplate")
                btn:SetSize(20, 20)
                
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
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", row, "LEFT", 108 + (pIdx-1)*40, 0) -- Alineado al píxel centrado bajo las cabeceras
        end
        
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
                
                local isHazard = (assignedSpell == 25895 and Scanner:IsMainTank(pData.unit))
                
                if assignedSpell and assignedSpell ~= "CLEAR" and assignedSpell ~= 0 then
                    local _, icon = L:GetSpellInfo(assignedSpell)
                    btn.icon:SetTexture(icon)
                    if isIndividual then
                        btn.icon:SetAlpha(1.0)
                        if isHazard then
                            btn:SetBackdropColor(0.35, 0.05, 0.05, 0.95)
                            btn:SetBackdropBorderColor(1.0, 0.1, 0.1, 1)
                        else
                            btn:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
                            btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                        end
                    else
                        btn.icon:SetAlpha(0.35)
                        if isHazard then
                            btn:SetBackdropColor(0.35, 0.05, 0.05, 0.95)
                            btn:SetBackdropBorderColor(1.0, 0.1, 0.1, 1)
                        else
                            btn:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
                            btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                        end
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
                    if isHazard then
                        GameTooltip:SetOwner(self, "ANCHOR_TOP")
                        GameTooltip:ClearLines()
                        GameTooltip:AddLine("|cffff0000¡PELIGRO DE SALVACIÓN!|r", 1, 0, 0)
                        GameTooltip:AddLine(string.format("Este jugador es Tanque y recibirá Salvación (%s).", isIndividual and "Individual" or "De clase"), 1, 1, 1)
                        GameTooltip:AddLine("Cambia a otra bendición o selecciona 'Ninguno'\npara anular el buff de clase.", 0.9, 0.9, 0)
                        GameTooltip:Show()
                    end
                end)
                
                btn:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                    if isHazard then
                        self:SetBackdropBorderColor(1.0, 0.1, 0.1, 1)
                    else
                        local assignedSpell = nil
                        if addonTable.Assignments["PALADIN"] and addonTable.Assignments["PALADIN"][palName] then
                            assignedSpell = addonTable.Assignments["PALADIN"][palName][pData.name]
                        end
                        if assignedSpell then
                            self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                        else
                            self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                        end
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
    SubFrame:SetPoint("TOPLEFT", Grid, "TOPRIGHT", 2, 0)
    SubFrame:RefreshList()
    SubFrame:Show()
end

showAllCheck:SetScript("OnShow", function(self) if RaidBuffetDB then self:SetChecked(RaidBuffetDB.ShowAllClasses) end end)

Grid:SetScript("OnShow", function(self)
    self:UpdateGrid()
    if not SubFrame.targetClass then
        SubFrame.targetClass = "WARRIOR"
    end
    SubFrame.title:SetText("Asignación Individual: " .. (L:GetClassName(SubFrame.targetClass) or SubFrame.targetClass))
    SubFrame:ClearAllPoints()
    SubFrame:SetPoint("TOPLEFT", Grid, "TOPRIGHT", 2, 0)
    SubFrame:RefreshList()
    SubFrame:Show()
    
    if addonTable.TestModeActive and addonTable.TestPanel then
        addonTable.TestPanel:ShowPanel()
    end
end)

Grid:SetScript("OnHide", function(self)
    SubFrame:Hide()
    if ReportPanel then
        ReportPanel:Hide()
    end
    if addonTable.TestPanel then
        addonTable.TestPanel:Hide()
    end
end)

-- ============================================================================
-- PANEL DE REPORTES DE FALTANTES (INTEGRADO - DRAWER IZQUIERDO)
-- ============================================================================
ReportPanel = CreateFrame("Frame", "RaidBuffetReportPanel", Grid, "BackdropTemplate")
ReportPanel:SetSize(380, 300)
ReportPanel:SetPoint("TOPRIGHT", Grid, "TOPLEFT", -2, 0)
ReportPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
ReportPanel:SetBackdropColor(0.06, 0.06, 0.06, 0.94)
ReportPanel:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
ReportPanel:Hide()

ReportPanel.title = ReportPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ReportPanel.title:SetPoint("TOPLEFT", 10, -8)
ReportPanel.title:SetText("Reporte de Faltantes")
ReportPanel.title:SetTextColor(0.8, 0.6, 0.2)

local ReportScrollFrame = CreateFrame("ScrollFrame", "RaidBuffetReportScrollFrame", ReportPanel, "UIPanelScrollFrameTemplate")
ReportScrollFrame:SetPoint("TOPLEFT", 10, -30)
ReportScrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

if _G["RaidBuffetReportScrollFrameScrollBar"] then
    _G["RaidBuffetReportScrollFrameScrollBar"]:SetAlpha(0)
    _G["RaidBuffetReportScrollFrameScrollBarScrollUpButton"]:SetAlpha(0)
    _G["RaidBuffetReportScrollFrameScrollBarScrollDownButton"]:SetAlpha(0)
end

local ReportScrollChild = CreateFrame("Frame", "RaidBuffetReportScrollChild", ReportScrollFrame)
ReportScrollChild:SetSize(260, 1)
ReportScrollFrame:SetScrollChild(ReportScrollChild)

ReportPanel.rows = {}

local function GetClassColorHex(classFileName)
    local color = GetClassColorObj(classFileName)
    return string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end

function ReportPanel:UpdateReport()
    local missing = Scanner:GetMissingBuffsReport()
    
    for _, row in ipairs(ReportPanel.rows) do
        row:Hide()
    end
    
    local yOffset = 0
    local rowIndex = 1
    
    if #missing == 0 then
        if not ReportPanel.noMissingText then
            ReportPanel.noMissingText = ReportScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            ReportPanel.noMissingText:SetPoint("CENTER", ReportScrollFrame, "CENTER", 0, 0)
            ReportPanel.noMissingText:SetText("|cff00ff00¡Todos buffeados!|r")
        end
        ReportPanel.noMissingText:Show()
    else
        if ReportPanel.noMissingText then
            ReportPanel.noMissingText:Hide()
        end
        for _, data in ipairs(missing) do
            local row = ReportPanel.rows[rowIndex]
            if not row then
                row = CreateFrame("Frame", nil, ReportScrollChild)
                row:SetSize(260, 30)
                
                row.iconCaster = row:CreateTexture(nil, "ARTWORK")
                row.iconCaster:SetSize(18, 18)
                row.iconCaster:SetPoint("LEFT", 5, 0)
                
                row.iconSpell = row:CreateTexture(nil, "ARTWORK")
                row.iconSpell:SetSize(18, 18)
                row.iconSpell:SetPoint("LEFT", row.iconCaster, "RIGHT", 6, 0)
                
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", row.iconSpell, "RIGHT", 6, 0)
                row.text:SetWidth(200)
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(true)
                
                ReportPanel.rows[rowIndex] = row
            end
            
            row:SetPoint("TOPLEFT", ReportScrollChild, "TOPLEFT", 0, -yOffset)
            
            local coords = CLASS_BUTTONS[data.casterClass]
            if coords then
                row.iconCaster:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                row.iconCaster:SetTexCoord(unpack(coords))
            else
                row.iconCaster:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            
            local _, spellIcon = L:GetSpellInfo(data.spellID)
            row.iconSpell:SetTexture(spellIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
            
            local targetName = data.targetID
            if string.find(targetName, "GROUP_") then
                targetName = "G" .. string.match(targetName, "GROUP_(%d+)")
            else
                targetName = L:GetClassName(targetName)
            end
            
            local cColor = GetClassColorHex(data.casterClass)
            local spellNameShort = string.gsub(data.spellName, " superior", "")
            spellNameShort = string.gsub(spellNameShort, "Bendición de ", "B. ")
            
            local missList = table.concat(data.missingPlayers, ", ")
            row.text:SetText(string.format("|c%s%s|r debe poner |cffffd100%s|r a %s\n|cff888888(Faltan: %s)|r", 
                cColor, data.casterName, spellNameShort, targetName, missList))
            
            row:Show()
            yOffset = yOffset + 34
            rowIndex = rowIndex + 1
        end
    end
    ReportScrollChild:SetHeight(yOffset + 10)
end

local function AnnounceToGroup(lines)
    local channel = RaidBuffetDB and RaidBuffetDB.AnnounceChannel or "RAID"
    if not IsInGroup() then
        for _, line in ipairs(lines) do
            print(line)
        end
        return
    end
    for _, line in ipairs(lines) do
        SendChatMessage(line, channel)
    end
end

function ReportPanel:AnnounceAssignments()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, classFileName = GetRaidRosterInfo(i)
            if name and classFileName then
                name = string.match(name, "([^%-]+)")
                units[name] = true
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local name = UnitName("party" .. i)
            if name then
                name = string.match(name, "([^%-]+)")
                units[name] = true
            end
        end
        units[UnitName("player")] = true
    else
        units[UnitName("player")] = true
    end
    
    local lines = {}
    table.insert(lines, "[RaidBuffet] --- Asignaciones de Buffs ---")
    local hasAny = false
    
    for casterClass, casters in pairs(addonTable.Assignments) do
        for casterName, targets in pairs(casters) do
            if units[casterName] or (not IsInGroup() and casterName == UnitName("player")) then
                local buffsGrouped = {}
                for targetID, spellID in pairs(targets) do
                    local spellName = L:GetSpellInfo(spellID)
                    if spellName then
                        local tName = targetID
                        if string.find(tName, "GROUP_") then
                            tName = "G" .. string.match(tName, "GROUP_(%d+)")
                        else
                            tName = L:GetClassName(tName)
                        end
                        if not buffsGrouped[spellName] then
                            buffsGrouped[spellName] = {}
                        end
                        table.insert(buffsGrouped[spellName], tName)
                    end
                end
                
                local playerBuffs = {}
                for spellName, targetsList in pairs(buffsGrouped) do
                    table.insert(playerBuffs, spellName .. " a " .. table.concat(targetsList, "/"))
                end
                
                if #playerBuffs > 0 then
                    hasAny = true
                    table.insert(lines, string.format("%s (%s) buffea: %s", casterName, L:GetClassName(casterClass), table.concat(playerBuffs, ", ")))
                end
            end
        end
    end
    
    if not hasAny then
        table.insert(lines, "No hay buffs asignados.")
    end
    AnnounceToGroup(lines)
end

function ReportPanel:AnnounceMissing()
    local missing = Scanner:GetMissingBuffsReport()
    local lines = {}
    table.insert(lines, "[RaidBuffet] --- Buffs Faltantes ---")
    
    if #missing == 0 then
        table.insert(lines, "¡Todos los buffs están al día!")
    else
        for _, data in ipairs(missing) do
            local targetName = data.targetID
            if string.find(targetName, "GROUP_") then
                targetName = "Grupo " .. string.match(targetName, "GROUP_(%d+)")
            else
                targetName = L:GetClassName(targetName)
            end
            local missingList = table.concat(data.missingPlayers, ", ")
            table.insert(lines, string.format("%s (%s) debe poner %s a %s (Faltan: %s)", 
                data.casterName, data.casterClass, data.spellName, targetName, missingList))
        end
    end
    AnnounceToGroup(lines)
end

-- Despachador de cola asíncrono para susurros (Anti-Spam / Throttling)
local whisperQueue = {}
local whisperDelay = 0.3
local whisperTimer = 0
local whisperFrame = CreateFrame("Frame")

whisperFrame:SetScript("OnUpdate", function(self, elapsed)
    if #whisperQueue == 0 then
        self:Hide()
        return
    end
    
    whisperTimer = whisperTimer + elapsed
    if whisperTimer >= whisperDelay then
        whisperTimer = 0
        local item = table.remove(whisperQueue, 1)
        if item and item.target and item.msg then
            SendChatMessage(item.msg, "WHISPER", nil, item.target)
        end
    end
end)
whisperFrame:Hide()

function ReportPanel:WhisperAssignments()
    local assignments = addonTable.Assignments
    local myName = UnitName("player")
    
    local castersToWhisper = {}
    
    for class, casters in pairs(assignments) do
        for casterName, targets in pairs(casters) do
            if casterName ~= myName then
                local casterExists = false
                if IsInRaid() then
                    for i = 1, GetNumGroupMembers() do
                        local name = GetRaidRosterInfo(i)
                        if name and string.match(name, "([^%-]+)") == casterName then
                            casterExists = true
                            break
                        end
                    end
                elseif IsInGroup() then
                    for i = 1, GetNumSubgroupMembers() do
                        local name = UnitName("party" .. i)
                        if name and string.match(name, "([^%-]+)") == casterName then
                            casterExists = true
                            break
                        end
                    end
                end
                
                if casterExists then
                    castersToWhisper[casterName] = { class = class, targets = targets }
                end
            end
        end
    end
    
    local queuedCount = 0
    for name, data in pairs(castersToWhisper) do
        local buffsList = {}
        for targetID, spellID in pairs(data.targets) do
            local spellName = L:GetSpellInfo(spellID)
            if spellName and spellID ~= "CLEAR" and spellID ~= 0 then
                local targetDesc = targetID
                if string.find(targetID, "GROUP_") then
                    targetDesc = "G" .. string.match(targetID, "GROUP_(%d+)")
                else
                    targetDesc = L:GetClassName(targetID) or targetID
                    targetDesc = string.sub(targetDesc, 1, 3) -- Abreviar clase
                end
                table.insert(buffsList, spellName .. " a " .. targetDesc)
            end
        end
        
        if #buffsList > 0 then
            local intro = "[RaidBuffet] Tus tareas asignadas: "
            local msg = intro .. table.concat(buffsList, ", ")
            
            if string.len(msg) > 235 then
                local currentMsg = intro
                for idx, buffStr in ipairs(buffsList) do
                    if string.len(currentMsg .. buffStr) > 230 then
                        table.insert(whisperQueue, { target = name, msg = currentMsg })
                        currentMsg = "[RaidBuffet] ... y: " .. buffStr
                        queuedCount = queuedCount + 1
                    else
                        if currentMsg == intro or currentMsg == "[RaidBuffet] ... y: " then
                            currentMsg = currentMsg .. buffStr
                        else
                            currentMsg = currentMsg .. ", " .. buffStr
                        end
                    end
                end
                if currentMsg ~= "[RaidBuffet] ... y: " then
                    table.insert(whisperQueue, { target = name, msg = currentMsg })
                    queuedCount = queuedCount + 1
                end
            else
                table.insert(whisperQueue, { target = name, msg = msg })
                queuedCount = queuedCount + 1
            end
        end
    end
    
    if queuedCount > 0 then
        print(string.format("|cff00ff00[RaidBuffet]|r Enviando tareas individuales a %d buffers. Cola de transmisión iniciada de forma segura...", queuedCount))
        whisperFrame:Show()
    else
        print("|cffff0000[RaidBuffet]|r No hay tareas asignadas para otros jugadores en la raid.")
    end
end

-- Botones inferiores compactos
local rRefreshBtn = CreateFrame("Button", nil, ReportPanel, "BackdropTemplate")
rRefreshBtn:SetSize(65, 22)
rRefreshBtn:SetPoint("BOTTOMLEFT", 10, 10)
rRefreshBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
rRefreshBtn:SetBackdropColor(0.14, 0.14, 0.14, 1)
rRefreshBtn:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
rRefreshBtn.text = rRefreshBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rRefreshBtn.text:SetPoint("CENTER", 0, 0)
rRefreshBtn.text:SetText("Refrescar")
rRefreshBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.22, 0.22, 0.22, 1)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
end)
rRefreshBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.14, 0.14, 0.14, 1)
    self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
end)
rRefreshBtn:SetScript("OnClick", function()
    ReportPanel:UpdateReport()
end)

local rAnnounceAssignBtn = CreateFrame("Button", nil, ReportPanel, "BackdropTemplate")
rAnnounceAssignBtn:SetSize(95, 22)
rAnnounceAssignBtn:SetPoint("LEFT", rRefreshBtn, "RIGHT", 5, 0)
rAnnounceAssignBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
rAnnounceAssignBtn:SetBackdropColor(0.14, 0.14, 0.14, 1)
rAnnounceAssignBtn:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
rAnnounceAssignBtn.text = rAnnounceAssignBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rAnnounceAssignBtn.text:SetPoint("CENTER", 0, 0)
rAnnounceAssignBtn.text:SetText("Anun. Tareas")
rAnnounceAssignBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.22, 0.22, 0.22, 1)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
end)
rAnnounceAssignBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.14, 0.14, 0.14, 1)
    self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
end)
rAnnounceAssignBtn:SetScript("OnClick", function()
    ReportPanel:AnnounceAssignments()
end)

local rAnnounceMissingBtn = CreateFrame("Button", nil, ReportPanel, "BackdropTemplate")
rAnnounceMissingBtn:SetSize(95, 22)
rAnnounceMissingBtn:SetPoint("LEFT", rAnnounceAssignBtn, "RIGHT", 5, 0)
rAnnounceMissingBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
rAnnounceMissingBtn:SetBackdropColor(0.14, 0.14, 0.14, 1)
rAnnounceMissingBtn:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
rAnnounceMissingBtn.text = rAnnounceMissingBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rAnnounceMissingBtn.text:SetPoint("CENTER", 0, 0)
rAnnounceMissingBtn.text:SetText("Anun. Faltas")
rAnnounceMissingBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.22, 0.22, 0.22, 1)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
end)
rAnnounceMissingBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.14, 0.14, 0.14, 1)
    self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
end)
rAnnounceMissingBtn:SetScript("OnClick", function()
    ReportPanel:AnnounceMissing()
end)

local rWhisperAssignBtn = CreateFrame("Button", nil, ReportPanel, "BackdropTemplate")
rWhisperAssignBtn:SetSize(100, 22)
rWhisperAssignBtn:SetPoint("LEFT", rAnnounceMissingBtn, "RIGHT", 5, 0)
rWhisperAssignBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
rWhisperAssignBtn:SetBackdropColor(0.14, 0.14, 0.14, 1)
rWhisperAssignBtn:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
rWhisperAssignBtn.text = rWhisperAssignBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rWhisperAssignBtn.text:SetPoint("CENTER", 0, 0)
rWhisperAssignBtn.text:SetText("Susurrar Tareas")
rWhisperAssignBtn:SetScript("OnEnter", function(self)
    if self.cooldownActive then return end
    self:SetBackdropColor(0.22, 0.22, 0.22, 1)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
end)
rWhisperAssignBtn:SetScript("OnLeave", function(self)
    if self.cooldownActive then return end
    self:SetBackdropColor(0.14, 0.14, 0.14, 1)
    self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
end)
rWhisperAssignBtn:SetScript("OnClick", function(self)
    if self.cooldownActive then return end
    
    ReportPanel:WhisperAssignments()
    
    -- Aplicar Cooldown visual y de lógica por 10 segundos
    self.cooldownActive = true
    self:SetAlpha(0.5)
    self:SetBackdropColor(0.08, 0.08, 0.08, 1)
    self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
    self.text:SetTextColor(0.5, 0.5, 0.5)
    
    local remaining = 10
    self.text:SetText("Esperar (" .. remaining .. "s)")
    
    local cooldownTimer
    cooldownTimer = C_Timer.NewTicker(1, function()
        remaining = remaining - 1
        if remaining > 0 then
            self.text:SetText("Esperar (" .. remaining .. "s)")
        else
            cooldownTimer:Cancel()
            self.cooldownActive = nil
            self:SetAlpha(1.0)
            self:SetBackdropColor(0.14, 0.14, 0.14, 1)
            self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
            self.text:SetTextColor(1, 0.82, 0)
            self.text:SetText("Susurrar Tareas")
        end
    end)
end)

ReportPanel:RegisterEvent("UNIT_AURA")
ReportPanel:RegisterEvent("GROUP_ROSTER_UPDATE")
ReportPanel:SetScript("OnEvent", function(self)
    if self:IsShown() then
        self:UpdateReport()
    end
end)

ReportPanel:SetScript("OnShow", function(self)
    self:UpdateReport()
end)

-- ============================================================================
-- PANEL DE PROPUESTA DE ASIGNACIÓN (DRAWER DE VISTA PREVIA)
-- ============================================================================
ProposalPanel = CreateFrame("Frame", "RaidBuffetProposalPanel", Grid, "BackdropTemplate")
ProposalPanel:SetSize(320, 300)
ProposalPanel:EnableMouse(true)
ProposalPanel:Hide()

ProposalPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
ProposalPanel:SetBackdropColor(0.06, 0.06, 0.06, 0.94)
ProposalPanel:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

ProposalPanel.header = CreateFrame("Frame", nil, ProposalPanel, "BackdropTemplate")
ProposalPanel.header:SetSize(320, 24)
ProposalPanel.header:SetPoint("TOPLEFT", ProposalPanel, "TOPLEFT", 0, 0)
ProposalPanel.header:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
ProposalPanel.header:SetBackdropColor(0.12, 0.12, 0.12, 1)
ProposalPanel.header:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

ProposalPanel.title = ProposalPanel.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ProposalPanel.title:SetPoint("LEFT", 10, 0)
ProposalPanel.title:SetText("Propuesta de Buffs")
ProposalPanel.title:SetTextColor(0.8, 0.6, 0.2)

ProposalPanel.closeBtn = CreateFrame("Button", nil, ProposalPanel.header, "BackdropTemplate")
ProposalPanel.closeBtn:SetSize(16, 16)
ProposalPanel.closeBtn:SetPoint("RIGHT", -6, 0)
ProposalPanel.closeBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
ProposalPanel.closeBtn:SetBackdropColor(0.2, 0.1, 0.1, 1)
ProposalPanel.closeBtn:SetBackdropBorderColor(0.3, 0.15, 0.15, 1)
ProposalPanel.closeBtn.text = ProposalPanel.closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ProposalPanel.closeBtn.text:SetPoint("CENTER", 0, 0)
ProposalPanel.closeBtn.text:SetText("X")
ProposalPanel.closeBtn.text:SetTextColor(0.8, 0.3, 0.3)
ProposalPanel.closeBtn:SetScript("OnClick", function() ProposalPanel:Hide() end)

-- Scroll Frame para la lista de propuestas
local pScroll = CreateFrame("ScrollFrame", nil, ProposalPanel, "UIPanelScrollFrameTemplate")
pScroll:SetPoint("TOPLEFT", 10, -34)
pScroll:SetPoint("BOTTOMRIGHT", -26, 40)

local pScrollChild = CreateFrame("Frame")
pScrollChild:SetSize(280, 200)
pScroll:SetScrollChild(pScrollChild)

ProposalPanel.lines = {}

-- Función dinámica de anclaje de paneles acoplados
local function AnchorPanels()
    if SubFrame and SubFrame:IsShown() then
        ProposalPanel:ClearAllPoints()
        ProposalPanel:SetPoint("TOPLEFT", SubFrame, "TOPRIGHT", 2, 0)
    else
        ProposalPanel:ClearAllPoints()
        ProposalPanel:SetPoint("TOPLEFT", Grid, "TOPRIGHT", 2, 0)
    end
end

-- Hookear cambios de visibilidad en SubFrame para auto-anclar
SubFrame:HookScript("OnShow", AnchorPanels)
SubFrame:HookScript("OnHide", AnchorPanels)

local currentProposal = nil

function ProposalPanel:ShowPreview()
    if not HasEditPermissions() then
        print("|cffff0000[RaidBuffet]|r No tienes permisos de edición para generar propuestas.")
        return
    end

    currentProposal = addonTable.Proposal:GenerateProposal()
    
    -- Limpiar textos antiguos
    for _, fontStr in ipairs(ProposalPanel.lines) do
        fontStr:Hide()
    end
    ProposalPanel.lines = {}
    
    local yOffset = -5
    if #currentProposal.summary == 0 then
        local fs = pScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", pScrollChild, "TOPLEFT", 5, yOffset)
        fs:SetText("|cffaaaaaaNo hay paladines ni casters activos en el grupo.|r")
        fs:Show()
        table.insert(ProposalPanel.lines, fs)
    else
        for _, text in ipairs(currentProposal.summary) do
            local fs = pScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", pScrollChild, "TOPLEFT", 5, yOffset)
            fs:SetWidth(270)
            fs:SetJustifyH("LEFT")
            fs:SetText(text)
            fs:Show()
            table.insert(ProposalPanel.lines, fs)
            yOffset = yOffset - 18
        end
    end
    pScrollChild:SetHeight(math.abs(yOffset) + 10)
    
    AnchorPanels()
    ProposalPanel:Show()
end

-- Botón de Aplicar (Verde)
local pApplyBtn = CreateFrame("Button", nil, ProposalPanel, "BackdropTemplate")
pApplyBtn:SetSize(130, 22)
pApplyBtn:SetPoint("BOTTOMLEFT", 15, 10)
pApplyBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
pApplyBtn:SetBackdropColor(0.1, 0.3, 0.1, 1) -- Verde oscuro
pApplyBtn:SetBackdropBorderColor(0.2, 0.6, 0.2, 1)
pApplyBtn.text = pApplyBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pApplyBtn.text:SetPoint("CENTER", 0, 0)
pApplyBtn.text:SetText("Aplicar Asignación")

pApplyBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.15, 0.45, 0.15, 1)
end)
pApplyBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.1, 0.3, 0.1, 1)
end)
pApplyBtn:SetScript("OnClick", function()
    if currentProposal then
        addonTable.Proposal:ApplyProposal(currentProposal)
        ProposalPanel:Hide()
        Grid:UpdateGrid()
    end
end)

-- Botón de Cancelar (Rojo)
local pCancelBtn = CreateFrame("Button", nil, ProposalPanel, "BackdropTemplate")
pCancelBtn:SetSize(130, 22)
pCancelBtn:SetPoint("BOTTOMRIGHT", -15, 10)
pCancelBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
pCancelBtn:SetBackdropColor(0.3, 0.1, 0.1, 1) -- Rojo oscuro
pCancelBtn:SetBackdropBorderColor(0.6, 0.2, 0.2, 1)
pCancelBtn.text = pCancelBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pCancelBtn.text:SetPoint("CENTER", 0, 0)
pCancelBtn.text:SetText("Cancelar")

pCancelBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.45, 0.15, 0.15, 1)
end)
pCancelBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.3, 0.1, 0.1, 1)
end)
pCancelBtn:SetScript("OnClick", function()
    ProposalPanel:Hide()
end)

-- ============================================================================
-- COMANDOS DE CHAT (SLASH COMMANDS)
-- ============================================================================
SLASH_RAIDBUFFET1 = "/rb"
SLASH_RAIDBUFFET2 = "/raidbuffet"

SlashCmdList["RAIDBUFFET"] = function(msg)
    local cmd, arg = string.match(msg, "^(%S+)%s*(%S*)$")
    if not cmd then cmd = msg end
    
    if cmd == "test" then
        local sub, rName, rClass, rGroup, rRole, rSpec = string.match(arg or "", "^(%S+)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)$")
        if not sub or sub == "" then
            sub = arg
        end
        
        if sub == "10" then
            addonTable.Core:StartTestMode(10)
            if not Grid:IsShown() then Grid:Show() end
            if addonTable.TestPanel then addonTable.TestPanel:ShowPanel() end
        elseif sub == "25" then
            addonTable.Core:StartTestMode(25)
            if not Grid:IsShown() then Grid:Show() end
            if addonTable.TestPanel then addonTable.TestPanel:ShowPanel() end
        elseif sub == "off" then
            addonTable.Core:StopTestMode()
            if addonTable.TestPanel then addonTable.TestPanel:Hide() end
        elseif sub == "clear" then
            addonTable.Core:ClearTestRoster()
            if addonTable.TestPanel then addonTable.TestPanel:UpdateRosterList() end
        elseif sub == "list" then
            addonTable.Core:ListTestRoster()
        elseif sub == "add" then
            addonTable.Core:AddTestMember(rName, rClass, rGroup, rRole, rSpec)
            if addonTable.TestPanel then addonTable.TestPanel:UpdateRosterList() end
        else
            print("|cffff0000[RaidBuffet]|r Uso del Modo Test:")
            print("  /rb test 10 | 25 | off (Carga plantillas)")
            print("  /rb test clear (Vacia el roster, te deja solo a ti)")
            print("  /rb test list (Muestra los miembros virtuales)")
            print("  /rb test add <nombre> <clase> <subgrupo> [tank] [spec]")
            print("    * Clase: paladin, priest, mage, druid, warrior, rogue, hunter, warlock, shaman")
            print("    * Grupo: 1 al 5")
            print("    * spec (opcional): wisdom, might, sant, mark, fort, spirit")
        end
        return
    elseif msg == "debug" then
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
