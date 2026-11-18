local ADDON, ns = ...
local Sendit = Sendit

ns.SetLanguage("auto")

ns.ICON = "Interface\\Icons\\Trade_Herbalism"
ns.DB_VERSION = 1

ns.defaults = {
    enabled       = true,
    disenchant    = true,
    skinning      = true,
    mining        = true,
    herbalism     = true,
    names         = true,
    compact       = false,
    chances       = true,
    value         = true,
    shiftOnly     = false,
    onlyKnown     = true,
}

ns.dataDefaults = {
    prices        = {},
    absent        = {},
    dribbler      = {},
}

ns.module = Sendit:RegisterModule({
    addon = "Sendit_Harvest",
    key = "harvest",
    title = "Harvest",
    icon = ns.ICON,
    defaults = ns.defaults,
    status = function()
        if not ns.opt then return nil end
        return ns.opt.enabled and "on" or "off"
    end,
})

ns.OnSettingsChanged, ns.SettingsChanged = Sendit.OnSettingsChanged, Sendit.SettingsChanged

local function Bind()
    ns.opt = ns.module.profile
end
Sendit.OnReady(Bind)
Sendit.OnProfile(Bind)

function ns.Get(key)
    local v = ns.opt and ns.opt[key]
    if v == nil then v = ns.defaults[key] end
    return v
end

function ns.Set(key, value)
    ns.opt[key] = value
    ns.SettingsChanged()
end

local function FillDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = type(v) == "table" and {} or v
        end
    end
end

local function Migrate(db)
    db.version = ns.DB_VERSION
end
ns.Migrate = Migrate

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Sendit_HarvestDB = Sendit_HarvestDB or {}
    Migrate(Sendit_HarvestDB)
    FillDefaults(Sendit_HarvestDB, ns.dataDefaults)
    ns.db = Sendit_HarvestDB
    ns.SettingsChanged()
end)

SLASH_SENDITHARVEST1 = "/harvest"
SLASH_SENDITHARVEST2 = "/dei"
SlashCmdList.SENDITHARVEST = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "probe" then
        ns.Scanner.Probe()
    elseif cmd == "dribbler" or cmd == "dd" then
        ns.DribblerWindow.Toggle()
    elseif ns.OpenSettings then
        ns.OpenSettings()
    end
end
