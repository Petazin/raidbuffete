local addonName, addonTable = ...
local L = addonTable.L
local Scanner = addonTable.Scanner
local Constants = addonTable.Constants

local ReportFrame = CreateFrame("Frame", "RaidBuffetReportFrame", UIParent, "BackdropTemplate")
ReportFrame:SetToplevel(true)
addonTable.UI.ReportFrame = ReportFrame

ReportFrame:SetSize(480, 360)
ReportFrame:SetPoint("CENTER", UIParent, "CENTER", 50, 0)
ReportFrame:SetMovable(true)
ReportFrame:EnableMouse(true)
ReportFrame:RegisterForDrag("LeftButton")
ReportFrame:SetScript("OnDragStart", ReportFrame.StartMoving)
ReportFrame:SetScript("OnDragStop", ReportFrame.StopMovingOrSizing)
ReportFrame:Hide()

ReportFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
ReportFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.94)
ReportFrame:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

ReportFrame.header = CreateFrame("Frame", nil, ReportFrame, "BackdropTemplate")
ReportFrame.header:SetSize(480, 24)
ReportFrame.header:SetPoint("TOPLEFT", ReportFrame, "TOPLEFT", 0, 0)
ReportFrame.header:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
ReportFrame.header:SetBackdropColor(0.12, 0.12, 0.12, 1)
ReportFrame.header:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

ReportFrame.header:EnableMouse(true)
ReportFrame.header:RegisterForDrag("LeftButton")
ReportFrame.header:SetScript("OnDragStart", function() ReportFrame:StartMoving() end)
ReportFrame.header:SetScript("OnDragStop", function() ReportFrame:StopMovingOrSizing() end)

ReportFrame.title = ReportFrame.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ReportFrame.title:SetPoint("LEFT", 10, 0)
ReportFrame.title:SetText("RaidBuffet - Reporte de Faltantes")
ReportFrame.title:SetTextColor(0.8, 0.6, 0.2)

ReportFrame.closeBtn = CreateFrame("Button", nil, ReportFrame.header, "BackdropTemplate")
ReportFrame.closeBtn:SetSize(16, 16)
ReportFrame.closeBtn:SetPoint("RIGHT", -6, 0)
ReportFrame.closeBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
ReportFrame.closeBtn:SetBackdropColor(0.2, 0.1, 0.1, 1)
ReportFrame.closeBtn:SetBackdropBorderColor(0.3, 0.15, 0.15, 1)
ReportFrame.closeBtn.text = ReportFrame.closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ReportFrame.closeBtn.text:SetPoint("CENTER", 0, 0)
ReportFrame.closeBtn.text:SetText("X")
ReportFrame.closeBtn.text:SetTextColor(0.8, 0.3, 0.3)
ReportFrame.closeBtn:SetScript("OnClick", function() ReportFrame:Hide() end)
ReportFrame.closeBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.4, 0.15, 0.15, 1)
end)
ReportFrame.closeBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.2, 0.1, 0.1, 1)
end)

-- ============================================================================
-- CONTENEDOR DE SCROLL PARA FILAS
-- ============================================================================
local ScrollFrame = CreateFrame("ScrollFrame", "RaidBuffetReportScrollFrame", ReportFrame, "UIPanelScrollFrameTemplate")
ScrollFrame:SetPoint("TOPLEFT", 10, -35)
ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)

if _G["RaidBuffetReportScrollFrameScrollBar"] then
    _G["RaidBuffetReportScrollFrameScrollBar"]:SetAlpha(0)
    _G["RaidBuffetReportScrollFrameScrollBarScrollUpButton"]:SetAlpha(0)
    _G["RaidBuffetReportScrollFrameScrollBarScrollDownButton"]:SetAlpha(0)
end

local ScrollChild = CreateFrame("Frame", "RaidBuffetReportScrollChild", ScrollFrame)
ScrollChild:SetSize(420, 1)
ScrollFrame:SetScrollChild(ScrollChild)

ReportFrame.rows = {}

-- Función segura para obtener color de clase
local function GetClassColorHex(classFileName)
    if C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classFileName)
        return string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFileName] then
        local color = RAID_CLASS_COLORS[classFileName]
        return string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    end
    return "ffffffff" -- Blanco por defecto
end

-- ============================================================================
-- DIBUJAR FILAS DEL REPORTE
-- ============================================================================
function ReportFrame:UpdateReport()
    local missing = Scanner:GetMissingBuffsReport()
    
    -- Ocultar todas las filas existentes
    for _, row in ipairs(ReportFrame.rows) do
        row:Hide()
    end
    
    local yOffset = 0
    local rowIndex = 1
    
    if #missing == 0 then
        if not ReportFrame.noMissingText then
            ReportFrame.noMissingText = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            ReportFrame.noMissingText:SetPoint("CENTER", ScrollFrame, "CENTER", 0, 0)
            ReportFrame.noMissingText:SetText("|cff00ff00¡Todos los jugadores de la banda están buffeados!|r")
        end
        ReportFrame.noMissingText:Show()
        yOffset = 30
    else
        if ReportFrame.noMissingText then
            ReportFrame.noMissingText:Hide()
        end
        for _, data in ipairs(missing) do
            local row = ReportFrame.rows[rowIndex]
            if not row then
                row = CreateFrame("Frame", nil, ScrollChild)
                row:SetSize(420, 30)
                
                -- Icono clase caster
                row.iconCaster = row:CreateTexture(nil, "ARTWORK")
                row.iconCaster:SetSize(20, 20)
                row.iconCaster:SetPoint("LEFT", 5, 0)
                
                -- Icono spell
                row.iconSpell = row:CreateTexture(nil, "ARTWORK")
                row.iconSpell:SetSize(20, 20)
                row.iconSpell:SetPoint("LEFT", row.iconCaster, "RIGHT", 8, 0)
                
                -- Texto informativo
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", row.iconSpell, "RIGHT", 8, 0)
                row.text:SetWidth(350)
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(true)
                
                ReportFrame.rows[rowIndex] = row
            end
            
            row:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, -yOffset)
            
            -- Setear iconos y texto
            local classCoords = CLASS_BUTTONS[data.casterClass]
            if classCoords then
                row.iconCaster:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                row.iconCaster:SetTexCoord(unpack(classCoords))
                row.iconCaster:Show()
            else
                row.iconCaster:Hide()
            end
            
            local _, icon = L:GetSpellInfo(data.spellID)
            row.iconSpell:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.iconSpell:Show()
            
            local casterHex = GetClassColorHex(data.casterClass)
            local targetName = data.targetID
            if string.find(targetName, "GROUP_") then
                targetName = "Grupo " .. string.match(targetName, "GROUP_(%d+)")
            else
                targetName = L:GetClassName(targetName)
            end
            
            local missingList = table.concat(data.missingPlayers, ", ")
            row.text:SetText(string.format("|c%s%s|r debe poner |cffffd100%s|r a %s\n|cff888888Faltan: %s|r", 
                casterHex, data.casterName, data.spellName, targetName, missingList))
            row.text:Show()
            
            row:Show()
            yOffset = yOffset + 35
            rowIndex = rowIndex + 1
        end
    end
    
    ScrollChild:SetHeight(yOffset)
end

-- ============================================================================
-- LÓGICA DE ENVÍO DE CHAT (ANUNCIOS SEGUROS)
-- ============================================================================
local function SendMessageToChannel(msg, channel)
    if channel == "LOCAL" then
        print(msg)
    else
        SendChatMessage(msg, channel)
    end
end

-- Envía un mensaje fragmentándolo si supera el límite de chat de WoW (240 caracteres)
-- y previniendo exploits de formato o caídas por límite de caracteres.
local function SendChatMessageSafe(fullMsg, channel)
    if string.len(fullMsg) <= 240 then
        SendMessageToChannel(fullMsg, channel)
    else
        -- Intentar dividir de forma inteligente por la coma
        local prefix = ""
        if string.find(fullMsg, "^%[RaidBuffet%]") then
            prefix = "[RaidBuffet] (Cont.) "
        end
        
        local currentMsg = ""
        for part in string.gmatch(fullMsg, "[^,]+") do
            part = string.gsub(part, "^%s+", "") -- Quitar espacios iniciales al trozo
            
            if currentMsg == "" then
                currentMsg = part
            else
                if string.len(currentMsg) + string.len(part) + 2 > 240 then
                    SendMessageToChannel(currentMsg, channel)
                    currentMsg = prefix .. part
                else
                    currentMsg = currentMsg .. ", " .. part
                end
            end
        end
        if currentMsg ~= "" then
            SendMessageToChannel(currentMsg, channel)
        end
    end
end

-- Envía el mensaje de chat respetando las restricciones de canal y combate
local function AnnounceToGroup(messages)
    if InCombatLockdown() then
        print("|cffff0000[RaidBuffet]|r No se pueden enviar anuncios en combate.")
        return
    end
    
    local channel = RaidBuffetDB and RaidBuffetDB.AnnounceChannel or "RAID"
    
    -- Validar canal de alerta de banda (/rw)
    if channel == "RAID_WARNING" then
        if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            channel = "RAID" -- Redirigir a banda si no tiene privilegios de /rw
        end
    end
    
    -- Redirigir a LOCAL si no estamos realmente en grupo/banda
    if channel ~= "LOCAL" and not IsInGroup() then
        channel = "LOCAL"
    end
    
    -- Enviar cada línea con un pequeño retraso visual para evitar mute/kick del cliente
    local delay = 0
    for _, msg in ipairs(messages) do
        if channel == "LOCAL" then
            SendChatMessageSafe(msg, channel)
        else
            C_Timer.After(delay, function()
                SendChatMessageSafe(msg, channel)
            end)
            delay = delay + 0.45 -- Cooldown seguro para evitar spam
        end
    end
end

-- Anuncia la distribución de tareas actuales (Quién bufea qué)
function ReportFrame:AnnounceAssignments()
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
            -- Solo anunciar si el caster está activo en el grupo
            if units[casterName] or (not IsInGroup() and casterName == UnitName("player")) then
                -- Agrupar los objetivos del mismo buff para ahorrar caracteres
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
                    -- Usamos comas (", ") como separador de hechizos para no contener el pipe ("|")
                    table.insert(lines, string.format("%s (%s) buffea: %s", casterName, L:GetClassName(casterClass), table.concat(playerBuffs, ", ")))
                end
            end
        end
    end
    
    if not hasAny then
        table.insert(lines, "No hay buffs asignados en este momento.")
    end
    
    AnnounceToGroup(lines)
end

-- Anuncia los jugadores específicos que carecen de sus buffs (Quién no ha bufeado)
function ReportFrame:AnnounceMissing()
    local missing = Scanner:GetMissingBuffsReport()
    
    local lines = {}
    table.insert(lines, "[RaidBuffet] --- Buffs Faltantes en el Grupo ---")
    
    if #missing == 0 then
        table.insert(lines, "¡Todos los buffs están al día! Ningún jugador pendiente.")
    else
        for _, data in ipairs(missing) do
            local targetName = data.targetID
            if string.find(targetName, "GROUP_") then
                targetName = "Grupo " .. string.match(targetName, "GROUP_(%d+)")
            else
                targetName = L:GetClassName(targetName)
            end
            
            local missingList = table.concat(data.missingPlayers, ", ")
            
            -- Opción A: Petazo (PALADIN) debe poner Poderío a Guerreros (Faltan: GuerreroA, GuerreroB)
            table.insert(lines, string.format("%s (%s) debe poner %s a %s (Faltan: %s)", 
                data.casterName, data.casterClass, data.spellName, targetName, missingList))
        end
    end
    
    AnnounceToGroup(lines)
end

-- ============================================================================
-- BOTONES INFERIORES DE LA VENTANA
-- ============================================================================

-- Botón Refrescar
local refreshBtn = CreateFrame("Button", "RaidBuffetReportRefreshBtn", ReportFrame, "BackdropTemplate")
refreshBtn:SetSize(90, 24)
refreshBtn:SetPoint("BOTTOMLEFT", 10, 10)
refreshBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
refreshBtn:SetBackdropColor(0.14, 0.14, 0.14, 1)
refreshBtn:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
refreshBtn.text = refreshBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
refreshBtn.text:SetPoint("CENTER", 0, 0)
refreshBtn.text:SetText("Refrescar")
refreshBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.22, 0.22, 0.22, 1)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
end)
refreshBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.14, 0.14, 0.14, 1)
    self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
end)
refreshBtn:SetScript("OnClick", function()
    ReportFrame:UpdateReport()
end)

local announceAssignBtn = CreateFrame("Button", "RaidBuffetReportAnnounceAssignBtn", ReportFrame, "BackdropTemplate")
announceAssignBtn:SetSize(140, 24)
announceAssignBtn:SetPoint("BOTTOMLEFT", refreshBtn, "BOTTOMRIGHT", 10, 0)
announceAssignBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
announceAssignBtn:SetBackdropColor(0.14, 0.14, 0.14, 1)
announceAssignBtn:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
announceAssignBtn.text = announceAssignBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
announceAssignBtn.text:SetPoint("CENTER", 0, 0)
announceAssignBtn.text:SetText("Anunciar Tareas")
announceAssignBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.22, 0.22, 0.22, 1)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
end)
announceAssignBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.14, 0.14, 0.14, 1)
    self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
end)
announceAssignBtn:SetScript("OnClick", function()
    ReportFrame:AnnounceAssignments()
end)

local announceMissingBtn = CreateFrame("Button", "RaidBuffetReportAnnounceMissingBtn", ReportFrame, "BackdropTemplate")
announceMissingBtn:SetSize(140, 24)
announceMissingBtn:SetPoint("BOTTOMLEFT", announceAssignBtn, "BOTTOMRIGHT", 10, 0)
announceMissingBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 1,
})
announceMissingBtn:SetBackdropColor(0.14, 0.14, 0.14, 1)
announceMissingBtn:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
announceMissingBtn.text = announceMissingBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
announceMissingBtn.text:SetPoint("CENTER", 0, 0)
announceMissingBtn.text:SetText("Anunciar Faltantes")
announceMissingBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.22, 0.22, 0.22, 1)
    self:SetBackdropBorderColor(0.85, 0.7, 0.3, 1)
end)
announceMissingBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.14, 0.14, 0.14, 1)
    self:SetBackdropBorderColor(0.7, 0.5, 0.2, 0.5)
end)
announceMissingBtn:SetScript("OnClick", function()
    ReportFrame:AnnounceMissing()
end)

-- Texto indicador del canal configurado
local channelLbl = ReportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
channelLbl:SetPoint("BOTTOMRIGHT", -15, 38)
channelLbl:SetJustifyH("RIGHT")

local function UpdateChannelLabel()
    local currentChannel = RaidBuffetDB and RaidBuffetDB.AnnounceChannel or "RAID"
    local channelName = "Banda"
    for _, chData in ipairs(Constants.AnnounceChannels) do
        if chData.code == currentChannel then
            channelName = chData.name
            break
        end
    end
    channelLbl:SetText("Canal activo: |cff00ff00" .. channelName .. "|r")
end

ReportFrame:RegisterEvent("UNIT_AURA")
ReportFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
ReportFrame:SetScript("OnEvent", function(self, event, ...)
    if self:IsShown() then
        self:UpdateReport()
    end
end)

ReportFrame:SetScript("OnShow", function(self)
    self:UpdateReport()
    UpdateChannelLabel()
end)
