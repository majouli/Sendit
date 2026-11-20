--[[
  Safe: in chat lockdown texts and senders are secret - they may be stored and passed to widgets, but
  not compared, measured, concatenated or gsub'd. Every transform asks Safe first.
]]
local _, ns = ...

local Safe = {}
ns.Safe = Safe

local issecret = _G["issecretvalue"]

function Safe.IsSecret(v)
    return issecret ~= nil and issecret(v) == true
end

function Safe.Str(v)
    if type(v) ~= "string" or Safe.IsSecret(v) then return nil end
    return v
end

function Safe.Num(v)
    if type(v) ~= "number" or Safe.IsSecret(v) then return nil end
    return v
end

function Safe.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
end

-- true while sending chat from addon code would be refused
function Safe.InLockdown()
    local info = _G["C_ChatInfo"]
    local fn = info and info.InChatMessagingLockdown
    if not fn then return false end
    local ok, r = pcall(fn)
    if not ok or Safe.IsSecret(r) then return true end
    return r == true
end
