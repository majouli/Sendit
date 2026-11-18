--[[
  Init: namespace, settings binding, saved data, event dispatch, secret-safe
  helpers, slash.
  Settings live in the Sendit core: ns.db = this module's section of the
  active profile (auto = inspect on hover, itemTip / playerTip = tooltip
  lines, charRow = character window row, inspectPos = "top" | "bottom"),
  rebound on every profile switch; the Sendit window has its page (Pages.lua).
  Sendit_GearScoreDB (account, data): players = known players by GUID (score,
  item level, talents, time), talentPos, probe / probeJournal = last probes.
  ns.On(event, fn) adds a listener; several per event. Files add slash
  sub commands to ns.commands.
]]
local ADDON, ns = ...
local L = ns.L

ns.DB_VERSION = 1
ns.defaults = { auto = true, itemTip = true, playerTip = true, charRow = true, inspectPos = "top" }
ns.commands = {}
-- Known players older than this are dropped at login: gear moves on.
local KEEP_SECONDS = 30 * 24 * 3600

local PREFIX = "|cffe6b84d" .. L.title .. "|r: "
function ns.Print(...)
    print(PREFIX .. strjoin(" ", tostringall(...)))
end

-- Secret values (Forever) may be stored but not compared: everything read
-- from the client passes through Safe before it is used.
local isSecret = issecretvalue or function() return false end
function ns.Safe(v)
    if v == nil or isSecret(v) then return nil end
    return v
end

-- pcall + Safe for one return value.
function ns.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    return ns.Safe(v)
end

function ns.GUID(unit)
    return ns.Call(UnitGUID, unit)
end

function ns.ClassOf(unit)
    local ok, _, class = pcall(UnitClass, unit)
    return ok and ns.Safe(class) or nil
end

local listeners = {}
local events = CreateFrame("Frame")
function ns.On(event, fn)
    if not listeners[event] then
        listeners[event] = {}
        -- events this client does not know are skipped, not an error
        pcall(events.RegisterEvent, events, event)
    end
    table.insert(listeners[event], fn)
end
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(listeners[event]) do fn(...) end
end)

ns.module = Sendit:RegisterModule({
    addon = "Sendit_GearScore",
    key = "gearscore",
    title = "GearScore",
    icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02",
    defaults = ns.defaults,
    status = function()
        if not ns.Score then return nil end
        local ok, r = pcall(ns.Score.Unit, "player")
        return ok and r and tostring(r.score) or nil
    end,
})
local function Bind() ns.db = ns.module.profile end
Sendit.OnReady(Bind)
Sendit.OnProfile(Bind)

local function Migrate(db)
    -- Version 1 is the first saved format; later format changes add steps here.
    db.version = ns.DB_VERSION
end

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    Sendit_GearScoreDB = Sendit_GearScoreDB or {}
    local db = Sendit_GearScoreDB
    Migrate(db)
    db.players = db.players or {}
    local now = time()
    for guid, p in pairs(db.players) do
        if type(p) ~= "table" or not p.t or now - p.t > KEEP_SECONDS then db.players[guid] = nil end
    end
    ns.data = db
end)

function ns.commands.auto()
    ns.db.auto = not ns.db.auto
    ns.Print(ns.db.auto and L.autoOn or L.autoOff)
    Sendit.SettingsChanged()
end

function ns.commands.reset()
    wipe(ns.data.players)
    if ns.Inspect then ns.Inspect.Forget() end
    ns.Print(L.cacheCleared)
end

-- Slash command (globals by necessity: the client looks them up by name).
SLASH_SENDITGEARSCORE1 = "/gs"
SLASH_SENDITGEARSCORE2 = "/gearscore"
SlashCmdList.SENDITGEARSCORE = function(msg)
    if not ns.data then return end
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        ns.OpenSettings()
    elseif cmd == "score" then
        local r = ns.Score.Unit("player")
        ns.Print(L.yourScore:format(ns.Score.Colored(r.score), r.ilvl))
    elseif ns.commands[cmd] then
        ns.commands[cmd](rest)
    else
        ns.Print(L.help)
    end
end
