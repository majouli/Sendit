--[[
  Profiles: named sets of every setting (design + one section per module), account-wide in
  SenditDB.profiles; each character remembers its choice (SenditCharDB.profile, else "Default").
  The picked profile is active and is what every page edits. ns.profile = the active table.
]]
local _, ns = ...

local Profiles = {}
ns.Profiles = Profiles
local L = ns.L

local DEFAULT = "Default"
local MAX_NAME = 32
Profiles.DEFAULT = DEFAULT

local function Store()
    return ns.db.profiles
end

local function Fresh()
    local p = {}
    ns.FillProfile(p)
    return p
end

local function Activate(name)
    SenditCharDB.profile = name
    ns.profile = Store()[name]
    ns.BindAll()
    ns.FireProfile()
    ns.SettingsChanged()
end

function Profiles:Load()
    local store = Store()
    store[DEFAULT] = store[DEFAULT] or {}
    for _, p in pairs(store) do ns.FillProfile(p) end
    local char = SenditCharDB
    if not store[char.profile or ""] then char.profile = DEFAULT end
    ns.profile = store[char.profile]
end

function Profiles:Active()
    return SenditCharDB.profile
end

function Profiles:Exists(name)
    return name ~= nil and Store()[name] ~= nil
end

function Profiles:List()
    local names = {}
    for name in pairs(Store()) do
        if name ~= DEFAULT then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    table.insert(names, 1, DEFAULT)
    return names
end

function Profiles:Use(name)
    if not self:Exists(name) then return false, L.ERR_MISSING:format(tostring(name)) end
    if name ~= self:Active() then Activate(name) end
    return true
end

-- a new profile: the defaults or a copy of the active one; it becomes active
function Profiles:Create(name, copy)
    name = strtrim(name or "")
    if name == "" then return false, L.ERR_NAME end
    if #name > MAX_NAME then return false, L.ERR_LONG:format(MAX_NAME) end
    if self:Exists(name) then return false, L.ERR_EXISTS:format(name) end
    Store()[name] = copy and ns.Copy(ns.profile) or Fresh()
    Activate(name)
    return true
end

function Profiles:Delete(name)
    if name == DEFAULT then return false, L.ERR_DEFAULT end
    if not self:Exists(name) then return false, L.ERR_MISSING:format(tostring(name)) end
    if name == self:Active() then Activate(DEFAULT) end
    Store()[name] = nil
    ns.SettingsChanged()
    return true
end

-- reset keys of one module's sections to their defaults (profile or account section)
function Profiles:Reset(module, keys)
    for _, k in ipairs(keys) do
        if module.defaults and module.defaults[k] ~= nil then
            module.profile[k] = ns.Copy(module.defaults[k])
        elseif module.accountDefaults and module.accountDefaults[k] ~= nil then
            module.db[k] = ns.Copy(module.accountDefaults[k])
        end
    end
end
