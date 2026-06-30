local addonName, addonTable = ...
local L = addonTable.L

-- Comprobamos si el cliente está en español
if GetLocale() == "esES" or GetLocale() == "esMX" then
    L["OPTIONS_TITLE"] = "Opciones de RaidBuffet"
    L["REAGENTS_LOW"] = "¡Componentes Bajos!"
end
