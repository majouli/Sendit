--[[
  Gain: experience gains from any source - the change of UnitXP between two readings, across a
  level-up through the old UnitXPMax. Gain.On(fn(amount, max)); Gain.Update() on every XP event;
  Gain.Read() -> { xp, max, level } | nil.
  A secret or missing reading drops the base; the next readable one starts over.
]]
local _, ns = ...
local Gain = {}
ns.Gain = Gain

local isSecret = issecretvalue or function() return false end
local listeners = {}
local last

function Gain.Read()
    local ok, xp, max, level = pcall(function()
        return UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    end)
    if not ok or isSecret(xp) or isSecret(max) or isSecret(level) then return nil end
    if type(xp) ~= "number" or type(max) ~= "number" or type(level) ~= "number" or max <= 0 then return nil end
    return { xp = xp, max = max, level = level }
end

-- XP falling below the old reading is a level-up even before UnitLevel shows it; the new reading
-- then carries the next level so the later level change is not counted twice.
function Gain.Amount(old, new)
    if new.xp < old.xp or new.level > old.level then
        if new.level > old.level + 1 then return 0 end
        new.level = old.level + 1
        return old.max - old.xp + new.xp
    end
    return new.xp - old.xp
end

function Gain.On(fn) listeners[#listeners + 1] = fn end

function Gain.Update()
    local now = Gain.Read()
    local old = last
    last = now
    if not (old and now) then return end
    local amount = Gain.Amount(old, now)
    if amount <= 0 then return end
    for _, fn in ipairs(listeners) do fn(amount, old.max) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_XP_UPDATE")
events:SetScript("OnEvent", Gain.Update)
