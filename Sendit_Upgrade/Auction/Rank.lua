--[[
  Rank: rates every candidate of the auction data once with Compare.Evaluate (its own link: random
  suffixes count) in the background, and shows the upgrades through the filters. Filters never rate
  again: Rank.Groups() filters and sorts the rated upgrades (Filter.Sort: best gain, cheapest, gain per
  gold), so a ticked slot shows at once. Rated first: what the filters show and the client already knows,
  then what they show, then the rest (known first) - items the client must load wait for REQUESTS a second.
  Background rules: each step works at most BUDGET ms (less while the window is closed), pauses in
  combat, and asks the server for at most REQUESTS unloaded items per second (a request flood crashed
  the client). Ratings are cached per variant until gear, level or spec change; then all are rated again.
  Items above the level filter's top are put aside unrated (most of an auction house) and come back
  when the top is raised. Ratings are kept in Sendit_UpgradeDB.auctionRatings with a fingerprint of
  the character (spec, level, enemy level, worn links): after a reload the list is there at once.
  Rank.Start(candidates) / Stop() / Progress() -> rated, total, running, missing (never loaded)
  Rank.Groups() -> { { key, group, list = { candidate + pct, unit, gate } } } in Sendit.GearSlots order
  Rank.Count() -> upgrades shown;  Rank.Dirty() after a filter or sort change;  Rank.OnChange(fn)
  Rank.SetFast(on): the larger budget while the window is open
  Rank.Stats() -> { total, rated, missing, queued, deferred, kept, loads, throttled, limit, seconds,
    perSecond, eta } (/gc ah stats)
]]
local _, ns = ...
local Filter, Slots = ns.AuctionFilter, Sendit.GearSlots
local Rank = {}
ns.AuctionRank = Rank

local FAST, SLOW, STEP, COMBAT_WAIT = 6, 2, 0.03, 1  -- ms per step open / closed; s between steps; s in combat
local RETRIES, RETRY_AFTER, REQUESTS = 8, 1.5, 20
local Clock = debugprofilestop or function() return 0 end
local listeners = {}
-- the queue runs from head to tail; taken slots are cleared, so its length is never asked
-- (# of a table with holes is any border: the queue lost its end and spun without work)
local all, queue, head, tail, generation, running = {}, {}, 1, 0, 0, false

local function Push(c)
    tail = tail + 1
    queue[tail] = c
end
local rated, missing, budget = 0, 0, SLOW
local cache = {}  -- variant key -> { pct, unit, gate } | false (no upgrade)
local groups, dirty = {}, true
local requestSecond, requestCount = 0, 0
local stats = { loads = 0, throttled = 0, started = 0, kept = 0 }
local deferred, deferredTop = {}, nil  -- items above the level filter's top, and that top
local attached = false                  -- cache is the saved one (fingerprint known)
local SAVE_VERSION = 2                  -- 2: saves of version 1 could hold "no upgrade" from an unreadable moment

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

local function Cached(c)
    local fn = C_Item.IsItemDataCachedByID
    if not fn then return true end
    local ok, has = pcall(fn, c.itemID)
    return not ok or has == true
end

local function MayLoad(c)
    if Cached(c) then return true end
    local second = math.floor(GetTime())
    if second ~= requestSecond then requestSecond, requestCount = second, 0 end
    if requestCount >= REQUESTS then
        stats.throttled = stats.throttled + 1
        return false
    end
    requestCount = requestCount + 1
    stats.loads = stats.loads + 1
    return true
end

-- the character's fingerprint: ratings stay valid while it is the same
local function Fingerprint()
    local ok, ctx = pcall(ns.Compare.Context)
    if not ok or not ctx or not ctx.s then return nil end
    local parts = { tostring(ctx.specKey), tostring(ctx.s.level), tostring(ns.Settings.TargetDelta()) }
    for slot = 1, 19 do
        local g = ctx.gear and ctx.gear[slot]
        parts[#parts + 1] = g and g.link or ""
    end
    return table.concat(parts, "|")
end

-- takes the saved ratings when the fingerprint matches, else starts a new save with what is rated
local function Attach()
    if attached or not ns.db then return end
    local print = Fingerprint()
    if not print then return end
    local saved = ns.db.auctionRatings
    if saved and saved.print == print and saved.version == SAVE_VERSION and type(saved.map) == "table" then
        for key, v in pairs(cache) do saved.map[key] = v end
        cache = saved.map
        local n = 0
        for _ in pairs(cache) do n = n + 1 end
        stats.kept = n
    else
        ns.db.auctionRatings = { print = print, version = SAVE_VERSION, map = cache }
    end
    attached = true
end

local function Top() return select(2, Filter.Range()) end

-- "wait" (item data not there yet) | "later" (no request share this second) | "deferred" (above the
-- level filter) | "done"
local function Rate(c)
    local known = cache[c.key]
    if known == nil then
        if not MayLoad(c) then return "later" end
        local name, _, quality, _, reqLevel = C_Item.GetItemInfo(c.link)
        if not quality then return "wait" end
        c.quality, c.reqLevel, c.name = quality, reqLevel, name
        if (reqLevel or 0) > Top() then return "deferred" end
        local ok, r = pcall(ns.Compare.Evaluate, c.link)
        -- the character is not readable for a moment (gear loading, sheet secret): later, never "no upgrade"
        if ok and r and r.item and (r.status == "loading" or r.status == "nodata") then return "later" end
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
    local buckets = { {}, {}, {}, {} }  -- shown + known, shown, known, the rest
    for i = head, tail do
        local c = queue[i]
        local rank = (Shown(c) and 1 or 3) + (Cached(c) and 0 or 1)
        buckets[rank][#buckets[rank] + 1] = c
    end
    local out = {}
    for _, list in ipairs(buckets) do
        for _, c in ipairs(list) do out[#out + 1] = c end
    end
    queue, head, tail = out, 1, #out
end

local function Tick(gen)
    if gen ~= generation then return end
    if InCombatLockdown() then
        C_Timer.After(COMBAT_WAIT, function() Tick(gen) end)
        return
    end
    Attach()
    local now, start = GetTime(), Clock()
    local before, size, seen = rated, tail - head + 1, 0
    while seen < size and Clock() - start < budget do  -- each waiting item once per step
        seen = seen + 1
        local c = queue[head]
        queue[head], head = nil, head + 1
        if c.retryAt and c.retryAt > now then
            Push(c)
        else
            local result = Rate(c)
            if result == "done" then
                rated = rated + 1
            elseif result == "deferred" then
                rated = rated + 1
                deferred[#deferred + 1] = c
            elseif result == "later" then
                c.retryAt = now + 1
                Push(c)
            elseif (c.tries or 0) < RETRIES then
                c.tries, c.retryAt = (c.tries or 0) + 1, now + RETRY_AFTER
                Push(c)
            else
                rated, missing = rated + 1, missing + 1
            end
        end
    end
    running = head <= tail
    if rated ~= before or not running then Changed() end
    if running then C_Timer.After(STEP, function() Tick(gen) end) end
end

function Rank.Start(candidates)
    generation = generation + 1
    all, queue, head, tail, rated, missing = candidates, {}, 1, 0, 0, 0
    stats = { loads = 0, throttled = 0, started = GetTime(), kept = 0 }
    deferred, deferredTop = {}, Top()
    attached = false  -- the save is taken up again (it may belong to another fingerprint by now)
    Attach()
    for i, c in ipairs(candidates) do
        c.tries, c.retryAt, c.pct, c.rated = nil, nil, nil, nil
        Push(c)
    end
    Prioritize()
    dirty, running = true, tail > 0
    Changed()
    if running then
        local gen = generation
        C_Timer.After(0, function() Tick(gen) end)
    end
end

function Rank.Stop()
    generation = generation + 1
    queue, head, tail, running = {}, 1, 0, false
end

function Rank.Progress() return rated, #all, running, missing end

function Rank.Stats()
    local seconds = math.max(0, GetTime() - (stats.started or 0))
    local perSecond = seconds > 0 and rated / seconds or 0
    local left = #all - rated
    return { total = #all, rated = rated, missing = missing, queued = running and (tail - head + 1) or 0,
        deferred = #deferred, kept = stats.kept,
        loads = stats.loads, throttled = stats.throttled, limit = REQUESTS, seconds = seconds, perSecond = perSecond,
        eta = perSecond > 0 and left > 0 and left / perSecond or nil }
end

-- a raised level top brings the items put aside back into the queue
local function Undefer()
    local top = Top()
    if deferredTop and top <= deferredTop then return end
    deferredTop = top
    local keep, back = {}, {}
    for _, c in ipairs(deferred) do
        if (c.reqLevel or 0) > top then keep[#keep + 1] = c else back[#back + 1] = c end
    end
    if #back == 0 then return end
    deferred, rated = keep, rated - #back
    if running then
        for _, c in ipairs(back) do Push(c) end
        return
    end
    queue, head, tail, running = back, 1, #back, true  -- the finished queue is spent: a fresh one
    local gen = generation
    C_Timer.After(0, function() Tick(gen) end)
end

function Rank.Dirty()
    dirty = true
    Undefer()
    if running then Prioritize() end
end

local service = Sendit.Service("upgrade")
if service then
    service.OnChange(function()
        cache, attached = {}, false
        if ns.db then ns.db.auctionRatings = nil end
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
