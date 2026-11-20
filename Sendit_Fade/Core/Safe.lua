--[[
  Safe: error-proof reads from frames Fade does not own. Secret values (Forever) may be stored but not
  compared, counted, used as keys or tested; foreign frames can answer secrets any time and some
  objects are forbidden. Rule: read foreign frames only through these helpers - plain values or nil.
]]
local _, ns = ...

local Safe = {}
ns.Safe = Safe

local issecretvalue = issecretvalue

function Safe.Value(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local Value = Safe.Value

function Safe.Call(obj, method, ...)
    local fn = obj[method]
    if not fn then return nil end
    local ok, v = pcall(fn, obj, ...)
    if ok then return Value(v) end
end
local Call = Safe.Call

function Safe.IsForbidden(obj)
    local ok, forbidden = pcall(obj.IsForbidden, obj)
    if ok and Value(forbidden) == true then return true end
    -- IsForbidden is unreliable: probe a harmless getter
    return not pcall(obj.GetParent, obj)
end

function Safe.Parent(obj)
    local ok, parent = pcall(obj.GetParent, obj)
    if ok then return parent end
end

local function Pack(...) return { ... } end

function Safe.Children(f)
    local ok, list = pcall(function() return Pack(f:GetChildren()) end)
    return ok and list or {}
end

function Safe.Regions(f)
    local ok, list = pcall(function() return Pack(f:GetRegions()) end)
    return ok and list or {}
end

function Safe.Name(obj)
    local name = Call(obj, "GetName")
    if type(name) == "string" then return name end
end

function Safe.IsVisible(obj)
    return Call(obj, "IsVisible") == true
end

function Safe.Visibility(obj)
    local v = Call(obj, "IsVisible")
    if v == true or v == false then return v end
end

function Safe.Alpha(obj)
    return Call(obj, "GetAlpha")
end

function Safe.Size(obj)
    local ok, w, h = pcall(obj.GetSize, obj)
    w, h = ok and Value(w), ok and Value(h)
    if w and h then return w, h end
end

function Safe.Rect(obj)
    local ok, l, b, w, h = pcall(obj.GetRect, obj)
    if not ok then return nil end
    l, b, w, h = Value(l), Value(b), Value(w), Value(h)
    local scale = Call(obj, "GetEffectiveScale")
    if not scale then
        local parent = Safe.Parent(obj)
        scale = parent and Call(parent, "GetEffectiveScale")
    end
    if not (l and b and w and h and scale) then return nil end
    scale = scale / UIParent:GetEffectiveScale()
    return l * scale, b * scale, w * scale, h * scale
end
