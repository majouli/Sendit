--[[
  Init: the Sendit core namespace, saved variables, module registry.

  Sendit is a suite: this core addon owns the one options window, the design,
  the language and the profiles; every module (Sendit_Fade, Sendit_Chat, ...)
  is its own addon that depends on the core and reaches it through the one
  global `Sendit` (addons share no `ns`).

  Saved variables
    SenditDB      account: version, profiles, each module's account section,
                  core UI (minimap)
    SenditCharDB  character: { profile = name } (Profiles.lua)
  Format changes of the core get a step in Migrate below; a module's own
  format changes go into its def.migrate(section, from) (see RegisterModule).

  A profile holds everything a player sets up: profile.design (Design page)
  and one section per module (profile[module.key]). Data that is no setting
  (caches, chat history, prices) stays in the module's own saved variables.

  Module contract (Sendit.API; raise it when a documented call changes):
    local M = Sendit:RegisterModule{
      key = "fade", title = "Fade", icon = "...",
      addon = "Sendit_Fade",      -- its addon folder: the sidebar's on/off switch
      defaults = { ... },         -- its profile section
      accountDefaults = { ... },  -- its account section (optional)
      version = 1, migrate = function(section, from) end,  -- optional
      status = function() return "12 faded" end,            -- optional
    }
    M.profile / M.db             the active profile section / the account
                                 section (rebound on every profile switch:
                                 never keep a reference across a switch)
    Sendit.OnReady(fn)           fn() once the saved variables are loaded
    Sendit.OnProfile(fn)         fn() after every profile switch
    Sendit.OnModuleSwitch(fn)    fn(addonName, on) when a module is switched in
                                 the sidebar: hide what is visible at once
    Sendit.OnSettingsChanged(fn) / Sendit.SettingsChanged()
    Sendit.Provide(name, api) / Sendit.Service(name) -> api or nil
                                 a module offers calls to the others by name
                                 (e.g. "upgrade": item ratings); nil when that
                                 module is switched off or not installed
    Sendit.Locale (Locale.lua), Sendit.Theme / Widgets / Options (UI/*),
    Sendit.Profiles, Sendit:AddQuickToggle (UI/MinimapButton.lua)
  Everything else on `Sendit` is internal. Registration works before and
  after the core's ADDON_LOADED.
]]
local ADDON, ns = ...

Sendit = ns  -- the one global: modules live in other addons

ns.API = 2
ns.DB_VERSION = 1

-- Services: what one module offers the others (they never know each other).
local services = {}
function ns.Provide(name, api) services[name] = api end
function ns.Service(name) return services[name] end
ns.name = ADDON
ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.ICON = "Interface\\Icons\\INV_Misc_Gear_01"
ns.ownFrames = {}  -- frames of the suite; Sendit_Fade never fades them
ns.modules = {}    -- registration order
ns.commands = {}   -- /sendit sub commands

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

-- Fill missing keys from the defaults. Tables that are empty by default
-- (user lists) are created once and never refilled.
function ns.Merge(db, def)
    for k, v in pairs(def) do
        if db[k] == nil then
            db[k] = ns.Copy(v)
        elseif type(v) == "table" and type(db[k]) == "table" and next(v) ~= nil then
            ns.Merge(db[k], v)
        end
    end
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------
ns.defaults = {  -- core account settings
    minimap = { hide = false, angle = 200 },
}

local byKey = {}

-- A module's saved sections in an older format of the module: its migrate
-- step runs once per section (every profile + the account section).
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

-- Point a module at its sections of the active profile and the account.
local function Bind(m)
    ns.db.account[m.key] = ns.db.account[m.key] or {}
    m.db = ns.db.account[m.key]
    ns.Merge(m.db, m.accountDefaults or {})
    m.profile = ns.profile[m.key]
end

-- Make sure every profile has a filled section for the module.
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

-- Rebind every module after a profile switch (Profiles.lua).
function ns.BindAll()
    for _, m in ipairs(ns.modules) do Bind(m) end
end

-- The core's own profile section: the look and the language of every module.
-- style: "modern" (1px hairlines) | "azeroth" (the game's gold borders).
-- language: "auto" (the client's) or a code of Locale.LANGUAGES.
ns:RegisterModule({
    key = "design",
    title = "Design",
    defaults = { palette = "dusk", style = "modern", animations = true, language = "auto" },
    -- debug: the error log (Core/ErrorLog.lua) - a tool, not part of a profile
    accountDefaults = { debug = false },
})

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
-- Older formats of the core's own keys. Version 1 is the first format.
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
