--[[
  Leash: has the player walked away from where something started?

  Leash:Start() remembers the spot; Leash:Exceeded() is true once the player
  is more than RANGE yards from it. UnitPosition is not readable everywhere
  (instances, maybe secret): then walking counts instead, MOVE_TIME seconds
  of continuous movement (about RANGE yards at run speed). Turning or
  jumping in place never counts.

  Used by Cinema: the film of an NPC's line ends when the player leaves.
]]
local _, ns = ...

local Leash = {}
ns.Leash = Leash

local RANGE = 12      -- yards: well past the interaction range of an NPC
local MOVE_TIME = 2   -- seconds of walking when the position is unreadable

local origin = nil       -- { x, y, map, at } (x nil: position unreadable); nil = off
local movingSince = nil  -- GetTime() when the current walk began

-- -> x, y, instance map, or nil when unreadable.
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
    -- Only walking since Start counts: the player may have been moving before.
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
