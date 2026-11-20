--[[
  Boost: which quests give an item that is an upgrade - every reward item (fixed and pick-one) of the
  quests in range rated once by Sendit Upgrade (Sendit.ItemRatings -> Service "upgrade"); a quest counts
  with its best item, by the whole character's gain in the spec's main metric (as Upgrade's tooltip).
  In range: not done, race / class, required level reached (unknown: quest level - LEVEL_AHEAD);
  Ahead moves the level up. Runs only when started; changes mark it stale.
  Boost.Available() / Start() / Stop() / Active() / Stale()
  Boost.Min() / SetMin(pct)       account: boostMin (decimals allowed)
  Boost.Ahead() / SetAhead(n)     account: boostAhead;   Boost.NeedsLevel(q) -> level | nil
  Boost.Locked() / SetLocked(on)  account: boostLocked (also locked chain steps)
  Boost.Slot(key) / SetSlot(key, on)   account: boostSlots (Sendit.GearSlots groups, a filter)
  Boost.Get(id) -> { pct, slotPct, secondaryPct, secondaryLabel, itemID, label, equipLoc } | nil
  Boost.Progress() -> rated, total, running, missing;  Boost.Report() -> lines (/sq boost)
]]
local _, ns = ...
local Boost = {}
ns.Boost = Boost
local Ratings = Sendit.ItemRatings.New()
ns.ItemRatings = Ratings
local active, candidates, subscribed, stale = false, {}, false, false
local LEVEL_AHEAD = 3

function Boost.Ahead()
    local v = ns.module.db and tonumber(ns.module.db.boostAhead)
    return v and math.max(0, math.min(10, math.floor(v))) or 0
end

function Boost.SetAhead(n)
    if ns.module.db then ns.module.db.boostAhead = math.max(0, math.min(10, math.floor(tonumber(n) or 0))) end
end

local function Needed(q)
    if q.requiredLevel then return q.requiredLevel end
    return (q.questLevel or 0) - LEVEL_AHEAD
end

-- the level a preview quest can be taken from; nil when it can be taken now or unknown
function Boost.NeedsLevel(q)
    local ok, level = pcall(UnitLevel, "player")
    if not q or not ok or (issecretvalue and issecretvalue(level)) or type(level) ~= "number" then return nil end
    local need = Needed(q)
    return need > level and need or nil
end

function Boost.TooHigh(q, level)
    if not level or not q then return false end
    return Needed(q) > level + Boost.Ahead()
end

local function Service() return Sendit.Service("upgrade") end
function Boost.Available() return Service() ~= nil end
function Boost.Active() return active end
function Boost.Stale() return stale end

function Boost.Locked()
    local v = ns.module.db and ns.module.db.boostLocked
    return v ~= false
end

function Boost.SetLocked(on)
    if ns.module.db then ns.module.db.boostLocked = on and true or false end
end

function Boost.Min()
    local v = ns.module.db and tonumber(ns.module.db.boostMin)
    return v or 1
end

function Boost.SetMin(pct)
    if ns.module.db then ns.module.db.boostMin = math.max(0, math.min(100, tonumber(pct) or 1)) end
    Boost.Invalidate()
end

local function Level()
    local ok, level = pcall(UnitLevel, "player")
    if not ok or (issecretvalue and issecretvalue(level)) or type(level) ~= "number" then return nil end
    return level
end

-- [questID] = { itemID, ... } of the quests in range; every other quest lands in one
-- bucket of Boost.Report's counts, in this order
local scan = {}
local function Candidates()
    local level, out = Level(), {}
    scan = { quests = 0, noItems = 0, done = 0, level = 0, notForYou = 0, locked = 0, taken = 0,
        guaranteed = 0, choice = 0 }
    for id, q in pairs(ns.quests) do
        scan.quests = scan.quests + 1
        local r, items = q.rewards, {}
        for _, item in ipairs(r and r.items or {}) do items[#items + 1] = item.itemId end
        local fixed = #items
        for _, item in ipairs(r and r.choice or {}) do items[#items + 1] = item.itemId end
        if #items == 0 then scan.noItems = scan.noItems + 1
        elseif ns.Progress.State(id) == "done" then scan.done = scan.done + 1
        elseif Boost.TooHigh(q, level) then scan.level = scan.level + 1
        elseif not ns.Track.Allowed(id) then scan.notForYou = scan.notForYou + 1
        elseif not Boost.Locked() and ns.Style.Show(id, ns.Database.Prerequisites(id)) == "locked" then
            scan.locked = scan.locked + 1
        else
            out[id] = items
            scan.taken = scan.taken + 1
            scan.guaranteed, scan.choice = scan.guaranteed + fixed, scan.choice + #items - fixed
        end
    end
    return out
end

local function Changed()
    Boost.Invalidate()
    if ns.Window then ns.Window:BoostChanged() end
end

function Boost.Start()
    local svc = Service()
    if not svc then return false end
    if not subscribed and svc.OnChange then  -- Upgrade loads after Quests: subscribe on first use
        subscribed = true
        svc.OnChange(function()
            if active then stale = true Changed() end
        end)
    end
    active, stale = true, false
    Boost.Invalidate()
    candidates = Candidates()
    local items = {}
    for _, list in pairs(candidates) do
        for _, itemID in ipairs(list) do items[#items + 1] = itemID end
    end
    table.sort(items)
    Ratings.Start(items, Changed, Changed)
    return true
end

function Boost.Stop()
    active, stale = false, false
    Boost.Invalidate()
    Ratings.Stop()
end

function Boost.Slot(key) return Sendit.GearSlots.On(ns.module.db, key) end

function Boost.SetSlot(key, on)
    Sendit.GearSlots.Set(ns.module.db, key, on)
    Boost.Invalidate()
end

local function Wanted(equipLoc) return Sendit.GearSlots.Wanted(ns.module.db, equipLoc) end

-- answers are kept until an input changes: the list sorts thousands of quests
local memo = {}
function Boost.Invalidate() memo = {} end

local function Compute(id)
    local items = active and candidates[id]
    if not items or ns.Progress.State(id) == "done" then return false end
    local min, best = Boost.Min(), nil
    local ahead, level = Boost.Ahead(), Level()
    for _, itemID in ipairs(items) do
        local r = Ratings.Get(itemID)
        if not r and ahead > 0 and level then  -- preview: an item for a level reached within Ahead counts
            local g = Ratings.Gated(itemID)
            if g and g.gate and g.gate <= level + ahead then r = g end
        end
        if r and r.pct >= min and Wanted(r.equipLoc) and (not best or r.pct > best.pct) then
            best = { pct = r.pct, slotPct = r.slotPct, itemID = itemID, label = r.label, equipLoc = r.equipLoc,
                secondaryPct = r.secondaryPct, secondaryLabel = r.secondaryLabel }
        end
    end
    return best or false
end

function Boost.Get(id)
    local r = memo[id]
    if r == nil then
        r = Compute(id)
        memo[id] = r
    end
    return r or nil
end

function Boost.Progress() return Ratings.Progress() end

local function QuestName(id)
    return ns.Database.Name(id) .. " (" .. id .. ")"
end

local function ItemName(itemID)
    local get = C_Item and C_Item.GetItemNameByID
    local ok, name = false, nil
    if get then ok, name = pcall(get, itemID) end
    return ok and type(name) == "string" and name or ("item " .. itemID)
end

function Boost.Report()
    local out = {}
    local function Add(fmt, ...) out[#out + 1] = fmt:format(...) end
    if not active then
        Add("boost is not running - start it in the journal (Boost)")
        return out
    end
    local svc = Service()
    local rated, total, running, missing = Ratings.Progress()
    local min, quests, questOf = Boost.Min(), 0, {}
    for id, items in pairs(candidates) do
        quests = quests + 1
        for _, itemID in ipairs(items) do questOf[itemID] = questOf[itemID] or id end
    end
    Add("level %s, rated for %s, threshold %s %%, stale: %s", tostring(Level() or "?"),
        tostring(svc and svc.Spec and svc.Spec() or "?"), tostring(min), tostring(stale))
    Add("quests in the database: %d - without reward items %d, done %d, level too high %d, not for your race / class %d%s",
        scan.quests, scan.noItems, scan.done, scan.level, scan.notForYou,
        Boost.Locked() and "" or (", chain still locked %d"):format(scan.locked))
    Add("%d quests scanned: %d reward items (%d guaranteed, %d pick-one) = %d different items",
        quests, scan.guaranteed + scan.choice, scan.guaranteed, scan.choice, total)
    Add("items: %d answered, %d never sent by the server%s", rated, missing, running and " - still rating" or "")
    local off = {}
    for _, g in ipairs(Sendit.GearSlots.GROUPS) do if not Boost.Slot(g.key) then off[#off + 1] = g.key end end
    if #off > 0 then Add("slots switched off: %s", table.concat(off, ", ")) end
    local counts, below, slotOff, shown = {}, {}, {}, {}
    for itemID, id in pairs(questOf) do
        local r = Ratings.Get(itemID)
        if r then
            if not Wanted(r.equipLoc) then slotOff[#slotOff + 1] = itemID
            elseif r.pct < min then below[#below + 1] = { itemID, r.pct }
            else shown[#shown + 1] = { itemID, r.pct } end
        else
            local why = Ratings.Why(itemID) or "pending"
            counts[why] = counts[why] or {}
            table.insert(counts[why], itemID)
        end
    end
    local names = { worse = "weaker than what you wear", nogain = "changes nothing for your spec",
        noCompare = "not wearable (consumables, quest items, bags) or no slot to compare",
        gate = "needs a higher level", unusable = "you cannot use it (armor / weapon type, class)",
        missing = "never sent by the server (asked 3 times, 8 s each)", pending = "not rated yet",
        equipped = "already worn", error = "rating failed" }
    Add("%d items at least %s %% (their quests are listed)", #shown, tostring(min))
    Add("%d items with a gain below %s %%", #below, tostring(min))
    if #slotOff > 0 then Add("%d items in switched-off slots", #slotOff) end
    for why, list in pairs(counts) do Add("%d items: %s", #list, names[why] or why) end
    table.sort(shown, function(a, b) return a[2] > b[2] end)
    table.sort(below, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(10, #shown) do
        Add("  + %.2f %%  %s  <- %s", shown[i][2], ItemName(shown[i][1]), QuestName(questOf[shown[i][1]]))
    end
    for i = 1, math.min(5, #below) do
        Add("  below: %.2f %%  %s  <- %s", below[i][2], ItemName(below[i][1]), QuestName(questOf[below[i][1]]))
    end
    for i, itemID in ipairs(counts.missing or {}) do
        if i > 15 then Add("  ... %d more", #counts.missing - 15) break end
        Add("  never sent: item %d  <- %s", itemID, QuestName(questOf[itemID]))
    end
    return out
end
