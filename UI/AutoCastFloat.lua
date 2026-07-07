local addonName, addonTable = ...
local ClickCast = addonTable.ClickCast
local L = addonTable.L
local Constants = addonTable.Constants

-- Crear botón flotante seguro anclado a UIParent
local FloatBtn = ClickCast:CreateSecureButton(UIParent, "RaidBuffetFloatCastBtn", 40, nil, nil)
ClickCast.floatBtn = FloatBtn

FloatBtn:SetClampedToScreen(true)
FloatBtn:SetMovable(true)
FloatBtn:EnableMouse(true)
FloatBtn:RegisterForDrag("LeftButton")
FloatBtn:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")

-- Crear panel contenedor translúcido y acoplado para el HUD de faltantes
local hudPanel = CreateFrame("Frame", "RaidBuffetFloatHUD", FloatBtn, "BackdropTemplate")
hudPanel:SetSize(166, 22)
hudPanel:SetPoint("TOP", FloatBtn, "BOTTOM", 0, -4)
hudPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
hudPanel:SetBackdropColor(0.06, 0.06, 0.06, 0.94)
hudPanel:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
FloatBtn.hudPanel = hudPanel

-- Generar los 9 micro-botones de clase/grupo seguros en el HUD
hudPanel.buttons = {}
for i = 1, 9 do
    local btn = CreateFrame("Button", "RaidBuffetHUDButton" .. i, hudPanel, "SecureActionButtonTemplate, BackdropTemplate")
    btn:SetSize(14, 14)
    btn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    btn:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
    btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
    btn.text:SetPoint("CENTER", 0, 0)
    btn.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    
    btn:SetPoint("LEFT", hudPanel, "LEFT", 4 + (i-1)*18, 0)
    btn:SetAttribute("type", "target")
    hudPanel.buttons[i] = btn
end

-- Función para actualizar la visibilidad del HUD
local function UpdateHUDVisibility()
    if not RaidBuffetDB or not RaidBuffetDB.EnableFloatBtn or RaidBuffetDB.ShowFloatHUD == false or FloatBtn.hudCollapsed or not FloatBtn:IsShown() then
        hudPanel:Hide()
    else
        hudPanel:Show()
    end
end

-- Actualiza dinámicamente el estado de los micro-iconos del HUD flotante
local function UpdateHUDButtons()
    if not addonTable.Scanner or not RaidBuffetDB or not FloatBtn:IsShown() then return end
    
    local _, myClass = UnitClass("player")
    local targetType = Constants.TargetTypes[myClass]
    local maxCols = (targetType == "CLASS") and 9 or 8
    
    -- Redimensionar el panel del HUD dinámicamente según las columnas
    hudPanel:SetWidth(8 + (maxCols * 18) - 4)
    
    local missing = addonTable.Scanner:GetMissingBuffsReport()
    local myName = UnitName("player")
    local assignments = addonTable.Assignments[myClass] and addonTable.Assignments[myClass][myName]
    
    for i = 1, 9 do
        local btn = hudPanel.buttons[i]
        if i <= maxCols then
            local targetID = (targetType == "CLASS") and Constants.ClassOrder[i] or ("GROUP_" .. i)
            
            -- Verificar si el jugador local tiene asignado algo en esta columna
            local hasAssignment = false
            if assignments then
                if assignments[targetID] and assignments[targetID] ~= "CLEAR" and assignments[targetID] ~= 0 then
                    hasAssignment = true
                else
                    -- También verificar si hay bendición pequeña individual asignada en esa clase
                    if targetType == "CLASS" then
                        for targetName, spellID in pairs(assignments) do
                            if spellID and spellID ~= "CLEAR" and spellID ~= 0 then
                                -- Si el objetivo individual pertenece a esa clase
                                if IsInRaid() then
                                    for rIdx = 1, GetNumGroupMembers() do
                                        local name, _, _, _, _, classFileName = GetRaidRosterInfo(rIdx)
                                        if name and string.match(name, "([^%-]+)") == targetName and classFileName == targetID then
                                            hasAssignment = true
                                            break
                                        end
                                    end
                                elseif IsInGroup() then
                                    for pIdx = 1, GetNumSubgroupMembers() do
                                        local unit = "party" .. pIdx
                                        local name = UnitName(unit)
                                        local _, classFileName = UnitClass(unit)
                                        if name and string.match(name, "([^%-]+)") == targetName and classFileName == targetID then
                                            hasAssignment = true
                                            break
                                        end
                                    end
                                end
                            end
                            if hasAssignment then break end
                        end
                    end
                end
            end
            
            if not hasAssignment then
                btn:Hide()
            else
                btn:Show()
                
                -- Configurar Textura/Texto
                if targetType == "CLASS" then
                    btn.icon:SetTexture("Interface\\Glue\\CharacterCreate\\UI-CharacterCreate-Classes")
                    local coords = CLASS_ICON_TCOORDS[targetID]
                    if coords then
                        btn.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                    end
                    btn.text:SetText("")
                else
                    btn.icon:SetTexture(nil)
                    btn.text:SetText(tostring(i))
                    btn.text:SetTextColor(1, 0.82, 0)
                end
                
                -- Comprobar si faltan buffs asignados por ti en esta columna
                local isMissing = false
                local targetUnitName = nil
                
                for _, data in ipairs(missing) do
                    if data.casterName == myName and data.targetID == targetID then
                        isMissing = true
                        targetUnitName = data.missingPlayers[1] -- Primer jugador faltante
                        break
                    end
                end
                
                -- Cambiar estado visual y asociar macro de targeteo seguro (fuera de combate)
                if isMissing then
                    btn:SetAlpha(1.0)
                    btn:SetBackdropColor(0.3, 0.05, 0.05, 0.9)
                    btn:SetBackdropBorderColor(1.0, 0.1, 0.1, 1)
                    
                    -- Actualizar target seguro si no estamos en combate
                    if not InCombatLockdown() and targetUnitName then
                        -- Limpiar nombre para la API de target
                        local cleanTarget = string.match(targetUnitName, "([^%s]+)")
                        btn:SetAttribute("unit", cleanTarget)
                    end
                    
                    btn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_TOP")
                        GameTooltip:ClearLines()
                        local titleDesc = (targetType == "CLASS") and L:GetClassName(targetID) or ("Grupo " .. i)
                        GameTooltip:AddLine(titleDesc, 1, 0.82, 0)
                        GameTooltip:AddLine("|cffff0000Faltan buffs en esta columna.|r", 1, 0.9, 0.9)
                        GameTooltip:AddLine("|cff00ffffClic:|r Targetear a |cffddffdd" .. targetUnitName .. "|r", 0.5, 0.8, 1)
                        GameTooltip:Show()
                    end)
                else
                    btn:SetAlpha(0.35)
                    btn:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
                    btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                    
                    if not InCombatLockdown() then
                        btn:SetAttribute("unit", nil)
                    end
                    
                    btn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_TOP")
                        GameTooltip:ClearLines()
                        local titleDesc = (targetType == "CLASS") and L:GetClassName(targetID) or ("Grupo " .. i)
                        GameTooltip:AddLine(titleDesc, 1, 0.82, 0)
                        GameTooltip:AddLine("Todos los buffs al día en esta columna.", 0.2, 1, 0.2)
                        GameTooltip:Show()
                    end)
                end
                
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        else
            btn:Hide()
        end
    end
end

-- Tooltip informativo
FloatBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("RaidBuffet - Auto-Cast", 1, 0.8, 0)
    GameTooltip:AddLine("Clic Izquierdo: Lanzar Buff Pendiente", 1, 1, 1)
    GameTooltip:AddLine("Clic Derecho: Colapsar/Expandir HUD", 1, 1, 1)
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
    if button == "RightButton" then
        self.hudCollapsed = not self.hudCollapsed
        UpdateHUDVisibility()
    elseif not InCombatLockdown() then
        ClickCast:UpdateMasterButton()
    end
end)

FloatBtn:SetScript("PostClick", function(self, button)
    if button == "RightButton" then return end
    if InCombatLockdown() then return end
    ClickCast:ClearMasterButton()
end)

-- Hookear UpdateFloatButtonVisibility para refrescar también nuestro HUD
local origUpdateVisibility = ClickCast.UpdateFloatButtonVisibility
ClickCast.UpdateFloatButtonVisibility = function(self)
    origUpdateVisibility(self)
    UpdateHUDVisibility()
    UpdateHUDButtons()
end

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
    
    FloatBtn.hudCollapsed = false
    ClickCast:UpdateFloatButtonVisibility()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Actualización periódica visual para el HUD flotante
local elapsedTimer = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    if not FloatBtn:IsShown() then return end
    elapsedTimer = elapsedTimer + elapsed
    if elapsedTimer > 0.5 then
        elapsedTimer = 0
        UpdateHUDButtons()
    end
end)

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
    UpdateHUDVisibility()
end
