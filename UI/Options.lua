local addonName, addonTable = ...
local L = addonTable.L
local Constants = addonTable.Constants

-- ============================================================================
-- PANEL DE OPCIONES DE INTERFAZ NATIVO (BLIZZARD OPTIONS)
-- ============================================================================
local OptionsPanel = CreateFrame("Frame", "RaidBuffetOptionsPanel", UIParent)
OptionsPanel.name = "RaidBuffet"

local title = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(L["OPTIONS_TITLE"] or "Opciones de RaidBuffet")

local desc = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
desc:SetText("Ajusta la configuración global y personal de las alertas de componentes.")

-- ============================================================================
-- SLIDER: Umbral de Componentes (Reagents)
-- ============================================================================
local reagentSlider = CreateFrame("Slider", "RaidBuffetReagentSlider", OptionsPanel, "OptionsSliderTemplate")
reagentSlider:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -40)
reagentSlider:SetMinMaxValues(1, 100)
reagentSlider:SetValueStep(1)
reagentSlider:SetObeyStepOnDrag(true)

_G[reagentSlider:GetName() .. "Low"]:SetText("1")
_G[reagentSlider:GetName() .. "High"]:SetText("100")
local sliderText = _G[reagentSlider:GetName() .. "Text"]
sliderText:SetText("Alerta de Componentes (Reagents)")

local sliderValueText = reagentSlider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sliderValueText:SetPoint("TOP", reagentSlider, "BOTTOM", 0, -5)

reagentSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value + 0.5)
    sliderValueText:SetText("Avisar cuando tenga menos de: " .. rounded)
    if RaidBuffetDB then
        RaidBuffetDB.ReagentThreshold = rounded
    end
end)

-- Checkboxes de opciones de Componentes y HUD
local announceReagentsCheck = CreateFrame("CheckButton", "RaidBuffetAnnounceReagentsCheck", OptionsPanel, "UICheckButtonTemplate")
announceReagentsCheck:SetPoint("TOPLEFT", reagentSlider, "BOTTOMLEFT", 0, -25)
_G[announceReagentsCheck:GetName() .. "Text"]:SetText("Anunciar reactivos bajos en grupo/banda")
announceReagentsCheck:SetScript("OnClick", function(self)
    if RaidBuffetDB then
        RaidBuffetDB.AnnounceLowReagents = self:GetChecked()
    end
end)

local alertCapitalCheck = CreateFrame("CheckButton", "RaidBuffetAlertCapitalCheck", OptionsPanel, "UICheckButtonTemplate")
alertCapitalCheck:SetPoint("TOPLEFT", announceReagentsCheck, "BOTTOMLEFT", 0, -5)
_G[alertCapitalCheck:GetName() .. "Text"]:SetText("Alertar en Ciudades Capitales / descanso")
alertCapitalCheck:SetScript("OnClick", function(self)
    if RaidBuffetDB then
        RaidBuffetDB.AlertInCapital = self:GetChecked()
    end
end)

local showHUDCheck = CreateFrame("CheckButton", "RaidBuffetShowHUDCheck", OptionsPanel, "UICheckButtonTemplate")
showHUDCheck:SetPoint("TOPLEFT", alertCapitalCheck, "BOTTOMLEFT", 0, -5)
_G[showHUDCheck:GetName() .. "Text"]:SetText("Mostrar HUD flotante de buffs")
showHUDCheck:SetScript("OnClick", function(self)
    if RaidBuffetDB then
        RaidBuffetDB.ShowFloatHUD = self:GetChecked()
        if addonTable.UpdateFloatButtonVisibility then
            addonTable.UpdateFloatButtonVisibility()
        end
    end
end)

-- Slider para el intervalo de alerta local de reactivos (en minutos)
local warnIntervalSlider = CreateFrame("Slider", "RaidBuffetWarnIntervalSlider", OptionsPanel, "OptionsSliderTemplate")
warnIntervalSlider:SetPoint("TOPLEFT", showHUDCheck, "BOTTOMLEFT", 0, -35)
warnIntervalSlider:SetMinMaxValues(1, 30) -- De 1 a 30 minutos
warnIntervalSlider:SetValueStep(1)
warnIntervalSlider:SetObeyStepOnDrag(true)
_G[warnIntervalSlider:GetName() .. "Low"]:SetText("1 min")
_G[warnIntervalSlider:GetName() .. "High"]:SetText("30 min")

local warnIntervalSliderText = _G[warnIntervalSlider:GetName() .. "Text"]
warnIntervalSliderText:SetText("Frecuencia de Alerta de Reactivos")

local warnIntervalValueText = warnIntervalSlider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
warnIntervalValueText:SetPoint("TOP", warnIntervalSlider, "BOTTOM", 0, -5)

warnIntervalSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value + 0.5)
    warnIntervalValueText:SetText("Repetir cada: " .. rounded .. " min")
    if RaidBuffetDB then
        RaidBuffetDB.ReagentWarnInterval = rounded * 60
    end
end)

-- ============================================================================
-- RADIO BUTTONS: Selector de Idioma (Evitamos UIDropDownMenu por compatibilidad)
-- ============================================================================
local langLabel = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
langLabel:SetPoint("TOPLEFT", warnIntervalSlider, "BOTTOMLEFT", 0, -30)
langLabel:SetText("Forzar Idioma de la Interfaz (Requiere /reload):")

local function CreateRadio(name, labelText, langCode)
    local btn = CreateFrame("CheckButton", name, OptionsPanel, "UIRadioButtonTemplate")
    btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    btn.text:SetPoint("LEFT", btn, "RIGHT", 5, 0)
    btn.text:SetText(labelText)
    btn.langCode = langCode
    return btn
end

local rbAuto = CreateRadio("RaidBuffetLangAuto", "Automático (Cliente)", "AUTO")
rbAuto:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 0, -10)

local rbES = CreateRadio("RaidBuffetLangES", "Español", "esES")
rbES:SetPoint("LEFT", rbAuto.text, "RIGHT", 20, 0)

local rbEN = CreateRadio("RaidBuffetLangEN", "English", "enUS")
rbEN:SetPoint("LEFT", rbES.text, "RIGHT", 20, 0)

local radios = {rbAuto, rbES, rbEN}

local function UpdateRadios()
    local currentLang = RaidBuffetDB and RaidBuffetDB.ForceLang or "AUTO"
    for _, rb in ipairs(radios) do
        rb:SetChecked(rb.langCode == currentLang)
    end
end

for _, rb in ipairs(radios) do
    rb:SetScript("OnClick", function(self)
        if RaidBuffetDB then
            RaidBuffetDB.ForceLang = self.langCode
        end
        UpdateRadios()
    end)
end

-- ============================================================================
-- RADIO BUTTONS: Canal de Anuncios
-- ============================================================================
local announceLabel = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
announceLabel:SetPoint("TOPLEFT", rbAuto, "BOTTOMLEFT", 0, -40)
announceLabel:SetText("Canal para Anunciar Buffs / Faltantes:")

local function CreateAnnounceRadio(name, labelText, channelCode)
    local btn = CreateFrame("CheckButton", name, OptionsPanel, "UIRadioButtonTemplate")
    btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    btn.text:SetPoint("LEFT", btn, "RIGHT", 5, 0)
    btn.text:SetText(labelText)
    btn.channelCode = channelCode
    return btn
end

local announceRadios = {}
for i, chData in ipairs(Constants.AnnounceChannels) do
    local btn = CreateAnnounceRadio("RaidBuffetAnnounceRadio" .. chData.code, chData.name, chData.code)
    if i == 1 then
        btn:SetPoint("TOPLEFT", announceLabel, "BOTTOMLEFT", 0, -10)
    elseif i == 3 then
        btn:SetPoint("TOPLEFT", announceRadios[1], "BOTTOMLEFT", 0, -15)
    else
        btn:SetPoint("LEFT", announceRadios[i-1].text, "RIGHT", 20, 0)
    end
    table.insert(announceRadios, btn)
end

local function UpdateAnnounceRadios()
    local currentChannel = RaidBuffetDB and RaidBuffetDB.AnnounceChannel or "RAID"
    for _, rb in ipairs(announceRadios) do
        rb:SetChecked(rb.channelCode == currentChannel)
    end
end

for _, rb in ipairs(announceRadios) do
    rb:SetScript("OnClick", function(self)
        if RaidBuffetDB then
            RaidBuffetDB.AnnounceChannel = self.channelCode
        end
        UpdateAnnounceRadios()
    end)
end

-- ============================================================================
-- OPCIONES: Botón de Auto-Cast Flotante
-- ============================================================================
local floatLabel = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
floatLabel:SetPoint("TOPLEFT", announceRadios[3], "BOTTOMLEFT", 0, -40)
floatLabel:SetText("Botón de Auto-Cast Flotante:")

local floatCheck = CreateFrame("CheckButton", "RaidBuffetEnableFloatBtnCheck", OptionsPanel, "UICheckButtonTemplate")
floatCheck:SetPoint("TOPLEFT", floatLabel, "BOTTOMLEFT", 0, -10)
_G[floatCheck:GetName() .. "Text"]:SetText("Habilitar botón flotante independiente (Shift+Arrastrar para mover)")

local function CreateFloatRadio(name, labelText, mode)
    local btn = CreateFrame("CheckButton", name, OptionsPanel, "UIRadioButtonTemplate")
    btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    btn.text:SetPoint("LEFT", btn, "RIGHT", 5, 0)
    btn.text:SetText(labelText)
    btn.mode = mode
    return btn
end

local floatRadioAlways = CreateFloatRadio("RaidBuffetFloatAlwaysRadio", "Siempre visible", "ALWAYS")
floatRadioAlways:SetPoint("TOPLEFT", floatCheck, "BOTTOMLEFT", 15, -10)

local floatRadioMissing = CreateFloatRadio("RaidBuffetFloatMissingRadio", "Solo cuando falten buffs", "MISSING")
floatRadioMissing:SetPoint("LEFT", floatRadioAlways.text, "RIGHT", 20, 0)

local floatRadios = { floatRadioAlways, floatRadioMissing }

local function UpdateFloatOptions()
    if RaidBuffetDB then
        floatCheck:SetChecked(RaidBuffetDB.EnableFloatBtn)
        local currentMode = RaidBuffetDB.FloatVisibilityMode or "ALWAYS"
        for _, rb in ipairs(floatRadios) do
            rb:SetChecked(rb.mode == currentMode)
        end
        -- Habilitar/Deshabilitar según el checkbox master
        for _, rb in ipairs(floatRadios) do
            if RaidBuffetDB.EnableFloatBtn then
                rb:Enable()
                rb.text:SetTextColor(1, 1, 1)
            else
                rb:Disable()
                rb.text:SetTextColor(0.5, 0.5, 0.5)
            end
        end
    end
end

floatCheck:SetScript("OnClick", function(self)
    if RaidBuffetDB then
        RaidBuffetDB.EnableFloatBtn = self:GetChecked()
        if addonTable.UpdateFloatButtonVisibility then
            addonTable.UpdateFloatButtonVisibility()
        end
    end
    UpdateFloatOptions()
end)

for _, rb in ipairs(floatRadios) do
    rb:SetScript("OnClick", function(self)
        if RaidBuffetDB then
            RaidBuffetDB.FloatVisibilityMode = self.mode
            if addonTable.UpdateFloatButtonVisibility then
                addonTable.UpdateFloatButtonVisibility()
            end
        end
        UpdateFloatOptions()
    end)
end

-- ============================================================================
-- COLUMNA DERECHA: Selección Dinámica de Reactivos a Rastrear
-- ============================================================================
local reagentsSectionTitle = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
reagentsSectionTitle:SetPoint("TOPLEFT", OptionsPanel, "TOPLEFT", 420, -100)
reagentsSectionTitle:SetText("Componentes a Rastrear:")

local reagentChecks = {}
local _, playerClass = UnitClass("player")
local classReagents = {}

local mainReagent = addonTable.Constants.Reagents[playerClass]
if mainReagent then
    table.insert(classReagents, mainReagent)
end
local extraReagents = addonTable.Constants.ExtraReagents and addonTable.Constants.ExtraReagents[playerClass]
if extraReagents then
    for _, id in ipairs(extraReagents) do
        table.insert(classReagents, id)
    end
end

if #classReagents == 0 then
    reagentsSectionTitle:SetText("Componentes a Rastrear:\n\n|cffaaaaaaTu clase no consume reactivos\npara lanzar bendiciones o buffs\nmasivos de grupo/banda.|r")
end

for i, id in ipairs(classReagents) do
    local cb = CreateFrame("CheckButton", "RaidBuffetReagentTrackCheck" .. id, OptionsPanel, "UICheckButtonTemplate")
    if i == 1 then
        cb:SetPoint("TOPLEFT", reagentsSectionTitle, "BOTTOMLEFT", 0, -10)
    else
        cb:SetPoint("TOPLEFT", reagentChecks[i - 1], "BOTTOMLEFT", 0, -5)
    end
    
    cb.reagentID = id
    
    -- Cargar nombre (usando GetReagentName exportado)
    local name = addonTable.GetReagentName(id)
    local desc = name
    if cb.reagentID == 22148 then
        desc = "Videpluma salvaje (Don de lo salvaje R3)"
    elseif cb.reagentID == 17026 then
        desc = "Raíz de espina salvaje (Don de lo salvaje R2)"
    elseif cb.reagentID == 22147 then
        desc = "Semilla de silexia (Renacer R6)"
    elseif cb.reagentID == 17038 then
        desc = "Semilla de pino hierro (Renacer R5)"
    elseif cb.reagentID == 21177 then
        desc = "Símbolo de reyes (Bendiciones)"
    elseif cb.reagentID == 17029 then
        desc = "Vela sagrada (Rezos R2/Max)"
    elseif cb.reagentID == 17028 then
        desc = "Vela sagrada ligera (Rezos R1)"
    elseif cb.reagentID == 17020 then
        desc = "Polvo arcano (Luminosidad)"
    elseif cb.reagentID == 17031 then
        desc = "Runa de teletransportación (Teleports)"
    elseif cb.reagentID == 17032 then
        desc = "Runa de portales (Portales)"
    end
    _G[cb:GetName() .. "Text"]:SetText(desc)
    
    cb:SetScript("OnClick", function(self)
        if RaidBuffetDB and RaidBuffetDB.TrackedReagents then
            RaidBuffetDB.TrackedReagents[self.reagentID] = self:GetChecked()
            addonTable.Core:CheckReagents() -- Ejecutar comprobación al instante al alternar
        end
    end)
    table.insert(reagentChecks, cb)
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
OptionsPanel:SetScript("OnShow", function(self)
    if RaidBuffetDB then
        reagentSlider:SetValue(RaidBuffetDB.ReagentThreshold or 20)
        announceReagentsCheck:SetChecked(RaidBuffetDB.AnnounceLowReagents or false)
        alertCapitalCheck:SetChecked(RaidBuffetDB.AlertInCapital or false)
        showHUDCheck:SetChecked(RaidBuffetDB.ShowFloatHUD ~= false)
        warnIntervalSlider:SetValue((RaidBuffetDB.ReagentWarnInterval or 300) / 60)
        
        -- Inicializar checkboxes de reactivos
        if reagentChecks then
            for _, cb in ipairs(reagentChecks) do
                cb:SetChecked(RaidBuffetDB.TrackedReagents[cb.reagentID] ~= false)
            end
        end
    end
    UpdateRadios()
    UpdateAnnounceRadios()
    UpdateFloatOptions()
end)

-- Registrar el panel
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category, layout = Settings.RegisterCanvasLayoutCategory(OptionsPanel, OptionsPanel.name)
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(OptionsPanel)
end
