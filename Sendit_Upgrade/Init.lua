--[[
  Init: namespace, module, saved variables, events, slash. No profile settings: the spec is per
  character, the window a tool. Sendit_UpgradeDB (account: probe, measure, auctionScanAt, auctionLast =
  the kept auction scan, auctionWindow = scan window size, auctionRatings = the scan's ratings with the
  character's fingerprint), Sendit_UpgradeCharDB (character: spec, enemy
  level, calibration, auction = the scan filters). /gc = window, /gc spec <key|auto>, /gc weights,
  /gc probe [links], /gc measure on|off|reset|window, /gc ah = auction upgrade scan. Gear, stats or level
  invalidate the context.
]]
local ADDON, ns = ...
local L = ns.L

ns.DB_VERSION = 2
ns.commands = {}

local PREFIX = "|cff66c2ffSendit Upgrade|r: "
function ns.Print(...)
    print(PREFIX .. strjoin(" ", tostringall(...)))
end

local function Migrate(db)
    -- 2: measure counts per character; the old account-wide counts mixed classes, pets and groups
    if (db.version or 1) < 2 and type(db.measure) == "table" then db.measure = { on = db.measure.on } end
    db.version = ns.DB_VERSION
end

ns.module = Sendit:RegisterModule({
    addon = "Sendit_Upgrade",
    key = "upgrade",
    title = "Upgrade",
    icon = "Interface\\AddOns\\Sendit_Upgrade\\Media\\Icon",
    status = function()
        local ok, ctx = pcall(function() return ns.charDB and ns.Compare.Context() end)
        return ok and ctx and L.specs[ctx.specKey] or nil
    end,
})

-- "automatic (Affliction)": the guess shown with the automatic choice
function ns.AutoLabel(ctx)
    if ctx == nil then
        local ok, c = pcall(function() return ns.charDB and ns.Compare.Context() end)
        ctx = ok and c or nil
    end
    local guessed = ctx and ctx.auto and L.specs[ctx.auto]
    return guessed and (L.specAuto .. " (" .. guessed .. ")") or L.specAuto
end

-- nil = guess from gear
function ns.SetSpec(key)
    ns.charDB.spec = key
    ns.Compare.Invalidate()
    if ns.Window then ns.Window:Refresh() end
    Sendit.SettingsChanged()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("UNIT_STATS")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("TRAIT_CONFIG_UPDATED")
events:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        Sendit_UpgradeDB = Sendit_UpgradeDB or {}
        Sendit_UpgradeCharDB = Sendit_UpgradeCharDB or {}
        Migrate(Sendit_UpgradeDB)
        ns.db, ns.charDB = Sendit_UpgradeDB, Sendit_UpgradeCharDB
        return
    end
    if event == "PLAYER_LEVEL_UP" then ns.Stats.ClearCache() end  -- red "requires level" lines change
    ns.Compare.Invalidate()
    if ns.Window then ns.Window:Refresh() end
end)

-- /gc spec <key> - any spec key of the player's class (ret, holy, frost, cat, ...)
function ns.commands.spec(arg)
    arg = (arg or ""):lower()
    local _, class = UnitClass("player")
    local data = class and ns.Specs[class]
    if arg == "auto" then
        ns.SetSpec(nil)
    elseif data and data.specs[arg:upper()] then
        ns.SetSpec(arg:upper())
    end
    local ctx = ns.Compare.Context()
    if ctx then ns.Print(L.specSet:format(L.specs[ctx.specKey] .. (ns.charDB.spec and "" or (" (" .. L.specAuto .. ")")))) end
end

SLASH_SENDITUPGRADE1 = "/gc"
SLASH_SENDITUPGRADE2 = "/upgrade"
SlashCmdList.SENDITUPGRADE = function(msg)
    if not ns.db then return end
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        ns.Window:Toggle()
    elseif ns.commands[cmd] then
        ns.commands[cmd](rest)
    else
        ns.Print(L.help)
    end
end
