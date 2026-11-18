--[[
  Suite: the Sendit module addons as the game sees them, and their on/off
  switch (the sidebar of the window).

  Switching a module off disables its addon in the game's addon list, for
  all characters (C_AddOns.DisableAddOn with no character, like the addon
  list's "All"), so after a reload none of its code runs: no hooks, no
  frames, no tooltips. That is the only way to switch everything of a module
  off reliably; a module's own settings stay as they are for when it comes
  back. On takes a reload too. The core itself is not listed.

  Suite.Addons()            { { name, title, notes, icon, loaded, enabled, module }, ... }
                            every Sendit_* addon, in the client's order
  Suite.Get(name)
  Suite.SetEnabled(name, on)
  Suite.ReloadNeeded()      true when a switch differs from what is loaded
  Suite.ModuleAddon(module) the addon of a registered module
  Sendit.OnModuleSwitch(fn) fn(addonName, on) right after a switch: a module
                            hides what it shows at once (Fade: fading and its
                            icon), the reload then stops its code
]]
local _, ns = ...

local Suite = {}
ns.Suite = Suite

local function API() return _G["C_AddOns"] end

local switchListeners = {}
function ns.OnModuleSwitch(fn) switchListeners[#switchListeners + 1] = fn end

-- A module names its addon (RegisterModule{ addon = ... }); else by key
-- ("fade" -> "Sendit_Fade").
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
