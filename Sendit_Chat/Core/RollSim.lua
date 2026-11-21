--[[
  RollSim: /chat rolltest - plays a group loot roll and a /roll challenge without a group, through the
  real paths (the client's own loot and roll texts into Rolls / Duels), so the arena, the reveal and
  the result card show as in a raid. Item: the player's main hand (always cached), else a hearthstone.
  Only the result line reaches the chat (restyled into the roll summary, as a real one).
]]
local _, ns = ...
local Safe = ns.Safe

local RollSim = {}
ns.RollSim = RollSim

local NAMES = { "Aldric", "Mirela", "Torvan", "Kessa" }
local FALLBACK = "|cffffffff|Hitem:6948::::::::1:::::|h[Hearthstone]|h|r"

-- a client template filled in; loot texts with a "[Loot]" history link get its number first
local function Fmt(global, ...)
    local fmt = _G[global]
    if type(fmt) ~= "string" then return nil end
    if fmt:find("^|HlootHistory:%%d") then return fmt:format(0, ...) end
    return fmt:format(...)
end

local function Loot(global, ...)
    local text = Fmt(global, ...)
    if text then ns.Rolls.OnEvent(nil, text) end
    return text
end

-- the result into the chat like the client's loot line
local function Echo(text)
    local cf = _G["DEFAULT_CHAT_FRAME"]
    local info = _G["ChatTypeInfo"] and _G["ChatTypeInfo"].LOOT
    if cf and text then cf:AddMessage(text, info and info.r or 0, info and info.g or 0.67, info and info.b or 0) end
end

local function Distinct(n)
    local used, out = {}, {}
    while #out < n do
        local v = math.random(1, 100)
        if not used[v] then used[v], out[#out + 1] = true, v end
    end
    return out
end

local function ItemLink()
    for _, slot in ipairs({ 16, 1, 5, 7 }) do
        local link = Safe.Str(Safe.Call(_G["GetInventoryItemLink"], "player", slot))
        if link and link:find("|Hitem:", 1, true) then return link end
    end
    return FALLBACK
end

-- steps: { at seconds, fn }
local function Play(steps)
    for _, s in ipairs(steps) do C_Timer.After(s[1], s[2]) end
end

function RollSim.Run()
    if not ns.db.rollArena then return ns.Print(ns.L.ROLL_TEST_OFF) end
    local me = Safe.Str(Safe.Call(_G["UnitName"], "player")) or "You"
    local link = ItemLink()
    local a, m, t, k = NAMES[1], NAMES[2], NAMES[3], NAMES[4]
    local v = Distinct(3)       -- Mirela, me, Aldric (need); Torvan's greed does not roll
    local winner, best = m, v[1]
    if v[2] > best then winner, best = me, v[2] end
    if v[3] > best then winner = a end
    local r = Distinct(4)
    Play({
        { 0, function() ns.Duels.Start(link, 14) end },
        { 0.8, function() Loot("LOOT_ROLL_NEED", m, link) end },
        { 1.6, function() Loot("LOOT_ROLL_GREED", t, link) end },
        { 2.4, function() Loot("LOOT_ROLL_PASSED", k, link) end },
        { 3.4, function() Loot("LOOT_ROLL_NEED_SELF", link) end },
        { 4.4, function() Loot("LOOT_ROLL_NEED", a, link) end },
        { 5.5, function()
            Loot("LOOT_ROLL_ROLLED_NEED", v[1], link, m)
            Loot("LOOT_ROLL_ROLLED_NEED", v[2], link, me)
            Loot("LOOT_ROLL_ROLLED_NEED", v[3], link, a)
            if winner == me then Echo(Loot("LOOT_ROLL_YOU_WON", link)) else Echo(Loot("LOOT_ROLL_WON", winner, link)) end
        end },
        { 13, function() ns.Duels.OnSystem(nil, Fmt("RANDOM_ROLL_RESULT", k, r[1], 1, 100)) end },
        { 14, function() ns.Duels.OnSystem(nil, Fmt("RANDOM_ROLL_RESULT", me, r[2], 1, 100)) end },
        { 15.2, function() ns.Duels.OnSystem(nil, Fmt("RANDOM_ROLL_RESULT", t, r[3], 1, 100)) end },
        { 16.2, function() ns.Duels.OnSystem(nil, Fmt("RANDOM_ROLL_RESULT", a, r[4], 1, 100)) end },
    })
end
