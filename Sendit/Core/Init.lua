--[[
  Init: the core namespace (the one global `Sendit`), saved variables, module registry.
  SenditDB (account): version, profiles, module account sections, core UI (minimap, app bar);
  SenditCharDB (character): { profile = name }. Core format changes: Migrate; a module's: def.migrate.
  A profile = profile.design + one section per module; data that is no setting stays in the module's
  own saved variables.

  Module contract (Sendit.API; raise it when a documented call changes):
    local M = Sendit:RegisterModule{ key, title, icon, addon, defaults, accountDefaults,
                                     version, migrate(section, from), status() }
    M.profile / M.db             active profile section / account section (rebound on every switch)
    Sendit.OnReady(fn) / OnProfile(fn) / OnModuleSwitch(fn(addon, on))
    Sendit.OnSettingsChanged(fn) / SettingsChanged()
    Sendit.Provide(name, api) / Service(name) -> api | nil (nil: module off or missing)
    Sendit.Locale, Theme, Widgets, Options, Profiles, ItemRatings
    Sendit:AddQuickToggle (minimap menu) / Sendit:AddLauncher (app bar)
  Everything else on `Sendit` is internal. Registration works before and after ADDON_LOADED.
]]
local ADDON, ns = ...

Sendit = ns

ns.API = 2
ns.DB_VERSION = 1

local services = {}
function ns.Provide(name, api) services[name] = api end
function ns.Service(name) return services[name] end
ns.name = ADDON
ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.ICON = "Interface\\AddOns\\Sendit\\Media\\Icon"
ns.ownFrames = {}  -- frames of the suite: Sendit_Fade never fades them
ns.modules = {}
ns.commands = {}  -- /sendit sub commands

local PREFIX = "|cffe6ba66Sendit|r: "
function ns.Print(...)
    print(PREFIX .. strjoin(" ", tostringall(...)))
end

local function Listeners()
    local list = {}
    return list, function(fn) list[#list + 1] = fn end, function(...)
        for _, fn in ipairs(list) do fn(...) end
    end
end

local _, onChanged, fireChanged = Listeners()
ns.OnSettingsChanged, ns.SettingsChanged = onChanged, fireChanged
local _, onProfile, fireProfile = Listeners()
ns.OnProfile, ns.FireProfile = onProfile, fireProfile

local readyList = {}
function ns.OnReady(fn)
    if ns.db then fn() else readyList[#readyList + 1] = fn end
end

function ns.Copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = ns.Copy(x) end
    return c
end

-- fill missing keys from the defaults; tables empty by default (user lists) are created once
function ns.Merge(db, def)
    for k, v in pairs(def) do
        if db[k] == nil then
            db[k] = ns.Copy(v)
        elseif type(v) == "table" and type(db[k]) == "table" and next(v) ~= nil then
            ns.Merge(db[k], v)
        end
    end
end

ns.defaults = {
    minimap = { hide = false, angle = 200 },
    appbar = { hide = false, open = false },
}

local byKey = {}

-- a module's sections in an older format: its migrate runs once per section
local function MigrateModule(m)
    local want = m.version or 1
    local versions = ns.db.moduleVersions
    local from = versions[m.key] or want
    if from < want and m.migrate then
        for _, p in pairs(ns.db.profiles) do
            if p[m.key] then m.migrate(p[m.key], from) end
        end
        if ns.db.account[m.key] then m.migrate(ns.db.account[m.key], from) end
    end
    versions[m.key] = want
end

local function Bind(m)
    ns.db.account[m.key] = ns.db.account[m.key] or {}
    m.db = ns.db.account[m.key]
    ns.Merge(m.db, m.accountDefaults or {})
    m.profile = ns.profile[m.key]
end

function ns.FillProfile(profile)
    for _, m in ipairs(ns.modules) do
        profile[m.key] = profile[m.key] or {}
        ns.Merge(profile[m.key], m.defaults or {})
    end
end

function ns:RegisterModule(def)
    assert(type(def.key) == "string" and not byKey[def.key], "Sendit: module key missing or taken")
    byKey[def.key] = def
    ns.modules[#ns.modules + 1] = def
    if ns.db then
        MigrateModule(def)
        for _, p in pairs(ns.db.profiles) do ns.FillProfile(p) end
        Bind(def)
    end
    return def
end

function ns:Module(key)
    return byKey[key]
end

function ns.BindAll()
    for _, m in ipairs(ns.modules) do Bind(m) end
end

-- the core's profile section: style "modern" | "azeroth", language "auto" or a code
ns:RegisterModule({
    key = "design",
    title = "Design",
    defaults = { palette = "dusk", style = "modern", animations = true, language = "auto" },
    -- debug: the error log - a tool, not part of a profile
    accountDefaults = { debug = false },
})

local function Migrate(db)
    db.version = ns.DB_VERSION
end

local events = CreateFrame("Frame")
ns.ownFrames[events] = true
events:SetScript("OnEvent", function(_, event, ...)
    local handler = ns[event]
    if handler then handler(ns, ...) end
end)
events:RegisterEvent("ADDON_LOADED")

function ns:ADDON_LOADED(name)
    if name ~= ADDON then return end
    events:UnregisterEvent("ADDON_LOADED")
    SenditDB = SenditDB or {}
    SenditCharDB = SenditCharDB or {}
    local db = SenditDB
    Migrate(db)
    ns.Merge(db, ns.defaults)
    db.account = db.account or {}
    db.profiles = db.profiles or {}
    db.moduleVersions = db.moduleVersions or {}
    ns.db = db
    for _, m in ipairs(ns.modules) do MigrateModule(m) end
    ns.Profiles:Load()
    ns.BindAll()
    local list = readyList
    readyList = {}
    for _, fn in ipairs(list) do fn() end
    ns.SettingsChanged()
end
