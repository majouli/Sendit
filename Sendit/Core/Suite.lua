--[[
  Suite: the Sendit module addons and their on/off switch. Off = C_AddOns.DisableAddOn for all
  characters, so after a reload none of its code runs; settings stay. The core is not listed.
  Suite.Addons() -> { { name, title, notes, icon, loaded, enabled, module } }
  Suite.Get(name) / SetEnabled(name, on) / ReloadNeeded() / ModuleAddon(module)
  Sendit.OnModuleSwitch(fn(addon, on))   a module hides what it shows at once
]]
local _, ns = ...

local Suite = {}
ns.Suite = Suite

local function API() return _G["C_AddOns"] end

local switchListeners = {}
function ns.OnModuleSwitch(fn) switchListeners[#switchListeners + 1] = fn end

-- a module names its addon (RegisterModule{ addon }); else by key ("fade" -> "Sendit_Fade")
local function Matches(module, name)
    if module.addon then return module.addon == name end
    return name:lower() == ("sendit_" .. tostring(module.key)):lower()
end

local function Names()
    local api, out = API(), {}
    if not (api and api.GetNumAddOns and api.GetAddOnInfo) then return out end
    for i = 1, api.GetNumAddOns() do
        local name = api.GetAddOnInfo(i)
        if type(name) == "string" and name:find("^Sendit_") then out[#out + 1] = name end
    end
    return out
end

function Suite.ModuleAddon(module)
    if not module then return nil end
    if module.addon then return module.addon end
    for _, name in ipairs(Names()) do
        if Matches(module, name) then return name end
    end
end

local function ModuleOf(name)
    for _, m in ipairs(ns.modules) do
        if Matches(m, name) then return m end
    end
end

local function Enabled(name)
    local api = API()
    if not (api and api.GetAddOnEnableState) then return true end
    local ok, state = pcall(api.GetAddOnEnableState, name, nil)
    return not ok or (tonumber(state) or 0) > 0
end

function Suite.Addons()
    local api, out = API(), {}
    if not (api and api.GetNumAddOns and api.GetAddOnInfo) then return out end
    for i = 1, api.GetNumAddOns() do
        local name, title, notes = api.GetAddOnInfo(i)
        if type(name) == "string" and name:find("^Sendit_") then
            title = type(title) == "string" and title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or name
            out[#out + 1] = {
                name = name,
                title = title:gsub("^Sendit:%s*", ""),
                notes = notes,
                icon = api.GetAddOnMetadata and api.GetAddOnMetadata(name, "IconTexture") or nil,
                loaded = api.IsAddOnLoaded and api.IsAddOnLoaded(name) and true or false,
                enabled = Enabled(name),
                module = ModuleOf(name),
            }
        end
    end
    return out
end

function Suite.Get(name)
    for _, a in ipairs(Suite.Addons()) do
        if a.name == name then return a end
    end
end

function Suite.SetEnabled(name, on)
    local api = API()
    if not api then return end
    if on then api.EnableAddOn(name) else api.DisableAddOn(name) end
    if api.SaveAddOns then api.SaveAddOns() end
    for _, fn in ipairs(switchListeners) do pcall(fn, name, on) end
end

function Suite.ReloadNeeded()
    for _, a in ipairs(Suite.Addons()) do
        if a.enabled ~= a.loaded then return true end
    end
    return false
end
