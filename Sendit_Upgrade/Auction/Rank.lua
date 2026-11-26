--[[
  Rank: rates every candidate of the auction data once with Compare.Evaluate (its own link: random
  suffixes count) in the background, and shows the upgrades through the filters. Filters never rate
  again: Rank.Groups() filters and sorts the rated upgrades (Filter.Sort: best gain, cheapest, gain per
  gold), so a ticked slot shows at once. What the filters show is rated first.
  Background rules: each step works at most BUDGET ms (less while the window is closed), pauses in
  combat, and asks the server for at most REQUESTS unloaded items per second (a request flood crashed
  the client). Ratings are cached per variant until gear, level or spec change; then all are rated again.
  Rank.Start(candidates) / Stop() / Progress() -> rated, total, running, missing (never loaded)
  Rank.Groups() -> { { key, group, list = { candidate + pct, unit, gate } } } in Sendit.GearSlots order
  Rank.Count() -> upgrades shown;  Rank.Dirty() after a filter or sort change;  Rank.OnChange(fn)
  Rank.SetFast(on): the larger budget while the window is open
]]
local _, ns = ...
local Filter, Slots = ns.AuctionFilter, Sendit.GearSlots
local Rank = {}
ns.AuctionRank = Rank

local FAST, SLOW, STEP, COMBAT_WAIT = 6, 2, 0.03, 1  -- ms per step open / closed; s between steps; s in combat
local RETRIES, RETRY_AFTER, REQUESTS = 8, 1.5, 20
local Clock = debugprofilestop or function() return 0 end
local listeners = {}
local all, queue, head, generation, running = {}, {}, 1, 0, false
local rated, missing, budget = 0, 0, SLOW
local cache = {}  -- variant key -> { pct, unit, gate } | false (no upgrade)
local groups, dirty = {}, true
local requestSecond, requestCount = 0, 0

local function Changed() for _, fn in ipairs(listeners) do fn() end end
function Rank.OnChange(fn) listeners[#listeners + 1] = fn end
function Rank.SetFast(on) budget = on and FAST or SLOW end

local ORDER = {
    gain = function(a, b)
        if a.pct ~= b.pct then return a.pct > b.pct end
        return a.buyout < b.buyout
    end,
    price = function(a, b)
        if a.buyout ~= b.buyout then return a.buyout < b.buyout end
        return a.pct > b.pct
    end,
    value = function(a, b)
        local va, vb = a.pct / math.max(1, a.buyout), b.pct / math.max(1, b.buyout)
        if va ~= vb then return va > vb end
        return a.pct > b.pct
    end,
}

local function Shown(c)
    return Filter.Slot(c.equipLoc) and Filter.Price(c.buyout) and Filter.Type(c.itemID, c.equipLoc)
        and (c.quality == nil or Filter.Item(c.quality, c.reqLevel))
end

local function MayLoad(c)
    local cached = C_Item.IsItemDataCachedByID
    if not cached then return true end
    local ok, has = pcall(cached, c.itemID)
    if not ok or has then return true end
    local second = math.floor(GetTime())
    if second ~= requestSecond then requestSecond, requestCount = second, 0 end
    if requestCount >= REQUESTS then return false end
    requestCount = requestCount + 1
    return true
end

-- "wait" (item data not there yet) | "later" (no request share this second) | "done"
local function Rate(c)
    local known = cache[c.key]
    if known == nil then
        if not MayLoad(c) then return "later" end
        local name, _, quality, _, reqLevel = C_Item.GetItemInfo(c.link)
        if not quality then return "wait" end
        c.quality, c.reqLevel, c.name = quality, reqLevel, name
        local ok, r = pcall(ns.Compare.Evaluate, c.link)
        if ok and r and r.status == "loading" then return "wait" end
        local gain = ok and r and r.status == "ok" and r.primary and type(r.primary.pct) == "number"
            and r.primary.pct > 0
        known = gain and { pct = r.primary.pct, unit = r.primary.label, gate = r.levelGate } or false
        cache[c.key] = known
    elseif not c.name then  -- a new copy of a rated variant
        local name, _, quality, _, reqLevel = C_Item.GetItemInfo(c.link)
        if quality then c.quality, c.reqLevel, c.name = quality, reqLevel, name end
    end
    if known then
        c.pct, c.unit, c.gate = known.pct, known.unit, known.gate
        dirty = true
    end
    c.rated = true
    return "done"
end

local function Prioritize()
    local front, back = {}, {}
    for i = head, #queue do
        local c = queue[i]
        if Shown(c) then front[#front + 1] = c else back[#back + 1] = c end
    end
    for _, c in ipairs(back) do front[#front + 1] = c end
    queue, head = front, 1
end

local function Tick(gen)
    if gen ~= generation then return end
    if InCombatLockdown() then
        C_Timer.After(COMBAT_WAIT, function() Tick(gen) end)
        return
    end
    local now, start = GetTime(), Clock()
    local before, size, seen = rated, #queue - head + 1, 0
    while seen < size and Clock() - start < budget do  -- each waiting item once per step
        seen = seen + 1
        local c = queue[head]
        queue[head], head = nil, head + 1
        if c.retryAt and c.retryAt > now then
            queue[#queue + 1] = c
        else
            local result = Rate(c)
            if result == "done" then
                rated = rated + 1
            elseif result == "later" then
                c.retryAt = now + 1
                queue[#queue + 1] = c
            elseif (c.tries or 0) < RETRIES then
                c.tries, c.retryAt = (c.tries or 0) + 1, now + RETRY_AFTER
                queue[#queue + 1] = c
            else
                rated, missing = rated + 1, missing + 1
            end
        end
    end
    running = queue[head] ~= nil
    if rated ~= before or not running then Changed() end
    if running then C_Timer.After(STEP, function() Tick(gen) end) end
end

function Rank.Start(candidates)
    generation = generation + 1
    all, queue, head, rated, missing = candidates, {}, 1, 0, 0
    for i, c in ipairs(candidates) do
        c.tries, c.retryAt, c.pct, c.rated = nil, nil, nil, nil
        queue[i] = c
    end
    Prioritize()
    dirty, running = true, #queue > 0
    Changed()
    if running then
        local gen = generation
        C_Timer.After(0, function() Tick(gen) end)
    end
end

function Rank.Stop()
    generation = generation + 1
    queue, head, running = {}, 1, false
end

function Rank.Progress() return rated, #all, running, missing end

function Rank.Dirty()
    dirty = true
    if running then Prioritize() end
end

local service = Sendit.Service("upgrade")
if service then
    service.OnChange(function()
        cache = {}
        if #all > 0 then Rank.Start(all) end
    end)
end

function Rank.Groups()
    if not dirty then return groups end
    dirty = false
    local bySlot = {}
    for _, c in ipairs(all) do
        if c.pct and Shown(c) and Filter.Gain(c.pct) then
            local key = Slots.Group(c.equipLoc)
            if key then
                bySlot[key] = bySlot[key] or {}
                table.insert(bySlot[key], c)
            end
        end
    end
    local order = ORDER[Filter.Sort()]
    groups = {}
    for _, g in ipairs(Slots.GROUPS) do
        local list = bySlot[g.key]
        if list then
            table.sort(list, order)
            groups[#groups + 1] = { key = g.key, group = g, list = list }
        end
    end
    return groups
end

function Rank.Count()
    local n = 0
    for _, g in ipairs(Rank.Groups()) do n = n + #g.list end
    return n
end
