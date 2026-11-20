--[[
  Triggers: when the UI must be awake. Unit values are secret: never read health or casts - events
  carry it (UNIT_HEALTH ticks until full, spellcast start / stop, PLAYER_REGEN_*). Power regen is no
  trigger (mana ticks woke the UI over and over).
]]
local _, ns = ...

local Triggers = { lastWake = GetTime(), reason = "login" }
ns.Triggers = Triggers

local CAST_TIMEOUT = 30  -- a lost stop event must not keep the UI awake forever

local inCombat, castStart, hasTarget = false, nil, false
local holds = {}  -- owner -> reason: fading paused

function Triggers:Wake(reason)
    self.lastWake = GetTime()
    self.reason = reason
end

local function Wake(trigger, reason)
    if ns.profile and ns.profile.triggers[trigger] then Triggers:Wake(reason or trigger) end
end

function Triggers:Hold(owner, reason)
    holds[owner] = reason
    if reason then self:Wake(reason) end
end

function Triggers:Active(now)
    local _, held = next(holds)
    if held then return held end
    local t = ns.profile.triggers
    if t.combat and (inCombat or InCombatLockdown()) then return "combat" end
    if t.target and hasTarget then return "target" end
    if t.casting and castStart and now - castStart < CAST_TIMEOUT then return "casting" end
end

function Triggers:Refresh()
    ns:PLAYER_TARGET_CHANGED()  -- a target can survive /reload without the event
end

function ns:UNIT_HEALTH() Wake("health") end
ns.UNIT_HEALTH_FREQUENT = ns.UNIT_HEALTH

local function CastStart() castStart = GetTime(); Wake("casting") end
local function CastStop()  castStart = nil;       Wake("casting") end
ns.UNIT_SPELLCAST_START         = CastStart
ns.UNIT_SPELLCAST_CHANNEL_START = CastStart
ns.UNIT_SPELLCAST_STOP          = CastStop
ns.UNIT_SPELLCAST_CHANNEL_STOP  = CastStop
ns.UNIT_SPELLCAST_INTERRUPTED   = CastStop
ns.UNIT_SPELLCAST_FAILED        = CastStop
function ns:UNIT_SPELLCAST_SUCCEEDED() Wake("casting") end

function ns:PLAYER_REGEN_DISABLED() inCombat = true end
function ns:PLAYER_REGEN_ENABLED()  inCombat = false; Wake("combat", "combat ended") end
function ns:PLAYER_TARGET_CHANGED() hasTarget = ns.Safe.Value(UnitExists("target")) == true end

-- chat activity shows the chat elements for `delay` (the event only, never its text)
local CHAT_TRIGGERS = {
    CHAT_MSG_PARTY = "chatGroup", CHAT_MSG_PARTY_LEADER = "chatGroup",
    CHAT_MSG_RAID = "chatGroup", CHAT_MSG_RAID_LEADER = "chatGroup", CHAT_MSG_RAID_WARNING = "chatGroup",
    CHAT_MSG_INSTANCE_CHAT = "chatGroup", CHAT_MSG_INSTANCE_CHAT_LEADER = "chatGroup",
    CHAT_MSG_LOOT = "chatLoot", CHAT_MSG_MONEY = "chatLoot",
}
for event, key in pairs(CHAT_TRIGGERS) do
    ns[event] = function()
        if ns.profile and ns.profile.triggers[key] and ns.Fader then
            ns.Fader:PeekKind("chat", ns.profile.delay)
        end
    end
end

do
    local ev = ns.eventFrame
    for event in pairs(CHAT_TRIGGERS) do pcall(ev.RegisterEvent, ev, event) end
    local unitEvents = {
        "UNIT_HEALTH", "UNIT_HEALTH_FREQUENT",
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_SUCCEEDED",
    }
    -- an event this client does not know must not break loading
    for _, e in ipairs(unitEvents) do pcall(ev.RegisterUnitEvent, ev, e, "player") end
    for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
end
