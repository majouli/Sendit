--[[
  Boost: "gear boost" - which quests give an item that is an upgrade for you.
  Every reward item (guaranteed and pick-one) of the quests you can take now
  is rated once by Sendit Upgrade (Sendit.ItemRatings -> Sendit.Service
  "upgrade": the character recalculated with the item, for your spec). A
  quest counts with its best item; a pick-one reward counts because you can
  pick it.

  Only quests possible now: not done, your race / class (Track.Allowed), its
  required level reached, the item usable at your level (no level gate). A
  quest without a known required level (some new Forever quests) counts only
  up to its quest level = your level + LEVEL_AHEAD (assumption: the game shows
  quests up to a few levels above you as takeable; a level-58 quest is not one
  for a level-45 character - seen in game).
  Threshold, display and order use one number: the gain for the whole
  character in the spec's main metric - the same "+1,0 % Damage" as Upgrade's
  item tooltip. (A ratio against the worn item blew tiny differences up to
  "+60 % vs Hands" for a sidegrade - seen in game; the character gain only
  looked broken earlier because items that loaded slowly were dropped.) A
  loss in the second metric ("but Survival -2,6 %") is shown with it.
  It runs only when the player starts it (UI/BoostDialog.lua): gear, level
  or spec changes mark the result stale, they never start it again by
  themselves (an automatic restart looked like an endless loop in game).

  Boost.Available() / Start() / Stop() / Active() / Stale()
  Boost.Min() / SetMin(pct)  the threshold (account layout: boostMin), default 1,
                             decimals allowed (0,5)
  Boost.Ahead() / SetAhead(n)  preview: also quests (and their items) up to n
                             levels above you (account layout: boostAhead), default 0
  Boost.Locked() / SetLocked(on)  also quests of a chain whose prerequisites are
                             still open (account layout: boostLocked), default on
  Boost.SLOTS, Boost.Slot(key) / SetSlot(key, on) / SlotLabel(group)
                             which slots count (account layout: boostSlots);
                             a filter on the ratings, so switching is instant
  Boost.Get(id) -> { pct, slotPct, secondaryPct, secondaryLabel, itemID, label,
                             equipLoc } or nil (cached; Invalidate() when an input changes)
  Boost.Progress() -> rated, total, running, missing   (items; missing = never sent by the server)
  Boost.Report() -> lines (English diagnostics, /sq boost): what was rated,
                             why items do not count, which ones never arrived
]]
local _, ns = ...
local Boost = {}
ns.Boost = Boost
-- the item scanner (Sendit core, shared with Dungeons): this module's own
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

-- The level a quest asks for: its required level, else (unknown) its quest level - LEVEL_AHEAD.
local function Needed(q)
    if q.requiredLevel then return q.requiredLevel end
    return (q.questLevel or 0) - LEVEL_AHEAD
end

-- The level from which a quest can be taken, while that is above the player's (the preview shows such
-- quests: the list says "from level X"); nil when it can be taken now or the level is unknown.
function Boost.NeedsLevel(q)
    local ok, level = pcall(UnitLevel, "player")
    if not q or not ok or (issecretvalue and issecretvalue(level)) or type(level) ~= "number" then return nil end
    local need = Needed(q)
    return need > level and need or nil
end

-- The preview (Ahead) moves the player's level up.
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

-- nil when the client keeps the level secret: then the item's own level gate decides.
local function Level()
    local ok, level = pcall(UnitLevel, "player")
    if not ok or (issecretvalue and issecretvalue(level)) or type(level) ~= "number" then return nil end
    return level
end

-- [questID] = { itemID, ... } of the quests possible now.
-- Also counts why the other quests are left out (Boost.Report): every quest
-- lands in exactly one bucket, in this order.
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
    Boost.Invalidate()  -- new ratings arrived
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

-- Slot groups the player can pick in the dialog: client slot types per group.
-- The label: the client's own slot name, or ours for groups of several types.
Boost.SLOTS = {
    { key = "head", locs = { "INVTYPE_HEAD" } }, { key = "neck", locs = { "INVTYPE_NECK" } },
    { key = "shoulder", locs = { "INVTYPE_SHOULDER" } }, { key = "back", locs = { "INVTYPE_CLOAK" } },
    { key = "chest", locs = { "INVTYPE_CHEST", "INVTYPE_ROBE" } }, { key = "wrist", locs = { "INVTYPE_WRIST" } },
    { key = "hands", locs = { "INVTYPE_HAND" } }, { key = "waist", locs = { "INVTYPE_WAIST" } },
    { key = "legs", locs = { "INVTYPE_LEGS" } }, { key = "feet", locs = { "INVTYPE_FEET" } },
    { key = "finger", locs = { "INVTYPE_FINGER" } }, { key = "trinket", locs = { "INVTYPE_TRINKET" } },
    { key = "weapon", locs = { "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND" }, own = "slotWeapon" },
    { key = "offhand", locs = { "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE" }, own = "slotOffhand" },
    { key = "ranged", locs = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC" }, own = "slotRanged" },
}
local groupOf = {}
for _, g in ipairs(Boost.SLOTS) do for _, loc in ipairs(g.locs) do groupOf[loc] = g.key end end

function Boost.SlotLabel(g)
    if g.own then return ns.L[g.own] end
    local name = _G[g.locs[1]]
    return type(name) == "string" and name or g.key
end

-- Which slot groups count (account layout: boostSlots[key] = false hides one).
function Boost.Slot(key)
    local slots = ns.module.db and ns.module.db.boostSlots
    return not (slots and slots[key] == false)
end

function Boost.SetSlot(key, on)
    if not ns.module.db then return end
    ns.module.db.boostSlots = ns.module.db.boostSlots or {}
    ns.module.db.boostSlots[key] = on and true or false
    Boost.Invalidate()
end

-- Slots filter what is shown, not what is rated: switching one is instant.
local function Wanted(equipLoc)
    local key = equipLoc and groupOf[equipLoc]
    return key == nil or Boost.Slot(key)
end

-- Answers are kept until something they depend on changes (ratings arrive,
-- threshold, slots, start / stop): the list sorts thousands of quests and
-- asked Get twice per comparison - "script ran too long" in game.
local memo = {}
function Boost.Invalidate() memo = {} end

-- Counts: the character gets at least Min % stronger. The quest shows its
-- best item.
local function Compute(id)
    local items = active and candidates[id]
    if not items or ns.Progress.State(id) == "done" then return false end  -- turned in meanwhile
    local min, best = Boost.Min(), nil
    local ahead, level = Boost.Ahead(), Level()
    for _, itemID in ipairs(items) do
        local r = Ratings.Get(itemID)
        if not r and ahead > 0 and level then  -- preview: an item for a level you reach within Ahead counts
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

-- Why the list looks as it does: every candidate item with its outcome.
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
    for _, g in ipairs(Boost.SLOTS) do if not Boost.Slot(g.key) then off[#off + 1] = g.key end end
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
