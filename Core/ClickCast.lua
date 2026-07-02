local addonName, addonTable = ...
local L = addonTable.L

local ClickCast = {}
addonTable.ClickCast = ClickCast

-- Declarar variables para la interfaz de atajos de teclado (Keybindings) de WoW
_G["BINDING_HEADER_RAIDBUFFET"] = "RaidBuffet"
_G["BINDING_NAME_CLICK RaidBuffetAutoCastBtn:LeftButton"] = "Lanzar Buff Pendiente (Auto-Cast)"

function ClickCast:CreateSecureButton(parent, name, size, spellID, targetUnit)
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    btn:SetSize(size, size)
    btn:RegisterForClicks("LeftButtonDown", "RightButtonDown", "AnyUp", "AnyDown")
    
    -- Establecer tipo seguro estático (idéntico al sistema robusto de PallyPower)
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("type1", "spell")
    
    -- Crear texturas visuales manualmente para no heredar de ActionButtonTemplate,
    -- evitando que sus scripts internos de barra de acción interfieran con los clics seguros.
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    
    local normalTexture = btn:CreateTexture(nil, "BACKGROUND")
    normalTexture:SetAllPoints()
    normalTexture:SetColorTexture(0.1, 0.1, 0.1, 0.5)
    
    if spellID then
        local spellName, icon = L:GetSpellInfo(spellID)
        btn.icon:SetTexture(icon)
        btn:SetAttribute("spell", spellName)
        btn:SetAttribute("spell1", spellName)
        if targetUnit then
            btn:SetAttribute("unit", targetUnit)
            btn:SetAttribute("unit1", targetUnit)
        end
    end
    
    -- Crear frame de brillo y animación de alerta roja intensa/molesta (Doble Capa Incandescente)
    btn.glowFrame = CreateFrame("Frame", nil, btn)
    btn.glowFrame:SetSize(size * 2.0, size * 2.0)
    btn.glowFrame:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.glowFrame:Hide()
    
    -- Capa Interna (Núcleo denso de color rojo puro)
    btn.glow = btn.glowFrame:CreateTexture(nil, "OVERLAY")
    btn.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    btn.glow:SetBlendMode("ADD")
    btn.glow:SetSize(size * 1.4, size * 1.4)
    btn.glow:SetPoint("CENTER", btn.glowFrame, "CENTER", 0, 0)
    btn.glow:SetVertexColor(1, 0, 0, 1)
    
    -- Capa Externa (Corona expansiva de color rojo brillante)
    btn.glowOuter = btn.glowFrame:CreateTexture(nil, "OVERLAY")
    btn.glowOuter:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    btn.glowOuter:SetBlendMode("ADD")
    btn.glowOuter:SetSize(size * 1.9, size * 1.9)
    btn.glowOuter:SetPoint("CENTER", btn.glowFrame, "CENTER", 0, 0)
    btn.glowOuter:SetVertexColor(1, 0.2, 0.2, 0.9)
    
    btn.glowAnimGroup = btn.glowFrame:CreateAnimationGroup()
    local anim = btn.glowAnimGroup:CreateAnimation("Alpha")
    anim:SetFromAlpha(1.0)
    anim:SetToAlpha(0.0)
    anim:SetDuration(0.15) -- Parpadeo veloz tipo estrobo (0.15 segundos)
    btn.glowAnimGroup:SetLooping("BOUNCE")
    
    return btn
end

function ClickCast:SetMasterButton(uiBtn, textWidget)
    self.uiBtn = uiBtn
    self.masterText = textWidget
    
    -- Botón de macro siempre "visible" (renderizado en el centro de la pantalla) para que /click funcione con la UI cerrada
    if not self.macroBtn then
        self.macroBtn = CreateFrame("Button", "RaidBuffetAutoCastBtn", UIParent, "SecureActionButtonTemplate")
        self.macroBtn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        self.macroBtn:SetSize(1, 1)
        self.macroBtn:SetAlpha(0) -- Totalmente invisible para no interferir en la pantalla
        self.macroBtn:RegisterForClicks("LeftButtonDown", "RightButtonDown", "AnyUp", "AnyDown")
        
        -- Establecer tipo seguro estático (idéntico al sistema robusto de PallyPower)
        self.macroBtn:SetAttribute("type", "spell")
        self.macroBtn:SetAttribute("type1", "spell")
        self.macroBtn:Show()
    end
    
    -- Configurar scripts de PreClick y PostClick en el botón de macro (idéntico al sistema de PallyPower)
    self.macroBtn:SetScript("PreClick", function(self, button)
        if InCombatLockdown() then return end
        ClickCast:UpdateMasterButton()
    end)
    self.macroBtn:SetScript("PostClick", function(self, button)
        if InCombatLockdown() then return end
        ClickCast:ClearMasterButton()
    end)
    
    -- Configurar scripts de PreClick y PostClick en el botón visual de la UI
    if not self.uiBtn.scriptsSet then
        self.uiBtn:RegisterForClicks("LeftButtonDown", "RightButtonDown", "AnyUp", "AnyDown")
        self.uiBtn:SetScript("PreClick", function(self, button)
            if InCombatLockdown() then return end
            ClickCast:UpdateMasterButton()
        end)
        self.uiBtn:SetScript("PostClick", function(self, button)
            if InCombatLockdown() then return end
            ClickCast:ClearMasterButton()
        end)
        self.uiBtn.scriptsSet = true
    end
    
    -- Timer OnUpdate puramente VISUAL para la UI (no toca atributos seguros, seguro en combate)
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event)
        ClickCast.inCombat = (event == "PLAYER_REGEN_DISABLED")
    end)
    
    local timer = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        timer = timer + elapsed
        if timer > 0.5 then
            timer = 0
            ClickCast:UpdateVisualState()
        end
    end)
    
    ClickCast:UpdateVisualState()
end

function ClickCast:UpdateMasterButton()
    if not self.uiBtn or not addonTable.Scanner or InCombatLockdown() then return end
    
    local unit, spellName, playerName = addonTable.Scanner:GetNextBuffTarget()
    
    if unit and spellName and playerName then
        -- Asignar atributos seguros justo a tiempo antes del procesamiento del clic
        self.uiBtn:SetAttribute("spell", spellName)
        self.uiBtn:SetAttribute("spell1", spellName)
        self.uiBtn:SetAttribute("unit", unit)
        self.uiBtn:SetAttribute("unit1", unit)
        
        self.macroBtn:SetAttribute("spell", spellName)
        self.macroBtn:SetAttribute("spell1", spellName)
        self.macroBtn:SetAttribute("unit", unit)
        self.macroBtn:SetAttribute("unit1", unit)
        
        if self.floatBtn then
            self.floatBtn:SetAttribute("spell", spellName)
            self.floatBtn:SetAttribute("spell1", spellName)
            self.floatBtn:SetAttribute("unit", unit)
            self.floatBtn:SetAttribute("unit1", unit)
        end
    end
end

function ClickCast:ClearMasterButton()
    if not self.uiBtn or InCombatLockdown() then return end
    
    -- Limpiar atributos seguros de lanzamiento después del procesamiento del clic
    self.uiBtn:SetAttribute("spell", nil)
    self.uiBtn:SetAttribute("spell1", nil)
    self.uiBtn:SetAttribute("unit", nil)
    self.uiBtn:SetAttribute("unit1", nil)
    
    self.macroBtn:SetAttribute("spell", nil)
    self.macroBtn:SetAttribute("spell1", nil)
    self.macroBtn:SetAttribute("unit", nil)
    self.macroBtn:SetAttribute("unit1", nil)
    
    if self.floatBtn then
        self.floatBtn:SetAttribute("spell", nil)
        self.floatBtn:SetAttribute("spell1", nil)
        self.floatBtn:SetAttribute("unit", nil)
        self.floatBtn:SetAttribute("unit1", nil)
    end
end

function ClickCast:UpdateVisualState()
    if not self.uiBtn or not addonTable.Scanner then return end
    
    local unit, spellName, playerName = addonTable.Scanner:GetNextBuffTarget()
    
    if unit and spellName then
        local icon = select(3, GetSpellInfo(spellName))
        local tex = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        
        self.uiBtn.icon:SetTexture(tex)
        self.uiBtn.icon:SetDesaturated(false)
        self.uiBtn:SetAlpha(1)
        if self.uiBtn.glowFrame then
            self.uiBtn.glowFrame:Show()
            self.uiBtn.glowAnimGroup:Play()
        end
        
        if self.floatBtn then
            self.floatBtn.icon:SetTexture(tex)
            self.floatBtn.icon:SetDesaturated(false)
            self.floatBtn:SetAlpha(1)
            if self.floatBtn.glowFrame then
                self.floatBtn.glowFrame:Show()
                self.floatBtn.glowAnimGroup:Play()
            end
            
            if RaidBuffetDB and RaidBuffetDB.EnableFloatBtn then
                self.floatBtn:Show()
            end
        end
        
        if self.masterText then
            self.masterText:SetText("Falta Buff:\n|cff00ff00" .. playerName .. "|r")
        end
    else
        local tex = "Interface\\Icons\\Spell_Holy_AshesToAshes"
        self.uiBtn.icon:SetTexture(tex)
        self.uiBtn.icon:SetDesaturated(true)
        self.uiBtn:SetAlpha(0.6)
        if self.uiBtn.glowFrame then
            self.uiBtn.glowFrame:Hide()
            self.uiBtn.glowAnimGroup:Stop()
        end
        
        if self.floatBtn then
            self.floatBtn.icon:SetTexture(tex)
            self.floatBtn.icon:SetDesaturated(true)
            self.floatBtn:SetAlpha(0.6)
            if self.floatBtn.glowFrame then
                self.floatBtn.glowFrame:Hide()
                self.floatBtn.glowAnimGroup:Stop()
            end
            
            if RaidBuffetDB and RaidBuffetDB.EnableFloatBtn then
                if RaidBuffetDB.FloatVisibilityMode == "MISSING" then
                    -- Evitar Hide en combate para no provocar errores de Blizzard
                    if not InCombatLockdown() then
                        self.floatBtn:Hide()
                    end
                else
                    self.floatBtn:Show()
                end
            end
        end
        
        if self.masterText then
            self.masterText:SetText("|cff888888Todos\nBuffeados|r")
        end
    end
end

function ClickCast:UpdateFloatButtonVisibility()
    if not self.floatBtn then return end
    
    if InCombatLockdown() then
        self.pendingVisibilityUpdate = true
        return
    end
    
    self.pendingVisibilityUpdate = false
    
    if not RaidBuffetDB or not RaidBuffetDB.EnableFloatBtn then
        self.floatBtn:Hide()
        return
    end
    
    local unit, spellName = addonTable.Scanner:GetNextBuffTarget()
    if RaidBuffetDB.FloatVisibilityMode == "MISSING" and not unit then
        self.floatBtn:Hide()
    else
        self.floatBtn:Show()
    end
end
