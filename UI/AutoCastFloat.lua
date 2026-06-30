local addonName, addonTable = ...
local ClickCast = addonTable.ClickCast
local L = addonTable.L

-- Crear botón flotante seguro anclado a UIParent
local FloatBtn = ClickCast:CreateSecureButton(UIParent, "RaidBuffetFloatCastBtn", 40, nil, nil)
ClickCast.floatBtn = FloatBtn

FloatBtn:SetClampedToScreen(true)
FloatBtn:SetMovable(true)
FloatBtn:EnableMouse(true)
FloatBtn:RegisterForDrag("LeftButton")

-- Tooltip informativo
FloatBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("RaidBuffet - Auto-Cast", 1, 0.8, 0)
    GameTooltip:AddLine("Clic Izquierdo: Lanzar Buff Pendiente", 1, 1, 1)
    GameTooltip:AddLine("Shift + Arrastrar para mover el botón", 0.5, 0.5, 0.5)
    
    if addonTable.Scanner then
        local unit, spellName, playerName = addonTable.Scanner:GetNextBuffTarget()
        if unit and spellName then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Siguiente Buff: |cff00ff00" .. spellName .. "|r en |cff00ffff" .. playerName .. "|r", 1, 1, 1)
        end
    end
    GameTooltip:Show()
end)

FloatBtn:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Shift+Arrastrar para mover
FloatBtn:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() and not InCombatLockdown() then
        self:StartMoving()
    end
end)

FloatBtn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Guardar posición en savedvariables
    if RaidBuffetDB then
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        RaidBuffetDB.FloatPosition = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
    end
end)

-- Binds del botón seguro flotante
FloatBtn:SetScript("PreClick", function(self, button)
    if InCombatLockdown() then return end
    ClickCast:UpdateMasterButton()
end)

FloatBtn:SetScript("PostClick", function(self, button)
    if InCombatLockdown() then return end
    ClickCast:ClearMasterButton()
end)

-- Carga e inicialización de posición
local function InitFloatButton()
    if RaidBuffetDB and RaidBuffetDB.FloatPosition then
        local pos = RaidBuffetDB.FloatPosition
        FloatBtn:ClearAllPoints()
        FloatBtn:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    else
        FloatBtn:ClearAllPoints()
        FloatBtn:SetPoint("CENTER", UIParent, "CENTER", 150, -50)
    end
    
    ClickCast:UpdateFloatButtonVisibility()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitFloatButton()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ClickCast.pendingVisibilityUpdate then
            ClickCast:UpdateFloatButtonVisibility()
        end
    end
end)

-- Exportar método de actualización de visibilidad
addonTable.UpdateFloatButtonVisibility = function()
    ClickCast:UpdateFloatButtonVisibility()
end
