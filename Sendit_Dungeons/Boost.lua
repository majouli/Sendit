--[[
  Boost: "gear boost" for dungeons - the same algorithm as the Quests journal.
  Every item the bosses of the dungeons you can enter now drop is rated once
  by Sendit Upgrade (Sendit.ItemRatings -> Sendit.Service "upgrade": the
  character recalculated with the item, for your spec). An item counts when
  your whole character gets at least Min % stronger - the same "+1,0 % Damage"
  as Upgrade's item tooltip; a dungeon counts with its best item and is sorted
  by it. Range (Boost.Ahead): standard = what you can do now - dungeons you
  can enter, items you can wear (like Quests). A preview of N levels above
  also takes dungeons and items up to level + N: such an item is rated for
  your character as it is now (what it would give if you could wear it) and
  carries its level (rating.gate) so the window says "from level X".
  It runs only when the player starts it; gear, level or spec changes mark it
  stale (never a restart by itself - that looked like an endless loop in game).

  Boost.Available() / Start() / Stop() / Active() / Stale()
  Boost.Min() / SetMin(pct)   threshold (account layout: boostMin), default 1
  Boost.Ahead() / SetAhead(n) range: levels above yours (account layout: boostAhead),
                              0 = standard; changing it rates again while it runs
  Boost.Get(map) -> { pct, label, secondaryPct, secondaryLabel, itemID, boss, count, gate } or nil
                              (best item, count = items over the threshold; cached)
  Boost.Item(itemID) -> the item's rating when it counts, else nil
  Boost.Progress() -> rated, total, running, missing
  Boost.Report() -> lines (English diagnostics, /sd boost)
]]
local _, ns = ...
local Boost = {}
ns.Boost = Boost
local Ratings = Sendit.ItemRatings.New()
ns.ItemRatings = Ratings
local active, stale, subscribed = false, false, false
local candidates = {}   -- [map] = { { itemID, boss }, ... } of the dungeons enterable now
local memo = {}

local function Service() return Sendit.Service("upgrade") end
function Boost.Available() return Service() ~= nil end
function Boost.Active() return active end
function Boost.Stale() return stale end
function Boost.Invalidate() memo = {} end

function Boost.Min()
    local v = ns.module.db and tonumber(ns.module.db.boostMin)
    return v or 1
end

function Boost.SetMin(pct)
    if ns.module.db then ns.module.db.boostMin = math.max(0, math.min(100, tonumber(pct) or 1)) end
    Boost.Invalidate()
end

function Boost.Ahead()
    local v = ns.module.db and tonumber(ns.module.db.boostAhead)
    return math.max(0, math.floor(v or 0))
end

function Boost.SetAhead(n)
    if ns.module.db then ns.module.db.boostAhead = math.max(0, math.floor(tonumber(n) or 0)) end
    if active then Boost.Start() end
end

-- The highest level the range reaches (nil: the client keeps the level secret).
local function Reach()
    local level = ns.Database.Level()
    return level and level + Boost.Ahead()
end

local function Changed()
    Boost.Invalidate()
    if ns.Window then ns.Window:BoostChanged() end
end

local function Candidates()
    local reach, out = Reach(), {}
    for _, d in ipairs(ns.Database.All()) do
        if ns.Database.Enterable(d, reach) then
            local items = {}
            for _, boss in ipairs(d.bosses) do
                for _, drop in ipairs(ns.Database.Loot(boss)) do items[#items + 1] = { drop[1], boss } end
            end
            if #items > 0 then out[d.map] = items end
        end
    end
    return out
end

function Boost.Start()
    local svc = Service()
    if not svc then return false end
    if not subscribed and svc.OnChange then
        subscribed = true
        svc.OnChange(function() if active then stale = true Changed() end end)
    end
    active, stale = true, false
    candidates = Candidates()
    local ids, seen = {}, {}
    for _, list in pairs(candidates) do
        for _, drop in ipairs(list) do
            if not seen[drop[1]] then seen[drop[1]] = true ids[#ids + 1] = drop[1] end
        end
    end
    table.sort(ids)
    Boost.Invalidate()
    Ratings.Start(ids, Changed, Changed)
    return true
end

function Boost.Stop()
    active, stale = false, false
    Ratings.Stop()
    Boost.Invalidate()
end

-- The item's rating within the range (also under the threshold), or nil.
local function InRange(itemID)
    local r = Ratings.Get(itemID)
    if not r and Boost.Ahead() > 0 then
        local g, reach = Ratings.Gated(itemID), Reach()
        if g and reach and g.gate <= reach then r = g end
    end
    return r
end

function Boost.Item(itemID)
    if not active then return nil end
    local r = InRange(itemID)
    if r and r.pct >= Boost.Min() then return r end
    return nil
end

local function Compute(map)
    local items = active and candidates[map]
    if not items then return false end
    local best, count, counted = nil, 0, {}
    for _, drop in ipairs(items) do
        local r = Boost.Item(drop[1])
        if r and not counted[drop[1]] then
            counted[drop[1]] = true
            count = count + 1
            if not best or r.pct > best.pct then
                best = { pct = r.pct, label = r.label, secondaryPct = r.secondaryPct,
                    secondaryLabel = r.secondaryLabel, itemID = drop[1], boss = drop[2], gate = r.gate }
            end
        end
    end
    if best then best.count = count end
    return best or false
end

function Boost.Get(map)
    local r = memo[map]
    if r == nil then
        r = Compute(map)
        memo[map] = r
    end
    return r or nil
end

function Boost.Progress() return Ratings.Progress() end

-- Why the list looks as it does: dungeons and items with their outcome.
function Boost.Report()
    local out = {}
    local function Add(fmt, ...) out[#out + 1] = fmt:format(...) end
    if not active then
        Add("boost is not running - start it in the window (Gear boost)")
        return out
    end
    local svc, level = Service(), ns.Database.Level()
    local rated, total, running, missing = Ratings.Progress()
    local entered, shown, skipped = 0, 0, 0
    for _, d in ipairs(ns.Database.All()) do
        if candidates[d.map] then entered = entered + 1 if Boost.Get(d.map) then shown = shown + 1 end
        elseif not ns.Database.Enterable(d, Reach()) then skipped = skipped + 1 end
    end
    Add("level %s, range +%d, rated for %s, threshold %s %%, stale: %s", tostring(level or "?"), Boost.Ahead(),
        tostring(svc and svc.Spec and svc.Spec() or "?"), tostring(Boost.Min()), tostring(stale))
    Add("dungeons: %d in the data - %d in range with known loot, %d above the range, %d listed",
        #ns.Database.All(), entered, skipped, shown)
    Add("%d different items: %d answered, %d never sent by the server%s", total, rated, missing,
        running and " - still rating" or "")
    local why, counts = { worse = "weaker than what you wear", nogain = "changes nothing for your spec",
        noCompare = "not wearable here / no slot to compare", gate = "needs a higher level",
        unusable = "you cannot use it", missing = "never sent by the server", error = "rating failed" }, {}
    local over, under = 0, 0
    local seen = {}
    for _, list in pairs(candidates) do
        for _, drop in ipairs(list) do
            local id = drop[1]
            if not seen[id] then
                seen[id] = true
                local r = InRange(id)
                if r then
                    if r.pct >= Boost.Min() then over = over + 1 else under = under + 1 end
                else
                    local key = Ratings.Why(id) or "pending"
                    counts[key] = (counts[key] or 0) + 1
                end
            end
        end
    end
    Add("%d items at least %s %%, %d with a smaller gain", over, tostring(Boost.Min()), under)
    for key, n in pairs(counts) do Add("%d items: %s", n, why[key] or key) end
    return out
end
