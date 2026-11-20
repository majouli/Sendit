--[[
  Leash: has the player walked away? Start() remembers the spot; Exceeded() once more than RANGE yards
  away - or, where UnitPosition is unreadable, after MOVE_TIME s of continuous walking.
]]
local _, ns = ...

local Leash = {}
ns.Leash = Leash

local RANGE = 12  -- yards: well past an NPC's interaction range
local MOVE_TIME = 2   -- seconds of walking when the position is unreadable

local origin = nil       -- { x, y, map, at } (x nil: position unreadable); nil = off
local movingSince = nil  -- GetTime() when the current walk began

local function Position()
    local fn = _G.UnitPosition
    if type(fn) ~= "function" then return nil end
    local ok, y, x, _, map = pcall(fn, "player")
    if not ok then return nil end
    y, x, map = ns.Safe.Value(y), ns.Safe.Value(x), ns.Safe.Value(map)
    if type(x) == "number" and type(y) == "number" then return x, y, map end
end

function Leash:Start()
    local x, y, map = Position()
    origin = { x = x, y = y, map = map, at = GetTime() }
end

function Leash:Stop()
    origin = nil
end

function Leash:Exceeded()
    if origin == nil then return false end
    if origin.x then
        local x, y, map = Position()
        if x then
            if map ~= origin.map then return true end  -- another instance: surely gone
            local dx, dy = x - origin.x, y - origin.y
            return dx * dx + dy * dy > RANGE * RANGE
        end
    end
    if not movingSince then return false end
    return GetTime() - math.max(movingSince, origin.at) > MOVE_TIME
end

local ev = CreateFrame("Frame")
ns.ownFrames[ev] = true
ev:SetScript("OnEvent", function(_, event)
    movingSince = event == "PLAYER_STARTED_MOVING" and GetTime() or nil
end)
for _, e in ipairs({ "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" }) do
    pcall(ev.RegisterEvent, ev, e)
end
