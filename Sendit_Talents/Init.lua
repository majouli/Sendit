--[[
  Init: registers the Talents module with Sendit and holds the client-read
  helpers. It has no settings: the module switch turns it on and off, the
  route is picked in Blizzard's talent window. Account layout: whether the
  route timeline is folded out.
  Saved per character: SenditTalentsChar[configID] = route key | "off"
  (Primary and Secondary talents are separate configs, each with its own route).
  Nothing saved = the suggested route (Route.Suggest).
]]
local _, ns = ...
ns.module = Sendit:RegisterModule({
    key = "talents", title = "Talents", addon = "Sendit_Talents",
    icon = "Interface\\AddOns\\Sendit_Talents\\Media\\Icon",
    accountDefaults = { timeline = false },  -- route timeline folded out
})

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
