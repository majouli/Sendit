--[[
  Init: namespace, settings binding (ns.db = the profile section: auto, itemTip, playerTip, charRow,
  inspectPos), saved data, event dispatch, secret-safe helpers, slash.
  Sendit_GearScoreDB (account): players by GUID (score, ilvl, talents, time), talentPos, probes.
  ns.On(event, fn) adds a listener; files add slash sub commands to ns.commands.
]]
local ADDON, ns = ...
local L = ns.L

ns.DB_VERSION = 1
ns.defaults = { auto = true, itemTip = true, playerTip = true, charRow = true, inspectPos = "top" }
ns.commands = {}
-- known players older than this are dropped at login
local KEEP_SECONDS = 30 * 24 * 3600

local PREFIX = "|cffe6b84d" .. L.title .. "|r: "
function ns.Print(...)
    print(PREFIX .. strjoin(" ", tostringall(...)))
end

local isSecret = issecretvalue or function() return false end
function ns.Safe(v)
    if v == nil or isSecret(v) then return nil end
    return v
end

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
    icon = "Interface\\AddOns\\Sendit_GearScore\\Media\\Icon",
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
