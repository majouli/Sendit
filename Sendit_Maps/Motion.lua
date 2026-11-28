--[[
  Motion: which way the player walks relative to where they look - from the movement keys (post-hooks on
  the client's movement functions, never more). Inside an instance the client gives no facing, only the
  located heading, which points backwards when walking backwards.
  Motion.Offset() -> angle of the walk against the facing (radians, counter-clockwise; 0 = forwards,
    pi = backwards) | nil (no movement key held: the heading says nothing about the facing)
  facing = heading - Motion.Offset()
  Motion.Turning() -> 1 (turning left, counter-clockwise) | -1 (right) | 0, from the turn keys
  Motion.TURN_RATE  radians per second of a key turn (the client's default turn speed, 180 degrees)
  A mouse turn is invisible here (no facing; the cursor delta stays 0 while the mouse steers): Camera.
]]
local _, ns = ...
local Motion = {}
ns.Motion = Motion

local keys = { forward = false, back = false, left = false, right = false, auto = false, turnLeft = false, turnRight = false }
Motion.TURN_RATE = math.pi
local atan2 = math.atan2 or math.atan

function Motion.Offset()
    local f = ((keys.forward or keys.auto) and 1 or 0) - (keys.back and 1 or 0)
    local s = (keys.left and 1 or 0) - (keys.right and 1 or 0)
    if f == 0 and s == 0 then return nil end
    return atan2(s, f)
end

local function Hook(name, key, on)
    if type(_G[name]) == "function" then hooksecurefunc(name, function() keys[key] = on end) end
end
Hook("MoveForwardStart", "forward", true)
Hook("MoveForwardStop", "forward", false)
Hook("MoveBackwardStart", "back", true)
Hook("MoveBackwardStop", "back", false)
Hook("StrafeLeftStart", "left", true)
Hook("StrafeLeftStop", "left", false)
Hook("StrafeRightStart", "right", true)
Hook("StrafeRightStop", "right", false)
if type(_G.ToggleAutoRun) == "function" then hooksecurefunc("ToggleAutoRun", function() keys.auto = not keys.auto end) end
Hook("StartAutoRun", "auto", true)
Hook("StopAutoRun", "auto", false)
Hook("MoveForwardStart", "auto", false)  -- pressing forward ends autorun
Hook("MoveBackwardStart", "auto", false)

Hook("TurnLeftStart", "turnLeft", true)
Hook("TurnLeftStop", "turnLeft", false)
Hook("TurnRightStart", "turnRight", true)
Hook("TurnRightStop", "turnRight", false)

function Motion.Turning() return (keys.turnLeft and 1 or 0) - (keys.turnRight and 1 or 0) end

function Motion.Set(key, on) keys[key] = on end  -- tests
