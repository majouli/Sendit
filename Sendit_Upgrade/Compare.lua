--[[
  Compare: rates an item by equipping it virtually and recomputing the character for the spec.
  Compare.Evaluate(link) -> result | nil
    status "ok" | "equipped" | "unusable" | "noCompare" | "loading" | "unsupported" | "nodata"
    primary / secondary = { label, unit, pct, abs } - pct = change of the whole character;
    primary.slotPct = gain against what the worn item itself is worth (nil: empty slot / adds nothing)
    breakdown = { { name, value } }, levelGate, item
  Compare.Pair(linkA, linkB) -> both rated in one slot;  Compare.Context() -> ctx (cached 1 s)
  Rings and trinkets: the better of the two replacements counts.
]]
local _, ns = ...

local Compare = {}
ns.Compare = Compare

-- equipLoc -> inventory slots the item can go into
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    -- One-handers: main hand; also the off hand for classes that dual wield (SlotsFor).
    INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
Compare.SLOTS = SLOTS

-- Classes that dual wield (Classic: Warriors and Hunters from level 20 via
-- trainer, Rogues from the start). The client's CanDualWield() answers when
-- it exists; the class list is the fallback.
local DUAL_WIELD = { WARRIOR = true, ROGUE = true, HUNTER = true }

local function DualWields()
    local fn = _G["CanDualWield"]
    if type(fn) == "function" then
        local ok, yes = pcall(fn)
        if ok and yes ~= nil then return yes == true end
    end
    local _, class = UnitClass("player")
    return DUAL_WIELD[class] == true
end

function Compare.SlotsFor(item)
    local loc = item and item.equipLoc or ""
    if loc == "INVTYPE_WEAPON" and DualWields() then return { 16, 17 } end
    return SLOTS[loc]
end
local EPSILON = 1e-6

local cached, cachedAt

function Compare.Invalidate()
    cached = nil
end

local function ReadGear()
    local gear = {}
    for slot = 1, 18 do
        local link = GetInventoryItemLink("player", slot)
        if link and not (issecretvalue and issecretvalue(link)) then
            local item = ns.Stats.Read(link)
            if not item then return nil end  -- not cached yet
            gear[slot] = item
        end
    end
    return gear
end

-- the tree with the most talent points (classData.trees in client order); nil without points
local function FromTalents(classData, gear, s)
    local Points = Sendit.TalentPoints
    local main = Points.Main(Points.Own())
    local spec = main and classData.trees and classData.trees[main]
    if type(spec) ~= "table" then return spec end
    local guess = classData.Guess(gear, s)
    for _, key in ipairs(spec) do if key == guess then return key end end
    return spec[1]
end

function Compare.Context()
    local now = GetTime()
    if cached and cachedAt and now - cachedAt < 1 then return cached end
    local gear = ReadGear()
    if not gear then return nil, "loading" end
    local s = ns.Character.Snapshot(gear)
    if not s then return nil, "nodata" end
    local classData = ns.Specs[s.class]
    if not classData then return nil, "unsupported" end
    if not InCombatLockdown() then ns.Calibrate.Sample(s) end
    local auto = FromTalents(classData, gear, s) or classData.Guess(gear, s)  -- s: the Druid's form decides first
    local key = (ns.charDB and ns.charDB.spec) or auto
    if not classData.specs[key] then key = auto end
    cached = { gear = gear, s = s, specKey = key, spec = classData.specs[key], auto = auto,
               classData = classData }
    cachedAt = now
    return cached
end

local function AddStats(into, item, sign)
    if not item then return end
    for k, v in pairs(item.stats) do into[k] = (into[k] or 0) + sign * v end
end

-- What changes when `item` (nil = nothing) goes into `slot`: stat delta and
-- the weapons argument of Character.Apply, or nil when not possible.
local function Swap(ctx, item, slot)
    local gear, delta, weapons = ctx.gear, {}, nil
    if slot == 16 then
        AddStats(delta, gear[16], -1)
        weapons = { main = item and item.weapon or false }
        if item and item.equipLoc == "INVTYPE_2HWEAPON" then
            AddStats(delta, gear[17], -1)  -- a two-hander frees the off hand
            weapons.off = false
        end
    elseif slot == 17 then
        if gear[16] and gear[16].equipLoc == "INVTYPE_2HWEAPON" then return nil end
        AddStats(delta, gear[17], -1)
        weapons = { off = item and item.weapon or false }
    elseif slot == 18 then
        AddStats(delta, gear[18], -1)
        weapons = { ranged = item and item.weapon or false }
    else
        AddStats(delta, gear[slot], -1)
    end
    AddStats(delta, item, 1)
    return delta, weapons
end

-- Talents that multiply a stat (spec.statMult, e.g. Lightning Reflexes +15%
-- agility) act on the item stats too; the live stats already contain them.
local function Scaled(ctx, delta)
    local mult = ctx.spec.statMult
    if not mult then return delta end
    local out = {}
    for k, v in pairs(delta) do out[k] = v * (mult[k] or 1) end
    return out
end
Compare._Scaled = Scaled

local function Metrics(ctx, item, slot)
    local delta, weapon = Swap(ctx, item, slot)
    if not delta then return nil end
    local after = ns.Character.Apply(ctx.s, Scaled(ctx, delta), weapon)
    return { primary = ctx.spec.primary.fn(after), secondary = ctx.spec.secondary.fn(after) }, delta, weapon
end

local function Change(metric, now, new)
    return {
        label = metric.label, key = metric.key, unit = metric.unit, abs = new - now,
        pct = now > EPSILON and (new / now - 1) * 100 or nil,
    }
end

local function Breakdown(ctx, delta, weapon)
    local fn, base = ctx.spec.primary.fn, ctx.spec.primary.fn(ctx.s)
    local out = {}
    for key, value in pairs(delta) do
        if value ~= 0 then
            local v = fn(ns.Character.Apply(ctx.s, Scaled(ctx, { [key] = value }))) - base
            out[#out + 1] = { key = key, name = ns.StatNames[key] or key, amount = value, value = v }
        end
    end
    if weapon ~= nil then
        local v = fn(ns.Character.Apply(ctx.s, {}, weapon)) - base
        out[#out + 1] = { key = "weapon", name = ns.L.weapon, value = v }
    end
    table.sort(out, function(a, b) return math.abs(a.value) > math.abs(b.value) end)
    return out
end

local function RateInSlot(ctx, item, slot)
    local now = { primary = ctx.spec.primary.fn(ctx.s), secondary = ctx.spec.secondary.fn(ctx.s) }
    local new, delta, weapon = Metrics(ctx, item, slot)
    if not new then return nil end
    local primary = Change(ctx.spec.primary, now.primary, new.primary)
    -- what the worn item is worth: the character with that slot empty
    local empty = Metrics(ctx, nil, slot)
    local worth = empty and now.primary - empty.primary or 0
    primary.slotPct = (ctx.gear[slot] and worth > EPSILON) and primary.abs / worth * 100 or nil
    primary.slotEmpty = ctx.gear[slot] == nil
    return {
        slot = slot, metrics = new,
        primary = primary,
        secondary = Change(ctx.spec.secondary, now.secondary, new.secondary),
        breakdown = Breakdown(ctx, delta, weapon),
    }
end

local function Usability(item, level)
    local gate, unusable = nil, false
    for _, text in ipairs(item.red) do
        if item.minLevel > level and text:find(tostring(item.minLevel), 1, true) then
            gate = item.minLevel
        else
            unusable = true
        end
    end
    return unusable, gate
end

local OFF_HAND = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true }
local MAIN_HAND = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true }

local function ForSpec(ctx, specKey)
    if not specKey or specKey == ctx.specKey then return ctx end
    local spec = ctx.classData.specs[specKey]
    if not spec then return nil end
    return setmetatable({ specKey = specKey, spec = spec }, { __index = ctx })
end

-- What a weapon, shield or off-hand item adds for a spec with both hands empty: a second spec's weapons
-- (a shield and a one-hander for a tank) cannot be weighed against the worn two-hander. Higher is better,
-- comparable between items of one kind. -> gain | nil, status ("loading", "unusable", "noCompare", ...)
function Compare.WeaponScore(link, specKey)
    local item = ns.Stats.Read(link)
    if not item then return nil, "loading" end
    local slot = MAIN_HAND[item.equipLoc] and 16 or OFF_HAND[item.equipLoc] and 17 or nil
    if not slot then return nil, "noCompare" end
    local ctx, reason = Compare.Context()
    if not ctx then return nil, reason end
    ctx = ForSpec(ctx, specKey)
    if not ctx then return nil, "noCompare" end
    if Usability(item, ctx.s.level) then return nil, "unusable" end
    local bare = {}
    AddStats(bare, ctx.gear[16], -1)
    AddStats(bare, ctx.gear[17], -1)
    local before = ctx.spec.primary.fn(ns.Character.Apply(ctx.s, Scaled(ctx, bare), { main = false, off = false }))
    local with = {}
    for k, v in pairs(bare) do with[k] = v end
    AddStats(with, item, 1)
    local weapons = { main = false, off = false }
    if slot == 16 then weapons.main = item.weapon or false else weapons.off = item.weapon or false end
    local after = ctx.spec.primary.fn(ns.Character.Apply(ctx.s, Scaled(ctx, with), weapons))
    return after - before
end

-- specKey (optional): rate for another spec of the class (a second spec) instead of the rated one
function Compare.Evaluate(link, specKey)
    local item = ns.Stats.Read(link)
    if not item then return { status = "loading" } end
    local slots = Compare.SlotsFor(item)
    if not slots then return nil end
    local ctx, reason = Compare.Context()
    if not ctx then return { status = reason, item = item } end
    ctx = ForSpec(ctx, specKey)
    if not ctx then return { status = "noCompare", item = item } end

    for _, slot in ipairs(slots) do
        if ctx.gear[slot] and ctx.gear[slot].link == link then
            return { status = "equipped", item = item }
        end
    end
    local unusable, gate = Usability(item, ctx.s.level)
    if unusable then return { status = "unusable", item = item } end

    local best
    for _, slot in ipairs(slots) do
        local r = RateInSlot(ctx, item, slot)
        if r and (not best or r.primary.abs > best.primary.abs) then best = r end
    end
    if not best then return { status = "noCompare", item = item } end
    best.status, best.item, best.levelGate = "ok", item, gate
    best.ctx = ctx
    return best
end

function Compare.Pair(linkA, linkB)
    local a, b = ns.Stats.Read(linkA), ns.Stats.Read(linkB)
    if not (a and b) then return { status = "loading" } end
    local ctx, reason = Compare.Context()
    if not ctx then return { status = reason } end
    local slotsA, slotsB = Compare.SlotsFor(a), Compare.SlotsFor(b)
    if not (slotsA and slotsB) or slotsA[1] ~= slotsB[1] then
        return { status = "differentSlots" }
    end
    local slot = slotsA[1]
    local ma = Metrics(ctx, a, slot)
    local mb = Metrics(ctx, b, slot)
    if not (ma and mb) then return { status = "noCompare" } end
    return { status = "ok", ctx = ctx, a = a, b = b, ma = ma, mb = mb }
end
