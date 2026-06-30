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

-- ============================================================================
-- RADIO BUTTONS: Selector de Idioma (Evitamos UIDropDownMenu por compatibilidad)
-- ============================================================================
local langLabel = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
langLabel:SetPoint("TOPLEFT", reagentSlider, "BOTTOMLEFT", 0, -40)
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
-- INICIALIZACIÓN
-- ============================================================================
OptionsPanel:SetScript("OnShow", function(self)
    if RaidBuffetDB then
        reagentSlider:SetValue(RaidBuffetDB.ReagentThreshold or 20)
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
