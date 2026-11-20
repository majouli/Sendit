--[[
  Init: registers the Talents module; client-read helpers (pcall + Safe).
  Account: timeline folded out. Per character: SenditTalentsChar[configID] = route key | "off";
  nothing saved = the suggested route.
]]
local _, ns = ...
ns.module = Sendit:RegisterModule({
    key = "talents", title = "Talents", addon = "Sendit_Talents",
    icon = "Interface\\AddOns\\Sendit_Talents\\Media\\Icon",
    accountDefaults = { timeline = false },
})

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

function ns.Choice(configID)
    local db = SenditTalentsChar
    return type(db) == "table" and db[configID] or nil
end

function ns.SetChoice(configID, key)
    SenditTalentsChar = type(SenditTalentsChar) == "table" and SenditTalentsChar or {}
    SenditTalentsChar[configID] = key
end

Sendit.OnModuleSwitch(function(addon, on)
    if addon ~= "Sendit_Talents" then return end
    ns.disabled = not on
    if ns.Refresh then ns.Refresh() end
end)
