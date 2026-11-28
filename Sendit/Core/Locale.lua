--[[
  Locale: one language for the whole suite (profile.design.language).
  Sendit.Locale.New(tables) -> L   L.key = active language, else English, else the key
  Sendit.Locale.Code()             "auto" resolved (esMX -> esES, enGB -> enUS)
  Sendit.Locale.LANGUAGES / Text(L, key) (a function: follows a switch) / Missing(L)
  Sendit.Locale.Global(name) -> a client text (slot, quality) in the suite language (Data/ClientNames.lua),
    else the client's own _G[name] | nil;  Sendit.Locale.SubClass(classID, subclassID) -> weapon/armor
    item sub class name (weapon, armor, trade goods, ...) the same way | nil
]]
local _, ns = ...

local Locale = {}
ns.Locale = Locale

Locale.LANGUAGES = {
    { code = "enUS", name = "English" },
    { code = "deDE", name = "Deutsch" },
    { code = "frFR", name = "Français" },
    { code = "esES", name = "Español" },
    { code = "ruRU", name = "Русский" },
}

local ALIAS = { enGB = "enUS", esMX = "esES" }

function Locale.Code()
    local d = ns.profile and ns.profile.design
    local code = d and d.language or "auto"
    if code == "auto" then code = GetLocale and GetLocale() or "enUS" end
    return ALIAS[code] or code
end

local registry = setmetatable({}, { __mode = "k" })

function Locale.New(tables)
    local L = setmetatable({}, { __index = function(_, key)
        local t = tables[Locale.Code()]
        local v = t and t[key]
        if v == nil and tables.enUS then v = tables.enUS[key] end
        if v == nil then return key end
        return v
    end })
    registry[L] = tables
    return L
end

function Locale.Missing(L)
    local tables = registry[L]
    local out = {}
    if not (tables and tables.enUS) then return out end
    for _, lang in ipairs(Locale.LANGUAGES) do
        local t = tables[lang.code] or {}
        for key in pairs(tables.enUS) do
            if t[key] == nil then
                out[lang.code] = out[lang.code] or {}
                table.insert(out[lang.code], key)
            end
        end
        if out[lang.code] then table.sort(out[lang.code]) end
    end
    return out
end

local function ClientNames() return ns.clientNames and ns.clientNames[Locale.Code()] end

function Locale.Global(name)
    local t = ClientNames()
    local v = t and t.globals[name]
    if v then return v end
    v = _G[name]
    return type(v) == "string" and v or nil
end

function Locale.SubClass(classID, subclassID)
    local t = ClientNames()
    return t and t.subclasses[classID .. ":" .. subclassID] or nil
end

function Locale.Text(L, key)
    return function() return L[key] end
end

function Locale.Resolve(text)
    if type(text) == "function" then return text() end
    return text
end
