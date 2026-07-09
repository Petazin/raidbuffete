local addonName, addonTable = ...

local minimapButton = CreateFrame("Button", "RaidBuffetMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)

-- Textura del hechizo (Ícono)
minimapButton.icon = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapButton.icon:SetTexture("Interface\\Icons\\spell_holy_greaterblessingofkings")
minimapButton.icon:SetSize(21, 21)
minimapButton.icon:SetPoint("TOPLEFT", 7, -6)

-- Borde nativo del Minimapa
minimapButton.border = minimapButton:CreateTexture(nil, "ARTWORK")
minimapButton.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapButton.border:SetSize(56, 56)
minimapButton.border:SetPoint("TOPLEFT", 0, 0)

minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

minimapButton:RegisterForClicks("AnyUp")
minimapButton:RegisterForDrag("LeftButton")

-- Función para actualizar la posición alrededor del minimapa
local function UpdateMinimapPos()
    local angle = RaidBuffetDB and RaidBuffetDB.MinimapPos or 45
    local rad = math.rad(angle)
    local x = math.cos(rad) * 80
    local y = math.sin(rad) * 80
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Funcionalidad de los Clics
minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if addonTable.UI:IsShown() then
            addonTable.UI:Hide()
        else
            addonTable.UI:Show()
        end
    elseif button == "RightButton" then
        -- Abrir Opciones de Blizzard
        if Settings and Settings.OpenToCategory and addonTable.settingsCategory then
            local categoryID = addonTable.settingsCategory.GetID and addonTable.settingsCategory:GetID() or addonTable.settingsCategory
            Settings.OpenToCategory(categoryID)
        else
            InterfaceOptionsFrame_OpenToCategory("RaidBuffet")
            InterfaceOptionsFrame_OpenToCategory("RaidBuffet") -- Llamar 2 veces para un viejo bug de TBC/Wrath
        end
    end
end)

-- Funcionalidad de Arrastre (Drag)
minimapButton:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        
        local angle = math.deg(math.atan2(py - my, px - mx))
        if RaidBuffetDB then RaidBuffetDB.MinimapPos = angle end
        UpdateMinimapPos()
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

-- Tooltip
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("RaidBuffet", 1, 0.8, 0)
    GameTooltip:AddLine("Clic Izquierdo: Abrir Grilla", 1, 1, 1)
    GameTooltip:AddLine("Clic Derecho: Abrir Opciones", 1, 1, 1)
    GameTooltip:AddLine("Arrastrar: Mover el ícono", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Inicialización de la posición al cargar
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    UpdateMinimapPos()
end)
