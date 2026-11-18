--[[
  Profiles: named sets of every setting of the suite (design + one section
  per module, see Init.lua).

  All profiles live account-wide in SenditDB.profiles, so every character can
  use any of them. Each character remembers its choice in
  SenditCharDB.profile; new characters, and characters whose profile was
  deleted, use "Default".

  Kept simple on purpose (no profiles per situation, no
  separate edit target): the picked profile is active, and it is what every
  page edits. A new profile starts from the defaults or as a copy of the
  active one, and becomes active.

  ns.profile always points at the active profile table; modules read their
  section through module.profile, rebound on every switch (Sendit.OnProfile).
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

-- After the saved variables are loaded (Init.lua).
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

-- Names, "Default" first, then alphabetical.
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

-- A new profile starts from the defaults, or with copy as a copy of the
-- active one; it becomes active.
function Profiles:Create(name, copy)
    name = strtrim(name or "")
    if name == "" then return false, L.ERR_NAME end
    if #name > MAX_NAME then return false, L.ERR_LONG:format(MAX_NAME) end
    if self:Exists(name) then return false, L.ERR_EXISTS:format(name) end
    Store()[name] = copy and ns.Copy(ns.profile) or Fresh()
    Activate(name)
    return true
end

-- Characters using a deleted profile fall back to Default on their next login.
function Profiles:Delete(name)
    if name == DEFAULT then return false, L.ERR_DEFAULT end
    if not self:Exists(name) then return false, L.ERR_MISSING:format(tostring(name)) end
    if name == self:Active() then Activate(DEFAULT) end
    Store()[name] = nil
    ns.SettingsChanged()
    return true
end

-- Reset keys of one module's sections to their defaults: the profile section
-- for keys in module.defaults, the account section otherwise.
function Profiles:Reset(module, keys)
    for _, k in ipairs(keys) do
        if module.defaults and module.defaults[k] ~= nil then
            module.profile[k] = ns.Copy(module.defaults[k])
        elseif module.accountDefaults and module.accountDefaults[k] ~= nil then
            module.db[k] = ns.Copy(module.accountDefaults[k])
        end
    end
end
