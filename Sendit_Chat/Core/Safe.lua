--[[
  Safe: helpers for secret values.

  In a chat messaging lockdown (boss fights, instances) message texts and
  sender names arrive as secret values: they may be stored and passed to
  widgets (SetText / AddMessage accept them), but comparing, measuring,
  concatenating or gsub-ing them raises an error. Every transform in
  Sendit Chat asks Safe first and passes secrets through whole.
]]
local _, ns = ...

local Safe = {}
ns.Safe = Safe

local issecret = _G["issecretvalue"]

function Safe.IsSecret(v)
    return issecret ~= nil and issecret(v) == true
end

-- The value if it is a plain (non-secret) string, else nil.
function Safe.Str(v)
    if type(v) ~= "string" or Safe.IsSecret(v) then return nil end
    return v
end

-- The value if it is a plain number, else nil.
function Safe.Num(v)
    if type(v) ~= "number" or Safe.IsSecret(v) then return nil end
    return v
end

-- pcall that returns only the first result (nil on error).
function Safe.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
end

-- True while sending chat from addon code would be refused.
function Safe.InLockdown()
    local info = _G["C_ChatInfo"]
    local fn = info and info.InChatMessagingLockdown
    if not fn then return false end
    local ok, r = pcall(fn)
    if not ok or Safe.IsSecret(r) then return true end
    return r == true
end
