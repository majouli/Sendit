--[[
  Duels: live state of the roll arena (off with rollArena). Per loot item: choices live; the server rolls
  all numbers at once, so they are revealed one per STEP, lowest first. Per /roll range: rolls live, a
  re-roll replaces the last one, decided IDLE s after the last roll with a summary line in the chat.
  Duel: { id, link | range, rows, ends, state = "live" | "reveal" | "done", winner }
  Row: { key, name, me, class, kind, value (shown), pending (not shown yet), led (took the lead) }
  Duels.OnChange(fn(duel, what, row)) - what = "row" | "reveal" | "done" | "gone"
]]
local _, ns = ...
local Safe, Loot = ns.Safe, ns.Loot

local Duels = {}
ns.Duels = Duels

local STEP = 0.7
local DONE_HOLD = 3       -- a decided duel stays this long, then the result card takes over
local IDLE = 12
local KEEP = 180          -- an undecided loot duel (group left) is dropped
local WEIGHT = { need = 3, greed = 2, de = 2 }

local duels, order, listeners = {}, {}, {}

function Duels.OnChange(fn) listeners[#listeners + 1] = fn end

local function Notify(d, what, row)
    for _, fn in ipairs(listeners) do fn(d, what, row) end
end

local function On() return ns.db and ns.db.rollArena end

function Duels.List() return order end

local function Remove(d)
    if duels[d.id] ~= d then return end
    duels[d.id] = nil
    for i, x in ipairs(order) do if x == d then table.remove(order, i) break end end
    if d.ticker then d.ticker:Cancel() end
    Notify(d, "gone")
end

local function New(id, fields)
    local d = { id = id, rows = {}, state = "live" }
    for k, v in pairs(fields) do d[k] = v end
    duels[id] = d
    order[#order + 1] = d
    C_Timer.After(KEEP, function() if d.state ~= "done" then Remove(d) end end)
    return d
end

-- need beats greed, then the number
local function Rank(kind, value) return (WEIGHT[kind] or 1) * 1000 + value end

function Duels.Score(row) return row.value and Rank(row.kind, row.value) end

function Duels.Leader(d)
    local best, bestScore
    for _, r in ipairs(d.rows) do
        local s = Duels.Score(r)
        if s and (not bestScore or s > bestScore) then best, bestScore = r, s end
    end
    return best
end

local function ClassOf(name)
    if not name then return nil end
    local fn = _G["UnitClass"]
    if type(fn) ~= "function" then return nil end
    local ok, _, class = pcall(fn, name)
    return ok and Safe.Str(class) or nil
end

local function Row(d, who, me)
    local key = me and "\0me" or ns.Rolls.First(who)
    for _, r in ipairs(d.rows) do if r.key == key then return r end end
    local r = { key = key, me = me, name = me and ns.L.YOU_SHORT or key, class = ClassOf(me and "player" or who) }
    d.rows[#d.rows + 1] = r
    return r
end

-- group loot -----------------------------------------------------------------

local function ItemId(link) return "item:" .. ns.Rolls.Key(link) end

-- a decided duel makes room for a new one
local function Open(link)
    local id = ItemId(link)
    local d = duels[id]
    if d and d.state == "done" then Remove(d) d = nil end
    return d or New(id, { link = link })
end

function Duels.Start(link, seconds)
    if not On() or not link then return end
    local d = Open(link)
    if seconds and seconds > 0 then d.ends = GetTime() + seconds end
    Notify(d, "row")
end

function Duels.Choice(link, who, kind, me)
    if not On() or not link then return end
    local d = Open(link)
    if d.state ~= "live" then return end
    local r = Row(d, who, me)
    r.kind = kind
    Notify(d, "row", r)
end

-- "<dice> /roll 1-100  Bob wins  Bob 99 · You 77"; the winner is the leader, so first
function Duels.Summary(d)
    local list = {}
    for _, r in ipairs(d.rows) do if r.value then list[#list + 1] = r end end
    table.sort(list, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.name < b.name
    end)
    local parts = {}
    for _, r in ipairs(list) do
        parts[#parts + 1] = (r == d.winner and "|cffffffff" or "|cff8a8f9c") .. r.name .. " " .. r.value .. "|r"
    end
    local w = d.winner
    local head = w and (w.me and ns.L.WON or ns.L.WINS:format(w.name)) or ""
    return "|T" .. ns.Rolls.ICONS.need .. ":0|t |cffffd100/roll " .. d.range .. "|r  " .. head .. "  "
        .. table.concat(parts, "|cff8a8f9c · |r")
end

local function Log(d)
    local cf = _G["DEFAULT_CHAT_FRAME"]
    local info = _G["ChatTypeInfo"] and _G["ChatTypeInfo"].SYSTEM
    if cf then cf:AddMessage(Duels.Summary(d), info and info.r or 1, info and info.g or 1, info and info.b or 0) end
end

local function Finish(d)
    if d.state == "done" then return end
    if d.ticker then d.ticker:Cancel() d.ticker = nil end
    d.state = "done"
    local f = d.final or {}
    local w = f.winner
    if w then
        d.winner = Row(d, w ~= true and w or nil, w == true or ns.Rolls._IsMe(w))
    else
        d.winner = Duels.Leader(d)
    end
    Notify(d, "done")
    if d.range and #d.rows > 0 then Log(d) end
    C_Timer.After(DONE_HOLD, function()
        if f.after then f.after() end
        Remove(d)
    end)
end

local function Show(d, r, value)
    local before = Duels.Leader(d)
    r.value, r.pending = value, nil
    r.led = Duels.Leader(d) == r and before ~= r
    Notify(d, "reveal", r)
end

local function RevealNext(d)
    local pick, low
    for _, r in ipairs(d.rows) do
        if r.pending and (not low or Rank(r.kind, r.pending) < low) then pick, low = r, Rank(r.kind, r.pending) end
    end
    if pick then
        Show(d, pick, pick.pending)
    elseif d.final then
        Finish(d)
    end
end

function Duels.Roll(link, who, kind, value, me)
    if not On() or not link or not value then return end
    local d = Open(link)
    if d.state == "done" then return end
    local r = Row(d, who, me)
    if r.value then return end   -- the own roll comes in two lines
    r.kind, r.pending = kind or r.kind, value
    if d.state ~= "reveal" then
        d.state, d.ends = "reveal", nil
        d.ticker = C_Timer.NewTicker(STEP, function() RevealNext(d) end)
    end
    Notify(d, "row", r)
end

-- winner: a name, true (the player) or nil (all passed); after() runs when the duel hands over.
-- false: no duel, the caller shows its card itself
function Duels.Final(link, winner, after)
    if not On() or not link then return false end
    local d = duels[ItemId(link)]
    if not d or d.state == "done" then return false end
    d.final = { winner = winner, after = after }
    if d.state ~= "reveal" then Finish(d) end
    return true
end

-- /roll challenges ------------------------------------------------------------

function Duels.RandomRoll(who, value, lo, hi, me)
    if not On() or not value then return end
    local id = "roll:" .. lo .. "-" .. hi
    local d = duels[id]
    if d and d.state == "done" then Remove(d) d = nil end
    d = d or New(id, { range = lo .. "-" .. hi })
    local r = Row(d, who, me)
    r.kind, d.state = "roll", "reveal"
    Show(d, r, value)
    local token = {}
    d.token = token
    C_Timer.After(IDLE, function() if d.token == token then Finish(d) end end)
end

local rollPat, rollOrder
local function ParseRandomRoll(text)
    if rollPat == nil then
        rollPat, rollOrder = Loot.Compile(_G["RANDOM_ROLL_RESULT"], { "who", "value", "lo", "hi" })
        rollPat = rollPat or false
    end
    if not rollPat or not Safe.Str(text) then return nil end
    local res = { text:find(rollPat) }
    if not res[1] then return nil end
    local v = {}
    for i, role in ipairs(rollOrder) do v[role] = res[i + 2] end
    v.value, v.lo, v.hi = tonumber(v.value), tonumber(v.lo), tonumber(v.hi)
    if not (v.who and v.value and v.lo and v.hi) then return nil end
    return v
end

function Duels.OnSystem(_, text)
    if not On() then return end
    local v = ParseRandomRoll(text)
    if v then Duels.RandomRoll(v.who, v.value, v.lo, v.hi, ns.Rolls._IsMe(v.who)) end
end

local function OnLootStart(_, rollID, rollTime)
    if not On() then return end
    local link = Safe.Str(Safe.Call(_G["GetLootRollItemLink"], rollID))
    local ms = Safe.Num(rollTime)
    if link then Duels.Start(link, ms and ms / 1000) end
end

ns.OnReady(function()
    ns.Listen("CHAT_MSG_SYSTEM", Duels.OnSystem)
    ns.Listen("START_LOOT_ROLL", OnLootStart)
end)
