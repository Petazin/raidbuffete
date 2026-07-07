local addonName, addonTable = ...
local L = addonTable.L

-- Redirecciones locales para Modo Test simulado
local IsInRaid = function() return addonTable:IsInRaid() end
local IsInGroup = function() return addonTable:IsInGroup() end
local GetNumGroupMembers = function() return addonTable:GetNumGroupMembers() end
local GetRaidRosterInfo = function(idx) return addonTable:GetRaidRosterInfo(idx) end
local UnitName = function(unit) return addonTable:UnitName(unit) end
local UnitClass = function(unit) return addonTable:UnitClass(unit) end

local TestPanel = CreateFrame("Frame", "RaidBuffetTestPanel", UIParent, "BackdropTemplate")
TestPanel:SetSize(280, 520)
TestPanel:EnableMouse(true)
TestPanel:Hide()

TestPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
TestPanel:SetBackdropColor(0.06, 0.06, 0.06, 0.94)
TestPanel:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

-- Título del Panel
TestPanel.title = TestPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
TestPanel.title:SetPoint("TOPLEFT", 15, -12)
TestPanel.title:SetText("Configurador de Raid de Test")
TestPanel.title:SetTextColor(0.85, 0.7, 0.3)

-- Botón de Cerrar Panel (X)
TestPanel.closeBtn = CreateFrame("Button", nil, TestPanel, "BackdropTemplate")
TestPanel.closeBtn:SetSize(16, 16)
TestPanel.closeBtn:SetPoint("TOPRIGHT", -10, -10)
TestPanel.closeBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
TestPanel.closeBtn:SetBackdropColor(0.2, 0.1, 0.1, 1)
TestPanel.closeBtn:SetBackdropBorderColor(0.3, 0.15, 0.15, 1)
TestPanel.closeBtn.text = TestPanel.closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
TestPanel.closeBtn.text:SetPoint("CENTER", 0, 0)
TestPanel.closeBtn.text:SetText("X")
TestPanel.closeBtn.text:SetTextColor(0.8, 0.3, 0.3)
TestPanel.closeBtn:SetScript("OnClick", function() TestPanel:Hide() end)

-- Sección 1: Formulario para añadir jugador
local formFrame = CreateFrame("Frame", nil, TestPanel, "BackdropTemplate")
formFrame:SetSize(250, 240)
formFrame:SetPoint("TOPLEFT", 15, -35)
formFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
formFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
formFrame:SetBackdropBorderColor(0.16, 0.16, 0.16, 1)

-- EditBox de Nombre
local nameLabel = formFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameLabel:SetPoint("TOPLEFT", 8, -8)
nameLabel:SetText("Nombre:")

local nameInput = CreateFrame("EditBox", "RaidBuffetTestNameInput", formFrame, "InputBoxTemplate")
nameInput:SetSize(100, 18)
nameInput:SetPoint("TOPLEFT", 60, -5)
nameInput:SetAutoFocus(false)
nameInput:SetMaxLetters(12)

-- Selector de Grupo (1 al 5)
local groupLabel = formFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
groupLabel:SetPoint("TOPLEFT", 168, -8)
groupLabel:SetText("G:")

local groupButtons = {}
local selectedGroup = 1

local function SetSelectedGroup(gNum)
    selectedGroup = gNum
    for num, btn in pairs(groupButtons) do
        if num == gNum then
            btn:SetBackdropColor(0.7, 0.5, 0.2, 1)
            btn.text:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(0.14, 0.14, 0.14, 1)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
end

for g = 1, 5 do
    local btn = CreateFrame("Button", nil, formFrame, "BackdropTemplate")
    btn:SetSize(14, 14)
    btn:SetPoint("TOPLEFT", groupLabel, "RIGHT", 5 + (g - 1) * 16, 2)
    btn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("CENTER", 0, 0)
    btn.text:SetText(g)
    
    btn:SetScript("OnClick", function() SetSelectedGroup(g) end)
    groupButtons[g] = btn
end
SetSelectedGroup(1)

-- Selector de Clases (Grid 3x3)
local classLabel = formFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
classLabel:SetPoint("TOPLEFT", 8, -32)
classLabel:SetText("Clase:")

local classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
local classButtons = {}
local selectedClass = "WARRIOR"

-- Contenedores de opciones dinámicas según la clase elegida
local tankCheck = CreateFrame("CheckButton", "RaidBuffetTestTankCheck", formFrame, "UICheckButtonTemplate")
tankCheck:SetSize(20, 20)
tankCheck:SetPoint("TOPLEFT", 8, -100)
_G[tankCheck:GetName() .. "Text"]:SetText("Es Tanque Principal (MT)")
_G[tankCheck:GetName() .. "Text"]:SetFontObject("GameFontNormalSmall")

local specLabel = formFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
specLabel:SetPoint("TOPLEFT", 8, -135)
specLabel:SetText("Especialización / Talento:")

local specRadios = {}
local selectedSpec = "none"

local function UpdateSpecLayout()
    -- Mostrar/ocultar rol de tanque y talentos según la clase elegida
    if selectedClass == "WARRIOR" or selectedClass == "PALADIN" or selectedClass == "DRUID" then
        tankCheck:Show()
    else
        tankCheck:Hide()
        tankCheck:SetChecked(false)
    end
    
    -- Ocultar todos los radios de specs
    specLabel:Hide()
    for _, rb in pairs(specRadios) do rb:Hide() end
    
    if selectedClass == "PALADIN" then
        specLabel:Show()
        specRadios["none"]:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -5)
        specRadios["none"]:Show()
        _G[specRadios["none"]:GetName() .. "Text"]:SetText("Ninguna")
        
        specRadios["wisdom"]:SetPoint("TOPLEFT", specRadios["none"], "BOTTOMLEFT", 0, -8)
        specRadios["wisdom"]:Show()
        _G[specRadios["wisdom"]:GetName() .. "Text"]:SetText("Sabiduría Mej.")
        
        specRadios["might"]:SetPoint("LEFT", specRadios["none"].text, "RIGHT", 30, 0)
        specRadios["might"]:Show()
        _G[specRadios["might"]:GetName() .. "Text"]:SetText("Poder Mej.")
        
        specRadios["sant"]:SetPoint("LEFT", specRadios["wisdom"].text, "RIGHT", 30, 0)
        specRadios["sant"]:Show()
        _G[specRadios["sant"]:GetName() .. "Text"]:SetText("Santuario")
    elseif selectedClass == "PRIEST" then
        specLabel:Show()
        specRadios["none"]:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -5)
        specRadios["none"]:Show()
        _G[specRadios["none"]:GetName() .. "Text"]:SetText("Ninguna")
        
        specRadios["fort"]:SetPoint("TOPLEFT", specRadios["none"], "BOTTOMLEFT", 0, -8)
        specRadios["fort"]:Show()
        _G[specRadios["fort"]:GetName() .. "Text"]:SetText("Entereza Mej.")
        
        specRadios["spirit"]:SetPoint("LEFT", specRadios["none"].text, "RIGHT", 30, 0)
        specRadios["spirit"]:Show()
        _G[specRadios["spirit"]:GetName() .. "Text"]:SetText("Espíritu Mej.")
    elseif selectedClass == "DRUID" then
        specLabel:Show()
        specRadios["none"]:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -5)
        specRadios["none"]:Show()
        _G[specRadios["none"]:GetName() .. "Text"]:SetText("Ninguna")
        
        specRadios["mark"]:SetPoint("TOPLEFT", specRadios["none"], "BOTTOMLEFT", 0, -8)
        specRadios["mark"]:Show()
        _G[specRadios["mark"]:GetName() .. "Text"]:SetText("Marca Mej.")
    end
end

local function SetSelectedClass(class)
    selectedClass = class
    selectedSpec = "none"
    for _, rb in pairs(specRadios) do rb:SetChecked(rb.specVal == "none") end
    
    for cName, btn in pairs(classButtons) do
        if cName == class then
            btn.border:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
            btn.border:SetBackdropColor(0.2, 0.18, 0.1, 0.6)
        else
            btn.border:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
            btn.border:SetBackdropColor(0, 0, 0, 0)
        end
    end
    UpdateSpecLayout()
end

for i, class in ipairs(classes) do
    local btn = CreateFrame("Button", nil, formFrame)
    btn:SetSize(22, 22)
    local row = math.floor((i - 1) / 5)
    local col = (i - 1) % 5
    btn:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", col * 26 + 10, -row * 24 - 5)
    
    -- Icono de clase de Blizzard
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    local coords = CLASS_ICON_TCOORDS[class]
    if coords then
        icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
    
    -- Borde de selección
    btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.border:SetSize(26, 26)
    btn.border:SetPoint("CENTER", 0, 0)
    btn.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    btn.border:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
    btn.border:SetBackdropColor(0, 0, 0, 0)
    
    btn:SetScript("OnClick", function() SetSelectedClass(class) end)
    
    -- Tooltip informativo
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L:GetClassName(class) or class, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    classButtons[class] = btn
end

-- Crear Radios de Talentos
local function CreateSpecRadio(name, labelText, specVal)
    local btn = CreateFrame("CheckButton", name, formFrame, "UIRadioButtonTemplate")
    btn:SetSize(14, 14)
    btn.text = _G[btn:GetName() .. "Text"]
    btn.text:SetFontObject("GameFontHighlightSmall")
    btn.text:SetText(labelText)
    btn.specVal = specVal
    
    btn:SetScript("OnClick", function(self)
        selectedSpec = self.specVal
        for _, rb in pairs(specRadios) do
            rb:SetChecked(rb == self)
        end
    end)
    return btn
end

specRadios["none"] = CreateSpecRadio("RaidBuffetTestSpecNone", "Ninguna", "none")
specRadios["wisdom"] = CreateSpecRadio("RaidBuffetTestSpecWisdom", "Sabiduría", "wisdom")
specRadios["might"] = CreateSpecRadio("RaidBuffetTestSpecMight", "Poder", "might")
specRadios["sant"] = CreateSpecRadio("RaidBuffetTestSpecSant", "Santuario", "sant")
specRadios["mark"] = CreateSpecRadio("RaidBuffetTestSpecMark", "Marca", "mark")
specRadios["fort"] = CreateSpecRadio("RaidBuffetTestSpecFort", "Entereza", "fort")
specRadios["spirit"] = CreateSpecRadio("RaidBuffetTestSpecSpirit", "Espíritu", "spirit")

SetSelectedClass("WARRIOR")

-- Botón de Añadir (Verde)
local addBtn = CreateFrame("Button", nil, formFrame, "BackdropTemplate")
addBtn:SetSize(234, 20)
addBtn:SetPoint("BOTTOMLEFT", 8, 8)
addBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
addBtn:SetBackdropColor(0.12, 0.32, 0.12, 1)
addBtn:SetBackdropBorderColor(0.2, 0.6, 0.2, 1)
addBtn.text = addBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
addBtn.text:SetPoint("CENTER", 0, 0)
addBtn.text:SetText("Añadir Jugador a la Simulación")

addBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.18, 0.48, 0.18, 1)
end)
addBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.12, 0.32, 0.12, 1)
end)
addBtn:SetScript("OnClick", function()
    local name = nameInput:GetText()
    name = string.gsub(name, "%s+", "") -- Sin espacios
    if name == "" then
        print("|cffff0000[RaidBuffet]|r Error: Escribe un nombre.")
        return
    end
    
    local isTank = tankCheck:GetChecked()
    local role = isTank and "tank" or "none"
    
    addonTable.Core:AddTestMember(name, selectedClass, selectedGroup, role, selectedSpec ~= "none" and selectedSpec or nil)
    nameInput:SetText("")
    nameInput:ClearFocus()
    TestPanel:UpdateRosterList()
end)

-- Sección 2: Lista Scroll de Miembros actuales
local listFrame = CreateFrame("Frame", nil, TestPanel, "BackdropTemplate")
listFrame:SetSize(250, 195)
listFrame:SetPoint("TOPLEFT", 15, -283)
listFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
listFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
listFrame:SetBackdropBorderColor(0.14, 0.14, 0.14, 1)

local scrollFrame = CreateFrame("ScrollFrame", "RaidBuffetTestRosterScroll", listFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 6, -6)
scrollFrame:SetPoint("BOTTOMRIGHT", -24, 6)

local scrollChild = CreateFrame("Frame")
scrollChild:SetSize(220, 180)
scrollFrame:SetScrollChild(scrollChild)

TestPanel.rows = {}

function TestPanel:UpdateRosterList()
    if not addonTable.TestRoster then return end
    
    -- Limpiar filas anteriores
    for _, row in ipairs(TestPanel.rows) do
        row:Hide()
    end
    TestPanel.rows = {}
    
    local yOffset = -5
    for idx, data in ipairs(addonTable.TestRoster) do
        local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        row:SetSize(210, 22)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, yOffset)
        row:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        })
        if idx % 2 == 1 then
            row:SetBackdropColor(0.12, 0.12, 0.12, 0.4)
        else
            row:SetBackdropColor(0.06, 0.06, 0.06, 0)
        end
        
        -- Icono Clase
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", 4, 0)
        icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        local coords = CLASS_ICON_TCOORDS[data.class]
        if coords then
            icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        end
        
        -- Nombre
        local nameStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameStr:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        nameStr:SetWidth(100)
        nameStr:SetJustifyH("LEFT")
        
        local colorCode = "ffffff"
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[data.class] then
            colorCode = RAID_CLASS_COLORS[data.class].colorStr
        end
        nameStr:SetText("|c" .. colorCode .. data.name .. "|r")
        
        -- Grupo e Info (Shield/Spec)
        local infoStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        infoStr:SetPoint("LEFT", nameStr, "RIGHT", 5, 0)
        infoStr:SetTextColor(0.6, 0.6, 0.6)
        
        local roleStr = "G" .. data.subgroup
        if data.role == "MAINTANK" then
            roleStr = roleStr .. " |cff00ffff[T]|r"
        end
        
        -- Añadir talento si existe en caché
        local talentsEntry = addonTable.TalentsCache[data.name]
        local talents = talentsEntry and talentsEntry.talents
        if talents then
            if talents.imprWisdom and talents.imprWisdom > 0 then roleStr = roleStr .. " (Wis)" end
            if talents.imprMight and talents.imprMight > 0 then roleStr = roleStr .. " (Mgt)" end
            if talents.imprSant and talents.imprSant > 0 then roleStr = roleStr .. " (Snt)" end
            if talents.imprMark and talents.imprMark > 0 then roleStr = roleStr .. " (Mrk)" end
            if talents.imprFort and talents.imprFort > 0 then roleStr = roleStr .. " (Frt)" end
            if talents.imprSpirit and talents.imprSpirit > 0 then roleStr = roleStr .. " (Spr)" end
        end
        infoStr:SetText(roleStr)
        
        -- Botón de Borrar (X rojo)
        local delBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
        delBtn:SetSize(12, 12)
        delBtn:SetPoint("RIGHT", -4, 0)
        delBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = true, tileSize = 16, edgeSize = 1,
        })
        delBtn:SetBackdropColor(0.25, 0.08, 0.08, 1)
        delBtn:SetBackdropBorderColor(0.5, 0.1, 0.1, 1)
        
        delBtn.text = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        delBtn.text:SetPoint("CENTER", 0, 0)
        delBtn.text:SetText("x")
        delBtn.text:SetTextColor(0.8, 0.2, 0.2)
        
        delBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.4, 0.1, 0.1, 1)
        end)
        delBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.25, 0.08, 0.08, 1)
        end)
        delBtn:SetScript("OnClick", function()
            -- El jugador local (posición 1) no se puede borrar de la simulación
            if idx == 1 then
                print("|cffff0000[RaidBuffet]|r No puedes borrarte a ti mismo de la simulación.")
                return
            end
            table.remove(addonTable.TestRoster, idx)
            addonTable.TalentsCache[data.name] = nil
            TestPanel:UpdateRosterList()
            if addonTable.UI and addonTable.UI.UpdateGrid then
                addonTable.UI:UpdateGrid()
            end
        end)
        
        row:Show()
        table.insert(TestPanel.rows, row)
        yOffset = yOffset - 22
    end
    scrollChild:SetHeight(math.abs(yOffset) + 10)
end

-- Sección 3: Botones de Acción inferior
local actionFrame = CreateFrame("Frame", nil, TestPanel)
actionFrame:SetSize(250, 24)
actionFrame:SetPoint("BOTTOMLEFT", 15, 10)

local function CreateActionBtn(labelText, xOffset, width, clickFunc)
    local btn = CreateFrame("Button", nil, actionFrame, "BackdropTemplate")
    btn:SetSize(width, 20)
    btn:SetPoint("LEFT", xOffset, 0)
    btn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    btn:SetBackdropColor(0.14, 0.14, 0.14, 1)
    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("CENTER", 0, 0)
    btn.text:SetText(labelText)
    btn.text:SetTextColor(0.85, 0.75, 0.5)
    
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.14, 0.14, 0.14, 1)
    end)
    btn:SetScript("OnClick", clickFunc)
    return btn
end

CreateActionBtn("R10", 0, 48, function()
    addonTable.Core:StartTestMode(10)
    TestPanel:UpdateRosterList()
end)

CreateActionBtn("R25", 52, 48, function()
    addonTable.Core:StartTestMode(25)
    TestPanel:UpdateRosterList()
end)

CreateActionBtn("Vaciar", 104, 62, function()
    addonTable.Core:ClearTestRoster()
    TestPanel:UpdateRosterList()
end)

CreateActionBtn("Apagar Test", 170, 80, function()
    addonTable.Core:StopTestMode()
    TestPanel:Hide()
end)

-- Función pública para abrir el configurador
function TestPanel:ShowPanel()
    if not addonTable.TestModeActive then
        addonTable.Core:StartTestMode(10)
    end
    
    -- Anclar de forma dinámica a la izquierda del ReportPanel si está abierto, sino a la grilla
    self:ClearAllPoints()
    if RaidBuffetReportPanel and RaidBuffetReportPanel:IsShown() then
        self:SetPoint("TOPRIGHT", RaidBuffetReportPanel, "TOPLEFT", -2, 0)
    elseif RaidBuffetGridFrame then
        self:SetPoint("TOPRIGHT", RaidBuffetGridFrame, "TOPLEFT", -2, 0)
    else
        self:SetPoint("CENTER", 0, 0)
    end
    
    self:UpdateRosterList()
    self:Show()
end

addonTable.TestPanel = TestPanel
